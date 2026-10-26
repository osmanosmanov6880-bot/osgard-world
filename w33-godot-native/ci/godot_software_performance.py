#!/usr/bin/env python3
"""OSGARD W44: measure REAL Godot engine FPS in Chromium SwiftShader.

This is NOT a physical PC/phone performance certification. A software WebGL
runner yields a reproducible, source-bound performance diagnostic. We do NOT
assert arbitrary 60 FPS on a shared CI machine or spoof native engine data.
"""
import argparse
import http.server
import json
import statistics
import threading
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

class StaticServer(http.server.SimpleHTTPRequestHandler):
    def log_message(self,*_args): pass

def state(marker):
    raw=marker.get_attribute("data-state",timeout=10000)
    return json.loads(raw) if raw else {}

def geometry(marker):
    raw=marker.get_attribute("data-geometry",timeout=10000)
    return json.loads(raw) if raw else {}

def await_quality(page,marker,quality):
    for _ in range(120):
        data=state(marker)
        if data.get("quality")==quality:
            return data
        page.wait_for_timeout(200)
    raise AssertionError(f"Real Godot quality control never became {quality}: {state(marker)}")

def measure(page,marker,mode,period=12,require_draw_calls=True):
    # W47 pristine baseline predates the read-only draw-call probe. Its real
    # FPS can still be measured independently; draw-call fields stay null.
    # W48 itself ALWAYS uses the strict default and cannot PASS without data.
    samples=[]
    frame_reads=[]
    draw_samples=[]
    object_samples=[]
    start=time.monotonic()
    while time.monotonic()-start < period:
        s=state(marker)
        assert s.get("quality")==mode,("Measured the wrong real mode",s)
        if require_draw_calls:
            # Unlike native --headless, this is a real Chromium WebGL
            # RenderingServer readback of ALL 83 W48 GPU instanced slots.
            assert s.get("w48_real_renderer_readback") is True, (
                "W48 actual browser renderer not available", s)
            assert s.get("w48_gpu_ring_transforms_ok") is True, (
                "W48 actual WebGL multimesh writes do not equal authored transforms", s)
            assert s.get("w48_gpu_ring_transforms_checked") == 83, (
                "Real WebGL did not check all 83 instanced ring pieces", s)
            assert s.get("w48_gpu_ring_mismatch_count") == 0, (
                "True GPU ring transform readback differs", s)
            assert 0 <= s.get("w48_gpu_ring_max_error", -1) < 0.0001, (
                "Real renderer ring transform maximum error beyond W47 tolerance", s)
        value=s.get("godot_render_fps")
        count=s.get("godot_frames_drawn")
        draws=s.get("godot_3d_draw_calls")
        objects=s.get("godot_3d_rendered_objects")
        if isinstance(draws,(int,float)) and 0<draws<20000:
            draw_samples.append(int(draws))
        if isinstance(objects,(int,float)) and 0<objects<20000:
            object_samples.append(int(objects))
        if isinstance(value,(int,float)) and value>0 and value<1000:
            samples.append(float(value))
        if isinstance(count,int) and count>=0:
            frame_reads.append(count)
        page.wait_for_timeout(550)
    # W48 cannot claim usable profiling evidence when the Godot renderer
    # reports no draw calls or object counts (missing/zero telemetry).
    if require_draw_calls:
        assert len(draw_samples)>=3,("Godot actual draw call samples unavailable",draw_samples)
        assert len(object_samples)>=3,("Godot rendered object samples unavailable",object_samples)
    assert len(samples)>=3,("Native engine FPS counter was not available",samples)
    assert len(frame_reads)>=3 and max(frame_reads)>min(frame_reads),(
        "Native Godot render loop stopped or did not advance",frame_reads)
    ordered=sorted(samples)
    return {
        "mode":mode,"sample_count":len(samples),"duration_seconds":round(time.monotonic()-start,2),
        "godot_engine_fps_mean":round(statistics.mean(samples),2),
        "godot_engine_fps_median":round(statistics.median(samples),2),
        "godot_engine_fps_p10":round(ordered[max(0,int(len(ordered)*0.1)-1)],2),
        "godot_engine_fps_min":round(min(samples),2),
        "godot_rendered_frames_progressed":True,
        "w48_actual_webgl_ring_transforms_checked": 83 if require_draw_calls else None,
        "render_draw_call_samples":len(draw_samples),
        "draw_call_probe_required":require_draw_calls,
        "render_draw_calls_median":statistics.median(draw_samples) if draw_samples else None,
        "render_objects_median":statistics.median(object_samples) if object_samples else None,
        "render_object_sample_count":len(object_samples),
        "software_emulation_only":True,
        "commercial_device_60fps_certified":False
    }

def real_quality_click(page,marker):
    geo=geometry(marker)
    x,y,w,h=geo["quality"]
    vw,vh=geo["viewport"]
    bounds=page.locator("canvas").first.bounding_box()
    assert bounds and vw and vh, "No true Godot canvas geometry"
    px=bounds["x"]+(x+w*0.5)*bounds["width"]/vw
    py=bounds["y"]+(y+h*0.5)*bounds["height"]/vh
    assert 0<px<page.viewport_size["width"] and 0<py<page.viewport_size["height"]
    page.mouse.click(px,py)

def visit(browser,url,w,h,touch=False):
    ctx=browser.new_context(viewport={"width":w,"height":h},
                            device_scale_factor=1,is_mobile=touch,has_touch=touch)
    page=ctx.new_page()
    errors=[]
    page.on("pageerror",lambda issue:errors.append(str(issue)))
    page.goto(url,wait_until="domcontentloaded",timeout=60000)
    page.locator("canvas").first.wait_for(state="visible",timeout=90000)
    marker=page.locator("#osgard-native-state")
    marker.wait_for(state="attached",timeout=90000)
    await_quality(page,marker,"hero")
    page.wait_for_timeout(1250)
    return ctx,page,marker,errors

def run(export,out,sha):
    assert len(sha)==40 and all(c in "0123456789abcdef" for c in sha)
    export=export.resolve()
    for f in ("index.html","index.js","index.wasm","index.pck","evidence.json"):
        assert (export/f).is_file(),f
    build=json.loads((export/"evidence.json").read_text(encoding="utf8"))
    assert build["source_commit"]==sha and build["godot_release"]=="4.4.1"
    out.mkdir(parents=True,exist_ok=True)
    handler=lambda *args,**kw:StaticServer(*args,directory=str(export),**kw)
    srv=http.server.ThreadingHTTPServer(("127.0.0.1",0),handler)
    threading.Thread(target=srv.serve_forever,daemon=True).start()
    report={"schema":"OSGARD_W44_SOURCE_BOUND_SW_WEBGL_PERFORMANCE_V1",
      "source_sha":sha,"status":"FAIL","renderer":"Chromium software WebGL / SwiftShader",
      "native_godot_fps_measured":True,"physical_iphone_android_tested":False,
      "physical_windows_gpu_tested":False,"AAA_60fps_certified":False,
      "hardware_comparison_inferred":False,"runs":[]}
    try:
        with sync_playwright() as p:
            browser=p.chromium.launch(headless=True,args=[
              "--enable-webgl","--ignore-gpu-blocklist","--use-angle=swiftshader",
              "--enable-unsafe-swiftshader","--disable-dev-shm-usage"])
            url=f"http://127.0.0.1:{srv.server_port}/index.html"
            try:
                ctx,page,marker,errors=visit(browser,url,1366,768)
                try:
                    report["runs"].append({"device":"desktop software Chromium",**measure(page,marker,"hero")})
                    real_quality_click(page,marker)
                    await_quality(page,marker,"eco")
                    report["runs"].append({"device":"desktop software Chromium",**measure(page,marker,"eco")})
                    assert not errors,errors
                finally:
                    ctx.close()
                ctx,page,marker,errors=visit(browser,url,390,844,True)
                try:
                    report["runs"].append({"device":"emulated phone / software Chromium",**measure(page,marker,"hero",9)})
                    assert not errors,errors
                finally:
                    ctx.close()
            finally:
                browser.close()
        assert len(report["runs"])==3
        assert all(run["render_draw_call_samples"] >= 3 and run["render_object_sample_count"] >= 3 for run in report["runs"]), "Missing real draw submission telemetry"
        report["status"]="PASS"
    finally:
        srv.shutdown()
        srv.server_close()
        (out/"godot-software-performance-evidence.json").write_text(
          json.dumps(report,indent=2,ensure_ascii=False)+"\n",encoding="utf8")
    print(json.dumps({"status":report["status"],"source_sha":sha,
                      "runs":report["runs"]},indent=2,ensure_ascii=False))

if __name__=="__main__":
    arg=argparse.ArgumentParser()
    arg.add_argument("--export",type=Path,required=True)
    arg.add_argument("--output",type=Path,required=True)
    arg.add_argument("--sha",required=True)
    opts=arg.parse_args()
    run(opts.export,opts.output,opts.sha)
