#!/usr/bin/env python3
"""Produce an UNREVIEWED W20 checksum draft from actual GitHub Actions bytes.

Never self-approve layout, real hardware, AAA or production publishing.
A successful exact-source GitHub run and visual inspection are separate.
"""
from __future__ import annotations
import argparse
import importlib.util
import json
from pathlib import Path

src = Path(__file__).with_name("r135-w20-promotion-qa.py")
spec = importlib.util.spec_from_file_location("osgard_w20_review", src)
assert spec and spec.loader
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def make_unreviewed_draft(root: Path, source_sha: str,
                          run_id: int, artifact_id: int, native_run_id: int) -> dict:
    gate.require(bool(gate.SHA40.fullmatch(source_sha)), "expected exact source SHA")
    gate.require(type(run_id) is int and run_id > 0, "run ID must be positive")
    gate.require(type(artifact_id) is int and artifact_id > 0, "artifact ID must be positive")
    gate.require(type(native_run_id) is int and native_run_id > 0, "native run ID must be positive")
    release = root / "r135-optimized-release"
    zip_file = release / "OSGARD_R135_OPTIMIZED_WEB.zip"
    manifest_file = release / "R135_OPTIMIZED_MANIFEST.json"
    gate.require(zip_file.is_file() and manifest_file.is_file(),
                 "successful packaged optimized Godot artifact is missing")
    manifest = json.loads(manifest_file.read_bytes())
    gate.require(manifest.get("version") == gate.VERSION and
                 manifest.get("source_commit") == source_sha and
                 manifest.get("engine") == "Godot 4.4.1" and
                 manifest.get("webgl_browser_software_smoke") == "passed",
                 "not completed exact-source W19 Godot WebGL manifest")
    gate.previous.verify_archive(zip_file, manifest)

    expected = root / "r135-w10-release-evidence.json"
    gate.require(expected.is_file(), "W10 source-matched release proof not passed")
    proof = json.loads(expected.read_bytes())
    manifest_sha = gate.digest(manifest_file)
    archive_sha = gate.digest(zip_file)
    gate.require(proof.get("status") == "PASS" and
                 proof.get("source_commit") == source_sha and
                 proof.get("manifest_sha256") == manifest_sha and
                 proof.get("archive_sha256") == archive_sha and
                 proof.get("hardware_gpu_fps_certified") is False,
                 "W10 exact-asset acceptance absent or incomplete")

    screens = root / "r135-screens"
    hashes = {}
    for name in gate.FRAMES:
        frame = screens / name
        gate.require(frame.is_file(), "required original browser screenshot missing: " + name)
        sha = gate.digest(frame)
        gate.previous.verify_png(frame, sha)
        hashes[name] = sha
    gate.require(len(set(hashes.values())) == len(gate.FRAMES), "duplicate screenshots")

    # False means reviewer has NOT signed off. Gate.verify_pin rejects this draft.
    result = {
        "version": gate.VERSION,
        "source_commit": source_sha,
        "artifact_run_id": run_id,
        "artifact_id": artifact_id,
        "native_run_id": native_run_id,
        "artifact_name": "osgard-r135-optimized-web-qa",
        "manifest_sha256": manifest_sha,
        "archive_sha256": archive_sha,
        "screenshots_sha256": hashes,
        "reviewed_luxury_desktop": False,
        "reviewed_luxury_mobile": False,
        "reviewed_settings_desktop": False,
        "reviewed_settings_mobile": False,
        "reviewed_settings_persistence": False,
        "reviewed_no_overlap": False,
        "reviewed_ru_en": False,
        "browser_three_fault_cases": False,
        "physical_phone_fps_verified": False,
        "photorealistic_aaa_certified": False,
        "review_provenance": "UNREVIEWED draft; inspect the original PNGs and actual gameplay logs before attestation",
    }
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--run-id", type=int, required=True)
    parser.add_argument("--artifact-id", type=int, required=True)
    parser.add_argument("--native-run-id", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    value = make_unreviewed_draft(args.artifact, args.source, args.run_id, args.artifact_id, args.native_run_id)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("W20 UNREVIEWED checksum draft produced; NOT a promotion pin:", args.output)


if __name__ == "__main__":
    main()
