#!/usr/bin/env python3
import json
import os
import re
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEPLOY_ALL = ROOT / ".github" / "workflows" / "deploy-all.yml"
GOOGLE_PLAY_DOC = ROOT / "docs" / "05-markets" / "google-play.md"


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def block_for(lines: list[str], path: tuple[str, ...]) -> tuple[int, int, int]:
    start = 0
    end = len(lines)
    indent = 0
    for key in path:
        target = f"{' ' * indent}{key}:"
        index = next(
            (
                candidate
                for candidate in range(start, end)
                if lines[candidate].rstrip() == target
            ),
            None,
        )
        if index is None:
            raise AssertionError(f"missing YAML block {'.'.join(path)}")
        child_end = end
        for candidate in range(index + 1, end):
            stripped = lines[candidate].strip()
            if stripped and not stripped.startswith("#") and indent_of(lines[candidate]) <= indent:
                child_end = candidate
                break
        start = index + 1
        end = child_end
        indent += 2
    return start, end, indent


def scalar(lines: list[str], path: tuple[str, ...], key: str) -> str:
    start, end, indent = block_for(lines, path)
    prefix = f"{' ' * indent}{key}:"
    for line in lines[start:end]:
        if line.startswith(prefix):
            return line[len(prefix) :].strip().strip('"')
    raise AssertionError(f"missing YAML value {'.'.join((*path, key))}")


class ReleaseWorkflowContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.workflow_lines = DEPLOY_ALL.read_text(encoding="utf-8").splitlines()

    def test_deploy_all_forwards_google_play_inputs(self) -> None:
        reusable_path = ("jobs", "google-play", "with")
        self.assertEqual(
            {
                "track": scalar(self.workflow_lines, reusable_path, "track"),
                "release_status": scalar(
                    self.workflow_lines, reusable_path, "release_status"
                ),
            },
            {
                "track": "${{ inputs.google_play_track }}",
                "release_status": "${{ inputs.google_play_release_status }}",
            },
        )

    def test_deploy_all_exposes_track_and_status_choices(self) -> None:
        track_path = ("on", "workflow_dispatch", "inputs", "google_play_track")
        status_path = (
            "on",
            "workflow_dispatch",
            "inputs",
            "google_play_release_status",
        )
        self.assertEqual(
            {
                "google_play_track": {
                    "type": scalar(self.workflow_lines, track_path, "type"),
                    "default": scalar(self.workflow_lines, track_path, "default"),
                    "options": scalar(
                        self.workflow_lines, track_path, "options"
                    ).replace(" ", ""),
                },
                "google_play_release_status": {
                    "type": scalar(self.workflow_lines, status_path, "type"),
                    "default": scalar(self.workflow_lines, status_path, "default"),
                    "options": scalar(
                        self.workflow_lines, status_path, "options"
                    ).replace(" ", ""),
                },
            },
            {
                "google_play_track": {
                    "type": "choice",
                    "default": "internal",
                    "options": "[internal,production]",
                },
                "google_play_release_status": {
                    "type": "choice",
                    "default": "completed",
                    "options": "[draft,completed]",
                },
            },
        )

    def test_production_documentation_covers_account_gate(self) -> None:
        release_doc = GOOGLE_PLAY_DOC.read_text(encoding="utf-8")
        for required_text in (
            "Play Console `Account Details`",
            "`google_play_track=production`",
            "`google_play_release_status=completed`",
            "403",
        ):
            with self.subTest(required_text=required_text):
                self.assertIn(required_text, release_doc)

    def test_workflows_only_run_existing_npm_scripts(self) -> None:
        """워크플로가 부르는 npm script 가 package.json 에 실제로 있어야 한다.

        CI 의 check_command 목록과 package.json 은 서로 다른 파일이라 한쪽만 고치면
        드리프트가 난다. 로컬 `npm test` 는 자기 체인만 돌아서 이 어긋남을 못 잡고,
        push 한 뒤 CI 에서 "Missing script" 로 터진다.
        """
        scripts = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))["scripts"]
        pattern = re.compile(r"npm(?:\s+--prefix\s+\S+)?\s+run\s+([A-Za-z0-9:_-]+)")
        missing = []
        for workflow in sorted((ROOT / ".github" / "workflows").glob("*.yml")):
            text = workflow.read_text(encoding="utf-8")
            for match in pattern.finditer(text):
                name = match.group(1)
                # --prefix 로 다른 패키지를 가리키는 호출은 그 패키지가 소유한다.
                if "--prefix" in match.group(0):
                    continue
                if name not in scripts:
                    missing.append(f"{workflow.name}: npm run {name}")
        self.assertEqual(missing, [], "package.json 에 없는 npm script 를 호출한다: " + ", ".join(missing))

    def test_actionlint_accepts_all_workflows(self) -> None:
        actionlint_bin = os.environ.get("ACTIONLINT_BIN")
        self.assertTrue(actionlint_bin, "ACTIONLINT_BIN must be set by check_workflows.sh")
        workflow_files = sorted((ROOT / ".github" / "workflows").glob("*.yml"))
        self.assertGreater(len(workflow_files), 0, "workflow inventory must not be empty")
        result = subprocess.run(
            [actionlint_bin, *(str(path) for path in workflow_files)],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
