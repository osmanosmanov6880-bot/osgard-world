"""OSGARD M182 read-only integration readiness validator.

This program never extracts archives, executes product code, modifies repos
or authorizes production. It checks only structurally supplied evidence.
"""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import stat
import sys
import zipfile

M181_SHA256 = "c6d0ff3ff9caa435e6928244ab70ecee8156747306ac3174faca82702be2969a"
M181_COMMIT = "ff5e6de7e9614add995d11a7330fc2f13d2c1206"
TEAM_COUNTS = {
    "TITAN / KRAKEN": 30,
    "NEXUS / AETHERION": 30,
    "COMMERCE": 30,
    "HUMAN EXPERIENCE": 30,
    "GENESIS MEDIA": 30,
    "ORBITAL": 30,
}
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
GIT_SHA_RE = re.compile(r"^[0-9a-f]{40}$")
MAX_ARCHIVE_MEMBERS = 100_000
MAX_UNCOMPRESSED_SIZE = 6 * 1024**3
MAX_COMPRESSION_RATIO = 1_000

def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for piece in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(piece)
    return h.hexdigest()

def check_archive(path: Path, expected_sha: str = M181_SHA256) -> dict:
    """Read-only SHA-256 + ZIP member safety; never extracts or executes."""
    if not path.is_file():
        return {"ok": False, "reason": "archive_missing", "path": str(path)}
    if not SHA_RE.fullmatch(expected_sha):
        return {"ok": False, "reason": "invalid_expected_sha256"}
    actual = digest(path)
    if actual != expected_sha:
        return {"ok": False, "reason": "archive_sha256_mismatch", "sha256": actual}
    seen: set[str] = set()
    total_size = 0
    try:
        with zipfile.ZipFile(path, "r") as archive:
            members = archive.infolist()
            if len(members) > MAX_ARCHIVE_MEMBERS:
                return {"ok": False, "reason": "too_many_members"}
            for entry in members:
                name = entry.filename
                pieces = name.split("/")
                if (not name or name.startswith("/") or name.startswith("\\")
                    or "\\" in name or "\x00" in name
                    or any(p in (".", "..") for p in pieces)
                    or re.match(r"^[A-Za-z]:", name)):
                    return {"ok": False, "reason": "unsafe_member_path", "member": name}
                normalized = name.rstrip("/").casefold()
                if normalized in seen:
                    return {"ok": False, "reason": "duplicate_member", "member": name}
                seen.add(normalized)
                if stat.S_ISLNK(entry.external_attr >> 16):
                    return {"ok": False, "reason": "symlink_member", "member": name}
                total_size += entry.file_size
                if total_size > MAX_UNCOMPRESSED_SIZE:
                    return {"ok": False, "reason": "uncompressed_size_limit"}
                if entry.file_size > MAX_COMPRESSION_RATIO * max(entry.compress_size, 1):
                    return {"ok": False, "reason": "compression_ratio_limit", "member": name}
            corrupt = archive.testzip()
            if corrupt is not None:
                return {"ok": False, "reason": "member_crc_error", "member": corrupt}
    except (OSError, zipfile.BadZipFile, RuntimeError, EOFError) as exc:
        return {"ok": False, "reason": "invalid_zip", "detail": type(exc).__name__}
    return {"ok": True, "sha256": actual, "members": len(members), "uncompressed_bytes": total_size}

def independently_accepted(item: dict, *, require_sha: bool = True) -> bool:
    if not isinstance(item, dict) or item.get("status") != "accepted":
        return False
    author, reviewer = item.get("author"), item.get("reviewer")
    if not isinstance(author, str) or not isinstance(reviewer, str) or not author or not reviewer:
        return False
    if author.casefold() == reviewer.casefold():
        return False
    if not str(item.get("review_url", "")).startswith("https://"):
        return False
    return not require_sha or bool(SHA_RE.fullmatch(str(item.get("evidence_sha256", ""))))

def has_cycle(ids: set[str], links: list[dict]) -> bool:
    adj = {key: [] for key in ids}
    indegree = {key: 0 for key in ids}
    for x in links:
        adj[x["from"]].append(x["to"])
        indegree[x["to"]] += 1
    roots = [key for key in ids if indegree[key] == 0]
    visited = 0
    while roots:
        current = roots.pop()
        visited += 1
        for target in adj[current]:
            indegree[target] -= 1
            if indegree[target] == 0:
                roots.append(target)
    return visited != len(ids)

def evaluate(evidence: dict, archive_status: dict) -> dict:
    """Fail closed. Never returns production GO."""
    faults: list[str] = []
    if not archive_status.get("ok"):
        faults.append("M181 original ZIP is not byte-verified")
    if evidence.get("m181_commit") != M181_COMMIT:
        faults.append("M181 local Git commit pin mismatch")
    if evidence.get("m181_zip_sha256") != M181_SHA256:
        faults.append("M181 ZIP hash pin mismatch")

    upstreams = evidence.get("upstreams", [])
    if not isinstance(upstreams, list):
        upstreams = []
    if len(upstreams) != 6:
        faults.append("six canonical team upstreams not recorded")
    if set(str(x.get("team")) for x in upstreams if isinstance(x, dict)) != set(TEAM_COUNTS):
        faults.append("upstream/team identity mapping incomplete")
    for x in upstreams:
        if not isinstance(x, dict) or not GIT_SHA_RE.fullmatch(str(x.get("git_sha", ""))):
            faults.append("invalid upstream commit SHA")
            continue
        if not independently_accepted(x, require_sha=False) or not x.get("repo") or not x.get("branch"):
            faults.append("canonical upstream not independently reviewed")

    conflicts = evidence.get("conflicts", [])
    if not isinstance(conflicts, list):
        conflicts = []
    priority = Counter(str(x.get("priority")) for x in conflicts if isinstance(x, dict))
    if len(conflicts) != 28 or priority != {"P0": 17, "P1": 11}:
        faults.append("28 original conflict reviews (17 P0, 11 P1) missing")
    if len({str(x.get("path")) for x in conflicts if isinstance(x, dict)}) != len(conflicts):
        faults.append("duplicate conflict paths")
    for x in conflicts:
        if not isinstance(x, dict) or not independently_accepted(x):
            faults.append("unreviewed conflict")
            break
        if not SHA_RE.fullmatch(str(x.get("left_sha256", ""))) or not SHA_RE.fullmatch(str(x.get("right_sha256", ""))):
            faults.append("conflict byte hashes missing")
            break

    contracts = evidence.get("contracts", [])
    if not isinstance(contracts, list):
        contracts = []
    if len(contracts) != 9 or len({str(x.get("id")) for x in contracts if isinstance(x, dict)}) != 9:
        faults.append("nine unique cross-team contracts missing")
    for x in contracts:
        if (not isinstance(x, dict) or not independently_accepted(x)
            or not str(x.get("ci_url", "")).startswith("https://")):
            faults.append("contract missing independent review/CI evidence")
            break

    tasks = evidence.get("tasks", [])
    if not isinstance(tasks, list):
        tasks = []
    ids = [str(x.get("id")) for x in tasks if isinstance(x, dict)]
    counts = Counter(str(x.get("team")) for x in tasks if isinstance(x, dict))
    if len(tasks) != 180 or len(set(ids)) != 180 or "None" in ids or counts != TEAM_COUNTS:
        faults.append("original 180 unique tasks/30 per team not proven")
    if any(not independently_accepted(x) for x in tasks):
        faults.append("at least one task lacks independent acceptance")
    links = evidence.get("dependencies", [])
    if not isinstance(links, list):
        links = []
    edges = [(str(x.get("from")), str(x.get("to"))) for x in links if isinstance(x, dict)]
    if (len(links) != 294 or len(set(edges)) != 294 or
        any(a not in ids or b not in ids or a == b for a, b in edges)):
        faults.append("294 valid unique task dependencies not proven")
    elif len(ids) == 180 and len(set(ids)) == 180 and has_cycle(set(ids), links):
        faults.append("task dependency cycle")

    drills = evidence.get("drills", {})
    if not isinstance(drills, dict):
        drills = {}
    for name in ("staging_e2e", "security", "backup_restore", "rollback", "release_reproducibility"):
        item = drills.get(name, {})
        if not independently_accepted(item) or not str(item.get("ci_url", "")).startswith("https://"):
            faults.append("required independent release drill missing: " + name)

    return {
        "program": "OSGARD M182",
        "scope": "structural author-side preflight only",
        "local_readiness": "READY_FOR_EXTERNAL_REVIEW" if not faults else "BLOCKED",
        "production_release": "NO_GO",
        "externally_accepted_tasks": sum(1 for t in tasks if independently_accepted(t)) if len(tasks) == 180 else 0,
        "faults": sorted(set(faults)),
        "archive": archive_status,
        "note": "Editable JSON evidence is not cryptographic proof of reviewer authority, CI, or production acceptance.",
    }

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--archive", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args(argv)
    if args.evidence.stat().st_size > 25 * 1024 * 1024:
        raise ValueError("evidence exceeds 25 MiB")
    with args.evidence.open("r", encoding="utf-8") as stream:
        evidence = json.load(stream)
    if not isinstance(evidence, dict):
        evidence = {}
    status = check_archive(args.archive) if args.archive else {"ok": False, "reason": "archive_not_supplied"}
    result = evaluate(evidence, status)
    output = json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if args.report:
        if args.report.is_symlink():
            raise ValueError("refusing symlink report")
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output, encoding="utf-8")
    print(output, end="")
    return 0 if result["local_readiness"] == "READY_FOR_EXTERNAL_REVIEW" else 2

if __name__ == "__main__":
    sys.exit(main())
