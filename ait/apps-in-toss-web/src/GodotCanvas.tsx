import { useEffect, useRef, useState } from 'react'
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
  const [status, setStatus] = useState('Loading...')
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

        setStatus('Starting...')
        const engine = new Engine({
          ...GODOT_CONFIG,
          canvas,
        })

        await engine.startGame({
          canvas,
          onProgress: (current: number, total: number) => {
            if (cancelled || total <= 0) {
              return
            }
            setStatus(`Loading ${Math.round((current / total) * 100)}%`)
          },
        } as Partial<GodotConfig>)

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
        <div className={error ? 'status status-error' : 'status'}>{error ?? status}</div>
      )}
    </main>
  )
}
