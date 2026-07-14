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

export function installFoamPartyFirebaseBridge() {
  window.__foamPartyFirebase = {
    fetchRemoteConfig,
    getBoolean,
    getNumber,
    getString,
    logEvent: logFirebaseEvent,
    recordError,
  }

  logActiveAnalyticsPath()
}

function logActiveAnalyticsPath() {
  const mode = measurementProtocolEnabled() ? 'ga4-mp' : 'disabled'
  console.info(`[FoamParty] analytics path: ${mode}`)
}

function fetchRemoteConfig() {
  // AIT packages intentionally ship without the Firebase Web SDK or API key.
  // Keep the bridge method as a no-op so the Godot adapter stays compatible.
}

function getBoolean(key: string, fallback: boolean) {
  const value = REMOTE_DEFAULTS[key as keyof typeof REMOTE_DEFAULTS]
  return typeof value === 'boolean' ? value : fallback
}

function getNumber(key: string, fallback: number) {
  const value = REMOTE_DEFAULTS[key as keyof typeof REMOTE_DEFAULTS]
  return typeof value === 'number' ? value : fallback
}

function getString(_key: string, fallback: string) {
  return fallback
}

function logFirebaseEvent(eventName: string, paramsJson = '{}') {
  sendFirebaseEvent(eventName, parseParams(paramsJson))
}

function sendFirebaseEvent(eventName: string, params: EventParams) {
  const cleanName = sanitizeEventName(eventName)
  if (cleanName === '') {
    return
  }
  sendViaMeasurementProtocol(cleanName, params)
}

// AIT uses GA4 Measurement Protocol directly so no Google API key or Firebase
// client SDK is included in the package.
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
