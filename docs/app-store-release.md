# App Store Release

폼 파티의 Apple App Store 빌드 기준 문서다. 현재 배포 정본은 GitHub Actions `Deploy to App Store`(org `godot-deploy-app-store.yml`, `macos-26`)이며 로컬 Xcode archive/export는 검증·복구 경로다. 1.3.16/build 25까지는 Xcode Cloud로 빌드했고 이후 Actions로 이관했다.

## 현재 심사 상태

| 항목 | 값 |
| --- | --- |
| Version / build | `1.3.16 (25)` |
| Source | `v1.3.16` / `7e8e96ff52b6fb89cfe029a631648d2aa659dc5b` |
| Build | Xcode Cloud `Release` run 25, `VALID`, `APP_STORE_ELIGIBLE` |
| Review submission | `94a206fe-cdbc-4355-9e6d-0bb6a3a849fa` |
| State | `WAITING_FOR_REVIEW` — 2026-08-21T00:46:05.358Z |
| Release type | `MANUAL` — 승인 후 별도 공개 필요 |

App Privacy에는 기존 광고·분석 유형과 함께 Firebase `User ID`를 `App Functionality`, 사용자 연결 있음, 추적 없음으로 게시했다.

## 빌드 기준

| 항목 | 값 | 상태 |
| --- | --- | --- |
| Godot preset | `iOS` | 생성됨 |
| Bundle ID | `com.seorilabs.foamparty` | App Store Connect 확정 |
| Team ID | `HCDUXX4Z3X` | 로컬 Apple Distribution 인증서에서 확인 |
| Marketing version | `1.3.16` | App Store version 기준 |
| Build number | `25` | Xcode Cloud / App Store Connect 기준 |
| Export method | `app-store-connect` | script export 기준 |
| Target device | iPhone only | iPad screenshot/icon gate를 피하기 위한 초기값 |
| Primary locale | `en-US` | 초기 전세계 출시 기준 |
| Availability | Worldwide | 초기 출시 기준 |
| App Store icon | `app-store/assets/icon-1024.png` | 생성됨, 1024x1024, alpha 없음 |

## 로컬 빌드

Xcode project만 다시 만들 때:

```bash
tools/build_ios_app_store.sh --project-only
```

서명 없이 Release compile 경로를 확인할 때:

```bash
tools/build_ios_app_store.sh --unsigned-build
```

서명된 App Store archive/export에는 App Store provisioning profile 이름 또는 UUID가 필요하다.

```bash
export FOAM_PARTY_IOS_PROFILE_SPECIFIER="<App Store provisioning profile name or uuid>"
tools/build_ios_app_store.sh
```

Bundle ID, Team ID, signing identity, target device family가 App Store Connect/App ID 확정값과 달라지면 환경 변수로 명시해 단일 빌드에서 덮어쓴다.

```bash
export FOAM_PARTY_IOS_BUNDLE_ID="com.seorilabs.foamparty"
export FOAM_PARTY_IOS_TEAM_ID="HCDUXX4Z3X"
export FOAM_PARTY_IOS_SIGNING_IDENTITY="Apple Distribution: Seori Labs (HCDUXX4Z3X)"
export FOAM_PARTY_IOS_TARGETED_DEVICE_FAMILY="1"
```

AdMob app/unit ID도 같은 빌드에서 주입한다. 미설정 값은 Google 공식 테스트 ID로 남으므로 production 제출 전에 모두 지정해야 한다.

```bash
export ADMOB_IOS_APP_ID="ca-app-pub-9932778305312246~7227831828"
export ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID="ca-app-pub-9932778305312246/1584622900"
export ADMOB_IOS_FOAM_BOMB_REWARDED_AD_UNIT_ID="ca-app-pub-9932778305312246/3266379398"
export ADMOB_IOS_LEVEL_REWARD_REWARDED_AD_UNIT_ID="ca-app-pub-9932778305312246/3883483180"
export ADMOB_REQUIRE_PRODUCTION="1"
```

위 값은 로컬 빌드용 override다. CI 정본은 `app-store/app-store.config.json`의 `adMob` 절이고, `Deploy to App Store`가 export 전에 `tools/prepare_ios_native_ads.sh`로 같은 값을 주입한다. 광고 단위 형식은 `game_over=전면 광고`, `foam_bomb_free/level_reward_2x=보상형`으로 AdMob 콘솔에서 확인했다. `보상형 전면`으로 만든 유닛은 `RewardedAdLoader`가 로드하지 못하므로 설정 스크립트가 거부한다.

Godot iOS export는 `build/ios/foam-party.xcodeproj`와 AdMob용 local `Package.swift`를 만든다. 스크립트는 headless export에서 누락될 수 있는 Swift Package project reference를 idempotent하게 보정한 뒤 `build/ios/foam-party.xcarchive`와 `.ipa` export를 이어서 만든다.

## 현재 제한

- App Privacy, age rating, review notes는 1.3.16 심사 제출 기준으로 확정했다.
- iOS는 ATT를 활성화하지 않고 광고 요청에 `npa=1`을 기본 적용한다. Worldwide의 EEA/UK 배포 전 AdMob privacy message와 UMP 동의 흐름을 구성한다.
- 실제 iPhone 광고 load/impression/dismiss/earned 및 GA4 이벤트를 확인한다. 운영 app/unit ID와 Xcode Cloud 주입은 완료됐다.
- `app-store/assets/icon-1024.png`는 600x600 원본에서 생성했으므로 최종 고해상도 원본 교체를 권장한다.

## 확인 명령

```bash
godot --version
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
security find-identity -v -p codesigning
tools/check_app_store_readiness.py --json
```

## 검증 기록

- 2026-09-22: `v1.3.18`(source `d4f83a2`) build `1003018` 을 GitHub Actions 로 업로드하고 ASC 에서 `VALID` 를 확인했다. appStoreVersion 1.3.18 을 만들어 build 를 연결하고 ko/en-US whatsNew 를 넣은 뒤 심사 제출했다. reviewSubmission `1eec01db-aaf8-4a56-a5c7-e49b36bf61ac`, state `WAITING_FOR_REVIEW`, releaseType `MANUAL`. 앱의 App Store 로케일이 ko/en-US 둘뿐이라 ja/zh-Hans 노트는 대상이 없어 건너뛰었다.
- 2026-09-22: AdMob v5 로 올리면서 caller 의 `post_export_project_script` 를 뺐다. v4 시절 후처리가 v5 의 `admob_spm/Package.swift` 위치를 못 찾아 첫 배포가 실패했고, 훅 제거 후 같은 태그로 재실행해 성공했다.
- 2026-09-21: AdMob 유지 publisher `pub-9932778305312246`로 iOS 앱(`~7227831828`)과 유닛 3종(`game_over` 전면 `/1584622900`, `foam_bomb_free` 보상형 `/3266379398`, `level_reward_2x` 보상형 `/3883483180`)을 발급하고 `app-store/app-store.config.json`에 반영했다. `tools/prepare_ios_native_ads.sh`를 로컬 실행해 `ADMOB_REQUIRE_PRODUCTION=1` 주입이 새 ID로 통과하는 것을 확인했다. 실기기 광고 QA와 스토어 업로드는 미수행.
- 2026-08-21: Xcode Cloud `Release` run 25의 `v1.3.16`/`7e8e96f` build 25가 `VALID`, `APP_STORE_ELIGIBLE`임을 확인하고 App Store version 1.3.16에 선택했다.
- 2026-08-21: App Privacy에 Firebase `User ID`를 `App Functionality`, linked=yes, tracking=no로 게시했다.
- 2026-08-21: review submission `94a206fe-cdbc-4355-9e6d-0bb6a3a849fa`를 제출하고 version/submission 모두 `WAITING_FOR_REVIEW`, releaseType `MANUAL`을 API로 재조회했다.
- 2026-07-29: Xcode Cloud `Release` build 24를 `v1.3.12`/`cc5c723` 대상으로 완료했다. Archive issue 0, App Store Connect `processingState=VALID`, `buildAudienceType=APP_STORE_ELIGIBLE`, `internalBuildState=IN_BETA_TESTING`을 API로 재조회했다.
- 2026-07-29: build 22는 자동 package resolution 비활성 상태에서 `Package.resolved`가 없어 실패했다. build 23은 post-clone의 Xcode resolver도 같은 설정을 상속해 exit 74로 실패했다. SwiftPM CLI로 lockfile을 선생성하고 Xcode workspace에 복사하도록 보정한 뒤 build 24에서 해결을 확인했다.
- 2026-07-29: AdMob 콘솔에서 iOS 전면 광고 1개와 일반 보상형 2개의 이름·ID·형식을 확인했다. Xcode Cloud `Release` workflow에 app/unit ID와 `ADMOB_REQUIRE_PRODUCTION=1`을 등록한 뒤 재조회했다.
- 2026-07-21: Poing AdMob v4.3.1 iOS xcframework를 Godot 4.6.3 preset에 번들하고 project-only export를 확인했다. 생성된 plist에 Google 테스트 app ID와 SKAdNetworkItems가 포함되고 ATT usage description은 없다.
- 2026-07-21: headless export 후 local Swift Package reference를 보정해 GoogleMobileAds 13.3.0, UMP 3.1.0, Poing xcframework가 링크된 unsigned Release iphoneos build를 완료했다.
- 2026-06-12: App Store 준비 시작. iOS preset, repo-local config, release docs, readiness checker, build script 추가.
- 2026-06-12: `tools/build_ios_app_store.sh --project-only` 성공. `build/ios/foam-party.xcodeproj` 생성 확인.
- 2026-06-12: `tools/build_ios_app_store.sh --unsigned-build` 성공. Xcode 26.5 / iPhoneOS SDK 26.5에서 `CODE_SIGNING_ALLOWED=NO`, `TARGETED_DEVICE_FAMILY=1` Release compile 확인.
- 2026-06-12: `tools/build_ios_app_store.sh`는 `FOAM_PARTY_IOS_PROFILE_SPECIFIER` 미설정으로 exit code `2`에서 중단. 서명된 `.ipa` 생성은 App Store provisioning profile 확정 후 진행.
- 2026-06-12: `tools/check_app_store_readiness.py --json` 결과, iOS template/Xcode/Apple Distribution/App Store icon은 통과. `com.seorilabs.foamparty`용 App Store provisioning profile과 App Store screenshots는 blocker.
- 2026-06-12: iPhone Simulator 실행 확인. Godot 4.6.3 로컬 iOS template의 Simulator `libgodot.a`는 실제로 x86_64 only라 iOS 26.5 arm64 Simulator 설치가 실패한다. iOS 18.1 `iPhone 16 Pro`를 `xcrun simctl boot <UDID> --arch=x86_64`로 부팅하고, x86_64 Simulator build를 설치/실행해 타이틀 화면을 확인했다. 스크린샷: `tmp/foam-party-iphone16pro-sim.png`.
- 2026-06-12: 초기 App Store 등록 기준을 `en-US` primary locale과 worldwide availability로 확정했다. 게임 내 표시 텍스트도 영어로 맞춰 App Store 스크린샷/심사 화면을 영어 기준으로 준비한다.
- 2026-06-12: 영어 UI 전환 후 `godot --headless --path godot --script res://tests/smoke_scene.gd`, `tools/check_app_store_readiness.py --json`, `tools/build_ios_app_store.sh --project-only`, `tools/build_ios_app_store.sh --unsigned-build`를 재확인했다. Readiness blocker는 App Store profile, screenshots, App Store Connect 수동 gate다.

## iPhone Simulator 실행 메모

현재 로컬 Godot 4.6.3 iOS export template 기준으로 Simulator 실행은 x86_64 경로가 필요하다.

```bash
tools/build_ios_app_store.sh --project-only
xcodebuild \
  -project build/ios/foam-party.xcodeproj \
  -scheme foam-party \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/ios-sim/DerivedData-x86_64 \
  build \
  CODE_SIGNING_ALLOWED=NO \
  TARGETED_DEVICE_FAMILY=1 \
  ARCHS=x86_64 \
  ONLY_ACTIVE_ARCH=NO \
  EXCLUDED_ARCHS=arm64

SIM_UDID=07D9A5CC-AB1D-43AA-915F-7A8128044B5B
xcrun simctl boot "$SIM_UDID" --arch=x86_64
xcrun simctl bootstatus "$SIM_UDID" -b
xcrun simctl install "$SIM_UDID" build/ios-sim/DerivedData-x86_64/Build/Products/Release-iphonesimulator/foam-party.app
xcrun simctl launch "$SIM_UDID" com.seorilabs.foamparty
```

iOS 26.5 Simulator runtime은 현재 arm64 only라 위 x86_64 app 설치가 `Failed to find matching arch`로 실패한다.
