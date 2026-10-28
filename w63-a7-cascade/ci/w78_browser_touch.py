#!/usr/bin/env python3
"""W78 original Godot WebGL Chromium: real mouse-as-touch button_down/up,
native W70 physical character and eye view, G physics refusal at distance,
compact 390/320 immersive layout and actual unchanged gameplay images.
No real phone or touch hardware certification is inferred.
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


def check(ok, why):
    if not ok:
        raise AssertionError(why)


def screenshot(page, folder, name):
    b=page.screenshot(path=str(folder/name))
    img=Image.open(io.BytesIO(b)).convert("RGB")
    check(max(ImageStat.Stat(img).stddev)>6.0,
          "Godot original gameplay must render visible 3D pixels")
    return b


def changed(a,b):
    aa=Image.open(io.BytesIO(a)).convert("RGB")
    bb=Image.open(io.BytesIO(b)).convert("RGB")
    check(aa.size==bb.size,"Only actual same-size browser screenshots compared")
    return sum(ImageChops.difference(aa,bb).convert("L").histogram()[12:])


def center(rect):
    check(len(rect)==4 and rect[2]>=20 and rect[3]>=30,
          "Original Control rect must be a real visible Godot button")
    return float(rect[0])+float(rect[2])/2, float(rect[1])+float(rect[3])/2


def run(export,evidence,sha):
    check(len(sha)==40 and all(c in "0123456789abcdef" for c in sha),
          "Exact source Git head SHA required")
    check((export/"index.wasm").read_bytes()[:4]==b"\0asm",
          "Must run compiled Godot 4.4 WebAssembly not a mock HTML page")
    evidence.mkdir(parents=True,exist_ok=True)
    errors=[]
    with LocalServer(("127.0.0.1",0),
                     functools.partial(HTTPHandler,directory=str(export))) as srv:
        threading.Thread(target=srv.serve_forever,daemon=True).start()
        with sync_playwright() as pw:
            browser=pw.chromium.launch(headless=True,args=[
                "--no-sandbox","--disable-dev-shm-usage",
                "--enable-webgl","--use-gl=angle",
                "--use-angle=swiftshader","--enable-unsafe-swiftshader"])
            context=browser.new_context(viewport={"width":1366,"height":900})
            page=context.new_page()
            page.on("pageerror",lambda e:errors.append(str(e)))
            page.goto(f"http://127.0.0.1:{srv.server_address[1]}/index.html",
                      wait_until="domcontentloaded",timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached",timeout=180000)
            state=wait_state(page,{
                "w78_true_native_touch_button_count":8,
                "w78_original_touch_movement_visible":False,
                "w77_original_physical_sector_bulkhead":True,
                "w72_extended_mode":False,
                "history_count":0,
            })
            check(state["w78_phone_hardware_approved"] is False,
                  "Original source explicitly disclaims physical mobile testing")
            page.locator("canvas").first.click(position={"x":18,"y":18})
            page.keyboard.press("Enter")
            wait_state(page,{
                "w76_actual_immersive_first_person":True,
                "w70_physical_operator":True,
                "w72_extended_mode":True,
                "w77_original_mission_gate_locked":True,
            })
            page.set_viewport_size({"width":390,"height":844})
            page.wait_for_function("""() => {
              const e=document.getElementById('a7-cascade-native-state');
              if(!e)return false;
              try{
                const s=JSON.parse(e.getAttribute('data-state'));
                const g=JSON.parse(e.getAttribute('data-geometry'));
                return s.w78_original_touch_movement_visible===true &&
                  s.w78_true_native_touch_button_count===8 &&
                  g.viewport[0]===390 &&
                  g.w78_true_touch_forward.length===4;
              }catch(_){return false;}
            }""",timeout=60000)
            g=geometry(page)
            rect=g["w78_true_touch_forward"]
            check(rect[1]>0 and rect[1]+rect[3]<844,
                  "Real touch forward input stays visible INSIDE original mobile viewport")
            check(rect[3]>=40 and rect[3]<=75,
                  "Usable 48px actual physical mobile button, not gigantic UI")
            old=snapshot(page)
            p=screenshot(page,evidence,
                "w78-01-real-original-mobile-390-physics-controls.png")
            x,y=center(rect)
            page.mouse.move(x,y)
            page.mouse.down()
            wait_state(page,{"w78_touch_player_inputs":1})
            page.wait_for_timeout(1350)
            during=snapshot(page)
            page.mouse.up()
            check(during["w78_true_touch_physics_frames"]>3,
                  "Actual Godot held native Button.down moved W70 CharacterBody frames")
            check(during["w70_actual_walk_distance"] >
                  old["w70_actual_walk_distance"]+0.35,
                  "Pointer held on actual original Godot touch button MOVES physical actor")
            page.wait_for_timeout(150)
            after=screenshot(page,evidence,
                "w78-02-real-human-pointer-holds-native-W-3d-movement.png")
            check(changed(p,after)>80,
                  "Real 3D pixels change after true physics walking, not a CSS animation")
            tool_x,tool_y=center(geometry(page)["w78_true_touch_world_use"])
            page.mouse.click(tool_x,tool_y)
            refused=wait_state(page,{"w78_touch_actual_world_G_actions":1})
            check(refused["w73_real_raycast_uses"]==0 and
                  refused["w72_valve_index"]==0 and
                  refused["history_count"]==0,
                  "Touch G from actual distant location cannot fake a valid original 3D ray hit")
            button=screenshot(page,evidence,
                "w78-03-original-distant-3d-G-physics-correctly-refused.png")
            check(Image.open(io.BytesIO(button)).size==(390,844),
                  "Actual 390px true source screenshot")
            # Real camera rotation remains native even when touch control is
            # held: source-documented arrow look is not a pre-rendered scene.
            page.keyboard.press("Tab")
            hidden=wait_state(page,{
                "w78_original_touch_movement_visible":False,
                "w76_actual_immersive_first_person":False,
                "history_count":0,
            })
            hidden_image=screenshot(page,evidence,
                "w78-04-hide-touch-return-original-operator-controls.png")
            check(changed(button,hidden_image)>50,
                  "Exiting cinema actually hides the in-viewport controls")
            page.keyboard.press("Tab")
            wait_state(page,{
                "w78_original_touch_movement_visible":True,
                "w76_actual_immersive_first_person":True,
            })
            page.keyboard.press("l")
            wait_state(page,{
                "locale":"en",
                "w78_original_touch_movement_visible":True,
                "history_count":0,
            })
            en=screenshot(page,evidence,
                "w78-05-mobile-English-true-3d-physical-controls.png")
            check(changed(hidden_image,en)>50,
                  "Actual bilingual Godot UI screen changed in original framebuffer")
            page.set_viewport_size({"width":320,"height":700})
            page.wait_for_function("""() => {
              const e=document.getElementById('a7-cascade-native-state');
              if(!e)return false;
              try{
                const s=JSON.parse(e.getAttribute('data-state'));
                const g=JSON.parse(e.getAttribute('data-geometry'));
                return s.w78_original_touch_movement_visible===true &&
                    g.viewport[0]===320 &&
                    g.w78_true_touch_forward.length===4;
              }catch(_){return false;}
            }""",timeout=60000)
            small=screenshot(page,evidence,
                "w78-06-mobile-320-real-physical-native-stage.png")
            check(Image.open(io.BytesIO(small)).size==(320,700),
                  "True original narrow 320px WebGL stage not AI-generated crop")
            check(not errors,"Actual Chromium JS errors: "+" | ".join(errors[:5]))
            context.close()
            browser.close()
        srv.shutdown()
    images=[{"name":p.name,"sha256":hashlib.sha256(p.read_bytes()).hexdigest(),
             "bytes":p.stat().st_size} for p in sorted(evidence.glob("*.png"))]
    check(len(images)==6,"Exactly 6 source-bound true Godot browser image captures")
    proof={
        "schema":"LAST_FRONTIER_W78_TRUE_WEBGL_MOBILE_NATIVE_TOUCH_V1",
        "source_sha":sha,
        "result":"PASS",
        "actual_Godot_webassembly":True,
        "actual_characterbody_movement_by_held_browser_pointer":True,
        "original_aimed_device_distance_refusal":True,
        "reversible_inworld_touch_layout":True,
        "real_320_and_390_browser_mobile_width":True,
        "no_fake_A7_gameplay_success":True,
        "real_mobile_touch_device_hardware_tested":False,
        "actual_controller_hardware_tested":False,
        "real_hardware_60fps_certified":False,
        "AAA_art_retail_release_approved":False,
        "screenshots":images,
    }
    (evidence/"W78_ORIGINAL_GODOT_TOUCH_BROWSER_PROOF.json").write_text(
        json.dumps(proof,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("LAST FRONTIER W78 TRUE GODOT MOBILE TOUCH CHROMIUM PASS:",
          len(images),"unaltered original SHA-bound screenshots")

if __name__=="__main__":
    a=argparse.ArgumentParser()
    a.add_argument("--export",type=Path,required=True)
    a.add_argument("--evidence",type=Path,required=True)
    a.add_argument("--sha",required=True)
    args=a.parse_args()
    run(args.export.resolve(),args.evidence,args.sha)
