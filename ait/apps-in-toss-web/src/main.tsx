import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { installFoamPartyFirebaseBridge } from './firebaseRuntime.ts'
import { installFoamPartyTossFullScreenAdBridge } from './tossFullScreenAdRuntime.ts'
import { installFoamPartySafeAreaBridge } from './safeAreaRuntime.ts'

installFoamPartySafeAreaBridge()
installFoamPartyFirebaseBridge()
installFoamPartyTossFullScreenAdBridge()

createRoot(document.getElementById('root')!).render(<App />)
