# Autopilot (자율 이슈 처리 루틴) — foam-party 가이드

클라우드 autopilot 루틴이 foam-party의 열린 이슈를 자율적으로 해결할 때 읽는 repo 전용 가이드다. 이 문서는 foam-party에만 해당하는 실행 정보를 담고, 절차 자체는 org 공통 계약을 참조한다.

## 적용 계약

- **순차 드레인 루프(A~E)와 서리봇 리뷰·머지 절차**: `seorilabs/.github`의 [`docs/agent-governance/autonomous-issue-routine.md`](https://github.com/seorilabs/.github/blob/main/docs/agent-governance/autonomous-issue-routine.md)를 따른다. 루틴 실행 시 `.github` 레포가 함께 체크아웃되므로 로컬 파일로 읽는다.
- **PR 계약**: `seorilabs/.github`의 [`docs/agent-governance/agent-contribution-contract.md`](https://github.com/seorilabs/.github/blob/main/docs/agent-governance/agent-contribution-contract.md).
- 이 가이드와 org 계약이 충돌하면 **이 가이드가 우선**한다.
- 저장소 공통 규약(source-of-truth, 구조 경계, 배포 게이트)은 루트 [`AGENTS.md`](../../AGENTS.md)를 함께 읽는다.

## 스택 / 구조 맵

- **엔진**: Godot 4.6 (`godot/`). scene tree·rendering·input·animation·lifecycle은 여기.
- **엔진 독립 core**: `packages/product-core` — 규칙·유스케이스·포트·순수 테스트만. Godot/Firebase/광고/결제/네트워크를 직접 import하지 않는다.
- **시장별 어댑터**: `play-store/`, `app-store/`, `apps-in-toss/`, `apps/ait/`, `firebase/`.
- **보조 도구**: `tools/`(Python 검증기), `scripts/`(bash 게이트).
- 경계 원칙 상세는 `AGENTS.md`의 "구조 원칙" 참조.

## 게이트 · 검증 명령 (npm — pnpm 아님)

- **통합 게이트**: `npm run test` — `test:core` + `check:architecture` + `check:stalled-dirt-overlay` + `check:customer-presentation` + `check:workflows` + `check:native-ads` + `test:godot` + `check:docs`를 순차 실행.
- 변경 종류별 최소 게이트:
  - core 규칙/유스케이스 변경 → `npm run test:core`, `npm run check:architecture`
  - Godot scene/스크립트 변경 → `npm run test:godot`
  - docs 변경 → `npm run check:docs`
  - 워크플로/네이티브 광고/iOS AdMob 패치 관련 → 대응 `check:*`
- **릴리스 인벤토리**(`npm run check:release`, `npm run check:app-store`)는 릴리스 승인 전에는 참고만 하고, 이 값을 바꾸는 작업은 배포 게이트에 해당한다.
- `test:godot`는 Godot headless exit code만 믿지 말고 로그의 `SCRIPT ERROR` / `ERROR:`도 실패로 처리한다.

## Godot 바이너리 확보 (클라우드 샌드박스)

- 레포 제공 스크립트를 사용한다: `bash scripts/ensure_godot.sh` (필요 시 `--with-export-templates`). Godot 4.6 계열을 확보해 PATH에 노출한다.
- 확보 실패로 `test:godot`가 막히면 그 단계는 "실행 불가(리뷰 위임)"로 PR에 명시하고, headless로 가능한 나머지 게이트(`test:core`, `check:architecture`, `check:docs`, Python `check:*`)는 실행·기록한다.

## 우선순위 축 (같은 P 라벨대 안에서)

**잔존·리텐션(`evidence:ga4`) > 밸런스·경제 > 기능·컨텐츠 > 시각·UX.**
- `evidence:ga4`/`instrumentation` 라벨 이슈는 지표 근거가 이미 붙어 있으니 근거를 인수조건 검증에 활용한다.

## i18n

- 지원 로케일: **ko / en**. 사용자 노출 문자열을 추가하면 두 로케일을 함께 갱신한다.
- 런타임 번역은 `TranslationServer` 기반. 캔버스 텍스트는 `draw_string`에 원문을 직접 넣지 말고 `tr()`로 키를 조회한다.
- 한글 렌더용 번들 폰트는 Do Hyeon. 새 폰트를 임의로 추가하지 않는다.

## 아트 에셋

- style anchor/manifest는 **재생성 금지**. 스타일 일관성의 기준이므로 건드리지 않는다.
- 신규 에셋은 anchor를 기준으로 파이프라인을 통해 추가만 한다.

## IA / 화면 밀도

- 신규 UI·정보는 메인 화면 상시 영역(HUD)에 계속 쌓지 말고 시트/탭/팝업 등 한 뎁스 뒤로 분리한다.
- 이슈 인수조건에 UI 거주 위치가 없으면 상시 HUD 추가보다 시트/팝업 배치를 기본값으로 택한다.

## Source of Truth

- 제품 원장(기획·의사결정·마켓·릴리스 상태)은 `docs/`. 작업 로그는 `docs/04-work/`.
- 콘솔에서만 바뀐 값은 release-ready로 보지 않는다(`AGENTS.md`의 "Source Of Truth" 참조).

## 라벨

- 라벨 체계·우선순위·`no-autopilot`/`blocked` 처리는 org 공통 계약과 동일하다.
- 현재 foam-party에 `no-autopilot`·`blocked` 라벨은 생성돼 있지 않다. 필요한 이슈가 생기면 GitHub에서 생성한다. `-label:no-autopilot` 검색은 라벨이 없어도 무해히 전체를 반환한다.
