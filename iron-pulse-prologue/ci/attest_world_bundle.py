#!/usr/bin/env python3
"""Fail-closed, source-bound manifest for IRON PULSE WORLD (no upload/network)."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


BUNDLE = (
    "index.html", "styles.css", "app.js", "preflight.js", "preflight.css", "manifest.webmanifest", "sw.js",
    "assets/iron-pulse-mark.svg", "assets/gameplay-proof.png",
    "play/index.html", "play/index.js", "play/index.wasm", "play/index.pck",
)
MUST_BE_ACTUAL_GODOT = ("play/index.html", "play/index.js", "play/index.wasm", "play/index.pck")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def attest(site: Path, original_web: Path, source_screenshot: Path, sha: str) -> dict:
    site = site.resolve()
    original_web = original_web.resolve()
    source_screenshot = source_screenshot.resolve()
    assert re.fullmatch(r"[0-9a-f]{40}", sha), "Invalid exact source SHA"
    assert site.is_dir() and original_web.is_dir(), "Missing source export or world directory"
    checks = {}
    for relative in BUNDLE:
        candidate = site / relative
        assert candidate.is_file() and not candidate.is_symlink(), f"Missing or symlinked bundle entry: {relative}"
        assert candidate.resolve().is_relative_to(site), f"Unsafe bundle path: {relative}"
        size = candidate.stat().st_size
        assert size > 0, f"Empty distribution file: {relative}"
        checks[relative] = {"size": size, "sha256": sha256(candidate)}
    assert checks["play/index.wasm"]["size"] > 1_000_000, "No genuine Godot WebAssembly runtime"
    assert checks["assets/gameplay-proof.png"]["size"] > 1_000, "Missing real captured game image"
    assert source_screenshot.is_file(), "No real Chromium screenshot found"
    assert sha256(site / "assets/gameplay-proof.png") == sha256(source_screenshot), (
        "World portal artwork must be the exact, unaltered exported game screenshot"
    )
    for relative in MUST_BE_ACTUAL_GODOT:
        assert sha256(site / relative) == sha256(original_web / Path(relative).name), (
            f"World portal silently replaced or altered Godot runtime {relative}"
        )
    html = (site / "index.html").read_text(encoding="utf-8")
    js = (site / "app.js").read_text(encoding="utf-8")
    css = (site / "styles.css").read_text(encoding="utf-8")
    preflight = (site / "preflight.js").read_text(encoding="utf-8")
    sw = (site / "sw.js").read_text(encoding="utf-8")
    assert "IRON_PULSE_LOCAL_PREFLIGHT_V14" in preflight, "Local V14 preflight absent"
    assert 'id="preflight-run"' in html and './preflight.js' in html, "Preflight UI not wired"
    assert not re.search(r'\b(?:eval|Function)\s*\(', preflight), "Unsafe preflight dynamic execution"
    assert "IRON PULSE" in html and 'id="campaign-play"' in html, "Real campaign CTA absent"
    assert "./play/index.html" in js and "campaignUrl" in js, "World launch links missing"
    assert ".mini-play" in css and "min-height: 48px" in css, "44px mobile target fix absent"
    assert 'url.pathname.includes("/play/")' in sw, "Do not silently cache multi-MB game"
    assert "fetch(request).then" in sw, "Service worker must refresh its shell between versions"
    assert not re.search(r'<script[^>]+src=["\']https?://', html, re.I), "Untrusted remote executable script"
    assert not re.search(r'@import\s+url\(\s*["\']?https?://', css, re.I), "Untrusted remote CSS"
    assert not re.search(r'\b(?:eval|Function)\s*\(', js), "Frontend must not execute dynamic source"
    assert not re.search(r'\b(?:fetch|XMLHttpRequest)\s*\(', js), "Portal has no tracking or outbound API"
    evidence = {
        "schema": "IRON_PULSE_WORLD_SOURCE_BOUND_V13",
        "source_sha": sha,
        "status": "SOFTWARE_PREVIEW",
        "production_approved": False,
        "hardware_tested": False,
        "cloud_accounts_or_leaderboard": False,
        "campaign_godot_engine": "IPCampaignFlow",
        "real_gameplay_screenshot": "assets/gameplay-proof.png",
        "browser_capture_unchanged_sha256": sha256(source_screenshot),
        "runtime_verified_against_export": True,
        "files": checks,
    }
    dest = site / "assets" / "build-proof.json"
    dest.write_text(json.dumps(evidence, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return evidence


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--site", required=True, type=Path)
    p.add_argument("--web", required=True, type=Path)
    p.add_argument("--capture", required=True, type=Path)
    p.add_argument("--sha", required=True)
    args = p.parse_args()
    evidence = attest(args.site, args.web, args.capture, args.sha)
    print(f"IRON PULSE V13 WORLD BUNDLE PASS: {len(evidence['files'])} independently checked files")
    print(f"Exact source {evidence['source_sha']} | {evidence['status']}")


if __name__ == "__main__":
    main()
