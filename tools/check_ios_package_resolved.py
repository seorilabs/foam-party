#!/usr/bin/env python3
"""Validate the exact AdMob Swift Package versions resolved for iOS."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


EXPECTED_VERSIONS = {
    "swift-package-manager-google-mobile-ads": "13.3.0",
    "swift-package-manager-google-user-messaging-platform": "3.1.0",
}


def validate_package_resolved(path: Path) -> dict[str, str]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"iOS Package.resolved 읽기 실패: {path}: {error}") from error

    pins = payload.get("pins")
    if not isinstance(pins, list):
        raise SystemExit(f"iOS Package.resolved pins 누락: {path}")

    resolved: dict[str, str] = {}
    for pin in pins:
        if not isinstance(pin, dict):
            continue
        identity = pin.get("identity")
        state = pin.get("state")
        version = state.get("version") if isinstance(state, dict) else None
        if isinstance(identity, str) and isinstance(version, str):
            resolved[identity] = version

    errors = [
        f"{identity}: expected {expected}, got {resolved.get(identity, 'missing')}"
        for identity, expected in EXPECTED_VERSIONS.items()
        if resolved.get(identity) != expected
    ]
    if errors:
        raise SystemExit("iOS Swift Package 버전 불일치: " + "; ".join(errors))

    return resolved


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("package_resolved", type=Path)
    args = parser.parse_args()
    resolved = validate_package_resolved(args.package_resolved)
    versions = ", ".join(
        f"{identity}={resolved[identity]}" for identity in EXPECTED_VERSIONS
    )
    print(f"iOS Swift Package versions verified: {versions}")


if __name__ == "__main__":
    main()
