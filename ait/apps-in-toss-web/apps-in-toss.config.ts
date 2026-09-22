import { defineConfig } from '@apps-in-toss/web-framework/config'

export default defineConfig({
  appName: 'foam-party',

  brand: {
    primaryColor: '#81c5c3'
  },

  permissions: [],
  webBundleDir: 'dist',

  webView: {
    // 게임 웹뷰 모드. 2.x 의 webViewProps.type 에 있던 키인데 ait migrate v3 가
    // 떨어뜨렸고, 그 뒤 AIT 웹뷰에서 Godot wasm 이 instantiate 되지 않아 스플래시에서
    // 멈춘다. 3.5.0 설정 타입에는 없지만 CLI 가 bundle.json 에 그대로 직렬화해
    // 플랫폼까지 값이 전달된다. seorilabs/lucid-chess 가 같은 증상을 같은 키로 해결했다.
    type: 'game',
    overScrollMode: 'never'
  }
})
