#!/usr/bin/env python3
"""W67 real export + Chromium first-person Godot keyboard, not a fake scene.

Actions must enter the original native Control keyboard path. The optional
read-only Godot DOM state makes assertions observable but never issues input.
"""
import argparse
import functools
import hashlib
import json
import re
import threading
from pathlib import Path
from PIL import Image
from playwright.sync_api import sync_playwright
from w64_browser_acceptance import HTTPHandler, LocalServer, wait_state, snapshot


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def wait_sector(page, sector):
    page.wait_for_function("""target => {
        const e=document.getElementById('a7-cascade-native-state');
        if (!e || !e.getAttribute('data-state')) return false;
        try {
            const s=JSON.parse(e.getAttribute('data-state'));
            return s.walk_mode===true && s.operator_sector===target;
        } catch (_){return false;}
    }""", arg=sector, timeout=45000)
    return snapshot(page)


def drive(page, key, millis=1550):
    # This is the real browser keyboard, not direct invocation of Godot model.
    page.keyboard.down(key)
    page.wait_for_timeout(millis)
    page.keyboard.up(key)
    page.wait_for_timeout(210)
    return snapshot(page)


def run(export, evidence, exact_sha):
    require(re.fullmatch("[0-9a-f]{40}", exact_sha or "") is not None,
            "W67 exact Git commit hash required")
    evidence.mkdir(parents=True, exist_ok=True)
    require((export / "index.wasm").read_bytes()[:4] == b"\0asm",
            "True Godot wasm code missing")
    with LocalServer(("127.0.0.1", 0),
                     functools.partial(HTTPHandler, directory=str(export))) as http:
        threading.Thread(target=http.serve_forever, daemon=True).start()
        url=f"http://127.0.0.1:{http.server_address[1]}/index.html"
        failures=[]
        with sync_playwright() as playwright:
            browser=playwright.chromium.launch(
                headless=True, args=[
                    "--no-sandbox", "--disable-dev-shm-usage", "--enable-webgl",
                    "--use-gl=angle", "--use-angle=swiftshader",
                    "--enable-unsafe-swiftshader",
                ])
            context=browser.new_context(viewport={"width":1366,"height":900},
                                        device_scale_factor=1)
            page=context.new_page()
            page.on("pageerror",lambda error: failures.append(str(error)))
            page.goto(url,wait_until="domcontentloaded",timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(
                state="attached",timeout=180000)
            first=wait_state(page,{"shift":0,"actions_left":2,
                                   "walk_mode":False,"history_count":0,
                                   "operator_sector":"central"})
            require(first["walk_physics_colliders"]==5,
                    "Five native Godot StaticBody3D colliders absent")
            require(first["real_native_3d"] and first["scene_meshes"] >= 75,
                    "Real W66 world not rendered by actual Godot")
            page.locator("canvas").first.click(position={"x":25,"y":25})
            page.keyboard.press("f")
            first=wait_state(page,{"walk_mode":True,"history_count":0})
            require(first["operator_sector"]=="central" and
                    first["operator_context_action"]=="SCAN",
                    "Actual operator not in first-person central sector")
            walk_photo=page.screenshot(
                path=str(evidence/"w67-first-person-desktop.png"))
            require(len(walk_photo)>12_000,"No first-person native WebGL screenshot")

            # Move to the physical coolant bay, select console E.
            left=drive(page,"a",1650)
            require(left["walk_mode"] and left["operator_position"][0]<-3.0,
                    "Actual WASD input did not move the CharacterBody3D left")
            require(left["operator_travel_metres"]>3.0,
                    "Physics traversal was not recorded")
            cool=wait_sector(page,"coolant")
            require(cool["operator_context_action"]=="PUMP",
                    "Coolant bay does not expose the original PUMP action")
            page.keyboard.press("e")
            changed=wait_state(page,{"history_count":1,"actions_left":1})
            require(changed["metrics"]["heat"]==42 and changed["shift"]==0,
                    "Coolant console didn't execute actual W63 resource move")
            require(changed["operator_sector"]=="coolant",
                    "Console unexpectedly teleported physical player")
            page.screenshot(path=str(evidence/"w67-coolant-console-reactive.png"))

            # Real restart must not fabricate actions; it recenters the rig.
            page.keyboard.press("r")
            restarted=wait_state(page,{"history_count":0,"shift":0,
                                       "operator_sector":"central"})
            require(abs(restarted["operator_position"][0])<0.1,
                    "Restart did not recenter true first-person character")
            require(restarted["metrics"]["heat"]==62,
                    "Original W63 deterministic restart lost")
            right=drive(page,"d",1650)
            require(right["operator_position"][0]>3.0,
                    "Right direction failed to traverse to pressure bay")
            press=wait_sector(page,"pressure")
            require(press["operator_context_action"]=="SEAL",
                    "Pressure room must select original SEAL instead of PUMP")
            page.keyboard.press("e")
            changed=wait_state(page,{"history_count":1,"actions_left":1})
            require(changed["metrics"]["seal"]==92,
                    "Pressure console did not apply real SEAL +24")
            require(changed["metrics"]["heat"]==62,
                    "Pressure console affected an unrelated game metric")
            page.screenshot(path=str(evidence/"w67-pressure-console-reactive.png"))

            page.keyboard.press("l")
            localized=wait_state(page,{"locale":"en","walk_mode":True})
            require(localized["history_count"]==1,
                    "RU/EN switch cannot mutate original mechanics")
            page.keyboard.press("q")
            eco=wait_state(page,{"quality":"eco","walk_mode":True})
            require(eco["history_count"]==1,"ECO cannot alter game")
            page.keyboard.press("f")
            ordinary=wait_state(page,{"walk_mode":False,"history_count":1})
            require(ordinary["shift"]==0,"Exiting first-person mode altered history")

            page.set_viewport_size({"width":390,"height":844})
            page.wait_for_function("""() => {
                const e=document.getElementById('a7-cascade-native-state');
                if(!e)return false;
                try{
                    const g=JSON.parse(e.getAttribute('data-geometry'));
                    return g.viewport[0]<=420 &&
                           g.stage_requested_height<=310;
                }catch(_){return false;}
            }""",timeout=60000)
            page.keyboard.press("f")
            mobile=wait_state(page,{"walk_mode":True,"locale":"en"})
            require(mobile["history_count"]==1 and
                    mobile["operator_sector"]=="pressure",
                    "Mobile viewport should preserve first-person position")
            png=page.screenshot(path=str(evidence/"w67-390px-mobile-operator.png"))
            with Image.open(evidence/"w67-390px-mobile-operator.png") as shot:
                require(shot.size==(390,844),
                        "Original mobile viewport screenshot incorrect")
            require(len(png)>12_000,
                    "Mobile real Godot WebGL screenshot missing pixels")
            page.keyboard.press("f")
            exited=wait_state(page,{"walk_mode":False})
            require(exited["history_count"]==1,
                    "Exiting operator mode consumed an unrequested game action")
            context.close()
            browser.close()
        http.shutdown()
    require(not failures,"Uncaught Godot/JavaScript errors: "+repr(failures[:5]))
    pictures=[{
        "filename":path.name,
        "sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
        "bytes":path.stat().st_size,
    } for path in sorted(evidence.glob("*.png"))]
    require(len(pictures)==4,"Four authentic 3D first-person screenshots required")
    report={
        "schema":"LAST_FRONTIER_W67_NATIVE_FIRST_PERSON_BROWSER_V1",
        "status":"PASS","exact_source_sha":exact_sha,
        "real_godot_character_body":True,
        "actual_chromium_keyboard_actions":True,
        "actual_sector_walk_coolant_pressure":True,
        "original_game_model_used":True,
        "actual_w67_3d_webgl":True,
        "mobile_390_is_browser_emulation_only":True,
        "real_consumer_gpu_certified":False,
        "real_mobile_device_certified":False,
        "production_approved":False,
        "public_deployment":False,
        "screenshots":pictures,
    }
    (evidence/"W67_ACTUAL_OPERATOR_CHROMIUM.json").write_text(
        json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("LAST FRONTIER W67 TRUE FIRST PERSON GODOT CHROMIUM WALK / "
          "TWO PHYSICAL CONSOLES PASS:",len(pictures),"original PNGs")


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--export",type=Path,required=True)
    p.add_argument("--evidence",type=Path,required=True)
    p.add_argument("--sha",required=True)
    a=p.parse_args()
    run(a.export.resolve(),a.evidence,a.sha)
