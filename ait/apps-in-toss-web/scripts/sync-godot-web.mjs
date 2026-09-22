import { cp, mkdir, readdir, readFile, rm, stat, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { sanitizeGodotLoaderSource } from '../src/godotLoaderSanitizer.ts'

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
// wasm 은 건드리지 않는다. 로더가 emscripten import 항목의 키를 그대로 두므로 wasm 쪽
// import 이름과 계속 일치한다. 예전에는 양쪽 이름을 함께 바꿨는데, 4.7.2 에서 로더의
// 키가 최소화되면서 그 이중 수정이 반쪽만 적용돼 게임이 열리지 않았다(#297).
const loaderPath = path.join(targetDir, loaderFile)
await writeFile(loaderPath, sanitizeGodotLoaderSource(await readFile(loaderPath, 'utf8')))

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
console.log(`Sanitized Godot Web loader ${path.join('public', 'godot', loaderFile)}`)
