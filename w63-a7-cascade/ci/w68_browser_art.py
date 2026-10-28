#!/usr/bin/env python3
"""W68 visual acceptance using true exported Godot WASM and genuine Chromium.

This test sends native keyboard events to the real 3D game. It never paints an
imitation screenshot or directly manipulates the read-only gameplay marker.
"""
import argparse
import functools
import hashlib
import io
import json
import threading
from pathlib import Path

from PIL import Image, ImageStat, ImageChops
from playwright.sync_api import sync_playwright
from w64_browser_acceptance import HTTPHandler, LocalServer, wait_state, snapshot, geometry


def require(ok, reason):
    if not ok:
        raise AssertionError(reason)


def crop_and_metrics(raw):
    image = Image.open(io.BytesIO(raw)).convert("RGB")
    width, height = image.size
    rectangle = (
        int(width * 0.18), int(height * 0.20),
        int(width * 0.84), int(height * 0.71)
    )
    portion = image.crop(rectangle)
    stats = ImageStat.Stat(portion)
    luminance = 0.2126*stats.mean[0] + 0.7152*stats.mean[1] + 0.0722*stats.mean[2]
    return portion, {
        "luminance": round(luminance, 3),
        "color_spread": round(max(stats.stddev), 3),
        "unique_coarse_colors": len({
            (r//24, g//24, b//24) for (r,g,b) in
            list(portion.resize((150,75)).getdata())
        })
    }


def change_pixels(a, b):
    delta = ImageChops.difference(a, b).convert("L")
    return sum(delta.histogram()[12:])


def main(export, out, sha):
    require(len(sha)==40 and all(k in "0123456789abcdef" for k in sha),
            "Exact Git SHA required")
    require((export/"index.wasm").read_bytes()[:4]==b"\x00asm",
            "Actual Godot WebAssembly export required")
    out.mkdir(parents=True, exist_ok=True)
    errors = []
    evidence = {}
    with LocalServer(("127.0.0.1", 0),
                     functools.partial(HTTPHandler, directory=str(export))) as http:
        threading.Thread(target=http.serve_forever, daemon=True).start()
        url = f"http://127.0.0.1:{http.server_address[1]}/index.html"
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True, args=[
                "--no-sandbox", "--disable-dev-shm-usage", "--enable-webgl",
                "--use-gl=angle", "--use-angle=swiftshader",
                "--enable-unsafe-swiftshader",
            ])
            ctx = browser.new_context(viewport={"width":1366, "height":900},
                                      device_scale_factor=1)
            page = ctx.new_page()
            page.on("pageerror", lambda e: errors.append(str(e)))
            page.goto(url, wait_until="domcontentloaded", timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached", timeout=180000)
            boot = wait_state(page, {"shift":0, "status":"playing",
                                     "history_count":0, "real_native_3d":True,
                                     "w67_two_3d_sectors":True,
                                     "w67_inspection_sector":0})
            require(boot["w68_machined_hero_meshes"] >=145,
                    "Actual new smooth industrial 3D geometry not loaded")
            require(boot["w68_smooth_parts"]>=18,
                    "No real smooth annular reactor components")
            require(boot["w68_pbr_profiles"]==7,
                    "Seven original textured PBR material families absent")
            require(boot["w68_genuine_texture_pixels"]==7*96*96,
                    "Actual procedural PBR ImageTexture pixels not produced")
            require(boot["w68_restrained_hud"],
                    "Native read-only visual overlay missing")
            canvas=page.locator("canvas").first
            canvas.click(position={"x":18,"y":18})
            page.wait_for_timeout(600)
            before = page.screenshot(path=str(out/"w68-01-industrial-reactor.png"))
            photo_core, metrics = crop_and_metrics(before)
            require(metrics["luminance"]>=18.0,
                    "New authored reactor is too dark to read in actual Chromium")
            require(metrics["color_spread"]>=17.0,
                    "New rendered 3D environment lacks visual contrast")
            require(metrics["unique_coarse_colors"]>=20,
                    "World palette lost visual hierarchy and materially readable surfaces")
            evidence["reactor_metrics"]=metrics
            print("W68 ACTUAL PBR REACTOR VISUAL METRICS", json.dumps(metrics), flush=True)

            page.keyboard.press("n")
            relay = wait_state(page, {"w67_inspection_sector":1,
                                      "w67_walk_progress":1.0,
                                      "history_count":0})
            require(relay["w68_machined_hero_meshes"]>=145,
                    "Original detailed relay machines not present in zone 02")
            page.wait_for_timeout(500)
            relay_png=page.screenshot(path=str(out/"w68-02-pbr-relay.png"))
            photo_relay, relay_metric=crop_and_metrics(relay_png)
            require(change_pixels(photo_core,photo_relay)>800,
                    "Native relay room is not visibly different")
            require(relay_metric["luminance"]>=18.0,
                    "Relay machinery too dark to distinguish")
            evidence["relay_metrics"]=relay_metric

            page.keyboard.press("n")
            wait_state(page, {"w67_inspection_sector":0,
                              "w67_walk_progress":0.0})
            page.keyboard.press("1")
            pumping=wait_state(page, {"history_count":1,"actions_left":1})
            require(pumping["metrics"]["heat"]==42 and
                    pumping["metrics"]["energy"]==79,
                    "W63 source mechanical tradeoff changed by art code")
            page.keyboard.press("4")
            after=wait_state(page, {"history_count":2,"shift":1})
            require(after["metrics"]["heat"]==59 and
                    after["metrics"]["signal"]==61,
                    "Original deterministic first incident changed by art code")
            reactive=page.screenshot(path=str(out/"w68-03-reactive-machinery.png"))
            reactive_crop,reactive_metrics=crop_and_metrics(reactive)
            require(change_pixels(photo_core,reactive_crop)>200,
                    "Genuine 3D machine image did not respond to real player input")
            evidence["reaction_metrics"]=reactive_metrics

            page.keyboard.press("q")
            eco = wait_state(page, {"quality":"eco"})
            require(eco["history_count"]==2,
                    "Rendering quality switch changed original game progression")
            page.keyboard.press("q")
            hero = wait_state(page, {"quality":"hero"})
            require(hero["history_count"]==2,
                    "Restoring real Hero quality changed the game")

            page.set_viewport_size({"width":390,"height":844})
            page.wait_for_function("""() => {
                const e=document.getElementById('a7-cascade-native-state');
                if (!e) return false;
                const state=JSON.parse(e.getAttribute('data-state'));
                const geo=JSON.parse(e.getAttribute('data-geometry'));
                return geo.viewport[0]<=420 &&
                    geo.stage_requested_height<=310 &&
                    state.w68_mobile_hud_compact === true;
            }""", timeout=60000)
            page.keyboard.press("n")
            mobile_state=wait_state(page, {"w67_inspection_sector":1,
                                           "w67_mobile_world_text_hidden":True,
                                           "w68_mobile_hud_compact":True})
            require(mobile_state["history_count"]==2,
                    "Mobile world camera navigation touched original game")
            mobile_png=page.screenshot(path=str(out/"w68-04-relay-mobile-390.png"))
            mobile_image=Image.open(io.BytesIO(mobile_png)).convert("RGB")
            require(mobile_image.size==(390,844),
                    "Real screenshot must use 390x844 phone viewport")
            require(max(ImageStat.Stat(mobile_image).stddev)>6.0,
                    "Mobile real Godot window is blank")
            evidence["mobile"]={"width":390,"height":844,"readable_ui":True,
                                "certified_real_mobile_device":False}
            require(not errors, "Uncaught JS/Godot browser failure: "+
                    " | ".join(errors[:5]))
            ctx.close()
            browser.close()
        http.shutdown()

    pictures=[]
    for path in sorted(out.glob("*.png")):
        pictures.append({"filename":path.name,"bytes":len(path.read_bytes()),
                        "sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
    require(len(pictures)==4,"Four actual source-bound Chromium screenshots required")
    report = {
        "schema":"LAST_FRONTIER_W68_ACTUAL_PBR_GODOT_CHROMIUM_V1",
        "source_sha":sha,"status":"PASS",
        "real_native_godot_export":True,
        "real_chromium_webassembly":True,
        "real_player_keys":["N","1","4","Q"],
        "verified_true_3d_rooms":2,
        "actual_procedural_microtextures":7,
        "all_pngs_original_browser_output":True,
        "physical_gpu_benchmark_available":False,
        "human_aaa_art_approval":False,
        "production_approved":False,"deployed":False,
        "image_evidence":evidence,"pictures":pictures,
    }
    (out/"W68_ORIGINAL_VISUAL_ACCEPTANCE.json").write_text(
        json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("LAST FRONTIER W68 REAL PBR THREE-DIMENSIONAL WEBGL GAME PASS:",
          len(pictures),"authentic source-bound visual frames")


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--export",type=Path,required=True)
    p.add_argument("--evidence",type=Path,required=True)
    p.add_argument("--sha",required=True)
    a=p.parse_args()
    main(a.export.resolve(),a.evidence,a.sha)
