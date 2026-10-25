#!/usr/bin/env python3
"""R88: safely extract ORIGINAL published Godot screenshots from verified R84.

This is a private ART REVIEW STARTER, not AAA or physical-phone certification.
Requires source-bound 7/7 local+public hashes and genuine zero-flaky Chromium
tests through the unchanged R83/R50 release gate before accepting any pixels.
"""
from __future__ import annotations

import argparse
import base64
import binascii
import json
import os
import struct
import sys
from pathlib import Path

import omega_r73_field_qa as r73
import omega_r83_release_gate as r83
import omega_r86_private_field_kit as kit

MAX_PNG_BYTES = 8 * 1024 * 1024
SOURCE_SCREENSHOT = "godot-real-world-initial.png"
PROOF_SCHEMA = "empire-omega-r88-original-published-frame-intake-v1"
FRAMES = {
    "desktop-chromium": ("1366x768", "r88-real-desktop.png"),
    "touch-phone-chromium": ("390x844", "r88-real-touch-portrait.png"),
}


def require(ok: bool, reason: str) -> None:
    if not ok:
        raise ValueError(reason)


def specs_of(suites: list) -> list[dict]:
    result = []
    for suite in suites:
        require(isinstance(suite, dict), "invalid original Playwright suite")
        for spec in suite.get("specs", []):
            require(isinstance(spec, dict), "invalid original Playwright spec")
            result.append(spec)
        for nested in suite.get("suites", []):
            result.extend(specs_of([nested]))
    return result


def original_png_attachments(report: dict) -> dict[str, bytes]:
    """Decode only two genuinely passed source reporter test screenshot bodies.

    R83/R50 verifies real test status/pixels/browsers BEFORE this function is
    called in production. Synthetic unit-test reporters cannot create a GO.
    """
    found: dict[str, bytes] = {}
    for spec in specs_of(report["suites"]):
        for test in spec.get("tests", []):
            require(isinstance(test, dict), "malformed original browser test")
            project = test.get("projectName")
            if project not in FRAMES:
                continue
            require(project not in found, "duplicate original Chromium project")
            results = test.get("results")
            require(test.get("status") == "expected" and isinstance(results, list)
                    and len(results) == 1 and isinstance(results[0], dict)
                    and results[0].get("status") == "passed"
                    and results[0].get("retry") == 0,
                    "not an original zero-retry passed Playwright project: " + project)
            attachments = results[0].get("attachments")
            require(isinstance(attachments, list), "original attachments missing")
            matches = [a for a in attachments if isinstance(a, dict) and
                       a.get("name") == SOURCE_SCREENSHOT and
                       a.get("contentType") == "image/png"]
            require(len(matches) == 1, "missing/duplicated real Godot initial frame: " + project)
            body = matches[0].get("body")
            require(isinstance(body, str) and 100 <= len(body) <=
                    (MAX_PNG_BYTES * 4 // 3 + 16),
                    "original screenshot body empty or too large")
            try:
                raw = base64.b64decode(body, validate=True)
            except (ValueError, binascii.Error) as exc:
                raise ValueError("invalid original screenshot base64") from exc
            require(100 <= len(raw) <= MAX_PNG_BYTES and
                    raw[:8] == r73.PNG_SIGNATURE and len(raw) >= 24,
                    "original screenshot is not bounded PNG")
            w, h = struct.unpack(">II", raw[16:24])
            if project == "desktop-chromium":
                require(850 <= w <= 1366 and 475 <= h <= 768 and
                        abs(w / h - 1366 / 768) < 0.025,
                        "original desktop PNG wrong viewport/proportion")
            else:
                require((w, h) == (390, 844),
                        "original portrait PNG must be true 390x844")
            found[project] = raw
    require(set(found) == set(FRAMES),
            "both original desktop and touch Playwright project screenshots required")
    require(found["desktop-chromium"] != found["touch-phone-chromium"],
            "reused screenshot cannot represent two viewports")
    return found


def write_new(path: Path, body: bytes) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(body)
    except BaseException:
        path.unlink(missing_ok=True)
        raise


def export_verified_frames(root: Path, manifest: Path, live: Path,
                           browser: Path) -> dict:
    source = kit.pin_source(root, manifest)
    require(not live.is_symlink() and not browser.is_symlink(),
            "original R84 inputs cannot be symlinks")
    release = r83.load_object(manifest)
    # Re-run original full source-bound R83/R50 7-local + 7-HTTP SHA AND
    # zero-flaky real desktop/touch validation. Do not trust JSON success text.
    r83.source_bound_public_webgl(
        release, kit.REPO / "public/games/omega-3d-preview", live, browser)
    actual = r83.load_original_browser_report(browser)
    decoded = original_png_attachments(actual)
    dest = root / "art"
    result_files = [dest / FRAMES[p][1] for p in FRAMES]
    output_names = ("r88-frame-provenance.json", "art-review.template.json",
                    "R88-MISSING-EVIDENCE.md")
    require(all(not p.exists() and not p.is_symlink()
                for p in [*result_files, *(dest / n for n in output_names)]),
            "refusing overwrite of original art evidence or an existing reviewer template")
    created: list[Path] = []
    try:
        frames = []
        for project, (view, name) in FRAMES.items():
            image_path = dest / name
            write_new(image_path, decoded[project])
            created.append(image_path)
            # Full CRC + bounded PNG scanline/decompression validation reuses R73.
            r73.validate_decodable_png(image_path)
            frames.append({"viewport": view, "file": name,
                           "sha256": kit.sha256(image_path)})
        proof = {
            "schema": PROOF_SCHEMA,
            "source_commit": source,
            "original_r84_browser_sha256": kit.sha256(browser),
            "original_r84_live_integrity_sha256": kit.sha256(live),
            "actual_published_godot_frames": frames,
            "independent_art_review_complete": False,
            "missing_original_viewports": ["320x568", "844x390"],
            "original_20_player_sessions_proven": False,
            "aaa_quality_certified": False,
            "production_go": False,
        }
        art_template = {
            "schema": "empire-omega-r83-original-art-v1",
            "source_commit": source,
            "reviewer": "",
            "real_godot_frames_reviewed": False,
            "assets": [],
            "screenshots": frames,
            "_note": "PARTIAL ORIGINALS ONLY: independent art/licence review and 2 real viewports missing.",
        }
        instruction = (
            "# R88 PARTIAL original art evidence — NOT a game AAA certificate\n\n"
            "Two originals extracted only after genuine R83/R50 live/source/WebGL\n"
            "verification. Original R84 desktop is an authentic downsampled\n"
            "1366x768 CDP screenshot; touch portrait is native 390x844.\n\n"
            "Still required: original Godot 320x568 and 844x390 captures,\n"
            "licence inventory, manual semantic assessment of actual game\n"
            "art/lighting/UI/audio, reviewer name and independent review.\n"
            "Copy art-review.template.json to art-review.json, add the two\n"
            "MISSING genuine screens with SHA, licence assets and only AFTER\n"
            "real human review set real_godot_frames_reviewed=true.\n"
            "Run the original R86 audit again; production_go always remains false.\n"
            "Keep all media in this private, source-pinned QA workspace.\n"
        )
        for name, value in (
            ("r88-frame-provenance.json",
             (json.dumps(proof, ensure_ascii=False, indent=2) + "\n").encode()),
            ("art-review.template.json",
             (json.dumps(art_template, ensure_ascii=False, indent=2) + "\n").encode()),
            ("R88-MISSING-EVIDENCE.md", instruction.encode()),
        ):
            path = dest / name
            write_new(path, value)
            created.append(path)
    except BaseException:
        for item in created:
            item.unlink(missing_ok=True)
        raise
    return {
        "status": "PARTIAL_ORIGINAL_ART_EVIDENCE_ONLY",
        "source_commit": source,
        "verified_original_frames": 2,
        "still_missing_original_viewports": ["320x568", "844x390"],
        "source_and_genuine_webgl_preflight": "PASS",
        "independent_art_review_complete": False,
        "production_go": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kit-root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, default=kit.DEFAULT_MANIFEST)
    args = parser.parse_args()
    try:
        root = kit.private_root(args.kit_root)
        result = export_verified_frames(
            root, args.manifest, root / "web/live-integrity.json",
            root / "web/playwright.json")
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError, TypeError, KeyError, OverflowError,
            json.JSONDecodeError) as exc:
        print(json.dumps({"status": "HOLD", "production_go": False,
                          "reason": str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
