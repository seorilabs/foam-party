# Work Log

## 2026-07-14

- AIT 반려 사유 2건 해결.
- **미니앱 표기명 불일치**: 콘솔 앱정보 등록명은 `버블 버블 거품 세차`인데 미니앱 표기명이 `폼 파티`였다. `ait/apps-in-toss-web/granite.config.ts`(`brand.displayName`), `ait/apps-in-toss-web/index.html`(title), `apps-in-toss/apps-in-toss.config.json`, `apps-in-toss/registration.md`, `docs/05-markets/apps-in-toss.md`의 한글 표기명을 등록명으로 정정했다. `appName`(`foam-party`)은 내부 식별자라 변경 없음.
- **Gemini API 키 사용 확인**: 런타임 클라이언트/서버 어디에도 Gemini API 키 사용 없음. Gemini(`gemini-3-pro-image`) 참조는 디자인 타임 에셋 생성 provenance 파일(`godot/assets/art/asset-manifest.json`, `icon-manifest.json`)에만 존재하며 런타임 코드(`.gd`)가 읽지 않는다. `export_filter=all_resources`로 이 매니페스트가 배포 번들에 포함돼 심사자가 런타임 Gemini 호출로 오인한 것으로 보고, iOS/Web/Android export preset의 `exclude_filter`에 두 매니페스트와 `assets/art/style/**`를 추가해 번들에서 제외했다. 저장소 원본과 에셋 재생성 경로는 영향 없음.
- **AIT API Key 기계 탐지 대응**: 심사 산출물에 Firebase Web 공개 설정인 `AIza...` 키가 포함되어 Gemini 키로 기계 탐지될 수 있음을 확인했다. AIT에서 Firebase Web SDK/Remote Config/API Key를 제거하고 애널리틱스는 기존 GA4 Measurement Protocol 경로만 사용하도록 변경했다. 빌드 후 `.ait` 내 `AIza`, Generative Language, Firebase AI, Gemini 모델 마커를 검사하는 gate를 추가했다.

## 2026-06-16

- `seorilabs/starter-template-game`에서 docs 원장, Clean Architecture scaffold, GitHub Actions 검사 구성을 Foam Party에 맞게 병합했다.
- `Deploy Godot Web Pages` 구조를 추가하고 Godot `Web` export preset을 생성했다.
- GitHub Pages source를 Actions workflow로 활성화했다. URL: `https://seorilabs.github.io/foam-party/`
- Release blocker는 `npm run check:release`에서 inventory로 확인한다.
