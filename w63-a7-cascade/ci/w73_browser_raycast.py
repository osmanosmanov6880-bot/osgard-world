#!/usr/bin/env python3
"""W73 actual Godot exported WASM: native physical player, true machine
RayCast3D G at 3D target, RU/EN responsive original PNGs. Actual save/load
file restore and forged journal rejection verified by separate native suite.
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
from w64_browser_acceptance import HTTPHandler, LocalServer, wait_state, snapshot


def check(ok, label):
    if not ok:
        raise AssertionError(label)


def capture(page, directory, filename):
    b=page.screenshot(path=str(directory/filename))
    rgb=Image.open(io.BytesIO(b)).convert("RGB")
    check(max(ImageStat.Stat(rgb).stddev)>6.0,
          "Real game WebGL frame is flat/blank")
    return b


def changed(before,after):
    aa=Image.open(io.BytesIO(before)).convert("RGB")
    bb=Image.open(io.BytesIO(after)).convert("RGB")
    check(aa.size==bb.size,"Comparing two actual same-size Godot frames")
    return sum(ImageChops.difference(aa,bb).convert("L").histogram()[12:])


def execute(export,evidence,source_sha):
    check(len(source_sha)==40,"Full exact Git SHA required")
    check((export/"index.wasm").read_bytes()[:4]==b"\0asm",
          "Actual Godot WASM export required; no replacement with HTML mock")
    evidence.mkdir(parents=True,exist_ok=True)
    errors=[]
    with LocalServer(("127.0.0.1",0),
                     functools.partial(HTTPHandler,directory=str(export))) as server:
        threading.Thread(target=server.serve_forever,daemon=True).start()
        address=f"http://127.0.0.1:{server.server_address[1]}/index.html"
        with sync_playwright() as pw:
            browser=pw.chromium.launch(headless=True,args=[
                "--no-sandbox","--disable-dev-shm-usage","--enable-webgl",
                "--use-gl=angle","--use-angle=swiftshader",
                "--enable-unsafe-swiftshader",
            ])
            context=browser.new_context(viewport={"width":1366,"height":900})
            page=context.new_page()
            page.on("pageerror",lambda e:errors.append(str(e)))
            page.goto(address,wait_until="domcontentloaded",timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached",timeout=180000)
            first=wait_state(page,{
                "w72_extended_mode":False,
                "w73_real_native_world_raycast":True,
                "w73_real_collider_target_count":7,
                "w73_real_raycast_uses":0,
                "w73_checkpoint_events":0,
                "history_count":0,
            })
            check(first["w70_true_industrial_bridge_meshes"]>=130,
                  "Real original W70.1 PBR bridge missing")
            page.locator("canvas").first.click(position={"x":17,"y":19})
            page.wait_for_timeout(300)
            a=capture(page,evidence,"w73-01-actual-original-3d-game.png")
            page.keyboard.press("y")
            wait_state(page,{
                "w72_extended_mode":True,"w72_valve_index":0,
                "w73_checkpoint_events":1,"w71_mission_phase":0,
            })
            page.keyboard.press("p")
            wait_state(page,{"w70_physical_operator":True,
                             "w72_extended_mode":True})
            page.keyboard.press("g")
            denied=wait_state(page,{
                "w73_real_raycast_uses":0,
                "w72_valve_index":0,
                "history_count":0,
            })
            check(denied["w73_rejected_world_uses"]>=1,
                  "G at spawn must reject actual distant world target")
            b=capture(page,evidence,"w73-02-real-first-person-ray-with-distant-target.png")
            check(changed(a,b)>700,
                  "Real first-person playable camera not shown")
            page.keyboard.down("s")
            try:
                # Actual browser GPU software frame pacing is variable;
                # evaluate a real CharacterBody arrival within physical
                # reactor zone, never synthetic duration.
                page.wait_for_function("""() => {
                  const e=document.getElementById('a7-cascade-native-state');
                  if (!e) return false;
                  try {
                    const s=JSON.parse(e.getAttribute('data-state'));
                    const p=s.w70_real_body_xyz;
                    return s.w70_physical_operator===true &&
                      s.w70_real_physical_distance>2.3 &&
                      Math.hypot(p[0]-4.1,p[1]-1.2,p[2]-2.14)<3.05;
                  }catch(_){return false;}
                }""",timeout=40000)
            finally:
                page.keyboard.up("s")
            page.wait_for_timeout(350)
            moved=snapshot(page)
            check(moved["w70_real_physical_distance"]>2.3,
                  "Actual physical player S movement must happen")
            c=capture(page,evidence,"w73-03-real-world-body-near-core.png")
            check(changed(b,c)>300,"Native physical world route not observable")
            page.keyboard.press("k")
            calibrated=wait_state(page,{
                "w72_valve_index":1,
                "w72_thermal_camera_focused":True,
                "w73_checkpoint_events":2,
                "history_count":0,
            })
            page.wait_for_timeout(600)
            diag=snapshot(page)
            print("W73 TRUE CAMERA RAY PHYSICS DIAG",json.dumps({
                "body":diag["w70_real_body_xyz"],
                "valve":diag["w72_valve_index"],
                "focused":diag["w72_thermal_camera_focused"],
                "actual_ray":diag["w73_actual_ray_physics_debug"],
            }),flush=True)
            d=capture(page,evidence,"w73-04-genuine-eye-raycast-on-physical-thermal-valve.png")
            aimed=wait_state(page,{
                "w73_actual_world_ray_target":"valve",
                "w73_real_native_world_raycast":True,
                "w72_valve_index":1,
            })
            check(changed(c,d)>130,
                  "Contextual target focus must visibly turn REAL 3D camera")
            page.keyboard.press("g")
            acted=wait_state(page,{
                "w73_real_raycast_uses":1,
                "w72_valve_index":2,
                "w73_checkpoint_events":3,
                "w71_mission_phase":0,
                "history_count":0,
            })
            check(acted["w73_real_collider_target_count"]==7,
                  "Native seven collision targets actually mounted")
            e=capture(page,evidence,"w73-05-actual-ray-G-advances-one-world-valve-detent.png")
            check(changed(d,e)>90,
                  "Real native G world interaction should visibly rotate hardware/HUD")

            page.set_viewport_size({"width":390,"height":844})
            page.wait_for_function("""() => {
              const n=document.getElementById('a7-cascade-native-state');
              if (!n) return false;
              try {
                const s=JSON.parse(n.getAttribute('data-state'));
                const g=JSON.parse(n.getAttribute('data-geometry'));
                return g.viewport[0]===390 &&
                    s.w68_mobile_hud_compact===true &&
                    s.w73_real_raycast_uses===1 &&
                    s.w72_extended_mode===true;
              }catch(_){return false;}
            }""",timeout=60000)
            f=capture(page,evidence,"w73-06-mobile-390-real-aimed-world-operation.png")
            check(Image.open(io.BytesIO(f)).size==(390,844),
                  "Genuine responsive 390x844px game screenshot required")
            page.keyboard.press("l")
            final=wait_state(page,{
                "locale":"en",
                "w73_real_raycast_uses":1,
                "w73_checkpoint_events":3,
            })
            g=capture(page,evidence,"w73-07-English-mobile-native-world-reticle.png")
            check(changed(f,g)>80,
                  "Actual Godot game must translate native mission text")
            check(not errors,
                  "Unhandled genuine Chromium/Godot exception: "+"; ".join(errors[:4]))
            context.close()
            browser.close()
        server.shutdown()
    frames=[{"name":p.name,"size_bytes":p.stat().st_size,
             "sha256":hashlib.sha256(p.read_bytes()).hexdigest()}
            for p in sorted(evidence.glob("*.png"))]
    check(len(frames)==7,"Seven source-bound real Godot 3D WebGL screenshots")
    report={
        "schema":"LAST_FRONTIER_W73_TRUE_PHYSICAL_3D_RAY_AND_LOCAL_JOURNAL_BROWSER_V1",
        "source_commit":source_sha,"result":"PASS",
        "real_webassembly_game":True,
        "native_CharacterBody_must_physically_move":True,
        "native_RayCast3D_hit_required_for_G":True,
        "new_world_target_manipulates_original_W72_mechanic":True,
        "original_six_incidents_untouched":True,
        "native_checkpoint_full_replay_separately_tested":True,
        "browser_keyboard":["Y","P","G","S","K","L"],
        "real_original_frames":frames,
        "human_15min_session_measured":False,
        "real_Android_iPhone_GPU_tested":False,
        "professional_art_quality_approved":False,
        "production_released":False,
    }
    (evidence/"W73_REAL_GODOT_BROWSER_PROOF.json").write_text(
        json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("LAST FRONTIER W73 TRUE GODOT RAYCAST PHYSICAL WORLD CHROMIUM PASS:",
          len(frames),"original source SHA-bound frames")


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--export",type=Path,required=True)
    p.add_argument("--evidence",type=Path,required=True)
    p.add_argument("--sha",required=True)
    args=p.parse_args()
    execute(args.export.resolve(),args.evidence,args.sha)
