#!/usr/bin/env python3
"""Actual Godot W33 WebGL canvas in Chromium; NOT physical-device certification."""
import argparse
import hashlib
import http.server
import io
import json
import threading
from pathlib import Path
from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright

class Server(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass

def quality(frame):
    image=Image.open(io.BytesIO(frame)).convert('RGB')
    tiny=image.resize((128,72))
    colors={(r//16,g//16,b//16) for r,g,b in tiny.getdata()}
    # Detect Godot aspect-ratio letterboxing inside the CANVAS itself.
    # The previous mobile screenshot rendered only ~29% of the 844px height
    # while the canvas box filled the viewport: an invisible false PASS.
    columns=image.resize((64,128)).convert('RGB')
    active_rows=0
    for y in range(128):
        if any(max(columns.getpixel((x,y)))>=14 for x in range(12,52)):
            active_rows+=1
    return {'active_height_fraction':round(active_rows/128,3),
            'width':image.width,'height':image.height,
            'color_bins':len(colors),
            'deviation':round(max(ImageStat.Stat(tiny).stddev),2),
            'sha256':hashlib.sha256(frame).hexdigest()}

def check(directory,out,sha):
    directory=directory.resolve()
    if len(sha)!=40 or any(c not in '0123456789abcdef' for c in sha):
        raise ValueError('Require exact source commit SHA')
    for filename in ('index.html','index.wasm','index.pck','index.js'):
        if not (directory/filename).is_file():
            raise ValueError('Missing actual native export '+filename)
    out.mkdir(parents=True,exist_ok=True)
    handler=lambda *a,**k:Server(*a,directory=str(directory),**k)
    server=http.server.ThreadingHTTPServer(('127.0.0.1',0),handler)
    threading.Thread(target=server.serve_forever,daemon=True).start()
    url=f'http://127.0.0.1:{server.server_port}/index.html'
    report={'schema':'OSGARD_W33_REAL_WEBGL_BROWSER_V1','source_sha':sha,
            'real_godot_export':True,'phone_hardware_certified':False,
            'complete_browser_gameplay_certified':False,'status':'FAIL','screens':[]}
    try:
        with sync_playwright() as p:
            browser=p.chromium.launch(headless=True,args=[
                '--enable-webgl','--ignore-gpu-blocklist',
                '--use-angle=swiftshader','--enable-unsafe-swiftshader',
                '--disable-dev-shm-usage'])
            try:
                for name,viewport,touch in (
                    ('desktop-1366x768',{'width':1366,'height':768},False),
                    ('touch-emulation-390x844',{'width':390,'height':844},True)):
                    context=browser.new_context(viewport=viewport,has_touch=touch,
                                                is_mobile=touch,device_scale_factor=1)
                    page=context.new_page()
                    errors=[]
                    page.on('pageerror',lambda error: errors.append(str(error)))
                    try:
                        page.goto(url,wait_until='domcontentloaded',timeout=45000)
                        canvas=page.locator('canvas').first
                        canvas.wait_for(state='visible',timeout=90000)
                        page.wait_for_function("""() => {
                          const s=document.querySelector('#status');
                          return !s || s.hidden || getComputedStyle(s).display==='none';
                        }""",timeout=120000)
                        page.wait_for_timeout(2000)
                        frame=None
                        stats=None
                        for _ in range(6):
                            # A live Godot canvas never settles: Locator.screenshot
                            # waits for the element to be 'stable' and can hang.
                            # Capture the actual composited Chromium viewport
                            # without scrolling, pausing or faking WebGL input.
                            frame=page.screenshot(timeout=45000,animations='disabled')
                            stats=quality(frame)
                            if stats['color_bins']>=18 and stats['deviation']>11:
                                break
                            page.wait_for_timeout(1500)
                        assert stats['width']>=300 and stats['height']>=250,stats
                        assert stats['color_bins']>=18 and stats['deviation']>11,('blank Godot canvas',stats)
                        assert stats['active_height_fraction']>=0.70,('Godot letterboxed or shrunk canvas; NOT touch-ready',stats)
                        # W38 native Godot HUD geometry, not a mocked HTML image:
                        # require a dominating PC 3D stage and reachable portrait UI.
                        marker=page.locator('#osgard-native-state')
                        marker.wait_for(state='attached',timeout=15000)
                        frame_geometry=json.loads(marker.get_attribute('data-geometry',timeout=12000))
                        stage=frame_geometry.get('hero_stage')
                        assert stage and len(stage)==4,('Actual OBSIDIAN 3D stage missing',frame_geometry)
                        if touch:
                            assert 250<=stage[3]<=310,('Phone stage consumes inaccessible height',stage)
                            assert stage[2]>=290,('Phone stage too narrow',stage)
                        else:
                            assert stage[3]>=490,('Desktop cinematic stage insufficiently prominent',stage)
                            assert stage[2]>=900,('Desktop stage not full-width',stage)
                        assert 'dial_a' in frame_geometry and 'dial_b' in frame_geometry,('Native W36 knob rectangles missing',frame_geometry)
                        stats['hero_stage_rectangle']=stage
                        stats['native_dial_count']=2
                        assert not errors,('Uncaught JS errors',errors)
                        filename=name+'.png'
                        (out/filename).write_bytes(frame)
                        report['screens'].append({'target':name,'result':'PASS',**stats,'screenshot':filename})
                    finally:
                        context.close()
            finally:
                browser.close()
        report['status']='PASS'
    finally:
        server.shutdown()
        server.server_close()
        (out/'browser-webgl-evidence.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    print(json.dumps(report,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--export',type=Path,required=True)
    parser.add_argument('--evidence',type=Path,required=True)
    parser.add_argument('--sha',required=True)
    args=parser.parse_args()
    check(args.export,args.evidence,args.sha)
