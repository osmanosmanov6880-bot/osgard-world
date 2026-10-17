#!/usr/bin/env python3
"""Offline pilot observations: paired time, completion, cost and unseen-task outcomes."""
import argparse
import csv
import hashlib
import io
import json
import os
import re
import statistics
import sys
import tempfile
from collections import defaultdict
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, localcontext
from pathlib import Path

SCHEMA_VERSION = 2
PROPOSED_MINIMUM_PAIRS = 20  # A protocol choice, not a user target or statistical guarantee.
MAX_INPUT_BYTES = 16 * 1024 * 1024
FIELDS = ("task_id", "variant", "difficulty", "currency", "elapsed_minutes",
          "correction_minutes", "completed", "human_minutes", "corrections",
          "revenue", "refunds", "compute_cost", "payment_fees", "mentor_cost",
          "support_cost", "novel_skill_pass")
MONEY = ("revenue", "refunds", "compute_cost", "payment_fees", "mentor_cost", "support_cost")
NUMBER = ("elapsed_minutes", "correction_minutes", "human_minutes", "corrections")
ALLOWED_VARIANTS = {"baseline", "pilot"}
IDENTIFIER = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}")
ZERO = Decimal(0)


def decimal(value, field, line):
    if not isinstance(value, str) or len(value) > 32:
        raise ValueError(f"line {line}: invalid {field}")
    try:
        result = Decimal(value)
    except (InvalidOperation, TypeError):
        raise ValueError(f"line {line}: invalid {field}") from None
    if not result.is_finite() or result < 0:
        raise ValueError(f"line {line}: {field} must be finite and nonnegative")
    # Fixed-point input avoids ambiguous locale/scientific notation and huge exponents.
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]{1,6})?", value):
        raise ValueError(f"line {line}: {field} needs a decimal point and at most six decimals")
    return result


def parse_bool(value, field, line, optional=False):
    value = str(value).strip().lower()
    if optional and value == "":
        return None
    if value not in ("true", "false"):
        raise ValueError(f"line {line}: {field} must be true or false")
    return value == "true"


def read_input(path):
    with Path(path).open("rb") as handle:
        content = handle.read(MAX_INPUT_BYTES + 1)
    if len(content) > MAX_INPUT_BYTES:
        raise ValueError("CSV exceeds the 16 MiB input limit")
    return content


def parse_rows(content):
    reader = csv.DictReader(io.StringIO(content.decode("utf-8-sig"), newline=""), strict=True)
    headers = reader.fieldnames
    if headers is None:
        raise ValueError("missing required CSV headers")
    if len(headers) != len(set(headers)):
        raise ValueError("duplicate CSV headers")
    if set(headers) != set(FIELDS):
        missing = sorted(set(FIELDS) - set(headers))
        extra = sorted(set(headers) - set(FIELDS))
        raise ValueError(f"CSV headers do not match schema v2; missing={missing}, extra={extra}")
    rows, seen = [], set()
    for raw in reader:
        line = reader.line_num
        if None in raw or any(value is None for value in raw.values()):
            raise ValueError(f"line {line}: malformed CSV")
        row = {key: raw[key].strip() for key in FIELDS}
        if not IDENTIFIER.fullmatch(row["task_id"]) or row["variant"] not in ALLOWED_VARIANTS:
            raise ValueError(f"line {line}: pseudonymous task_id or variant invalid")
        if row["difficulty"] not in ("simple", "medium", "complex"):
            raise ValueError(f"line {line}: difficulty must be simple, medium or complex")
        if not re.fullmatch(r"[A-Z]{3}", row["currency"]):
            raise ValueError(f"line {line}: currency must be one three-letter uppercase code")
        key = (row["task_id"], row["variant"])
        if key in seen:
            raise ValueError(f"line {line}: duplicate task and variant")
        seen.add(key)
        for field in MONEY + NUMBER:
            row[field] = decimal(row[field], field, line)
        if row["elapsed_minutes"] == 0:
            raise ValueError(f"line {line}: elapsed_minutes must exceed zero")
        if row["corrections"] != row["corrections"].to_integral_value():
            raise ValueError(f"line {line}: corrections must be an integer")
        row["completed"] = parse_bool(row["completed"], "completed", line)
        row["novel_skill_pass"] = parse_bool(row["novel_skill_pass"], "novel_skill_pass", line, optional=True)
        rows.append(row)
    if not rows:
        raise ValueError("no pilot records")
    return rows


def read_rows(path):
    return parse_rows(read_input(path))


def total_minutes(row):
    # Categories must be disjoint in the preregistered timing protocol.
    return row["elapsed_minutes"] + row["correction_minutes"] + row["human_minutes"]


def rate(numerator, denominator):
    return round(numerator / denominator, 6) if denominator else None


def score(rows, minimum_pairs=PROPOSED_MINIMUM_PAIRS):
    # Keep arithmetic exact for bounded fixed-point inputs even when totals exceed 28 digits.
    with localcontext() as context:
        context.prec = 80
        return _score(rows, minimum_pairs)


def _score(rows, minimum_pairs):
    if type(minimum_pairs) is not int or not 1 <= minimum_pairs <= 100000:
        raise ValueError("minimum_pairs must be a whole number between 1 and 100000")
    groups = defaultdict(dict)
    for row in rows:
        if row["variant"] in groups[row["task_id"]]:
            raise ValueError("duplicate task and variant")
        groups[row["task_id"]][row["variant"]] = row
    currencies = {row["currency"] for row in rows}
    if len(currencies) != 1:
        raise ValueError("all observations must use the same currency; no implicit conversion")
    paired = [pair for pair in groups.values() if set(pair) == ALLOWED_VARIANTS]
    incomplete = sorted(task for task, pair in groups.items() if set(pair) != ALLOWED_VARIANTS)
    if not paired:
        raise ValueError("no baseline/pilot matched task pairs")
    if any(pair["baseline"]["difficulty"] != pair["pilot"]["difficulty"] for pair in paired):
        raise ValueError("paired tasks must have the same preregistered difficulty")
    # Keep unpaired failures/costs in the descriptive totals; they also block every gate.
    baseline = [row for row in rows if row["variant"] == "baseline"]
    pilot = [row for row in rows if row["variant"] == "pilot"]
    both_success = [(p["baseline"], p["pilot"]) for p in paired
                    if p["baseline"]["completed"] and p["pilot"]["completed"]]
    ratios = [total_minutes(a) / total_minutes(b) for a, b in both_success]
    speedup = statistics.median(ratios) if ratios else None
    execution_ratios = [a["elapsed_minutes"] / b["elapsed_minutes"] for a, b in both_success]
    contribution = sum((r["revenue"] - r["refunds"] - r["compute_cost"] -
                        r["payment_fees"] - r["mentor_cost"] - r["support_cost"]
                        for r in pilot), ZERO)
    known_skill = [(p["baseline"]["novel_skill_pass"], p["pilot"]["novel_skill_pass"])
                   for p in paired
                   if p["baseline"]["novel_skill_pass"] is not None and
                   p["pilot"]["novel_skill_pass"] is not None]
    skill_complete = len(known_skill) == len(paired) and not incomplete
    improved = sum(not before and after for before, after in known_skill)
    regressed = sum(before and not after for before, after in known_skill)
    sample_ok = len(paired) >= minimum_pairs and not incomplete
    successes = sum(row["completed"] for row in pilot)
    completion = Decimal(successes) / len(pilot)
    gates = {
        "proposed_sample_minimum_and_complete_pairs": sample_ok,
        "pilot_completion_at_least_85pct": sample_ok and completion >= Decimal("0.85"),
        "total_time_speedup_at_least_3x": sample_ok and len(both_success) >= minimum_pairs
                                       and speedup is not None and speedup >= 3,
        "positive_variable_contribution": sample_ok and contribution > 0,
        "unseen_pre_and_post_results_complete": sample_ok and skill_complete,
        "observed_unseen_skill_improvement": sample_ok and skill_complete and improved > regressed,
    }
    numeric_targets_met = all(gates.values())
    return {
        "schema_version": SCHEMA_VERSION,
        "currency": next(iter(currencies)),
        "sample": {
            "paired_tasks": len(paired), "unpaired_task_ids": incomplete,
            "baseline_observations": len(baseline), "pilot_observations": len(pilot),
            "both_completed_for_speed": len(both_success),
            "proposed_minimum_pairs": minimum_pairs,
            "minimum_is_statistical_guarantee": False,
            "difficulty_counts": {level: sum(r["difficulty"] == level for r in pilot)
                                  for level in ("simple", "medium", "complex")},
        },
        "baseline_completion_rate": rate(sum(r["completed"] for r in baseline), len(baseline)),
        "pilot_completion_rate": rate(successes, len(pilot)),
        "median_successful_pair_speedup": round(float(speedup), 6) if speedup is not None else None,
        "time_definition": "elapsed_minutes + correction_minutes + human_minutes; disjoint categories",
        "execution_only_median_pair_speedup": round(float(statistics.median(execution_ratios)), 6)
                                              if execution_ratios else None,
        "pilot_total_minutes": str(sum((total_minutes(r) for r in pilot), ZERO)),
        "pilot_human_minutes_total": str(sum((r["human_minutes"] for r in pilot), ZERO)),
        "pilot_correction_minutes_total": str(sum((r["correction_minutes"] for r in pilot), ZERO)),
        "pilot_corrections_total": int(sum((r["corrections"] for r in pilot), ZERO)),
        "pilot_variable_contribution": str(contribution),
        "unseen_skill": {
            "paired_known_outcomes": len(known_skill),
            "baseline_pass_rate": rate(sum(before for before, after in known_skill), len(known_skill)),
            "pilot_pass_rate": rate(sum(after for before, after in known_skill), len(known_skill)),
            "improved_pairs": improved, "regressed_pairs": regressed,
            "observed_gain_percentage_points": round(100 * (improved - regressed) / len(known_skill), 6)
                                               if known_skill else None,
            "independently_verified": False, "causal_learning_gain_proven": False,
        },
        "gates": gates,
        "numeric_targets_met": numeric_targets_met,
        "ready_for_review": numeric_targets_met,
        "ready_for_scale_decision": False,
        "decision": "independent_evidence_review_required" if numeric_targets_met else "targets_or_data_incomplete",
        "limitations": [
            "Inputs are observations, not verified source evidence; no automatic launch or scale approval.",
            "Twenty pairs is a proposed protocol minimum, not a statistical guarantee or the user's target.",
            "Speed is the median of individual matched total-time ratios on mutually completed tasks.",
            "Failed and unpaired observations remain in completion and cost totals; selection bias is possible.",
            "Difficulty labels do not prove task equivalence; audit a fixed task set and assignment protocol.",
            "Skill compares distinct unseen equivalent pre/post exercises; self-reports do not prove causal gain.",
            "Contribution excludes fixed expenses and taxes unless explicitly included; it is not net profit.",
            "Use one repeatable process and a fixed accounting window; never infer real revenue from a draft order.",
        ],
    }


def write_report(path, output):
    """Private, atomic output; never follows an existing .tmp symlink."""
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                         prefix="." + path.name + ".", suffix=".tmp",
                                         delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(output)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv_file", type=Path)
    parser.add_argument("--process", required=True, help="pseudonymous identifier for one repeatable process")
    parser.add_argument("--minimum-pairs", type=int, default=PROPOSED_MINIMUM_PAIRS)
    parser.add_argument("--output", type=Path, help="write private JSON atomically")
    parser.add_argument("--strict", action="store_true", help="exit 1 if any numeric/data gate fails")
    args = parser.parse_args(argv)
    try:
        if not IDENTIFIER.fullmatch(args.process):
            raise ValueError("--process requires a pseudonymous identifier")
        if args.output and args.output.resolve() == args.csv_file.resolve():
            raise ValueError("output must not overwrite the input CSV")
        content = read_input(args.csv_file)
        report = score(parse_rows(content), args.minimum_pairs)
        report.update(process_id=args.process, input_sha256=hashlib.sha256(content).hexdigest(),
                      generated_at=datetime.now(timezone.utc).isoformat())
        output = json.dumps(report, ensure_ascii=False, allow_nan=False, indent=2) + "\n"
        if args.output:
            write_report(args.output, output)
        else:
            print(output, end="")
    except (ValueError, OSError, csv.Error, InvalidOperation) as error:
        print(f"pilot measurement error: {error}", file=sys.stderr)
        return 2
    return 1 if args.strict and not report["numeric_targets_met"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
