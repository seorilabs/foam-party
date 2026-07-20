#!/usr/bin/env python3
"""Structural contracts for the procedural customer presentation."""

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MAIN_SOURCE = (ROOT / "godot/scripts/main.gd").read_text(encoding="utf-8")
CORE_TEST_SOURCE = (ROOT / "godot/tests/core_test.gd").read_text(encoding="utf-8")
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


class CustomerPresentationContractTest(unittest.TestCase):
    def test_profiles_rotate_by_car_type_and_level_deterministically(self):
        test_rule = godot_function(
            CORE_TEST_SOURCE, "_test_customer_presentation_rule"
        )
        self.assertIn("GameConfig.car_type_for_level(level)", test_rule)
        self.assertIn("profile_index(car_type, level)", test_rule)
        self.assertIn("first_rotation.has(profile_index)", test_rule)
        self.assertIn("first_rotation.size() < 3", test_rule)
        self.assertIn(
            "first_profile != CustomerPresentation.profile_for(car_type, level)",
            test_rule,
        )

    def test_customer_render_uses_procedural_primitives_without_images(self):
        render_source = "\n".join(
            [
                godot_function(MAIN_SOURCE, "_draw_customer_accessory"),
                godot_function(MAIN_SOURCE, "_draw_completion_customer_reaction"),
            ]
        )
        for primitive in [
            "draw_circle",
            "draw_arc",
            "draw_line",
            "draw_colored_polygon",
            "_draw_star",
        ]:
            self.assertIn(primitive, render_source)
        self.assertNotRegex(
            render_source,
            r"\b(load|preload|draw_texture|Texture2D|Sprite2D|AnimatedSprite2D)\b",
        )

    def test_visual_fixture_captures_all_star_reactions(self):
        self.assertIn("for stars in [1, 2, 3]", SCREENSHOT_SOURCE)
        self.assertIn(
            'shot_customer_reaction_%d_star.png" % stars', SCREENSHOT_SOURCE
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
