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
                        if mobile:
                            assert idle["touch_controls_visible"] is True, idle
                            assert len(idle.get("touch_button_rects", {})) >= 6, idle
                        page.keyboard.press("Enter")
                        deadline = time.monotonic() + 45
                        state = {}
                        while time.monotonic() < deadline:
                            state = json.loads(marker.get_attribute("data-state", timeout=10000))
                            if state.get("started") is True:
                                break
                            page.wait_for_timeout(200)
                        assert state.get("started") is True, f"Enter did not start game on real canvas: {state}"
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
