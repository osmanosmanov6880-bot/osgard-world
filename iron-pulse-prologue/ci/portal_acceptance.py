#!/usr/bin/env python3
"""Exact-source portal + packaging acceptance using real Chromium.

Validates the international launcher as a functional website, not a static
Photoshop image: RU/EN controls, mission selector, verified SHA, real
screenshots, responsive layout, download packaging and local-only resources.
"""
from __future__ import annotations
import argparse
import importlib.util
import json
import threading
from functools import partial
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
from zipfile import ZipFile
from playwright.sync_api import sync_playwright

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--portal", type=Path, required=True)
    parser.add_argument("--source-sha", type=str, required=True)
    args = parser.parse_args()
    root = args.portal.resolve(strict=True)
    must_exist = [
        "index.html","app.js","styles.css","build.json","serve_preview.py",
        "play/index.html","play/index.js","play/index.wasm","play/index.pck",
        "downloads/IRON_PULSE_WINDOWS.zip","evidence/cinematic-reactor-desktop.png"
    ]
    for name in must_exist:
        path = root / name
        assert path.is_file() and path.stat().st_size > 40, f"Missing real release asset: {name}"
    with ZipFile(root / "downloads/IRON_PULSE_WINDOWS.zip") as archive:
        names = archive.namelist()
        assert "IRON_PULSE_BLACKOUT.exe" in names and "IRON_PULSE_BLACKOUT.pck" in names, names
        assert archive.getinfo("IRON_PULSE_BLACKOUT.exe").file_size > 1024 * 1024
        assert archive.getinfo("IRON_PULSE_BLACKOUT.pck").file_size > 100
        assert archive.testzip() is None, "Windows download is corrupted"
    info = json.loads((root / "build.json").read_text(encoding="utf-8"))
    assert info["source_sha"] == args.source_sha, "Portal source != actual exported game SHA"
    assert info["status"] == "software_preview" and info["production_hold"] is True
    js_source = (root / "app.js").read_text(encoding="utf-8")
    html_source = (root / "index.html").read_text(encoding="utf-8")
    for forbidden in ("https://fonts.","google-analytics","gtag(","track(","stripe.com","pixel.","localStorage.setItem","facebook.net"):
        assert forbidden not in js_source + html_source, f"Unexpected network/tracker dependency: {forbidden}"
    spec = importlib.util.spec_from_file_location("preview_server",root / "serve_preview.py")
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    handler = partial(module.SafeGameHandler,directory=str(root))
    server = ThreadingHTTPServer(("127.0.0.1",0),handler)
    runner = threading.Thread(target=server.serve_forever,daemon=True)
    runner.start()
    host = f"http://127.0.0.1:{server.server_address[1]}"
    results = {"status":"PASS","sha":args.source_sha,"screens":[]}
    try:
        with sync_playwright() as tool:
            browser = tool.chromium.launch(headless=True,args=["--disable-gpu-sandbox"])
            for name,width,height,mobile in [
                ("desktop",1366,768,False),
                ("touch",390,844,True)
            ]:
                context = browser.new_context(
                    viewport={"width":width,"height":height},
                    device_scale_factor=1,
                    is_mobile=mobile,has_touch=mobile
                )
                page = context.new_page()
                off_origin = []
                page.on("request",lambda req: off_origin.append(req.url) if urlsplit(req.url).netloc != urlsplit(host).netloc else None)
                response = page.goto(host+"/",wait_until="networkidle",timeout=30000)
                assert response and response.status == 200
                assert response.headers["cross-origin-opener-policy"] == "same-origin"
                assert response.headers["cross-origin-embedder-policy"] == "require-corp"
                assert page.title() == "IRON PULSE — CONTAINMENT RUN"
                assert page.locator("html").get_attribute("lang") == "ru"
                assert page.locator("#build-sha").inner_text() == args.source_sha[:12]
                assert page.locator(".screen img").evaluate("(el) => el.complete && el.naturalWidth > 500")
                assert page.locator('a[href="./play/index.html"]').count() >= 2
                assert page.locator('a[href="./downloads/IRON_PULSE_WINDOWS.zip"]').count() == 1
                assert page.locator("#scenario-title").inner_text() == "BLACKOUT"
                page.locator('button[data-scenario="heat"]').click()
                assert page.locator("#scenario-title").inner_text() == "HEAT"
                assert page.locator('button[data-scenario="heat"]').get_attribute("aria-pressed") == "true"
                assert "температурные" in page.locator("#scenario-description").inner_text()
                page.locator("#locale-toggle").click()
                assert page.locator("html").get_attribute("lang") == "en"
                assert "Every decision" in page.locator("#mission-title").inner_text()
                assert "Recurring thermal" in page.locator("#scenario-description").inner_text()
                assert "Download for Windows" in page.locator(".hero-ctas").inner_text()
                assert page.locator("#locale-toggle").get_attribute("aria-pressed") == "true"
                page.locator('button[data-scenario="air"]').click()
                assert page.locator("#scenario-title").inner_text() == "AIR"
                assert "Oxygen is leaking" in page.locator("#scenario-description").inner_text()
                page.locator("#locale-toggle").click()
                assert page.locator("html").get_attribute("lang") == "ru"
                assert "Скачать для Windows" in page.locator(".hero-ctas").inner_text()
                dimensions = page.evaluate("""() => ({
                    content: document.documentElement.scrollWidth,
                    viewport: window.innerWidth,
                    hero: document.querySelector('.hero').getBoundingClientRect().width
                })""")
                assert dimensions["content"] <= dimensions["viewport"]+2, dimensions
                assert dimensions["hero"] >= width-8, dimensions
                assert not off_origin, f"Preview used 3rd-party URL: {off_origin}"
                screenshot_name = f"portal-{name}.png"
                page.screenshot(path=str(root/"evidence"/screenshot_name),full_page=True)
                results["screens"].append({
                    "name":name,"dimensions":[width,height],
                    "content_width":dimensions["content"],
                    "image":screenshot_name,"locale_switch":"PASS",
                    "scenario_tabs":"PASS","real_game_image":"PASS"
                })
                context.close()
            browser.close()
    finally:
        server.shutdown()
        server.server_close()
    (root / "evidence" / "portal-evidence.json").write_text(
        json.dumps(results,indent=2,ensure_ascii=False),encoding="utf-8")
    print("IRON PULSE V9 GLOBAL PORTAL PASS: bilingual desktop/touch, SHA256 and Windows/WebGL links")
    print(json.dumps(results,ensure_ascii=False,indent=2))

if __name__ == "__main__":
    main()
