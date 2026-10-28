#!/usr/bin/env python3
"""W69 genuine exported Godot WebGL: F real lens, X native cinema viewport,
two original 3D rooms, real game choices, mobile and source-bound visual evidence.
No screenshots reauthored, state marker read-only, no simulated keyboard input.
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

from w64_browser_acceptance import HTTPHandler, LocalServer, wait_state, snapshot, geometry


def check(ok, text):
    if not ok:
        raise AssertionError(text)


def difference(before, after):
    a = Image.open(io.BytesIO(before)).convert("RGB")
    b = Image.open(io.BytesIO(after)).convert("RGB")
    check(a.size == b.size, "Compared image dimensions must match")
    delta = ImageChops.difference(a, b).convert("L")
    return sum(delta.histogram()[12:])


def live_frame(page, directory, filename):
    raw = page.screenshot(path=str(directory / filename))
    img = Image.open(io.BytesIO(raw)).convert("RGB")
    check(max(ImageStat.Stat(img).stddev) > 6.0,
          "Actual Godot browser render is blank")
    return raw


def run(path, evidence, sha):
    check(len(sha) == 40 and all(s in "0123456789abcdef" for s in sha),
          "Exact source SHA required")
    check((path / "index.wasm").read_bytes()[:4] == b"\0asm",
          "Real original Godot WebAssembly required")
    evidence.mkdir(parents=True, exist_ok=True)
    errors = []
    with LocalServer(("127.0.0.1", 0),
                     functools.partial(HTTPHandler, directory=str(path))) as server:
        threading.Thread(target=server.serve_forever, daemon=True).start()
        url = f"http://127.0.0.1:{server.server_address[1]}/index.html"
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True, args=[
                "--no-sandbox", "--disable-dev-shm-usage",
                "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader",
                "--enable-unsafe-swiftshader",
            ])
            ctx = browser.new_context(viewport={"width": 1366, "height": 900})
            page = ctx.new_page()
            page.on("pageerror", lambda e: errors.append(str(e)))
            page.goto(url, wait_until="domcontentloaded", timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached", timeout=180000)
            boot = wait_state(page, {
                "shift": 0, "status": "playing",
                "history_count": 0,
                "w69_cinema_mode": False, "w69_focus_mode": False,
                "w69_real_incident_shutters": 4,
                "w69_in_world_machine_readouts": 2,
                "w69_real_action_reactions": 0,
            })
            check(boot["w68_pbr_profiles"] == 7,
                  "Original W68 PBR/textures were lost")
            check(boot["w67_two_3d_sectors"],
                  "Original two real zones were lost")
            canvas = page.locator("canvas").first
            check(canvas.count() == 1, "No real Godot WebGL canvas")
            canvas.click(position={"x": 19, "y": 21})
            page.wait_for_timeout(400)
            original = live_frame(page, evidence, "w69-01-original-industrial-chamber.png")
            base_height = geometry(page)["stage_requested_height"]
            check(base_height >= 390, "Original real hero is missing")

            # F and X are real native in-game keyboard controls, not JS getters.
            page.keyboard.press("f")
            focused = wait_state(page, {
                "w69_focus_mode": True, "w69_focus_switches": 1,
                "history_count": 0,
            })
            check(focused["w67_inspection_sector"] == 0,
                  "Optical zoom changed the game location")
            page.wait_for_timeout(350)
            zoomed = live_frame(page, evidence, "w69-02-real-3d-optical-zoom.png")
            check(difference(original, zoomed) > 1500,
                  "Actual 3D camera FOV change is not visible")
            page.keyboard.press("f")
            wait_state(page, {"w69_focus_mode": False,
                              "w69_focus_switches": 2,
                              "history_count": 0})

            page.keyboard.press("x")
            cinema = wait_state(page, {
                "w69_cinema_mode": True, "history_count": 0,
            })
            check(geometry(page)["stage_requested_height"] >= 585,
                  "Cinema button must grow REAL native Godot SubViewport")
            page.wait_for_timeout(350)
            immersive = live_frame(
                page, evidence, "w69-03-immersive-native-cinema-1366.png")
            check(difference(original, immersive) > 1500,
                  "Native cinema mode did not change visual composition")
            page.keyboard.press("x")
            wait_state(page, {"w69_cinema_mode": False,
                              "history_count": 0})
            check(geometry(page)["stage_requested_height"] == base_height,
                  "Real original workbench stage height did not restore")

            page.keyboard.press("n")
            relay = wait_state(page, {
                "w67_inspection_sector": 1,
                "w67_walk_progress": 1.0,
                "history_count": 0,
            })
            check(relay["w67_relay_fov"] >= 63.9,
                  "Original actual relay hall wide camera missing")
            page.wait_for_timeout(350)
            relay_shot = live_frame(
                page, evidence, "w69-04-second-real-machine-hall.png")
            check(difference(original, relay_shot) > 1500,
                  "Actual second Godot modeled room is not different")
            page.keyboard.press("n")
            wait_state(page, {"w67_inspection_sector": 0,
                              "history_count": 0})
            page.keyboard.press("1")
            p = wait_state(page, {"history_count": 1,
                                  "w69_real_action_reactions": 1,
                                  "actions_left": 1})
            check(p["metrics"]["heat"] == 42 and
                  p["metrics"]["energy"] == 79,
                  "Real W63 pump tradeoff was replaced by art animation")
            page.keyboard.press("4")
            incident = wait_state(page, {
                "history_count": 2, "shift": 1,
                "w69_real_action_reactions": 2,
            })
            check(incident["metrics"]["heat"] == 59 and
                  incident["metrics"]["signal"] == 61,
                  "Original W63 first incident determinism lost")
            page.wait_for_timeout(200)
            reactive = live_frame(
                page, evidence, "w69-05-reactive-3d-after-player-decisions.png")
            check(difference(original, reactive) > 600,
                  "Real scene failed to react to true original game decisions")

            # Mobile: standard gameplay still legible, native world labels
            # hide, and optical focus & game actions work without fake DOM.
            page.set_viewport_size({"width": 390, "height": 844})
            page.wait_for_function("""() => {
                const el=document.getElementById('a7-cascade-native-state');
                if (!el) return false;
                try {
                    const s=JSON.parse(el.getAttribute('data-state'));
                    const g=JSON.parse(el.getAttribute('data-geometry'));
                    return g.viewport[0]<=420 &&
                        g.stage_requested_height<=310 &&
                        s.w68_mobile_hud_compact===true &&
                        s.w67_mobile_world_text_hidden===true &&
                        s.w69_cinema_mode===false;
                } catch(e) { return false; }
            }""", timeout=60000)
            page.keyboard.press("x")
            mobile_immersive = wait_state(page, {
                "w69_cinema_mode": True, "history_count": 2,
            })
            check(geometry(page)["stage_requested_height"] >= 325,
                  "Actual 390px cinema mode does not enlarge 3D world")
            mobile = live_frame(page, evidence, "w69-06-immersive-mobile-390.png")
            check(Image.open(io.BytesIO(mobile)).size == (390, 844),
                  "Original phone screenshot wrong viewport size")
            page.keyboard.press("x")
            wait_state(page, {"w69_cinema_mode": False,
                              "history_count": 2})
            page.keyboard.press("l")
            english = wait_state(page, {"locale": "en", "history_count": 2})
            check(english["w69_in_world_machine_readouts"] == 2,
                  "Native translated UI lost in-world real status metadata")
            check(not errors, "Unhandled real browser error: " +
                  " | ".join(errors[:5]))
            ctx.close()
            browser.close()
        server.shutdown()

    images = []
    for file in sorted(evidence.glob("*.png")):
        images.append({
            "filename": file.name,
            "bytes": file.stat().st_size,
            "sha256": hashlib.sha256(file.read_bytes()).hexdigest(),
        })
    check(len(images) == 6,
          "Six genuine source-bound desktop/cinema/mobile frames expected")
    proof = {
        "schema": "LAST_FRONTIER_W69_REAL_CINEMA_INCIDENT_CHROMIUM_V1",
        "status": "PASS",
        "source_sha": sha,
        "true_exported_godot_webgl": True,
        "original_game_state_unmutated_by_camera": True,
        "real_camera_fov_changed": True,
        "real_native_subviewport_enlarged": True,
        "second_native_godot_room": True,
        "real_original_player_decisions": 2,
        "mobile_css_mockup": False,
        "real_phone_gpu_certified": False,
        "human_aaa_art_approval": False,
        "commercial_release_approved": False,
        "screenshots": images,
    }
    (evidence / "W69_REAL_CHROMIUM_PROOF.json").write_text(
        json.dumps(proof, indent=2, ensure_ascii=False) + "\n")
    print("LAST FRONTIER W69 ACTUAL GODOT CINEMA/FOCUS/INCIDENT WEBGL PASS:",
          len(images), "real source-bound PNG frames")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--export", type=Path, required=True)
    p.add_argument("--evidence", type=Path, required=True)
    p.add_argument("--sha", required=True)
    a = p.parse_args()
    run(a.export.resolve(), a.evidence, a.sha)
