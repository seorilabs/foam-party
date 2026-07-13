import { SafeAreaInsets } from '@apps-in-toss/web-framework'

// AppsInToss WebView safe-area insets, bridged to the Godot game so it can keep
// its HUD and top buttons clear of the status bar / notch / home indicator AND
// the framework's fixed top-right X (close) button. Godot's web export cannot
// read CSS env(safe-area-inset-*) or the AIT SDK directly, so we publish the
// insets (CSS px) plus the current viewport size (CSS px) here and let Godot
// convert to its design space. See main.gd `_safe_area_design_insets`.

type SafeAreaState = {
  top: number
  bottom: number
  left: number
  right: number
  // Viewport in CSS px, needed by Godot to map CSS insets → design units.
  vw: number
  vh: number
}

declare global {
  interface Window {
    __foamPartySafeArea?: SafeAreaState
  }
}

// A single, stable object reference. Godot caches the JS interface once and reads
// live values, so we MUTATE this in place rather than reassigning window.__foamPartySafeArea.
const state: SafeAreaState = { top: 0, bottom: 0, left: 0, right: 0, vw: 0, vh: 0 }

function refreshViewport() {
  state.vw = window.innerWidth
  state.vh = window.innerHeight
}

function apply(insets: { top: number; bottom: number; left: number; right: number }) {
  state.top = insets.top
  state.bottom = insets.bottom
  state.left = insets.left
  state.right = insets.right
  refreshViewport()
}

export function installFoamPartySafeAreaBridge() {
  window.__foamPartySafeArea = state
  refreshViewport()

  try {
    apply(SafeAreaInsets.get())
    // Screen-mode changes (rotation, split view) update the insets.
    SafeAreaInsets.subscribe({ onEvent: apply })
  } catch {
    // SDK unavailable (plain browser dev / sandbox without the bridge). Leave
    // insets at 0 → Godot falls back to no-inset layout, exactly as before.
  }

  // Viewport size can change without an inset event (e.g. keyboard, resize).
  window.addEventListener('resize', refreshViewport)
}
