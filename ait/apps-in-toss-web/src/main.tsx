import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { installFoamPartyFirebaseBridge } from './firebaseRuntime.ts'
import { installFoamPartyTossFullScreenAdBridge } from './tossFullScreenAdRuntime.ts'
import { installFoamPartySafeAreaBridge } from './safeAreaRuntime.ts'
import { installFoamPartyGraniteNavBridge } from './graniteNavRuntime.ts'
import { installFoamPartyScreenWakeBridge } from './screenWakeRuntime.ts'

installFoamPartySafeAreaBridge()
installFoamPartyScreenWakeBridge()
installFoamPartyGraniteNavBridge()
installFoamPartyFirebaseBridge()
installFoamPartyTossFullScreenAdBridge()

createRoot(document.getElementById('root')!).render(<App />)
