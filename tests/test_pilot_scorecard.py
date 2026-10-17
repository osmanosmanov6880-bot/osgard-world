#!/usr/bin/env python3
"""Regression scenarios for misleading or incomplete pilot observations."""
import contextlib
import csv
import hashlib
import importlib.util
import io
import json
import stat
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("pilot_scorecard", ROOT / "scripts/pilot-scorecard.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def row(task, variant, **changes):
    values = dict(task_id=task, variant=variant, difficulty="medium", currency="USD",
                  elapsed_minutes="30" if variant == "baseline" else "10",
                  correction_minutes="0", completed="true", human_minutes="0", corrections="0",
                  revenue="5", refunds="0", compute_cost="1", payment_fees="0",
                  mentor_cost="1", support_cost="1",
                  novel_skill_pass="false" if variant == "baseline" else "true")
    values.update(changes)
    return values


def records(count=20):
    return [row(f"t{i}", variant) for i in range(count) for variant in ("baseline", "pilot")]


def content(rows, fields=module.FIELDS):
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=fields)
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue().encode("utf-8")


class PilotScorecardTest(unittest.TestCase):
    def report(self, rows, **options):
        return module.score(module.parse_rows(content(rows)), **options)

    def test_numeric_success_requires_review_and_is_never_scale_approval(self):
        result = self.report(records())
        self.assertTrue(result["numeric_targets_met"])
        self.assertTrue(result["ready_for_review"])
        self.assertFalse(result["ready_for_scale_decision"])
        self.assertFalse(result["unseen_skill"]["independently_verified"])
        self.assertEqual(result["pilot_variable_contribution"], "40")

    def test_proposed_minimum_is_visible_and_a_small_sample_does_not_pass(self):
        result = self.report(records(1))
        self.assertFalse(result["numeric_targets_met"])
        self.assertEqual(result["sample"]["proposed_minimum_pairs"], 20)
        self.assertFalse(result["sample"]["minimum_is_statistical_guarantee"])
        self.assertEqual(result["median_successful_pair_speedup"], 3.0)

    def test_median_of_matched_ratios_preserves_pairing(self):
        rows = []
        for i, (before, after) in enumerate((("10", "100"), ("100", "10"), ("1000", "200"))):
            rows += [row(f"t{i}", "baseline", elapsed_minutes=before),
                     row(f"t{i}", "pilot", elapsed_minutes=after)]
        self.assertEqual(self.report(rows)["median_successful_pair_speedup"], 5.0)

    def test_corrections_and_manual_help_cannot_make_a_false_threefold_claim(self):
        rows = records()
        for item in rows:
            if item["variant"] == "pilot":
                item.update(correction_minutes="2", human_minutes="8", corrections="2")
        result = self.report(rows)
        self.assertEqual(result["execution_only_median_pair_speedup"], 3.0)
        self.assertEqual(result["median_successful_pair_speedup"], 1.5)
        self.assertFalse(result["gates"]["total_time_speedup_at_least_3x"])

    def test_failures_stay_in_completion_even_when_unpaired(self):
        rows = records() + [row("unmatched", "pilot", completed="false", revenue="0")]
        result = self.report(rows)
        self.assertEqual(result["pilot_completion_rate"], round(20 / 21, 6))
        self.assertEqual(result["sample"]["pilot_observations"], 21)
        self.assertEqual(result["pilot_variable_contribution"], "37")
        self.assertFalse(result["numeric_targets_met"])

    def test_exact_85_percent_passes_completion_but_small_success_sample_blocks_speed(self):
        rows = records()
        for item in rows:
            if item["variant"] == "pilot" and item["task_id"] in ("t0", "t1", "t2"):
                item["completed"] = "false"
        result = self.report(rows)
        self.assertTrue(result["gates"]["pilot_completion_at_least_85pct"])
        self.assertFalse(result["gates"]["total_time_speedup_at_least_3x"])
        rows[-1]["completed"] = "false"
        self.assertFalse(self.report(rows)["gates"]["pilot_completion_at_least_85pct"])

    def test_speed_threshold_is_compared_before_rounding(self):
        rows = records()
        for item in rows:
            item["elapsed_minutes"] = "2.999999" if item["variant"] == "baseline" else "1"
        self.assertFalse(self.report(rows)["gates"]["total_time_speedup_at_least_3x"])

    def test_recording_all_failed_new_exercises_is_not_learning_improvement(self):
        rows = records()
        for item in rows:
            item["novel_skill_pass"] = "false"
        result = self.report(rows)
        self.assertTrue(result["gates"]["unseen_pre_and_post_results_complete"])
        self.assertFalse(result["gates"]["observed_unseen_skill_improvement"])

    def test_already_successful_pretest_is_not_an_improvement(self):
        rows = records()
        for item in rows:
            item["novel_skill_pass"] = "true"
        result = self.report(rows)
        self.assertEqual(result["unseen_skill"]["observed_gain_percentage_points"], 0)
        self.assertFalse(result["numeric_targets_met"])

    def test_missing_pretest_or_posttest_blocks_learning_gate(self):
        for variant in ("baseline", "pilot"):
            with self.subTest(variant=variant):
                rows = records()
                for item in rows:
                    if item["variant"] == variant:
                        item["novel_skill_pass"] = ""
                result = self.report(rows)
                self.assertEqual(result["unseen_skill"]["paired_known_outcomes"], 0)
                self.assertFalse(result["gates"]["unseen_pre_and_post_results_complete"])

    def test_refunds_and_variable_costs_block_nonpositive_contribution(self):
        rows = records()
        for item in rows:
            item["refunds"] = "2"
        result = self.report(rows)
        self.assertEqual(result["pilot_variable_contribution"], "0")
        self.assertFalse(result["gates"]["positive_variable_contribution"])

    def test_contribution_does_not_lose_small_differences_in_large_fixed_point_amounts(self):
        rows = records()
        for item in rows:
            item.update(revenue="1000000000000000000000000000000",
                        compute_cost="999999999999999999999999999999", mentor_cost="0", support_cost="0")
        self.assertEqual(self.report(rows)["pilot_variable_contribution"], "20")

    def test_mixed_currency_or_task_difficulty_is_rejected(self):
        for field, value in (("currency", "EUR"), ("difficulty", "complex")):
            with self.subTest(field=field):
                rows = records()
                rows[1][field] = value
                with self.assertRaises(ValueError):
                    self.report(rows)

    def test_duplicates_and_missing_costs_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            self.report([row("a", "pilot"), row("a", "pilot")])
        for value in ("", "NaN", "Infinity", "-1", "1e999", "1,5"):
            with self.subTest(value=value):
                rows = records(1)
                rows[1]["compute_cost"] = value
                with self.assertRaises(ValueError):
                    self.report(rows)

    def test_malformed_headers_boolean_and_fractional_corrections_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate CSV headers"):
            module.parse_rows((",".join(module.FIELDS + ("revenue",)) + "\n").encode())
        for field, value in (("corrections", "1.5"), ("completed", "yes"), ("task_id", "person@example.com")):
            with self.subTest(field=field):
                rows = records(1)
                rows[1][field] = value
                with self.assertRaises(ValueError):
                    self.report(rows)

    def test_cli_provenance_strict_status_and_private_atomic_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "measurements.csv"
            output = Path(directory) / "report.json"
            unrelated = Path(directory) / "keep.txt"
            unrelated.write_text("keep")
            output.with_name(output.name + ".tmp").symlink_to(unrelated)
            data = content(records(1))
            source.write_bytes(data)
            result = module.main([str(source), "--process", "repeatable-process-01",
                                  "--output", str(output), "--strict"])
            self.assertEqual(result, 1)
            report = json.loads(output.read_text())
            self.assertEqual(report["input_sha256"], hashlib.sha256(data).hexdigest())
            self.assertEqual(report["process_id"], "repeatable-process-01")
            self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o600)
            self.assertEqual(unrelated.read_text(), "keep")

    def test_cli_does_not_replace_the_input_or_crash_on_missing_output_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "measurements.csv"
            data = content(records(1))
            source.write_bytes(data)
            for output in (source, Path(directory) / "absent" / "report.json"):
                with self.subTest(output=output), contextlib.redirect_stderr(io.StringIO()):
                    status = module.main([str(source), "--process", "process-01", "--output", str(output)])
                    self.assertEqual(status, 2)
            self.assertEqual(source.read_bytes(), data)


if __name__ == "__main__":
    unittest.main()
