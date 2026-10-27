#!/usr/bin/env python3
"""W65 browser: original six-incident narrative and sound toggle by REAL keys.

Does not play prerecorded music, synth in Python, call game APIs, or claim
physical speakers or consumer mobile-device certification.
"""
import argparse
import functools
import hashlib
import json
import threading
from pathlib import Path
from playwright.sync_api import sync_playwright
from w64_browser_acceptance import HTTPHandler, LocalServer, wait_state, snapshot


def check(test, description):
    if not test:
        raise AssertionError(description)


def run(export, evidence, sha):
    check(len(sha) == 40, "Exact Git SHA required")
    evidence.mkdir(parents=True, exist_ok=True)
    with LocalServer(("127.0.0.1", 0),
                     functools.partial(HTTPHandler, directory=str(export))) as http:
        threading.Thread(target=http.serve_forever, daemon=True).start()
        address = f"http://127.0.0.1:{http.server_address[1]}/index.html"
        with sync_playwright() as pw:
            browser = pw.chromium.launch(headless=True, args=[
                "--no-sandbox", "--disable-dev-shm-usage", "--enable-webgl",
                "--use-gl=angle", "--use-angle=swiftshader",
                "--enable-unsafe-swiftshader",
            ])
            context = browser.new_context(viewport={"width": 1366, "height": 900})
            page = context.new_page()
            page.goto(address, wait_until="domcontentloaded", timeout=120000)
            page.locator("#a7-cascade-native-state").wait_for(state="attached", timeout=180000)
            initial = wait_state(page, {"shift": 0, "locale": "ru",
                                        "narrative_id": "wake",
                                        "sound_muted": False, "sound_cues": 0})
            check(initial["history_count"] == 0, "No ghost actions at boot")
            page.locator("canvas").first.click(position={"x": 25, "y": 25})
            initial_shot = page.screenshot(path=str(evidence / "w65-intro-ru.png"))
            page.keyboard.press("s")
            value = wait_state(page, {"sound_muted": True})
            check(value["history_count"] == 0, "Mute toggle cannot change game")
            page.keyboard.press("1")
            value = wait_state(page, {"sound_cues": 1, "history_count": 1})
            check(value["sound_muted"] and value["metrics"]["heat"] == 42,
                  "Muted input still changes the original W63 model")
            page.keyboard.press("s")
            value = wait_state(page, {"sound_muted": False})
            check(value["history_count"] == 1, "Unmute cannot change gameplay")
            page.keyboard.press("4")
            value = wait_state(page, {"sound_cues": 2, "history_count": 2,
                                      "shift": 1, "narrative_id": "thermal"})
            check(value["metrics"]["seal"] == 64,
                  "Actual incident physical game consequence maintained")
            page.keyboard.press("l")
            value = wait_state(page, {"locale": "en", "narrative_id": "thermal"})
            check(value["shift"] == 1 and value["history_count"] == 2,
                  "English localized incident must not change state")

            page.keyboard.press("r")
            value = wait_state(page, {"shift": 0, "narrative_id": "wake",
                                      "history_count": 0, "sound_cues": 3})
            check(value["metrics"]["energy"] == 85,
                  "Reset restored original game state and story")
            winning = ["1", "4", "1", "3", "2", "4",
                       "2", "3", "1", "5", "2", "4"]
            for index, key in enumerate(winning):
                page.keyboard.press(key)
                value = wait_state(page, {"history_count": index + 1})
                check(value["sound_cues"] == index + 4,
                      "SFX requested only after actual player actions")
            final = wait_state(page, {"status": "won", "narrative_id": "won",
                                      "shift": 6, "history_count": 12})
            check(final["metrics"]["energy"] == 32 and
                  final["metrics"]["heat"] == 70,
                  "True original six-cycle winning model was not simulated")
            win_image = page.screenshot(path=str(evidence / "w65-winning-terminal-en.png"))
            check(len(win_image) > 12_000 and initial_shot != win_image,
                  "Original terminal screenshot must change visibly")
            page.set_viewport_size({"width": 390, "height": 844})
            page.wait_for_timeout(400)
            mobile = page.screenshot(path=str(evidence / "w65-mobile-story-en.png"))
            check(len(mobile) > 12_000,
                  "Actual mobile-viewport native game frame missing")
            context.close()
            browser.close()
        http.shutdown()
    pictures = []
    for file in sorted(evidence.glob("*.png")):
        pictures.append({
            "file": file.name,
            "bytes": file.stat().st_size,
            "sha256": hashlib.sha256(file.read_bytes()).hexdigest()
        })
    report = {
        "schema": "LAST_FRONTIER_W65_REAL_BROWSER_STORY_AUDIO_V1",
        "status": "PASS",
        "source_sha": sha,
        "genuine_native_godot_keyboard": True,
        "six_step_scripted_incidents": True,
        "actual_w63_twelve_decision_winning_route": True,
        "read_only_accessibility_marker": True,
        "original_sound_stream_requested_from_godot": True,
        "human_speaker_certified": False,
        "consumer_phone_certified": False,
        "production_approved": False,
        "published": False,
        "screenshots": pictures,
    }
    (evidence / "W65_BROWSER_EVIDENCE.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print("LAST FRONTIER W65 GENUINE CHROMIUM NARRATIVE / SOUND + WIN PASS:",
          len(pictures), "original game screenshots")


if __name__ == "__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--export",type=Path,required=True)
    p.add_argument("--evidence",type=Path,required=True)
    p.add_argument("--sha",required=True)
    x=p.parse_args()
    run(x.export.resolve(),x.evidence,x.sha)
