#!/usr/bin/env python3
"""Fail closed if a Godot Web export is older than its actual runtime inputs.

Game documentation under godot/empire-omega/docs/*.md is not a runtime
asset. Adding a release checklist after the native export must not falsely
mark its WASM/PCK as SUPERSEDED. Every other tracked file remains part of
the immutable release fingerprint, including scripts, tests, scenes, audio,
textures, imports, and any non-Markdown file under docs/.

Exit 0: all tracked runtime-related Git entries are identical.
Exit 3: changed files or unavailable/invalid comparison. Never deploy.
"""
from __future__ import annotations

import hashlib
import pathlib
import re
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


def _validate_ref(ref: str) -> None:
    # Needed refs are full Git commit SHA, HEAD, or origin/master. Do not
    # accept -options, path-escape suffixes, or shell-style ambiguity.
    if not re.fullmatch(r"[A-Za-z0-9_./-]+", ref or "") or ref.startswith("-") or ".." in ref:
        raise ValueError("unsafe or blank git ref")


def _tree(repo: pathlib.Path, ref: str) -> str:
    _validate_ref(ref)
    return _run("git", "rev-parse", "--verify", f"{ref}:{SOURCE_PATH}", cwd=repo)


def _runtime_entries(repo: pathlib.Path, ref: str) -> list[bytes]:
    _tree(repo, ref)  # exact Git object exists; invalid refs fail closed
    result = subprocess.run(
        ["git", "ls-tree", "-r", "-z", f"{ref}:{SOURCE_PATH}"],
        cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        check=False, timeout=15,
    )
    if result.returncode:
        raise RuntimeError(
            f"git ls-tree failed ({result.returncode}): "
            f"{result.stderr.decode('utf-8', errors='replace')[:200]}"
        )
    entries: list[bytes] = []
    for entry in result.stdout.split(b"\x00"):
        if not entry:
            continue
        fields = entry.split(b"\t", 1)
        if len(fields) != 2 or len(fields[0].split()) != 3:
            raise RuntimeError("invalid Git tree entry")
        meta, relative_path = fields
        # Markdown release notes are human documentation, NOT inputs to Godot
        # native Web export. Exempt nothing outside docs/ and no scene/resource
        # files even inside docs/; fail closed on any other file changes.
        if relative_path.startswith(b"docs/") and relative_path.lower().endswith(b".md"):
            continue
        entries.append(meta + b"\t" + relative_path)
    if not entries:
        raise RuntimeError("no runtime files found in game source tree")
    return sorted(entries)


def runtime_fingerprint(repo: pathlib.Path, ref: str) -> str:
    digest = hashlib.sha256()
    for entry in _runtime_entries(repo, ref):
        digest.update(entry)
        digest.update(b"\x00")
    return digest.hexdigest()


def is_fresh(repo: pathlib.Path, build_ref: str, latest_ref: str) -> bool:
    return runtime_fingerprint(repo, build_ref) == runtime_fingerprint(repo, latest_ref)


def _self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="omega-runtime-git-test-") as root:
        repo = pathlib.Path(root)
        _run("git", "init", "-q", cwd=repo)
        _run("git", "config", "user.name", "OSGARD QA", cwd=repo)
        _run("git", "config", "user.email", "qa@example.invalid", cwd=repo)
        game = repo / SOURCE_PATH
        game.mkdir(parents=True)
        (game / "main.gd").write_text("extends Node3D\n", encoding="utf-8")
        _run("git", "add", ".", cwd=repo)
        _run("git", "commit", "-qm", "original runtime", cwd=repo)
        original = _run("git", "rev-parse", "HEAD", cwd=repo)
        assert is_fresh(repo, original, "HEAD"), "exact same source must pass"

        (repo / "README.md").write_text("unrelated portal change\n", encoding="utf-8")
        _run("git", "add", ".", cwd=repo)
        _run("git", "commit", "-qm", "portal only", cwd=repo)
        assert is_fresh(repo, original, "HEAD"), "other website files must not block"

        docs = game / "docs"
        docs.mkdir()
        (docs / "R61-REAL-PUBLIC-DRIVING-ACCEPTANCE.md").write_text("QA only\n", encoding="utf-8")
        _run("git", "add", ".", cwd=repo)
        _run("git", "commit", "-qm", "new Markdown release evidence", cwd=repo)
        assert is_fresh(repo, original, "HEAD"), "docs-only change must not supersede WASM"
        docs_ref = _run("git", "rev-parse", "HEAD", cwd=repo)
        (docs / "R61-REAL-PUBLIC-DRIVING-ACCEPTANCE.md").write_text("New QA wording\n", encoding="utf-8")
        _run("git", "add", ".", cwd=repo)
        _run("git", "commit", "-qm", "edited Markdown evidence", cwd=repo)
        assert is_fresh(repo, docs_ref, "HEAD"), "edited Markdown must not supersede"
        assert is_fresh(repo, original, "HEAD"), "multiple Markdown revisions are safe"

        (game / "main.gd").write_text("extends CharacterBody3D\n", encoding="utf-8")
        _run("git", "add", ".", cwd=repo)
        _run("git", "commit", "-qm", "real game changed", cwd=repo)
        assert not is_fresh(repo, original, "HEAD"), "GDScript modification MUST block old WASM"
        newest = _run("git", "rev-parse", "HEAD", cwd=repo)
        assert is_fresh(repo, newest, "HEAD"), "latest game source must pass"

        (game / "level.tscn").write_text("[gd_scene format=3]\n", encoding="utf-8")
        _run("git", "add", ".", cwd=repo)
        _run("git", "commit", "-qm", "new scene", cwd=repo)
        assert not is_fresh(repo, newest, "HEAD"), "new playable scene MUST block"
        newest = _run("git", "rev-parse", "HEAD", cwd=repo)

        (docs / "resource.tres").write_text("[gd_resource type=\"Resource\"]\n", encoding="utf-8")
        _run("git", "add", ".", cwd=repo)
        _run("git", "commit", "-qm", "potential game asset under docs", cwd=repo)
        assert not is_fresh(repo, newest, "HEAD"), "only docs Markdown is exempt"
        newest = _run("git", "rev-parse", "HEAD", cwd=repo)

        (game / "audio.wav").write_bytes(b"original game audio")
        _run("git", "add", ".", cwd=repo)
        _run("git", "commit", "-qm", "new audio", cwd=repo)
        assert not is_fresh(repo, newest, "HEAD"), "game media MUST block"
        newest = _run("git", "rev-parse", "HEAD", cwd=repo)

        (game / "main.gd").unlink()
        _run("git", "add", ".", cwd=repo)
        _run("git", "commit", "-qm", "remove game code", cwd=repo)
        assert not is_fresh(repo, newest, "HEAD"), "removing a script MUST block"
        for invalid in ("missing-revision", "--malicious", "HEAD:outside"):
            try:
                is_fresh(repo, invalid, "HEAD")
            except (RuntimeError, ValueError):
                pass
            else:
                raise AssertionError(f"invalid source ref accepted: {invalid}")
    print("OMEGA R69 SOURCE FRESHNESS: 12 real-Git safety conditions verified")


def main() -> int:
    if sys.argv[1:] == ["--self-test"]:
        _self_test()
        return 0
    if len(sys.argv) != 3:
        print("usage: omega-build-freshness.py BUILD_REF LATEST_REF", file=sys.stderr)
        return 2
    try:
        original = runtime_fingerprint(pathlib.Path.cwd(), sys.argv[1])
        latest = runtime_fingerprint(pathlib.Path.cwd(), sys.argv[2])
    except (RuntimeError, ValueError, subprocess.TimeoutExpired) as exc:
        print(f"Omega source check unavailable: {exc}", file=sys.stderr)
        return 3
    if original != latest:
        print(
            f"SUPERSEDED: {SOURCE_PATH} runtime files changed after export; "
            f"build fingerprint {original[:12]} != latest {latest[:12]}. "
            "Do not overwrite newer game assets with old WebAssembly."
        )
        return 3
    print(f"FRESH: exact tracked Godot runtime inputs {original[:12]} are current.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
