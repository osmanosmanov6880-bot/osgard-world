#!/usr/bin/env python3
"""Run with python3 -m unittest discover -s tests -p test_pilot_scorecard.py"""
import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("pilot_scorecard", ROOT / "scripts/pilot-scorecard.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

HEADERS = ",".join(module.FIELDS)
def row(task, variant, completed="true", elapsed="10", revenue="5", novel="true"):
    return ",".join((task, variant, elapsed, completed, "1", "0", revenue,
                     "0", "1", "0", "1", "1", novel))

class PilotScorecardTest(unittest.TestCase):
    def load(self, rows):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "pilot.csv"
            path.write_text(HEADERS + "\n" + "\n".join(rows) + "\n", encoding="utf-8")
            return module.read_rows(path)

    def test_no_fake_success_on_single_pair(self):
        report = module.score(self.load([row("a","baseline",elapsed="30"), row("a","pilot")]))
        self.assertFalse(report["ready_for_scale_decision"])
        self.assertEqual(report["median_successful_pair_speedup"], 3.0)

    def test_valid_20_pair_pilot(self):
        lines = []
        for i in range(20):
            lines.extend((row(f"t{i}","baseline",elapsed="30"), row(f"t{i}","pilot")))
        report = module.score(self.load(lines))
        self.assertTrue(report["ready_for_scale_decision"])

    def test_failure_cannot_be_hidden_from_completion(self):
        lines = []
        for i in range(20):
            lines.extend((row(f"t{i}","baseline",elapsed="30"),
                          row(f"t{i}","pilot",completed="false" if i < 4 else "true")))
        report = module.score(self.load(lines))
        self.assertFalse(report["gates"]["pilot_completion_at_least_85pct"])
        self.assertFalse(report["gates"]["speedup_at_least_3x"])

    def test_unpaired_blocks_scaling(self):
        lines = []
        for i in range(20):
            lines.extend((row(f"t{i}","baseline",elapsed="30"), row(f"t{i}","pilot")))
        lines.append(row("extra","pilot"))
        self.assertFalse(module.score(self.load(lines))["ready_for_scale_decision"])

    def test_duplicate_and_missing_cost_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            self.load([row("a","pilot"), row("a","pilot")])
        with self.assertRaisesRegex(ValueError, "invalid compute_cost"):
            self.load([row("a","baseline").replace(",1,0,1,1,true", ",,0,1,1,true")])

    def test_missing_skill_never_counts_as_pass(self):
        lines = []
        for i in range(20):
            lines.extend((row(f"t{i}","baseline",elapsed="30"), row(f"t{i}","pilot",novel="")))
        report = module.score(self.load(lines))
        self.assertIsNone(report["pilot_novel_skill_pass_rate"])
        self.assertFalse(report["gates"]["novel_skill_results_recorded"])

if __name__ == "__main__":
    unittest.main()
