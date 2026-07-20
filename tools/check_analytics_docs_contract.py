#!/usr/bin/env python3
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ANALYTICS_DOC = ROOT / "docs" / "analytics-events.md"


class AnalyticsDocsContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.document = ANALYTICS_DOC.read_text(encoding="utf-8")

    def test_ftue_event_contract_is_documented(self) -> None:
        for event_name in (
            "title_screen_view",
            "level_load_start",
            "level_load_complete",
            "play_tap",
            "tutorial_step_view",
            "tutorial_complete",
            "app_info.version",
        ):
            with self.subTest(event_name=event_name):
                self.assertIn(event_name, self.document)

    def test_ftue_funnel_order_is_documented(self) -> None:
        self.assertIn(
            "first_open → title_screen_view → level_load_complete → "
            "play_tap → level_start → tutorial_complete",
            self.document,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
