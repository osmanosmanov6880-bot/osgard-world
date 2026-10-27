#!/usr/bin/env python3
"""W64 actual exported Godot WebGL+Chromium gameplay, not screenshot mockup.

Native Godot uses a read-only DOM snapshot for accessibility and external QA.
This browser driver MUST send actual keyboard events to the Godot canvas.
"""
import argparse
import contextlib
import functools
import hashlib
import io
import json
import socketserver
import threading
import time
from pathlib import Path
from http.server import SimpleHTTPRequestHandler
from playwright.sync_api import sync_playwright
from PIL import Image, ImageChops, ImageStat


class HTTPHandler(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass


class LocalServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True


def ensure(condition, why):
    if not condition:
        raise AssertionError(why)


def snapshot(page):
    text = page.locator("#a7-cascade-native-state").get_attribute("data-state")
    ensure(text, "No actual Godot read-only state marker")
    state = json.loads(text)
    ensure(state.get("schema") == "LAST_FRONTIER_W64_REAL_GODOT_WEB_STATE",
           "Unexpected Godot WebGL marker schema")
    return state


def geometry(page):
    text = page.locator("#a7-cascade-native-state").get_attribute("data-geometry")
    ensure(text, "Godot native gameplay geometry unavailable")
    return json.loads(text)


def wait_state(page, expected):
    page.wait_for_function("""expected => {
        const node=document.getElementById('a7-cascade-native-state');
        if (!node || !node.getAttribute('data-state')) return false;
        try {
            const x=JSON.parse(node.getAttribute('data-state'));
            return Object.entries(expected).every(([key,val])=>x[key]===val);
        } catch(e){ return false; }
    }""", arg=expected, timeout=100_000)
    return snapshot(page)


def image_difference(a, b):
    image_a = Image.open(io.BytesIO(a)).convert("RGB")
    image_b = Image.open(io.BytesIO(b)).convert("RGB")
    ensure(image_a.size == image_b.size, "Screenshot dimensions are inconsistent")
    difference = ImageChops.difference(image_a, image_b).convert("L")
    histogram = difference.histogram()
    return sum(histogram[12:])


def play(export, evidence, exact_sha):
    evidence.mkdir(parents=True, exist_ok=True)
    ensure(len(exact_sha) == 40 and all(c in "0123456789abcdef" for c in exact_sha),
           "Exact commit SHA required")
    ensure((export / "index.html").is_file(), "Real Godot exported HTML is missing")
    ensure((export / "index.wasm").read_bytes()[:4] == b"\0asm",
           "Real compiled Godot WASM header is missing")
    with LocalServer(("127.0.0.1", 0),
                     functools.partial(HTTPHandler, directory=str(export))) as server:
        runner = threading.Thread(target=server.serve_forever, daemon=True)
        runner.start()
        address = f"http://127.0.0.1:{server.server_address[1]}/index.html"
        start = time.monotonic()
        js_errors = []
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True, args=[
                "--no-sandbox", "--disable-dev-shm-usage", "--enable-webgl",
                "--use-gl=angle", "--use-angle=swiftshader",
                "--enable-unsafe-swiftshader",
            ])
            context = browser.new_context(
                viewport={"width": 1366, "height": 900},
                device_scale_factor=1,
                reduced_motion="no-preference",
            )
            page = context.new_page()
            page.on("pageerror", lambda e: js_errors.append(str(e)))
            page.goto(address, wait_until="domcontentloaded", timeout=120_000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached", timeout=180_000)
            first = wait_state(page, {"shift": 0, "actions_left": 2,
                                      "status": "playing", "locale": "ru",
                                      "real_native_3d": True})
            ensure(first["scene_meshes"] >= 75, "Godot procedural 3D mesh scene was never created")
            ensure(first["scene_lights"] == 3, "Native Godot 3D lights absent")
            ensure(first["metrics"]["heat"] == 62, "Initial heat did not come from game model")
            ensure(first["history_count"] == 0, "Unexpected simulated actions before input")
            canvas = page.locator("canvas").first
            ensure(canvas.count() == 1, "Actual Godot WebGL canvas missing")
            canvas.click(position={"x": 25, "y": 25}, timeout=30_000)
            page.wait_for_timeout(450)
            # Engine.get_frames_drawn() can remain zero on some SwiftShader
            # configurations, even after a successful Godot 3D render.
            # Validate the genuine pixels inside the *native 3D hero*, not
            # that driver-dependent counter and not an arbitrary HTML label.
            baseline = page.screenshot(path=str(evidence / "1366x900-before.png"))
            scene_area = geometry(page)["stage"]
            desktop_image = Image.open(io.BytesIO(baseline)).convert("RGB")
            rect = (
                max(0, scene_area[0]),
                max(0, scene_area[1]),
                min(desktop_image.width, scene_area[0] + scene_area[2]),
                min(desktop_image.height, scene_area[1] + scene_area[3]),
            )
            ensure(rect[2] - rect[0] > 450 and rect[3] - rect[1] > 200,
                   "Real native 3D scene was not visibly mounted on screen")
            stage_pixels = desktop_image.crop(rect)
            channel_deviation = max(ImageStat.Stat(stage_pixels).stddev)
            ensure(channel_deviation > 3.0,
                   "Actual native 3D viewport appears unrendered or completely blank")

            # Actual player keyboard path into the native Godot game, not a DOM
            # state spoof or direct call to a JavaScript helper.
            page.keyboard.press("1")
            result = wait_state(page, {"actions_left": 1, "history_count": 1})
            ensure(result["metrics"]["heat"] == 42, "Pump click did not change original model")
            ensure(result["metrics"]["energy"] == 79, "Pump energy tradeoff incorrect")
            ensure(abs(result["energy_gauge"] - 0.79) < 0.001,
                   "Actual 3D gauge did not follow the game")
            page.keyboard.press("4")
            result = wait_state(page, {"shift": 1, "actions_left": 2,
                                       "history_count": 2})
            ensure(result["metrics"]["heat"] == 59 and
                   result["metrics"]["seal"] == 64,
                   "Real model incident state mismatches original deterministic W63")
            changed_image = page.screenshot(path=str(evidence / "1366x900-reactive.png"))
            ensure(image_difference(baseline, changed_image) > 250,
                   "Actual rendered game did not visibly react")

            page.keyboard.press("c")
            result = wait_state(page, {"renderer_camera": 1})
            ensure(result["shift"] == 1, "Camera input illegally changed game cycle")
            page.keyboard.press("q")
            result = wait_state(page, {"quality": "eco"})
            ensure(result["shift"] == 1, "ECO control illegally changes game")
            page.keyboard.press("m")
            result = wait_state(page, {"reduced_motion": True})
            ensure(result["status"] == "playing", "Reduced motion cannot finish a mission")
            page.keyboard.press("l")
            result = wait_state(page, {"locale": "en"})
            ensure(result["shift"] == 1, "Language toggle changed game simulation")
            desktop_geometry = geometry(page)
            ensure(desktop_geometry["stage"][3] >= 390,
                   "Desktop 3D hero is not actually allocated visual space")

            page.set_viewport_size({"width": 390, "height": 844})
            page.wait_for_timeout(850)
            responsive = geometry(page)
            ensure(responsive["viewport"][0] <= 420,
                   "Mobile browser viewport did not propagate into Godot")
            ensure(responsive["stage"][3] <= 310,
                   "Actual native mobile stage blocks the game controls")
            mobile = page.screenshot(path=str(evidence / "390x844-mobile.png"))
            ensure(len(mobile) > 12_000, "Real mobile screenshot invalid")
            page.keyboard.press("r")
            result = wait_state(page, {"shift": 0, "actions_left": 2,
                                       "history_count": 0})
            ensure(result["metrics"]["heat"] == 62 and
                   result["metrics"]["energy"] == 85,
                   "Real mobile reset did not restore original gameplay")
            page.keyboard.press("1")
            result = wait_state(page, {"history_count": 1, "actions_left": 1})
            ensure(result["metrics"]["heat"] == 42,
                   "Mobile viewport lost real player keyboard input")

            context.close()
            browser.close()
        server.shutdown()
    ensure(not js_errors, "Uncaught JS errors from actual Godot WASM runtime: " +
           " | ".join(js_errors[:5]))
    images = []
    for path in sorted(evidence.glob("*.png")):
        image = Image.open(path)
        ensure(image.width > 350 and image.height > 700,
               "Browser evidence is not an actual full-size screenshot")
        images.append({
            "name": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "width": image.width, "height": image.height,
        })
    report = {
        "schema": "LAST_FRONTIER_W64_REAL_CHROMIUM_NATIVE_GAMEPLAY_V1",
        "source_sha": exact_sha, "status": "PASS",
        "actual_godot_wasm": True,
        "browser_played_original_model": True,
        "browser_verified_native_3d": True,
        "native_input_source": "real Chromium keyboard events into Godot canvas",
        "mobile_test_is_emulated_viewport_only": True,
        "consumer_mobile_hardware_certified": False,
        "production_approved": False, "public_deployed": False,
        "elapsed_seconds": round(time.monotonic() - start, 2),
        "screenshots": images,
    }
    (evidence / "W64_REAL_BROWSER_GAMEPLAY.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"LAST FRONTIER W64 REAL GODOT 3D CHROMIUM GAMEPLAY PASS: "
          f"{len(images)} original screenshots, 3D gauges, input, RU/EN and mobile viewport")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--export", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--sha", required=True)
    args = parser.parse_args()
    play(args.export.resolve(), args.evidence, args.sha)
