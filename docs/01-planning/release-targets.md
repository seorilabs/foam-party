# Release Targets

## Google Play

- Android package name: `com.seorilabs.foamparty`
- Firebase Android app: `1:72898706664:android:456c2bdc38879e37bc5d5d`
- Release track: production
- Current public release: `0.1.0` / versionCode `2`
- Target release: `1.0.0` / versionCode `1000000`; Play bundle과 internal upload 완료, production draft 생성 상태.
- Current blocker: 한국 개발자 계정의 Play Console `Account Details` 추가 정보 미입력으로 production commit이 403 거부됨.
- Release automation: `Deploy All`은 `internal`/`completed`를 기본값으로 유지하며, 승인된 배포에서는 `production`/`completed`를 명시적으로 선택할 수 있다.

## Apple App Store

- iOS bundle ID: `com.seorilabs.foamparty`
- Apple Developer Team: `HCDUXX4Z3X`
- Primary locale: `en-US`
- Availability: worldwide
- TestFlight target: 확정 필요
- Current status: iOS export preset, App Store config, local project-only/unsigned build path 있음. provisioning profile, screenshots, App Store Connect 수동 gate는 남아 있음.

## AppsInToss

- AppsInToss appName: 확정 필요
- Delivery shape: Godot Web export wrapper 후보
- Godot Web preset: `Web`
- Sandbox QA status: 확정 필요
- Current status: 미구현.

## Firebase

- Firebase project ID: 확정 필요
- Current status: MVP에는 포함하지 않음.
