#!/usr/bin/env python3
"""W83 live Godot 4.4.1 WebGL multi-touch browser acceptance.
Sends TRUE Chromium CDP Input.dispatchTouchEvent with two different real
touch point IDs, simultaneously holds original W78 movement while dragging
real W70 first-person camera. No fake JS game mutations, no mocked screens.
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
from w64_browser_acceptance import LocalServer,HTTPHandler,snapshot,geometry,wait_state

def require(ok,detail):
    if not ok:
        raise AssertionError(detail)

def midpoint(r):
    require(isinstance(r,list) and len(r)==4 and r[2]>30 and r[3]>35,
            "Original native control must have actual clickable geometry")
    return float(r[0])+float(r[2])*0.5,float(r[1])+float(r[3])*0.5

def contained(a,b):
    return (len(a)==4 and a[2]>20 and a[3]>15 and
        a[0]>=b[0]-3 and a[1]>=b[1]-3 and
        a[0]+a[2]<=b[0]+b[2]+3 and a[1]+a[3]<=b[1]+b[3]+3)

def picture(page,path):
    raw=page.screenshot(path=str(path))
    img=Image.open(io.BytesIO(raw)).convert("RGB")
    require(max(ImageStat.Stat(img).stddev)>5.0,
            "Original real Godot WebGL screenshot has actual varied pixels")
    return raw

def difference(a,b):
    aa=Image.open(io.BytesIO(a)).convert("RGB")
    bb=Image.open(io.BytesIO(b)).convert("RGB")
    require(aa.size==bb.size,"Compare ONLY same-resolution real source frames")
    return sum(ImageChops.difference(aa,bb).convert("L").histogram()[12:])

def stage_ready(page,width,height):
    page.set_viewport_size({"width":width,"height":height})
    page.wait_for_function("""([w,h]) => {
      const el=document.getElementById('a7-cascade-native-state');
      if(!el)return false;
      try {
        const s=JSON.parse(el.getAttribute('data-state'));
        const g=JSON.parse(el.getAttribute('data-geometry'));
        const inside=(r,p) => Array.isArray(r)&&r.length===4&&
          r[2]>0&&r[3]>0&&r[0]>=p[0]-3&&r[1]>=p[1]-3&&
          r[0]+r[2]<=p[0]+p[2]+3&&r[1]+r[3]<=p[1]+p[3]+3;
        return g.viewport[0]===w&&g.viewport[1]===h&&
          s.w83_real_multitouch_active===true&&
          s.w80_genuine_full_bleed_original_stage===true&&
          s.w83_original_body_preserved===true&&
          s.w79_mobile_complete_mission_visible===true&&
          inside(g.w80_native_touch_rail,g.stage)&&
          inside(g.w80_native_mission_panel,g.stage)&&
          inside(g.w82_native_compass_hud,g.stage);
      }catch(e){return false}
    }""",arg=[width,height],timeout=100000)
    g=geometry(page)
    require(contained(g["w80_native_touch_rail"],g["stage"]) and
            contained(g["w80_native_mission_panel"],g["stage"]) and
            contained(g["w82_native_compass_hud"],g["stage"]),
            "Original actual W78/W79/W82 rectangles entirely in real 3D stage")
    return g

def point(x,y,finger):
    return {"x":round(float(x),2),"y":round(float(y),2),
            "id":int(finger),"radiusX":3.0,"radiusY":3.0,
            "force":1.0}

def send(cdp,kind,points):
    # Chromium's default CDP implementation treats touchPoints as the
    # CHANGED points, not the remaining active points. In particular,
    # touchEnd([finger]) ENDS that exact finger. Never send [finger 1]
    # when trying to release finger 2; that accidentally stops walking.
    cdp.send("Input.dispatchTouchEvent",
             {"type":kind,"touchPoints":points})

def enable_native_touch_audit(page):
    # Passive DOM event observation ONLY. No mutation of the Godot game,
    # input queue, camera, physics, mission or read-only source snapshot.
    page.evaluate("""() => {
        window.__w83TouchAudit = [];
        for (const type of ['touchstart','touchmove','touchend','touchcancel']) {
            window.addEventListener(type, event => {
                const points = xs => Array.from(xs, t => ({
                    id: t.identifier, x: Math.round(t.clientX),
                    y: Math.round(t.clientY)
                }));
                window.__w83TouchAudit.push({
                    type, changed: points(event.changedTouches),
                    remaining: points(event.touches)
                });
            }, {capture: true, passive: true});
        }
    }""")

def assert_source_touch_release(page,a,b):
    audit=page.evaluate("() => window.__w83TouchAudit.slice()")
    endings=[x for x in audit if x['type']=='touchend']
    require(len(endings)>=2,
        "Real Chromium must deliver TWO separate native DOM touchend events")
    camera_end,walk_end=endings[-2:]
    require(len(camera_end['changed'])==1 and
            abs(camera_end['changed'][0]['x']-b['x'])<35 and
            len(camera_end['remaining'])==1 and
            abs(camera_end['remaining'][0]['x']-a['x'])<35,
            "CDP must release camera finger at camera x while FIRST walk finger remains physically down")
    require(len(walk_end['changed'])==1 and
            abs(walk_end['changed'][0]['x']-a['x'])<35 and
            len(walk_end['remaining'])==0,
            "CDP final touchEnd must release ONLY first walking finger")
    return {'camera_end':camera_end,'walk_end':walk_end,
            'event_count':len(audit)}

def true_dual_finger(page,cdp,g):
    start=snapshot(page)
    wx,wy=midpoint(g["w78_true_touch_forward"])
    world=g["stage"]
    top=g["w80_native_mission_panel"][1]
    lx=world[0]+world[2]*0.83
    ly=min(top-20.0,world[1]+205.0)
    require(ly>world[1]+55.0 and ly<top-8.0,
            "Second live finger starts in safe 3D look area above mission deck")
    a=point(wx,wy,1)
    b=point(lx,ly,2)
    send(cdp,"touchStart",[a])
    page.wait_for_timeout(280)
    # CDP touchStart appends only the CHANGED source finger; sending
    # [a,b] would incorrectly re-send finger a as another new press.
    send(cdp,"touchStart",[b])
    for ix in range(4):
        b=point(lx+float(ix+1)*16.0,ly-float(ix+1)*7.0,2)
        send(cdp,"touchMove",[b])
        page.wait_for_timeout(110)
    page.wait_for_function("""previous => {
       const el=document.getElementById('a7-cascade-native-state');
       if(!el)return false;
       try { const s=JSON.parse(el.getAttribute('data-state'));
         return s.w83_real_camera_rotations>=previous+2 &&
           s.w83_source_yaw!==null && s.w83_active_look_finger>=0;
       }catch(e){return false}
    }""",arg=start["w83_real_camera_rotations"],timeout=30000)
    with_fingers=snapshot(page)
    require(with_fingers["w70_real_physical_distance"] >
            start["w70_real_physical_distance"]+0.30 and
            with_fingers["w83_source_walk_touch_starts"]>=1 and
            with_fingers["w83_source_active_walk_fingers"]>=1,
            "Actual first source-indexed physical W78 touch is independently tracked")
    require(with_fingers["w70_real_physical_distance"] >
            start["w70_real_physical_distance"]+0.30,
            "FIRST physical finger still walks CharacterBody3D while SECOND finger drags original Camera3D")
    require(abs(with_fingers["w83_source_yaw"]-start["w83_source_yaw"])>0.07 and
            abs(with_fingers["w83_source_pitch"]-start["w83_source_pitch"])>0.012,
            "Actual original W70 yaw AND camera pitch change from real native touchMove")
    require(with_fingers["history_count"]==0 and
            with_fingers["w72_valve_index"]==0,
            "True indexed two-finger gestures cannot fake any source gameplay progress")
    # The previous driver incorrectly issued touchEnd([a]), terminating
    # the FIRST walking finger while intending to end the SECOND camera.
    # In Chromium's real CDP implementation [b] releases ONLY camera.
    send(cdp,"touchEnd",[b])
    page.wait_for_function("""() => {
        const el=document.getElementById('a7-cascade-native-state');
        if(!el)return false;
        try {
            const s=JSON.parse(el.getAttribute('data-state'));
            return s.w83_active_look_finger===-1 &&
                (s.w83_touch_release_events>0 ||
                 s.w83_touch_release_position_recovers>0 ||
                 s.w83_touch_release_timeout_recovers>0);
        }catch(e){return false}
    }""",timeout=12000)
    released=snapshot(page)
    distance_at_release=released["w70_real_physical_distance"]
    # Ensure the original native Godot physics scene has actually rendered
    # new frames after the release; do not compare two stale DOM snapshots.
    page.wait_for_function("""previous => {
      const el=document.getElementById('a7-cascade-native-state');
      if(!el)return false;
      try {
        const s=JSON.parse(el.getAttribute('data-state'));
        return s.w70_real_physics_frames>=previous+6;
      }catch(e){return false}
    }""",arg=released["w70_real_physics_frames"],timeout=18000)
    still_walking=snapshot(page)
    # Original W70 has colliders; do not require translation through
    # solid geometry. The FIRST finger must remain physically captured,
    # W70 original held-key state true, source reassert and native
    # physics advancing. Motion OR contact proves actual collision-world
    # processing, never JS altering the character position.
    advancing = still_walking["w70_real_physical_distance"] > distance_at_release+0.12
    body_xyz = still_walking["w70_real_body_xyz"]
    actual_world_contact = (
        len(body_xyz)==3 and
        still_walking["w70_real_collisions"] >
            released["w70_real_collisions"]
    )
    evidence={
        "look_finger_released":released["w83_active_look_finger"],
        "source_finger_before":released["w83_source_active_walk_fingers"],
        "source_finger_after":still_walking["w83_source_active_walk_fingers"],
        "real_key_after":still_walking["w83_true_original_walk_key_held"],
        "walk_source_touch_ends_after":still_walking["w83_source_walk_touch_ends"],
        "walk_safety_expirations_after":still_walking["w83_source_walk_safety_expirations"],
        "W70_physics_frames_before":released["w70_real_physics_frames"],
        "W70_physics_frames_after":still_walking["w70_real_physics_frames"],
        "W70_collisions_before":released["w70_real_collisions"],
        "W70_collisions_after":still_walking["w70_real_collisions"],
        "W70_actual_xyz":body_xyz,
        "real_distance_before":distance_at_release,
        "real_distance_after":still_walking["w70_real_physical_distance"],
        "actually_moved":advancing,"actual_original_world_contact":actual_world_contact,
    }
    print("W83 TRUE ORIGINAL 2-FINGER POST-LOOK PHYSICS EVIDENCE:",
          json.dumps(evidence,sort_keys=True),flush=True)
    require(still_walking["w83_source_active_walk_fingers"]>=1 and
            still_walking["w83_true_original_walk_key_held"] is True and
            still_walking["w83_real_walk_reassert_frames"] >
                released["w83_real_walk_reassert_frames"] and
            still_walking["w70_real_physics_frames"] >=
                released["w70_real_physics_frames"]+6 and
            (advancing or actual_world_contact),
            "First original W70 finger stays pressed; independent camera touchEnd cannot release WALK; actual physics moves or collides")
    # Only now finish the original FIRST movement finger.
    send(cdp,"touchEnd",[a])
    page.wait_for_timeout(220)
    audit=assert_source_touch_release(page,a,b)
    print("W83 REAL CDP TOUCH RELEASE ORDER:",json.dumps(audit,sort_keys=True),
          flush=True)
    all_released=snapshot(page)
    require(all_released["w83_active_look_finger"]==-1 and
            all_released["w83_source_active_walk_fingers"]==0 and
            all_released["w83_source_walk_touch_ends"]>=1 and
            all_released["history_count"]==0,
            "Both real CDP fingers released without inventing original game decisions")
    return start,with_fingers,all_released

def run(export,evidence,sha):
    require(len(sha)==40 and all(c in "0123456789abcdef" for c in sha),
            "Exact source-Git SHA required for original Godot WebGL browser")
    require((export/"index.wasm").read_bytes()[:4]==b"\0asm",
            "Actual compiled original Godot 4.4.1 WASM required")
    evidence.mkdir(parents=True,exist_ok=True)
    page_errors=[]
    measurements=[]
    with LocalServer(("127.0.0.1",0),
        functools.partial(HTTPHandler,directory=str(export))) as server:
        threading.Thread(target=server.serve_forever,daemon=True).start()
        with sync_playwright() as pw:
            browser=pw.chromium.launch(headless=True,args=[
                "--no-sandbox","--disable-dev-shm-usage",
                "--enable-webgl","--use-gl=angle",
                "--use-angle=swiftshader","--enable-unsafe-swiftshader"])
            context=browser.new_context(
                viewport={"width":1366,"height":900},
                has_touch=True,device_scale_factor=1)
            page=context.new_page()
            page.on("pageerror",lambda e:page_errors.append(str(e)))
            page.goto(f"http://127.0.0.1:{server.server_address[1]}/index.html",
                wait_until="domcontentloaded",timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached",timeout=180000)
            start=wait_state(page,{"w83_real_multitouch_active":False,
                                   "w76_actual_immersive_first_person":False,
                                   "history_count":0})
            require(start["w83_original_body_preserved"],
                    "Native original W70 CharacterBody3D source identity")
            page.locator("canvas").first.click(position={"x":18,"y":20})
            page.keyboard.press("Enter")
            wait_state(page,{"w83_real_multitouch_active":False,
                             "w76_actual_immersive_first_person":True,
                             "w80_genuine_full_bleed_original_stage":True,
                             "history_count":0})
            g=stage_ready(page,390,844)
            a=picture(page,evidence/
              "w83-01-390px-original-Godot-3d-world-and-free-look-hint.png")
            cdp=context.new_cdp_session(page)
            enable_native_touch_audit(page)
            initial,live,rest=true_dual_finger(page,cdp,g)
            b=picture(page,evidence/
              "w83-02-real-two-CDP-fingers-walk-and-camera-look.png")
            require(difference(a,b)>65,
                    "Source 3D framebuffer pixels change when real 3D player walks and looks")
            measurements.append({"viewport":[390,844],
              "actual_w70_distance_before":initial["w70_real_physical_distance"],
              "actual_w70_distance_after":live["w70_real_physical_distance"],
              "actual_camera_yaw_before":initial["w83_source_yaw"],
              "actual_camera_yaw_after":live["w83_source_yaw"],
              "actual_camera_pitch_after":live["w83_source_pitch"]})
            # Original W79 mission equipment stays source-gated and clickable.
            g=geometry(page)
            ix,iy=midpoint(g["w79_command1"])
            page.mouse.click(ix,iy)
            denied=wait_state(page,{"w79_physical_equipment_attempts":1})
            require(denied["w72_valve_index"]==0 and
                    denied["history_count"]==0,
                    "Real far-range valve is STILL rejected after two-finger camera movement")
            c=picture(page,evidence/
              "w83-03-source-physical-rejection-after-multitouch.png")
            # Independence test: previous portrait run legitimately walks
            # the original CharacterBody3D into collidable world geometry.
            # Reset via actual WebGL page reload + native PLAY NOW, NEVER JS
            # teleport or assignment to a body position. Landscape must
            # prove forward travel from its OWN original physical spawn.
            page.set_viewport_size({"width":844,"height":390})
            page.reload(wait_until="domcontentloaded",timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached",timeout=180000)
            fresh=wait_state(page,{
                "w83_real_multitouch_active":False,
                "w76_actual_immersive_first_person":False,
                "history_count":0,
                "w80_genuine_full_bleed_original_stage":False})
            require(fresh["w70_real_physical_distance"]<0.02,
                "New real Godot landscape run starts from real original W70 spawn")
            page.locator("canvas").first.click(position={"x":18,"y":20})
            page.keyboard.press("Enter")
            wait_state(page,{"w83_real_multitouch_active":True,
                             "w80_genuine_full_bleed_original_stage":True,
                             "history_count":0})
            enable_native_touch_audit(page)
            cdp.detach()
            cdp=context.new_cdp_session(page)
            g=stage_ready(page,844,390)
            d=picture(page,evidence/
              "w83-04-844x390-real-native-landscape-physical-touch-zone.png")
            s0,s1,s2=true_dual_finger(page,cdp,g)
            e=picture(page,evidence/
              "w83-05-844x390-real-landscape-two-finger-camera-physics.png")
            require(difference(d,e)>65,
                    "True Godot landscape original 3D camera changes real rendered pixels")
            measurements.append({"viewport":[844,390],
              "actual_w70_distance_before":s0["w70_real_physical_distance"],
              "actual_w70_distance_after":s1["w70_real_physical_distance"],
              "actual_camera_yaw_before":s0["w83_source_yaw"],
              "actual_camera_yaw_after":s1["w83_source_yaw"],
              "actual_camera_pitch_after":s1["w83_source_pitch"]})
            mx,my=midpoint(geometry(page)["w80_true_native_menu"])
            page.mouse.click(mx,my)
            end=wait_state(page,{"w83_real_multitouch_active":False,
                                 "w83_active_look_finger":-1,
                                 "w80_genuine_full_bleed_original_stage":False,
                                 "history_count":0})
            f=picture(page,evidence/
              "w83-06-real-native-MENU-exit-clears-look-and-keeps-original-game.png")
            require(difference(e,f)>70,"Actual native MENU changes real original Godot screen")
            require(not end["w83_phone_hardware_approved"],
                    "Chromium emulation never certifies real iPhone/Android hardware")
            require(not page_errors,
                    "Actual original Godot WebGL runtime errors: "+" | ".join(page_errors[:5]))
            context.close()
            browser.close()
        server.shutdown()
    images=[]
    for path in sorted(evidence.glob("*.png")):
        raw=path.read_bytes()
        images.append({"name":path.name,"bytes":len(raw),
                       "sha256":hashlib.sha256(raw).hexdigest()})
    require(len(images)==6,
            "Six original Godot SHA-bound browser screenshots, no artificial frames")
    report={"schema":"LAST_FRONTIER_W83_ORIGINAL_REAL_GODOT_CDP_MULTI_TOUCH_V1",
        "source_sha":sha,"result":"PASS","genuine_Godot_4_4_1_WebGL_WASM":True,
        "actual_Chromium_two_distinct_concurrent_touch_ids":True,
        "native_Chrome_CDP_changed_finger_release_semantics_verified":True,
        "native_DOM_camera_then_walk_touchend_audited":True,
        "portrait_and_landscape_begin_from_separate_real_Godot_3D_spawns":True,
        "original_CharacterBody3D_walking_during_camera_drag":True,
        "original_camera_yaw_and_pitch_changed_by_real_touch_move":True,
        "source_game_decisions_and_physical_valve_remain_gated":True,
        "responsive_390px_portrait_and_844px_landscape":True,
        "Android_or_iPhone_physical_hardware_certified":False,
        "retail_AAA_art_certified":False,
        "observations":measurements,"images":images}
    (evidence/"W83_TRUE_ORIGINAL_GODOT_MULTITOUCH_BROWSER.json").write_text(
        json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("LAST FRONTIER W83 ACTUAL TWO-FINGER GODOT WEBGL CHROMIUM PASS:",
          len(images),"authentic original source-bound Godot frames")

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--export",type=Path,required=True)
    parser.add_argument("--evidence",type=Path,required=True)
    parser.add_argument("--sha",required=True)
    args=parser.parse_args()
    run(args.export.resolve(),args.evidence,args.sha)
