# Firebase

## Current Status

- MVP에는 Firebase가 포함되어 있지 않다.
- 현재 소스 기준 계정, cloud save, Remote Config, Analytics, Crashlytics, FCM, App Check는 없다.

## Future Boundary

Firebase를 도입하면 gameplay script에 SDK를 직접 섞지 않는다.

- Core에는 `AnalyticsPort`, `RemoteConfigPort`, `StoragePort`, `ClockPort`, `IdGeneratorPort` 같은 port만 둔다.
- Firebase SDK adapter는 `firebase/` 또는 platform delivery layer에 둔다.
- Security Rules, indexes, functions, service access는 version-controlled 상태로 둔다.
