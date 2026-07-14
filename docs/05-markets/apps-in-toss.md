# AppsInToss

## App Identity

- AppsInToss appName: `foam-party` (등록 완료, 수정 불가)
- Display name(한글): 버블 버블 거품 세차 (콘솔 앱정보 등록명 = 미니앱 표기명. `granite.config.ts` `brand.displayName` / `ait/apps-in-toss-web/index.html` title과 일치해야 함)
- Display name(영문): Foam Party
- Delivery shape: Godot Web export + AppsInToss Web wrapper

## Registration

- 콘솔 입력 원본: `apps-in-toss/registration.md`
- 등록 이미지: `apps-in-toss/assets/` (로고 600×600, 썸네일 1932×828, 세로 스크린샷 636×1048 3장)
- 게임 등급분류 증빙: 필수 gate. 오픈마켓(App Store/Google Play) 출시 후 자체등급분류 정보 활용 또는 게임위 증명서 제출. 현재 미충족.

## Release

- Web export preset: `Web`
- Granite wrapper: `ait/apps-in-toss-web`
- `.ait` artifact: 생성/배포 가능. 생성 후 `npm run check:no-google-api-key` 필수
- Sandbox QA: 확정 필요
- Registration images: `apps-in-toss/assets/` 제작본, 콘솔 업로드 미진행

## Current Status

- Godot Web export preset은 GitHub Pages와 AppsInToss wrapper 후보가 공유한다.
- AIT 번들은 Google API Key/GA4 secret을 포함하지 않으며, 서버 프록시 도입 전까지 웹 애널리틱스를 비활성한다.
- `.ait` 생성 성공은 AppsInToss 콘솔 등록, 이미지, 광고, sandbox QA 완료를 의미하지 않는다.
- 게임 등급분류 증빙 전에는 앱정보 검토 요청을 완료할 수 없다.
