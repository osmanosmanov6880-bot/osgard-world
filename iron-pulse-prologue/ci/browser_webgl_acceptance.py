#!/usr/bin/env python3
"""Exercise the REAL Godot WebGL canvas, input and read-only native state.

No in-game methods are injected, no direct simulation values are modified,
no screenshots are substituted. Emulated mobile is NOT physical-device QA.
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


class QuietServer(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def frame_metrics(frame: bytes) -> dict:
    im = Image.open(io.BytesIO(frame)).convert("RGB")
    thumb = im.resize((128, 72))
    bins = {(r // 16, g // 16, b // 16) for r, g, b in thumb.getdata()}
    return {
        "width": im.width,
        "height": im.height,
        "color_bins": len(bins),
        "stddev": round(max(ImageStat.Stat(thumb).stddev), 2),
        "sha256": hashlib.sha256(frame).hexdigest(),
    }


def test_webgl(directory: Path, output: Path, source_sha: str) -> dict:
    assert len(source_sha) == 40 and all(c in "0123456789abcdef" for c in source_sha), "Need exact source SHA"
    for name in ("index.html", "index.js", "index.pck", "index.wasm"):
        assert (directory / name).is_file(), f"Not a real Godot WebGL export: {name}"
    directory = directory.resolve()
    output.mkdir(parents=True, exist_ok=True)
    handler = lambda *a, **kw: QuietServer(*a, directory=str(directory), **kw)
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{httpd.server_port}/index.html"
    report = {
        "schema": "IRON_PULSE_BLACKOUT_WEBGL_PLAYER_INPUT_V1",
        "source_sha": source_sha,
        "real_godot_export": True,
        "physical_device_certified": False,
        "production_ready": False,
        "status": "FAIL",
        "screens": [],
    }
    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True, args=[
                "--enable-webgl", "--ignore-gpu-blocklist", "--use-angle=swiftshader",
                "--enable-unsafe-swiftshader", "--disable-dev-shm-usage",
            ])
            try:
                targets = [
                    ("desktop", {"width": 1366, "height": 768}, False),
                    ("touch-emulation", {"width": 390, "height": 844}, True),
                ]
                for name, size, mobile in targets:
                    ctx = browser.new_context(viewport=size, is_mobile=mobile, has_touch=mobile,
                                              device_scale_factor=1)
                    page = ctx.new_page()
                    exceptions = []
                    page.on("pageerror", lambda error: exceptions.append(str(error)))
                    try:
                        page.goto(url, wait_until="domcontentloaded", timeout=60000)
                        canvas = page.locator("canvas").first
                        canvas.wait_for(state="visible", timeout=90000)
                        marker = page.locator("#iron-pulse-native-state")
                        marker.wait_for(state="attached", timeout=120000)
                        idle = {}
                        # Godot starts at its configured 1280x720 logical size,
                        # then asynchronously adopts the actual browser viewport.
                        # The additional native art can make that transition take
                        # multiple real rendered frames on SwiftShader; DO NOT
                        # accept an initial 1280x720 as final, or silently scale
                        # the game to fake a mobile pass.
                        observed_viewports = []
                        deadline = time.monotonic() + 100
                        while time.monotonic() < deadline:
                            idle = json.loads(marker.get_attribute("data-state", timeout=10000))
                            native = idle.get("viewport", [])
                            if native and (not observed_viewports or observed_viewports[-1] != native):
                                observed_viewports.append(native)
                            resized = (len(native) == 2 and
                                       abs(native[0]-size["width"]) <= 2.0 and
                                       abs(native[1]-size["height"]) <= 2.0)
                            if int(idle.get("godot_frames_drawn", 0)) >= 2 and resized:
                                break
                            page.wait_for_timeout(250)
                        report.setdefault("viewport_transitions", {})[name] = observed_viewports
                        assert idle["scene"] == "IRON_PULSE_BLACKOUT", idle
                        assert idle["started"] is False and idle["intro_visible"] is True, idle
                        assert idle["objective"] == "scan", idle
                        assert idle["godot_frames_drawn"] >= 1, idle
                        assert idle["locale"] == "ru", idle
                        assert idle.get("soundscape_ready") is True, idle
                        assert idle.get("cinematic_details",{}).get("instanced_detail_count",0) >= 270, idle
                        assert idle.get("cinematic_details",{}).get("safety_signs",0) >= 3, idle
                        # V5 world is actual imported GPU-backed Godot geometry.
                        # Inspect read-only scene data; never construct fake visuals in browser QA.
                        world = idle.get("world_sectors",{})
                        assert world.get("zone_count") == 3, ("Three physically separate zones missing",world)
                        assert world.get("sign_count") == 3 and world.get("geometry_count",0) >= 40, (
                            "Physical wayfinding or architectural silhouettes missing",world)
                        assert world.get("instanced_detail_count") == 108 and world.get("single_draw_deck") is True, (
                            "Optimized repeated world geometry was lost",world)
                        # V7: verify three real scripted physical relay positions
                        # are present inside the exported WebGL game, not injected.
                        assert idle.get("relay_3d_terminals") == 3, (
                            "Rescue relay consoles absent from actual exported 3D scene",idle)
                        positions = idle.get("relay_positions",[])
                        assert len(positions)==3 and [p[0] for p in positions] == ["medbay","quench","uplink"], (
                            "3D relay identifiers differ from source gameplay",positions)
                        assert abs(positions[0][2]+23.0)<0.1 and abs(positions[1][2]+39.5)<0.1 and abs(positions[2][2]+53.0)<0.1, (
                            "Relays have no physical presence at required locations",positions)
                        assert idle.get("relay_count",0)==0 and idle.get("thermal_shield") is False, (
                            "Rescue budget silently pre-spent before real player action",idle)
                        report.setdefault("v7_real_rescue_world",{})[name] = {
                            "real_relay_positions":positions,
                            "available_slots":2
                        }
                        # V8 must render a NEW 15m side reactor chamber,
                        # not just rename old corridor meshes or substitute CGI.
                        bay = idle.get("reactor_atrium", {})
                        assert bay.get("security_director_camera") is True and bay.get("plasma_shader_live") is True, (
                            "New real in-engine observation camera or procedural plasma material missing",bay)
                        assert bay.get("open_core_inspection") is True, (
                            "Physical front armour still covers the live plasma reactor",bay)
                        hero = idle.get("reactor_hero",{})
                        assert hero.get("core_sphere_radius",0.0)>=1.20 and hero.get("support_piers")==4, (
                            "Real WebGL sphere not enlarged or obstructing solid plinth still used",hero)
                        assert len(hero.get("ring_profiles",[]))==3 and max(hero["ring_profiles"])<=0.061, (
                            "Original 3D containment rings remained oversized neon strips",hero)
                        assert hero.get("front_light_power",0.0)>2.0, (
                            "No physical key light illuminates the reactor",hero)
                        assert hero.get("halo_camera_alignment",0.0)>=0.93, (
                            "Camera sees the original 3D containment halo edge-on as a huge cyan obstruction",hero)
                        report.setdefault("v8_4_hero_visual",{})[name]=hero
                        # V8.6: inspect only source-bound Godot scene geometry.
                        # Never fabricate environmental FX or alter gameplay state.
                        containment = idle.get("containment_fx",{})
                        assert containment.get("physical_vent_modules")==3 and containment.get("shutters_animated")==3, (
                            "Physical A7 relief vent scene not attached to real exported game",containment)
                        assert containment.get("steam_puffs_original")==18 and containment.get("thermal_spark_instances")==16, (
                            "Procedural vapor or instanced emergency spark meshes missing",containment)
                        assert containment.get("spark_instanced_draw_groups")==1, (
                            "Emergency surge spark renderer must use one MultiMesh group",containment)
                        assert containment.get("quality")==("eco" if mobile else "hero"), (
                            "Low-end/mobile hardware budgets are ignored by real reactor FX",containment)
                        assert containment.get("vapor_visible") is False and containment.get("spark_burst_visible") is False, (
                            "False catastrophe effects appear on the idle scenario menu",containment)
                        report.setdefault("v8_6_reactive_world",{})[name]=containment
                        assert bay.get("open_core_inspection") is True, (
                            "V8.3 reactor remains obscured by front armour despite successful render",bay)
                        assert bay.get("cinematic_vault") is True, (
                            "Actual 3D reactor atrium missing from Godot scene",bay)
                        assert bay.get("vault_height_m",0)>=14.0 and bay.get("open_wall_span_m",0)>=21.0, (
                            "Monumental room dimensions were not authored",bay)
                        assert bay.get("core_center",[0])[0]>10.0, (
                            "Reactor was not relocated beyond old corridor wall",bay)
                        assert float(idle.get("reactor_framing_alignment",-1.0)) > 0.96, (
                            "The cinematic reactor was built but is NOT centered in the actual playable first-person shot",idle.get("reactor_framing_alignment"))
                        assert bay.get("monumental_geometry",0)>=125 and bay.get("instanced_fasteners")==216, (
                            "Physical reactor shell/draw-call optimized detail missing",bay)
                        assert bay.get("pbr_texture_maps")==3 and bay.get("physical_guardrail_colliders")==1, (
                            "Original PBR assets or real physics guardrail missing",bay)
                        assert bay.get("moving_rotors")==3 and bay.get("diegetic_signs")==3, (
                            "Real moving containment rings and in-world signs missing",bay)
                        expected_quality = "eco" if mobile else "hero"
                        assert bay.get("quality")==expected_quality and bay.get("hero_visible") is (not mobile), (
                            "Phone/HERO performance budget did not affect new reactor",bay)
                        report.setdefault("v8_reactor_megastructure",{})[name]={
                            "room_height_m":bay["vault_height_m"],
                            "view_opening_m":bay["open_wall_span_m"],
                            "core_center":bay["core_center"],
                            "monumental_meshes":bay["monumental_geometry"],
                            "instanced_steel_fasteners":bay["instanced_fasteners"],
                            "original_pbr_maps":bay["pbr_texture_maps"],
                            "guardrail_physics":bay["physical_guardrail_colliders"],
                            "render_quality":bay["quality"]
                        }
                        assert idle.get("world_sector") == "reactor",(
                            "Player starts in wrong world area",idle.get("world_sector"))
                        assert world.get("quality") in ("hero","eco"),world
                        report.setdefault("v5_world_geometry",{})[name] = {
                            "sectors":world.get("landmark_ids"),
                            "independent_structures":world.get("geometry_count"),
                            "instanced_parts":world.get("instanced_detail_count"),
                            "quality":world.get("quality")
                        }
                        assert idle.get("vitals_visible") is (not mobile), idle
                        # Actual real-canvas UI rectangles, not a fabricated CSS layout.
                        cards = idle.get("hud_rects", {})
                        assert all(name in cards for name in ("header","telemetry","vitals","prompt")), (
                            "Missing source-bound native HUD geometry",cards)
                        header, telemetry = cards["header"], cards["telemetry"]
                        prompt = cards["prompt"]
                        assert header[1] + header[3] <= telemetry[1] - 4, (
                            "Header overlaps mission telemetry",name,header,telemetry)
                        assert telemetry[1] + telemetry[3] < prompt[1] - 22, (
                            "Mission telemetry obstructs gameplay/prompt",name,telemetry,prompt)
                        for title, rect in (("header",header),("telemetry",telemetry),("prompt",prompt)):
                            assert rect[0] >= 0 and rect[0] + rect[2] <= size["width"] + 3, (
                                "HUD card falls outside real viewport",name,title,rect,size)
                        if mobile:
                            assert header[2] >= 280 and telemetry[2] >= 280, (
                                "Phone HUD too narrow for readable localized type",header,telemetry)
                        else:
                            vitals = cards["vitals"]
                            assert header[0]+header[2] <= vitals[0]-20, (
                                "Desktop objective and vital bars collide",header,vitals)
                        report.setdefault("hud_layout",{})[name] = cards
                        # A visible canvas is not enough: Godot must lay out HUD in
                        # real CSS pixel coordinates, not shrink a 1280px desktop
                        # scene to 390px and pretend the touch buttons are usable.
                        native_view = idle["viewport"]
                        assert abs(native_view[0] - size["width"]) <= 2.0, (
                            "Godot viewport shrunk horizontally: unreadable text", native_view, size)
                        assert abs(native_view[1] - size["height"]) <= 2.0, (
                            "Godot viewport stretched vertically: inaccessible touch UI", native_view, size)
                        if mobile:
                            assert idle["touch_controls_visible"] is True, idle
                            rectangles = idle.get("touch_button_rects", {})
                            assert len(rectangles) >= 6, idle
                            for label in ("W", "A", "S", "D", "USE / E", "L / RU-EN", "FAST / Q", "J / LOG"):
                                rect = rectangles[label]
                                # Read actual native Control rectangles, then compare
                                # against the real CSS pixel scaling on this device.
                                real_width = rect[2] * size["width"] / native_view[0]
                                real_height = rect[3] * size["height"] / native_view[1]
                                assert real_width >= 44 and real_height >= 44, (
                                    "Touch target too small in browser pixels", label, rect,
                                    real_width, real_height)
                                assert rect[1] + rect[3] < cards["prompt"][1] - 1, (
                                    "Mobile touch target obstructed by prompt card",label,rect,cards["prompt"])
                        # Real Godot input: three different emergencies selected
                        # with genuine native Button clicks/taps, not state injection.
                        selector_rects = idle.get("scenario_button_rects", {})
                        assert set(selector_rects) == {"blackout","thermal","breach"}, (
                            "Three actual mission-selection buttons missing",selector_rects)
                        assert idle.get("scenario") == "blackout",idle
                        for scenario_id,expected_key,expected_value in (
                            ("thermal","heat",72.0),
                            ("breach","oxygen",68.0),
                            ("blackout","heat",48.0),
                        ):
                            fresh = json.loads(marker.get_attribute("data-state",timeout=10000))
                            rect = fresh["scenario_button_rects"][scenario_id]
                            canvas_box = canvas.bounding_box()
                            assert canvas_box is not None,("No physical Godot canvas",name)
                            tap_x = canvas_box["x"] + (rect[0]+rect[2]/2)*canvas_box["width"]/fresh["viewport"][0]
                            tap_y = canvas_box["y"] + (rect[1]+rect[3]/2)*canvas_box["height"]/fresh["viewport"][1]
                            assert 0 <= tap_x <= size["width"] and 0 <= tap_y <= size["height"],(
                                "Scenario button is clipped",scenario_id,name,rect,(tap_x,tap_y))
                            if mobile:
                                page.touchscreen.tap(tap_x,tap_y)
                            else:
                                page.mouse.click(tap_x,tap_y)
                            deadline = time.monotonic()+24
                            changed={}
                            while time.monotonic()<deadline:
                                changed=json.loads(marker.get_attribute("data-state",timeout=10000))
                                if changed.get("scenario")==scenario_id:
                                    break
                                page.wait_for_timeout(200)
                            assert changed.get("scenario")==scenario_id,(
                                "Real mission picker click/tap failed",name,scenario_id,changed)
                            assert abs(float(changed[expected_key])-expected_value)<0.1,(
                                "Mission selection did not change simulation conditions",scenario_id,changed)
                            assert changed.get("started") is False,(
                                "Scenario button accidentally started the game",scenario_id,changed)
                        report.setdefault("real_scenario_picker",{})[name] = "3/3 native clicks PASS"
                        page.keyboard.press("Enter")
                        deadline = time.monotonic() + 45
                        state = {}
                        while time.monotonic() < deadline:
                            state = json.loads(marker.get_attribute("data-state", timeout=10000))
                            if state.get("started") is True:
                                break
                            page.wait_for_timeout(200)
                        assert state.get("started") is True, f"Enter did not start game on real canvas: {state}"
                        # V6: the actual renderer must display original MARA dialogue.
                        # This introspection is read-only; keyboard/touch below are real inputs.
                        narrative = state.get("story",{})
                        assert narrative.get("latest_key") == "arrival_blackout", (
                            "Wrong chapter opening after real scenario selection",narrative)
                        assert narrative.get("journal_entries",0) >= 1 and state.get("radio_visible") is True, (
                            "Story radio not truly visible after starting game",narrative,state)
                        assert state.get("priority_visible") is False, (
                            "Crew/core priority offered before real scanner",state)
                        assert "МАРА" in state.get("radio_text","") or "MARA" in state.get("radio_text",""), (
                            "No authored radio subtitles shown in Godot",state.get("radio_text"))
                        # Capture an extra BEFORE-controls gameplay camera frame
                        # to compare the central scene's art evolution fairly.
                        # The image is a direct Chromium screenshot of the actual
                        # exported Godot canvas; no altered/composited stills.
                        page.wait_for_timeout(900)
                        hero_png = page.screenshot(timeout=60000,animations="disabled")
                        hero_stats = frame_metrics(hero_png)
                        assert hero_stats["color_bins"] >= 12 and hero_stats["stddev"] > 7,hero_stats
                        hero_name = "hero-"+name+".png"
                        (output / hero_name).write_bytes(hero_png)
                        report.setdefault("hero_frame_evidence",{})[name]={
                            **hero_stats,"image":hero_name,
                            "source":"actual_godot_webgl_chromium",
                            "not_a_render_mockup":True
                        }
                        # V8: a cinematic frame must come from actual real-input
                        # Godot gameplay with the HUD removed through the player's
                        # C key, not from a generated render or altered screenshot.
                        if not mobile:
                            page.keyboard.press("c")
                            deadline=time.monotonic()+20
                            clean={}
                            while time.monotonic()<deadline:
                                clean=json.loads(marker.get_attribute("data-state",timeout=10000))
                                if clean.get("cinematic_view") is True:
                                    break
                                page.wait_for_timeout(150)
                            assert clean.get("cinematic_view") is True and clean.get("cinematic_hud_hidden") is True, (
                                "C did not genuinely remove the in-game HUD",clean)
                            assert clean.get("active_camera") == "A7_ServiceObservationCamera" and clean.get("director_camera_alignment",0) > 0.995, (
                                "C must select physical camera aimed at real reactor, not just hide HUD",clean)
                            # Camera is physically mounted in the actual rendered
                            # gallery facing the real reactor. No CSS/art overlays
                            # or simulated stills are ever substituted.
                            page.wait_for_timeout(900)
                            pure_image=page.screenshot(timeout=60000,animations="disabled")
                            pure_stats=frame_metrics(pure_image)
                            assert pure_stats["color_bins"] >= 12 and pure_stats["stddev"] > 7, pure_stats
                            (output/"cinematic-reactor-desktop.png").write_bytes(pure_image)
                            report["v8_cinematic_camera_proof"]={
                                **pure_stats,
                                "image":"cinematic-reactor-desktop.png",
                                "input":"real keyboard C + in-world Godot 3D director camera",
                                "active_camera":clean.get("active_camera"),
                                "camera_alignment":clean.get("director_camera_alignment"),
                                "source":"actual_godot_webgl_chromium",
                                "hdr_overlays_hidden":True
                            }
                            page.keyboard.press("c")
                            deadline=time.monotonic()+20
                            restored={}
                            while time.monotonic()<deadline:
                                restored=json.loads(marker.get_attribute("data-state",timeout=10000))
                                if restored.get("cinematic_view") is False:
                                    break
                                page.wait_for_timeout(150)
                            assert restored.get("cinematic_view") is False and restored["started"] is True, (
                                "C did not restore the working real HUD",restored)
                            assert restored.get("active_camera") == "FirstPersonCamera", (
                                "C must restore original player camera and controls",restored)
                        # Verify both opening and closing the actual journal.
                        if mobile:
                            journal_rect = state["touch_button_rects"]["J / LOG"]
                            canvas_bounds = canvas.bounding_box()
                            assert canvas_bounds is not None
                            jx = canvas_bounds["x"] + (journal_rect[0]+journal_rect[2]/2)*canvas_bounds["width"]/state["viewport"][0]
                            jy = canvas_bounds["y"] + (journal_rect[1]+journal_rect[3]/2)*canvas_bounds["height"]/state["viewport"][1]
                            page.touchscreen.tap(jx,jy)
                        else:
                            page.keyboard.press("j")
                        deadline = time.monotonic()+20
                        while time.monotonic()<deadline:
                            state=json.loads(marker.get_attribute("data-state",timeout=10000))
                            if state.get("journal_visible") is True:
                                break
                            page.wait_for_timeout(200)
                        assert state.get("journal_visible") is True and state.get("paused") is True, (
                            "Actual radio journal failed to pause game",name,state)
                        if mobile:
                            close_rect=state["journal_close_rect"]
                            bounds=canvas.bounding_box()
                            assert bounds is not None
                            page.touchscreen.tap(
                                bounds["x"]+(close_rect[0]+close_rect[2]/2)*bounds["width"]/state["viewport"][0],
                                bounds["y"]+(close_rect[1]+close_rect[3]/2)*bounds["height"]/state["viewport"][1])
                        else:
                            page.keyboard.press("Escape")
                        deadline = time.monotonic()+20
                        while time.monotonic()<deadline:
                            state=json.loads(marker.get_attribute("data-state",timeout=10000))
                            if state.get("journal_visible") is False and state.get("paused") is False:
                                break
                            page.wait_for_timeout(200)
                        assert state.get("journal_visible") is False and state.get("paused") is False, (
                            "Actual radio journal could not be closed",name,state)
                        report.setdefault("v6_real_radio",{})[name] = "original localized subtitles and native journal PASS"
                        if mobile:
                            # Genuine mobile tap through Chromium's touchscreen,
                            # on the actual Godot Button; never call the locale
                            # setter or write a synthetic result to the game.
                            rect = state["touch_button_rects"]["L / RU-EN"]
                            canvas_box = canvas.bounding_box()
                            assert canvas_box is not None
                            tap_x = canvas_box["x"] + (rect[0]+rect[2]/2)*canvas_box["width"]/state["viewport"][0]
                            tap_y = canvas_box["y"] + (rect[1]+rect[3]/2)*canvas_box["height"]/state["viewport"][1]
                            page.touchscreen.tap(tap_x,tap_y)
                            deadline = time.monotonic() + 25
                            while time.monotonic() < deadline:
                                state = json.loads(marker.get_attribute("data-state", timeout=10000))
                                if state.get("locale") == "en":
                                    break
                                page.wait_for_timeout(200)
                            assert state.get("locale") == "en", ("Mobile language button does not work", state)
                        if not mobile:
                            origin = state["player_position"][2]
                            page.keyboard.down("w")
                            try:
                                deadline = time.monotonic() + 30
                                while time.monotonic() < deadline:
                                    state = json.loads(marker.get_attribute("data-state", timeout=10000))
                                    if state["player_position"][2] < origin - 0.35:
                                        break
                                    page.wait_for_timeout(200)
                            finally:
                                page.keyboard.up("w")
                            assert state["player_position"][2] < origin - 0.35, (origin, state)
                            # Verify real 3D detail and motion/audio accessibility via
                            # real Chromium keys; only read Godot state, never modify it.
                            for key, property_name, expected in (
                                ("g","quality_mode","eco"),
                                ("v","reduced_motion",True),
                                ("m","audio_muted",True),
                            ):
                                page.keyboard.press(key)
                                deadline = time.monotonic() + 25
                                while time.monotonic() < deadline:
                                    state = json.loads(marker.get_attribute("data-state",timeout=10000))
                                    if state.get(property_name) == expected:
                                        break
                                    page.wait_for_timeout(200)
                                assert state.get(property_name) == expected,(key,property_name,state)
                                if key=="g":
                                    assert state.get("reactor_atrium",{}).get("quality") == expected, (
                                        "G button did not switch actual V8 vaulted reactor geometry",state.get("reactor_atrium"))
                                    assert state.get("containment_fx",{}).get("quality") == expected, (
                                        "G button did not scale procedural pressure vents/steam",state.get("containment_fx"))
                                    if expected=="eco":
                                        assert state.get("containment_fx",{}).get("vapor_visible") is False, (
                                            "ECO retained heavyweight vapor rendering",state.get("containment_fx"))
                            page.keyboard.press("g")
                            page.keyboard.press("m")
                            page.keyboard.press("v")
                            page.keyboard.press("l")
                            deadline = time.monotonic() + 20
                            while time.monotonic() < deadline:
                                state = json.loads(marker.get_attribute("data-state", timeout=10000))
                                if state["locale"] == "en":
                                    break
                                page.wait_for_timeout(200)
                            assert state["locale"] == "en", state
                            page.keyboard.press("Escape")
                            deadline = time.monotonic() + 20
                            while time.monotonic() < deadline:
                                state = json.loads(marker.get_attribute("data-state", timeout=10000))
                                if state.get("paused"):
                                    break
                                page.wait_for_timeout(200)
                            assert state.get("paused") is True, state
                            page.keyboard.press("Escape")
                        # Also enforce resize AFTER gameplay/touch and toggling
                        # graphics: older builds briefly reported a correct
                        # viewport at boot, then regressed to 1280px on mobile.
                        final_view = state.get("viewport", [])
                        assert len(final_view) == 2 and abs(final_view[0]-size["width"]) <= 2.0 and abs(final_view[1]-size["height"]) <= 2.0, (
                            "Viewport regressed after real gameplay",name,final_view,size,state.get("godot_frames_drawn"))
                        page.wait_for_timeout(1800)
                        png = page.screenshot(timeout=60000, animations="disabled")
                        stats = frame_metrics(png)
                        assert stats["width"] == size["width"] and stats["height"] == size["height"], stats
                        assert stats["color_bins"] >= 12 and stats["stddev"] > 7, ("blank native Godot canvas", stats)
                        assert not exceptions, exceptions
                        filename = name + ".png"
                        (output / filename).write_bytes(png)
                        report["screens"].append({"device": name, "status": "PASS", **stats,
                                                  "screenshot": filename,
                                                  "initial_frames": idle["godot_frames_drawn"],
                                                  "last_native_state": state})
                    finally:
                        ctx.close()
            finally:
                browser.close()
        report["status"] = "PASS"
    finally:
        httpd.shutdown()
        httpd.server_close()
        (output / "webgl-evidence.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--export", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--sha", required=True)
    args = parser.parse_args()
    result = test_webgl(args.export, args.evidence, args.sha)
    assert result["status"] == "PASS"
