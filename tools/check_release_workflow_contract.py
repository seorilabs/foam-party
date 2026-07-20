#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEPLOY_ALL = ROOT / ".github" / "workflows" / "deploy-all.yml"
GOOGLE_PLAY_DOC = ROOT / "docs" / "05-markets" / "google-play.md"


def fail(message: str) -> None:
    raise SystemExit(f"Release workflow contract failed: {message}")


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
            fail(f"missing YAML block {'.'.join(path)}")
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
    fail(f"missing YAML value {'.'.join((*path, key))}")
    return ""


def assert_choice(
    lines: list[str], input_name: str, expected_default: str, expected_options: str
) -> None:
    path = ("on", "workflow_dispatch", "inputs", input_name)
    if scalar(lines, path, "type") != "choice":
        fail(f"{input_name} must be a workflow_dispatch choice")
    if scalar(lines, path, "default") != expected_default:
        fail(f"{input_name} default must remain {expected_default}")
    options = scalar(lines, path, "options").replace(" ", "")
    if options != expected_options:
        fail(f"{input_name} options must be {expected_options}")


def main() -> int:
    workflow_lines = DEPLOY_ALL.read_text(encoding="utf-8").splitlines()
    assert_choice(workflow_lines, "google_play_track", "internal", "[internal,production]")
    assert_choice(
        workflow_lines,
        "google_play_release_status",
        "completed",
        "[draft,completed]",
    )

    reusable_call = ("jobs", "google-play", "with")
    if scalar(workflow_lines, reusable_call, "track") != "${{ inputs.google_play_track }}":
        fail("google-play job must forward google_play_track")
    if (
        scalar(workflow_lines, reusable_call, "release_status")
        != "${{ inputs.google_play_release_status }}"
    ):
        fail("google-play job must forward google_play_release_status")

    release_doc = GOOGLE_PLAY_DOC.read_text(encoding="utf-8")
    for required_text in (
        "Play Console `Account Details`",
        "`google_play_track=production`",
        "`google_play_release_status=completed`",
        "403",
    ):
        if required_text not in release_doc:
            fail(f"Google Play release documentation must include {required_text}")

    print("Deploy All Google Play production contract passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
