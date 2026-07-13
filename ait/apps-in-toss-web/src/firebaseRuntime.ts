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
  logActiveAnalyticsPath()
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

// One-line diagnostic so the active path is visible in the WebView console (AIT
// sandbox / remote DevTools). Runs from installFoamPartyFirebaseBridge so it fires
// even when initializeFirebase early-returns on missing config (MP can still be
// the live path in that case).
function logActiveAnalyticsPath() {
  void analyticsReady.then((analytics) => {
    const mode = analytics != null ? 'firebase' : measurementProtocolEnabled() ? 'mp-fallback' : 'disabled'
    console.info(`[FoamParty] analytics path: ${mode}`)
  })
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
    } else {
      // Firebase Analytics unavailable in this WebView (isSupported() false /
      // gtag blocked) — fall back to GA4 Measurement Protocol so collection still
      // works. Only one path runs per event, so there is no double counting.
      sendViaMeasurementProtocol(cleanName, params)
    }
  })
}

// ── GA4 Measurement Protocol fallback ───────────────────────────────────────
// A plain fetch to GA4 that does not depend on gtag, cookies, IndexedDB, or the
// Firebase API key — the exact things that can make Firebase Analytics silently
// no-op inside the AppsInToss WebView. Enabled only when an MP api_secret is set.
const GA4_MP_ENDPOINT = 'https://www.google-analytics.com/mp/collect'

function mpApiSecret() {
  return optional(import.meta.env.VITE_GA4_MP_API_SECRET) ?? ''
}

function mpMeasurementId() {
  return optional(import.meta.env.VITE_FIREBASE_MEASUREMENT_ID) ?? ''
}

function measurementProtocolEnabled() {
  return mpApiSecret() !== '' && mpMeasurementId() !== ''
}

let cachedClientId: string | null = null

function ga4ClientId() {
  if (cachedClientId != null) {
    return cachedClientId
  }
  const key = 'foam_ga4_client_id'
  try {
    const stored = window.localStorage.getItem(key)
    if (stored) {
      cachedClientId = stored
      return stored
    }
  } catch {
    // localStorage blocked — fall through to an in-memory id for this session.
  }
  const generated = `${Date.now()}.${Math.floor(Math.random() * 1_000_000_000)}`
  cachedClientId = generated
  try {
    window.localStorage.setItem(key, generated)
  } catch {
    // ignore: an in-memory client id still lets events land, just not stitched
    // across app restarts.
  }
  return generated
}

// GA4 rolls a session after 30 min of inactivity; mirror that so a long play
// session is not collapsed into one artificially-long session on the GA4 side.
const GA4_SESSION_TIMEOUT_MS = 30 * 60 * 1000
let cachedSessionId = ''
let lastEventAtMs = 0

export function ga4SessionId(nowMs: number = Date.now()) {
  if (cachedSessionId === '' || nowMs - lastEventAtMs > GA4_SESSION_TIMEOUT_MS) {
    cachedSessionId = String(nowMs)
  }
  lastEventAtMs = nowMs
  return cachedSessionId
}

// Pure MP request body builder — extracted so the payload shape (session_id +
// engagement_time_msec, which make GA4 count an engaged session) is unit-tested.
export function buildMpRequestBody(
  clientId: string,
  eventName: string,
  params: EventParams,
  sessionId: string,
): string {
  return JSON.stringify({
    client_id: clientId,
    events: [
      {
        name: eventName,
        params: { ...params, session_id: sessionId, engagement_time_msec: 100 },
      },
    ],
  })
}

function sendViaMeasurementProtocol(eventName: string, params: EventParams) {
  if (!measurementProtocolEnabled()) {
    return
  }
  // GA4 Measurement Protocol REQUIRES api_secret + measurement_id as query params;
  // the API has no header/body option for them. The MP api_secret is a write-only
  // "collection" credential intended to ship in client apps — it cannot read data
  // or change configuration — so query-string exposure over TLS is the documented,
  // accepted design (a server-side proxy is the only alternative, and the static
  // AIT web export has no backend).
  const url = `${GA4_MP_ENDPOINT}?measurement_id=${encodeURIComponent(mpMeasurementId())}&api_secret=${encodeURIComponent(mpApiSecret())}`
  const body = buildMpRequestBody(ga4ClientId(), eventName, params, ga4SessionId())
  try {
    void fetch(url, { method: 'POST', body, keepalive: true })
      .then((res) => {
        // Surface delivery failures so a broken fallback is diagnosable instead of
        // silently swallowing every event (the exact failure mode we are fixing).
        if (!res.ok) {
          console.warn(`[FoamParty] GA4 MP send failed: HTTP ${res.status}`)
        }
      })
      .catch(() => {
        // Log the fact, not the error object (which could echo the URL/secret).
        console.warn('[FoamParty] GA4 MP network error')
      })
  } catch {
    console.warn('[FoamParty] GA4 MP send threw before dispatch')
  }
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

export function parseParams(paramsJson: string): EventParams {
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

export function sanitizeEventName(eventName: string) {
  return sanitizeParamName(eventName).slice(0, 40)
}

export function sanitizeParamName(paramName: string) {
  return paramName.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_')
}

function optional(value: string | undefined) {
  const clean = value?.trim()
  return clean === '' ? undefined : clean
}
