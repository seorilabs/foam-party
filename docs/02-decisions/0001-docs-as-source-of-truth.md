# ADR 0001: Docs As Source Of Truth

## Status

Accepted

## Context

Foam Party는 Godot gameplay, App Store 준비 문서, 향후 Google Play/AppsInToss/Firebase 후보가 함께 존재한다. 콘솔 상태나 대화 기록만으로는 릴리스 준비 상태를 재현하기 어렵다.

## Decision

제품 실행 원장은 `docs/`와 repo-local config에 둔다.

- 기획: `docs/01-planning/`
- 아키텍처: `docs/03-architecture/`
- 마켓/플랫폼: `docs/05-markets/`, `app-store/`, `play-store/`, `apps-in-toss/`
- 릴리스 gate: `docs/06-release/`
- 운영/CI: `docs/08-ops/`

Obsidian은 프로젝트 간 재사용 가능한 운영 노하우를 보조 기록하는 위치로 둔다.

## Consequences

- 새 콘솔 값이나 release blocker는 repo 문서 또는 config에 반영해야 한다.
- 모르는 값은 `확정 필요`로 남기며 추정으로 채우지 않는다.
- `npm run check:docs`와 `npm run check:release`가 문서 구조와 blocker inventory를 검증한다.
