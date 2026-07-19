# Google Play

## App Identity

- App name: `Foam Party` (`en-US`), `폼 파티` (`ko-KR` 준비)
- Package name: `com.seorilabs.foamparty`
- Category: Games / Casual
- Support email: `cs@seorilabs.com`
- Privacy Policy URL: `https://www.seorilabs.com/privacy/`

## Store Listing

- Default language: `en-US`
- Existing listing: `en-US`
- Pending localization: `ko-KR`
- Korean title: `폼 파티`
- Korean description and `1.0.0` release notes are stored in `play-store/google-play.config.json`.
- Existing Play images were verified by API hash and restored to the repo-local source of truth.

## Production Release

- Current public release: `0.1.0` / versionCode `2` / `completed`
- Target release: `1.0.0` / versionCode `1000000`
- Source: tag `v1.0.0` / commit `0e22fa23cb0b3c13396df5c29cb9e4899122dff6`
- Play bundle SHA-256: `0b8a5469c23efe4b87c2dfaf39d30ee2c6b822438636a537d59b282316aae296`
- Internal track: `1.0.0` / versionCode `1000000` / `completed`
- Production track: `1.0.0` / versionCode `1000000` / `draft`
- Intended rollout: production `completed` with `en-US` and `ko-KR` release notes

## Current Status

- 2026-07-18 Android Publisher API readback으로 bundle, internal/production track, listing language를 확인했다.
- `ko-KR` listing과 production 완료 커밋은 아직 적용되지 않았다.
- Blocker: 한국 개발자 계정의 Play Console `Account Details` 추가 정보가 미입력되어 모든 edit commit이 403으로 거부된다.
- 사업자 계정은 최소 business contact address와 contact telephone number를 Play Console에서 확정해야 한다. 유료 앱/IAP가 있으면 사업자등록번호, 통신판매업 신고번호, 신고기관도 필요하다.
- Android AAB/APK release build는 Seorilabs RPI ARC runner로 보내지 않는다.
