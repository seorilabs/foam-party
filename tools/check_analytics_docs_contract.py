#!/usr/bin/env python3
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ANALYTICS_DOC = ROOT / "docs" / "analytics-events.md"


class AnalyticsDocsContractTest(unittest.TestCase):
    # AC-4: docs/analytics-events.md records every FTUE event contract and the
    # BigQuery funnel order used to analyze first_open -> level_start drop-off.
    def test_docs_analytics_events_records_ftue_contract_and_funnel_order(self) -> None:
        document = ANALYTICS_DOC.read_text(encoding="utf-8")
        self.assertIn("## FTUE 퍼널 이벤트", document)
        self.assertIn("| `title_screen_view`", document)
        self.assertIn("| `level_load_start`", document)
        self.assertIn("| `level_load_complete`", document)
        self.assertIn("| `play_tap`", document)
        self.assertIn("| `tutorial_step_view`", document)
        self.assertIn("| `tutorial_complete`", document)
        self.assertIn("`app_info.version`", document)
        self.assertIn(
            "first_open → title_screen_view → level_load_complete → "
            "play_tap → level_start → tutorial_complete",
            document,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
