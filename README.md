# 폼 파티

Godot 4.6 기반 카툰풍 세차 게임 프로토타입입니다.

## 현재 MVP

- 흙탕물, 먼지, 낙엽, 벌레 자국, 오일 얼룩이 붙은 카툰풍 차량.
- 청소 도구 4종: 바람, 고압수, 비누, 스펀지.
- 이물질 종류마다 유효한 청소 순서가 다르고, 오물 상태가 바뀌며 사라집니다.
- 바람은 낙엽/먼지를 날려 보내고, 고압수는 흙탕물/먼지/비누칠된 오염을 흘려보냅니다.
- 비누는 오일/벌레 자국을 먼저 불리고, 이후 고압수나 스펀지로 제거합니다.
- 도구별 합성 효과음과 루프 배경음악이 들어가 있습니다.
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

## 범위 메모

- MVP는 로컬-only 게임플레이입니다.
- 효과음과 배경음악은 외부 에셋이 아니라 런타임 합성 WAV입니다.
- Firebase, Google Play, App Store, AppsInToss release setup은 아직 추가하지 않았습니다.
- 이후 플랫폼 서비스는 gameplay script에 직접 섞지 말고 adapter 뒤에 둡니다.

## 오디오 메모

- 도구 효과음은 `godot/scripts/main.gd`에서 런타임 합성합니다.
- 바람은 에어 컴프레셔 질감에 맞춰 저역 풍압, 호스 공진, 노즐 고역을 섞습니다.
- 고압수는 물줄기 hiss보다 차체를 때리는 충돌 펄스와 튀는 물방울을 강조합니다.
- 비누는 부드러운 fizz와 작은 거품 pop을 여러 속도로 겹칩니다.
- 스펀지는 걸레가 유리를 왕복 문지르는 마찰음과 높은 squeak을 반복합니다.
