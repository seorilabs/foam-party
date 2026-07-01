# AppsInToss Wrapper

Godot Web export를 AppsInToss(.ait)로 감싸는 web wrapper다.

## 구조

- `granite.config.ts` — AppsInToss 앱 메타(appName, brand, outdir=dist). 빌드 command는 `npm run build:web`.
- `scripts/build-web.sh` — `godot/` 프로젝트를 Godot Web export 해서 `dist/` 로 산출한다.
- `package.json`
  - `build:web` — Godot Web export → `dist/`
  - `lint` — `tsc --noEmit` (granite.config.ts 타입 체크)
  - `build` — `ait build` (`dist/` 를 `.ait` 로 패키징)
  - `deploy` — `ait deploy`

## 배포

org 재사용 워크플로우 `godot-deploy-ait.yml` 이 caller `deploy-apps-in-toss.yml`(`wrapper_dir: apps/ait`)를 통해
`npm ci` → `npm run lint` → `npm run build` → `npm run deploy -- --api-key <APPS_IN_TOSS_API_KEY> --memo <...>`
순서로 실행한다. 러너는 `seorilabs-rpi-arm64`(ARC).

## 로컬

```bash
cd apps/ait
npm ci
npm run lint
npm run build   # Godot(4.6.3 stable) + web export 템플릿 필요
```
