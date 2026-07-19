# Work Log

## 2026-07-19

- HUD 사운드/도움말 버튼이 터치에서 동작하지 않던 원인을 수정했다. z-index 충돌이 아니라 하나의 탭이 `InputEventScreenTouch`와 에뮬레이션된 `InputEventMouseButton`으로 연속 전달되어 토글이 두 번 실행되던 문제였으며, 프로젝트의 포인터 에뮬레이션 비활성화와 `DEVICE_ID_EMULATION` 입력 차단을 함께 적용하고 smoke 회귀 테스트를 추가했다.
- 상단 HUD를 정리해 별점·손님 만족도·오늘의 미션을 동일 높이의 한 행으로 묶고, 사운드·도움말은 상태 카드 안의 작은 보조 버튼으로 이동했다. 보이는 버튼은 24px로 줄였지만 실기기 터치 영역은 44px로 유지하고 서로 겹치지 않도록 회귀 테스트로 고정했다.

## 2026-07-18

- 스펀지 전용 오물로 보이던 줄무늬 사각 `sticker`를 실제 세차 흐름에 맞는 `road_grime`(도로 때)으로 교체했다. 도로 때는 불규칙한 반투명 회갈색 얼룩으로 그리며, 마른 상태에서 바로 문지르지 않고 고압수 또는 비누로 불린 뒤 스펀지로 제거한다.

## 2026-07-14

- AIT 반려 사유 2건 해결.
- **미니앱 표기명 불일치**: 콘솔 앱정보 등록명은 `버블 버블 거품 세차`인데 미니앱 표기명이 `폼 파티`였다. `ait/apps-in-toss-web/granite.config.ts`(`brand.displayName`), `ait/apps-in-toss-web/index.html`(title), `apps-in-toss/apps-in-toss.config.json`, `apps-in-toss/registration.md`, `docs/05-markets/apps-in-toss.md`의 한글 표기명을 등록명으로 정정했다. `appName`(`foam-party`)은 내부 식별자라 변경 없음.
- **Gemini API 키 사용 확인**: 런타임 클라이언트/서버 어디에도 Gemini API 키 사용 없음. Gemini(`gemini-3-pro-image`) 참조는 디자인 타임 에셋 생성 provenance 파일(`godot/assets/art/asset-manifest.json`, `icon-manifest.json`)에만 존재하며 런타임 코드(`.gd`)가 읽지 않는다. `export_filter=all_resources`로 이 매니페스트가 배포 번들에 포함돼 심사자가 런타임 Gemini 호출로 오인한 것으로 보고, iOS/Web/Android export preset의 `exclude_filter`에 두 매니페스트와 `assets/art/style/**`를 추가해 번들에서 제외했다. 저장소 원본과 에셋 재생성 경로는 영향 없음.
- **AIT API Key 기계 탐지 대응**: 심사 산출물에 Firebase Web 공개 설정인 `AIza...` 키가 포함되어 Gemini 키로 기계 탐지될 수 있음을 확인했다. AIT에서 Firebase Web SDK/Remote Config/API Key를 제거하고 애널리틱스는 기존 GA4 Measurement Protocol 경로만 사용하도록 변경했다. 빌드 후 `.ait` 내 `AIza`, Generative Language, Firebase AI, Gemini 모델 마커를 검사하는 gate를 추가했다.
- **AIT 클라이언트 secret 완전 제거**: API Key 제거 후에도 심사가 반복 반려해 `.ait` 전체를 재조사한 결과 GA4 Measurement Protocol `api_secret`이 Web JS에 포함된 것을 확인했다. AIT 애널리틱스 전송을 비활성하고 secret/측정 ID 환경변수 참조를 제거했으며, 산출물 gate에 `api_secret`과 `VITE_GA4_MP_API_SECRET`를 추가했다.

## 2026-06-16

- `seorilabs/starter-template-game`에서 docs 원장, Clean Architecture scaffold, GitHub Actions 검사 구성을 Foam Party에 맞게 병합했다.
- `Deploy Godot Web Pages` 구조를 추가하고 Godot `Web` export preset을 생성했다.
- GitHub Pages source를 Actions workflow로 활성화했다. URL: `https://seorilabs.github.io/foam-party/`
- Release blocker는 `npm run check:release`에서 inventory로 확인한다.
