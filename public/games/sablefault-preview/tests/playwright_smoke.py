#!/usr/bin/env python3
"""Source-bound actual Chromium gameplay/render smoke, not hardware certification."""
import hashlib
import json
import os
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(os.environ.get("SABLEFAULT_EVIDENCE_DIR", "sablefault-evidence"))
OUT.mkdir(parents=True, exist_ok=True)
SHA = os.environ.get("GITHUB_SHA", "")
URL = os.environ.get("SABLEFAULT_URL", "http://127.0.0.1:8769")
assert len(SHA) == 40 and all(c in "0123456789abcdef" for c in SHA), "Pin full exact GitHub SHA"
report = {"schema": "SABLEFAULT_REAL_WEBGL_BETA_QA_V1",
          "source_sha": SHA, "status": "FAIL", "software_browser_only": True,
          "native_godot_exported": False, "physical_windows_gpu_certified": False,
          "physical_android_ios_certified": False, "production_deployed": False,
          "screenshots": {}, "checks": {}, "console_errors": []}
def screenshot(page, name):
    path = OUT / name
    page.screenshot(path=str(path))
    raw = path.read_bytes()
    assert raw[:8] == b"\x89PNG\r\n\x1a\n" and len(raw) > 8000, name
    report["screenshots"][name] = {"sha256": hashlib.sha256(raw).hexdigest(),
                                   "bytes": len(raw)}
def read(page):
    return page.evaluate("window.SABLEFAULT_INSPECT()")
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True,
            args=["--enable-webgl", "--ignore-gpu-blocklist",
                  "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                  "--disable-dev-shm-usage"])
        try:
            ctx = browser.new_context(viewport={"width": 1440, "height": 900},
                device_scale_factor=1)
            page = ctx.new_page()
            page.on("pageerror", lambda err: report["console_errors"].append(str(err)))
            page.goto(URL, wait_until="domcontentloaded", timeout=45000)
            page.wait_for_function("typeof window.SABLEFAULT_INSPECT === 'function'",
                                   timeout=20000)
            initial = read(page)
            assert initial["phase"] == "briefing" and initial["production_ready"] is False
            assert initial["renderer"] == "WebGL2", "Actual WebGL2 shader/geometry pipeline failed"
            screenshot(page, "cover-original-1440.png")
            report["checks"]["actual_webgl2_context"] = "PASS"
            page.locator("#start").click()
            page.wait_for_timeout(600)
            screenshot(page, "core-original-1440.png")
            assert read(page)["phase"] == "boot"
            # Real CDP keyboard locomotion, not direct state mutation.
            page.keyboard.down("w")
            try:
                page.wait_for_function("window.SABLEFAULT_INSPECT().nearest === 'cmd'",
                                       timeout=20000)
            finally:
                page.keyboard.up("w")
            before = read(page)
            assert before["player"]["z"] < 11.0
            page.keyboard.press("e")
            assert read(page)["terminal"] == "cmd"
            screenshot(page, "command-original-1440.png")
            page.locator("#terminalActions button:not([disabled])").first.click()
            assert read(page)["phase"] == "stabilize"
            screenshot(page, "active-incident-original-1440.png")
            page.locator("#lang").click()
            assert page.locator("html").get_attribute("lang") == "en"
            page.locator("#lang").click()
            assert page.locator("html").get_attribute("lang") == "ru"
            report["checks"]["real_input_command_and_protocol"] = "PASS"
            report["checks"]["ru_en_toggle"] = "PASS"
            assert read(page)["real_physical_gpu_certified"] is False
            ctx.close()

            mobile = browser.new_context(viewport={"width": 390, "height": 844},
                device_scale_factor=1, is_mobile=True, has_touch=True)
            phone = mobile.new_page()
            phone.on("pageerror", lambda err: report["console_errors"].append(str(err)))
            phone.goto(URL, wait_until="domcontentloaded", timeout=45000)
            phone.wait_for_function("typeof window.SABLEFAULT_INSPECT === 'function'",
                                     timeout=20000)
            assert read(phone)["renderer"] == "WebGL2", "Mobile viewport WebGL2 not rendered"
            screenshot(phone, "cover-original-390.png")
            phone.locator("#start").tap()
            phone.wait_for_timeout(450)
            screenshot(phone, "core-original-390.png")
            rect = phone.locator("#touchUse").bounding_box()
            assert rect is not None and rect["x"] >= 0
            assert rect["x"] + rect["width"] <= 393, rect
            assert phone.locator("#touch").is_visible()
            assert phone.locator("#objective").is_visible()
            assert phone.locator("#gauges").is_visible()
            assert read(phone)["phase"] == "boot"
            report["checks"]["original_390_touch_layout"] = "PASS"
            mobile.close()
            assert not report["console_errors"], report["console_errors"]
            report["status"] = "PASS"
        finally:
            browser.close()
finally:
    (OUT / "sablefault-browser-qa.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(json.dumps(report, indent=2, ensure_ascii=False))
if report["status"] != "PASS":
    raise SystemExit("SABLEFAULT original exported Chromium WebGL QA failed")
