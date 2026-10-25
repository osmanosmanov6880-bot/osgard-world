#!/usr/bin/env python3
"""Restore only the SHA-pinned original W18 evidence, never arbitrary ZIP data.

No network, SSH, production mutation, hardware benchmark or dynamic path fallback.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

SOURCE = "5971112ef861afc257aeb0e054550c158c260b6a"
VERSION = "r135-premium-learning-w18-candidate-20261025"
SCHEMA = "OSGARD_R135_W18_ORIGINAL_EVIDENCE_MEMBERS_V1"
MAX_ARCHIVE_BYTES = 25_000_000
MAX_EXPANDED_BYTES = 40_000_000
MAX_MEMBER_BYTES = 8_000_000
MAX_MEMBERS = 32


def require(ok: bool, why: str) -> None:
    if not ok:
        raise ValueError("W18 durable evidence restore rejected: " + why)


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def validate_name(name: str) -> None:
    posix = PurePosixPath(name)
    require(not name.startswith("/") and not name.startswith("\\") and
            "\\" not in name and
            name == posix.as_posix() and
            ".." not in posix.parts and
            all(part not in ("", ".", "..") for part in posix.parts),
            "unsafe ZIP entry name")
    require(
        (len(posix.parts) == 2 and posix.parts[0] == "r135-screens" and
         posix.name != "" and posix.suffix in (".png", ".json"))
        or name in ("r135-w10-release-evidence.json",
                    "r135-w11-readability-evidence.json"),
        "entry is not a reviewed R135 screenshot/report")


def verified_members(pin: dict, evidence_pin: dict, archive: Path) -> dict[str, bytes]:
    require(pin.get("version") == VERSION and pin.get("source_commit") == SOURCE,
            "game source/version mismatch")
    require(evidence_pin.get("schema") == SCHEMA and
            evidence_pin.get("version") == VERSION and
            evidence_pin.get("source_commit") == SOURCE,
            "reviewed report/member source mismatch")
    specs = evidence_pin.get("members")
    require(isinstance(specs, dict) and len(specs) == 18,
            "exactly 18 independently reviewed evidence members are required")
    frames = pin.get("screenshots_sha256")
    require(isinstance(frames, dict) and len(frames) == 11,
            "exactly 11 pinned genuine screenshots are required")
    for frame, expected_sha in frames.items():
        member = "r135-screens/" + frame
        require(member in specs and specs[member]["sha256"] == expected_sha,
                "source screenshot pin disagrees with archive proof: " + frame)
    require(archive.is_file() and 0 < archive.stat().st_size <= MAX_ARCHIVE_BYTES,
            "missing or oversized release evidence archive")
    results: dict[str, bytes] = {}
    with zipfile.ZipFile(archive, "r") as source:
        infos = source.infolist()
        names = [item.filename for item in infos]
        require(len(names) == len(specs) and len(infos) <= MAX_MEMBERS and
                set(names) == set(specs), "unknown, duplicate or missing ZIP member")
        total = 0
        for item in infos:
            name = item.filename
            validate_name(name)
            mode = stat.S_IFMT(item.external_attr >> 16)
            require(not item.is_dir() and not (item.flag_bits & 1) and
                    mode in (0, stat.S_IFREG),
                    "encrypted, linked or directory ZIP member")
            expected = specs[name]
            require(type(expected.get("bytes")) is int and
                    type(expected.get("sha256")) is str and
                    len(expected["sha256"]) == 64 and
                    0 < expected["bytes"] <= MAX_MEMBER_BYTES and
                    item.file_size == expected["bytes"],
                    "member size/provenance mismatch: " + name)
            total += item.file_size
            require(total <= MAX_EXPANDED_BYTES, "total uncompressed evidence limit")
            # ZipFile.read also validates ZIP CRC, but SHA-256 binds the actual
            # bytes to the independent pre-release original source artifact.
            raw = source.read(item)
            require(len(raw) == expected["bytes"] and
                    sha256(raw) == expected["sha256"],
                    "modified or substituted original evidence: " + name)
            results[name] = raw
    return results


def restore(pin_file: Path, evidence_pin_file: Path, archive: Path,
            target: Path) -> dict:
    pin = json.loads(pin_file.read_text(encoding="utf-8"))
    source_pin = json.loads(evidence_pin_file.read_text(encoding="utf-8"))
    contents = verified_members(pin, source_pin, archive)
    target.mkdir(parents=True, exist_ok=True)
    root = target.resolve(strict=True)
    # Validate every byte before writing anything; no partial extraction on bad
    # archives. Staging remains inside the temp workspace.
    with tempfile.TemporaryDirectory(prefix=".w18-evidence-", dir=root) as td:
        staging = Path(td)
        for member, raw in contents.items():
            dst = staging.joinpath(*PurePosixPath(member).parts)
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(raw)
        for member in contents:
            relative = PurePosixPath(member)
            destination = root.joinpath(*relative.parts)
            require(os.path.commonpath((str(root), str(destination.resolve()))) ==
                    str(root), "symlink escape from evidence target")
            destination.parent.mkdir(parents=True, exist_ok=True)
            os.replace(staging.joinpath(*relative.parts), destination)
    return {"status": "W18_ORIGINAL_EVIDENCE_RESTORED", "source_commit": SOURCE,
            "original_verified_members": len(contents),
            "original_verified_screenshots": len(pin["screenshots_sha256"]),
            "physical_phone_certified": False}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pin", type=Path, required=True)
    parser.add_argument("--member-pin", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--target", type=Path, required=True)
    args = parser.parse_args()
    result = restore(args.pin, args.member_pin, args.evidence, args.target)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
