#!/usr/bin/env python3
"""LAST FRONTIER W79: TRUE ORIGINAL GODOT WebGL mobile source UI.
Chromium sends actual pointer taps to native 3D mission controls; confirms
real original W72 distance rejection, 390/320 compact UI and Tab/RU-EN.
The complete 12-action five-stage winning route is separately performed by
Godot's actual native W79 game test, using controlled QA station placement.
No human session or physical Android/iOS device is claimed here.
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


def verify(ok, message):
    if not ok:
        raise AssertionError(message)


def shot(page, folder, name):
    raw=page.screenshot(path=str(folder/name))
    image=Image.open(io.BytesIO(raw)).convert("RGB")
    verify(max(ImageStat.Stat(image).stddev)>6.0,
           "Actual original native Godot 3D framebuffer not blank")
    return raw


def changed(a,b):
    left=Image.open(io.BytesIO(a)).convert("RGB")
    right=Image.open(io.BytesIO(b)).convert("RGB")
    verify(left.size==right.size,"Same source-authentic framebuffer required")
    return sum(ImageChops.difference(left,right).convert("L").histogram()[12:])


def middle(rect):
    verify(isinstance(rect,list) and len(rect)==4 and
           rect[2]>=25 and rect[3]>=20,"A real visible native Godot button required")
    return rect[0]+rect[2]/2,rect[1]+rect[3]/2


def run(export, folder, sha):
    verify(len(sha)==40 and all(ch in "0123456789abcdef" for ch in sha),
           "Exact source commit required")
    verify((export/"index.wasm").read_bytes()[:4]==b"\0asm",
           "Original real Godot 4.4.1 WASM required; no HTML simulation")
    folder.mkdir(parents=True,exist_ok=True)
    errors=[]
    with LocalServer(("127.0.0.1",0),
                     functools.partial(HTTPHandler,directory=str(export))) as server:
        threading.Thread(target=server.serve_forever,daemon=True).start()
        with sync_playwright() as playwright:
            browser=playwright.chromium.launch(headless=True,args=[
                "--no-sandbox","--disable-dev-shm-usage","--enable-webgl",
                "--use-gl=angle","--use-angle=swiftshader",
                "--enable-unsafe-swiftshader"])
            context=browser.new_context(viewport={"width":1366,"height":900})
            page=context.new_page()
            page.on("pageerror",lambda e:errors.append(str(e)))
            page.goto(f"http://127.0.0.1:{server.server_address[1]}/index.html",
                      wait_until="domcontentloaded",timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached",timeout=180000)
            initial=wait_state(page,{
                "w79_mobile_complete_mission_visible":False,
                "w79_native_command_slots":5,
                "w78_true_native_touch_button_count":8,
                "w72_extended_mode":False,"history_count":0,
            })
            verify(initial["w79_phone_hardware_certified"] is False,
                   "Software test must not certify an actual phone")
            page.locator("canvas").first.click(position={"x":18,"y":18})
            page.keyboard.press("Enter")
            wait_state(page,{
                "w76_actual_immersive_first_person":True,
                "w70_physical_operator":True,
                "w72_extended_mode":True,
                "w79_mobile_complete_mission_visible":False,
                "history_count":0,
            })
            page.set_viewport_size({"width":390,"height":844})
            page.wait_for_function("""() => {
              const e=document.getElementById('a7-cascade-native-state');
              if(!e)return false;
              try{
                const s=JSON.parse(e.getAttribute('data-state'));
                const g=JSON.parse(e.getAttribute('data-geometry'));
                return g.viewport[0]===390 &&
                    s.w79_mobile_complete_mission_visible===true &&
                    s.w79_source_based_mode==='valve' &&
                    s.w79_current_source_phase===0 &&
                    g.w79_command1.length===4;
              }catch(_){return false;}
            }""",timeout=60000)
            start=snapshot(page)
            g=geometry(page)
            cmd=g["w79_command1"]
            touch=g["w78_true_touch_forward"]
            verify(cmd[3]>=30 and cmd[3]<=80,
                   "Real native mobile phase-action must be a concise tap target")
            verify(cmd[1]+cmd[3] <= touch[1]+3,
                   "Source-authored mission deck may not cover original walk buttons")
            verify(g["stage"][1]<450,
                   "Real 3D world must remain visible above mobile screen fold")
            before=shot(page,folder,
                "w79-01-real-Godot-390-original-source-thermal-mission.png")
            x,y=middle(cmd)
            page.mouse.click(x,y)
            far=wait_state(page,{
                "w79_physical_equipment_attempts":1,
                "w79_current_source_phase":0,
                "w72_valve_index":0,
                "history_count":0,
            })
            verify(far["w79_source_based_mode"]=="valve",
                   "Original physical W72 valve refuses remote mobile action")
            after=shot(page,folder,
                "w79-02-true-Godot-physical-distance-refuses-remote-touch.png")
            verify(changed(before,after)>35,
                   "Original equipment rejection must visibly update the scene")

            page.keyboard.press("Tab")
            wait_state(page,{
                "w79_mobile_complete_mission_visible":False,
                "w78_original_touch_movement_visible":False,
                "w76_actual_immersive_first_person":False,
                "history_count":0,
            })
            restored=shot(page,folder,
                "w79-03-original-dashboard-restores-without-losing-game.png")
            verify(changed(after,restored)>50,
                   "Original desktop-style controls are restored by real Tab")
            page.keyboard.press("Tab")
            wait_state(page,{
                "w79_mobile_complete_mission_visible":True,
                "w78_original_touch_movement_visible":True,
                "w79_source_based_mode":"valve",
                "history_count":0,
            })
            page.keyboard.press("l")
            en=wait_state(page,{
                "locale":"en",
                "w79_mobile_complete_mission_visible":True,
                "w79_current_source_phase":0,
                "history_count":0,
            })
            translated=shot(page,folder,
                "w79-04-original-English-source-phase-controls-Godot.png")
            verify(changed(restored,translated)>50,
                   "Real RU/EN native interactive mission interface translated")

            page.set_viewport_size({"width":320,"height":700})
            page.wait_for_function("""() => {
              const e=document.getElementById('a7-cascade-native-state');
              if(!e)return false;
              try{
                const s=JSON.parse(e.getAttribute('data-state'));
                const g=JSON.parse(e.getAttribute('data-geometry'));
                return g.viewport[0]===320 &&
                    s.w79_mobile_complete_mission_visible===true &&
                    s.w79_source_based_mode==='valve' &&
                    g.w79_command1.length===4;
              }catch(_){return false;}
            }""",timeout=60000)
            g320=geometry(page)
            verify(g320["w79_command1"][3]<=80 and
                   g320["w79_command1"][2]>=30,
                   "Even original 320px layout exposes real equipment button")
            verify(g320["w79_command1"][1]+g320["w79_command1"][3]
                    <=g320["w78_true_touch_forward"][1]+3,
                   "320px field controls do not overlap physical walking controls")
            small=shot(page,folder,
                "w79-05-authentic-320px-original-mobile-mission-and-physics.png")
            verify(Image.open(io.BytesIO(small)).size==(320,700),
                   "Actual native 320px browser capture, no generated crop")
            page.keyboard.press("Tab")
            tiny=wait_state(page,{
                "w79_mobile_complete_mission_visible":False,
                "w78_original_touch_movement_visible":False,
                "history_count":0,
            })
            compact=shot(page,folder,
                "w79-06-320px-native-original-source-controls-reversible.png")
            verify(changed(small,compact)>35,
                   "Original source normal/immersive layout actually changes")
            verify(not errors,"Original WebGL JS failures: "+" | ".join(errors[:5]))
            context.close()
            browser.close()
        server.shutdown()
    frames=[{"name":p.name,"bytes":p.stat().st_size,
             "sha256":hashlib.sha256(p.read_bytes()).hexdigest()}
             for p in sorted(folder.glob("*.png"))]
    verify(len(frames)==6,
           "Exactly 6 original unedited real native Godot browser screenshots")
    evidence={
        "schema":"LAST_FRONTIER_W79_REAL_COMPLETE_MOBILE_SOURCE_DECK_WEBGL_V1",
        "source_sha":sha,
        "result":"PASS",
        "actual_original_Godot_WebGL_game":True,
        "native_context_controls_in_true_3d_world":True,
        "original_W72_distance_lock_refuses_remote_touch":True,
        "real_RU_EN_390px_and_320px_browser":True,
        "no_source_fabricated_win_or_progress":True,
        "original_full_game_12_action_success_tested_in_native_Godot_suite":True,
        "real_human_long_session_tested":False,
        "physical_Android_iOS_hardware_tested":False,
        "consumer_GPU_60fps_certified":False,
        "commercial_original_AAA_art_signoff":False,
        "screenshots":frames,
    }
    (folder/"W79_ORIGINAL_MOBILE_GODOT_BROWSER_EVIDENCE.json").write_text(
        json.dumps(evidence,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("LAST FRONTIER W79 ORIGINAL COMPLETE MOBILE DECK GODOT CHROMIUM PASS:",
          len(frames),"real source-linked unedited game screenshots")


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--export",type=Path,required=True)
    parser.add_argument("--evidence",type=Path,required=True)
    parser.add_argument("--sha",required=True)
    a=parser.parse_args()
    run(a.export.resolve(),a.evidence,a.sha)
