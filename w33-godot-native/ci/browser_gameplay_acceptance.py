#!/usr/bin/env python3
"""Actual Godot WebGL gameplay: real pointer/keyboard events, read-only DOM mirror.

The mirror exposes only simulation state + native Control rectangles.
This test never calls core methods, invents success, or writes saves directly.
"""
import argparse
import hashlib
import http.server
import json
import threading
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

BASE = ((68, 44), (80, 75), (48, 55))
RECOVERY = ((56, 62), (90, 86), (62, 40))

class Server(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass

class Driver:
    def __init__(self,page,device,folder):
        self.page,self.device,self.folder=page,device,folder
        self.events=[]
        self.canvas=page.locator("canvas").first
        self.marker=page.locator("#osgard-native-state")
        self.marker.wait_for(state="attached",timeout=90000)
        self.until(lambda state: state.get("mission")==-1, "native Godot idle")
    def state(self):
        s=self.marker.get_attribute("data-state",timeout=10000)
        return json.loads(s) if s else {}
    def geometry(self):
        s=self.marker.get_attribute("data-geometry",timeout=10000)
        return json.loads(s) if s else {}
    def until(self,predicate,label,timeout=20000):
        deadline=time.monotonic()+timeout/1000
        last={}
        while time.monotonic()<deadline:
            last=self.state()
            if predicate(last):
                return last
            self.page.wait_for_timeout(180)
        raise AssertionError(f"{self.device}: {label} timeout; last={last}")
    def record(self,action):
        state=self.state()
        self.events.append({"action":action,**state})
        return state
    def click_ui(self,name,ratio=0.5):
        for attempt in range(48):
            geometry=self.geometry()
            if name not in geometry:
                raise AssertionError(f"UI rectangle absent: {name}")
            x,y,w,h=geometry[name]
            vw,vh=geometry["viewport"]
            box=self.canvas.bounding_box()
            if not box or not vw or not vh:
                raise AssertionError("Missing original Godot canvas bounds")
            # Native scroll geometry is measured in its own canvas coordinates.
            tx=x+w*ratio
            ty=y+h/2
            if 4<tx<vw-4 and 8<ty<vh-8:
                bx=box["x"]+tx*box["width"]/vw
                by=box["y"]+ty*box["height"]/vh
                self.page.mouse.click(bx,by)
                self.page.wait_for_timeout(180)
                return self.record("click "+name)
            mx=box["x"]+box["width"]*0.48
            my=box["y"]+box["height"]*0.60
            self.page.mouse.move(mx,my)
            self.page.mouse.wheel(0, 360 if ty>=vh-8 else -360)
            self.page.wait_for_timeout(200)
        raise AssertionError(f"Godot native scroll cannot bring {name} onto screen: {self.geometry()[name]}")
    def key(self,key):
        self.page.keyboard.press(key)
        self.page.wait_for_timeout(180)
        return self.record("key "+key)
    def tune(self,axis,target):
        name="slider_"+axis
        self.click_ui(name,target/100)
        for n in range(85):
            current=int(self.state()[axis])
            if current==target:
                return self.record(f"calibrate {axis}={target}")
            self.key("ArrowRight" if current<target else "ArrowLeft")
            updated=int(self.state()[axis])
            if updated==current:
                raise AssertionError(f"Native slider {axis} not responding to arrow keyboard: {current}")
        raise AssertionError(f"Cannot calibrate native {axis} to {target}")
    def screenshot(self,label):
        path=self.folder/f"{self.device}-{label}.png"
        data=self.canvas.screenshot(timeout=30000)
        path.write_bytes(data)
        return {"file":path.name,"sha256":hashlib.sha256(data).hexdigest()}
    def mission(self,index):
        base=index%3
        advanced=index>=3
        self.click_ui("mission"+str(index))
        self.until(lambda s:s.get("active") and s.get("mission")==index, f"mission {index} selected")
        self.key("s")
        self.until(lambda s:s.get("step")==1 and not s.get("drive_on"),"stopped")
        self.until(lambda s:s.get("rpm",2000)<=80,"rotor stopped",timeout=18000)
        self.key("h")
        self.until(lambda s:s.get("step")==2 and s.get("inspection_allowed")==False,"hatch open; inspect camera",timeout=20000)
        self.key("3" if base==0 else "2")
        self.until(lambda s:s.get("inspection_allowed") is True,"correct camera")
        self.tune("a",BASE[base][0])
        self.tune("b",BASE[base][1])
        if advanced:
            self.until(lambda s:s.get("incident") is True,"real scripted incident")
            self.tune("a",RECOVERY[base][0])
            self.tune("b",RECOVERY[base][1])
        self.until(lambda s:s.get("ready") is True,"genuine stable readings",timeout=25000)
        self.key("x")
        self.until(lambda s:s.get("step")==3,"scan accepted")
        self.key("h")
        self.until(lambda s:s.get("step")==4 and s.get("hatch",1)<0.01,"hatch safely closed",timeout=18000)
        self.key("s")
        complete=self.until(lambda s:s.get("complete") is True and s.get("step")==5,"real case completion")
        assert complete["errors"]==0, f"Unexpected unsafe native actions: {complete}"
        assert complete["score"]>=60, f"Native score too low: {complete}"
        assert complete["cleared"] == (index+1 if not advanced else 3), f"Base progress count wrong: {complete}"
        if advanced:
            assert complete["shift_cleared"] == index-2 and complete["incident"],complete
        self.record("mission completed")
        self.screenshot(f"mission-{index}-completed")
        return complete

def check(folder,out,sha):
    folder=folder.resolve()
    if len(sha)!=40 or any(c not in "0123456789abcdef" for c in sha):
        raise ValueError("Exact Git source SHA required")
    for file in ("index.html","index.js","index.pck","index.wasm"):
        assert (folder/file).is_file(), "Not an actual Godot export: "+file
    out.mkdir(parents=True,exist_ok=True)
    handler=lambda *args,**kwargs:Server(*args,directory=str(folder),**kwargs)
    httpd=http.server.ThreadingHTTPServer(("127.0.0.1",0),handler)
    threading.Thread(target=httpd.serve_forever,daemon=True).start()
    report={"schema":"OSGARD_W33_REAL_WEBGL_INTERACTION_V1",
            "source_sha":sha,"status":"FAIL",
            "physical_device_certified":False,
            "actual_windows_execution_certified":False,
            "gameplay_verified_by_real_canvas_events":False,"devices":[]}
    try:
        url=f"http://127.0.0.1:{httpd.server_port}/index.html"
        with sync_playwright() as playwright:
            browser=playwright.chromium.launch(headless=True,args=[
                "--enable-webgl","--ignore-gpu-blocklist",
                "--use-angle=swiftshader","--enable-unsafe-swiftshader",
                "--disable-dev-shm-usage"])
            try:
                device="desktop-1366x768"
                context=browser.new_context(viewport={"width":1366,"height":768},device_scale_factor=1)
                errors=[]
                page=context.new_page()
                page.on("pageerror",lambda ex:errors.append(str(ex)))
                try:
                    page.goto(url,wait_until="domcontentloaded",timeout=60000)
                    driver=Driver(page,device,out)
                    # Actual unsafe hatch hotkey must remain interlocked before a mission.
                    driver.key("h")
                    driver.until(lambda s:s.get("feedback")=="safetyInterlock" and s.get("drive_on"),"unsafe hatch blocked")
                    for mission_index in range(6):
                        driver.mission(mission_index)
                    assert not errors, "Browser runtime exceptions: "+str(errors)
                    report["devices"].append({"name":device,"missions":list(range(6)),
                        "actions":driver.events,"result":"PASS"})
                except Exception as error:
                    driver=locals().get("driver")
                    if driver and driver.page==page:
                        driver.screenshot("FAILED")
                    raise
                finally:
                    context.close()
            finally:
                browser.close()
        report["gameplay_verified_by_real_canvas_events"]=True
        report["status"]="PASS"
    finally:
        httpd.shutdown()
        httpd.server_close()
        (out/"gameplay-evidence.json").write_text(json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf8")
    print(json.dumps({"status":report["status"],"source_sha":sha,
        "devices":[{"name":d["name"],"missions":d["missions"],"actions":len(d["actions"])} for d in report["devices"]]},indent=2))

if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--export",type=Path,required=True)
    p.add_argument("--evidence",type=Path,required=True)
    p.add_argument("--sha",required=True)
    args=p.parse_args()
    check(args.export,args.evidence,args.sha)
