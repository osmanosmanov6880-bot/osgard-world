#!/usr/bin/env python3
"""Fail-closed OSGARD release evidence gate; never publishes or changes production."""
import argparse
import hashlib
import json
import sys
from pathlib import Path

REQUIRED = ("code_ci", "frontend_ci", "archive", "backup_restore", "smoke")
HASH_KEYS = ("artifact_sha256", "commit_sha")
def sha(value, lengths=(64,)):
    return isinstance(value, str) and len(value) in lengths and all(c in "0123456789abcdef" for c in value.lower())

def check(record, artifact=None):
    problems = []
    if not isinstance(record, dict) or record.get("schema_version") != 1:
        raise ValueError("release evidence must be a JSON object with schema_version=1")
    if not isinstance(record.get("release_id"), str) or not record["release_id"].strip():
        problems.append("release_id missing")
    for key in HASH_KEYS:
        if not sha(record.get(key), (40, 64) if key == "commit_sha" else (64,)):
            problems.append(f"{key} is not a valid hex digest (Git commit 40/64, artifact 64)")
    for key in REQUIRED:
        entry = record.get("checks", {}).get(key) if isinstance(record.get("checks"), dict) else None
        if not isinstance(entry, dict) or entry.get("status") != "passed" or not isinstance(entry.get("evidence_url"), str) or not entry["evidence_url"].startswith("https://"):
            problems.append(key + ": passed status and HTTPS evidence_url required")
    if record.get("payment_mode") != "disabled":
        problems.append("payment_mode must remain disabled for this release profile")
    if record.get("publication_authorized") is not False:
        problems.append("publication_authorized must be false for this evidence-only gate")
    if artifact:
        artifact = Path(artifact)
        if artifact.is_symlink() or not artifact.is_file():
            problems.append("artifact must be a regular file")
        else:
            h = hashlib.sha256()
            with artifact.open("rb") as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    h.update(block)
            if h.hexdigest() != str(record.get("artifact_sha256", "")).lower():
                problems.append("artifact SHA-256 mismatch")
    return {"status": "blocked" if problems else "ready_for_human_review",
            "release_id": record.get("release_id"), "problems": problems,
            "publication_performed": False}

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--artifact", type=Path)
    args = parser.parse_args(argv)
    try:
        result = check(json.loads(args.evidence.read_text(encoding="utf-8")), args.artifact)
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print("BLOCK RELEASE: " + str(error), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "ready_for_human_review" else 2

if __name__ == "__main__":
    raise SystemExit(main())
