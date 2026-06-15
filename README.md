# 폼 파티

Godot 4.6 기반 카툰풍 세차 게임 프로토타입입니다.

## 현재 MVP

- 흙탕물, 먼지, 낙엽, 벌레 자국, 오일 얼룩이 붙은 카툰풍 차량.
- 차종 3종(시티카/스포츠카/트럭)이 레벨마다 순환하며 색상 팔레트도 함께 바뀝니다.
- 청소 도구 4종: 바람, 고압수, 비누, 스펀지.
- 이물질 종류마다 유효한 청소 순서가 다르고, 오물 상태가 바뀌며 사라집니다.
- 바람은 낙엽/먼지를 날려 보내고, 고압수는 흙탕물/먼지/비누칠된 오염을 흘려보냅니다.
- 비누는 오일/벌레 자국을 먼저 불리고, 이후 고압수나 스펀지로 제거합니다.
- 도구별 합성 효과음과 루프 배경음악이 들어가 있습니다.
- 세차 중 도구를 끌면 속도에 비례해 도구 색의 잔상(드래그 트레일)이 남아 문지르는 손맛을 더합니다.
- 연속 제거 콤보(피치 상승 효과음, 콤보 배지)와 완료 별점(시간+최고 콤보 기준 1~3개)이 있습니다.
- 플레이 중 실시간 등급 트래커가 지금 받을 별점을 보여줍니다. 별 3개 조건(빠른 클리어 + 콤보 x4)을 안내하고, 별이 깎이기 직전 남은 시간을 카운트다운으로 경고합니다.
- 레벨별 최고 기록(클리어 시간)을 저장하고, 결과 화면에서 기존 기록과 비교해 갱신 시 "신기록!" 연출을 보여줍니다.
- 결과 화면에서 "다시 세차"로 같은 레벨을 재도전하거나 "다음 차"로 넘어갈 수 있습니다.
- 코인 보상(별점·콤보 기반)과 거품 폭탄 부스터(코인 40, 전체 오물 비누칠)가 있습니다.
- 타이틀 화면(이어하기), 첫 실행 세차 가이드, 사운드 토글, 로컬 진행 저장이 들어가 있습니다.
- 레벨이 오를수록 오물 수(20→24)와 체력이 점진적으로 늘어납니다.
- 청결도 게이지와 다음 차량 루프가 메인 씬에서 플레이 가능합니다.

## 실행

```bash
godot --path godot
```

## Smoke Test

```bash
godot --headless --path godot --script res://tests/smoke_scene.gd
```

## Android Debug APK

현재 debug APK 산출물:

```bash
build/android/foam-party-debug.apk
```

기기가 ADB에 보이면 설치/실행:

```bash
godot --headless --path godot --export-debug "Android Debug"
adb install -r build/android/foam-party-debug.apk
adb shell monkey -p com.seorilabs.foamparty -c android.intent.category.LAUNCHER 1
```

Android export에는 ETC2/ASTC texture import 설정이 필요합니다. `godot/project.godot`의
`textures/vram_compression/import_etc2_astc=true`를 유지해야 합니다.

## Apple App Store 준비

App Store 준비 상태의 repo-local 원본은 다음 파일이다.

- `app-store/app-store.config.json`
- `docs/app-store-registration.md`
- `docs/app-store-release.md`
- `tools/build_ios_app_store.sh`
- `tools/check_app_store_readiness.py`

Xcode project만 생성:

```bash
tools/build_ios_app_store.sh --project-only
```

서명 없이 Release compile 경로 확인:

```bash
tools/build_ios_app_store.sh --unsigned-build
```

현재 서명된 `.ipa` 생성은 `com.seorilabs.foamparty`용 App Store provisioning profile 확정 후 진행한다.

```bash
export FOAM_PARTY_IOS_PROFILE_SPECIFIER="<profile name or uuid>"
tools/build_ios_app_store.sh
```

남은 App Store Connect/manual gate는 아래 명령으로 확인한다.

```bash
tools/check_app_store_readiness.py
```

## 범위 메모

- MVP는 로컬-only 게임플레이입니다.
- 효과음과 배경음악은 외부 에셋이 아니라 런타임 합성 WAV입니다.
- App Store release setup은 repo-local config와 iOS export path만 추가되어 있으며, App Store Connect 등록/서명/스크린샷은 아직 남아 있습니다.
- Firebase, Google Play, AppsInToss release setup은 아직 추가하지 않았습니다.
- 이후 플랫폼 서비스는 gameplay script에 직접 섞지 말고 adapter 뒤에 둡니다.

## 스크린샷 캡처

디스플레이가 있는 환경(또는 Xvfb)에서 기본 화면, 도구별 세차 장면, 완료 화면 PNG를 캡처합니다:

```bash
xvfb-run -a godot --path godot --script res://tests/screenshot_scene.gd --audio-driver Dummy
```

`FOAM_SHOT_DIR` 환경 변수로 저장 위치를 바꿀 수 있습니다(기본 `/tmp`).

## 오디오 메모

- 도구 효과음은 `godot/scripts/main.gd`에서 런타임 합성하며, 현실적인 기계음 대신 카툰 게임 톤을 지향합니다.
- 바람은 부드러운 바람 스웰에 가벼운 휘파람 톤을 섞습니다.
- 고압수는 보글거리는 물 흐름과 음계를 따라 떨어지는 물방울 플링크를 씁니다.
- 비누는 펜타토닉 음계 거품 팝과 몽글한 fizz를 겹칩니다.
- 스펀지는 말랑한 squish 리듬과 귀여운 boing을 반복합니다.
- 오물 제거 시 피치가 살짝 바뀌는 팝+차임 효과음이 추가로 재생됩니다.
