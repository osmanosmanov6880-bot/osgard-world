#!/usr/bin/env python3
"""R63: verify all 40 authored missions have reachable gameplay action hooks.

This is a static wiring contract. It does not simulate player input or claim
that anyone completed the campaign. Native R55 and real WebGL/manual QA remain
separate mandatory gates.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path("godot/empire-omega/scripts")
CHAPTER_IDS = ["arrival", "builder", "world"]
CHAPTER_ENDS = [6, 20, 40]
BONUSES = [300, 650, 1200]


def authored_array(source: str, symbol: str) -> list:
    marker = f"const {symbol} = "
    if source.count(marker) != 1:
        raise AssertionError(f"Missing/duplicate authored {symbol} definition")
    tail = source.split(marker, 1)[1].lstrip()
    obj, _ = json.JSONDecoder().raw_decode(tail)
    if not isinstance(obj, list):
        raise AssertionError(f"{symbol} is not an authored array")
    return obj


def declared_actions(main: str, hud: str) -> set[str]:
    calls = re.findall(
        r"MissionManager\.register_action\s*\(([^\n)]*)\)",
        main + "\n" + hud,
    )
    if not calls:
        raise AssertionError("No original user-facing mission callbacks")
    # Supports conditional action expressions such as
    # "vehicle_select" if owned else "vehicle_buy".
    return set(re.findall(r'"([a-z_]+)"', "\n".join(calls)))


def analyze(mission_source: str, main: str, hud: str, state: str) -> dict:
    chapters = authored_array(mission_source, "CHAPTERS")
    missions = authored_array(mission_source, "MISSIONS")
    assert len(chapters) == 3, "Require exactly three existing story chapters"
    assert len(missions) == 40, "Require exactly 40 authored real campaign missions"
    assert [x["id"] for x in chapters] == CHAPTER_IDS
    assert [int(x["end"]) for x in chapters] == CHAPTER_ENDS
    assert [int(x["bonus"]) for x in chapters] == BONUSES
    start = 0
    for chapter in chapters:
        assert chapter["start"] == start, "Chapters must join without gaps/overlap"
        assert chapter["end"] > start, "Empty campaign chapter"
        start = chapter["end"]

    for i, mission in enumerate(missions):
        assert isinstance(mission, dict), f"Malformed mission {i}"
        assert re.fullmatch(r"[a-z_]+", str(mission.get("id", ""))), f"Bad action id at {i}"
        assert type(mission.get("reward")) is int and 0 < mission["reward"] < 100000, f"Invalid reward {i}"
        for language in ("ru", "en", "zh"):
            assert isinstance(mission.get(language), str) and len(mission[language]) > 5, f"Missing {language} text at {i}"

    expected = {m["id"] for m in missions}
    callbacks = declared_actions(main, hud)
    missing = sorted(expected - callbacks)
    assert not missing, "Mission actions have no real in-game trigger: " + ", ".join(missing)

    # Distinguish actual user events from a script calling register_action
    # directly in the test harness. Original main and HUD must be wired to
    # success conditions and must actually send mission results to the HUD.
    assert "MissionManager.mission_completed.connect(" in main
    assert "MissionManager.register_action(\"enter_vehicle\")" in main
    assert 'if GameState.trade_goods(id,buying,10):' in hud
    assert 'MissionManager.register_action("trade")' in hud
    assert 'if GameState.start_initiative(id):' in hud
    assert 'MissionManager.register_action("initiative_start")' in hud
    assert 'if successful:' in hud and 'MissionManager.register_action("neighborhood_accept")' in hud
    assert 'if service_result == "completed": MissionManager.register_action("service_complete")' in main
    assert 'if local_outcome == "completed": MissionManager.register_action("neighborhood_deliver")' in main
    assert 'if str(data["vehicle_selected"]) == id:' in state, "Reselecting same car must not count as an action"
    assert 'if mission["id"] != action: return false' in mission_source
    assert 'if stage >= MISSIONS.size(): return false' in mission_source
    assert 'GameState.add_reward(' in mission_source

    base_rewards = sum(m["reward"] for m in missions)
    bonuses = sum(x["bonus"] for x in chapters)
    return {
        "schema": "empire-omega-r63-campaign-action-wiring-v1",
        "engine_source_path": str(ROOT),
        "authored_missions": len(missions),
        "authored_chapters": len(chapters),
        "unique_mission_actions": len(expected),
        "covered_mission_actions": len(expected),
        "action_ids": sorted(expected),
        "base_mission_rewards": base_rewards,
        "chapter_bonuses": bonuses,
        "total_authored_rewards": base_rewards + bonuses,
        "callbacks_found_in_runtime": sorted(expected & callbacks),
        "static_input_wiring_verified": True,
        "native_event_transition_attested": False,
        "browser_input_attested": False,
        "human_40_mission_playthrough_attested": False,
        "physical_hardware_attested": False,
        "production_release_authorized": False,
    }


def self_test() -> None:
    sample = 'const MISSIONS = [{"id":"x","reward":12}]'
    assert authored_array(sample, "MISSIONS") == [{"id":"x", "reward":12}]
    assert declared_actions(
        'MissionManager.register_action("drive")',
        'MissionManager.register_action("buy" if ok else "select")'
    ) == {"drive", "buy", "select"}
    for invalid in ("const MISSIONS = nope", "const MISSIONS = {}", ""):
        try:
            authored_array(invalid, "MISSIONS")
        except (AssertionError, ValueError):
            pass
        else:
            raise AssertionError("Invalid mission registry accepted")
    print("PASS: R63 strict JSON mission parser and branch-specific action wiring parser")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test()
            return 0
        paths = {
            name: (ROOT / f"{name}.gd").read_text(encoding="utf-8")
            for name in ("mission_manager", "main", "hud", "game_state")
        }
        report = analyze(paths["mission_manager"], paths["main"], paths["hud"], paths["game_state"])
        assert report["authored_missions"] == 40
        assert report["unique_mission_actions"] == 24
        assert report["base_mission_rewards"] == 17230
        assert report["total_authored_rewards"] == 19380
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print("PASS: R63 genuine runtime action wiring for 40 authored missions, 24 action types, 3 chapters")
        print(json.dumps(report, indent=2, ensure_ascii=False))
        return 0
    except (AssertionError, OSError, ValueError, KeyError, TypeError) as exc:
        print(f"FAIL: R63 original campaign wiring: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
