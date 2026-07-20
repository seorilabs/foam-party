# Release Checklist

## Common

- [ ] `npm run test:core`
- [ ] `npm run check:architecture`
- [ ] `npm run test:godot`
- [ ] `npm run check:docs`
- [ ] `npm run build:godot:web`
- [ ] `npm run check:release`
- [ ] Privacy/policy answers confirmed
- [ ] Release notes confirmed

## Google Play

- [ ] Play Console `Account Details` 한국 법률 추가 정보 완료 및 403 해소
- [ ] AAB built on x64 Linux release path
- [ ] Signing confirmed
- [ ] Internal testing upload ready
- [ ] Data safety confirmed
- [ ] 승인된 태그로 `google_play_track=production`, `google_play_release_status=completed` dispatch
- [ ] Android Publisher API 또는 Play Console에서 production versionName/versionCode/status readback

## App Store

- [ ] `npm run check:app-store`
- [ ] Xcode/macOS build path confirmed
- [ ] Signing/provisioning confirmed
- [ ] TestFlight notes ready
- [ ] Privacy labels confirmed
- [ ] Screenshot set captured

## AppsInToss

- [ ] Godot Web export ready
- [ ] Wrapper build ready
- [ ] `.ait` artifact generated
- [ ] Sandbox QA completed
- [ ] Registration images ready

## GitHub Pages

- [x] GitHub Pages source is Actions workflow
- [ ] `Deploy Godot Web Pages` succeeds on `main`
- [ ] Published URL smoke-tested
