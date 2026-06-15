# GitHub Actions

## Workflows

- `Godot Compile`: Godot import, compile, smoke scene.
- `Repository Checks`: core, architecture, docs checks.
- `Deploy Godot Web Pages`: `main` push 후 Godot Web export를 GitHub Pages로 배포.
- `Release Inventory`: manual release blocker inventory.

## GitHub Pages

- Source: GitHub Actions workflow
- URL: `https://seorilabs.github.io/foam-party/`
- Enabled: 2026-06-16 via GitHub Pages API

## Runner Routing

- `foam-party`는 private repo다.
- private repo에서는 Godot compile, Godot Web build, 일반 repo checks에 `seorilabs-rpi-arm64`를 사용한다.
- workflow에는 `github.event.repository.private` 조건을 둬 public fallback은 `ubuntu-latest`로 남긴다.
- public PR path에는 Seorilabs private ARC runner를 노출하지 않는다.
- Android release build와 App Store build는 RPI ARC로 보내지 않는다.

## Central Source

수정 전 확인:

```bash
cat /Users/syous/Workspace/kubectl/github-actions-runners/global-versions.yaml
```

2026-06-16 확인값:

- `actions/checkout@v6`
- `actions/setup-node@v6`
- `actions/configure-pages@v6`
- `actions/upload-pages-artifact@v5`
- `actions/deploy-pages@v5`
- `actions/upload-artifact@v7`
- `seorilabs-rpi-arm64`
- Godot `4.6.3.stable`
- Node `24.16.0`

수치는 운영 중 바뀔 수 있으므로 workflow 수정 전 중앙 파일을 다시 확인한다.
