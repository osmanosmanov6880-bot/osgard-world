#!/usr/bin/env python3
"""W67: real exported WebGL, actual source-linked industrial camera navigation.

No frontend mockups. Only native input (N/W/A/1/4) is sent to the Godot
canvas. State marker is READ ONLY. All PNG evidence is a real Chromium frame.
"""
import argparse
import functools
import hashlib
import io
import json
import threading
from pathlib import Path

from PIL import Image, ImageChops, ImageStat
from playwright.sync_api import sync_playwright
from w64_browser_acceptance import HTTPHandler, LocalServer, geometry, snapshot, wait_state


def require(condition, failure):
    if not condition:
        raise AssertionError(failure)


def diff_pixels(before, after, crop=None):
    a = Image.open(io.BytesIO(before)).convert("RGB")
    b = Image.open(io.BytesIO(after)).convert("RGB")
    require(a.size == b.size, "Screenshots must use same actual viewport size")
    if crop is not None:
        a = a.crop(crop)
        b = b.crop(crop)
    delta = ImageChops.difference(a, b).convert("L")
    return sum(delta.histogram()[12:])


def actual_stage_crop(raw):
    image = Image.open(io.BytesIO(raw)).convert("RGB")
    width, height = image.size
    crop = (int(width * 0.18), int(height * 0.20),
            int(width * 0.84), int(height * 0.71))
    return crop, max(ImageStat.Stat(image.crop(crop)).stddev)


def run(web, evidence, exact_sha):
    require(len(exact_sha) == 40 and all(ch in "0123456789abcdef" for ch in exact_sha),
            "Full exact source SHA is required")
    require((web / "index.html").exists() and
            (web / "index.wasm").read_bytes()[:4] == b"\0asm",
            "Only actual Godot WebAssembly export accepted")
    evidence.mkdir(parents=True, exist_ok=True)
    errors = []
    with LocalServer(("127.0.0.1", 0),
                     functools.partial(HTTPHandler, directory=str(web))) as http:
        threading.Thread(target=http.serve_forever, daemon=True).start()
        address = f"http://127.0.0.1:{http.server_address[1]}/index.html"
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True, args=[
                "--no-sandbox", "--disable-dev-shm-usage",
                "--enable-webgl", "--use-gl=angle",
                "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
            ])
            context = browser.new_context(
                viewport={"width": 1366, "height": 900},
                device_scale_factor=1,
            )
            page = context.new_page()
            page.on("pageerror", lambda e: errors.append(str(e)))
            page.goto(address, wait_until="domcontentloaded", timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached", timeout=180000)
            first = wait_state(page, {
                "shift": 0, "status": "playing",
                "real_native_3d": True, "w67_two_3d_sectors": True,
                "w67_inspection_sector": 0, "w67_walk_progress": 0.0,
            })
            require(first["scene_meshes"] >= 75, "Original W64 3D was removed")
            require(first["w67_cathedral_meshes"] >= 260,
                    "Extra real cathedral industrial geometry missing")
            require(first["history_count"] == 0, "Ghost gameplay event at opening")
            canvas = page.locator("canvas").first
            require(canvas.count() == 1, "No actual Godot WebGL canvas")
            canvas.click(position={"x": 18, "y": 18})
            page.wait_for_timeout(550)
            core = page.screenshot(path=str(evidence / "w67-01-core-chamber-1366.png"))
            crop, spread = actual_stage_crop(core)
            require(spread > 6.0, "Core room rendered an unlit/blank image")
            print("W67 FIRST FRAME VISUAL STDDEV", spread, "stage crop", crop, flush=True)

            # N changes real Godot camera and reveals an actually MODELED
            # second industrial room, without changing deterministic gameplay.
            page.keyboard.press("n")
            relay = wait_state(page, {
                "w67_inspection_sector": 1, "w67_walk_progress": 1.0,
                "history_count": 0, "shift": 0,
            })
            require(relay["w67_nav_steps"] >= 1,
                    "Guided 3D camera selection did not register")
            page.wait_for_timeout(550)
            relay_png = page.screenshot(
                path=str(evidence / "w67-02-relay-sector-1366.png"))
            require(diff_pixels(core, relay_png, crop) > 800,
                    "Second actual sector is not visually distinct from core")
            _, relay_contrast = actual_stage_crop(relay_png)
            require(relay_contrast > 6.0, "Actual relay room is blank")

            page.keyboard.press("a")
            page.wait_for_function("""() => {
                const e=document.getElementById('a7-cascade-native-state');
                if (!e) return false;
                const d=JSON.parse(e.getAttribute('data-state'));
                return d.w67_walk_progress<1 && d.w67_walk_progress>0.7;
            }""", timeout=50000)
            require(snapshot(page)["history_count"] == 0,
                    "Camera walk was recorded as an actual gameplay decision")
            page.keyboard.press("w")
            wait_state(page, {"w67_walk_progress": 1.0})
            page.keyboard.press("n")
            wait_state(page, {"w67_inspection_sector": 0,
                              "w67_walk_progress": 0.0})

            # Preserve original W63 decisions and changing 3D material/state.
            page.keyboard.press("1")
            decision = wait_state(page, {"actions_left": 1, "history_count": 1})
            require(decision["metrics"]["heat"] == 42 and
                    decision["metrics"]["energy"] == 79,
                    "Original PUMP tradeoff broken by visual overhaul")
            page.keyboard.press("4")
            shift = wait_state(page, {"shift": 1, "history_count": 2})
            require(shift["metrics"]["heat"] == 59 and
                    shift["metrics"]["signal"] == 61,
                    "Original six-cycle deterministic incident rules changed")
            page.wait_for_timeout(300)
            reactor_after = page.screenshot(
                path=str(evidence / "w67-03-real-reactive-1366.png"))
            require(diff_pixels(core, reactor_after, crop) > 250,
                    "Genuine reactor 3D state failed to react after two decisions")

            page.set_viewport_size({"width": 390, "height": 844})
            page.wait_for_function("""() => {
                const e=document.getElementById('a7-cascade-native-state');
                if (!e) return false;
                const g=JSON.parse(e.getAttribute('data-geometry'));
                return g.viewport[0] <= 420 && g.stage_requested_height<=310;
            }""", timeout=60000)
            page.keyboard.press("n")
            wait_state(page, {"w67_inspection_sector": 1,
                              "history_count": 2, "shift": 1})
            page.wait_for_timeout(300)
            mobile = page.screenshot(
                path=str(evidence / "w67-04-relay-mobile-390.png"))
            image = Image.open(io.BytesIO(mobile)).convert("RGB")
            require(image.size == (390, 844), "Mobile original PNG wrong dimensions")
            require(max(ImageStat.Stat(image).stddev) > 6.0,
                    "No visible original mobile WebGL content")
            require(not errors, "Actual WASM app uncaught JS errors: " +
                    " | ".join(errors[:4]))
            context.close()
            browser.close()
        http.shutdown()
    pictures = []
    for path in sorted(evidence.glob("*.png")):
        pictures.append({
            "file": path.name,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "size": path.stat().st_size,
        })
    require(len(pictures) == 4, "Four independently sourced original visual frames required")
    proof = {
        "schema": "LAST_FRONTIER_W67_TWO_ZONE_ACTUAL_WEBGL_V1",
        "source_sha": exact_sha,
        "status": "PASS", "actual_godot_webassembly": True,
        "real_native_3d_rooms": 2, "genuine_godot_gameplay_input": True,
        "navigation_keys": ["N", "W", "A"],
        "original_gameplay_keys": ["1", "4"],
        "all_screenshots_from_real_browser": True,
        "source_webgl_sha256": hashlib.sha256((web / "index.wasm").read_bytes()).hexdigest(),
        "physical_mobile_gpu_certified": False,
        "human_art_director_approved": False,
        "production_approved": False,
        "publicly_deployed": False,
        "pictures": pictures,
    }
    (evidence / "W67_ACTUAL_BROWSER_PROOF.json").write_text(
        json.dumps(proof, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("LAST FRONTIER W67 TRUE TWO-ROOM GODOT WEBGL CHROMIUM PASS: 4 source-bound screenshots")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--export", type=Path, required=True)
    p.add_argument("--evidence", type=Path, required=True)
    p.add_argument("--sha", required=True)
    x = p.parse_args()
    run(x.export.resolve(), x.evidence, x.sha)
