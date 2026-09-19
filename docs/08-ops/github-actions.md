# GitHub Actions

## Workflows

- `Godot Checks`: main/PR 정적 게이트. Godot import·compile·smoke scene과 core, architecture, workflows, docs 검사.
- `Deploy Godot Web Pages`: Godot Web export를 GitHub Pages로 배포. 명시적 dispatch로만 실행한다.
- `Deploy AppsInToss` / `Deploy Google Play` / `Deploy All`: 릴리즈 태그 대상 마켓 배포. dispatch 전용.
- `Deploy App Store`: Godot iOS export → Xcode archive → App Store Connect 업로드. GitHub-hosted `macos-26`에서 실행한다.
- `Release Tag` / `Release Inventory` / `Cleanup Actions Storage`: 태그 생성, 릴리즈 blocker 인벤토리, Actions 스토리지 정리.

## GitHub Pages

- Source: GitHub Actions workflow
- URL: `https://seorilabs.github.io/foam-party/`
- Enabled: 2026-06-16 via GitHub Pages API

## Runner Routing

- 러너는 repo 가시성에 따라 갈린다. workflow에 `github.event.repository.private` 가드를 둬서 private이면 ARC, public이면 `ubuntu-latest`로 보낸다.
- Godot compile, Godot Web build, 일반 repo checks: `seorilabs-x64` ↔ `ubuntu-latest`.
- Android release build: `aapt2`가 x86-64 binary라 x64 Linux가 필요하다. 중앙 워크플로우가 `ubuntu-latest`를 쓰며 RPI ARC로 보내지 않는다.
- App Store build는 macOS가 필요하므로 ARC로 보내지 않고 GitHub-hosted `macos-26`을 쓴다. public 저장소라 표준 러너가 무료다.
- public 경로에는 Seorilabs private ARC runner를 노출하지 않는다. 러너가 고정된 재사용 워크플로우를 호출할 때도 caller가 `runs_on` 가드를 넘겨 public fallback을 유지한다.

## Central Source

- org 재사용 워크플로우는 `seorilabs/.github`에 있고, caller는 `@main`으로 호출한다. 중앙 정본이 곧 실행되는 정의다. SHA로 pin하지 않는다.
- runner 이름, Node/Godot 버전, action 버전의 shared source of truth는 org 운영 저장소의 `global-versions.yaml`이다. 위치와 최신값은 `seorilabs-arc-runners` 스킬로 확인한다.
- 수치는 운영 중 바뀌므로 workflow 수정 전에 중앙 파일을 다시 확인한다. 아래는 2026-06-16 확인값이다.

- `actions/checkout@v6`
- `actions/setup-node@v6`
- `actions/configure-pages@v6`
- `actions/upload-pages-artifact@v5`
- `actions/deploy-pages@v5`
- `actions/upload-artifact@v7`
- `seorilabs-x64`
- Godot `4.6.3.stable`
- Node `24.16.0`
