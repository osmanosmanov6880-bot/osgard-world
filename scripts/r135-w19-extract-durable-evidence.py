#!/usr/bin/env python3
"""Safely restore original SHA-reviewable W19 browser evidence from GitHub Release.

The release fallback MUST be followed by the same independent W19 original
PNG/binary/three-fault review, never accepted by metadata or filename alone.
"""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path, PurePosixPath
import stat
import zipfile

MAX_ITEM_BYTES = 18_000_000
MAX_TOTAL_BYTES = 100_000_000
MAX_ITEMS = 70


def reject(reason: str) -> None:
    raise ValueError("W19 durable evidence rejected: " + reason)


def allowed_member(filename: str, directory: bool) -> bool:
    if directory:
        return filename == "r135-screens/"
    path = PurePosixPath(filename)
    if (
        path.is_absolute() or "\\" in filename or "\x00" in filename
        or "//" in filename or "." in path.parts or ".." in path.parts
    ):
        return False
    return (filename == "r135-w10-release-evidence.json"
            or (len(path.parts) == 2
                and path.parts[0] == "r135-screens"
                and path.suffix in {".png", ".json"}
                and path.name not in ("", ".", "..")))


def unpack(source: Path, destination: Path) -> dict:
    if not source.is_file() or source.stat().st_size < 1024:
        reject("release original-evidence ZIP is absent")
    with zipfile.ZipFile(source) as archive:
        infos = archive.infolist()
        if not 2 <= len(infos) <= MAX_ITEMS:
            reject("unbounded or empty archive")
        names = [i.filename for i in infos]
        if len(names) != len(set(names)):
            reject("duplicate archive entries")
        total = 0
        for info in infos:
            if not allowed_member(info.filename, info.is_dir()):
                reject("unsafe or unexpected archive entry: " + info.filename)
            mode = info.external_attr >> 16
            if stat.S_ISLNK(mode) or info.flag_bits & 1:
                reject("symlink or encrypted original evidence is forbidden")
            if info.file_size > MAX_ITEM_BYTES:
                reject("oversized member: " + info.filename)
            total += info.file_size
            if total > MAX_TOTAL_BYTES:
                reject("unbounded expanded ZIP")
        if "r135-w10-release-evidence.json" not in names:
            reject("no original signed W10 readiness report")
        pngs = [n for n in names if n.startswith("r135-screens/") and n.endswith(".png")]
        if len(pngs) < 13:
            reject("missing 13 original browser frames")
        if not any(n.endswith("-three-case-evidence.json") for n in names):
            reject("no original three-case browser diagnostics")

        destination.mkdir(parents=True, exist_ok=True)
        for info in infos:
            if info.is_dir():
                continue
            target = (destination / info.filename).resolve()
            if not target.is_relative_to(destination.resolve()):
                reject("target escaped private staging directory")
            if target.exists():
                reject("refusing to replace previously extracted evidence")
            target.parent.mkdir(parents=True, exist_ok=True)
            count = 0
            with archive.open(info) as reader, target.open("xb") as writer:
                for chunk in iter(lambda: reader.read(1024 * 1024), b""):
                    count += len(chunk)
                    if count > info.file_size or count > MAX_ITEM_BYTES:
                        reject("ZIP decompression exceeded declared bytes")
                    writer.write(chunk)
            if count != info.file_size:
                reject("ZIP extracted byte count differs from central directory")
    return {"status": "UNREVIEWED_EXTRACTED_FOR_REVALIDATION",
            "files": len(pngs), "total_bytes": total,
            "fully_certified": False}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    print(json.dumps(unpack(args.archive, args.destination), ensure_ascii=False))


if __name__ == "__main__":
    main()
