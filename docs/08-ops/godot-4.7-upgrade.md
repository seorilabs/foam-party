# Godot 4.7.2 업그레이드

이슈 #245(Android 계측 전면 미수집)의 해법으로 엔진을 4.6.3에서 4.7.2로 올린다.
엔진과 네이티브 플러그인은 **원자적으로 함께** 올려야 한다. 한쪽만 올리면 빌드가 깨진다.

## 왜 올리는가

4.6.x Android 템플릿에는 `com.google.gms.google-services` gradle 플러그인 적용이 없다.
4.7부터 상류에 들어갔다.

```gradle
# 4.7.2 android_source.zip / build.gradle
classpath 'com.google.gms:google-services:4.4.4'
if (file('google-services.json').exists()) {
    apply plugin: 'com.google.gms.google-services'
}

# 4.6.3 android_source.zip / build.gradle → 해당 코드 없음
```

이 플러그인이 `google-services.json`을 `google_app_id` 등 string 리소스로 굽는다.
없으면 `FirebaseInitProvider`가 기본 `FirebaseApp`을 만들지 못하고 Analytics가 통째로 꺼진다.

부수 효과로 ARC 러너 이미지에 preinstall된 엔진과 버전이 맞는다. 현재는 어긋나서
러너가 매 실행마다 엔진을 새로 받는다.

## ABI 제약

Godot 4.7이 내부 C++ API의 const 여부를 바꿨다. iOS 네이티브 정적 라이브러리는
엔진 ABI에 묶이므로 4.6용 바이너리는 4.7에서 링크되지 않는다.

| 대상 | 요구 심볼 | 4.7.2 호환 |
| --- | --- | --- |
| Godot 4.7.2 `libgodot.a` | `Object::_add_class_to_classdb(GDType&, GDType const*)` | 기준 |
| Poing AdMob v4.3.1 (현재) | `Object::_add_class_to_classdb(GDType const&, ...)` | 아니오 |
| godotx_firebase 2.4.1 (현재) | `Object::_add_class_to_classdb(GDType const&, ...)` | 아니오 |
| Poing AdMob v5.1.0 `ios-template-v4.7.2` | `Object::_add_class_to_classdb(GDType&, GDType const*)` | 예 |
| godotx_firebase 3.1.0 | `Object::_add_class_to_classdb(GDType&, GDType const*)` | 예 |

확인 방법은 `nm -u <lib>.a | c++filt | grep GDType`이다.

Android는 JVM `.aar`이라 이 제약이 없다. iOS만 해당한다.

## 올릴 대상

| 구성요소 | 현재 | 목표 | 근거 |
| --- | --- | --- | --- |
| Godot | 4.6.3 | 4.7.2 | org `global-versions.yaml` 러너 이미지가 `godot4.7.2` |
| Poing AdMob | v4.3.1 | v5.1.0 | 릴리스 노트 "minimum Godot export version to 4.4+ (testing through 4.7.2)" |
| godotx Firebase | 2.4.1 | 3.1.0 | README "This project is built for Godot 4.7 or later" |

배포처는 `poing-studios/godot-admob-plugin`(에셋 `poing-godot-admob-v5.1.0.zip`,
`ios-template-v4.7.2.zip`, `android-template-v4.7.2.zip`)과 `godot-x/firebase`
(에셋 `godotx_firebase.zip`)다. Poing은 Godot 버전별 네이티브 템플릿을 따로 낸다.

## 진행 상황

엔진 버전 고정은 `chore/godot-4.7.2-upgrade` 브랜치에 있다. 네이티브 플러그인 교체가
남아 있어 iOS 링크가 실패하므로 아직 병합하지 않는다.

- [x] `godot/project.godot` `config/features` 4.7
- [x] caller 5곳 `godot_version: "4.7.2"` 고정 — 중앙 재사용 워크플로 기본값이 4.6.3이라 `godot-checks`·`deploy-godot-pages`도 명시해야 한다
- [x] `scripts/ensure_godot.sh` 기본값, 마켓 config, docs
- [x] 검증: `npm test` 통과, Android AAB에 `google_app_id`·`gcm_defaultSenderId`·`google_api_key`·`project_id` 생성 확인, iOS export(project-only) 성공
- [ ] Poing AdMob v5.1.0 교체 — `godot/addons/admob/`, iOS `godot/ios/plugins/poing-godot-admob*`, Android `godot/addons/admob/android/bin/`
- [ ] godotx Firebase 3.1.0 교체 — `godot/addons/godotx_firebase/`, `godot/android/firebase_*`, `godot/ios/plugins/firebase_*`
- [ ] `tools/check_native_admob_bundle.py` 고정값 갱신 (현재 `v4.3.1`·Ads SDK `24.9.0`·GMA `13.3.0`·UMP `3.1.0`을 검사)
- [ ] iOS unsigned build 링크 통과 확인
- [ ] Android 실기기에서 `level_start` 등 커스텀 이벤트 수집 확인 (#245 AC-2)

## 교체 시 주의

- AdMob v5는 `RewardedAdLoader`·`InterstitialAdLoader`·`OnUserEarnedRewardListener`와
  `PoingGodotAdMob*` 싱글턴 이름을 유지한다. `ad_service.gd` 대규모 수정은 예상되지 않으나
  `.gdip`의 `binary` 경로가 `bin/`에서 `libs/`로 바뀌므로 exporter 규칙을 따라 배치한다.
- Firebase 3.1.0은 export option 이름(`firebase/enable_analytics` 등)을 유지하고
  `privacy_safe_defaults`가 추가됐다. 기본 수집이 꺼질 수 있으니 확인한다.
- 릴리스 게이트에 AAB 리소스 검사를 넣으면 같은 회귀를 막는다.
  `unzip -p <aab> base/resources.pb | grep -a google_app_id`
