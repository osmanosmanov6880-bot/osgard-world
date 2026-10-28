#!/usr/bin/env python3
"""W84: original actual Godot WebGL native control profile browser.
No UI mockup or JS game mutation. Click real Godot buttons, verify original
W83 physical Camera3D pitch via CDP real touch, localized/reflowed panel.
"""
import argparse
import functools
import hashlib
import io
import json
import threading
from pathlib import Path
from PIL import Image,ImageChops,ImageStat
from playwright.sync_api import sync_playwright
from w64_browser_acceptance import LocalServer,HTTPHandler,snapshot,geometry,wait_state

def need(v,why):
    if not v:
        raise AssertionError(why)

def inside(r,p):
    return (isinstance(r,list) and len(r)==4 and r[2]>30 and r[3]>30
        and r[0]>=p[0]-3 and r[1]>=p[1]-3
        and r[0]+r[2]<=p[0]+p[2]+3
        and r[1]+r[3]<=p[1]+p[3]+3)

def center(r):
    need(len(r)==4 and r[2]>30 and r[3]>30,"Real Godot native button rect required")
    return r[0]+r[2]*.5,r[1]+r[3]*.5

def click(page,key):
    r=geometry(page)[key]
    x,y=center(r)
    page.mouse.click(x,y)

def img(page,where):
    raw=page.screenshot(path=str(where))
    a=Image.open(io.BytesIO(raw)).convert("RGB")
    need(max(ImageStat.Stat(a).stddev)>5,
        "Actual original Godot WebGL pixel variation, not a blank mockup")
    return raw

def differing(a,b):
    aa=Image.open(io.BytesIO(a)).convert("RGB")
    bb=Image.open(io.BytesIO(b)).convert("RGB")
    need(aa.size==bb.size,"Native source image comparison must be same-size")
    return sum(ImageChops.difference(aa,bb).convert("L").histogram()[12:])

def settled(page,w,h,modal=True):
    page.set_viewport_size({"width":w,"height":h})
    page.wait_for_function("""([w,h,m]) => {
        const el=document.getElementById('a7-cascade-native-state');
        if(!el)return false;
        try {
          const g=JSON.parse(el.getAttribute('data-geometry'));
          const s=JSON.parse(el.getAttribute('data-state'));
          const inside=(r,p)=>Array.isArray(r)&&r.length===4&&
            r[2]>30&&r[3]>30&&r[0]>=p[0]-3&&r[1]>=p[1]-3&&
            r[0]+r[2]<=p[0]+p[2]+3&&r[1]+r[3]<=p[1]+p[3]+3;
          return g.viewport[0]===w&&g.viewport[1]===h&&
            s.w84_native_touch_tune_visible===true&&
            s.w84_native_tune_open===m&&
            inside(g.w84_tune_entry,g.stage)&&
            (!m||[
             'w84_native_panel','w84_gain_button','w84_invert_button',
             'w84_hand_button','w84_reset_button','w84_done_button'
            ].every(key=>inside(g[key],g.stage)));
        }catch(e){return false}
    }""",arg=[w,h,modal],timeout=100000)
    return snapshot(page),geometry(page)

def finger(x,y,index):
    return {"x":round(x,2),"y":round(y,2),
            "id":index,"radiusX":3,"radiusY":3,"force":1}

def original_camera_inversion(page,cdp,g):
    before=snapshot(page)
    a=g['stage']
    mission=g['w80_native_mission_panel']
    look_x=a[0]+a[2]*0.83
    look_y=min(a[1]+205,mission[1]-18)
    need(look_y>a[1]+56 and look_y<mission[1]-8,
         "Actual free camera touch region above live original mission controls")
    start=finger(look_x,look_y,71)
    motion=finger(look_x+8,look_y+29,71)
    cdp.send("Input.dispatchTouchEvent",{"type":"touchStart","touchPoints":[start]})
    cdp.send("Input.dispatchTouchEvent",{"type":"touchMove","touchPoints":[motion]})
    page.wait_for_function("""prior => {
      const e=document.getElementById('a7-cascade-native-state');
      if(!e)return false;
      try {
        const s=JSON.parse(e.getAttribute('data-state'));
        return s.w83_real_camera_rotations>prior;
      }catch(e){return false}
    }""",arg=before["w83_real_camera_rotations"],timeout=30000)
    after=snapshot(page)
    cdp.send("Input.dispatchTouchEvent",{"type":"touchEnd","touchPoints":[motion]})
    need(after["w83_source_pitch"]>before["w83_source_pitch"]+.025,
         "Actual original W70 Camera3D pitch INVERTS under native user preference")
    need(abs(after["w83_source_yaw"]-before["w83_source_yaw"])>.01,
         "Real W70 original yaw responds at user-selected sensitivity")
    need(after["history_count"]==0 and after["w72_valve_index"]==0,
         "Gesture cannot grant original A7 decisions or solve real equipment")
    return {"old_yaw":before["w83_source_yaw"],
            "new_yaw":after["w83_source_yaw"],
            "old_pitch":before["w83_source_pitch"],
            "new_pitch":after["w83_source_pitch"]}

def run(export,evidence,sha):
    need(len(sha)==40 and all(v in "0123456789abcdef" for v in sha),
         "Exact PR source SHA only")
    need((export/"index.wasm").read_bytes()[:4]==b"\0asm",
         "Real original Godot 4.4.1 WebAssembly required")
    evidence.mkdir(parents=True,exist_ok=True)
    errors=[]
    with LocalServer(("127.0.0.1",0),
        functools.partial(HTTPHandler,directory=str(export))) as server:
        threading.Thread(target=server.serve_forever,daemon=True).start()
        with sync_playwright() as pw:
            browser=pw.chromium.launch(headless=True,args=[
                "--no-sandbox","--disable-dev-shm-usage","--enable-webgl",
                "--use-gl=angle","--use-angle=swiftshader",
                "--enable-unsafe-swiftshader"])
            context=browser.new_context(
                viewport={"width":390,"height":844},
                has_touch=True,device_scale_factor=1)
            page=context.new_page()
            page.on("pageerror",lambda e:errors.append(str(e)))
            page.goto(f"http://127.0.0.1:{server.server_address[1]}/index.html",
                wait_until="domcontentloaded",timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached",timeout=180000)
            wait_state(page,{"w84_native_touch_tune_visible":False,
                             "w76_actual_immersive_first_person":False,
                             "history_count":0})
            page.locator("canvas").first.click(position={"x":18,"y":20})
            page.keyboard.press("Enter")
            wait_state(page,{"w84_native_touch_tune_visible":True,
                             "w84_native_tune_open":False,
                             "w80_genuine_full_bleed_original_stage":True,
                             "history_count":0})
            s,g=settled(page,390,844,False)
            actor=s["w82_real_player_body_id"]
            need(actor>0,"Original W70 CharacterBody preserved with actual W84 UI")
            before=img(page,evidence/"w84-01-original-390-Godot-physical-game.png")
            click(page,"w84_tune_entry")
            wait_state(page,{"w84_native_tune_open":True,
                             "w84_modal_actually_suspends_touch":True,
                             "history_count":0})
            s,g=settled(page,390,844,True)
            need(not s["w79_mobile_complete_mission_visible"] and
                 s["w84_original_core_actions_issued"]==0,
                 "Real settings must hide machine actions and never invent decisions")
            click(page,"w84_reset_button")
            wait_state(page,{"w84_look_sensitivity":0.85,
                             "w84_real_inverted_y":False,
                             "w84_real_left_handed":False})
            click(page,"w84_gain_button")
            wait_state(page,{"w84_look_sensitivity":1.15})
            click(page,"w84_invert_button")
            wait_state(page,{"w84_real_inverted_y":True})
            click(page,"w84_hand_button")
            s=wait_state(page,{"w84_real_left_handed":True,
                               "w84_modal_actually_suspends_touch":True,
                               "w84_source_first_button":"W78ActualPhysicsTouch_right"})
            need(s["w84_native_saved_profiles"]>=1,
                 "Real Godot user:// saves native preference without network")
            panel=img(page,evidence/"w84-02-390-real-native-Godot-tuning-modal.png")
            need(differing(before,panel)>85,
                 "Actual native Godot live-game controls visibly changed after clicks")
            click(page,"w84_done_button")
            s=wait_state(page,{"w84_native_tune_open":False,
                               "w84_modal_actually_suspends_touch":False,
                               "w79_mobile_complete_mission_visible":True,
                               "history_count":0})
            cdp=context.new_cdp_session(page)
            look_proof=original_camera_inversion(page,cdp,geometry(page))
            click(page,"w84_tune_entry")
            wait_state(page,{"w84_native_tune_open":True})
            s,g=settled(page,320,700,True)
            need(s["w84_look_sensitivity"]==1.15 and
                 s["w84_real_inverted_y"] and s["w84_real_left_handed"],
                 "Real native controls retain preferences after source 390->320 resize")
            narrow=img(page,evidence/"w84-03-320-responsive-real-mobile-settings.png")
            s,g=settled(page,844,390,True)
            need(s["w84_modal_actually_suspends_touch"] and
                 s["w82_real_player_body_id"]==actor,
                 "Landscape rotates same physical Godot player, profile modal stays safe")
            landscape=img(page,evidence/"w84-04-844-landscape-live-control-studio.png")
            click(page,"w84_reset_button")
            wait_state(page,{"w84_look_sensitivity":0.85,
                             "w84_real_inverted_y":False,
                             "w84_real_left_handed":False})
            click(page,"w84_done_button")
            s,g=settled(page,844,390,False)
            need(not s["w84_modal_actually_suspends_touch"] and
                 s["w79_mobile_complete_mission_visible"] and
                 s["w82_real_player_body_id"]==actor,
                 "Actual source controls and original player restored on landscape DONE")
            playing=img(page,evidence/"w84-05-844-landscape-original-3d-resumed.png")
            need(differing(landscape,playing)>70,
                 "Actual Godot world viewport changes visibly after closing native panel")
            click(page,"w80_true_native_menu")
            end=wait_state(page,{"w84_native_touch_tune_visible":False,
                                 "w84_native_tune_open":False,
                                 "w80_genuine_full_bleed_original_stage":False,
                                 "history_count":0})
            finish=img(page,evidence/"w84-06-exit-original-mission-source-intact.png")
            need(not end["w84_modal_actually_suspends_touch"],
                 "Return-to-MENU cannot leave physical camera input suspended")
            need(not errors,"Actual Godot WebGL runtime errors: "+"|".join(errors[:3]))
            context.close()
            browser.close()
        server.shutdown()
    images=[]
    for path in sorted(evidence.glob("*.png")):
        data=path.read_bytes()
        images.append({"name":path.name,"bytes":len(data),
                       "sha256":hashlib.sha256(data).hexdigest()})
    need(len(images)==6,"Six real Godot 4.4.1 source screenshots, no decorative graphics")
    manifest={
        "schema":"LAST_FRONTIER_W84_NATIVE_MOBILE_COMFORT_BROWSER_V1",
        "source_sha":sha,"result":"PASS",
        "original_live_Godot_WebGL_3D":True,
        "actual_touch_settings_native_buttons":True,
        "original_W70_camera_invert_and_sensitivity_changed":True,
        "real_W78_handedness_change":True,
        "original_A7_decision_history_intact":True,
        "private_local_original_native_user_preferences":True,
        "actual_390_320_844_responsive":True,
        "physical_device_certified":False,
        "actual_original_look_measurement":look_proof,
        "images":images,
    }
    (evidence/"W84_REAL_ORIGINAL_GODOT_NATIVE_SETTINGS.json").write_text(
        json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("LAST FRONTIER W84 ORIGINAL GODOT PHYSICAL MOBILE CONTROL STUDIO CHROMIUM PASS:",
          len(images),"real SHA-verified game frames")

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--export",type=Path,required=True)
    p.add_argument("--evidence",type=Path,required=True)
    p.add_argument("--sha",required=True)
    a=p.parse_args()
    run(a.export.resolve(),a.evidence,a.sha)
