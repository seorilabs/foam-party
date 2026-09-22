import { useEffect, useRef, useState } from 'react'
import splashImage from '../../../godot/assets/branding/seori-labs-boot-splash-1024.png'
import { GODOT_CONFIG, GODOT_SCRIPT_PATH, GODOT_THREADS_ENABLED } from './godotBuild'

type GodotConfig = typeof GODOT_CONFIG & {
  canvas?: HTMLCanvasElement
}

type GodotEngineInstance = {
  startGame: (override?: Partial<GodotConfig>) => Promise<void>
}

type GodotEngineConstructor = {
  new (config: GodotConfig): GodotEngineInstance
  getMissingFeatures: (features: { threads: boolean }) => string[]
}

declare global {
  interface Window {
    Engine?: GodotEngineConstructor
  }
}

// Godot 로더의 init 은 wasm 적재, 모듈 초기화, initFS 를 연쇄 then 으로만 잇고 rejection
// 핸들러를 달지 않는다. 중간에 하나라도 실패하면 startGame 의 Promise 가 영원히 pending 이
// 되어 로딩 화면이 단서 없이 멈춘다(#297). 진행률이 이만큼 멈춰 있으면 실패로 판정한다.
const BOOT_STALL_TIMEOUT_MS = 20_000

const scriptPromises = new Map<string, Promise<void>>()

function loadGodotScript(src: string) {
  const cached = scriptPromises.get(src)
  if (cached) {
    return cached
  }

  const promise = new Promise<void>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(`script[src="${src}"]`)
    if (existing?.dataset.loaded === 'true') {
      resolve()
      return
    }

    const script = existing ?? document.createElement('script')
    script.src = src
    script.async = true

    const onLoad = () => {
      script.dataset.loaded = 'true'
      resolve()
    }

    const onError = () => {
      script.remove()
      scriptPromises.delete(src)
      reject(new Error(`Failed to load Godot loader: ${src}`))
    }

    script.addEventListener('load', onLoad, { once: true })
    script.addEventListener('error', onError, { once: true })

    if (!existing) {
      document.body.appendChild(script)
    }
  })

  scriptPromises.set(src, promise)
  return promise
}

export default function GodotCanvas() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [status, setStatus] = useState('게임을 준비하고 있어요')
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false

    async function boot() {
      try {
        const canvas = canvasRef.current
        if (!canvas) {
          throw new Error('Godot canvas is not mounted')
        }

        await loadGodotScript(GODOT_SCRIPT_PATH)

        const Engine = window.Engine
        if (!Engine) {
          throw new Error('Godot Engine loader is not available')
        }

        const isLocalAppsInTossSandbox =
          import.meta.env.DEV &&
          window.location.protocol === 'http:' &&
          window.navigator.userAgent.includes('AppsInToss')
        const missingFeatures = Engine.getMissingFeatures({ threads: GODOT_THREADS_ENABLED }).filter(
          (feature) => !(isLocalAppsInTossSandbox && feature.startsWith('Secure Context')),
        )
        if (missingFeatures.length > 0) {
          throw new Error(`Missing browser features: ${missingFeatures.join(', ')}`)
        }

        setStatus('게임을 시작하고 있어요')
        const engine = new Engine({
          ...GODOT_CONFIG,
          canvas,
        })

        // 로더가 삼킨 실패를 화면에 올리기 위해 부팅 동안의 첫 오류를 잡아 둔다.
        let firstRuntimeFailure: string | null = null
        const rememberFailure = (reason: unknown) => {
          if (firstRuntimeFailure !== null) {
            return
          }
          firstRuntimeFailure = reason instanceof Error ? `${reason.name}: ${reason.message}` : String(reason)
        }
        const onWindowError = (event: ErrorEvent) => rememberFailure(event.error ?? event.message)
        const onUnhandledRejection = (event: PromiseRejectionEvent) => rememberFailure(event.reason)
        window.addEventListener('error', onWindowError)
        window.addEventListener('unhandledrejection', onUnhandledRejection)

        let stallTimer: ReturnType<typeof setTimeout> | undefined
        let failStalledBoot: () => void = () => {}
        const stalled = new Promise<never>((_resolve, reject) => {
          failStalledBoot = () =>
            reject(
              new Error(
                `게임 초기화가 응답하지 않아요: ${firstRuntimeFailure ?? '원인을 확인하지 못했습니다'}`,
              ),
            )
        })
        const armStallWatchdog = () => {
          clearTimeout(stallTimer)
          stallTimer = setTimeout(() => failStalledBoot(), BOOT_STALL_TIMEOUT_MS)
        }

        try {
          armStallWatchdog()
          await Promise.race([
            engine.startGame({
              canvas,
              onProgress: (current: number, total: number) => {
                armStallWatchdog()
                if (cancelled || total <= 0) {
                  return
                }
                setStatus(`게임 준비 ${Math.round((current / total) * 100)}%`)
              },
            } as Partial<GodotConfig>),
            stalled,
          ])
        } finally {
          clearTimeout(stallTimer)
          window.removeEventListener('error', onWindowError)
          window.removeEventListener('unhandledrejection', onUnhandledRejection)
        }

        if (!cancelled) {
          setStatus('')
        }
      } catch (bootError) {
        if (!cancelled) {
          setError(bootError instanceof Error ? bootError.message : String(bootError))
        }
      }
    }

    void boot()

    return () => {
      cancelled = true
    }
  }, [])

  return (
    <main className="godot-shell">
      <canvas ref={canvasRef} id="godot-canvas">
        Canvas is required to run Foam Party.
      </canvas>
      {(status || error) && (
        <div className={error ? 'status status-error' : 'status'}>
          <img className="status-symbol" src={splashImage} alt="서리랩스" />
          <span>{error ?? status}</span>
        </div>
      )}
    </main>
  )
}
