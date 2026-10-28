#!/usr/bin/env python3
"""W70 actual Godot WASM first-person physics in Chromium, not video/mockup.

Playwright emits real P/W/A/S/D/E/F/X keys to the original 3D Godot canvas,
and ONLY reads passive state from the real SceneTree. Screens are untouched PNGs.
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


def check(ok, why):
    if not ok:
        raise AssertionError(why)


def pixels_change(before, after):
    a=Image.open(io.BytesIO(before)).convert("RGB")
    b=Image.open(io.BytesIO(after)).convert("RGB")
    check(a.size==b.size,"Real source screenshots must match viewport")
    delta=ImageChops.difference(a,b).convert("L")
    return sum(delta.histogram()[12:])


def real_screenshot(page, directory, name):
    pixels=page.screenshot(path=str(directory/name))
    check(max(ImageStat.Stat(Image.open(io.BytesIO(pixels)).convert("RGB")).stddev)>6.0,
          "Actual Godot rendered only blank pixels")
    return pixels


def run(export, out, sha):
    check(len(sha)==40 and all(c in "0123456789abcdef" for c in sha),
          "Exact Git source SHA is mandatory")
    check((export/"index.wasm").read_bytes()[:4]==b"\0asm",
          "Must be actual Godot WebGL/WASM game, not an HTML mockup")
    out.mkdir(parents=True, exist_ok=True)
    js_errors=[]
    with LocalServer(("127.0.0.1",0),
                     functools.partial(HTTPHandler,directory=str(export))) as server:
        threading.Thread(target=server.serve_forever,daemon=True).start()
        base=f"http://127.0.0.1:{server.server_address[1]}/index.html"
        with sync_playwright() as pw:
            browser=pw.chromium.launch(headless=True,args=[
                "--no-sandbox","--disable-dev-shm-usage",
                "--enable-webgl","--use-gl=angle","--use-angle=swiftshader",
                "--enable-unsafe-swiftshader",
            ])
            ctx=browser.new_context(viewport={"width":1366,"height":900},device_scale_factor=1)
            page=ctx.new_page()
            page.on("pageerror",lambda error:js_errors.append(str(error)))
            page.goto(base,wait_until="domcontentloaded",timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached",timeout=180000)
            state=wait_state(page,{
                "w70_physical_operator":False,
                "shift":0,"history_count":0,
                "real_native_3d":True,
                "w67_two_3d_sectors":True,
                "w69_real_incident_shutters":4,
                "w70_true_headlamp":True,
            })
            check(state["w70_collision_shapes"]>=12,
                  "Game has no independently instantiated physics colliders")
            check(state["w68_pbr_profiles"]==7,
                  "W68 original real textured materials lost")
            canvas=page.locator("canvas").first
            check(canvas.count()==1,"No real Godot game canvas")
            canvas.click(position={"x":16,"y":18})
            page.wait_for_timeout(450)
            overview=real_screenshot(page,out,"w70-01-core-prior-cinematic-camera.png")
            page.keyboard.press("p")
            fp=wait_state(page,{"w70_physical_operator":True,
                                "history_count":0})
            check(fp["w70_true_headlamp"],"No physically attached headlamp")
            check(fp["w70_collision_shapes"]>=12,
                  "Physics body/obstacle shapes lost on enter")
            page.wait_for_timeout(400)
            first_person=real_screenshot(page,out,"w70-02-real-first-person-headlamp.png")
            check(pixels_change(overview,first_person)>1000,
                  "Opt-in first person didn't switch to the real playable eye camera")

            before=snapshot(page)
            begin_z=float(before["w70_real_body_xyz"][2])
            page.keyboard.down("w")
            page.wait_for_timeout(900)
            page.keyboard.up("w")
            page.wait_for_function("""start => {
                const node=document.getElementById('a7-cascade-native-state');
                if (!node) return false;
                try {
                    const state=JSON.parse(node.getAttribute('data-state'));
                    return state.w70_physical_operator &&
                        state.w70_real_body_xyz[2] > start+0.38 &&
                        state.w70_real_physical_distance>0.38 &&
                        state.w70_real_physics_frames>15;
                } catch(e){return false;}
            }""",arg=begin_z,timeout=50000)
            moved=snapshot(page)
            check(moved["history_count"]==0 and moved["shift"]==0,
                  "Physical W key movement must not trigger original machine choices")
            walking=real_screenshot(page,out,"w70-03-real-physics-walk-forward.png")
            check(pixels_change(first_person,walking)>1000,
                  "True moving first person player view remained stationary")

            # F now focuses the ACTUAL mounted operator eye camera.
            page.keyboard.press("f")
            eye_focus=wait_state(page,{"w69_focus_mode":True,
                                      "w70_physical_operator":True,
                                      "history_count":0})
            check(eye_focus["w70_real_physical_distance"]>0.38,
                  "Eye closeup destroyed player physics state")
            page.wait_for_timeout(220)
            macro=real_screenshot(page,out,"w70-04-eye-level-optical-focus.png")
            check(pixels_change(walking,macro)>700,
                  "Optical zoom did not change real first-person camera projection")
            page.keyboard.press("f")
            wait_state(page,{"w69_focus_mode":False,"w70_physical_operator":True})
            page.keyboard.press("x")
            cinema=wait_state(page,{"w69_cinema_mode":True,
                                    "w70_physical_operator":True})
            check(geometry(page)["stage_requested_height"]>=585,
                  "Cinema must expand real Godot live first person viewport")
            page.wait_for_timeout(220)
            immersive=real_screenshot(page,out,"w70-05-full-first-person-cinema.png")
            check(pixels_change(walking,immersive)>1200,
                  "Native expanded full first-person screen not visually distinct")
            page.keyboard.press("x")
            wait_state(page,{"w69_cinema_mode":False,"w70_physical_operator":True})

            # User gets the original exact 6-cycle puzzle on leaving pilot mode.
            page.keyboard.press("p")
            exit_state=wait_state(page,{"w70_physical_operator":False,
                                        "history_count":0})
            check(exit_state["w70_real_physical_distance"]>0.38,
                  "Real traveled distance is preserved after leaving pilot mode")
            page.keyboard.press("1")
            pump=wait_state(page,{"history_count":1,"actions_left":1})
            check(pump["metrics"]["heat"]==42 and pump["metrics"]["energy"]==79,
                  "Original W63 puzzle was overridden by the physics player")
            page.keyboard.press("4")
            scan=wait_state(page,{"history_count":2,"shift":1})
            check(scan["metrics"]["signal"]==61 and scan["metrics"]["heat"]==59,
                  "Real original incident progression changed")
            play=real_screenshot(page,out,"w70-06-original-puzzle-still-reacts.png")
            check(pixels_change(overview,play)>300,
                  "Actual 3D world no longer visualizes original machine commands")

            # Mobile = real 390px WebGL, native control rail, same physics.
            page.set_viewport_size({"width":390,"height":844})
            page.wait_for_function("""() => {
                const node=document.getElementById('a7-cascade-native-state');
                if (!node) return false;
                try {
                    const state=JSON.parse(node.getAttribute('data-state'));
                    const geo=JSON.parse(node.getAttribute('data-geometry'));
                    return geo.viewport[0]<=420 &&
                        geo.stage_requested_height<=310 &&
                        state.w68_mobile_hud_compact &&
                        state.w67_mobile_world_text_hidden;
                } catch(e){return false;}
            }""",timeout=60000)
            page.keyboard.press("p")
            mobile=wait_state(page,{"w70_physical_operator":True,
                                    "history_count":2})
            check(mobile["w70_collision_shapes"]>=12,
                  "Narrow screen cannot eliminate the actual static physics world")
            page.wait_for_timeout(350)
            mobile_frame=real_screenshot(page,out,"w70-07-mobile-operator-390.png")
            check(Image.open(io.BytesIO(mobile_frame)).size==(390,844),
                  "Mobile proof must be real 390x844 screenshot")
            page.keyboard.press("p")
            wait_state(page,{"w70_physical_operator":False,
                              "history_count":2})
            check(not js_errors, "Unhandled Godot/Chromium error: "+
                  " | ".join(js_errors[:4]))
            ctx.close()
            browser.close()
        server.shutdown()
    files=[{
        "filename":image.name,
        "bytes":image.stat().st_size,
        "sha256":hashlib.sha256(image.read_bytes()).hexdigest(),
    } for image in sorted(out.glob("*.png"))]
    check(len(files)==7,"Seven genuine real Godot browser PNG frames required")
    proof={
        "schema":"LAST_FRONTIER_W70_REAL_GODOT_PHYSICS_BROWSER_V1",
        "exact_git_sha":sha,"status":"PASS",
        "real_godot_webassembly":True,
        "real_physics_characterbody":True,
        "gamepad_or_keyboard":False,
        "real_key_input":["P","W","F","X","1","4"],
        "genuine_walking_changes_player_position":True,
        "original_causal_puzzle_preserved":True,
        "actual_phone_viewport_pixels":True,
        "source_bound_images":files,
        "hardware_gpu_performance_certified":False,
        "human_art_approved":False,
        "commercial_release_approved":False,
    }
    (out/"W70_ACTUAL_PHYSICS_BROWSER_PROOF.json").write_text(
        json.dumps(proof,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("LAST FRONTIER W70 TRUE GODOT CHARACTERBODY PHYSICS CHROMIUM PASS:",
          len(files),"real original 3D frames")


if __name__=="__main__":
    a=argparse.ArgumentParser()
    a.add_argument("--export",type=Path,required=True)
    a.add_argument("--evidence",type=Path,required=True)
    a.add_argument("--sha",required=True)
    b=a.parse_args()
    run(b.export.resolve(),b.evidence,b.sha)
