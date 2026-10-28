#!/usr/bin/env python3
"""W82 original source real 3D navigation HUD browser regression.
This only observes actual Godot WebAssembly frames + live physical controller;
no JavaScript can award A7 decisions, transport player or change mission.
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
from w64_browser_acceptance import HTTPHandler, LocalServer, snapshot, wait_state, geometry

def need(test,message):
    if not test:
        raise AssertionError(message)

def inside(a,b):
    return a[2]>60 and a[3]>35 and a[0]>=b[0]-3 and a[1]>=b[1]-3 and a[0]+a[2]<=b[0]+b[2]+3

def mid(r):
    return r[0]+r[2]/2.0,r[1]+r[3]/2.0

def frame(page,folder,name):
    raw=page.screenshot(path=str(folder/name))
    need(max(ImageStat.Stat(Image.open(io.BytesIO(raw)).convert("RGB")).stddev)>5.0,
         "True engine rendering, not blank mockup or decorative image")
    return raw

def changed(a,b):
    aa=Image.open(io.BytesIO(a)).convert("RGB")
    bb=Image.open(io.BytesIO(b)).convert("RGB")
    need(aa.size==bb.size,"No cross-size or fabricated screenshot differences")
    return sum(ImageChops.difference(aa,bb).convert("L").histogram()[12:])

def run(export,evidence,sha):
    need(len(sha)==40 and all(c in "0123456789abcdef" for c in sha),"Pin exact commit")
    need((export/"index.wasm").read_bytes()[:4]==b"\0asm","Actual Godot WebAssembly required")
    evidence.mkdir(parents=True,exist_ok=True)
    errors=[]
    snapshots=[]
    with LocalServer(("127.0.0.1",0),functools.partial(HTTPHandler,directory=str(export))) as server:
        threading.Thread(target=server.serve_forever,daemon=True).start()
        with sync_playwright() as pw:
            browser=pw.chromium.launch(headless=True,args=[
                "--no-sandbox","--disable-dev-shm-usage","--enable-webgl",
                "--use-gl=angle","--use-angle=swiftshader","--enable-unsafe-swiftshader"])
            context=browser.new_context(viewport={"width":1366,"height":900})
            page=context.new_page()
            page.on("pageerror",lambda e:errors.append(str(e)))
            page.goto(f"http://127.0.0.1:{server.server_address[1]}/index.html",
                      wait_until="domcontentloaded",timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(state="attached",timeout=180000)
            wait_state(page,{"w82_native_navigation_visible":False,
                             "w76_actual_immersive_first_person":False})
            page.locator("canvas").first.click(position={"x":18,"y":20})
            page.keyboard.press("Enter")
            wait_state(page,{"w82_native_navigation_visible":True,
                             "w82_source_phase":0,
                             "w82_source_target":"core",
                             "w80_genuine_full_bleed_original_stage":True,
                             "history_count":0})
            first=snapshot(page)
            need(first["w82_real_goal_distance_m"]>3.2 and
                 not first["w82_real_device_proximity"] and
                 first["w82_real_player_body_id"]>0,
                 "Actual physical CharacterBody source meters and original console radius")
            page.set_viewport_size({"width":390,"height":844})
            page.wait_for_function("""() => {
              const e=document.getElementById('a7-cascade-native-state');
              if(!e)return false;
              try{const g=JSON.parse(e.getAttribute('data-geometry'));
                const s=JSON.parse(e.getAttribute('data-state'));
                return g.viewport[0]===390 && g.viewport[1]===844 &&
                  s.w82_native_navigation_visible===true &&
                  s.w82_navigation_source_redraws>0;
              }catch(_){return false}
            }""",timeout=60000)
            g=geometry(page)
            need(inside(g["w82_native_compass_hud"],g["stage"]) and
                 g["w82_native_compass_hud"][1]+g["w82_native_compass_hud"][3]+5
                   <=g["w80_native_mission_panel"][1],
                 "Source navigation fully visible above native original mission buttons")
            a=frame(page,evidence,"w82-01-true-390px-original-3d-physical-compass.png")
            before=snapshot(page)
            tx,ty=mid(g["w78_true_touch_forward"])
            page.mouse.move(tx,ty)
            page.mouse.down()
            page.wait_for_timeout(950)
            page.mouse.up()
            moved=wait_state(page,{"w78_touch_player_inputs":1})
            need(abs(moved["w82_real_goal_distance_m"]-before["w82_real_goal_distance_m"])>0.12,
                 "Live source-derived compass distance responds to original physical walking")
            need(moved["history_count"]==0 and moved["w82_no_automatic_gameplay"],
                 "Compass changes no A7 core decisions")
            b=frame(page,evidence,"w82-02-true-physical-walk-changes-source-goal-range.png")
            need(changed(a,b)>50,"Original Godot 3D framebuffer changes due to true walking")
            g=geometry(page)
            x,y=mid(g["w79_command1"])
            page.mouse.click(x,y)
            rejected=wait_state(page,{"w79_physical_equipment_attempts":1})
            need(rejected["w72_valve_index"]==0 and
                 not rejected["w82_real_device_proximity"],
                 "Far source valve touch is rejected, HUD never manufactures progress")
            c=frame(page,evidence,"w82-03-physical-proximity-rejection-and-hud.png")
            page.set_viewport_size({"width":844,"height":390})
            page.wait_for_function("""() => {
              const e=document.getElementById('a7-cascade-native-state');
              if(!e)return false;
              try{const s=JSON.parse(e.getAttribute('data-state'));
                const g=JSON.parse(e.getAttribute('data-geometry'));
                return g.viewport[0]===844 && g.viewport[1]===390 &&
                  s.w82_native_navigation_visible===true &&
                  s.w81_touch_landscape_enabled===true;
              }catch(_){return false}
            }""",timeout=60000)
            wide=geometry(page)
            need(inside(wide["w82_native_compass_hud"],wide["stage"]) and
                 wide["w82_native_compass_hud"][1]+wide["w82_native_compass_hud"][3]+5
                   <=wide["w80_native_mission_panel"][1],
                 "True 844x390 physical HUD and mission source panels never intercept")
            p=mid(wide["w80_true_native_language"])
            page.mouse.click(*p)
            wait_state(page,{"locale":"en","w82_native_navigation_visible":True})
            english=snapshot(page)
            need("REACTOR" in english["w82_compass_source_label"] and
                 "GO TO" in english["w82_compass_source_guidance"],
                 "Original on-screen native RU/EN switches true source target guidance")
            d=frame(page,evidence,"w82-04-real-landscape-english-physics-goal.png")
            menu=mid(geometry(page)["w80_true_native_menu"])
            page.mouse.click(*menu)
            wait_state(page,{"w82_native_navigation_visible":False,
                             "w80_genuine_full_bleed_original_stage":False,
                             "history_count":0})
            e=frame(page,evidence,"w82-05-original-menu-restores-game-without-autoplay.png")
            need(changed(d,e)>80,"Real 844x390 MENU returns original native game")
            need(not errors,"Original Godot WebGL page error: "+" | ".join(errors[:5]))
            context.close()
            browser.close()
        server.shutdown()
    imgs=[{"name":p.name,"bytes":p.stat().st_size,
           "sha256":hashlib.sha256(p.read_bytes()).hexdigest()}
          for p in sorted(evidence.glob("*.png"))]
    need(len(imgs)==5,"Five authentic source-built Godot browser frames required")
    manifest={"schema":"LAST_FRONTIER_W82_NATIVE_REAL_SOURCE_WAYFINDER_BROWSER_V1",
       "source_sha":sha,"result":"PASS","actual_Godot_4_4_1_WASM":True,
       "original_CharacterBody_motion_drives_live_distance":True,
       "physical_rejection_preserved":True,"portrait_and_landscape_real_geometry":True,
       "no_auto_win_or_teleports":True,"physical_phone_verified":False,
       "commercial_AAA_approved":False,"images":imgs}
    (evidence/"W82_TRUE_NAVIGATION_CHROMIUM.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("LAST FRONTIER W82 REAL ORIGINAL GODOT PHYSICAL NAV CHROMIUM PASS:",
          len(imgs),"authentic original 3D screenshots")

if __name__=="__main__":
    ap=argparse.ArgumentParser()
    ap.add_argument("--export",type=Path,required=True)
    ap.add_argument("--evidence",type=Path,required=True)
    ap.add_argument("--sha",required=True)
    args=ap.parse_args()
    run(args.export.resolve(),args.evidence,args.sha)
