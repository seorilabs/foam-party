#!/usr/bin/env python3
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXPECTED_FTUE_EVENT_CONTRACT = {
    "title_screen_view": (
        "`entry`(`cold_start` \\| `pause_home`)",
        "최초 타이틀 진입 또는 플레이 중 홈 복귀",
    ),
    "level_load_start": ("`level`, `reason`", "보드 준비 시작"),
    "level_load_complete": (
        "`level`, `car_type`, `reason`",
        "오염 배치와 초기 진행도 계산 완료",
    ),
    "play_tap": ("`level`", "타이틀의 플레이 버튼 탭"),
    "tutorial_step_view": (
        "`step`(`overview`), `source`",
        "단일 화면 세차 가이드 표시",
    ),
    "tutorial_complete": (
        "`step`(`overview`), `source`",
        "표시된 세차 가이드 닫기",
    ),
}
EXPECTED_FTUE_FUNNEL = [
    "first_open",
    "title_screen_view",
    "level_load_complete",
    "play_tap",
    "level_start",
    "tutorial_complete",
]


class AnalyticsDocsContractTest(unittest.TestCase):
    # AC-4: parse the Markdown table and compare the complete event contract,
    # rather than accepting documents that merely mention the event names.
    def test_docs_analytics_events_records_exact_ftue_event_contract(self) -> None:
        document_path = ROOT / "docs" / "analytics-events.md"
        document = document_path.read_text(encoding="utf-8")
        ftue_section = document.split("## FTUE 퍼널 이벤트", 1)[1].split(
            "\n## ", 1
        )[0]
        actual_contract: dict[str, tuple[str, str]] = {}
        for line in ftue_section.splitlines():
            if not line.startswith("| `"):
                continue
            columns = [
                column.strip()
                for column in re.split(r"(?<!\\)\|", line.strip().strip("|"))
            ]
            event_name = columns[0].strip("`")
            actual_contract[event_name] = (columns[1], columns[2])

        self.assertEqual(EXPECTED_FTUE_EVENT_CONTRACT, actual_contract)

    # AC-4: attribute the funnel to GA4 app_info.version and compare every step
    # in the documented BigQuery analysis order.
    def test_docs_analytics_events_records_exact_versioned_funnel_order(self) -> None:
        document_path = ROOT / "docs" / "analytics-events.md"
        document = document_path.read_text(encoding="utf-8")
        ftue_section = document.split("## FTUE 퍼널 이벤트", 1)[1].split(
            "\n## ", 1
        )[0]
        attribution_line = next(
            line
            for line in ftue_section.splitlines()
            if "따라서 BigQuery에서는" in line
        )
        backtick_values = re.findall(r"`([^`]+)`", attribution_line)
        self.assertEqual(
            ["release_version", "app_info.version", "app_info.id"],
            backtick_values[:3],
        )
        self.assertEqual(EXPECTED_FTUE_FUNNEL, backtick_values[3].split(" → "))


if __name__ == "__main__":
    unittest.main(verbosity=2)
