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
- [x] Poing AdMob v5.1.0 교체 — v5는 네이티브 바이너리를 addon 안(`android/bin`, `ios/bin`)에 두고, v4의 `res://ios/plugins/poing-godot-admob*` 배치를 충돌로 거부한다
- [x] godotx Firebase 3.1.0 교체
- [x] `tools/check_native_admob_bundle.py` 고정값 갱신
- [x] iOS unsigned build 링크 통과 — `BUILD SUCCEEDED`
- [x] 운영 app id가 생성 plist에 반영됨 — `GADApplicationIdentifier` = `ca-app-pub-9932778305312246~7227831828`
- [ ] Android 실기기에서 `level_start` 등 커스텀 이벤트 수집 확인 (#245 AC-2)
- [x] **CI 주입 순서** — `seorilabs/.github#202` 머지 후 caller 연결

## 남은 블로커: CI 주입 순서

AdMob v5는 app id를 `.gdip`/`config.gd`가 아니라 ProjectSettings
(`admob/general/<platform>/app_id`)로 읽는다. 그런데 **`godot --import`가 등록되지 않은
커스텀 ProjectSettings를 저장 시 버린다.** 에디터에서는 AdMob addon의 `_enter_tree`가
`register_settings()`로 등록하지만 headless import는 EditorPlugin을 로드하지 않는다.

그래서 app id는 저장소에 보관할 수 없고 빌드마다 주입해야 한다.
`tools/configure_native_ads.py`가 `[admob]` 섹션을 upsert하도록 바꿨고, 로컬 빌드는
`configure → export` 순서라 정상 동작한다.

중앙 재사용 워크플로는 순서가 다르다.

```
Run caller project preparation   ← prepare_ios_native_ads.sh (주입)
Import Godot project             ← godot --import   (여기서 삭제됨)
Export Xcode project             ← export (기본값 = Google 테스트 ID)
```

주입이 무효화되고 **테스트 광고 ID로 조용히 빌드된다.** `ADMOB_REQUIRE_PRODUCTION=1`
검사는 prepare 시점에 돌아 통과하므로 잡지 못한다.

해소했다. `seorilabs/.github#202`(`efabd09`)가 `godot-deploy-app-store.yml`에
`post_import_script` 선택 입력을 추가했고, 이 저장소의 App Store caller가 import 전후로
`tools/prepare_ios_native_ads.sh`를 두 번 넘긴다. 주입 대상이 둘이고 살아남는 시점이 다르다.

- `native_ads.json`의 유닛 ID: pck에 들어가야 하므로 **import 전**
- ProjectSettings의 app id: import가 지우므로 **import 후**

Google Play 워크플로는 `Build AdMob plugin` 단계가 이미 import 뒤에 있어 그대로 둔다.

검증은 산출물로 한다.
- iOS: `build/ios/<name>/<name>-Info.plist`의 `GADApplicationIdentifier`
- Android: AAB manifest의 `com.google.android.gms.ads.APPLICATION_ID`

## AIT 웹 로더 후처리 파손 (#297)

4.7.2 로 올린 뒤 AppsInToss 미니앱이 열리지 않았다. 화면은 `게임 준비 100%` 에서 멈추고
오류도 로그도 남지 않았다. 원인은 엔진이 아니라 **래퍼의 로더 후처리가 반쪽만 적용된 것**이다.

`sync-godot-web.mjs` 는 브라우저 코드 실행 브리지를 무력화하려고 두 가지를 함께 바꿨다.

| 대상 | 4.6.3 | 4.7.2 |
| --- | --- | --- |
| 함수 정의 `function _godot_js_eval(` | 있음 → 교체됨 | 있음 → **교체됨** |
| import 항목 `godot_js_eval:_godot_js_eval` | 있음 → 교체됨 | **없음(`$e:_godot_js_eval` 로 최소화)** → 미적용 |

emscripten 이 import 키를 최소화하면서 두 번째 치환이 0 건이 됐다. 정의는 사라지고 참조만
남아 import 객체를 만드는 순간 `ReferenceError: _godot_js_eval is not defined` 가 난다.
Godot 로더의 init 은 연쇄 `then` 만 쓰고 rejection 핸들러가 없어서, 이 오류가 바깥 Promise 를
영원히 pending 으로 만든다. `startGame()` 이 resolve 도 reject 도 하지 않으니 래퍼의 `catch` 도
돌지 않고 로딩 문구만 남는다.

치환이 실패해도 스크립트는 **성공으로 보고했다.** 패턴을 못 찾으면 원본을 그대로 돌려주는
fail-open 구조였기 때문이다.

해소 방법은 두 가지다.

- import 키는 wasm 의 import 이름과 1:1 이므로 **건드리지 않고 값만** 새 이름으로 바꾼다.
  키를 안 바꾸니 wasm 바이트 패치도 필요 없어졌고, 판본별 최소화 규칙과 무관해졌다.
- 후처리 각 단계를 **패치 후 불변식**으로 판정하고 어긋나면 예외를 던진다. 예를 들어 브리지
  단계는 "치환 뒤 `_godot_js_eval` 참조가 0 건" 을 요구한다. 로직은
  `ait/apps-in-toss-web/src/godotLoaderSanitizer.ts` 에 있고 단위 테스트가 4.7 최소화 형태와
  4.6 원래 형태를 모두 덮는다.

래퍼에는 부팅 감시도 넣었다. 진행률이 20 초 동안 멈추면 그동안 잡아 둔 첫 오류를 화면에
띄운다. 다음에 같은 종류의 실패가 나면 실기기에서 바로 사유를 읽을 수 있다.

## 교체 시 주의

- AdMob v5는 `RewardedAdLoader`·`InterstitialAdLoader`·`OnUserEarnedRewardListener`와
  `PoingGodotAdMob*` 싱글턴 이름을 유지한다. `ad_service.gd` 대규모 수정은 예상되지 않으나
  `.gdip`의 `binary` 경로가 `bin/`에서 `libs/`로 바뀌므로 exporter 규칙을 따라 배치한다.
- Firebase 3.1.0에 `privacy_safe_defaults` export option이 추가됐고 **기본값이 true**다.
  켜면 `firebase_analytics_collection_enabled=false`와 consent 신호 denied가 manifest/plist에
  들어가 수집이 멈춘다. 2.4.1에는 없던 동작이라 양 preset에서 `false`로 고정했고
  `check:native-ads`가 이를 검사한다. EEA/UK 동의 흐름(`umpConsent`)을 갖추면 다시 검토한다.
- 릴리스 게이트에 AAB 리소스 검사를 넣으면 같은 회귀를 막는다.
  `unzip -p <aab> base/resources.pb | grep -a google_app_id`
