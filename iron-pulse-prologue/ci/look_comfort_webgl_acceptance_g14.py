#!/usr/bin/env python3
"""Exact-source G14 real Godot WebGL camera comfort/input browser acceptance.

Only Playwright's real keyboard, mouse and touchscreen interactions change the
game. DOM state is READ-ONLY. No mocked pixels, synthesized gameplay wins or
fabricated real-hardware/camera certification.
"""
import argparse
import hashlib
import http.server
import io
import json
import threading
import time
from pathlib import Path
from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


class QuietHTTP(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def wait_state(page, marker, predicate, deadline=25, subject="source state"):
    until = time.monotonic() + deadline
    state = {}
    while time.monotonic() < until:
        state = json.loads(marker.get_attribute("data-state", timeout=12000))
        if predicate(state):
            return state
        page.wait_for_timeout(200)
    raise AssertionError(f"Actual Godot {subject} did not update: {json.dumps(state,ensure_ascii=False)[:2200]}")


def native_tap(page, canvas, rect, native_size):
    assert len(rect) == 4 and rect[2] >= 44 and rect[3] >= 44, ("Native 44px+ required",rect)
    bound = canvas.bounding_box()
    assert bound is not None
    px = bound["x"] + (rect[0] + rect[2] / 2) * bound["width"] / native_size[0]
    py = bound["y"] + (rect[1] + rect[3] / 2) * bound["height"] / native_size[1]
    assert bound["x"] <= px <= bound["x"] + bound["width"],("Native button X clipped",rect,px)
    assert bound["y"] <= py <= bound["y"] + bound["height"],("Native button Y clipped",rect,py)
    page.touchscreen.tap(px,py)


def visual_proof(png, width, height):
    im=Image.open(io.BytesIO(png)).convert("RGB")
    assert im.size == (width,height), ("Wrong actual game screenshot size",im.size)
    thumb=im.resize((128,72))
    colors=len({(r//16,g//16,b//16) for r,g,b in thumb.getdata()})
    std=max(ImageStat.Stat(thumb).stddev)
    assert colors>=12 and std>7, ("Empty real Godot game canvas",colors,std)
    return {"width":width,"height":height,"sha256":hashlib.sha256(png).hexdigest(),
            "color_bins":colors,"stddev":round(std,2)}


def run(website:Path,evidence:Path,source:str):
    assert len(source)==40 and all(x in "0123456789abcdef" for x in source)
    for name in ("index.html","index.js","index.pck","index.wasm"):
        assert (website/name).is_file(),("Exact exported Godot asset required",name)
    evidence.mkdir(parents=True,exist_ok=True)
    handler=lambda *a,**k:QuietHTTP(*a,directory=str(website.resolve()),**k)
    server=http.server.ThreadingHTTPServer(("127.0.0.1",0),handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    report={
        "schema":"IRON_PULSE_G14_REAL_WEBGL_CAMERA_ACCESSIBILITY",
        "source_sha":source,"status":"FAIL",
        "real_webgl":True,"native_godot_camera":True,
        "physical_devices_certified":False,"production_ready":False,
        "remote_telemetry":False,"user_tracking":False,
        "screenshots":[]
    }
    try:
        with sync_playwright() as pw:
            browser=pw.chromium.launch(headless=True,args=[
                "--enable-webgl","--ignore-gpu-blocklist",
                "--use-angle=swiftshader","--enable-unsafe-swiftshader",
                "--disable-dev-shm-usage"
            ])
            try:
                for name,view,is_mobile in [
                    ("desktop",{"width":1366,"height":768},False),
                    ("mobile-touch",{"width":390,"height":844},True),
                ]:
                    ctx=browser.new_context(viewport=view,is_mobile=is_mobile,has_touch=is_mobile,
                        device_scale_factor=1)
                    try:
                        page=ctx.new_page()
                        failures=[]
                        page.on("pageerror",lambda e:failures.append(str(e)))
                        page.goto(f"http://127.0.0.1:{server.server_port}/index.html",
                            wait_until="domcontentloaded",timeout=60000)
                        canvas=page.locator("canvas").first
                        canvas.wait_for(state="visible",timeout=90000)
                        marker=page.locator("#iron-pulse-native-state")
                        marker.wait_for(state="attached",timeout=120000)
                        idle=wait_state(page,marker,
                            lambda s:s.get("viewport")==[view["width"],view["height"]] and
                                s.get("godot_frames_drawn",0)>=2,100,
                            subject="true native CSS-sized game viewport")
                        look=idle.get("g14_look_comfort",{})
                        assert look.get("schema")=="IRON_PULSE_LOOK_COMFORT_G14",look
                        assert look.get("mode")=="standard" and look.get("original_input_path","").startswith("Godot"),look
                        assert look.get("autonomous_camera") is False and look.get("gameplay_mutated") is False,look
                        assert look.get("telemetry_uploaded") is False and look.get("local_only") is True,look
                        assert look.get("pause_control_rect",[0,0,0,0])[3]>=44,look
                        if is_mobile:
                            rect=look.get("touch_control_rect",[])
                            assert len(rect)==4 and rect[2]>=44 and rect[3]>=44 and rect[0]+rect[2]<=390
                            others=idle.get("g12_control_comfort",{}).get("touch_pause_rect")
                            assert len(others)==4 and (rect[1]>=others[1]+others[3]+3),(
                                "Real mobile camera LOOK must not cover native PAUSE",rect,others)
                        canvas.focus()
                        page.keyboard.press("Enter")
                        playing=wait_state(page,marker,lambda s:s.get("started") is True,45,
                            subject="real original 3-act mission")
                        baseline={"switches":playing["switches"],"faults":playing["faults"],
                                  "scanned":playing["scanned"],"priority":playing.get("priority","")}
                        if is_mobile:
                            native_tap(page,canvas,playing["g14_look_comfort"]["touch_control_rect"],
                                playing["viewport"])
                        else:
                            page.keyboard.press("F10")
                        gentle=wait_state(page,marker,lambda s:s.get("g14_look_comfort",{}).get("mode")=="gentle",
                            22,subject="physical F10/mobile LOOK switched actual source camera into gentle mode")
                        assert 0.001 < gentle["g14_look_comfort"]["camera_speed"] < 0.0021
                        assert gentle["g14_look_comfort"]["invert_y"] is False
                        assert gentle["g14_look_comfort"]["ui_label"]
                        # Demonstrate the original source Camera3D/yaw/pitch is
                        # controlled by real user input, never directly assigned
                        # through read-only browser JS diagnostic DOM.
                        if not is_mobile:
                            bound=canvas.bounding_box()
                            assert bound is not None
                            centre_x=bound["x"]+bound["width"]*.51
                            centre_y=bound["y"]+bound["height"]*.56
                            # Pointer lock requires genuine browser user activation.
                            # Enter may start Godot without granting Chromium mouse
                            # capture; a real canvas click requests that permission.
                            page.mouse.click(centre_x,centre_y)
                            deadline=time.monotonic()+13
                            captured={}
                            while time.monotonic()<deadline:
                                captured=json.loads(marker.get_attribute("data-state",timeout=12000))
                                if captured.get("mouse_captured") is True:
                                    break
                                page.mouse.click(centre_x,centre_y)
                                page.wait_for_timeout(350)
                            print("G14_REAL_DESKTOP_POINTER_CAPTURE",
                                  captured.get("mouse_captured"),flush=True)
                            assert captured.get("mouse_captured") is True, (
                                "The true Godot mouse input must capture after physical canvas activation",
                                captured.get("mouse_captured"))
                            before=captured["g14_look_comfort"]["camera_yaw"]
                            moved=captured
                            for attempt in range(5):
                                page.mouse.move(centre_x+12,centre_y+6,steps=4)
                                page.mouse.move(centre_x+120,centre_y+64,steps=10)
                                page.wait_for_timeout(350)
                                moved=json.loads(marker.get_attribute("data-state",timeout=12000))
                                if abs(moved.get("g14_look_comfort",{}).get("camera_yaw",before)-before)>.006:
                                    break
                                # These are real physical browser mouse events,
                                # not commands sent to the Godot engine.
                                page.mouse.down()
                                page.mouse.move(centre_x+140,centre_y+90,steps=7)
                                page.mouse.up()
                                page.wait_for_timeout(250)
                                moved=json.loads(marker.get_attribute("data-state",timeout=12000))
                                if abs(moved.get("g14_look_comfort",{}).get("camera_yaw",before)-before)>.006:
                                    break
                            delta=abs(moved.get("g14_look_comfort",{}).get("camera_yaw",before)-before)
                            print("G14_REAL_MOUSE_ROTATION_DELTA",delta,
                                  "capture",moved.get("mouse_captured"),flush=True)
                            assert delta>.006, (
                                "Actual Chromium physical mouse movement failed to rotate the real Godot Camera3D",
                                "capture",moved.get("mouse_captured"),"delta",delta,
                                "look",moved.get("g14_look_comfort",{}))
                            assert abs(moved["g14_look_comfort"]["camera_yaw"]-
                                       moved["g14_look_comfort"]["native_camera_yaw"])<.0005
                        if is_mobile:
                            native_tap(page,canvas,gentle["g14_look_comfort"]["touch_control_rect"],gentle["viewport"])
                        else:
                            page.keyboard.press("F10")
                        inverted=wait_state(page,marker,
                            lambda s:s.get("g14_look_comfort",{}).get("mode")=="invert_y",22,
                            subject="actual physical input selected inverted vertical look")
                        assert inverted["g14_look_comfort"]["invert_y"] is True
                        if is_mobile:
                            native_tap(page,canvas,inverted["g14_look_comfort"]["touch_control_rect"],inverted["viewport"])
                        else:
                            page.keyboard.press("F10")
                        restored=wait_state(page,marker,lambda s:s.get("g14_look_comfort",{}).get("mode")=="standard",
                            22,subject="original source camera accessibility mode restored")
                        assert abs(restored["g14_look_comfort"]["camera_speed"]-0.0021)<.0000001
                        assert all(restored[k]==baseline[k] for k in baseline),(
                            "No camera profile may change any real campaign decisions",restored)
                        if is_mobile:
                            native_tap(page,canvas,restored["g12_control_comfort"]["touch_pause_rect"],restored["viewport"])
                            paused=wait_state(page,marker,lambda s:s.get("paused") is True and
                                s.get("touch_controls_visible") is False,22,
                                subject="original native mobile PAUSE opens 52px camera settings")
                            camera_rect=paused["g14_look_comfort"]["pause_control_rect"]
                            assert camera_rect and camera_rect[2]>=44 and camera_rect[3]>=44
                            assert camera_rect[0]>=0 and camera_rect[1]>=0 and (
                                camera_rect[0]+camera_rect[2]<=390 and camera_rect[1]+camera_rect[3]<=844), (
                                "Real G14 pause LOOK button unreachable on phone",camera_rect)
                            native_tap(page,canvas,camera_rect,paused["viewport"])
                            changed=wait_state(page,marker,lambda s:s.get("g14_look_comfort",{}).get("mode")=="gentle",
                                22,subject="finger tap on actual 52px pause LOOK control")
                            assert changed.get("paused") is True and all(changed[k]==baseline[k] for k in baseline)
                            native_tap(page,canvas,changed["g12_control_comfort"]["resume_rect"],changed["viewport"])
                            after_pause=wait_state(page,marker,lambda s:s.get("paused") is False and
                                s.get("touch_controls_visible") is True,22,
                                subject="real mobile resume restores thumb controls")
                        png=page.screenshot(animations="disabled",timeout=60000)
                        info=visual_proof(png,view["width"],view["height"])
                        filename=f"g14-source-native-camera-{name}.png"
                        (evidence/filename).write_bytes(png)
                        report["screenshots"].append({"device":name,"filename":filename,**info})
                        assert not failures,failures
                        report[name]={
                            "native_source_inputs":"F10 and mouse" if not is_mobile else "real touch LOOK/PAUSE/RESUME",
                            "original_3d_camera":True,"modes":["standard","gentle","invert_y"],
                            "restored_original":not is_mobile,
                            "local_only":True,"real_hardware_certified":False,
                            "mission_choices_unchanged":True
                        }
                    finally:
                        ctx.close()
            finally:
                browser.close()
        report["status"]="PASS"
    finally:
        server.shutdown()
        server.server_close()
        (evidence/"g14-look-webgl-evidence.json").write_text(
            json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report,ensure_ascii=False,indent=2))
    return report

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--export",type=Path,required=True)
    parser.add_argument("--evidence",type=Path,required=True)
    parser.add_argument("--sha",required=True)
    a=parser.parse_args()
    assert run(a.export,a.evidence,a.sha)["status"]=="PASS"
