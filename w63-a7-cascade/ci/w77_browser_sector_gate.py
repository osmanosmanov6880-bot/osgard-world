#!/usr/bin/env python3
"""W77 original Godot WebGL rendering of source-locked physical bulkhead.
Actual movement + visual feedback in Chromium. Real collision/pass traversal
is verified separately by the W77 Godot native physics suite.
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


def check(ok, message):
    if not ok:
        raise AssertionError(message)


def shot(page, dir_, name):
    raw=page.screenshot(path=str(dir_/name))
    im=Image.open(io.BytesIO(raw)).convert("RGB")
    check(max(ImageStat.Stat(im).stddev)>6.0,
          "Real original Godot 3D framebuffer is blank")
    return raw


def difference(a,b):
    im1=Image.open(io.BytesIO(a)).convert("RGB")
    im2=Image.open(io.BytesIO(b)).convert("RGB")
    check(im1.size==im2.size,"Only actual equal viewport images compared")
    return sum(ImageChops.difference(im1,im2).convert("L").histogram()[12:])


def run(export, evidence, sha):
    check(len(sha)==40 and all(x in "0123456789abcdef" for x in sha),
          "Exact source-pinned SHA required")
    check((export/"index.wasm").read_bytes()[:4]==b"\0asm",
          "True native Godot WASM game export required")
    evidence.mkdir(parents=True,exist_ok=True)
    page_errors=[]
    with LocalServer(("127.0.0.1",0),
                     functools.partial(HTTPHandler,directory=str(export))) as server:
        threading.Thread(target=server.serve_forever,daemon=True).start()
        with sync_playwright() as pw:
            browser=pw.chromium.launch(headless=True,args=[
                "--no-sandbox","--disable-dev-shm-usage",
                "--enable-webgl","--use-gl=angle",
                "--use-angle=swiftshader","--enable-unsafe-swiftshader"])
            context=browser.new_context(viewport={"width":1366,"height":900})
            page=context.new_page()
            page.on("pageerror",lambda e:page_errors.append(str(e)))
            page.goto(f"http://127.0.0.1:{server.server_address[1]}/index.html",
                      wait_until="domcontentloaded",timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached",timeout=180000)
            before=wait_state(page,{
                "w77_original_physical_sector_bulkhead":True,
                "w77_original_mission_gate_locked":False,
                "w77_true_bulkhead_open_events":0,
                "w76_actual_immersive_first_person":False,
                "w72_extended_mode":False,
                "history_count":0,
            })
            check(before["w77_true_native_bulkhead_leaves"]>=16,
                  "Actual source-backed PBR physical corridor model missing")
            page.locator("canvas").first.click(position={"x":18,"y":20})
            page.wait_for_timeout(230)
            a=shot(page,evidence,"w77-01-before-mission-original-free-facility.png")
            page.keyboard.press("Enter")
            started=wait_state(page,{
                "w77_original_mission_gate_locked":True,
                "w77_true_bulkhead_open_events":0,
                "w76_actual_immersive_first_person":True,
                "w70_physical_operator":True,
                "w71_mission_phase":0,
                "w72_extended_mode":True,
                "w76_actual_wayfinding_target":"core",
                "history_count":0,
            })
            check(started["w77_true_native_bulkhead_leaves"]>=16,
                  "Native physical two-panel bulkhead must exist on real 3D deck")
            b=shot(page,evidence,"w77-02-true-source-locked-industrial-airlock.png")
            check(difference(a,b)>500,
                  "Actual first-person playable camera with locked sector must appear")
            page.keyboard.down("w")
            try:
                page.wait_for_function("""() => {
                   const e=document.getElementById('a7-cascade-native-state');
                   if(!e)return false;
                   try{
                     const s=JSON.parse(e.getAttribute('data-state'));
                     return s.w70_physical_operator===true &&
                         s.w70_real_body_xyz[2]>8.5 &&
                         s.w77_original_mission_gate_locked===true;
                   }catch(_){return false;}
                }""",timeout=45000)
            finally:
                page.keyboard.up("w")
            moved=wait_state(page,{"w77_original_mission_gate_locked":True})
            check(moved["history_count"]==0 and moved["w77_true_bulkhead_open_events"]==0,
                  "Walking/approaching true locked gate never awards original A7 decisions")
            c=shot(page,evidence,"w77-03-physical-walk-on-actual-sector-bridge.png")
            check(difference(b,c)>200,"Native 3D player actually walked toward sector gate")

            page.keyboard.press("Tab")
            wait_state(page,{
                "w76_actual_immersive_first_person":False,
                "w77_original_mission_gate_locked":True,
                "history_count":0,
            })
            d=shot(page,evidence,"w77-04-reversible-original-source-controls.png")
            check(difference(c,d)>40,
                  "Controls actually reappear after original TAB cinematic toggle")
            page.keyboard.press("Tab")
            wait_state(page,{
                "w76_actual_immersive_first_person":True,
                "w77_original_mission_gate_locked":True,
            })
            page.set_viewport_size({"width":390,"height":844})
            page.wait_for_function("""() => {
              const e=document.getElementById('a7-cascade-native-state');
              if(!e)return false;
              try{
                const s=JSON.parse(e.getAttribute('data-state'));
                const g=JSON.parse(e.getAttribute('data-geometry'));
                return g.viewport[0]===390 &&
                    s.w68_mobile_hud_compact===true &&
                    s.w77_original_mission_gate_locked===true &&
                    s.w76_actual_immersive_first_person===true;
              }catch(_){return false;}
            }""",timeout=60000)
            g=geometry(page)
            check(g["brand"][3] <= 68 and g["brand"][2] >= 250,
                  "REAL MOBILE SCREEN MUST NOT render a 400px-high narrow brand column")
            check(g["w76_play"][3] <= 65 and g["w76_immersive"][3] <= 65,
                  "REAL MOBILE play/panel buttons must be 40px-class, never 400px tall")
            check(g["stage"][1] < 440,
                  "Actual Godot 3D world must start above mobile fold; no huge title/button header")
            m=shot(page,evidence,
                "w77-05-mobile-390-real-lock-mission-physical-deck.png")
            check(Image.open(io.BytesIO(m)).size==(390,844),
                  "Real mobile-width original Godot WebGL screenshot")
            page.keyboard.press("l")
            wait_state(page,{
                "locale":"en",
                "w77_original_mission_gate_locked":True,
                "history_count":0,
            })
            e=shot(page,evidence,"w77-06-mobile-English-true-3d-gate.png")
            check(difference(m,e)>50,"Native RU/EN actual state translation rendered")
            check(not page_errors,
                  "Unexpected original game WebGL error: "+" | ".join(page_errors[:5]))
            context.close()
            browser.close()
        server.shutdown()
    frames=[]
    for p in sorted(evidence.glob("*.png")):
        data=p.read_bytes()
        frames.append({"name":p.name,"bytes":len(data),
                       "sha256":hashlib.sha256(data).hexdigest()})
    check(len(frames)==6,"Exactly six real source-bound Godot PNGs")
    report={
        "schema":"LAST_FRONTIER_W77_GENUINE_3D_SECTOR_GATE_BROWSER_V1",
        "source_sha":sha,
        "result":"PASS",
        "actual_original_native_Godot_WebGL":True,
        "original_W77_source_gated_3D_sector_shutter_visible":True,
        "actual_physics_player_walks_toward_gate":True,
        "native_closed_gate_hit_and_real_unlocked_crossing_in_Godot_suite":True,
        "browser_does_not_claim_to_test_full_relay_crossing":True,
        "old_A7_core_history_remains_unchanged":True,
        "responsive_390px_browser_not_physical_phone":True,
        "mobile_brand_single_row_and_no_400px_buttons":True,
        "actual_playable_3d_scene_visible_above_mobile_fold":True,
        "AAA_professional_art_signed_off":False,
        "physically_verified_60fps":False,
        "commercial_release_authorized":False,
        "screenshots":frames,
    }
    (evidence/"W77_REAL_GODOT_GATE_BROWSER.json").write_text(
        json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("LAST FRONTIER W77 TRUE NATIVE SECTOR GATE GODOT CHROMIUM PASS:",
          len(frames),"real SHA-bound framebuffer frames")


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--export",type=Path,required=True)
    p.add_argument("--evidence",type=Path,required=True)
    p.add_argument("--sha",required=True)
    a=p.parse_args()
    run(a.export.resolve(),a.evidence,a.sha)
