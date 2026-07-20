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
- Poing AdMob v4.3.1 Android plugin은 repo에 번들되어 있다. 기본값은 Google 테스트 ID이며 `tools/build_admob_plugin.sh`가 x64 Google Play build에서 repo/environment 변수로 production ID를 주입한다.
- `game_over`와 `level_reward_2x` production unit ID, 실제 기기 광고/GA4 이벤트 확인 전에는 새 광고 빌드를 production으로 승격하지 않는다.
- 2026-07-21 로컬 debug AAB export에서 테스트 app ID, Poing AdMob singleton metadata, Google Mobile Ads/리워드/전면 구현을 bundle manifest와 DEX로 확인했다. 연결된 Android 기기가 없어 실노출 QA는 남았다.

## Production Promotion Procedure

1. Play Console `Account Details`에서 한국 법률상 추가 정보를 완료한다. 동일한 403 응답이 남아 있으면 업로드나 production 승격을 재시도하지 않는다.
2. 배포 승인을 받은 정확한 `vX.Y.Z` 태그와 release notes를 확인한다.
3. 필요하면 `Deploy Google Play` workflow를 `upload=false`로 실행해 x64 Linux AAB 빌드만 먼저 검증한다.
4. GitHub Actions의 `Deploy All`을 실행하고 `deploy_google_play=true`, `google_play_track=production`, `google_play_release_status=completed`를 선택한다. 기본값은 기존 동작과 같은 `internal`/`completed`다.
5. 성공 후 Android Publisher API 또는 Play Console에서 production track의 versionName, versionCode, status를 직접 확인한다. 태그나 workflow 성공만으로 공개 버전을 추정하지 않는다.

production dispatch 입력은 저장소의 배포 경로만 연다. Play Console 계정 요건 해소와 각 production 배포 승인은 별도 필수 gate다.
