#!/usr/bin/env python3
"""Regression tests for the committed Godot art manifest format checker."""

from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from check_asset_manifest import validate


class AssetManifestTest(unittest.TestCase):
    def _write_fixture(self, raw: bytes) -> Path:
        fixture_dir = tempfile.TemporaryDirectory()
        self.addCleanup(fixture_dir.cleanup)
        fixture_path = Path(fixture_dir.name) / "asset-manifest.json"
        fixture_path.write_bytes(raw)
        return fixture_path

    def test_valid_json_with_newline_passes(self) -> None:
        validate(self._write_fixture(b'{"assets": []}\n'))

    def test_missing_eof_newline_fails(self) -> None:
        with self.assertRaisesRegex(ValueError, "must end with a newline"):
            validate(self._write_fixture(b'{"assets": []}'))

    def test_malformed_json_fails(self) -> None:
        with self.assertRaises(json.JSONDecodeError):
            validate(self._write_fixture(b'{"assets": [}\n'))


if __name__ == "__main__":
    unittest.main(verbosity=2)
