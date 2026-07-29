# App Store Release

폼 파티의 Apple App Store 빌드 기준 문서다. 현재 실행 기준은 Godot iOS export preset과 로컬 Xcode archive/export다.

## 빌드 기준

| 항목 | 값 | 상태 |
| --- | --- | --- |
| Godot preset | `iOS` | 생성됨 |
| Bundle ID | `com.seorilabs.foamparty` | App Store Connect 최종 확인 필요 |
| Team ID | `HCDUXX4Z3X` | 로컬 Apple Distribution 인증서에서 확인 |
| Marketing version | `0.1.0` | iOS preset 기준 |
| Build number | `1` | iOS preset 기준 |
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
export ADMOB_IOS_APP_ID="ca-app-pub-2444587584524186~1722116096"
export ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID="ca-app-pub-2444587584524186/5905611520"
export ADMOB_IOS_FOAM_BOMB_REWARDED_AD_UNIT_ID="ca-app-pub-2444587584524186/1826765714"
export ADMOB_IOS_LEVEL_REWARD_REWARDED_AD_UNIT_ID="ca-app-pub-2444587584524186/8531774866"
export ADMOB_REQUIRE_PRODUCTION="1"
```

Xcode Cloud `Release` workflow에는 위 5개 변수를 2026-07-29 등록하고 저장 후 재조회했다. 광고 단위 형식은 `game_over=전면 광고`, `foam_bomb_free/level_reward_2x=보상형`으로 AdMob 콘솔에서 확인했다.

Godot iOS export는 `build/ios/foam-party.xcodeproj`와 AdMob용 local `Package.swift`를 만든다. 스크립트는 headless export에서 누락될 수 있는 Swift Package project reference를 idempotent하게 보정한 뒤 `build/ios/foam-party.xcarchive`와 `.ipa` export를 이어서 만든다.

## 현재 제한

- 1.0.0 제출 당시 답변과 달리 현재 소스는 AdMob/Firebase Analytics를 포함한다. 다음 버전의 App Privacy, age rating, review notes를 다시 확정해야 한다.
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
