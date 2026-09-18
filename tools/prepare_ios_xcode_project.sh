#!/usr/bin/env bash
# Godot iOS export 직후, archive 직전에 실행한다.
#
# Godot 이 만든 .xcodeproj 는 그대로 archive 되지 않는다. 두 가지를 여기서 끝낸다.
#
# 1) AdMob pbxproj 패치
#    AdMob export 플러그인은 pbxproj 패치를 call_deferred 로 예약하는데 headless
#    export 는 deferred 콜을 처리하기 전에 종료한다. 그러면 PoingGodotAdMobDeps
#    (→ GoogleMobileAds/UMP) 가 링크되지 않아 GAD*/UMP* Undefined symbol 로
#    archive 가 실패한다. Package.swift 와 PoingGodotAdMobDeps 자체는 export 시
#    동기로 생성되므로 pbxproj 만 결정론적으로 패치하면 된다.
#
# 2) SwiftPM lockfile 고정
#    lockfile 없이 resolver 를 돌리면 빌드마다 의존 버전이 달라질 수 있다. SwiftPM
#    CLI 로 Package.resolved 를 만들어 Xcode workspace 에 넣고, exact 버전만 쓰도록
#    요구한다.
#
# 호출부(org godot-deploy-app-store.yml)가 XCODE_PROJECT 로 export 된 .xcodeproj
# 경로를 넘긴다. 로컬에서 직접 돌릴 때는 기본값을 쓴다.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
xcode_project="${XCODE_PROJECT:-${repo_root}/build/ios/foam-party.xcodeproj}"
case "$xcode_project" in
  /*) ;;
  *) xcode_project="${repo_root}/${xcode_project}" ;;
esac

[ -d "$xcode_project" ] || {
  echo "[ios-prepare] .xcodeproj 가 없다: ${xcode_project}" >&2
  exit 1
}

scheme="$(basename "$xcode_project" .xcodeproj)"
package_dir="$(dirname "$xcode_project")"

echo "[ios-prepare] AdMob SPM 로컬 패키지를 Xcode 프로젝트에 링크"
python3 "${repo_root}/tools/patch_ios_admob_project.py" "${xcode_project}/project.pbxproj"

echo "[ios-prepare] SwiftPM lockfile 생성"
swift package --package-path "$package_dir" resolve
swift_resolved="${package_dir}/Package.resolved"
[ -f "$swift_resolved" ] || {
  echo "[ios-prepare] SwiftPM lockfile 이 생성되지 않았다: ${swift_resolved}" >&2
  exit 1
}

resolved_dir="${xcode_project}/project.xcworkspace/xcshareddata/swiftpm"
mkdir -p "$resolved_dir"
cp "$swift_resolved" "${resolved_dir}/Package.resolved"

echo "[ios-prepare] Xcode 에 lockfile 의 exact 버전만 사용하도록 고정"
xcodebuild \
  -resolvePackageDependencies \
  -project "$xcode_project" \
  -scheme "$scheme" \
  -onlyUsePackageVersionsFromResolvedFile

[ -f "${resolved_dir}/Package.resolved" ] || {
  echo "[ios-prepare] Xcode lockfile 이 사라졌다: ${resolved_dir}/Package.resolved" >&2
  exit 1
}
python3 "${repo_root}/tools/check_ios_package_resolved.py" "${resolved_dir}/Package.resolved"

echo "[ios-prepare] 완료 (scheme=${scheme})"
