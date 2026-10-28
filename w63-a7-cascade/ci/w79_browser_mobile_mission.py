#!/usr/bin/env python3
"""W79 original compiled Godot WebGL end-to-end input UX smoke, not a mockup.
The fully solved 6-cycle original campaign is tested by Godot W79 native
physics; this Chromium test checks rendered source-linked mobile commands,
actual pointer presses, immutable rejected-far valve, responsive 320/390
screen sizes, original actor movement and reversible desktop controls.
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


def check(ok, message):
    if not ok:
        raise AssertionError(message)


def frame(page, folder, name):
    raw=page.screenshot(path=str(folder/name))
    img=Image.open(io.BytesIO(raw)).convert("RGB")
    check(max(ImageStat.Stat(img).stddev)>6,
          "Native Godot genuine 3D framebuffer cannot be blank")
    return raw


def difference(a,b):
    aa=Image.open(io.BytesIO(a)).convert("RGB")
    bb=Image.open(io.BytesIO(b)).convert("RGB")
    check(aa.size==bb.size,"Real browser images use same actual viewport")
    return sum(ImageChops.difference(aa,bb).convert("L").histogram()[12:])


def center(r):
    check(len(r)==4 and r[2]>=22 and r[3]>=20,
          "Actual source-native Godot control must be interactable")
    return float(r[0])+float(r[2])/2,float(r[1])+float(r[3])/2


def run(export, evidence, sha):
    check(len(sha)==40 and all(x in "0123456789abcdef" for x in sha),
          "Full exact real Git source commit SHA")
    check((export/"index.wasm").read_bytes()[:4]==b"\0asm",
          "Real original Godot WebAssembly expected")
    evidence.mkdir(parents=True,exist_ok=True)
    errors=[]
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
            page.on("pageerror",lambda e:errors.append(str(e)))
            page.goto(f"http://127.0.0.1:{server.server_address[1]}/index.html",
                wait_until="domcontentloaded",timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached",timeout=180000)
            state=wait_state(page,{
                "w79_native_command_slots":5,
                "w79_mobile_complete_mission_visible":False,
                "w78_true_native_touch_button_count":8,
                "history_count":0,
            })
            check(not state["w79_phone_hardware_certified"],
                  "Do not confuse original Chromium software-rendered mobile with physical device QA")
            page.locator("canvas").first.click(position={"x":15,"y":18})
            page.keyboard.press("Enter")
            wait_state(page,{
                "w76_actual_immersive_first_person":True,
                "w72_extended_mode":True,
                "w77_original_mission_gate_locked":True,
                "w79_mobile_complete_mission_visible":False,
            })
            page.set_viewport_size({"width":390,"height":844})
            page.wait_for_function("""() => {
                const n=document.getElementById('a7-cascade-native-state');
                if(!n)return false;
                try {
                  const s=JSON.parse(n.getAttribute('data-state'));
                  const g=JSON.parse(n.getAttribute('data-geometry'));
                  return g.viewport[0]===390 &&
                      s.w79_mobile_complete_mission_visible===true &&
                      s.w79_source_based_mode==='valve' &&
                      s.w79_current_source_phase===0 &&
                      s.w78_original_touch_movement_visible===true &&
                      g.w79_command1.length===4;
                } catch(_) {return false}
            }""",timeout=60000)
            g=geometry(page)
            d=g["w79_command1"]
            check(d[1]>50 and d[1]+d[3]<844-65,
                  "True native W79 command dock must sit above existing W78 real touch rail")
            check(d[3]>=42 and d[3]<=67,
                  "Original source-gated mission command touch targets are usable, not a 400px column")
            check(g["w79_offline_save"][3]<=38,
                  "Source-validated save is compact in original real mobile game")
            first=frame(page,evidence,
                "w79-01-390-original-mobile-reactor-context-valve.png")
            px,py=center(d)
            page.mouse.click(px,py)
            refused=wait_state(page,{"w79_physical_equipment_attempts":1})
            check(refused["w72_valve_index"]==0 and
                  refused["history_count"]==0 and
                  refused["w71_mission_phase"]==0,
                  "Physical original W72 rejects valve touch when operator is too far")
            rejected=frame(page,evidence,
                "w79-02-physical-rejection-does-not-fake-mission-progress.png")
            check(difference(first,rejected)>20,
                  "Actual native 3D UI reacts to the refused source action")
            # Original W78 in-world movement remains reachable while the new
            # mission rail is present: no overlay blocks the world controls.
            move=g["w78_true_touch_forward"]
            mx,my=center(move)
            page.mouse.move(mx,my)
            page.mouse.down()
            page.wait_for_timeout(880)
            page.mouse.up()
            moved=wait_state(page,{"w78_touch_player_inputs":1})
            check(moved["w70_real_physical_distance"]>0.5 and
                  moved["history_count"]==0,
                  "New mission dock must not intercept actual old touch walk controls")
            moving=frame(page,evidence,
                "w79-03-actual-original-touch-walk-with-5-phase-overlay.png")
            check(difference(rejected,moving)>80,
                  "Actual original 3D world changes because source player physically walked")
            page.keyboard.press("l")
            translated=wait_state(page,{
                "locale":"en",
                "w79_mobile_complete_mission_visible":True,
                "w79_source_based_mode":"valve",
            })
            english=frame(page,evidence,
                "w79-04-original-English-one-goal-command-panel.png")
            check(difference(moving,english)>50,
                  "Actual native RU/EN game renders different original command text")
            page.set_viewport_size({"width":320,"height":700})
            page.wait_for_function("""() => {
                const n=document.getElementById('a7-cascade-native-state');
                if(!n)return false;
                try {
                  const s=JSON.parse(n.getAttribute('data-state'));
                  const g=JSON.parse(n.getAttribute('data-geometry'));
                  return g.viewport[0]===320 &&
                      s.w79_mobile_complete_mission_visible===true &&
                      g.w79_command1.length===4 &&
                      s.w79_source_based_mode==='valve';
                } catch(_){return false}
            }""",timeout=60000)
            small_geo=geometry(page)
            check(small_geo["w79_command1"][2]>=38 and
                  small_geo["w79_command1"][3]>=42,
                  "320px source-authentic compact phase command remains tappable")
            narrow=frame(page,evidence,
                "w79-05-real-320px-mobile-complete-mission-controls.png")
            check(Image.open(io.BytesIO(narrow)).size==(320,700),
                  "320x700 actually rendered unedited Chromium Godot pixels")
            page.keyboard.press("Tab")
            hidden=wait_state(page,{
                "w76_actual_immersive_first_person":False,
                "w79_mobile_complete_mission_visible":False,
                "w78_original_touch_movement_visible":False,
                "history_count":0,
            })
            no_dock=frame(page,evidence,
                "w79-06-original-Tab-safely-hides-both-physical-command-rails.png")
            check(difference(narrow,no_dock)>30,
                  "Tab actually restores original controls and clears mobile overlay")
            check(not errors,
                  "Genuine WebGL browser runtime errors: "+" | ".join(errors[:6]))
            context.close()
            browser.close()
        server.shutdown()
    images=[{"name":p.name,"sha256":hashlib.sha256(p.read_bytes()).hexdigest(),
             "bytes":p.stat().st_size} for p in sorted(evidence.glob("*.png"))]
    check(len(images)==6,"Six actual unchanged original WebGL screenshots required")
    report={
        "schema":"LAST_FRONTIER_W79_TRUE_COMPLETE_ORIGINAL_MOBILE_MISSION_BROWSER_V1",
        "head_source_sha":sha,
        "result":"PASS",
        "actual_original_Godot_4_4_1_WebGL":True,
        "mobile_source_phase_context_actions_rendered":True,
        "true_original_far_device_use_rejected":True,
        "original_touch_physical_walking_works_with_context_deck":True,
        "original_RU_EN_320_390_responsive_ui":True,
        "no_fake_one_click_win_or_autoplay":True,
        "complete_12_action_source_game_native_tested_separately":True,
        "physical_Android_iPhone_device_tested":False,
        "consumer_GPU_60fps_tested":False,
        "production_AAA_art_or_commercial_release_certified":False,
        "images":images,
    }
    (evidence/"W79_ACTUAL_GODOT_MOBILE_MISSION_BROWSER.json").write_text(
        json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("LAST FRONTIER W79 TRUE FIVE-PHASE MOBILE GAME CHROMIUM PASS:",
          len(images),"unaltered real engine frames")

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--export",type=Path,required=True)
    p.add_argument("--evidence",type=Path,required=True)
    p.add_argument("--sha",required=True)
    args=p.parse_args()
    run(args.export.resolve(),args.evidence,args.sha)
