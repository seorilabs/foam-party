import { loadFullScreenAd, showFullScreenAd } from '@apps-in-toss/web-framework'

type FoamPartyAdsBridge = {
  isGameOverInterstitialSupported: () => boolean
  loadGameOverInterstitial: () => void
  showGameOverInterstitial: () => boolean
}

type FullScreenAdEvent = {
  type: string
  data?: {
    unitAmount?: number
    unitType?: string
  }
}

declare global {
  interface Window {
    __foamPartyAds?: FoamPartyAdsBridge
  }
}

const GAME_OVER_PLACEMENT = 'game_over'
const LOAD_TIMEOUT_MS = 15 * 1000

let loaded = false
let loading = false
let showing = false
let disposeLoadListener: (() => void) | null = null
let disposeShowListener: (() => void) | null = null
let loadTimeoutId: ReturnType<typeof window.setTimeout> | null = null

export function installFoamPartyTossFullScreenAdBridge() {
  window.__foamPartyAds = {
    isGameOverInterstitialSupported,
    loadGameOverInterstitial,
    showGameOverInterstitial,
  }

  loadGameOverInterstitial()
}

function isGameOverInterstitialSupported() {
  try {
    return (
      gameOverInterstitialAdGroupId() !== '' &&
      loadFullScreenAd.isSupported() &&
      showFullScreenAd.isSupported()
    )
  } catch {
    return false
  }
}

function loadGameOverInterstitial() {
  if (!isGameOverInterstitialSupported() || loaded || loading) {
    return
  }

  loading = true
  disposeLoadListener?.()
  clearLoadTimeout()
  loadTimeoutId = window.setTimeout(() => {
    if (!loading) {
      return
    }
    loaded = false
    loading = false
    disposeLoadListener?.()
    disposeLoadListener = null
    recordAdError('ait_interstitial_load_timeout', new Error('loadFullScreenAd timed out'))
  }, LOAD_TIMEOUT_MS)
  logAdEvent('load_requested')
  disposeLoadListener = loadFullScreenAd({
    options: {
      adGroupId: gameOverInterstitialAdGroupId(),
    },
    onEvent: (event) => {
      if (event.type === 'loaded') {
        loaded = true
        loading = false
        clearLoadTimeout()
        logAdEvent('loaded')
      }
    },
    onError: (error) => {
      loaded = false
      loading = false
      clearLoadTimeout()
      recordAdError('ait_interstitial_load_failed', error)
    },
  })
}

function showGameOverInterstitial() {
  if (!isGameOverInterstitialSupported()) {
    return false
  }

  if (!loaded || showing) {
    logAdEvent(showing ? 'show_skipped_showing' : 'show_skipped_not_loaded')
    loadGameOverInterstitial()
    return false
  }

  showing = true
  loaded = false
  disposeShowListener?.()
  disposeShowListener = showFullScreenAd({
    options: {
      adGroupId: gameOverInterstitialAdGroupId(),
    },
    onEvent: (event: FullScreenAdEvent) => {
      logAdEvent(event.type, event.data)
      if (event.type === 'dismissed' || event.type === 'failedToShow') {
        showing = false
        disposeShowListener?.()
        disposeShowListener = null
        loadGameOverInterstitial()
      }
    },
    onError: (error) => {
      showing = false
      recordAdError('ait_interstitial_show_failed', error)
      loadGameOverInterstitial()
    },
  })

  return true
}

function gameOverInterstitialAdGroupId() {
  return import.meta.env.VITE_TOSS_INTERSTITIAL_AD_GROUP_ID?.trim() || ''
}

function logAdEvent(eventType: string, details: Record<string, number | string> = {}) {
  window.__foamPartyFirebase?.logEvent(
    `ait_interstitial_${eventNameSuffix(eventType)}`,
    JSON.stringify({
      placement: GAME_OVER_PLACEMENT,
      provider: 'toss_ads',
      ad_group_id: gameOverInterstitialAdGroupId(),
      event_type: eventType,
      ...details,
    }),
  )
}

function recordAdError(stage: string, error: unknown) {
  logAdEvent(stage.replace(/^ait_interstitial_/, ''))
  window.__foamPartyFirebase?.recordError(
    `${stage}: ${errorMessage(error)}`,
    JSON.stringify({
      placement: GAME_OVER_PLACEMENT,
      provider: 'toss_ads',
      ad_group_id: gameOverInterstitialAdGroupId(),
    }),
  )
}

function eventNameSuffix(value: string) {
  return value
    .replace(/([a-z])([A-Z])/g, '$1_$2')
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '')
    .slice(0, 20)
}

function errorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message
  }
  return String(error)
}

function clearLoadTimeout() {
  if (loadTimeoutId == null) {
    return
  }
  window.clearTimeout(loadTimeoutId)
  loadTimeoutId = null
}
