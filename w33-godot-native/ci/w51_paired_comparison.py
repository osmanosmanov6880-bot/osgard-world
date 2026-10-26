#!/usr/bin/env python3
"""W50-W51 original W47 vs W48 same-runner Godot/SwiftShader evidence.

Both builds are pristine SHA-pinned Godot WebGL exports. This job verifies
nonblank original 3D frames, records comparable native Godot FPS and W48
draw calls, but never treats moving-frame pixels as exact geometry parity,
a software renderer as customer hardware, or 1 paired run as statistical proof.
"""
import argparse
import hashlib
import json
import statistics
import threading
from functools import partial
from pathlib import Path
from http.server import ThreadingHTTPServer

from playwright.sync_api import sync_playwright
from godot_software_performance import (
    StaticServer, await_quality, measure, real_quality_click, state, visit
)
from visual_art_acceptance import render, compare, montage

W47_PINNED_SHA = "14be69cdaa1fdffa4e209645eed0b1964581858a"
MODES = (
    ("desktop_hero", 1366, 768, False, "hero", ("w47", "w48")),
    ("desktop_eco", 1366, 768, False, "eco", ("w48", "w47")),
    ("touch_hero", 390, 844, True, "hero", ("w47", "w48")),
)


def verify_export(folder, sha):
    folder = folder.resolve(strict=True)
    for name in ("index.html", "index.js", "index.wasm", "index.pck", "evidence.json"):
        if not (folder / name).is_file():
            raise ValueError("Pristine Godot export missing " + name + ": " + str(folder))
    evidence = json.loads((folder / "evidence.json").read_text(encoding="utf-8"))
    if evidence.get("source_commit") != sha or evidence.get("godot_release") != "4.4.1":
        raise ValueError("W47/W48 WebGL export not bound to requested source: " + str(folder))
    for entry in evidence.get("files", []):
        file = folder / entry["name"]
        if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError("Changed WebGL export asset: " + str(file))
    return folder


def serve(folder):
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(StaticServer, directory=str(folder)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, "http://127.0.0.1:%s/index.html" % server.server_port


def record(browser, url, out, label, scenario, width, height, touch, quality):
    ctx, page, marker, errors = visit(browser, url, width, height, touch)
    try:
        if quality == "eco":
            real_quality_click(page, marker)
            await_quality(page, marker, "eco")
        actual = state(marker)
        if actual.get("mission") != -1 or actual.get("view") != 0 or actual.get("quality") != quality:
            raise AssertionError("Mismatched native 3D scenario: " + str(actual))
        # W47 has genuine Godot FPS telemetry, but predates drawcall fields.
        # Strict W48 counter requirements are never waived for the candidate.
        timing = measure(page, marker, quality, period=9, require_draw_calls=(label == "w48"))
        image_file = out / (label + "_" + scenario + ".png")
        pixels = render(page, image_file)
        if errors:
            raise AssertionError("Actual browser errors: " + repr(errors))
        if timing["godot_rendered_frames_progressed"] is not True:
            raise AssertionError("Godot was frozen: " + label)
        return {
            "build": label,
            "scenario": scenario,
            "viewport": [width, height],
            "touch_emulated": touch,
            "engine": timing,
            "frame": pixels,
            "source_instrumented": False,
            "real_physical_device": False,
        }
    finally:
        ctx.close()


def analyze(records, out):
    indexed = {(rec["scenario"], rec["build"]): rec for rec in records}
    comparisons = []
    shots = []
    for scenario, _, _, _, mode, _ in MODES:
        old = indexed[(scenario, "w47")]
        new = indexed[(scenario, "w48")]
        old_fps = float(old["engine"]["godot_engine_fps_median"])
        new_fps = float(new["engine"]["godot_engine_fps_median"])
        old_image = out / old["frame"]["image"]
        new_image = out / new["frame"]["image"]
        shots.append((scenario + " / W47", old_image))
        shots.append((scenario + " / W48", new_image))
        comparisons.append({
            "scenario": scenario,
            "quality": mode,
            "baseline_w47_fps_median": old_fps,
            "candidate_w48_fps_median": new_fps,
            "single_pair_observed_fps_change_percent": round(100.0 * (new_fps - old_fps) / old_fps, 2) if old_fps > 0 else None,
            "candidate_w48_draw_calls_median": new["engine"]["render_draw_calls_median"],
            "candidate_w48_objects_median": new["engine"]["render_objects_median"],
            "baseline_draw_calls": old["engine"]["render_draw_calls_median"],
            "pristine_w47_draw_calls_unavailable": old["engine"]["render_draw_call_samples"] == 0,
            "non_deterministic_animated_pixel_difference_mean": compare(old_image, new_image),
            "pixel_identical_asserted": False,
            "performance_improvement_certified": False,
        })
    montage(shots, out / "W50_W47_W48_ORIGINAL_RENDER_SIDE_BY_SIDE.png")
    return comparisons


def run(base, candidate, base_sha, candidate_sha, out):
    if base_sha != W47_PINNED_SHA:
        raise ValueError("W47 original code baseline unexpectedly moved")
    if candidate_sha == base_sha or len(candidate_sha) != 40 or any(x not in "0123456789abcdef" for x in candidate_sha):
        raise ValueError("Expected a distinct exact W48 commit SHA")
    base = verify_export(base, base_sha)
    candidate = verify_export(candidate, candidate_sha)
    out.mkdir(parents=True, exist_ok=True)
    report = {
        "schema": "OSGARD_W50_W51_PRISTINE_GODOT_PAIRED_SW_WEBGL_V1",
        "status": "FAIL",
        "baseline_w47_sha": base_sha,
        "candidate_w48_sha": candidate_sha,
        "godot_release": "4.4.1",
        "renderer": "Chromium software WebGL SwiftShader, shared CI runner",
        "same_renderer_and_runner": True,
        "pristine_git_exports_no_probe_injected": True,
        "pixel_parity_certified": False,
        "statistical_speedup_certified": False,
        "physical_phone_gpu_certified": False,
        "production_published": False,
        "observations": [],
        "comparisons": [],
    }
    servers = []
    try:
        w47_server, w47_url = serve(base)
        servers.append(w47_server)
        w48_server, w48_url = serve(candidate)
        servers.append(w48_server)
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True, args=[
                "--enable-webgl", "--ignore-gpu-blocklist",
                "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                "--disable-dev-shm-usage",
            ])
            try:
                for scenario, width, height, touch, quality, order in MODES:
                    for label in order:
                        url = w47_url if label == "w47" else w48_url
                        report["observations"].append(
                            record(browser, url, out, label, scenario, width, height, touch, quality)
                        )
            finally:
                browser.close()
        if len(report["observations"]) != 6:
            raise AssertionError("Missing original W47/W48 scenario pairs")
        report["comparisons"] = analyze(report["observations"], out)
        if any(obs["build"] == "w48" and obs["engine"]["render_draw_call_samples"] < 3
               for obs in report["observations"]):
            raise AssertionError("W48 candidate has no real renderer submission measurement")
        report["status"] = "PASS"
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()
        (out / "w50-w51-paired-evidence.json").write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
    print(json.dumps({"status": report["status"], "source": candidate_sha,
                      "paired_scenarios": len(report["comparisons"])}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline-export", required=True, type=Path)
    parser.add_argument("--candidate-export", required=True, type=Path)
    parser.add_argument("--baseline-sha", required=True)
    parser.add_argument("--candidate-sha", required=True)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    run(args.baseline_export, args.candidate_export, args.baseline_sha,
        args.candidate_sha, args.out)
