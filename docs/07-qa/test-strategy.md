# Test Strategy

## Core

- Device, network, Firebase emulator, native runtime 없이 실행되어야 한다.
- 현재는 Clean Architecture scaffold 존재 여부를 확인한다.
- 엔진 독립 규칙을 `packages/product-core`로 추출하면 순수 테스트를 추가한다.

## Architecture

- core import boundary를 확인한다.
- platform SDK import는 adapter 계층으로 제한한다.
- `npm run check:architecture`가 `packages/product-core`의 금지 import 패턴을 검사한다.
- `npm run check:platform-sdk`가 vendored SDK의 SOURCE·VERSION과 전체 GDScript
  CHECKSUM을 재계산해 드리프트를 차단한다.

## Godot

- import pass를 먼저 수행한다.
- compile check는 Godot 로그의 `SCRIPT ERROR` / `ERROR:`를 실패로 처리한다.
- smoke scene은 main scene boot, cleaning rule, combo/star/coin/save-facing helper를 확인한다.
- Platform 인증 smoke는 fake identity/client를 주입해 운영 endpoint를 호출하지 않는다.
  `sign_in` 1회, `firebase-id-token` credential, 세션 실패 시 게임 진행, 재실행 UID
  재사용, custom token·ID token 비영속화를 확인한다.
- 명령:

```bash
npm run test:godot
```

## Release

- Google Play, App Store, AppsInToss, Firebase blocker를 분리해 inventory한다.
- App Store 세부 readiness는 macOS/Godot/Xcode 환경에서 `npm run check:app-store`로 확인한다.
