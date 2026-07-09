import { loadFullScreenAd, showFullScreenAd } from '@apps-in-toss/web-framework'

// AppsInToss integrated full-screen ads (Toss Ads + AdMob), bridged to the Godot
// game via window.__foamPartyAds. Both interstitial and rewarded use the same
// load/show API; the ad type is decided by the ad group id.
//   - placement "game_over"      → interstitial (VITE_TOSS_INTERSTITIAL_AD_GROUP_ID)
//   - placement "foam_bomb_free" → rewarded     (VITE_TOSS_REWARDED_AD_GROUP_ID)
// Rewards are granted ONLY on the 'userEarnedReward' event (never 'dismissed'),
// per AIT policy. SDK lifecycle events are logged via window.__foamPartyFirebase.

type RewardCallback = (placement: string) => void

type FoamPartyAdsBridge = {
  isRewardedReady: (placement: string) => boolean
  showRewarded: (placement: string, onReward: RewardCallback) => boolean
  showInterstitial: (placement: string) => boolean
}

declare global {
  interface Window {
    __foamPartyAds?: FoamPartyAdsBridge
  }
}

const REWARDED_PLACEMENT = 'foam_bomb_free'
const INTERSTITIAL_PLACEMENT = 'game_over'
const LOAD_TIMEOUT_MS = 15 * 1000

interface AdSlot {
  placement: string
  loaded: boolean
  loading: boolean
  showing: boolean
  disposeLoad: (() => void) | null
  disposeShow: (() => void) | null
  loadTimeoutId: ReturnType<typeof window.setTimeout> | null
}

const slots = new Map<string, AdSlot>()

export function installFoamPartyTossFullScreenAdBridge() {
  window.__foamPartyAds = {
    isRewardedReady,
    showRewarded,
    showInterstitial,
  }
  // Preload both placements up front so they are ready when the game asks.
  preload(REWARDED_PLACEMENT)
  preload(INTERSTITIAL_PLACEMENT)
}

function adGroupId(placement: string): string {
  const env = import.meta.env
  if (placement === REWARDED_PLACEMENT) {
    return env.VITE_TOSS_REWARDED_AD_GROUP_ID?.trim() || ''
  }
  if (placement === INTERSTITIAL_PLACEMENT) {
    return env.VITE_TOSS_INTERSTITIAL_AD_GROUP_ID?.trim() || ''
  }
  return ''
}

function supported(placement: string): boolean {
  try {
    return (
      adGroupId(placement) !== '' &&
      loadFullScreenAd.isSupported() &&
      showFullScreenAd.isSupported()
    )
  } catch {
    return false
  }
}

function slotFor(placement: string): AdSlot {
  let slot = slots.get(placement)
  if (!slot) {
    slot = {
      placement,
      loaded: false,
      loading: false,
      showing: false,
      disposeLoad: null,
      disposeShow: null,
      loadTimeoutId: null,
    }
    slots.set(placement, slot)
  }
  return slot
}

function preload(placement: string) {
  if (!supported(placement)) {
    return
  }
  const slot = slotFor(placement)
  if (slot.loaded || slot.loading) {
    return
  }
  slot.loading = true
  slot.disposeLoad?.()
  clearLoadTimeout(slot)
  slot.loadTimeoutId = window.setTimeout(() => {
    if (!slot.loading) {
      return
    }
    slot.loaded = false
    slot.loading = false
    slot.disposeLoad?.()
    slot.disposeLoad = null
    recordAdError(placement, 'load_timeout', new Error('loadFullScreenAd timed out'))
  }, LOAD_TIMEOUT_MS)
  logAdEvent(placement, 'load_requested')
  slot.disposeLoad = loadFullScreenAd({
    options: { adGroupId: adGroupId(placement) },
    onEvent: (event) => {
      if (event.type === 'loaded') {
        slot.loaded = true
        slot.loading = false
        clearLoadTimeout(slot)
        logAdEvent(placement, 'loaded')
      }
    },
    onError: (error) => {
      slot.loaded = false
      slot.loading = false
      clearLoadTimeout(slot)
      recordAdError(placement, 'load_failed', error)
    },
  })
}

function isRewardedReady(placement: string): boolean {
  if (placement !== REWARDED_PLACEMENT) {
    return false
  }
  const slot = slots.get(placement)
  return supported(placement) && !!slot?.loaded && !slot.showing
}

function showRewarded(placement: string, onReward: RewardCallback): boolean {
  if (placement !== REWARDED_PLACEMENT) {
    return false
  }
  return show(placement, onReward)
}

function showInterstitial(placement: string): boolean {
  return show(placement, null)
}

function show(placement: string, onReward: RewardCallback | null): boolean {
  if (!supported(placement)) {
    return false
  }
  const slot = slotFor(placement)
  if (!slot.loaded || slot.showing) {
    logAdEvent(placement, slot.showing ? 'show_skipped_showing' : 'show_skipped_not_loaded')
    preload(placement)
    return false
  }

  slot.showing = true
  slot.loaded = false
  slot.disposeShow?.()
  slot.disposeShow = showFullScreenAd({
    options: { adGroupId: adGroupId(placement) },
    onEvent: (event) => {
      logAdEvent(placement, event.type)
      if (event.type === 'userEarnedReward') {
        // Grant ONLY here — never on 'dismissed' — per AIT rewarded policy.
        try {
          onReward?.(placement)
        } catch (error) {
          recordAdError(placement, 'reward_callback_failed', error)
        }
      } else if (event.type === 'dismissed' || event.type === 'failedToShow') {
        slot.showing = false
        slot.disposeShow?.()
        slot.disposeShow = null
        preload(placement) // load → show → load
      }
    },
    onError: (error) => {
      slot.showing = false
      recordAdError(placement, 'show_failed', error)
      preload(placement)
    },
  })

  return true
}

function logAdEvent(placement: string, eventType: string, details: Record<string, number | string> = {}) {
  const rewarded = placement === REWARDED_PLACEMENT
  window.__foamPartyFirebase?.logEvent(
    `ait_${rewarded ? 'rewarded' : 'interstitial'}_${eventNameSuffix(eventType)}`,
    JSON.stringify({
      placement,
      provider: 'toss_ads',
      ad_group_id: adGroupId(placement),
      event_type: eventType,
      ...details,
    }),
  )
}

function recordAdError(placement: string, stage: string, error: unknown) {
  logAdEvent(placement, stage)
  window.__foamPartyFirebase?.recordError(
    `ait_${placement}_${stage}: ${errorMessage(error)}`,
    JSON.stringify({ placement, provider: 'toss_ads', ad_group_id: adGroupId(placement) }),
  )
}

function eventNameSuffix(value: string) {
  return value
    .replace(/([a-z])([A-Z])/g, '$1_$2')
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '')
    .slice(0, 24)
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : String(error)
}

function clearLoadTimeout(slot: AdSlot) {
  if (slot.loadTimeoutId == null) {
    return
  }
  window.clearTimeout(slot.loadTimeoutId)
  slot.loadTimeoutId = null
}
