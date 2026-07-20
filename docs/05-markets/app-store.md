# Apple App Store

## App Identity

- App name: `Foam Party`
- SKU: `foam-party`
- Bundle ID: `com.seorilabs.foamparty`
- Primary locale: `en-US`
- Availability: worldwide
- Category: Games / Casual 후보
- Support email: `cs@seorilabs.com`
- Support URL: 확정 필요
- Privacy Policy URL: 확정 필요

## Release

- Godot preset: `iOS`
- Marketing version: `0.1.0`
- Build number: `1`
- Team ID: `HCDUXX4Z3X`
- Target device: iPhone only
- Provisioning profile: 확정 필요
- TestFlight upload: 미진행

## Privacy / Review

- Current source privacy candidate: AdMob 및 Firebase Analytics 데이터 수집 항목 재작성 필요.
- Tracking / ATT: 아니오 후보. ATT 비활성, AdMob 요청은 `npa=1` 기본값.
- Consent: EEA/UK용 AdMob privacy message와 UMP 흐름 확정 필요.
- Age rating: 광고 포함 기준으로 다음 버전 재확정 필요.
- Export compliance: `ITSAppUsesNonExemptEncryption=false` 후보.
- DSA trader status: 확정 필요.

위 답변은 현재 소스 기준 후보이며 App Store Connect 실제 입력 전까지 완료로 보지 않는다.

## Assets

- App Store icon: `app-store/assets/icon-1024.png`
- Screenshot set: 확정 필요

## Sources

- Config source: `app-store/app-store.config.json`
- Registration notes: `docs/app-store-registration.md`
- Build/release notes: `docs/app-store-release.md`
- Readiness command: `npm run check:app-store`
