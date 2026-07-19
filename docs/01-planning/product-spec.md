# Foam Party Product Spec

## 기본 정보

- Korean app name: 폼 파티
- English app name: Foam Party
- Genre: mobile-first casual car wash game
- Engine: Godot 4.6.3
- Project path: `godot/`
- Main scene: `res://scenes/main.tscn`
- One-line pitch: 도구를 바꿔 쓰며 더러워진 카툰 차량을 빠르게 세차하는 캐주얼 게임.
- Target audience: 짧은 세션으로 즉시 이해 가능한 모바일 캐주얼 게임 이용자.
- Monetization: 현재 MVP는 유료화 없음. 후속 후보는 보상형 광고 기반 부스터.

## 핵심 루프

1. 흙탕물, 먼지, 낙엽, 벌레 자국, 오일 얼룩, 새똥, 도로 때가 붙은 차량이 등장한다.
2. 플레이어가 바람, 고압수, 비누, 스펀지 도구를 선택한다.
3. 차 위를 드래그하면 이물질 종류와 상태에 맞는 효과가 적용된다.
4. 빠르게 연속 제거하면 콤보가 쌓이고 완료 시 별점과 코인을 받는다.
5. 다음 차량으로 넘어가며 오물 수와 체력이 점진적으로 오른다.

## MVP Scope

- Must-have: title flow, tutorial, cleaning tools, dirt state transitions, combo, star rating, coins, foam bomb, local save, Godot smoke test.
- Should-have: App Store iOS export path, App Store metadata source, screenshot capture helper.
- Out of scope: Firebase, account, cloud save, ads SDK, IAP, Google Play release automation, AppsInToss wrapper.

## 현재 구현 상태

- MVP gameplay는 `godot/scripts/main.gd`에 집중되어 있다.
- smoke test는 `res://tests/smoke_scene.gd`다.
- App Store 준비 문서는 `docs/app-store-registration.md`, `docs/app-store-release.md`, `app-store/app-store.config.json`에 있다.
- 자세한 게임 스펙은 기존 문서 `docs/game-spec.md`를 보존한다.

## 승인

- Planning approval status: 기존 MVP 개발 승인 상태로 간주.
- Deployment approval status: Google Play production `1.0.0` 출시는 2026-07-18 사용자 승인 완료. App Store와 AppsInToss production 승인은 별도다.
- Deployment approval 전에는 store submission, production promotion, AppsInToss production release를 진행하지 않는다.
