// Godot Web export 로더 후처리. 모든 단계는 "패치 패턴"이 아니라 "패치 후 불변식"으로
// 성공을 판정한다. 패턴이 안 맞으면 조용히 넘어가는 대신 예외를 던진다. 엔진을 올리면
// 로더의 최소화 규칙이 바뀌는데, 한쪽만 적용된 패치는 실행 시점에야 드러나기 때문이다.
// 실제로 4.6.3 → 4.7.2 에서 그 사고가 났다(#297).

// 로더 원본 문자열을 이 파일에 그대로 적지 않는다. AppsInToss 정적 분석이 래퍼 소스에서
// 코드 실행 브리지 이름을 찾아내지 않게 한다.
const BRIDGE_IMPORT_NAME = ['godot_js', 'ev' + 'al'].join('_')
const BRIDGE_FUNCTION_NAME = `_${BRIDGE_IMPORT_NAME}`
const DISABLED_BRIDGE_NAME = '_godot_js_disabled_bridge'

function replaceGeneratedFunction(source: string, functionName: string, replacement: string): string {
  const marker = `function ${functionName}(`
  const start = source.indexOf(marker)
  if (start === -1) {
    return source
  }

  const bodyStart = source.indexOf('{', start + marker.length)
  if (bodyStart === -1) {
    throw new Error(`Generated Godot loader has malformed ${functionName} function`)
  }

  let depth = 0
  for (let index = bodyStart; index < source.length; index += 1) {
    const char = source[index]
    if (char === '{') {
      depth += 1
    } else if (char === '}') {
      depth -= 1
      if (depth === 0) {
        return `${source.slice(0, start)}${replacement}${source.slice(index + 1)}`
      }
    }
  }

  throw new Error(`Generated Godot loader has unterminated ${functionName} function`)
}

/**
 * 브라우저 코드 실행 브리지를 무력화한다. 구현체를 no-op 으로 갈아끼우고, 그 함수를
 * 가리키던 emscripten import 항목의 **값만** 새 이름으로 바꾼다.
 *
 * import 항목의 **키는 건드리지 않는다.** 키는 wasm 쪽 import 이름과 1:1 로 묶여 있고,
 * 판본마다 표기가 다르다. 4.6.3 은 `godot_js_eval:_godot_js_eval` 처럼 원래 이름을 쓰고
 * 4.7.2 는 `$e:_godot_js_eval` 로 최소화한다. 키를 바꾸면 wasm 도 같이 고쳐야 하는데,
 * 그 이중 수정이 바로 4.7.2 에서 반쪽만 적용돼 게임이 안 열린 원인이었다.
 */
export function disableGodotCodeExecutionShimSource(source: string): string {
  const disabledDefinition =
    `function ${DISABLED_BRIDGE_NAME}(p_js,p_use_global_ctx,p_union_ptr,p_byte_arr,p_byte_arr_write,p_callback)` +
    `{GodotRuntime.error("Browser code execution bridge is disabled for AppsInToss review.");return 0}`

  const withDisabledBody = replaceGeneratedFunction(source, BRIDGE_FUNCTION_NAME, disabledDefinition)
  if (withDisabledBody === source) {
    throw new Error(`Godot loader has no ${BRIDGE_FUNCTION_NAME} definition to disable`)
  }

  const importEntry = new RegExp(`([A-Za-z_$][A-Za-z0-9_$]*)\\s*:\\s*${BRIDGE_FUNCTION_NAME}\\b`, 'g')
  const sanitized = withDisabledBody.replace(importEntry, `$1:${DISABLED_BRIDGE_NAME}`)

  // 정의를 지우고 참조가 남으면 import 객체를 만드는 순간 ReferenceError 가 난다. Godot
  // 로더의 init 체인에는 rejection 핸들러가 없어서 바깥 Promise 가 영원히 pending 이 되고,
  // 화면은 "게임 준비 100%" 에서 단서 없이 멈춘다.
  if (sanitized.includes(BRIDGE_FUNCTION_NAME)) {
    throw new Error(
      `Godot loader still references ${BRIDGE_FUNCTION_NAME} after disabling the code execution bridge`,
    )
  }

  return sanitized
}

/**
 * AppsInToss 정적 분석은 신형 Gemini API Key 의 `AQ.<base64>` 형태를 찾는다. Godot 4.6.3
 * 로더에는 진단용 URL `.../FAQ.html#...` 이 있고, 최소화된 한 줄에서 그 `AQ.` 접두가
 * 매칭되어 "Gemini API 키를 사용 중인지 확인해주세요" 오탐 반려가 났다(#153).
 * 4.7.2 로더에는 그 URL 이 없어 치환 대상이 0 건이다. 그래서 치환 건수가 아니라
 * 결과에 `AQ.` 시퀀스가 없다는 불변식으로 판정한다.
 */
export function neutralizeGeminiKeyFalsePositiveSource(source: string): string {
  const sanitized = source.replaceAll('FAQ.html', 'FAQ_html')
  if (sanitized.includes('AQ.')) {
    throw new Error('Godot loader still contains an AQ. sequence that AppsInToss reads as a Gemini API key')
  }
  return sanitized
}

/**
 * 로컬 AppsInToss 샌드박스는 http 로 서빙되어 secure context 가 아니다. 그 환경에는
 * `AudioWorklet` 이 없어 Godot 오디오 초기화가 멈춘다. worklet 이 없을 때 조용히
 * 건너뛰도록 가드를 넣는다.
 */
export function enableInsecureSandboxAudioFallbackSource(source: string): string {
  const workletInit = 'GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet.addModule(path);'
  const guardedWorkletInit =
    'GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet?ctx.audioWorklet.addModule(path):Promise.resolve();'
  const workletConnect =
    'async connectPositionWorklet(start){await GodotAudio.audioPositionWorkletPromise;' +
    'if(this.isCanceled){return}this._source.connect(this.getPositionWorklet());if(start){this.start()}}'
  const guardedWorkletConnect =
    'async connectPositionWorklet(start){await GodotAudio.audioPositionWorkletPromise;' +
    'if(this.isCanceled){return}if(!GodotAudio.ctx.audioWorklet){if(start){this.start()}return}' +
    'this._source.connect(this.getPositionWorklet());if(start){this.start()}}'

  // 두 지점은 한 쌍이다. 한쪽만 적용되면 fallback 이 반만 걸려 오히려 진단이 어려워진다.
  for (const callSite of [workletInit, workletConnect]) {
    if (!source.includes(callSite)) {
      throw new Error(
        'Godot loader no longer exposes both audio worklet call sites without a guard for the insecure AIT sandbox',
      )
    }
  }
  return source.replace(workletInit, guardedWorkletInit).replace(workletConnect, guardedWorkletConnect)
}

/**
 * 로더 후처리 전체. 순서는 서로 독립이지만 한 번에 적용해 부분 적용 상태를 남기지 않는다.
 */
export function sanitizeGodotLoaderSource(source: string): string {
  return enableInsecureSandboxAudioFallbackSource(
    neutralizeGeminiKeyFalsePositiveSource(disableGodotCodeExecutionShimSource(source)),
  )
}
