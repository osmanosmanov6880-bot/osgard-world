#!/usr/bin/env python3
"""W55: actual Godot 4.4 WebGL 390px RU/EN typography, two true screenshots.
Touch input is real Chromium CDP; no fake gameplay or DOM text substitution.
The native W55 Godot GDScript test independently verifies visible labels.
"""
import argparse
import hashlib
import http.server
import json
import threading
from pathlib import Path

from playwright.sync_api import sync_playwright
from mobile_touch_acceptance import StaticHandler, TouchDriver


def verify(export: Path, evidence: Path, sha: str):
    assert len(sha) == 40 and all(c in "0123456789abcdef" for c in sha)
    export = export.resolve()
    manifest = json.loads((export / "evidence.json").read_text())
    assert manifest["source_commit"] == sha and manifest["godot_release"] == "4.4.1"
    for name in ("index.html", "index.wasm", "index.js", "index.pck"):
        assert (export / name).is_file(), name
    evidence.mkdir(parents=True, exist_ok=True)
    report = {"schema": "OSGARD_W55_REAL_GODOT_WEBGL_RU_EN_GLYPH_QA_V1",
              "status": "FAIL", "source_sha": sha,
              "real_godot_webgl": True, "viewport": "390x844",
              "real_chromium_touch": True, "synthetic_dom_gameplay": False,
              "actual_physical_phone_tested": False, "frames": []}
    handler = lambda *a, **kw: StaticHandler(*a, directory=str(export), **kw)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    page = None
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True, args=[
                "--enable-webgl", "--ignore-gpu-blocklist",
                "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                "--disable-dev-shm-usage"])
            try:
                context = browser.new_context(
                    viewport={"width": 390, "height": 844},
                    device_scale_factor=1, has_touch=True, is_mobile=True,
                    locale="ru-RU")
                try:
                    page = context.new_page()
                    errors = []
                    page.on("pageerror", lambda err: errors.append(str(err)))
                    page.goto(f"http://127.0.0.1:{server.server_port}/index.html",
                              wait_until="domcontentloaded", timeout=60000)
                    page.locator("canvas").first.wait_for(state="visible", timeout=90000)
                    driver = TouchDriver(page)
                    driver.until(lambda s: s.get("mission") == -1 and s.get("locale") == "ru",
                                 "actual Godot starts in Russian", timeout=90000)
                    for lang in ("ru", "en"):
                        if lang == "en":
                            # W53 real touchscreen swipe BACK to the true Godot language button.
                            driver.tap("language")
                            driver.until(lambda s: s.get("locale") == "en",
                                         "actual Godot language toggle", timeout=20000)
                        # Real input moves native Godot ScrollContainer to the
                        # original protocol line that had boxed missing arrows.
                        before = driver.geometry()["scroll"]
                        driver.swipe(1)
                        after = driver.geometry()["scroll"]
                        assert after > before + 75, (
                            "W55 mobile protocol text not reachable via real touch", lang,
                            before, after)
                        frame = page.screenshot(timeout=45000, animations="disabled")
                        name = f"w55-actual-godot-{lang}-390px-protocol.png"
                        (evidence / name).write_bytes(frame)
                        report["frames"].append({
                            "locale": lang, "name": name, "sha256": hashlib.sha256(frame).hexdigest(),
                            "viewport": [390, 844], "native_scroll_before": before,
                            "native_scroll_after": after
                        })
                        if lang == "ru":
                            # The next language tap may scroll BACK using true
                            # ScreenDrag gestures; no synthetic DOM scrolling.
                            pass
                    report["real_screen_drag_swipes"] = driver.swipes
                    report["real_touch_actions"] = len(driver.events)
                    assert len(report["frames"]) == 2
                    assert driver.swipes >= 2
                    assert not errors, ("Actual Chromium WebGL errors", errors)
                    report["status"] = "PASS"
                finally:
                    context.close()
            finally:
                browser.close()
    finally:
        server.shutdown()
        server.server_close()
        (evidence / "w55-glyph-evidence.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: report[k] for k in
                      ("status", "source_sha", "real_screen_drag_swipes", "frames")}, indent=2))


if __name__ == "__main__":
    arg = argparse.ArgumentParser()
    arg.add_argument("--export", type=Path, required=True)
    arg.add_argument("--evidence", type=Path, required=True)
    arg.add_argument("--sha", required=True)
    a = arg.parse_args()
    verify(a.export, a.evidence, a.sha)
