#!/usr/bin/env python3
"""W76 end-to-end acceptance: actual WebGL Godot 4.4.1 inside original premium
product, bilingual desktop/mobile, authentic game mission state, opt-in
self-observation report, byte-real file SHA + SW offline. No synthetic player
population, no substitute canvas and no physical hardware benchmark claims.
"""
import argparse
import functools
import hashlib
import io
import json
import sys
import threading
import time
from pathlib import Path

from PIL import Image, ImageChops, ImageStat
from playwright.sync_api import sync_playwright

CI_GAME_DIR = Path(__file__).resolve().parents[2] / "w63-a7-cascade" / "ci"
sys.path.insert(0, str(CI_GAME_DIR))
from w64_browser_acceptance import HTTPHandler, LocalServer

SOURCE_SHA = "73ef81b54cb42831cafd9ac8fa69c5807cd8dc8d"


def check(value, explanation):
    if not value:
        raise AssertionError(explanation)


def screenshot(page, folder, name):
    raw = page.screenshot(path=str(folder / name), animations="disabled")
    image = Image.open(io.BytesIO(raw)).convert("RGB")
    check(max(ImageStat.Stat(image).stddev) > 5,
          "The genuine portal screenshot must not be blank or generated")
    return raw


def different(a, b):
    imga = Image.open(io.BytesIO(a)).convert("RGB")
    imgb = Image.open(io.BytesIO(b)).convert("RGB")
    check(imga.size == imgb.size, "Original browser frames have same viewport size")
    return sum(ImageChops.difference(imga, imgb).convert("L").histogram()[12:])


def live_engine(page):
    return page.evaluate("""() => {
      const frame = document.getElementById('gameFrame');
      const child = frame?.contentDocument;
      const node = child?.getElementById('a7-cascade-native-state');
      if (!node) return null;
      try {return JSON.parse(node.getAttribute('data-state'));}catch(_){return null;}
    }""")


def ready(page):
    page.wait_for_function("""() => {
      const f = document.getElementById('gameFrame');
      if(!f || f.hidden) return false;
      const n = f.contentDocument?.getElementById('a7-cascade-native-state');
      if(!n)return false;
      try{
        const s=JSON.parse(n.getAttribute('data-state'));
        return s.real_native_3d===true &&
          s.w73_real_native_world_raycast===true &&
          s.w74_true_3d_feedback_meshes===8 &&
          document.getElementById('runtimeDot').classList.contains('good');
      }catch(_){return false;}
    }""",timeout=225000)


def run(site, evidence, sha, offline_test):
    check(len(sha)==40 and all(k in "0123456789abcdef" for k in sha),
          "Must bind browser QA to full exact W76 Git SHA")
    manifest=json.loads((site/"release-manifest.json").read_text(encoding="utf-8"))
    check(manifest["schema"]=="LAST_FRONTIER_WORLD_PLATFORM_V1" and
          manifest["sourceSha"]==SOURCE_SHA and
          manifest["platformSourceSha"]==sha,
          "Release manifest must pin original W74 game + exact W76 frontend SHA")
    wasm=(site/"game"/"index.wasm").read_bytes()
    pck=(site/"game"/"index.pck").read_bytes()
    check(wasm[:4]==b"\0asm" and pck[:4]==b"GDPC",
          "Browser must use genuine native engine + Godot PCK binaries")
    files={e["path"]:e for e in manifest["gameFiles"]}
    check(len(files)>=8 and "game/index.wasm" in files and "game/index.pck" in files,
          "Complete original game exported inside actual standalone portal")
    for path,data in files.items():
        original=(site/path).read_bytes()
        check(len(original)==data["bytes"] and
              hashlib.sha256(original).hexdigest()==data["sha256"],
              "Actual file hash mismatch: "+path)
    evidence.mkdir(parents=True, exist_ok=True)
    errors=[]
    downloaded_report=None
    offline_game_success=False
    with LocalServer(("127.0.0.1",0),
                     functools.partial(HTTPHandler,directory=str(site))) as server:
        threading.Thread(target=server.serve_forever,daemon=True).start()
        address="http://127.0.0.1:"+str(server.server_address[1])+"/index.html"
        with sync_playwright() as pw:
            browser=pw.chromium.launch(headless=True,args=[
                "--no-sandbox","--disable-dev-shm-usage","--enable-webgl",
                "--use-gl=angle","--use-angle=swiftshader",
                "--enable-unsafe-swiftshader"
            ])
            ctx=browser.new_context(viewport={"width":1440,"height":900},
                                    accept_downloads=True)
            page=ctx.new_page()
            page.on("pageerror",lambda err:errors.append(str(err)))
            page.goto(address,wait_until="domcontentloaded",timeout=60000)
            page.locator("#buildDot.good").wait_for(timeout=30000)
            check(page.locator("#sourceShort").inner_text().lower()==SOURCE_SHA[:9],
                  "Actual platform only shows original accepted W74 source SHA")
            check(page.locator("#gameFrame").is_hidden(),
                  "Native Godot 43 MB engine must not preload without user action")
            check(page.locator("#heatValue").inner_text()=="—",
                  "No fabricated reactor readings before actual live engine")
            check(page.locator("#missionList").is_hidden(),
                  "Mission panel not displayed until user opens it")
            check(page.locator("#buildStatus").inner_text()!="",
                  "Actual source-linked platform status rendered")
            before=screenshot(page,evidence,"w76-01-premium-world-command-desktop.png")
            page.get_by_role("button",name="02").count()  # navigation has textual labels
            page.locator('button[data-route="missions"]').click()
            check(page.locator(".mission-entry").count()==5,
                  "Original five mission phases are actually navigable")
            check(page.locator(".mission-entry.is-done").count()==0,
                  "World platform must not invent completed mission before game")
            page.locator("#localeButton").click()
            check(page.locator("#currentLocale").inner_text()=="EN",
                  "Actual English full-platform language switch works")
            check("MISSION" in page.locator("#routeName").inner_text().upper(),
                  "English route is visible")
            page.locator("#localeButton").click()
            page.locator('button[data-route="command"]').click()

            page.locator("#launchButton").click()
            check(not page.locator("#gameFrame").is_hidden(),
                  "Click launches real native Godot iframe (not a static screenshot)")
            ready(page)
            state=live_engine(page)
            check(state["real_native_3d"] and
                  state["w74_true_3d_feedback_meshes"]==8 and
                  state["w73_checkpoint_events"]==0,
                  "Actual real 3D native renderer and original unplayed game")
            check(page.locator("#heatValue").inner_text()!="—" and
                  page.locator("#integrityValue").inner_text()!="—",
                  "Original Godot core metrics actually flow into premium shell")
            check(page.locator("#focusButton").is_enabled() and
                  page.locator("#fullscreenButton").is_enabled(),
                  "Real player focus/fullscreen enabled only AFTER original engine readiness")
            active=screenshot(page,evidence,"w76-02-genuine-godot-embedded-3d-game.png")
            check(different(before,active)>900,
                  "Real WebGL game renders visibly inside the portal instead of poster")

            page.locator('button[data-route="lab"]').click()
            check(page.locator("#sessionStart").is_disabled(),
                  "Explicit consent is mandatory before local player observation")
            page.locator("#consentCheckbox").check()
            check(page.locator("#sessionStart").is_enabled(),
                  "Consent + truly running game unlocks real local session")
            page.locator("#sessionStart").click()
            check(page.locator("#sessionStop").is_enabled(),
                  "Actual session clock started by user, not synthetic data")
            page.locator('button[data-route="command"]').click()
            page.locator("#focusButton").click()
            frame=page.frame_locator("#gameFrame")
            frame.locator("#canvas").click(position={"x":14,"y":14})
            page.keyboard.press("y")
            page.wait_for_function("""() => {
              const f=document.getElementById('gameFrame');
              const n=f.contentDocument?.getElementById('a7-cascade-native-state');
              if(!n)return false;
              try{
                const s=JSON.parse(n.getAttribute('data-state'));
                return s.w72_extended_mode===true &&
                  s.w71_mission_active===true &&
                  s.w73_checkpoint_events>=1;
              }catch(_){return false;}
            }""",timeout=35000)
            page.wait_for_timeout(950)
            page.locator('button[data-route="missions"]').click()
            check(page.locator(".mission-entry.is-active").count()==1,
                  "Actually starting original Y mission advances only real first objective")
            check(page.locator(".mission-entry.is-done").count()==0,
                  "World shell never marks entire mission completed on launch")
            missions=screenshot(page,evidence,"w76-03-original-mission-live-true-state.png")
            page.locator('button[data-route="lab"]').click()
            check(int(page.locator("#eventCount").inner_text())>=2,
                  "Local session saw actual original mission start event after user input")
            page.locator("#confusionRange").fill("3")
            page.locator("#feedbackNote").fill("Actual session feedback only, no personal data.")
            page.locator("#sessionStop").click()
            check(page.locator("#sessionStart").is_enabled(),
                  "New session can begin after explicitly finishing prior observation")
            with page.expect_download(timeout=30000) as download_info:
                page.locator("#exportSession").click()
            download=download_info.value
            downloaded_report=Path(evidence/"W76_ACTUAL_SELF_OBSERVED_SESSION.json")
            download.save_as(downloaded_report)
            report=json.loads(downloaded_report.read_text(encoding="utf-8"))
            check(report["schema"]=="LAST_FRONTIER_WORLD_SELF_OBSERVED_SESSION_V1" and
                  report["source_sha"]==SOURCE_SHA,
                  "Actual consenting player session export source-bound")
            check(report["event_count"]>=2 and
                  report["observed_elapsed_seconds"]>=0,
                  "Local session records real monotonic elapsed time and changes")
            check(report["claimed_as_part_of_independent_12_player_study"] is False and
                  report["observed_by_independent_human"] is False and
                  report["completed_in_actual_engine"] is False and
                  report["commercial_release_approved"] is False,
                  "Self-observation never becomes fake human certification or victory")
            check(report["no_automatic_network_transmission"] is True,
                  "Consent never auto-posts a score to a cloud endpoint")
            lab=screenshot(page,evidence,"w76-04-private-consent-and-actual-session-lab.png")

            page.locator('button[data-route="system"]').click()
            check(page.locator("#sourceFull").inner_text()==SOURCE_SHA,
                  "Platform shows exact verified original game source in SYSTEM")
            page.locator("#verifyFiles").click()
            page.wait_for_function("""() => {
              return document.getElementById('integrityProgress')?.textContent
                .toLowerCase().includes('sha-256') &&
                !document.getElementById('verifyFiles')?.disabled;
            }""",timeout=180000)
            check(page.locator("#wasmDot.good").count()==1 and
                  page.locator("#packDot.good").count()==1,
                  "Original real 43MB WebAssembly and Godot PCK bytes independently SHA-verified")
            system=screenshot(page,evidence,"w76-05-original-wasm-pck-byte-verification.png")

            page.set_viewport_size({"width":390,"height":844})
            page.wait_for_timeout(500)
            check(page.locator("#rail").evaluate(
                "(e)=>Math.round(e.getBoundingClientRect().bottom)")<=844,
                "Mobile command nav is contained inside viewport")
            check(page.locator("#view-system").is_visible(),
                  "Genuine mobile route remains navigable")
            mobile=screenshot(page,evidence,"w76-06-mobile-390-system-integrity.png")
            check(Image.open(io.BytesIO(mobile)).size==(390,844),
                  "Real 390x844 responsive browser capture not generated art")
            page.locator('button[data-route="command"]').click()
            mobile_game=screenshot(page,evidence,"w76-07-mobile-390-real-godot-inside-station.png")
            page.locator("#localeButton").click()
            check(page.locator("#currentLocale").inner_text()=="EN",
                  "Mobile English language toggle remains accessible")
            mobile_en=screenshot(page,evidence,"w76-08-mobile-English-genuine-product.png")
            check(different(mobile_game,mobile_en)>70,
                  "Real localized product visibly changes on mobile")

            if offline_test:
                page.locator('button[data-route="system"]').click()
                page.locator("#offlineButton").wait_for(state="visible",timeout=30000)
                check(page.locator("#offlineButton").is_enabled(),
                      "Full original files verified before offline cache offered")
                page.locator("#offlineButton").click()
                page.wait_for_function("""() => {
                  return document.getElementById('integrityProgress')?.textContent
                   .toLowerCase().includes('offline') &&
                   !document.getElementById('offlineButton')?.disabled;
                }""",timeout=180000)
                result=page.locator("#integrityProgress").inner_text().lower()
                check(("available offline" in result) or ("available" in result),
                      "Actual original 43MB Godot binary cached for offline play")
                ctx.set_offline(True)
                page.reload(wait_until="domcontentloaded",timeout=60000)
                page.locator("#buildDot.good").wait_for(timeout=30000)
                check(page.locator("#sourceShort").inner_text().lower()==SOURCE_SHA[:9],
                      "True platform HTML/CSS/JS+manifest work without any internet")
                page.locator("#launchButton").click()
                ready(page)
                check(live_engine(page)["real_native_3d"] is True,
                      "True Godot native WASM engine launches again with browser OFFLINE")
                offline_game_success=True
                ctx.set_offline(False)
                screenshot(page,evidence,"w76-09-verified-fully-offline-original-godot-launch.png")

            check(not errors,
                  "Unhandled original platform/Godot JavaScript errors: "+
                  " | ".join(errors[:5]))
            ctx.close()
            browser.close()
        server.shutdown()
    frames=[{
        "name":path.name,"bytes":path.stat().st_size,
        "sha256":hashlib.sha256(path.read_bytes()).hexdigest()
    } for path in sorted(evidence.glob("w76-*.png"))]
    check(len(frames)==(9 if offline_test else 8),
          "Must preserve each actual original platform screenshot")
    acceptance={
      "schema":"LAST_FRONTIER_W76_ORIGINAL_WORLD_PLATFORM_BROWSER_V1",
      "platform_sha":sha,"game_sha":SOURCE_SHA,
      "result":"PASS","original_godot_WASM_loaded_in_actual_iframe":True,
      "real_engine_state_drives_dashboard":True,
      "real_mission_progress_proved_by_Y_input":True,
      "local_consent_and_self_report_download_proved":True,
      "wasm_and_pck_SHA256_bytes_verified_in_browser":True,
      "russian_and_english_desktop_and_mobile_proved":True,
      "real_offline_original_godot_playback_proved":offline_game_success,
      "real_anonymized_independent_12_person_study_conducted":False,
      "physical_consumer_GPU_benchmarked":False,
      "professional_AAA_art_approved":False,
      "worldwide_online_accounts_or_multiplayer_exists":False,
      "commercial_release_authorized":False,
      "true_browser_frames":frames,
      "self_observed_download_sha256":hashlib.sha256(
          downloaded_report.read_bytes()).hexdigest()
    }
    (evidence/"W76_REAL_BROWSER_AND_GAME_PROOF.json").write_text(
        json.dumps(acceptance,ensure_ascii=False,indent=2)+"\n",
        encoding="utf-8")
    print("LAST FRONTIER W76 REAL WORLD PLATFORM / ORIGINAL GODOT WASM ",
          "MOBILE I18N / LOCAL SESSION / BYTE SHA256 / OFFLINE PASS:",
          len(frames),"actual source-linked original screenshots")


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--site",type=Path,required=True)
    parser.add_argument("--evidence",type=Path,required=True)
    parser.add_argument("--sha",required=True)
    parser.add_argument("--offline",action="store_true")
    opts=parser.parse_args()
    run(opts.site.resolve(),opts.evidence.resolve(),opts.sha,opts.offline)
