#!/usr/bin/env python3
"""Exercise the REAL Godot WebGL canvas, input and read-only native state.

No in-game methods are injected, no direct simulation values are modified,
no screenshots are substituted. Emulated mobile is NOT physical-device QA.
"""
import argparse
import hashlib
import http.server
import io
import json
import threading
import time
from pathlib import Path

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


class QuietServer(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def frame_metrics(frame: bytes) -> dict:
    im = Image.open(io.BytesIO(frame)).convert("RGB")
    thumb = im.resize((128, 72))
    bins = {(r // 16, g // 16, b // 16) for r, g, b in thumb.getdata()}
    return {
        "width": im.width,
        "height": im.height,
        "color_bins": len(bins),
        "stddev": round(max(ImageStat.Stat(thumb).stddev), 2),
        "sha256": hashlib.sha256(frame).hexdigest(),
    }


def test_webgl(directory: Path, output: Path, source_sha: str) -> dict:
    assert len(source_sha) == 40 and all(c in "0123456789abcdef" for c in source_sha), "Need exact source SHA"
    for name in ("index.html", "index.js", "index.pck", "index.wasm"):
        assert (directory / name).is_file(), f"Not a real Godot WebGL export: {name}"
    directory = directory.resolve()
    output.mkdir(parents=True, exist_ok=True)
    handler = lambda *a, **kw: QuietServer(*a, directory=str(directory), **kw)
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{httpd.server_port}/index.html"
    report = {
        "schema": "IRON_PULSE_BLACKOUT_WEBGL_PLAYER_INPUT_V1",
        "source_sha": source_sha,
        "real_godot_export": True,
        "physical_device_certified": False,
        "production_ready": False,
        "status": "FAIL",
        "screens": [],
    }
    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True, args=[
                "--enable-webgl", "--ignore-gpu-blocklist", "--use-angle=swiftshader",
                "--enable-unsafe-swiftshader", "--disable-dev-shm-usage",
            ])
            try:
                targets = [
                    ("desktop", {"width": 1366, "height": 768}, False),
                    ("touch-emulation", {"width": 390, "height": 844}, True),
                ]
                for name, size, mobile in targets:
                    ctx = browser.new_context(viewport=size, is_mobile=mobile, has_touch=mobile,
                                              device_scale_factor=1)
                    page = ctx.new_page()
                    exceptions = []
                    page.on("pageerror", lambda error: exceptions.append(str(error)))
                    try:
                        page.goto(url, wait_until="domcontentloaded", timeout=60000)
                        canvas = page.locator("canvas").first
                        canvas.wait_for(state="visible", timeout=90000)
                        marker = page.locator("#iron-pulse-native-state")
                        marker.wait_for(state="attached", timeout=120000)
                        idle = {}
                        deadline = time.monotonic() + 40
                        while time.monotonic() < deadline:
                            idle = json.loads(marker.get_attribute("data-state", timeout=10000))
                            if int(idle.get("godot_frames_drawn", 0)) >= 1:
                                break
                            page.wait_for_timeout(250)
                        assert idle["scene"] == "IRON_PULSE_BLACKOUT", idle
                        assert idle["started"] is False and idle["intro_visible"] is True, idle
                        assert idle["objective"] == "scan", idle
                        assert idle["godot_frames_drawn"] >= 1, idle
                        assert idle["locale"] == "ru", idle
                        assert idle.get("soundscape_ready") is True, idle
                        assert idle.get("cinematic_details",{}).get("instanced_detail_count",0) >= 270, idle
                        assert idle.get("cinematic_details",{}).get("safety_signs",0) >= 3, idle
                        assert idle.get("vitals_visible") is (not mobile), idle
                        # A visible canvas is not enough: Godot must lay out HUD in
                        # real CSS pixel coordinates, not shrink a 1280px desktop
                        # scene to 390px and pretend the touch buttons are usable.
                        native_view = idle["viewport"]
                        assert abs(native_view[0] - size["width"]) <= 2.0, (
                            "Godot viewport shrunk horizontally: unreadable text", native_view, size)
                        assert abs(native_view[1] - size["height"]) <= 2.0, (
                            "Godot viewport stretched vertically: inaccessible touch UI", native_view, size)
                        if mobile:
                            assert idle["touch_controls_visible"] is True, idle
                            rectangles = idle.get("touch_button_rects", {})
                            assert len(rectangles) >= 6, idle
                            for label in ("↑", "←", "↓", "→", "USE / E", "L / RU-EN"):
                                rect = rectangles[label]
                                # Read actual native Control rectangles, then compare
                                # against the real CSS pixel scaling on this device.
                                real_width = rect[2] * size["width"] / native_view[0]
                                real_height = rect[3] * size["height"] / native_view[1]
                                assert real_width >= 44 and real_height >= 44, (
                                    "Touch target too small in browser pixels", label, rect,
                                    real_width, real_height)
                        page.keyboard.press("Enter")
                        deadline = time.monotonic() + 45
                        state = {}
                        while time.monotonic() < deadline:
                            state = json.loads(marker.get_attribute("data-state", timeout=10000))
                            if state.get("started") is True:
                                break
                            page.wait_for_timeout(200)
                        assert state.get("started") is True, f"Enter did not start game on real canvas: {state}"
                        if mobile:
                            # Genuine mobile tap through Chromium's touchscreen,
                            # on the actual Godot Button; never call the locale
                            # setter or write a synthetic result to the game.
                            rect = state["touch_button_rects"]["L / RU-EN"]
                            canvas_box = canvas.bounding_box()
                            assert canvas_box is not None
                            tap_x = canvas_box["x"] + (rect[0]+rect[2]/2)*canvas_box["width"]/state["viewport"][0]
                            tap_y = canvas_box["y"] + (rect[1]+rect[3]/2)*canvas_box["height"]/state["viewport"][1]
                            page.touchscreen.tap(tap_x,tap_y)
                            deadline = time.monotonic() + 25
                            while time.monotonic() < deadline:
                                state = json.loads(marker.get_attribute("data-state", timeout=10000))
                                if state.get("locale") == "en":
                                    break
                                page.wait_for_timeout(200)
                            assert state.get("locale") == "en", ("Mobile language button does not work", state)
                        if not mobile:
                            origin = state["player_position"][2]
                            page.keyboard.down("w")
                            try:
                                deadline = time.monotonic() + 30
                                while time.monotonic() < deadline:
                                    state = json.loads(marker.get_attribute("data-state", timeout=10000))
                                    if state["player_position"][2] < origin - 0.35:
                                        break
                                    page.wait_for_timeout(200)
                            finally:
                                page.keyboard.up("w")
                            assert state["player_position"][2] < origin - 0.35, (origin, state)
                            # Verify real 3D detail and motion/audio accessibility via
                            # real Chromium keys; only read Godot state, never modify it.
                            for key, property_name, expected in (
                                ("g","quality_mode","eco"),
                                ("v","reduced_motion",True),
                                ("m","audio_muted",True),
                            ):
                                page.keyboard.press(key)
                                deadline = time.monotonic() + 25
                                while time.monotonic() < deadline:
                                    state = json.loads(marker.get_attribute("data-state",timeout=10000))
                                    if state.get(property_name) == expected:
                                        break
                                    page.wait_for_timeout(200)
                                assert state.get(property_name) == expected,(key,property_name,state)
                            page.keyboard.press("g")
                            page.keyboard.press("m")
                            page.keyboard.press("v")
                            page.keyboard.press("l")
                            deadline = time.monotonic() + 20
                            while time.monotonic() < deadline:
                                state = json.loads(marker.get_attribute("data-state", timeout=10000))
                                if state["locale"] == "en":
                                    break
                                page.wait_for_timeout(200)
                            assert state["locale"] == "en", state
                            page.keyboard.press("Escape")
                            deadline = time.monotonic() + 20
                            while time.monotonic() < deadline:
                                state = json.loads(marker.get_attribute("data-state", timeout=10000))
                                if state.get("paused"):
                                    break
                                page.wait_for_timeout(200)
                            assert state.get("paused") is True, state
                            page.keyboard.press("Escape")
                        page.wait_for_timeout(1800)
                        png = page.screenshot(timeout=60000, animations="disabled")
                        stats = frame_metrics(png)
                        assert stats["width"] == size["width"] and stats["height"] == size["height"], stats
                        assert stats["color_bins"] >= 12 and stats["stddev"] > 7, ("blank native Godot canvas", stats)
                        assert not exceptions, exceptions
                        filename = name + ".png"
                        (output / filename).write_bytes(png)
                        report["screens"].append({"device": name, "status": "PASS", **stats,
                                                  "screenshot": filename,
                                                  "initial_frames": idle["godot_frames_drawn"],
                                                  "last_native_state": state})
                    finally:
                        ctx.close()
            finally:
                browser.close()
        report["status"] = "PASS"
    finally:
        httpd.shutdown()
        httpd.server_close()
        (output / "webgl-evidence.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--export", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--sha", required=True)
    args = parser.parse_args()
    result = test_webgl(args.export, args.evidence, args.sha)
    assert result["status"] == "PASS"
