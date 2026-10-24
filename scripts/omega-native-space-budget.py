#!/usr/bin/env python3
"""Fail-closed bounded space calculation for genuine Godot native Web uploads.

This code never deletes files, connects to a server, or retrieves secrets.
"""
from __future__ import annotations

import argparse
import pathlib
import sys

MIB = 1024 * 1024
BASE_RESERVE = 512 * MIB
MAX_INPUT = 2 * 1024 * MIB


def required_bytes(archive_bytes: int, game_bytes: int) -> int:
    for name, value in (("archive", archive_bytes), ("game", game_bytes)):
        if type(value) is not int or not 0 < value <= MAX_INPUT:
            raise ValueError(f"Invalid {name} asset size: {value!r}")
    return BASE_RESERVE + 2 * archive_bytes + 3 * game_bytes


def directory_size(path: pathlib.Path) -> int:
    if not path.is_dir() or path.is_symlink():
        raise ValueError("Game directory missing or a symlink")
    total = 0
    count = 0
    for candidate in path.iterdir():
        if candidate.is_symlink() or not candidate.is_file():
            raise ValueError("Export may contain only ordinary files")
        size = candidate.stat().st_size
        if size <= 0:
            raise ValueError(f"Empty source asset: {candidate.name}")
        total += size
        count += 1
    if not count:
        raise ValueError("Empty export directory")
    return total


def self_test() -> None:
    assert required_bytes(1, 1) == BASE_RESERVE + 5
    assert required_bytes(20 * MIB, 80 * MIB) == 792 * MIB
    assert required_bytes(MAX_INPUT, MAX_INPUT) == BASE_RESERVE + 5 * MAX_INPUT
    for a, b in [(0, 10), (10, 0), (-1, 1), (1, -1), (1, MAX_INPUT + 1),
                 (MAX_INPUT + 1, 1), (1.5, 2), ("10", 12), (True, 3)]:
        try:
            required_bytes(a, b)
        except ValueError:
            pass
        else:
            raise AssertionError(f"Unsafe size accepted: {a!r} {b!r}")
    import tempfile
    with tempfile.TemporaryDirectory(prefix="omega-capacity-") as d:
        target = pathlib.Path(d)
        (target / "index.wasm").write_bytes(b"WASM")
        (target / "index.pck").write_bytes(b"PCK")
        assert directory_size(target) == 7
        (target / "index.js").touch()
        try:
            directory_size(target)
        except ValueError:
            pass
        else:
            raise AssertionError("Empty asset accepted")
        (target / "index.js").unlink()
        (target / "fake-link").symlink_to(target / "index.wasm")
        try:
            directory_size(target)
        except ValueError:
            pass
        else:
            raise AssertionError("Symlink accepted")
    print("PASS OMEGA capacity budget: bounded assets, reserve and invalid files")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--archive", type=pathlib.Path)
    parser.add_argument("--game-dir", type=pathlib.Path)
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test()
            return 0
        if args.archive is None or args.game_dir is None:
            parser.error("--archive and --game-dir are required")
        if args.archive.is_symlink() or not args.archive.is_file():
            raise ValueError("Archive missing or symlink")
        print(required_bytes(args.archive.stat().st_size, directory_size(args.game_dir)))
        return 0
    except (OSError, ValueError, AssertionError) as exc:
        print(f"Unsafe native archive capacity preflight: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
