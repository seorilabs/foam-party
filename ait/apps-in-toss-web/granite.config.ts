import { defineConfig } from '@apps-in-toss/web-framework/config'

export default defineConfig({
  appName: 'foam-party',
  brand: {
    displayName: '폼 파티',
    primaryColor: '#81c5c3',
    // AIT 콘솔 로고 업로드 후 발급된 static.toss.im HTTPS URL.
    icon: 'https://static.toss.im/appsintoss/38345/ec558824-cda2-4308-ad78-e2ab45571a15.png',
    bridgeColorMode: 'basic',
  },
  web: {
    host: 'localhost',
    port: 5173,
    commands: {
      dev: 'vite --host 0.0.0.0',
      build: 'npm run build:web',
    },
  },
  permissions: [],
  outdir: 'dist',
  webViewProps: {
    type: 'game',
    overScrollMode: 'never',
  },
})
