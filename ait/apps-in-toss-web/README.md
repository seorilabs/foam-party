# 폼 파티 AppsInToss AIT 래퍼

Godot Web export를 AppsInToss WebView에서 직접 로드하는 래퍼입니다. iframe을 쓰지 않고 Godot가 생성한 `index.js` 런타임을 React 컴포넌트(`GodotCanvas`)에서 canvas에 붙입니다.

Godot 프로젝트는 저장소 루트가 아니라 `godot/` 하위에 있습니다.

## 1. Godot에서 직접 테스트

먼저 Godot 에디터에서 게임을 실행해 조작감, 상단 여백, 터치 입력을 확인합니다. 코드 변경 뒤에는 smoke test도 실행합니다.

```bash
godot --headless --path godot --script tests/smoke_scene.gd
godot --headless --path godot --quit-after 1
```

## 2. Godot Web export 생성

Web export는 저장소 루트의 `scripts/export_godot_web.sh`로 만듭니다. AIT 래퍼는 `build/web` 산출물을 사용하므로 출력 경로를 맞춰 실행합니다.

```bash
GODOT_WEB_OUTPUT_DIR=build/web scripts/export_godot_web.sh
```

## 3. AIT 래퍼 로컬 실행

```bash
cd ait/apps-in-toss-web
npm install
npm run dev
```

`npm run dev`는 `sync:godot`을 먼저 실행해 `build/web` 산출물을 `public/godot`으로 복사하고 `src/godotBuild.ts` 메타데이터를 재생성한 뒤 Granite 개발 서버를 엽니다.

## 4. AIT 빌드

```bash
npm run sync:godot
npm run build:web
npm run build
```

성공하면 `foam-party.ait`가 생성됩니다. 이 산출물 생성은 기술 패키징 확인이며, AppsInToss 출시 검수·게임 등급분류가 완료됐다는 뜻은 아닙니다.

## Firebase / 광고 브리지

- 이 래퍼는 `window.__foamPartyFirebase`(Analytics/Remote Config)와 `window.__foamPartyAds`(전면 광고) JS bridge를 설치합니다.
- **현재 폼 파티 Godot 빌드는 Web에서 이 JS bridge를 호출하지 않습니다.** Godot 쪽 Firebase는 Android 네이티브 플러그인 싱글턴(`GodotxFirebaseCore` 등) 경로만 사용합니다. 따라서 Web/AIT에서 이 bridge는 설치만 되고 소비되지 않는 상태이며, Web 분석·광고 연동은 후속 작업입니다.
- Firebase Web 환경변수(`VITE_FIREBASE_*`)가 없으면 bridge는 no-op으로 동작하고 AIT 빌드는 계속 가능합니다.

## GitHub Actions

저장소 루트 `.github/workflows/deploy-apps-in-toss.yml`이 org 재사용 워크플로우 `seorilabs/.github/.github/workflows/godot-deploy-ait.yml`을 호출합니다. 흐름:

1. Godot와 Web export template 설치
2. Godot 프로젝트 import (`godot/`)
3. smoke test 실행 (지정 시)
4. `scripts/export_godot_web.sh`로 Web export 생성 → `build/web`
5. `ait/apps-in-toss-web`에서 `npm ci`, `npm run lint`, `npm run build`
6. AppsInToss 배포 (`npm run deploy`)

배포에는 org secret `APPS_IN_TOSS_API_KEY`가 필요합니다.
