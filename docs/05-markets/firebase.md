# Firebase

## Current Status

- Android/iOS는 Firebase Core·Analytics 설정과 네이티브 플러그인을 포함한다.
- Android/iOS 시작 시 vendored Platform SDK `0.6.3`의
  `firebase_identity_adapter.gd`가 Platform custom token을 Firebase ID token으로
  교환하고, 그 ID token으로 `foam-party` Platform 세션을 비동기로 연다.
- 로컬 `user://seori_firebase_identity.json`에는 UID·refresh token·만료·provider만
  원자적으로 저장한다. Platform custom token과 Firebase ID token은 저장하거나
  로그에 남기지 않는다.
- 인증이나 세션이 실패해도 local-only 게임 진행은 계속된다.
- Platform registry와 custom-token bridge는 `seorilabs/platform#57`로 운영 반영됐다.
  다만 2026-08-20 현재 Firebase Auth 초기화가 되지 않아 실제
  `signInWithCustomToken`은 `CONFIGURATION_NOT_FOUND`이며, 초기화 후 Android/iOS
  실기기에서 로그인·재실행 UID 유지 확인이 남았다.
- Web/AIT는 기존 심사 번들의 no-key 정책을 유지해 이번 인증 bootstrap 대상이 아니다.
- Cloud save, Crashlytics, FCM, App Check 강제는 아직 없다.

## Future Boundary

Firebase 기능을 추가할 때 gameplay script에 SDK를 직접 섞지 않는다.

- Core에는 `AnalyticsPort`, `RemoteConfigPort`, `StoragePort`, `ClockPort`, `IdGeneratorPort` 같은 port만 둔다.
- Firebase SDK adapter는 `firebase/` 또는 platform delivery layer에 둔다.
- Security Rules, indexes, functions, service access는 version-controlled 상태로 둔다.
