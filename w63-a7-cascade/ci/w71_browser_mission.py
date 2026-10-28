#!/usr/bin/env python3
"""W71 genuine browser game: start story, physically reach reactor, inspect,
make two original decisions, see relay objective. Source-bound Godot screenshots.
The native Godot suite separately proves the entire 5-objective victory/loss.
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


def require(value, label):
    if not value:
        raise AssertionError(label)


def png(page, out, name):
    result=page.screenshot(path=str(out/name))
    image=Image.open(io.BytesIO(result)).convert("RGB")
    require(max(ImageStat.Stat(image).stddev)>6,
            "Actual Godot game did not produce visible pixels")
    return result


def contrast(a, b):
    aa=Image.open(io.BytesIO(a)).convert("RGB")
    bb=Image.open(io.BytesIO(b)).convert("RGB")
    require(aa.size==bb.size,"Visually compared original frames must match")
    diff=ImageChops.difference(aa,bb).convert("L")
    return sum(diff.histogram()[12:])


def run(export, out, sha):
    require(len(sha)==40 and all(x in "0123456789abcdef" for x in sha),
            "Pinned Git SHA required")
    require((export/"index.wasm").read_bytes()[:4]==b"\0asm",
            "Actual playable Godot WebAssembly export required")
    out.mkdir(parents=True,exist_ok=True)
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
            page.on("pageerror",lambda err:errors.append(str(err)))
            page.goto(address,wait_until="domcontentloaded",timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached",timeout=180000)
            boot=wait_state(page,{
                "status":"playing","shift":0,"history_count":0,
                "w70_physical_operator":False,
                "w71_mission_active":False,
                "w71_real_3d_mission":True,
                "w71_mission_events":0,
            })
            require(boot["w70_true_industrial_bridge_meshes"]>=130,
                    "Accepted W70.1 physical art absent in W71")
            canvas=page.locator("canvas").first
            require(canvas.count()==1,"Original Godot WebGL canvas missing")
            canvas.click(position={"x":17,"y":19})
            page.wait_for_timeout(280)
            baseline=png(page,out,"w71-01-original-real-world-with-physical-mission.png")

            # A story starts via genuine keyboard input only, never DOM writer.
            page.keyboard.press("t")
            started=wait_state(page,{
                "w71_mission_active":True,
                "w71_mission_phase":0,
                "w71_mission_events":0,
                "history_count":0,
            })
            require(started["metrics"]["heat"]==62,
                    "Opening a fictional mission changed original heat")
            page.keyboard.press("p")
            operator=wait_state(page,{
                "w70_physical_operator":True,
                "w71_mission_phase":0,"history_count":0,
            })
            # E at spawn is too far from reactor. It must not award a badge.
            page.keyboard.press("e")
            far=wait_state(page,{"w71_mission_phase":0,
                                  "w71_mission_physical_inspections":0})
            require(far["history_count"]==0,
                    "Distant E trigger altered true core game")
            page.wait_for_timeout(320)
            spawn=png(page,out,"w71-02-real-first-person-with-locked-reactor-objective.png")
            require(contrast(baseline,spawn)>750,
                    "Native physics player was not activated")

            # Physically walk back toward original reactor, no teleports or
            # writing to the passive DOM status. Coordinates are hidden from
            # script and can only change by authentic Godot physics.
            begin_z=float(snapshot(page)["w70_real_body_xyz"][2])
            page.keyboard.down("s")
            page.wait_for_timeout(1430)
            page.keyboard.up("s")
            page.wait_for_timeout(350)
            walked=snapshot(page)
            print("W71 ACTUAL S PHYSICS DEBUG",json.dumps({
                "spawn_z":begin_z,
                "actual_body":walked["w70_real_body_xyz"],
                "actual_path_m":walked["w70_real_physical_distance"],
                "physics_frames":walked["w70_real_physics_frames"],
                "pilot_active":walked["w70_physical_operator"],
                "mission_phase":walked["w71_mission_phase"],
            }),flush=True)
            require(walked["w70_physical_operator"],
                    "Held S cannot exit real physical player mode")
            require(walked["w70_real_physical_distance"]>2.1,
                    "Actual S character walk did not move real physics body")
            require(walked["history_count"]==0 and walked["w71_mission_phase"]==0,
                    "Walking by itself is neither an inspection nor a core decision")
            approach=png(page,out,"w71-03-real-physical-walk-to-reactor.png")
            require(contrast(spawn,approach)>500,
                    "Original core approach didn't change live Godot scene")
            page.keyboard.press("e")
            inspected=wait_state(page,{
                "w71_mission_phase":1,
                "w71_mission_events":1,
                "w71_mission_physical_inspections":1,
                "history_count":0,
            })
            require(inspected["metrics"]["heat"]==62,
                    "Genuine spatial reactor E inspection must not act as PUMP")
            page.wait_for_timeout(250)
            core=png(page,out,"w71-04-real-godot-inspected-core-objective.png")

            page.keyboard.press("1")
            pump=wait_state(page,{
                "w71_mission_phase":1,
                "w71_mission_actions":1,
                "history_count":1,
            })
            require(pump["metrics"]["heat"]==42 and pump["metrics"]["energy"]==79,
                    "Original six-cycle A7 PUMP tradeoff modified")
            page.keyboard.press("4")
            first=wait_state(page,{
                "w71_mission_phase":2,
                "w71_mission_events":2,
                "w71_mission_actions":2,
                "history_count":2,
                "shift":1,
            })
            require(first["metrics"]["heat"]==59 and first["metrics"]["signal"]==61,
                    "First original incident did not resolve as in accepted W70")
            page.wait_for_timeout(350)
            relay_objective=png(page,out,"w71-05-second-real-sector-unlocked-after-cycle.png")
            require(contrast(core,relay_objective)>120,
                    "Genuine new mission goal did not change native 3D/UI at all")
            require(first["w71_mission_phase"]==2,
                    "Story must demand physically reaching second sector next")

            # Real phone screenshot keeps original 390px independent buttons
            # and new mission label. No fake mobile screenshot substitution.
            page.set_viewport_size({"width":390,"height":844})
            page.wait_for_function("""() => {
                const element=document.getElementById('a7-cascade-native-state');
                if (!element) return false;
                try {
                    const d=JSON.parse(element.getAttribute('data-state'));
                    const g=JSON.parse(element.getAttribute('data-geometry'));
                    return g.viewport[0]<=420 &&
                        g.stage_requested_height<=310 &&
                        d.w71_mission_active===true &&
                        d.w71_mission_phase===2 &&
                        d.w68_mobile_hud_compact===true &&
                        d.w67_mobile_world_text_hidden===true;
                }catch(e){return false;}
            }""",timeout=60000)
            phone=png(page,out,"w71-06-real-mobile-390-mission-and-game.png")
            require(Image.open(io.BytesIO(phone)).size==(390,844),
                    "Original real phone WebGL proof dimensions wrong")
            page.keyboard.press("l")
            translated=wait_state(page,{"locale":"en",
                                        "w71_mission_phase":2,
                                        "history_count":2})
            require(translated["w71_mission_active"],
                    "Changing language cannot reset physical story")
            english=png(page,out,"w71-07-English-mobile-objective.png")
            require(contrast(phone,english)>90,
                    "RU to EN in real Godot game had no visible visual/text difference")
            page.keyboard.press("p")
            wait_state(page,{"w70_physical_operator":False,
                              "w71_mission_phase":2,
                              "history_count":2})
            require(not errors,"Unhandled real browser engine exception: "+
                    " | ".join(errors[:6]))
            context.close()
            browser.close()
        server.shutdown()
    images=[]
    for item in sorted(out.glob("*.png")):
        images.append({"file":item.name,"sha256":hashlib.sha256(item.read_bytes()).hexdigest(),
                       "bytes":item.stat().st_size})
    require(len(images)==7,"Seven original Chromium A7 source-bound frames required")
    proof={
        "schema":"LAST_FRONTIER_W71_TRUE_SPATIAL_MISSION_CHROMIUM_V1",
        "status":"PASS","source_sha":sha,
        "real_exported_godot_webassembly":True,
        "native_keyboard_input":["T","P","E","S","1","4","L"],
        "real_collision_character_physics":True,
        "far_E_does_not_progress":True,
        "near_reactor_E_advances":True,
        "real_first_shift_game_decisions":2,
        "next_objective_is_real_relay_sector":True,
        "phone_viewport": [390,844],
        "real_browser_screenshots":images,
        "complete_five_stage_mission_verified_in_native_suite":True,
        "claimed_measured_15_min_gameplay":False,
        "production_approved":False,
        "consumer_mobile_gpu_certified":False,
        "human_art_approved":False,
    }
    (out/"W71_ACTUAL_SPATIAL_BROWSER_PROOF.json").write_text(
        json.dumps(proof,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("LAST FRONTIER W71 GENUINE GODOT SPATIAL MISSION CHROMIUM PASS:",
          len(images),"source-bound physical in-game objective frames")


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--export",type=Path,required=True)
    parser.add_argument("--evidence",type=Path,required=True)
    parser.add_argument("--sha",required=True)
    args=parser.parse_args()
    run(args.export.resolve(),args.evidence,args.sha)
