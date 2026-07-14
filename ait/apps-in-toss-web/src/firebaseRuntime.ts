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
    logEvent: () => undefined,
    recordError: () => undefined,
  }

  console.info('[FoamParty] AIT analytics disabled')
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
