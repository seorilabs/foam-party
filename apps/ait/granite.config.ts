import { defineConfig } from '@apps-in-toss/web-framework/config';

// AppsInToss 웹 래퍼 설정.
// Godot Web export(정적 HTML/JS/WASM)를 감싸 `ait build`로 .ait 아티팩트를 만든다.
// 값 근거: app-store/app-store.config.json(appId=foam-party, koreanName=폼 파티),
//   godot/scripts/main.gd BAR_COL_START(#49a7ff, 물색 브랜드 액센트),
//   godot/assets/AppIcon.png(config/icon 원본 600×600).
export default defineConfig({
  appName: 'foam-party',
  brand: {
    displayName: '폼 파티',
    primaryColor: '#49a7ff', // main.gd BAR_COL_START(세차 물색 액센트)
    icon: '../../godot/assets/AppIcon.png', // Godot config/icon 원본(600×600)
  },
  web: {
    host: 'localhost',
    port: 5173,
    commands: {
      // dev/build 모두 Godot Web export를 dist/로 산출한다.
      // (Godot은 정적 빌드라 별도 dev 서버 대신 export 결과를 사용한다.)
      dev: 'npm run build:web',
      build: 'npm run build:web',
    },
  },
  permissions: [], // 진행은 기기 로컬 저장. 외부 권한 요청 없음.
  outdir: 'dist',
});
