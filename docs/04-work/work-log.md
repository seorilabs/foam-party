# Work Log

## 2026-07-21

- 5레벨에 해금되어 이후 시티카 오염 풀에 등장하는 `sap` 나무 수액을 추가했다. 물은 체력·연화에 영향을 주지 않고 비누로 불린 뒤 스펀지로만 정상 제거되며, 기존 오염 렌더 패스 안에서 호박색 수지 방울·실·광택으로 구분한다. 코칭·중앙 튜닝·스폰 풀·core/smoke/Metal screenshot 검증을 함께 확장했고 새 HUD나 시트는 추가하지 않았다.
- 타이틀의 흐린 배경 차량을 현재 레벨의 기존 `_draw_car` 경로를 재사용한 깨끗한 히어로 카로 교체하고, 장착한 물·바람·비누·스펀지 스킨 색을 보여 주는 4개 스와치를 데일리 미션 위 기존 공간에 배치했다. 새 시트나 gameplay HUD 요소는 추가하지 않았다.
- 도구 업그레이드의 동일 비용 곡선을 활용 범위 기준으로 고압수 `110/230/380`, 비누 `90/190/320`, 스펀지 `70/150/260`으로 차등화했다. 레벨별 효과 배율과 전체 1,800코인 싱크는 유지하고, 모든 도구·레벨 비용의 양수·증가·합계 불변식을 core test로 고정했다.
- 구매 불가 폼밤·업그레이드·스킨 버튼에 공통 잠금 글리프를 추가하고, 손님 인내 게이지의 네 티어를 점·눈금·십자·경고 패턴으로 분리해 색상 단독 상태 표시를 제거했다. 모두 기존 칩·카드·버튼 내부에 그려 상시 HUD 거주 영역은 유지한다.
- 노즐 스킨 소유권을 `도구:스킨` 단위로 분리해 한 도구의 `gold` 구매가 다른 도구를 함께 여는 누수를 막았다. 신규 저장은 도구별 키를 사용하고, 기존 flat 저장은 고유 스킨과 실제 선택 중이던 공유 유료 스킨만 보존적으로 마이그레이션한다.
- 손님 인내도를 경과 시간과 세차 진행도의 혼합 모델로 바꿨다. 진행도 0%의 기존 곡선은 유지하고, 100%에 가까울수록 시간 압력을 최대 65% 완화한다. 얼굴·기분·게이지 색·경고음 존은 하나의 product-core 계산을 공유하며 기존 HUD 구조는 바꾸지 않았다.
- 별 3개 콤보 게이트를 레벨 1~3의 4에서 시작해 3레벨마다 1씩, 최대 10까지 상승하도록 조정했다. 점수 판정·그레이드 트래커 문구·콤보 강조·게이트 통과 사운드와 햅틱이 같은 요구치를 사용한다.
- 데일리 미션 풀에 한 판 콤보 x8, 75초 이내 완료, 별 3개 세차 2회를 추가했다. 실제 콤보·완료 이벤트가 공통 진행/보상/저장 경로를 호출하고, 기존 타이틀 카드와 상단 칩에서 ko/en 라벨과 진행률을 표시한다.

## 2026-07-19

- HUD 사운드/도움말 버튼이 터치에서 동작하지 않던 원인을 수정했다. z-index 충돌이 아니라 하나의 탭이 `InputEventScreenTouch`와 에뮬레이션된 `InputEventMouseButton`으로 연속 전달되어 토글이 두 번 실행되던 문제였으며, 프로젝트의 포인터 에뮬레이션 비활성화와 `DEVICE_ID_EMULATION` 입력 차단을 함께 적용하고 smoke 회귀 테스트를 추가했다.
- 상단 HUD를 정리해 별점·손님 만족도·오늘의 미션을 동일 높이의 한 행으로 묶고, 사운드·도움말은 상태 카드 안의 작은 보조 버튼으로 이동했다. 보이는 버튼은 24px로 줄였지만 실기기 터치 영역은 44px로 유지하고 서로 겹치지 않도록 회귀 테스트로 고정했다.

## 2026-07-18

- 스펀지 전용 오물로 보이던 줄무늬 사각 `sticker`를 실제 세차 흐름에 맞는 `road_grime`(도로 때)으로 교체했다. 도로 때는 불규칙한 반투명 회갈색 얼룩으로 그리며, 마른 상태에서 바로 문지르지 않고 고압수 또는 비누로 불린 뒤 스펀지로 제거한다.

## 2026-07-17

- **AIT "Gemini API 키" 반려의 진짜 원인 확정 — 앱인토스 정적 분석의 오탐**. 아래 07-14의 가설들(Firebase 키/GA4/생성형 AI 정책)은 모두 헛다리였고, 이 항목이 최종 결론이다.
- **근거**: (1) 콘솔 `review_get`상 반려는 `AUTO_REJECTED`(1~4초)이고 매 재제출마다 동일 재검출 — 무키 v1.3.3, 검증 클린본 모두 동일 반려. (2) 승인된 형제 Godot 게임(루시드 체스 4.6.3, 리버시 4.6)은 **동일 엔진 wasm**을 쓰는데도 통과 — 6월 승인으로 규칙 추가(최근) 이전. (3) 앱인토스 담당자 커뮤니티 답변: *"`AQ.*` 패턴의 Gemini API Key를 코드에 넣는 걸 최근 정적 분석에서 걸리게 했는데, 일부 js obfuscation 과정에서 동일 패턴이 있다. 길이 조건 체크해서 통과되도록 하겠다."*
- **트리거 위치 특정**: 번들 전체에서 `AQ.` 패턴은 **정확히 1곳** — Godot/emscripten 로더 `web/godot/index.js`에 박힌 진단 URL `.../FAQ.html#...`. minify된 한 줄에서 `AQ.`(F**AQ.**html) 접두가 greedy 매칭되어(매치 길이 27만 자) 신형 Gemini 키로 오인됨. 실제 `AIza`/`generativelanguage`/`api_secret`은 0건.
- **조치(B) — 빌드 파이프라인 자체 무력화**: `ait/apps-in-toss-web/scripts/sync-godot-web.mjs`에 `neutralizeGeminiKeyFalsePositive` 추가 — 복사된 로더의 `FAQ.html`→`FAQ_html`로 치환해 `AQ.` 시퀀스를 제거(emscripten abort 진단 문자열이라 런타임 무해). `granite.config.ts`의 `web.commands.build='npm run build:web'` 덕에 `ait build`가 `sync:godot`를 호출하므로 로컬·CI 모두 자동 적용. `check-no-google-api-key.sh`에 신형 `AQ.<base64>` 키 탐지 + `AQ.html` 잔존 시 배포 전 실패 sentinel 추가. 리빌드 후 `.ait`에서 `AQ.` 패턴 0건·가드 통과 검증 완료.
- **조치(A) — 재발 방지 요청**: 앱인토스 개발자 문의/커뮤니티에 오탐(우리도 `FAQ.html` 동일 케이스) + 파이프라인 길이 조건 수정 ETA/그때까지 수동 승인 요청 예정.
- 다음: B 반영 브랜치/PR 후 재제출 → 통과 확인. 통과하면 stash된 Firebase/GA4 애널리틱스 복구 WIP 재개 검토(GA4 `api_secret` 서버 프록시 포함).

## 2026-07-14

- AIT 반려 사유를 조사하고 후속 심사 결과로 가설을 검증했다.
- **미니앱 표기명 불일치**: 콘솔 앱정보 등록명은 `버블 버블 거품 세차`인데 미니앱 표기명이 `폼 파티`였다. `ait/apps-in-toss-web/granite.config.ts`(`brand.displayName`), `ait/apps-in-toss-web/index.html`(title), `apps-in-toss/apps-in-toss.config.json`, `apps-in-toss/registration.md`, `docs/05-markets/apps-in-toss.md`의 한글 표기명을 등록명으로 정정했다. `appName`(`foam-party`)은 내부 식별자라 변경 없음.
- **Gemini 참조 번들 제외 가설**: 런타임 클라이언트/서버에는 Gemini API 사용이 없고, Gemini(`gemini-3-pro-image`) 참조는 디자인 타임 에셋 생성 provenance에만 있었다. 해당 매니페스트와 스타일 원본은 런타임에 불필요해 export에서 제외했지만, 후속 심사에서도 같은 반려 사유가 반복되어 원인은 아니었다.
- **Firebase API Key 탐지 가설 반증**: Firebase Web 공개 설정인 `AIza...` 키가 Gemini 키로 탐지된다고 가정해 Firebase SDK/Remote Config를 제거했으나, 키가 0건인 v1.3.3도 동일 사유로 반려됐다. 동일 워크스페이스의 출시 앱에는 Firebase Web 설정이 포함되어 있어 일반적인 Firebase 키 금지 규칙도 아니다.
- **GA4 설정 탐지 가설 반증**: GA4 Measurement Protocol 설정까지 제거하고 AIT 애널리틱스를 완전히 비활성화했지만 v1.3.3이 동일 사유로 반려됐다.
- **자동 스캐너 확인**: 반려는 사람 리뷰 스레드가 아니라 시스템 자동 체크다(반박 답변 채널 없음, 콘솔에 AI 사용 선언란도 없음). 심사가 "Gemini"를 볼 수 있는 곳은 제출 번들뿐이므로, 번들을 검증 가능하게 클린으로 만들면 통과해야 한다.
- **env 통째 인라인 누수 발견**: Firebase 복구 WIP의 `tossFullScreenAdRuntime.ts`에 `const env = import.meta.env`가 있어 Vite가 전체 `import.meta.env`를 번들에 직렬화했다. 개별 가드를 우회해 `AIza` 키와 `VITE_GA4_MP_API_SECRET`(실제 GA4 비밀값)이 평문 노출됐다. "코드에서 제거 ≠ 번들에서 제거"이므로, 제출 경로가 불확실했던 과거 "클린" 제출본이 실제로는 키를 포함했을 가능성이 있다.
- **결정(A)**: 승인 전까지 Firebase/GA4를 AIT 번들에 넣지 않는다. HEAD의 no-op 스텁 상태에서 `AIza`/`@firebase/ai`/`api_secret` 0건임을 `check:no-google-api-key` 가드로 검증한 `.ait`만 제출한다(검증 통과 확인함). Firebase/GA4 애널리틱스 복구 WIP는 `git stash`(`WIP: AIT Firebase/GA4 애널리틱스 복구 (승인 후 재개)`)에 보존. 복구 시 서버 프록시 없는 클라이언트 GA4 `api_secret`은 리뷰어의 "서버 경유" 지적과 충돌하므로 함께 해결한다.

## 2026-06-16

- `seorilabs/starter-template-game`에서 docs 원장, Clean Architecture scaffold, GitHub Actions 검사 구성을 Foam Party에 맞게 병합했다.
- `Deploy Godot Web Pages` 구조를 추가하고 Godot `Web` export preset을 생성했다.
- GitHub Pages source를 Actions workflow로 활성화했다. URL: `https://seorilabs.github.io/foam-party/`
- Release blocker는 `npm run check:release`에서 inventory로 확인한다.
