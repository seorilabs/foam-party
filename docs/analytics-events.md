# Foam Party — 애널리틱스 & 광고 이벤트 설계

모든 이벤트는 Firebase Analytics로 수집한다. 플랫폼별 경로:

- **네이티브(Android/iOS)**: Godot `FirebaseAnalyticsAdapter` → `godotx_firebase` 네이티브 플러그인.
- **웹/AIT**: 심사 번들에 클라이언트 비밀값을 두지 않기 위해 현재 비활성. `window.__foamPartyFirebase`는 호환용 no-op 브리지만 유지한다.

즉 게임 로직은 항상 `analytics.log_event(name, params)` 하나만 호출하고, 플랫폼 라우팅은 어댑터가 처리한다.

## 콘텐츠 이벤트 카탈로그 (Clean Architecture)

콘텐츠 이벤트의 **이름 + 파라미터 스키마 원본은 순수 코어**에 있다: `packages/product-core/src/analytics/content_events.gd`(`res://core/analytics/content_events.gd`). 엔진 의존 없는 빌더가 `{name, params}`를 만들고, `godot/scripts/main.gd`의 `_emit_content(...)`가 `AnalyticsPort`로 포워딩한다. 즉 호출부는 인라인 딕셔너리를 조립하지 않으며, 이벤트 스키마가 한 곳에서만 잠긴다.

- 파라미터 값 타입은 이 경계에서 GA4 export 컬럼 타입에 맞춰 고정한다. 수치 파라미터(`level`·`stars`·`time_sec`·`best_combo`·`coins_earned`·`cost`·`reward`·`bonus`·`unclaimed`·`streak`)는 네이티브 int로 보내 GA4가 `int_value`/`double_value`로 적재하게 한다(GA4 커스텀 측정항목 등록·무-CAST 집계의 전제). 식별자/enum(`mission_type`·`source`·`car_type`·`skin_id`·`tool`·`placement`)과 불리언 플래그(`new_record`)는 문자열로 둔다. 기존에 문자열로 적재되던 키를 int로 전환하면 그 키에 한해 BigQuery에서 int↔string 1회성 분리가 생기지만, 현재 소표본에서는 이를 감수해 이후 지표를 정상화한다(#246).
- 백오피스는 이 카탈로그와 1:1로 맞춘 `ContentMetricsSource`(GA4/BigQuery 어댑터, 자체 지표 서버로 교체 가능)로 하루 1회 집계한다. 상세: seorilabs-backoffice `src/lib/analytics/content-shapes.ts`, `src/lib/ga4/content-source.ts`.

| 이벤트 | 주요 파라미터 | 콘텐츠 지표 |
|---|---|---|
| `game_start` | `level` | 세션 시작 |
| `level_start` | `level`, `car_type` | 레벨 퍼널(시작) |
| `level_complete` | `level`, `stars`, `time_sec`, `best_combo`, `coins_earned`, `new_record` | 레벨 퍼널(완료/클리어시간/별), 경제(코인 획득) |
| `level_abandon` | `level`, **`reason`**(`pause_home` \| `pause_restart` \| `quit_confirm` \| `app_background`), `progress_pct`(0~100), `elapsed_sec` | 레벨 퍼널(중도 이탈 사유·진행률·경과초) |
| `foam_bomb_use` | `level`, **`source`**(`coins` \| `ad`), `cost` | 수익화(폼밤), 경제(코인/광고 소비) |
| `daily_mission_claim` | `mission_type`, `reward` | 3개 데일리 슬롯별 수령·streak 보너스를 포함한 실제 코인 획득 |
| `upgrade_purchase` | `tool`, `level`, `cost` | 수익화(업그레이드), 경제(코인 소비) |
| `skin_select` / `skin_purchase` | `tool`, `skin_id`(, `cost`) | 수익화(스킨), 경제(코인 소비) |

> `foam_bomb_use.cost`는 신규(경제 흐름 집계용). `source=ad`면 `cost=0`으로 보고해 코인 소비 합산 시 광고 지급분이 중복되지 않는다.

## FTUE 퍼널 이벤트

FTUE 이벤트의 이름과 파라미터 원본은 `packages/product-core/src/analytics/ftue_events.gd`다. Android와 iOS는 동일한 Godot 호출부와 `FirebaseAnalyticsAdapter`를 사용하므로 플랫폼별 이벤트 이름이 갈라지지 않는다.

| 이벤트 | 주요 파라미터 | 발화 시점 |
|---|---|---|
| `title_screen_view` | `entry`(`cold_start` \| `pause_home`) | 최초 타이틀 진입 또는 플레이 중 홈 복귀 |
| `level_load_start` | `level`, `reason` | 보드 준비 시작 |
| `level_load_complete` | `level`, `car_type`, `reason` | 오염 배치와 초기 진행도 계산 완료 |
| `play_tap` | `level` | 타이틀의 플레이 버튼 탭 |
| `tutorial_step_view` | `step`(`overview`), `source` | 단일 화면 세차 가이드 표시 |
| `tutorial_complete` | `step`(`overview`), `source` | 표시된 세차 가이드 닫기 |

콜드 스타트의 커스텀 이벤트 순서는 `title_screen_view → level_load_start → level_load_complete`다. 플레이 버튼을 누르면 `play_tap → game_start → level_start`가 이어지고, 첫 실행이면 `tutorial_step_view → tutorial_complete`가 추가된다. 재도전/다음 레벨은 `level_load_start → level_load_complete → level_start` 순서다.

`level_start`는 보드가 타이틀 뒤에서 미리 준비됐다는 이유만으로 발화하지 않는다. 실제 플레이 상태에 처음 진입했을 때 한 번만 발화하며, 홈 화면에서 같은 레벨로 복귀해도 중복 발화하지 않는다.

앱 버전은 별도 커스텀 `release_version`을 중복 전송하지 않고 GA4 export의 `app_info.version`과 `app_info.id`로 귀속한다. 따라서 BigQuery에서는 최신 계측 버전만 필터해 `first_open → title_screen_view → level_load_complete → play_tap → level_start → tutorial_complete` 전환율을 비교한다.

## 광고 이벤트

광고는 Clean Architecture `AdPort`(core/ports/ad_port.gd) + `AdService`(scripts/services/ad_service.gd) 시맨틱으로 통일한다. 두 층위로 로깅한다.

### 1) 게임 관점 (Godot `AdService` → analytics)

플레이어 행동/보상 지급 시점. `provider`는 실제 노출 SDK(웹=toss_ads, 네이티브=admob).

| 이벤트 | 파라미터 | 시점 |
|---|---|---|
| `ad_rewarded_request` | `placement`, `provider` | 로드된 리워드 광고 표시 요청 |
| `ad_rewarded_granted` | `placement`, `provider` | SDK earned callback 확인 후 보상 지급 |
| `ad_interstitial_request` | `placement`, `provider` | 로드된 전면 광고 표시 요청 |

### 2) SDK 라이프사이클

네이티브 `AdService`는 아래 이벤트를 Firebase Analytics로 기록한다. 공통 파라미터는 `placement`, `provider=admob`이다.

- `ad_{rewarded|interstitial}_loaded`
- `ad_{rewarded|interstitial}_load_failed`
- `ad_{rewarded|interstitial}_impression`
- `ad_{rewarded|interstitial}_dismissed`
- `ad_{rewarded|interstitial}_show_failed`

웹에서는 `tossFullScreenAdRuntime.ts`가 AIT 통합광고 이벤트를 직접 기록한다. 이름은 `ait_{rewarded|interstitial}_{event}`다.

`tossFullScreenAdRuntime.ts`가 AIT 통합광고 이벤트를 직접 기록. 이름은 `ait_{rewarded|interstitial}_{event}`.

| event_type | 출처 | 의미 |
|---|---|---|
| `load_requested` / `loaded` / `load_failed` / `load_timeout` | 런타임 `preload` | 사전 로드 |
| `show_skipped_not_loaded` / `show_skipped_showing` | 런타임 `show` | 미로드/중복 표시 스킵 |
| SDK `showFullScreenAd` 이벤트 (`requested`·`show`·`impression`·`clicked`·`dismissed`·`failed_to_show`·`user_earned_reward`) | AIT SDK → verbatim forward | SDK가 실제로 보낸 이벤트만 기록됨 |

즉 show-phase 이벤트는 `logAdEvent(placement, event.type)`로 **SDK가 emit한 그대로** 전달되므로, 특정 event_type의 존재/빈도는 SDK 동작에 따른다. 공통 파라미터: `placement`, `provider`(`toss_ads`), `ad_group_id`, `event_type`.

> 보상 지급은 **`user_earned_reward`에서만**(AIT 정책). `dismissed`만으로 지급 금지.

## 배치(placement) 규칙

| placement | 포맷 | 트리거 | 광고 그룹/유닛 |
|---|---|---|---|
| `foam_bomb_free` | 리워드 | 코인 부족 시 거품폭탄 칩 탭 → 광고 시청 → 무료 거품폭탄 | 네이티브 `native_ads.json` / AIT `VITE_TOSS_REWARDED_AD_GROUP_ID` |
| `level_reward_2x` | 리워드 | 결과 화면 보상 2배 | 네이티브 `native_ads.json` / AIT `VITE_TOSS_REWARDED_AD_GROUP_ID` |
| `game_over` | 전면 | 레벨 전환(next/retry) 시 `INTERSTITIAL_EVERY`(=3)회마다 1회 | 네이티브 `native_ads.json` / AIT `VITE_TOSS_INTERSTITIAL_AD_GROUP_ID` |

## 안전/비활성 규칙

- Android/iOS는 Poing AdMob v4.3.1과 Godot 4.6.3용 바이너리를 repo에 고정한다. desktop/headless/Web에는 네이티브 singleton이 없어 기존 no-op 경로를 유지한다.
- `godot/config/native_ads.json` 기본값은 Google 공식 테스트 app/unit ID다. `tools/configure_native_ads.py`가 빌드 환경변수로 실제 ID를 주입한다.
- 마켓 릴리즈는 `ADMOB_REQUIRE_PRODUCTION=1`과 `ADMOB_TARGET_PLATFORM=Android|iOS`를 전달한다. 선택한 플랫폼의 최종 `native_ads.json`·Android `config.gd`·iOS `.gdip` 중 테스트 퍼블리셔 `ca-app-pub-3940256099942544`가 하나라도 남으면 빌드가 실패해야 한다. 미설정 시 dev/AIT/PR의 기존 테스트 ID 동작은 유지한다.
- Android production 변수: `ADMOB_ANDROID_APP_ID`(호환: `ADMOB_APP_ID`), `ADMOB_ANDROID_INTERSTITIAL_AD_UNIT_ID`(호환: `ADMOB_INTERSTITIAL_AD_UNIT_ID`), `ADMOB_ANDROID_FOAM_BOMB_REWARDED_AD_UNIT_ID`, `ADMOB_ANDROID_LEVEL_REWARD_REWARDED_AD_UNIT_ID`.
- iOS production 변수: `ADMOB_IOS_APP_ID`, `ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID`, `ADMOB_IOS_FOAM_BOMB_REWARDED_AD_UNIT_ID`, `ADMOB_IOS_LEVEL_REWARD_REWARDED_AD_UNIT_ID`.
- 확정 앱 ID: Android `ca-app-pub-9932778305312246~1897457409`, iOS `ca-app-pub-9932778305312246~7227831828`.
- AdMob 콘솔에서 2026-09-21 확인한 운영 유닛. 전부 유지 publisher `pub-9932778305312246` 소속이다:

| 플랫폼 | placement | 형식 | 운영 ID |
|---|---|---|---|
| Android | `foam_bomb_free` | 보상형 | `ca-app-pub-9932778305312246/1257319840` |
| Android | `level_reward_2x` | 보상형 | `ca-app-pub-9932778305312246/6318074836` |
| Android | `game_over` | 전면 광고 | `ca-app-pub-9932778305312246/6583552731` |
| iOS | `foam_bomb_free` | 보상형 | `ca-app-pub-9932778305312246/3266379398` |
| iOS | `level_reward_2x` | 보상형 | `ca-app-pub-9932778305312246/3883483180` |
| iOS | `game_over` | 전면 광고 | `ca-app-pub-9932778305312246/1584622900` |

- 2026-09-21 이전 라이브 빌드는 레거시 publisher `pub-2444587584524186`(Android app `~8642747667`, iOS app `~1722116096`)를 싣고 나갔다. 두 publisher는 `www.seorilabs.com/app-ads.txt`에 함께 게시돼 있고, 구버전 설치본이 소진되면 레거시 줄을 지운다. 레거시 유닛 ID는 `play-store/google-play.config.json`과 `app-store/app-store.config.json`의 `legacy*` 항목에 비교용으로 남는다.
- 레거시 publisher의 Android `ca-app-pub-2444587584524186/5440739953`와 iOS `ca-app-pub-2444587584524186/7557772414`는 `보상형 전면 광고`라 `RewardedAdLoader`와 호환되지 않으며 설정 스크립트가 거부한다. 유지 publisher에서 보상형 유닛을 새로 만들 때도 `보상형 전면`이 아닌 `보상형`을 선택해야 한다.
- repo 밖 동반 설정: `seorilabs/.github`의 `godot-deploy-google-play.yml`은 Android rewarded 변수 2개와 `ADMOB_REQUIRE_PRODUCTION=1`을 전달한다. Android 운영 ID는 Google Play `google-play` environment 변수에 등록하고, iOS 운영 ID는 `app-store/app-store.config.json`의 `adMob` 절을 정본으로 `tools/prepare_ios_native_ads.sh`가 `Deploy to App Store` 빌드에서 주입한다. 유지 publisher 전환은 2026-09-21에 양쪽 모두 반영했다.
- iOS는 ATT prompt 없이 `npa=1`을 요청별 기본값으로 보낸다. 이는 UMP 동의 수집을 대체하지 않으므로 EEA/UK 배포 전 AdMob privacy message와 UMP 흐름을 별도 확정한다.
- 광고 이벤트는 fire-and-forget: 게임 상태/반환값에 영향 없음.
