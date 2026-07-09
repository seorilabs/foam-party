# Foam Party — 애널리틱스 & 광고 이벤트 설계

모든 이벤트는 Firebase Analytics로 수집한다. 플랫폼별 경로:

- **네이티브(Android/iOS)**: Godot `FirebaseAnalyticsAdapter` → `godotx_firebase` 네이티브 플러그인.
- **웹/AIT**: Godot `FirebaseAnalyticsAdapter` → `JavaScriptBridge` → `window.__foamPartyFirebase`(firebaseRuntime.ts) → Firebase JS SDK.

즉 게임 로직은 항상 `analytics.log_event(name, params)` 하나만 호출하고, 플랫폼 라우팅은 어댑터가 처리한다.

## 게임 이벤트 (기존)

| 이벤트 | 주요 파라미터 |
|---|---|
| `game_start` | `level` |
| `level_start` | `level`, `car_type` |
| `level_complete` | `level`, `stars`, `time_sec`, `best_combo`, `coins_earned`, `new_record` |
| `foam_bomb_use` | `level`, **`source`**(`coins` \| `ad`) |
| `daily_mission_claim` | `mission_type`, `reward` |
| `upgrade_purchase` | `tool`, `level`, `cost` |
| `skin_select` / `skin_purchase` | `tool`, `skin_id`(, `cost`) |

## 광고 이벤트 (신규)

광고는 Clean Architecture `AdPort`(core/ports/ad_port.gd) + `AdService`(scripts/services/ad_service.gd) 시맨틱으로 통일한다. 두 층위로 로깅한다.

### 1) 게임 관점 (Godot `AdService` → analytics)

플레이어 행동/보상 지급 시점. `provider`는 실제 노출 SDK(웹=toss_ads, 네이티브=admob).

| 이벤트 | 파라미터 | 시점 |
|---|---|---|
| `ad_rewarded_request` | `placement`(`foam_bomb_free`) | 리워드 광고 표시 요청 |
| `ad_rewarded_granted` | `placement` | 보상 지급(광고 시청 완료) → 무료 거품폭탄 |
| `ad_interstitial_request` | `placement`(`game_over`) | 전면 광고 표시 요청 |

### 2) SDK 라이프사이클 (웹 런타임 → `window.__foamPartyFirebase`)

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
| `foam_bomb_free` | 리워드 | 코인 부족 시 거품폭탄 칩 탭 → 광고 시청 → 무료 거품폭탄 | AdMob `ca-app-pub-2444587584524186/5440739953` / AIT `VITE_TOSS_REWARDED_AD_GROUP_ID` |
| `game_over` | 전면 | 레벨 전환(next/retry) 시 `INTERSTITIAL_EVERY`(=3)회마다 1회 | AIT `VITE_TOSS_INTERSTITIAL_AD_GROUP_ID` |

## 안전/비활성 규칙

- 광고 그룹 ID(env) 미설정 또는 SDK 미지원 → `is_rewarded_ready`/`show_*`가 no-op. 거품폭탄 칩은 코인 전용 모드로 표시.
- 네이티브 AdMob 플러그인 미탑재(현재) → 네이티브 경로 no-op (Phase 2에서 연결).
- 광고 이벤트는 fire-and-forget: 게임 상태/반환값에 영향 없음.
