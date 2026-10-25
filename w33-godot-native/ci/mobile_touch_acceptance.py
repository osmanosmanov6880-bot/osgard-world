#!/usr/bin/env python3
"""W45 real mobile-touch gameplay in exported Godot WebGL.

Only real Chromium touchscreen/CDP gestures are sent to the original canvas.
No programmatic gameplay-method invocation, DOM fake state, keyboard or mouse
input is permitted. A fail-closed QA gate, not a physical phone certification.
"""
import argparse
import hashlib
import http.server
import json
import math
import threading
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

TARGETS = {"a": 68, "b": 44}


class StaticHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


class TouchDriver:
    def __init__(self, page):
        self.page = page
        self.canvas = page.locator("canvas").first
        self.marker = page.locator("#osgard-native-state")
        self.marker.wait_for(state="attached", timeout=90000)
        self.cdp = page.context.new_cdp_session(page)
        self.events = []
        self.swipes = 0

    def state(self):
        return json.loads(self.marker.get_attribute("data-state", timeout=10000))

    def geometry(self):
        return json.loads(self.marker.get_attribute("data-geometry", timeout=10000))

    def until(self, predicate, label, timeout=30000):
        start = time.monotonic()
        last = {}
        while (time.monotonic() - start) * 1000 < timeout:
            last = self.state()
            if predicate(last):
                return last
            self.page.wait_for_timeout(220)
        raise AssertionError(f"{label}: real Godot state timed out; last={last}")

    def canvas_bounds(self):
        bounds = self.canvas.bounding_box()
        assert bounds and bounds["width"] > 0 and bounds["height"] > 0, "True Godot canvas missing"
        return bounds

    def to_css(self, native_x, native_y, geo=None):
        geo = self.geometry() if geo is None else geo
        vw, vh = geo["viewport"]
        box = self.canvas_bounds()
        assert vw > 0 and vh > 0
        return (box["x"] + native_x * box["width"] / vw,
                box["y"] + native_y * box["height"] / vh)

    def swipe(self, direction):
        assert direction in (1, -1)
        box = self.canvas_bounds()
        x = round(box["x"] + box["width"] * 0.89)
        start_y = box["y"] + box["height"] * (0.78 if direction == 1 else 0.26)
        end_y = box["y"] + box["height"] * (0.26 if direction == 1 else 0.78)
        def point(y):
            return [{"x": x, "y": round(y), "id": 1, "radiusX": 6, "radiusY": 6}]
        self.cdp.send("Input.dispatchTouchEvent", {"type": "touchStart", "touchPoints": point(start_y)})
        for step in range(1, 15):
            y = start_y + (end_y - start_y) * step / 14
            self.cdp.send("Input.dispatchTouchEvent", {"type": "touchMove", "touchPoints": point(y)})
            self.page.wait_for_timeout(18)
        self.cdp.send("Input.dispatchTouchEvent", {"type": "touchEnd", "touchPoints": []})
        self.page.wait_for_timeout(450)
        self.swipes += 1

    def visible_control(self, name):
        for attempt in range(19):
            geo = self.geometry()
            assert name in geo, f"Actual Godot control {name} not present"
            x,y,w,h = geo[name]
            vw,vh = geo["viewport"]
            assert w > 0 and h > 0 and vw > 0 and vh > 0, (name, geo[name])
            if 16 <= (y + h * 0.5) <= (vh - 20) and 8 <= (x + w * 0.5) <= vw - 8:
                return geo
            direction = 1 if y + h * 0.5 > vh - 20 else -1
            previous = geo.get("scroll", 0)
            self.swipe(direction)
            next_scroll = self.geometry().get("scroll", 0)
            if next_scroll == previous and attempt >= 5:
                raise AssertionError(f"Mobile native scroll stopped: {name} rect={geo[name]}, scroll={previous}")
        raise AssertionError(f"Real touch swipes cannot reach {name}; last geometry={self.geometry()}")

    def tap(self, name):
        geo = self.visible_control(name)
        x,y,w,h = geo[name]
        px,py = self.to_css(x+w*0.5,y+h*0.5,geo)
        self.page.touchscreen.tap(px,py)
        self.page.wait_for_timeout(260)
        self.events.append({"gesture": "touchTap", "control": name, "native_scroll": geo["scroll"]})
        return self.state()

    def turn_physical_dial(self, axis, target):
        geo = self.visible_control("dial_"+axis)
        x,y,w,h = geo["dial_"+axis]
        theta = math.radians(135.0 + 270.0 * target / 100.0)
        radius = 29.0
        native_x = x + w * 0.5 + radius * math.cos(theta)
        native_y = y + h * 0.5 + radius * math.sin(theta)
        px,py = self.to_css(native_x,native_y,geo)
        self.page.touchscreen.tap(px,py)
        state = self.until(lambda data: abs(int(data[axis])-target)<=2,
                           f"actual native dial touch {axis}={target}",timeout=16000)
        self.events.append({"gesture":"touchDial", "channel":axis,
                            "requested":target,"observed":int(state[axis])})
        return state


def check(export, evidence, sha):
    assert len(sha) == 40 and all(ch in "0123456789abcdef" for ch in sha)
    export = export.resolve()
    for name in ("index.html", "index.js", "index.wasm", "index.pck", "evidence.json"):
        assert (export / name).is_file(), name
    manifest = json.loads((export / "evidence.json").read_text())
    assert manifest["source_commit"] == sha and manifest["godot_release"] == "4.4.1"
    evidence.mkdir(parents=True, exist_ok=True)
    handler = lambda *args,**kwargs: StaticHandler(*args, directory=str(export), **kwargs)
    server = http.server.ThreadingHTTPServer(("127.0.0.1",0),handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    report = {
        "schema": "OSGARD_W45_REAL_MOBILE_TOUCH_GAMEPLAY_V1",
        "source_sha": sha, "status": "FAIL",
        "real_godot_webgl": True,
        "input_source": "Chromium touchscreen and CDP native touch gestures only",
        "synthetic_dom_gameplay": False,
        "physical_phone_tested": False, "ios_hardware_certified": False,
        "android_hardware_certified": False,
        "viewport": "390x844",
        "events": [], "touch_swipes": 0
    }
    driver = None
    page = None
    context = None
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True,args=[
                "--enable-webgl","--ignore-gpu-blocklist",
                "--use-angle=swiftshader","--enable-unsafe-swiftshader",
                "--disable-dev-shm-usage"])
            try:
                context = browser.new_context(viewport={"width":390,"height":844},
                    device_scale_factor=1,has_touch=True,is_mobile=True,locale="ru-RU")
                page = context.new_page()
                errors = []
                page.on("pageerror",lambda issue:errors.append(str(issue)))
                page.goto(f"http://127.0.0.1:{server.server_port}/index.html",
                          wait_until="domcontentloaded",timeout=60000)
                page.locator("canvas").first.wait_for(state="visible",timeout=90000)
                driver = TouchDriver(page)
                driver.until(lambda s:s.get("mission")==-1 and not s.get("active"),"cold native start")
                assert driver.state()["quality"]=="hero"
                driver.tap("quality")
                driver.until(lambda s:s.get("quality")=="eco","real touch turned ECO on")
                driver.tap("quality")
                driver.until(lambda s:s.get("quality")=="hero","real touch restored HERO")
                driver.tap("camera2")
                driver.until(lambda s:s.get("view")==2,"real touch selected actual optical camera")
                driver.tap("mission0")
                driver.until(lambda s:s.get("active") and s.get("mission")==0,"real touch started first mission")
                driver.tap("engine")
                driver.until(lambda s:s.get("step")==1 and not s.get("drive_on"),"real touch stopped engine")
                driver.until(lambda s:s.get("rpm",9999)<=80,"real rotor decelerated",18000)
                driver.tap("hatch")
                driver.until(lambda s:s.get("step")==2,"real touch opened hatch")
                driver.until(lambda s:s.get("hatch",0)>=0.995,"real hatch finished moving",18000)
                driver.tap("camera2")
                driver.until(lambda s:s.get("inspection_allowed") is True,"real view unlocks safe calibration")
                driver.turn_physical_dial("a",TARGETS["a"])
                driver.turn_physical_dial("b",TARGETS["b"])
                driver.until(lambda s:s.get("ready") is True,"real native calibration stabilizes",30000)
                driver.tap("scan")
                driver.until(lambda s:s.get("step")==3,"touch accepted safety scan")
                driver.tap("hatch")
                driver.until(lambda s:s.get("step")==4 and s.get("hatch",1)<0.01,
                             "touch closed hatch before restart",20000)
                driver.tap("engine")
                result = driver.until(lambda s:s.get("complete") is True and s.get("step")==5,
                                      "first complete real mobile-touch mission",20000)
                assert result.get("cleared")>=1 and result.get("errors")==0, result
                assert not errors,("Godot WebGL browser exceptions",errors)
                frame=page.screenshot(timeout=45000,animations="disabled")
                (evidence/"w45-mobile-real-touch-first-mission.png").write_bytes(frame)
                report["completed_case"]=0
                report["native_score"]=result["score"]
                report["native_events_confirmed"]=len(driver.events)
                report["original_screenshot_sha256"]=hashlib.sha256(frame).hexdigest()
                report["status"]="PASS"
            finally:
                if driver is not None:
                    report["events"]=driver.events
                    report["touch_swipes"]=driver.swipes
                if page is not None and report["status"]!="PASS":
                    try:
                        frame=page.screenshot(timeout=20000,animations="disabled")
                        (evidence/"w45-mobile-touch-failure.png").write_bytes(frame)
                    except Exception:
                        pass
                if context is not None:
                    context.close()
                browser.close()
    finally:
        server.shutdown()
        server.server_close()
        (evidence/"mobile-touch-evidence.json").write_text(
            json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf8")
    print(json.dumps({"status":report["status"],"source_sha":sha,
                      "swipes":report["touch_swipes"],
                      "touch_actions":len(report["events"]),
                      "completed_case":report.get("completed_case")},indent=2))


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--export",type=Path,required=True)
    parser.add_argument("--evidence",type=Path,required=True)
    parser.add_argument("--sha",required=True)
    args=parser.parse_args()
    check(args.export,args.evidence,args.sha)
