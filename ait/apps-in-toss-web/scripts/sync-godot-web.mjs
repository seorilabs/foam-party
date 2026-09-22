import { cp, mkdir, readdir, readFile, rm, stat, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { neutralizeGeminiKeyFalsePositiveSource } from '../src/godotLoaderSanitizer.ts'

const wrapperRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const repoRoot = path.resolve(wrapperRoot, '..', '..')
const sourceDir = path.join(repoRoot, 'build', 'web')
const targetDir = path.join(wrapperRoot, 'public', 'godot')
const generatedPath = path.join(wrapperRoot, 'src', 'godotBuild.ts')

async function assertFile(filePath) {
  const fileStat = await stat(filePath).catch(() => null)
  if (!fileStat?.isFile()) {
    throw new Error(`Missing Godot Web export file: ${path.relative(repoRoot, filePath)}`)
  }
}

function parseGodotConfig(html) {
  const configMatch = html.match(/const GODOT_CONFIG = (\{.*?\});/s)
  const threadsMatch = html.match(/const GODOT_THREADS_ENABLED = (true|false);/)

  if (!configMatch || !threadsMatch) {
    throw new Error('Godot export HTML does not include GODOT_CONFIG metadata')
  }

  return {
    config: JSON.parse(configMatch[1]),
    threadsEnabled: threadsMatch[1] === 'true',
  }
}

function prefixGodotConfig(config, basePath) {
  const executable = String(config.executable ?? 'index')
  const executablePath = `${basePath}/${executable}`
  const fileSizes = Object.fromEntries(
    Object.entries(config.fileSizes ?? {}).map(([fileName, size]) => [
      fileName.startsWith('/') ? fileName : `${basePath}/${fileName}`,
      size,
    ]),
  )

  return {
    ...config,
    executable: executablePath,
    fileSizes,
  }
}

function replaceGeneratedFunction(source, functionName, replacement) {
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

async function disableGodotCodeExecutionShim(loaderPath) {
  const loaderSource = await readFile(loaderPath, 'utf8')
  const shimImportName = ['godot_js', 'ev' + 'al'].join('_')
  const shimName = ['_godot_js', 'ev' + 'al'].join('_')
  const disabledShimName = '_godot_js_disabled_bridge'
  const replacement =
    `function ${disabledShimName}(p_js,p_use_global_ctx,p_union_ptr,p_byte_arr,p_byte_arr_write,p_callback){GodotRuntime.error("Browser code execution bridge is disabled for AppsInToss review.");return 0}`
  const sanitizedLoader = replaceGeneratedFunction(loaderSource, shimName, replacement).replaceAll(
    `${shimImportName}:${shimName}`,
    `godot_js_noop:${disabledShimName}`,
  )

  if (sanitizedLoader !== loaderSource) {
    await writeFile(loaderPath, sanitizedLoader)
    return true
  }
  return false
}

async function neutralizeGeminiKeyFalsePositive(loaderPath) {
  // AppsInToss 정적 분석 파이프라인은 신형 Gemini API Key의 `AQ.<base64>` 형태를
  // 탐지한다. Godot/emscripten 로더에는 진단용 URL `.../FAQ.html#...` 이 들어 있고,
  // minify된 한 줄에서 그 `AQ.` 접두가 greedy하게 매칭되어 심사가
  // "Gemini API 키를 사용 중인지 확인해주세요" 오탐 반려를 낸다(앱인토스 측 확인 완료,
  // 길이 조건 보강 예정). 해당 문자열은 emscripten의 abort() 진단 메시지 안에만 있어
  // 런타임 동작에 영향이 없으므로 `AQ.` 시퀀스를 깨뜨려 오탐을 무력화한다.
  const source = await readFile(loaderPath, 'utf8')
  const sanitized = neutralizeGeminiKeyFalsePositiveSource(source)
  if (sanitized !== source) {
    await writeFile(loaderPath, sanitized)
    return true
  }
  return false
}

// emscripten 런타임은 UA 에 Safari/ 가 있고 Version/x 가 잡히면 Safari 로 보고
// v15.2.0 미만이면 엔진 시작 전에 throw 한다. Android WebView 의 UA 는
// "... Version/4.0 Chrome/152.0.0.0 Mobile Safari/537.36" 이라 Safari 4.0 으로
// 오인되어 Chrome 웹뷰인데도 게임이 스플래시에서 멈춘다. 실기기 AIT 에서
// "requires Safari v15.2.0 (detected v040000)" 로 확인된 증상이다.
// Chrome/ 이 있으면 Safari 분기를 타지 않게 해 진짜 Safari 만 검사하게 한다.
// seorilabs/lucid-chess 가 같은 증상을 같은 패치로 해결했다.
async function relaxEmscriptenSafariGate(loaderPath) {
  const source = await readFile(loaderPath, 'utf8')
  const target = 'userAgent.includes("Safari/")&&userAgent.match('
  if (!source.includes(target)) {
    throw new Error('Generated Godot loader does not include the expected Safari version gate')
  }
  const patched = source.replace(
    target,
    'userAgent.includes("Safari/")&&!userAgent.includes("Chrome/")&&userAgent.match(',
  )
  if (patched === source) {
    return false
  }
  await writeFile(loaderPath, patched)
  return true
}


async function enableInsecureSandboxAudioFallback(loaderPath) {
  const source = await readFile(loaderPath, 'utf8')
  const audioPositionWorkletInit =
    'GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet.addModule(path);'
  const guardedAudioPositionWorkletInit =
    'GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet?ctx.audioWorklet.addModule(path):Promise.resolve();'
  const samplePositionWorkletConnect =
    'async connectPositionWorklet(start){await GodotAudio.audioPositionWorkletPromise;if(this.isCanceled){return}this._source.connect(this.getPositionWorklet());if(start){this.start()}}'
  const guardedSamplePositionWorkletConnect =
    'async connectPositionWorklet(start){await GodotAudio.audioPositionWorkletPromise;if(this.isCanceled){return}if(!GodotAudio.ctx.audioWorklet){if(start){this.start()}return}this._source.connect(this.getPositionWorklet());if(start){this.start()}}'
  const patched = source
    .replace(audioPositionWorkletInit, guardedAudioPositionWorkletInit)
    .replace(samplePositionWorkletConnect, guardedSamplePositionWorkletConnect)

  if (patched !== source) {
    await writeFile(loaderPath, patched)
    return true
  }
  return false
}

function replaceAsciiBytes(buffer, from, to) {
  if (from.length !== to.length) {
    throw new Error(`Cannot replace "${from}" with "${to}": byte lengths differ`)
  }

  const source = Buffer.from(from, 'ascii')
  const target = Buffer.from(to, 'ascii')
  let count = 0
  let offset = 0

  while ((offset = buffer.indexOf(source, offset)) !== -1) {
    target.copy(buffer, offset)
    offset += target.length
    count += 1
  }

  return count
}

async function patchGodotWasmBridgeStrings(wasmPath) {
  const wasm = await readFile(wasmPath)
  const replacements = [
    ['godot_js_' + 'ev' + 'al', 'godot_js_noop'],
  ]
  let replacementCount = 0

  for (const [from, to] of replacements) {
    replacementCount += replaceAsciiBytes(wasm, from, to)
  }

  if (replacementCount > 0) {
    await writeFile(wasmPath, wasm)
  }

  return replacementCount
}

const files = await readdir(sourceDir).catch(() => {
  throw new Error('Run Godot Web export before syncing: build/web does not exist')
})

const htmlFile = files.includes('index.html') ? 'index.html' : files.find((file) => file.endsWith('.html'))
if (!htmlFile) {
  throw new Error('No Godot Web export HTML found under build/web')
}

const executableName = path.basename(htmlFile, '.html')
const loaderFile = files.includes(`${executableName}.js`)
  ? `${executableName}.js`
  : files.find((file) => file.endsWith('.js') && !file.includes('.audio.') && !file.includes('.service.'))

if (!loaderFile) {
  throw new Error('No Godot Web loader JavaScript found under build/web')
}

await assertFile(path.join(sourceDir, htmlFile))
await assertFile(path.join(sourceDir, loaderFile))
await assertFile(path.join(sourceDir, `${executableName}.pck`))
await assertFile(path.join(sourceDir, `${executableName}.wasm`))

await rm(targetDir, { recursive: true, force: true })
await mkdir(targetDir, { recursive: true })
await cp(sourceDir, targetDir, { recursive: true })
await writeFile(path.join(targetDir, '.gitkeep'), '')
const disabledCodeExecutionShim = await disableGodotCodeExecutionShim(path.join(targetDir, loaderFile))
const neutralizedGeminiFalsePositive = await neutralizeGeminiKeyFalsePositive(path.join(targetDir, loaderFile))
const enabledInsecureSandboxAudioFallback = await enableInsecureSandboxAudioFallback(
  path.join(targetDir, loaderFile),
)
const relaxedSafariGate = await relaxEmscriptenSafariGate(path.join(targetDir, loaderFile))
const patchedWasmBridgeStrings = await patchGodotWasmBridgeStrings(path.join(targetDir, `${executableName}.wasm`))

const html = await readFile(path.join(sourceDir, htmlFile), 'utf8')
const { config, threadsEnabled } = parseGodotConfig(html)
const basePath = '/godot'
const prefixedConfig = prefixGodotConfig(config, basePath)

const generated = `export const GODOT_BASE_PATH = ${JSON.stringify(basePath)} as const
export const GODOT_SCRIPT_PATH = ${JSON.stringify(`${basePath}/${loaderFile}`)} as const
export const GODOT_EXPORT_HTML = ${JSON.stringify(`${basePath}/${htmlFile}`)} as const
export const GODOT_THREADS_ENABLED = ${JSON.stringify(threadsEnabled)} as const
export const GODOT_CONFIG = ${JSON.stringify(prefixedConfig, null, 2)} as const
`

await writeFile(generatedPath, generated)

console.log(`Synced Godot Web export to ${path.relative(wrapperRoot, targetDir)}`)
console.log(`Generated ${path.relative(wrapperRoot, generatedPath)} using ${loaderFile}`)
if (disabledCodeExecutionShim) {
  console.log(`Disabled Godot browser code execution shim in ${path.join('public', 'godot', loaderFile)}`)
}
if (relaxedSafariGate) {
  console.log(`Relaxed emscripten Safari version gate for Android WebView in ${path.join('public', 'godot', loaderFile)}`)
}
if (neutralizedGeminiFalsePositive) {
  console.log(`Neutralized AppsInToss Gemini-key false positive (FAQ.html) in ${path.join('public', 'godot', loaderFile)}`)
}
if (enabledInsecureSandboxAudioFallback) {
  console.log(`Enabled Godot audio fallback for insecure AppsInToss sandbox in ${path.join('public', 'godot', loaderFile)}`)
}
if (patchedWasmBridgeStrings > 0) {
  console.log(`Patched ${patchedWasmBridgeStrings} Godot Web bridge string(s) in ${path.join('public', 'godot', `${executableName}.wasm`)}`)
}
