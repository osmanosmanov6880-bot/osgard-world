#!/usr/bin/env python3
"""W39: original Godot WebGL screenshots, not concept art or device certification."""
import argparse
import hashlib
import http.server
import io
import json
import threading
import time
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageStat
from playwright.sync_api import sync_playwright

class Server(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass

def read(marker,key):
    value=marker.get_attribute(key,timeout=10000)
    return json.loads(value) if value else {}

def wait_state(page,marker,key,value):
    last={}
    for _ in range(110):
        last=read(marker,"data-state")
        if last.get(key)==value:
            return last
        page.wait_for_timeout(220)
    raise AssertionError(f"Native Godot {key} did not become {value}: {last}")

def render(page,path):
    png=page.screenshot(timeout=45000,animations="disabled")
    original=Image.open(io.BytesIO(png)).convert("RGB")
    small=original.resize((128,72))
    bins=len({tuple(x//16 for x in rgb) for rgb in small.getdata()})
    variance=max(ImageStat.Stat(small).stddev)
    assert bins>=18 and variance>11,("Empty/unclear real Godot framebuffer",bins,variance)
    path.write_bytes(png)
    return {"image":path.name,"sha256":hashlib.sha256(png).hexdigest(),
            "color_bins":bins,"variance":round(variance,2)}

def compare(path_a,path_b):
    a=Image.open(path_a).convert("RGB").resize((128,72))
    b=Image.open(path_b).convert("RGB").resize((128,72))
    return round(sum(ImageStat.Stat(ImageChops.difference(a,b)).mean)/3,2)

def open_game(browser,url,width,height,mobile):
    ctx=browser.new_context(viewport={"width":width,"height":height},
                            is_mobile=mobile,has_touch=mobile,device_scale_factor=1)
    page=ctx.new_page()
    errors=[]
    page.on("pageerror",lambda error:errors.append(str(error)))
    page.goto(url,wait_until="domcontentloaded",timeout=60000)
    page.locator("canvas").first.wait_for(state="visible",timeout=90000)
    marker=page.locator("#osgard-native-state")
    marker.wait_for(state="attached",timeout=90000)
    wait_state(page,marker,"mission",-1)
    page.wait_for_timeout(1000)
    return ctx,page,marker,errors

def click_control(page,marker,name):
    geom=read(marker,"data-geometry")
    x,y,w,h=geom[name]
    vw,vh=geom["viewport"]
    bounds=page.locator("canvas").first.bounding_box()
    assert bounds and vw and vh
    cx=bounds["x"]+(x+w/2)*bounds["width"]/vw
    cy=bounds["y"]+(y+h/2)*bounds["height"]/vh
    assert 0<=cx<=page.viewport_size["width"] and 0<=cy<=page.viewport_size["height"]
    page.mouse.click(cx,cy)

def montage(shots,out):
    width,height=600,370
    board=Image.new("RGB",(width*2,height*3),(8,12,16))
    paint=ImageDraw.Draw(board)
    for i,(label,filepath) in enumerate(shots):
        pic=Image.open(filepath).convert("RGB")
        scale=min((width-30)/pic.width,(height-65)/pic.height)
        pic=pic.resize((round(pic.width*scale),round(pic.height*scale)))
        column,row=i%2,i//2
        board.paste(pic,(column*width+(width-pic.width)//2,row*height+46))
        paint.text((column*width+17,row*height+14),label,fill=(220,195,164))
    board.save(out,optimize=True)

def verify(export,out,sha):
    assert len(sha)==40 and all(c in "0123456789abcdef" for c in sha)
    export=export.resolve()
    for n in ("index.html","index.js","index.wasm","index.pck"):
        assert (export/n).is_file(),n
    out.mkdir(parents=True,exist_ok=True)
    handler=lambda *a,**kw:Server(*a,directory=str(export),**kw)
    server=http.server.ThreadingHTTPServer(("127.0.0.1",0),handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    result={"schema":"OSGARD_W39_ORIGINAL_GODOT_ART_REVIEW","source_sha":sha,
            "real_godot_export":True,"not_concept_art":True,
            "real_phone_hardware_certified":False,
            "AAA_art_certified":False,"status":"FAIL","frames":[]}
    shots=[]
    try:
        with sync_playwright() as p:
            browser=p.chromium.launch(headless=True,args=[
                "--enable-webgl","--ignore-gpu-blocklist",
                "--use-angle=swiftshader","--enable-unsafe-swiftshader",
                "--disable-dev-shm-usage"])
            url=f"http://127.0.0.1:{server.server_port}/index.html"
            try:
                ctx,page,marker,errors=open_game(browser,url,1366,768,False)
                try:
                    geo=read(marker,"data-geometry")
                    stage=geo["hero_stage"]
                    assert stage[2]>=900 and stage[3]>=490,("Small actual hero",stage)
                    name=out/"01_HERO_OVERVIEW.png"
                    result["frames"].append(render(page,name))
                    shots.append(("A7 / HERO OVERVIEW",name))
                    page.mouse.click(500,320)
                    for index,key,label in [(1,"2","02_INSPECTION"),(2,"3","03_SERVICE")]:
                        page.keyboard.press(key)
                        wait_state(page,marker,"view",index)
                        page.wait_for_timeout(1500)
                        name=out/(label+".png")
                        result["frames"].append(render(page,name))
                        shots.append(("A7 / "+label[3:],name))
                    diffs=[compare(shots[0][1],shots[1][1]),
                           compare(shots[1][1],shots[2][1])]
                    result["camera_frame_difference"]=diffs
                    assert min(diffs)>0.5,("Actual camera view did not differ",diffs)
                    click_control(page,marker,"quality")
                    wait_state(page,marker,"quality","eco")
                    name=out/"04_ECO.png"
                    result["frames"].append(render(page,name))
                    shots.append(("A7 / ECO",name))
                    assert not errors,errors
                finally:
                    ctx.close()
                ctx,page,marker,errors=open_game(browser,url,390,844,True)
                try:
                    geo=read(marker,"data-geometry")
                    stage=geo["hero_stage"]
                    assert 250<=stage[3]<=310 and stage[2]>=290,stage
                    assert "dial_a" in geo and "dial_b" in geo,"Native knob geometry missing"
                    name=out/"05_MOBILE_EMULATED.png"
                    result["frames"].append(render(page,name))
                    shots.append(("A7 / MOBILE EMULATION",name))
                    assert not errors,errors
                finally:
                    ctx.close()
            finally:
                browser.close()
        montage(shots,out/"ORIGINAL_W39_OBSIDIAN_CONTACT_SHEET.png")
        result["status"]="PASS"
    finally:
        server.shutdown()
        server.server_close()
        (out/"visual-evidence.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf8")
    print(json.dumps({"result":result["status"],"source_sha":sha,
                      "original_frames":len(result["frames"]),
                      "camera_frame_difference":result.get("camera_frame_difference")}))

if __name__=="__main__":
    arg=argparse.ArgumentParser()
    arg.add_argument("--export",required=True,type=Path)
    arg.add_argument("--out",required=True,type=Path)
    arg.add_argument("--sha",required=True)
    a=arg.parse_args()
    verify(a.export,a.out,a.sha)
