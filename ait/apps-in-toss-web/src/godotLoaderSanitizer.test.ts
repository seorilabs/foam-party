import { describe, expect, it } from 'vitest'

import {
  EMSCRIPTEN_SAFARI_GATE,
  neutralizeGeminiKeyFalsePositiveSource,
  relaxEmscriptenSafariGateSource,
} from './godotLoaderSanitizer.ts'

describe('neutralizeGeminiKeyFalsePositiveSource', () => {
  it('removes every FAQ.html sequence that can trigger the AQ key scanner', () => {
    const loaderSource = [
      'See https://emscripten.org/docs/porting/Debugging.html#FAQ.html#abort',
      'fallback=/FAQ.html#missing-feature',
    ].join('\n')

    const sanitized = neutralizeGeminiKeyFalsePositiveSource(loaderSource)

    expect(sanitized).not.toContain('AQ.html')
    expect(sanitized).not.toContain('FAQ.html')
    expect(sanitized).toContain('FAQ_html#abort')
    expect(sanitized).toContain('FAQ_html#missing-feature')
  })
})

describe('relaxEmscriptenSafariGateSource', () => {
  it('skips the Safari version gate on Chrome-based WebViews', () => {
    const loaderSource =
      'var currentSafariVersion=userAgent.includes("Safari/")&&userAgent.match(/Version\\/(\\d+)/)'

    const patched = relaxEmscriptenSafariGateSource(loaderSource)

    expect(patched).toContain('!userAgent.includes("Chrome/")')
    // 진짜 Safari 는 Chrome/ 이 없으므로 기존대로 버전 검사를 받는다.
    expect(patched).toContain('userAgent.match(/Version\\/(\\d+)/)')
  })

  it('exposes the gate marker so the sync script can fail loudly when Godot changes it', () => {
    expect(EMSCRIPTEN_SAFARI_GATE).toContain('Safari/')
  })
})
