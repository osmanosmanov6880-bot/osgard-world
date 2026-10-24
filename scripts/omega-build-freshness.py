#!/usr/bin/env python3
"""Guard publication of an Omega Web export against newer game-source commits.

A GitHub worker can build commit A, then publish into a newer master at B.
The old workflow previously refreshed master and staged a stale A export.
This tool compares Git *tree objects*, so unrelated website changes do not
block publication but any change to the game source does.

Exit 0: source trees identical; safe to attempt atomic push.
Exit 3: superseded source or invalid comparison; do not push stale game.
"""

from __future__ import annotations

import pathlib
import subprocess
import sys
import tempfile

SOURCE_PATH = "godot/empire-omega"


def _run(*args: str, cwd: pathlib.Path) -> str:
    result = subprocess.run(
        list(args), cwd=cwd, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, check=False, timeout=15,
    )
    if result.returncode:
        raise RuntimeError(
            f"{' '.join(args[:2])} failed ({result.returncode}): "
            f"{result.stderr.strip()[:200]}"
        )
    return result.stdout.strip()


def _tree(repo: pathlib.Path, ref: str) -> str:
    if not ref or ref.startswith("-") or any(ch.isspace() for ch in ref):
        raise ValueError("unsafe or blank git ref")
    return _run("git", "rev-parse", "--verify", f"{ref}:{SOURCE_PATH}", cwd=repo)


def is_fresh(repo: pathlib.Path, build_ref: str, latest_ref: str) -> bool:
    return _tree(repo, build_ref) == _tree(repo, latest_ref)


def _self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="omega-tree-test-") as root:
        repo = pathlib.Path(root)
        _run("git", "init", "-q", cwd=repo)
        _run("git", "config", "user.name", "OSGARD QA", cwd=repo)
        _run("git", "config", "user.email", "qa@example.invalid", cwd=repo)
        game = repo / SOURCE_PATH
        game.mkdir(parents=True)
        (game / "main.gd").write_text("extends Node3D\n", encoding="utf-8")
        _run("git", "add", ".", cwd=repo)
        _run("git", "commit", "-qm", "game a", cwd=repo)
        original = _run("git", "rev-parse", "HEAD", cwd=repo)
        assert is_fresh(repo, original, "HEAD"), "matching source is accepted"

        (repo / "README.md").write_text("unrelated portal update\n", encoding="utf-8")
        _run("git", "add", ".", cwd=repo)
        _run("git", "commit", "-qm", "portal b", cwd=repo)
        assert is_fresh(repo, original, "HEAD"), "portal-only changes must not block the game"

        (game / "main.gd").write_text("extends CharacterBody3D\n", encoding="utf-8")
        _run("git", "add", ".", cwd=repo)
        _run("git", "commit", "-qm", "game c", cwd=repo)
        assert not is_fresh(repo, original, "HEAD"), "new gameplay source must block an old build"
        assert is_fresh(repo, "HEAD", "HEAD"), "newest source remains publishable"

        (game / "second.gd").write_text("extends RefCounted\n", encoding="utf-8")
        _run("git", "add", ".", cwd=repo)
        _run("git", "commit", "-qm", "game d", cwd=repo)
        assert not is_fresh(repo, original, "HEAD"), "added game asset must block an old build"
        try:
            is_fresh(repo, "missing-revision", "HEAD")
        except RuntimeError:
            pass
        else:
            raise AssertionError("missing source ref must fail closed")
        try:
            is_fresh(repo, "--malicious", "HEAD")
        except ValueError:
            pass
        else:
            raise AssertionError("unsafe ref must fail closed")
    print("OMEGA SOURCE FRESHNESS: 7 verified contracts, zero failures")


def main() -> int:
    if sys.argv[1:] == ["--self-test"]:
        _self_test()
        return 0
    if len(sys.argv) != 3:
        print("usage: omega-build-freshness.py BUILD_REF LATEST_REF", file=sys.stderr)
        return 2
    try:
        original = _tree(pathlib.Path.cwd(), sys.argv[1])
        latest = _tree(pathlib.Path.cwd(), sys.argv[2])
    except (RuntimeError, ValueError, subprocess.TimeoutExpired) as exc:
        print(f"Omega source check unavailable: {exc}", file=sys.stderr)
        return 3
    if original != latest:
        print(
            f"SUPERSEDED: {SOURCE_PATH} changed after this worker started; "
            f"build tree {original[:12]} != latest {latest[:12]}. "
            "Do not overwrite the new release with old WebAssembly."
        )
        return 3
    print(f"FRESH: exact Omega game source tree {original[:12]} is current.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
