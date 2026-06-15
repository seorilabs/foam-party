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

Godot iOS export는 `build/ios/foam-party.xcodeproj`를 만들고, 스크립트가 `build/ios/foam-party.xcarchive`와 `.ipa` export를 이어서 만든다.

## 현재 제한

- App Store Connect app shell, App Privacy, age rating, review contact, content rights, TestFlight upload는 아직 완료 상태가 아니다.
- Worldwide availability는 EU 배포를 포함하므로 App Store Connect에서 DSA trader status와 표시 연락처 요구사항을 확인해야 한다.
- 로컬에 있는 provisioning profile은 `AppStore Happy Farm Profile`이며 `com.seorilabs.happyfarm`용이라 폼 파티에 사용할 수 없다.
- `app-store/assets/icon-1024.png`는 현재 600x600 원본에서 생성한 임시 고해상도 아이콘이다. 최종 제출 전 1024 원본 제작을 권장한다.
- 스크린샷은 아직 실제 iOS/Simulator 화면에서 App Store용 `en-US` 세트로 캡처하지 않았다.

## 확인 명령

```bash
godot --version
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
security find-identity -v -p codesigning
tools/check_app_store_readiness.py --json
```

## 검증 기록

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
