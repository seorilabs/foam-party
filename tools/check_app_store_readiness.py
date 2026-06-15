#!/usr/bin/env python3
import argparse
import json
import plistlib
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "app-store" / "app-store.config.json"
EXPORT_PRESETS = ROOT / "godot" / "export_presets.cfg"


def run(command):
    return subprocess.run(
        command,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )


def add(results, name, status, detail):
    results.append({"name": name, "status": status, "detail": detail})


def command_output(command):
    proc = run(command)
    if proc.returncode != 0:
        return None
    return proc.stdout.strip()


def sips_value(path, key):
    proc = run(["sips", "-g", key, str(path)])
    if proc.returncode != 0:
        return None
    for line in proc.stdout.splitlines():
        if line.strip().startswith(f"{key}:"):
            return line.split(":", 1)[1].strip()
    return None


def load_profile(path):
    proc = run(["security", "cms", "-D", "-i", str(path)])
    if proc.returncode != 0:
        return None
    with tempfile.NamedTemporaryFile("wb", delete=False) as tmp:
        tmp.write(proc.stdout.encode())
        tmp_path = Path(tmp.name)
    try:
        with tmp_path.open("rb") as handle:
            return plistlib.load(handle)
    finally:
        tmp_path.unlink(missing_ok=True)


def find_matching_profile(bundle_id, team_id):
    profile_dir = Path.home() / "Library" / "MobileDevice" / "Provisioning Profiles"
    if not profile_dir.exists():
        return None
    expected = f"{team_id}.{bundle_id}"
    wildcard = f"{team_id}.*"
    for path in sorted(profile_dir.glob("*.mobileprovision")):
        profile = load_profile(path)
        if not profile:
            continue
        entitlements = profile.get("Entitlements", {})
        app_identifier = entitlements.get("application-identifier", "")
        provisions_all = not profile.get("ProvisionedDevices")
        if provisions_all and app_identifier in {expected, wildcard}:
            return {
                "path": str(path),
                "name": profile.get("Name"),
                "uuid": profile.get("UUID"),
                "applicationIdentifier": app_identifier,
            }
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true", help="print machine-readable results")
    args = parser.parse_args()

    checks = []
    blockers = []
    warnings = []

    if not CONFIG_PATH.exists():
        add(checks, "config", "blocker", f"missing {CONFIG_PATH.relative_to(ROOT)}")
        config = {}
    else:
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        add(checks, "config", "pass", str(CONFIG_PATH.relative_to(ROOT)))

    app = config.get("app", {})
    build = config.get("build", {})
    assets = config.get("assets", {})
    gates = config.get("releaseGates", {})
    bundle_id = app.get("bundleId", "")
    team_id = build.get("teamId", "")

    if EXPORT_PRESETS.exists() and 'name="iOS"' in EXPORT_PRESETS.read_text(encoding="utf-8"):
        add(checks, "godot-ios-preset", "pass", "iOS preset exists")
    else:
        add(checks, "godot-ios-preset", "blocker", "iOS preset missing")

    godot_version = command_output(["godot", "--version"])
    if godot_version:
        template_key = ".".join(godot_version.split(".")[:3]) + ".stable"
        template_path = Path.home() / "Library" / "Application Support" / "Godot" / "export_templates" / template_key / "ios.zip"
        if template_path.exists():
            add(checks, "godot-ios-template", "pass", str(template_path))
        else:
            add(checks, "godot-ios-template", "blocker", f"missing {template_path}")
    else:
        add(checks, "godot", "blocker", "godot command failed")

    xcode_version = command_output(["xcodebuild", "-version"])
    if xcode_version:
        add(checks, "xcode", "pass", xcode_version.splitlines()[0])
    else:
        add(checks, "xcode", "blocker", "xcodebuild command failed")

    identity_output = command_output(["security", "find-identity", "-v", "-p", "codesigning"]) or ""
    expected_identity = build.get("signingIdentity", "")
    if expected_identity and expected_identity in identity_output:
        add(checks, "apple-distribution-identity", "pass", expected_identity)
    else:
        add(checks, "apple-distribution-identity", "blocker", expected_identity or "missing configured identity")

    if bundle_id and team_id:
        profile = find_matching_profile(bundle_id, team_id)
        if profile:
            add(checks, "app-store-provisioning-profile", "pass", f"{profile['name']} ({profile['uuid']})")
        else:
            add(checks, "app-store-provisioning-profile", "blocker", f"no App Store profile for {bundle_id}")
    else:
        add(checks, "app-store-provisioning-profile", "blocker", "bundleId/teamId missing")

    icon_path = ROOT / assets.get("appStoreIcon", "")
    if icon_path.exists():
        width = sips_value(icon_path, "pixelWidth")
        height = sips_value(icon_path, "pixelHeight")
        has_alpha = sips_value(icon_path, "hasAlpha")
        if width == "1024" and height == "1024" and has_alpha == "no":
            add(checks, "app-store-icon", "pass", "1024x1024, alpha no")
        else:
            add(checks, "app-store-icon", "blocker", f"{width}x{height}, alpha {has_alpha}")
    else:
        add(checks, "app-store-icon", "blocker", f"missing {icon_path.relative_to(ROOT)}")

    screenshot_count = 0
    screenshot_root = ROOT / "app-store" / "screenshots"
    if screenshot_root.exists():
        screenshot_count = len(list(screenshot_root.rglob("*.png")))
    if screenshot_count > 0:
        add(checks, "screenshots", "pass", f"{screenshot_count} png files")
    else:
        add(checks, "screenshots", "blocker", "no App Store screenshots")

    for gate, value in gates.items():
        if isinstance(value, str) and ("확정 필요" in value or value == "미진행"):
            blockers.append({"gate": gate, "value": value})

    for check in checks:
        if check["status"] == "blocker":
            blockers.append({"gate": check["name"], "value": check["detail"]})

    if assets.get("appStoreIconStatus", "").find("600x600") >= 0:
        warnings.append("App Store icon is generated from a 600x600 source; replace with native 1024x1024 art before final submission.")

    result = {
        "ok": len(blockers) == 0,
        "checks": checks,
        "blockers": blockers,
        "warnings": warnings,
    }

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        for check in checks:
            print(f"[{check['status']}] {check['name']}: {check['detail']}")
        if warnings:
            print("\nWarnings:")
            for warning in warnings:
                print(f"- {warning}")
        if blockers:
            print("\nBlockers:")
            for blocker in blockers:
                print(f"- {blocker['gate']}: {blocker['value']}")

    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
