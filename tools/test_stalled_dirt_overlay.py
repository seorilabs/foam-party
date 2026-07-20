#!/usr/bin/env python3
"""Structural regression tests for the late-cleaning car-surface overlay."""

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN_SOURCE = (ROOT / "godot/scripts/main.gd").read_text(encoding="utf-8")
RULE_SOURCE = (
    ROOT / "packages/product-core/src/use_cases/stalled_dirt_highlight.gd"
).read_text(encoding="utf-8")
SCREENSHOT_SOURCE = (ROOT / "godot/tests/screenshot_scene.gd").read_text(
    encoding="utf-8"
)


def godot_function(source, name):
    match = re.search(
        rf"^func {re.escape(name)}\([^\n]*\).*?(?=^func |\Z)",
        source,
        flags=re.MULTILINE | re.DOTALL,
    )
    if match is None:
        raise AssertionError(f"Godot function not found: {name}")
    return match.group(0)


class StalledDirtOverlayContractTest(unittest.TestCase):
    def test_trigger_rule_stays_engine_independent(self):
        self.assertIn("extends RefCounted", RULE_SOURCE)
        self.assertIn("static func should_show", RULE_SOURCE)
        self.assertIn("static func cleaning_resumed", RULE_SOURCE)
        self.assertNotRegex(RULE_SOURCE, r"\b(Node|Control|CanvasItem|SceneTree)\b")

    def test_overlay_is_called_only_from_dirt_pass(self):
        dirt_pass = godot_function(MAIN_SOURCE, "_draw_dirt")
        renderer = godot_function(MAIN_SOURCE, "_draw_stalled_dirt_highlight")
        self.assertIn("_draw_stalled_dirt_highlight(", dirt_pass)
        self.assertEqual(MAIN_SOURCE.count("_draw_stalled_dirt_highlight("), 2)
        self.assertNotIn("draw_string", renderer)
        self.assertNotIn("Popup", renderer)

    def test_dirt_pass_runs_before_hud_and_toolbar(self):
        root_draw = godot_function(MAIN_SOURCE, "_draw")
        dirt_index = root_draw.index("_draw_dirt()")
        self.assertLess(root_draw.index("_set_design_draw_transform(transition_offset)"), dirt_index)
        self.assertLess(dirt_index, root_draw.index("_set_design_draw_transform()", dirt_index))
        self.assertLess(dirt_index, root_draw.index("_draw_toolbar()"))

    def test_full_frame_fixture_captures_isolated_faint_patch(self):
        self.assertIn("_isolate_stalled_dirt_patch(node)", SCREENSHOT_SOURCE)
        self.assertIn('raw_patch.set("health", float(raw_patch.get("max_health")) * 0.08)', SCREENSHOT_SOURCE)
        self.assertIn('shot_stalled_dirt_highlight.png', SCREENSHOT_SOURCE)


if __name__ == "__main__":
    unittest.main(verbosity=2)
