#!/usr/bin/env python3
"""Validate the committed Godot art manifest as JSON with a POSIX EOF newline."""

from __future__ import annotations

import json
from pathlib import Path
import sys


def validate(manifest_path: Path) -> None:
    raw = manifest_path.read_bytes()
    if not raw.endswith(b"\n"):
        raise ValueError(f"{manifest_path} must end with a newline")
    json.loads(raw.decode("utf-8"))


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_asset_manifest.py PATH", file=sys.stderr)
        return 2
    manifest_path = Path(sys.argv[1])
    try:
        validate(manifest_path)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
        print(f"Asset manifest check failed: {error}", file=sys.stderr)
        return 1
    print(f"Asset manifest check passed: {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
