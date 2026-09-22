import { describe, expect, it } from 'vitest'

import {
  disableGodotCodeExecutionShimSource,
  enableInsecureSandboxAudioFallbackSource,
  neutralizeGeminiKeyFalsePositiveSource,
} from './godotLoaderSanitizer.ts'

// 스캐너가 래퍼 소스에서 브리지 이름을 찾지 않도록 로더와 같은 방식으로 조립한다.
const BRIDGE = `_${['godot_js', 'ev' + 'al'].join('_')}`

function loaderWith(importKey: string) {
  return [
    `function ${BRIDGE}(p_js,p_use_global_ctx,p_union_ptr,p_byte_arr,p_byte_arr_write,p_callback)`,
    `{const js=GodotRuntime.parseString(p_js);const ret=(0,${['ev', 'al'].join('')})(js);return 0}`,
    `var wasmImports={godot_js_display_alert:_godot_js_display_alert,${importKey}:${BRIDGE},`,
    'godot_js_fetch_create:_godot_js_fetch_create};',
  ].join('')
}

describe('disableGodotCodeExecutionShimSource', () => {
  // Godot 4.7.2 는 emscripten import 키를 최소화한다. 4.6.3 은 원래 이름을 쓴다.
  it.each([
    ['minified import key (Godot 4.7.2)', '$e'],
    ['verbatim import key (Godot 4.6.3)', ['godot_js', 'ev' + 'al'].join('_')],
  ])('rewires the %s to the disabled bridge', (_label, importKey) => {
    const sanitized = disableGodotCodeExecutionShimSource(loaderWith(importKey))

    expect(sanitized).toContain(`${importKey}:_godot_js_disabled_bridge`)
    expect(sanitized).toContain('function _godot_js_disabled_bridge(')
    // 정의가 사라진 이름을 import 항목이 계속 가리키면 실행 시 ReferenceError 가 난다.
    expect(sanitized).not.toContain(BRIDGE)
  })

  it('keeps the import key so it still matches the wasm import name', () => {
    const sanitized = disableGodotCodeExecutionShimSource(loaderWith('$e'))

    expect(sanitized).toContain('$e:')
    expect(sanitized).toContain('godot_js_display_alert:_godot_js_display_alert')
  })

  it('fails when the loader has no bridge definition to disable', () => {
    expect(() => disableGodotCodeExecutionShimSource('var wasmImports={};')).toThrow(
      /no .* definition to disable/,
    )
  })

  it('fails when an import entry would be left pointing at the removed definition', () => {
    // 키를 못 잡는 형태를 만들어 참조가 남는 상황을 재현한다.
    const loader = `${loaderWith('$e')}var alias=[${BRIDGE}];`

    expect(() => disableGodotCodeExecutionShimSource(loader)).toThrow(/still references/)
  })
})

describe('neutralizeGeminiKeyFalsePositiveSource', () => {
  it('removes every FAQ.html sequence that can trigger the AQ key scanner', () => {
    const loaderSource = [
      'See https://emscripten.org/docs/porting/Debugging.html#FAQ.html#abort',
      'fallback=/FAQ.html#missing-feature',
    ].join('\n')

    const sanitized = neutralizeGeminiKeyFalsePositiveSource(loaderSource)

    expect(sanitized).not.toContain('AQ.')
    expect(sanitized).toContain('FAQ_html#abort')
    expect(sanitized).toContain('FAQ_html#missing-feature')
  })

  it('accepts a loader that never had the diagnostic URL (Godot 4.7.2)', () => {
    expect(neutralizeGeminiKeyFalsePositiveSource('var a=1;')).toBe('var a=1;')
  })

  it('fails when an AQ. sequence survives', () => {
    expect(() => neutralizeGeminiKeyFalsePositiveSource('const k="AQ.abcdef"')).toThrow(/Gemini API key/)
  })
})

describe('enableInsecureSandboxAudioFallbackSource', () => {
  const workletInit = 'GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet.addModule(path);'
  const workletConnect =
    'async connectPositionWorklet(start){await GodotAudio.audioPositionWorkletPromise;' +
    'if(this.isCanceled){return}this._source.connect(this.getPositionWorklet());if(start){this.start()}}'

  it('guards both audio worklet call sites', () => {
    const sanitized = enableInsecureSandboxAudioFallbackSource(`${workletInit}${workletConnect}`)

    expect(sanitized).toContain('ctx.audioWorklet?ctx.audioWorklet.addModule(path)')
    expect(sanitized).toContain('if(!GodotAudio.ctx.audioWorklet)')
    expect(sanitized).not.toContain(workletInit)
  })

  it('fails when only one call site matches', () => {
    expect(() => enableInsecureSandboxAudioFallbackSource(workletInit)).toThrow(/without a guard/)
  })
})
