#!/usr/bin/env python3
"""EMPIRE Ω R134: source-locked R87 rollback rehearsal in an isolated CI folder.

IMPORTANT: this script NEVER accesses the public server, a deployment key,
master writes, or production. It independently verifies ACTUAL master checkout
bytes, stages the real candidate Godot WebGL files, replaces the isolated
directory, restores all seven R87 files, then records exact SHA evidence.
An external Chromium test must separately open the restored R87 game;
a live HTTPS/VPS recovery or reviewer signoff is NOT implied by this check.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import shutil
import sys

HERE = Path(__file__).resolve().parent
GUARD = runpy.run_path(str(HERE / "omega-r128-r87-immutability.py"))
PINNED_FILES: dict[str, str] = GUARD["PINNED_FILES"]
PINNED_SOURCE_COMMIT: str = GUARD["PINNED_SOURCE_COMMIT"]
SHA40 = re.compile(r"^[0-9a-f]{40}$")


def digest(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open("rb") as inp:
        for block in iter(lambda: inp.read(1024 * 1024), b""):
            sha.update(block)
    return sha.hexdigest()


def assert_regular(path: Path, label: str) -> None:
    if not path.is_file() or path.is_symlink():
        raise ValueError(label + " missing or symlinked: " + str(path))
    if path.resolve().parent != path.parent.resolve():
        raise ValueError("Unsafe path escape: " + str(path))


def validate_r87(directory: Path, manifest: Path) -> dict[str, str]:
    assert_regular(manifest, "Original manifest")
    payload = json.loads(manifest.read_text("utf-8"))
    issues = GUARD["inspect_manifest"](payload)
    issues += GUARD["verify_downloaded_bytes"](directory)
    if issues:
        raise ValueError("Actual original seven R87 bytes invalid: " + "; ".join(issues))
    return {name: digest(directory / name) for name in PINNED_FILES}


def assert_candidate(directory: Path) -> dict[str, str]:
    if not directory.is_dir() or directory.is_symlink():
        raise ValueError("Actual Godot WebGL candidate directory missing/unsafe")
    hashes: dict[str, str] = {}
    for name in PINNED_FILES:
        path = directory / name
        assert_regular(path, "Candidate native WebGL file")
        if path.stat().st_size == 0:
            raise ValueError("Empty actual candidate: " + name)
        hashes[name] = digest(path)
    with (directory / "index.wasm").open("rb") as stream:
        if stream.read(4) != bytes((0, 97, 115, 109)):
            raise ValueError("Actual exported candidate WASM magic invalid")
    with (directory / "index.pck").open("rb") as stream:
        if stream.read(4) != b"GDPC":
            raise ValueError("Actual exported candidate PCK magic invalid")
    return hashes


def copy_original(source: Path, dest: Path, manifest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=False)
    for name in PINNED_FILES:
        assert_regular(source / name, "R87 source")
        shutil.copy2(source / name, dest / name, follow_symlinks=False)
    shutil.copy2(manifest, dest / "release.json", follow_symlinks=False)


def copy_candidate(source: Path, dest: Path, commit: str) -> None:
    dest.mkdir(parents=True, exist_ok=False)
    for name in PINNED_FILES:
        assert_regular(source / name, "R134 new candidate")
        shutil.copy2(source / name, dest / name, follow_symlinks=False)
    payload = {
        "engine": "Godot 4.4.1",
        "source_commit": commit,
        "artifact_kind": "ephemeral-local-CI-rehearsal-not-a-release",
        "files": {name: digest(dest / name) for name in PINNED_FILES},
        "production_authorized": False,
    }
    (dest / "release.json").write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def safe_work_dir(path: Path) -> Path:
    allowed = os.environ.get("RUNNER_TEMP")
    if not allowed:
        raise ValueError("RUNNER_TEMP is mandatory; never rehearse on source or VPS")
    real = path.absolute()
    temp = Path(allowed).resolve()
    if path.is_symlink() or not real.is_relative_to(temp) or real == temp:
        raise ValueError("R134 may only write inside a NEW dedicated RUNNER_TEMP child")
    if path.exists():
        raise ValueError("Rehearsal destination already exists; refuse overwrite: " + str(path))
    return path


def run(
    baseline: Path, manifest: Path, candidate: Path, temp_root: Path,
    evidence_dir: Path, original_head: str, baseline_git_head: str,
) -> dict:
    if not SHA40.fullmatch(original_head) or not SHA40.fullmatch(baseline_git_head):
        raise ValueError("Require exact 40-character actual Git commit SHA for both checkouts")
    sandbox = safe_work_dir(temp_root)
    output = safe_work_dir(evidence_dir)
    if sandbox == output or sandbox.is_relative_to(output) or output.is_relative_to(sandbox):
        raise ValueError("Evidence and rehearsal paths cannot overlap")
    if not baseline.is_dir() or baseline.is_symlink() or not manifest.is_file():
        raise ValueError("R87 original checked-out master source files are missing")
    original_hashes = validate_r87(baseline, manifest)
    candidate_hashes = assert_candidate(candidate)
    if candidate_hashes["index.pck"] == original_hashes["index.pck"]:
        raise ValueError("New candidate PCK identical to R87; no real restore transition")
    # The source checkout is read-only: ALL staging, takeover, restoration and
    # archived evidence live only under a fresh ephemeral GitHub runner folder.
    sandbox.mkdir(parents=True, exist_ok=False)
    output.mkdir(parents=True, exist_ok=False)
    original = sandbox / "immutable-r87-backup"
    copy_original(baseline, original, manifest)
    validate_r87(original, original / "release.json")

    live = sandbox / "localhost-live"
    copy_original(original, live, original / "release.json")
    assert digest(live / "release.json") == digest(manifest)
    validate_r87(live, live / "release.json")

    next_live = sandbox / "new-candidate-pending"
    copy_candidate(candidate, next_live, original_head)
    old_live = sandbox / "r87-before-upgrade"
    live.rename(old_live)
    next_live.rename(live)
    if json.loads((live / "release.json").read_text())["source_commit"] != original_head:
        raise ValueError("Did not actually replace R87 with candidate")
    assert_candidate(live)
    if digest(live / "index.pck") == original_hashes["index.pck"]:
        raise ValueError("Staged candidate never changed real PCK bytes")

    restore = sandbox / "verified-r87-restore"
    copy_original(original, restore, original / "release.json")
    retiring_candidate = sandbox / "candidate-before-rollback"
    live.rename(retiring_candidate)
    restore.rename(live)
    recovered_hashes = validate_r87(live, live / "release.json")
    if recovered_hashes != original_hashes:
        raise ValueError("Rollback copied R87 manifest but did not restore real bytes")
    if digest(live / "release.json") != digest(manifest):
        raise ValueError("Original R87 manifest bytes not recovered")
    for name in PINNED_FILES:
        if digest(live / name) != digest(original / name):
            raise ValueError("Rollback not byte-identical: " + name)
    result = {
        "schema": "empire-omega-r134-ephemeral-rollback-v1",
        "actual_checked_out_master_git_sha": baseline_git_head,
        "original_published_r87_source_commit": PINNED_SOURCE_COMMIT,
        "candidate_source_commit": original_head,
        "source_of_r87_bytes": "git-checkout-master-NOT-independent-live-HTTPS",
        "wasm_magic_verified": True,
        "pck_magic_verified": True,
        "exact_r87_files": 7,
        "r87_backup_sha256": original_hashes,
        "candidate_real_godot_sha256": candidate_hashes,
        "restored_r87_sha256": recovered_hashes,
        "original_release_manifest_sha256": digest(manifest),
        "restored_release_manifest_sha256": digest(live / "release.json"),
        "candidate_really_installed_then_rolled_back_in_ephemeral_runner": True,
        "all_seven_restored_bytes_identical_to_checked_out_master": True,
        "browser_original_r87_verified": False,  # must be changed by separate REAL Chromium step
        "real_production_vps_touched": False,
        "production_restore_rehearsed": False,
        "independent_live_https_r87_download_verified": False,
        "real_user_art_approved": False,
        "real_physical_devices_verified": False,
        "production_authorized": False,
    }
    path = output / "R134_ISOLATED_ROLLBACK.json"
    path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print("R134 PASS: staged real candidate and restored 7/7 exact original")
    print("R87 master checkout and original release.json SHA-256 verified")
    print("ALL actions isolated under RUNNER_TEMP; production NEVER touched")
    print("RESULT=" + str(path))
    print("LOCAL_RESTORED_DIR=" + str(live))
    return result


def self_test() -> None:
    good = {"source_commit": PINNED_SOURCE_COMMIT, "files": dict(PINNED_FILES)}
    assert GUARD["inspect_manifest"](good) == []
    good["files"]["index.pck"] = "0" * 64
    assert GUARD["inspect_manifest"](good)
    assert len(PINNED_FILES) == 7
    assert not SHA40.fullmatch("not-an-actual-git-commit")
    assert not os.getenv("EMPIRE_R134_ALLOW_PRODUCTION")
    print("R134 PASS: fail-closed real-byte guard and production prohibition self-test")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--temp-root", type=Path)
    parser.add_argument("--evidence-dir", type=Path)
    parser.add_argument("--candidate-sha")
    parser.add_argument("--baseline-git-sha")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test()
            return 0
        if any(v is None for v in (
            args.baseline, args.manifest, args.candidate, args.temp_root,
            args.evidence_dir, args.candidate_sha, args.baseline_git_sha
        )):
            parser.error("Actual master baseline, real Godot WebGL candidate and TWO SHA required")
        run(args.baseline, args.manifest, args.candidate,
            args.temp_root, args.evidence_dir, args.candidate_sha,
            args.baseline_git_sha)
        return 0
    except (OSError, ValueError, AssertionError, KeyError, json.JSONDecodeError) as exc:
        print("R134 ISOLATED ROLLBACK FAIL CLOSED:", exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
