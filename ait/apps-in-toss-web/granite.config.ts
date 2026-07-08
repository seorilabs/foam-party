import { defineConfig } from '@apps-in-toss/web-framework/config'

export default defineConfig({
  appName: 'foam-party',
  brand: {
    displayName: '폼 파티',
    primaryColor: '#81c5c3',
    // TODO(등록): 콘솔에 로고 업로드 후 발급되는 static.toss.im HTTPS URL로 교체.
    // 등록 전이라 확정 아이콘 URL 없음 → 배포 전 반드시 실제 URL로 변경.
    icon: 'https://static.toss.im/appsintoss/placeholder-foam-party.png',
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
