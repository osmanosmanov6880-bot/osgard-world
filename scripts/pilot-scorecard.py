#!/usr/bin/env python3
"""OSGARD pilot scorecard. Standard library only, no production APIs."""
import argparse
import csv
import json
import statistics
import sys
from collections import defaultdict
from decimal import Decimal, InvalidOperation
from pathlib import Path

FIELDS = ("task_id", "variant", "elapsed_minutes", "completed", "human_minutes",
          "corrections", "revenue", "refunds", "compute_cost",
          "payment_fees", "mentor_cost", "support_cost", "novel_skill_pass")
MONEY = ("revenue", "refunds", "compute_cost", "payment_fees", "mentor_cost", "support_cost")
NUMBER = ("elapsed_minutes", "human_minutes", "corrections")
ALLOWED_VARIANTS = {"baseline", "pilot"}

def decimal(value, field, line):
    try:
        result = Decimal(value)
    except (InvalidOperation, TypeError):
        raise ValueError(f"line {line}: invalid {field}") from None
    if not result.is_finite() or result < 0:
        raise ValueError(f"line {line}: {field} must be finite and nonnegative")
    return result

def parse_bool(value, field, line, optional=False):
    v = str(value).strip().lower()
    if optional and v == "":
        return None
    if v not in ("true", "false"):
        raise ValueError(f"line {line}: {field} must be true or false")
    return v == "true"

def read_rows(path):
    rows, seen = [], set()
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None or set(FIELDS) - set(reader.fieldnames):
            raise ValueError("missing required CSV headers: " + ", ".join(sorted(set(FIELDS) - set(reader.fieldnames or []))))
        for line, raw in enumerate(reader, 2):
            if None in raw or any(v is None for v in raw.values()):
                raise ValueError(f"line {line}: malformed CSV")
            row = {k: raw[k].strip() for k in FIELDS}
            if not row["task_id"] or row["variant"] not in ALLOWED_VARIANTS:
                raise ValueError(f"line {line}: task_id or variant invalid")
            key = (row["task_id"], row["variant"])
            if key in seen:
                raise ValueError(f"line {line}: duplicate task and variant: {key}")
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

def score(rows):
    groups = defaultdict(dict)
    for row in rows:
        groups[row["task_id"]][row["variant"]] = row
    paired = [pair for pair in groups.values() if set(pair) == ALLOWED_VARIANTS]
    incomplete = sorted(task for task, pair in groups.items() if set(pair) != ALLOWED_VARIANTS)
    if not paired:
        raise ValueError("no baseline/pilot matched task pairs")
    baseline = [pair["baseline"] for pair in paired]
    pilot = [pair["pilot"] for pair in paired]
    base_success = [r for r in baseline if r["completed"]]
    pilot_success = [r for r in pilot if r["completed"]]
    # Time comparisons are valid only for tasks successfully completed in BOTH variants.
    both_success = [(a, b) for a, b in zip(baseline, pilot) if a["completed"] and b["completed"]]
    speedup = None
    if both_success:
        speedup = statistics.median([float(a["elapsed_minutes"]) for a, b in both_success]) / statistics.median([float(b["elapsed_minutes"]) for a, b in both_success])
    contribution = sum((r["revenue"] - r["refunds"] - r["compute_cost"] - r["payment_fees"] - r["mentor_cost"] - r["support_cost"] for r in pilot), Decimal(0))
    skill = [r["novel_skill_pass"] for r in pilot]
    skill_known = all(v is not None for v in skill)
    # Do not pass a gate on a small, incomplete or unverified sample.
    sample_ok = len(paired) >= 20 and not incomplete
    success_rate = len(pilot_success) / len(pilot)
    gates = {
        "sample_minimum_20_paired_complete": sample_ok,
        "pilot_completion_at_least_85pct": sample_ok and success_rate >= 0.85,
        "speedup_at_least_3x": sample_ok and len(both_success) >= 20 and speedup is not None and speedup >= 3,
        "positive_contribution": sample_ok and contribution > 0,
        "novel_skill_results_recorded": sample_ok and skill_known,
    }
    return {
        "sample": {"paired_tasks": len(paired), "unpaired_task_ids": incomplete, "both_completed_for_speed": len(both_success)},
        "baseline_completion_rate": round(len(base_success) / len(baseline), 4),
        "pilot_completion_rate": round(success_rate, 4),
        "median_successful_pair_speedup": round(speedup, 4) if speedup is not None else None,
        "pilot_human_minutes_total": str(sum((r["human_minutes"] for r in pilot), Decimal(0))),
        "pilot_corrections_total": int(sum(r["corrections"] for r in pilot)),
        "pilot_variable_contribution": str(contribution),
        "pilot_novel_skill_pass_rate": round(sum(skill) / len(skill), 4) if skill_known else None,
        "gates": gates,
        "ready_for_scale_decision": all(gates.values()),
        "limitations": [
            "Unverified self-reported input; audit against source evidence before decisions.",
            "Speedup compares only matched tasks completed in both variants; failures are separately counted.",
            "Novel skill pass is recorded, not causal improvement; a pre-test or control is still required.",
            "No baseline economic comparison is inferred; costs must include all relevant variable expenses."
        ],
    }

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv_file", type=Path)
    parser.add_argument("--output", type=Path, help="write JSON atomically")
    args = parser.parse_args(argv)
    try:
        report = score(read_rows(args.csv_file))
    except (ValueError, OSError) as err:
        print(f"pilot measurement error: {err}", file=sys.stderr)
        return 2
    output = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        temporary = args.output.with_name(args.output.name + ".tmp")
        temporary.write_text(output, encoding="utf-8")
        temporary.replace(args.output)
    else:
        print(output, end="")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
