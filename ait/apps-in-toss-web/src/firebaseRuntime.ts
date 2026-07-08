import { getAnalytics, isSupported, logEvent, type Analytics } from 'firebase/analytics'
import { getApp, getApps, initializeApp, type FirebaseApp, type FirebaseOptions } from 'firebase/app'
import { fetchAndActivate, getRemoteConfig, getValue, type RemoteConfig } from 'firebase/remote-config'

type EventParams = Record<string, boolean | number | string>

type FoamPartyFirebaseBridge = {
  fetchRemoteConfig: () => void
  getBoolean: (key: string, fallback: boolean) => boolean
  getNumber: (key: string, fallback: number) => number
  getString: (key: string, fallback: string) => string
  logEvent: (eventName: string, paramsJson?: string) => void
  recordError: (message: string, paramsJson?: string) => void
}

declare global {
  interface Window {
    __foamPartyFirebase?: FoamPartyFirebaseBridge
  }
}

const REMOTE_DEFAULTS = {
  game_over_interstitial_enabled: true,
  game_over_interstitial_max_attempts: 8,
  game_over_interstitial_retry_delay_seconds: 1.5,
}

let app: FirebaseApp | null = null
let analyticsReady: Promise<Analytics | null> = Promise.resolve(null)
let remoteConfig: RemoteConfig | null = null

export function installFoamPartyFirebaseBridge() {
  initializeFirebase()

  window.__foamPartyFirebase = {
    fetchRemoteConfig,
    getBoolean,
    getNumber,
    getString,
    logEvent: logFirebaseEvent,
    recordError,
  }

  fetchRemoteConfig()
}

function initializeFirebase() {
  const config = firebaseOptions()
  if (!config) {
    return
  }

  app = getApps().length > 0 ? getApp() : initializeApp(config)
  remoteConfig = getRemoteConfig(app)
  remoteConfig.settings = {
    fetchTimeoutMillis: 30 * 1000,
    minimumFetchIntervalMillis: 60 * 60 * 1000,
  }
  remoteConfig.defaultConfig = REMOTE_DEFAULTS

  analyticsReady = isSupported()
    .then((supported) => {
      if (!supported || !config.measurementId || app == null) {
        return null
      }
      return getAnalytics(app)
    })
    .catch(() => null)
}

function firebaseOptions(): FirebaseOptions | null {
  const apiKey = optional(import.meta.env.VITE_FIREBASE_API_KEY)
  const projectId = optional(import.meta.env.VITE_FIREBASE_PROJECT_ID)
  const appId = optional(import.meta.env.VITE_FIREBASE_APP_ID)
  if (!apiKey || !projectId || !appId) {
    return null
  }

  return {
    apiKey,
    appId,
    authDomain: optional(import.meta.env.VITE_FIREBASE_AUTH_DOMAIN),
    measurementId: optional(import.meta.env.VITE_FIREBASE_MEASUREMENT_ID),
    messagingSenderId: optional(import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID),
    projectId,
    storageBucket: optional(import.meta.env.VITE_FIREBASE_STORAGE_BUCKET),
  }
}

function fetchRemoteConfig() {
  if (remoteConfig == null) {
    return
  }
  void fetchAndActivate(remoteConfig).catch(() => undefined)
}

function getBoolean(key: string, fallback: boolean) {
  if (remoteConfig == null || key.trim() === '') {
    return fallback
  }
  const value = getValue(remoteConfig, key)
  return value.getSource() === 'static' ? fallback : value.asBoolean()
}

function getNumber(key: string, fallback: number) {
  if (remoteConfig == null || key.trim() === '') {
    return fallback
  }
  const value = getValue(remoteConfig, key)
  return value.getSource() === 'static' ? fallback : value.asNumber()
}

function getString(key: string, fallback: string) {
  if (remoteConfig == null || key.trim() === '') {
    return fallback
  }
  const value = getValue(remoteConfig, key)
  return value.getSource() === 'static' ? fallback : value.asString()
}

function logFirebaseEvent(eventName: string, paramsJson = '{}') {
  sendFirebaseEvent(eventName, parseParams(paramsJson))
}

function sendFirebaseEvent(eventName: string, params: EventParams) {
  const cleanName = sanitizeEventName(eventName)
  if (cleanName === '') {
    return
  }
  void analyticsReady.then((analytics) => {
    if (analytics != null) {
      logEvent(analytics, cleanName, params)
    }
  })
}

function recordError(message: string, paramsJson = '{}') {
  if (message.trim() === '') {
    return
  }
  sendFirebaseEvent('exception', {
    ...parseParams(paramsJson),
    description: message.slice(0, 100),
    fatal: false,
  })
}

function parseParams(paramsJson: string): EventParams {
  try {
    const parsed: unknown = JSON.parse(paramsJson)
    if (parsed == null || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return {}
    }
    return Object.fromEntries(
      Object.entries(parsed)
        .filter(([, value]) => ['boolean', 'number', 'string'].includes(typeof value))
        .map(([key, value]) => [sanitizeParamName(key), value as boolean | number | string])
        .filter(([key]) => key !== ''),
    )
  } catch {
    return {}
  }
}

function sanitizeEventName(eventName: string) {
  return sanitizeParamName(eventName).slice(0, 40)
}

function sanitizeParamName(paramName: string) {
  return paramName.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_')
}

function optional(value: string | undefined) {
  const clean = value?.trim()
  return clean === '' ? undefined : clean
}
