#!/usr/bin/env python3
"""Prevent R28 civic and road WebGL CI cancelling each other for the same PR.

GitHub Actions concurrency groups are repository-wide, not per-workflow.
A shared group silently cancels required acceptance evidence.
"""
from pathlib import Path
import re
import unittest

CIVIC = Path(".github/workflows/omega-r28-civic-qa.yml")
ROAD = Path(".github/workflows/omega-r28-road-paint-qa.yml")
PR_SCOPE = "${{ github.event.pull_request.number || github.ref }}"


def read_group(path: Path) -> tuple[str, str]:
    text = path.read_text(encoding="utf-8")
    match = re.search(r"(?m)^  group: (.+)$", text)
    if not match:
        raise AssertionError(f"Missing workflow concurrency group: {path}")
    return match.group(1).strip(), text


class R28WorkflowIsolationTest(unittest.TestCase):
    def test_concurrent_required_workflows_are_independent(self):
        civic, _ = read_group(CIVIC)
        road, _ = read_group(ROAD)
        self.assertNotEqual(civic, road, "R28 workflows would cancel one another")
        self.assertIn("omega-r28-civic-", civic)
        self.assertIn("omega-r28-road-", road)
        self.assertIn(PR_SCOPE, civic)
        self.assertIn(PR_SCOPE, road)

    def test_stale_run_cancellation_is_local_to_each_workflow(self):
        for path in (CIVIC, ROAD):
            group, body = read_group(path)
            self.assertIn("cancel-in-progress: true", body)
            self.assertIn("pull_request:", body)
            self.assertIn("workflow_dispatch:", body)
            self.assertIn(PR_SCOPE, group)


if __name__ == "__main__":
    unittest.main(verbosity=2)
