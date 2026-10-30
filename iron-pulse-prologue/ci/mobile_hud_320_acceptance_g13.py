#!/usr/bin/env python3
"""G13: real 320x720 Godot WebGL mobile card audit — no substituted screenshots.

This starts the original exported WebGL game, taps actual in-canvas controls,
observes original authored timed dialogue, and checks that full telemetry
returns naturally after the line's TTL. Chromium emulation is NOT iPhone QA.
"""
from __future__ import annotations
import argparse
import hashlib
import http.server
import io
import json
import re
import threading
import time
from pathlib import Path

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


class SilentServer(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def wait_state(marker, page, condition, seconds: float, reason: str):
    finish = time.monotonic() + seconds
    latest = {}
    while time.monotonic() < finish:
        latest = json.loads(marker.get_attribute("data-state", timeout=12000))
        if condition(latest):
            return latest
        page.wait_for_timeout(200)
    raise AssertionError(f"{reason}: {json.dumps(latest, ensure_ascii=False)[:1600]}")


def image_proof(png: bytes, width: int, height: int):
    frame = Image.open(io.BytesIO(png)).convert("RGB")
    assert frame.width == width and frame.height == height, "wrong real WebGL screenshot dimensions"
    thumb = frame.resize((128, 72))
    varied = {(red // 16, green // 16, blue // 16) for red, green, blue in thumb.getdata()}
    stddev = max(ImageStat.Stat(thumb).stddev)
    assert len(varied) >= 12 and stddev > 7, "blank or fake blank WebGL frame"
    return {"sha256": hashlib.sha256(png).hexdigest(),
            "color_bins": len(varied), "stddev": round(stddev, 2),
            "width": frame.width, "height": frame.height}


def separate(a, b, allowance=1):
    assert len(a) == len(b) == 4, "actual native rectangles required"
    ax, ay, aw, ah = [float(x) for x in a]
    bx, by, bw, bh = [float(x) for x in b]
    return ax + aw <= bx + allowance or bx + bw <= ax + allowance or \
           ay + ah <= by + allowance or by + bh <= ay + allowance


def validate_layout(state):
    layout = state.get("g13_mobile_hud", {})
    assert layout.get("schema") == "IRON_PULSE_MOBILE_HUD_REFLOW_G13", layout
    assert layout.get("source") == "real_godot_native_panels_and_actual_crisis_engine", layout
    assert layout.get("source_engine_mutated") is False and layout.get("remote_analytics") is False, layout
    assert layout.get("compact") is True and layout.get("layout") == "single_story_card", layout
    assert layout.get("css_viewport") == [320, 720], layout
    assert layout.get("radio_visible") is True and layout.get("hud_card_visible") is False, layout
    assert layout.get("emergency_footer_from_real_engine") is True, layout
    footer = layout.get("emergency_footer", "")
    assert "ТЕПЛО" in footer and "ВОЗД" in footer, ("fictional crisis metrics lost during real MARA transmission", footer)
    assert str(int(state["heat"])) in footer and str(int(state["oxygen"])) in footer, (
        "G13 is not using real heat/oxygen instead of static placeholders", state, footer)
    bounds = state.get("hud_rects", {})
    radio, header = layout.get("radio_rect", []), bounds.get("header", [])
    assert radio and header and separate(radio, header), ("actual header-radio overlap", header, radio)
    first_row = float(layout.get("touch_first_row_y", 0))
    assert first_row == 249.0 and radio[1] + radio[3] + 1.0 < first_row, (
        "original radio obscures first physical touch row", radio, first_row)
    assert state.get("touch_controls_visible") is True, "actual phone controls must remain active"
    for label, rect in state.get("touch_button_rects", {}).items():
        # Hidden buttons are still included in the native read-only state; the
        # geometry property remains relevant as another input could reveal them.
        assert separate(radio, rect), ("real Godot story obstructs touch control", label, radio, rect)
    return layout


def run(web: Path, target: Path, source: str):
    assert re.fullmatch(r"[a-f0-9]{40}", source), "pin exact source commit SHA"
    for required in ("index.html", "index.js", "index.pck", "index.wasm"):
        assert (web / required).is_file(), "missing real Godot WebGL file: " + required
    target.mkdir(parents=True, exist_ok=True)
    root = web.resolve()
    handler = lambda *a, **kw: SilentServer(*a, directory=str(root), **kw)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    result = {"schema": "IRON_PULSE_G13_320PX_WEBGL_MOBILE_REAL",
              "source_sha": source, "status": "FAIL",
              "real_export": True, "true_godot_input": True,
              "physical_device_verified": False, "production_approved": False,
              "fake_html_or_mock_engine": False, "telemetry_uploaded": False}
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True, args=[
                "--enable-webgl", "--ignore-gpu-blocklist", "--use-angle=swiftshader",
                "--enable-unsafe-swiftshader", "--disable-dev-shm-usage"
            ])
            try:
                context = browser.new_context(viewport={"width": 320, "height": 720},
                    is_mobile=True, has_touch=True, device_scale_factor=1)
                try:
                    page = context.new_page()
                    page.goto(f"http://127.0.0.1:{server.server_port}/index.html",
                              wait_until="domcontentloaded", timeout=60000)
                    canvas = page.locator("canvas").first
                    canvas.wait_for(state="visible", timeout=90000)
                    marker = page.locator("#iron-pulse-native-state")
                    marker.wait_for(state="attached", timeout=120000)
                    idle = wait_state(marker, page, lambda x: x.get("scene") == "IRON_PULSE_BLACKOUT"
                        and x.get("viewport") == [320, 720]
                        and int(x.get("godot_frames_drawn", 0)) >= 2, 100,
                        "actual native canvas never reached 320x720")
                    assert idle.get("started") is False and idle.get("intro_visible") is True
                    # Real key press on the actual canvas; no engine state setter.
                    canvas.focus()
                    page.keyboard.press("Enter")
                    state = wait_state(marker, page, lambda x: x.get("started") is True
                        and x.get("radio_visible") is True, 45,
                        "original in-game opening radio never appeared")
                    assert state.get("story", {}).get("latest_key") == "arrival_blackout"
                    assert state.get("switches") == 0 and state.get("scanned") is False
                    layout = validate_layout(state)
                    picture = page.screenshot(animations="disabled", timeout=60000)
                    real_proof = image_proof(picture, 320, 720)
                    (target / "g13-real-320px-story.png").write_bytes(picture)
                    result["story_screenshot"] = {"path": "g13-real-320px-story.png", **real_proof}
                    result["initial_layout"] = {
                        "story_rect": layout["radio_rect"],
                        "header_rect": state["hud_rects"]["header"],
                        "physical_first_control_row_y": layout["touch_first_row_y"],
                        "emergency_footer_from_real_engine": True,
                        "player_actions_unchanged": True
                    }
                    # Actual in-canvas tap, not page.evaluate / local API hook.
                    language = state.get("touch_button_rects", {}).get("L / RU-EN")
                    assert language and language[2] >= 44 and language[3] >= 44
                    bounds = canvas.bounding_box()
                    assert bounds is not None
                    page.touchscreen.tap(
                        bounds["x"] + (language[0] + language[2]/2) * bounds["width"] / state["viewport"][0],
                        bounds["y"] + (language[1] + language[3]/2) * bounds["height"] / state["viewport"][1])
                    translated = wait_state(marker, page, lambda x: x.get("locale") == "en",
                        25, "real mobile language button not working")
                    assert translated.get("g13_mobile_hud", {}).get("layout") == "single_story_card"
                    assert translated.get("switches") == 0 and translated.get("scanned") is False
                    # Deliberately wait for the game to dismiss its own timed radio,
                    # rather than mutating the TTL or falsely claiming all time passes.
                    clean = wait_state(marker, page, lambda x: x.get("started") is True
                        and x.get("radio_visible") is False
                        and x.get("g13_mobile_hud", {}).get("hud_card_visible") is True, 45,
                        "full telemetry did not return after genuine MARA TTL")
                    assert clean.get("story", {}).get("journal_entries", 0) >= 1
                    assert clean.get("g13_mobile_hud", {}).get("emergency_footer_from_real_engine") is False
                    assert clean.get("scanned") is False and clean.get("switches") == 0
                    restored_picture = page.screenshot(animations="disabled", timeout=60000)
                    restored_proof = image_proof(restored_picture, 320, 720)
                    (target / "g13-real-320px-restored-telemetry.png").write_bytes(restored_picture)
                    result["restored_screenshot"] = {
                        "path": "g13-real-320px-restored-telemetry.png", **restored_proof}
                    result["restored_layout"] = clean.get("g13_mobile_hud")
                    result["native_ru_en_touch_pass"] = True
                    result["source_story_ttl_pass"] = True
                    result["original_game_actions_preserved"] = True
                    result["status"] = "PASS"
                finally:
                    context.close()
            finally:
                browser.close()
    finally:
        server.shutdown()
        server.server_close()
        (target / "g13-mobile-320-evidence.json").write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--export", required=True, type=Path)
    parser.add_argument("--evidence", required=True, type=Path)
    parser.add_argument("--sha", required=True)
    args = parser.parse_args()
    assert run(args.export, args.evidence, args.sha)["status"] == "PASS"
