import { describe, expect, it } from 'vitest'

import config from '../apps-in-toss.config'

describe('apps-in-toss.config', () => {
  it('keeps the game webview mode that ait migrate v3 drops', () => {
    // 2.x 의 webViewProps.type 에 있던 키다. ait migrate v3 가 떨어뜨리면 AIT 웹뷰에서
    // Godot wasm 이 instantiate 되지 않아 스플래시에서 멈춘다. 3.5.0 설정 타입에는
    // 없지만 CLI 가 bundle.json 의 config.webView 에 그대로 직렬화한다.
    const webView = config.webView as Record<string, unknown> | undefined
    expect(webView?.type).toBe('game')
  })

  it('keeps the app name and bundle dir the deploy pipeline expects', () => {
    expect(config.appName).toBe('foam-party')
    expect(config.webBundleDir).toBe('dist')
  })
})
