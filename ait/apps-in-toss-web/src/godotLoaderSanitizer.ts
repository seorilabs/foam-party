export function neutralizeGeminiKeyFalsePositiveSource(source: string): string {
  return source.replaceAll('FAQ.html', 'FAQ_html')
}

// emscripten 런타임은 UA 에 Safari/ 가 있고 Version/x 가 잡히면 Safari 로 보고
// v15.2.0 미만이면 엔진 시작 전에 throw 한다. Android WebView 의 UA 는
// "... Version/4.0 Chrome/152.0.0.0 Mobile Safari/537.36" 이라 Safari 4.0 으로
// 오인되어 Chrome 웹뷰인데도 게임이 스플래시에서 멈춘다.
// Chrome/ 이 있으면 Safari 분기를 타지 않게 해 진짜 Safari 만 검사하게 한다.
// scripts/sync-godot-web.mjs 의 relaxEmscriptenSafariGate 와 같은 치환이다.
export const EMSCRIPTEN_SAFARI_GATE = 'userAgent.includes("Safari/")&&userAgent.match('

export function relaxEmscriptenSafariGateSource(loaderSource: string): string {
  return loaderSource.replace(
    EMSCRIPTEN_SAFARI_GATE,
    'userAgent.includes("Safari/")&&!userAgent.includes("Chrome/")&&userAgent.match(',
  )
}
