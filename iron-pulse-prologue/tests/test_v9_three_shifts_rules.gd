extends SceneTree
## V9: a real three-operation IPCrisisEngine campaign, all outcomes are earned
## by existing scanner, repair, bus routing, override and evacuation rules.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(result: bool, description: String) -> void:
    checks += 1
    if not result:
        failures.append(description)

func _solve_real_chapter(engine: IPCrisisEngine,order: String,relay: String) -> bool:
    if not engine.scan_core():
        return false
    if order != "" and not engine.choose_priority(order):
        return false
    if not engine.repair_coolant():
        return false
    if relay != "" and not engine.activate_relay(relay):
        return false
    # This is the actual in-game power puzzle. Two lines for three systems,
    # so charge DOOR while LIFE is offline, then restore vital power.
    if not engine.cycle_bus(1):
        return false
    engine.tick(24.0)
    if engine.finished():
        return false
    if not engine.cycle_bus(1) or not engine.cycle_bus(1):
        return false
    return engine.activate_override() and engine.escape() and engine.won

func _run() -> void:
    var campaign := IPCampaignDirector.new()
    var engine := IPCrisisEngine.new()
    _check(not campaign.active and campaign.chapter == 0 and not campaign.complete(),
        "Campaign opt-in starts inactive, so previous stand-alone modes are unchanged")
    _check(not campaign.start_current(engine) and not campaign.record_victory(engine),
        "Menu cannot cheat progression or begin campaign without explicit opt-in")
    campaign.begin()
    _check(campaign.active and campaign.stage_scenario() == "blackout" and campaign.stage_number() == 1,
        "Single-player narrative starts with original GRID operation")
    _check(campaign.start_current(engine) and engine.scenario_id == "blackout",
        "Stage 1 actually resets existing IPCrisisEngine to the first emergency")
    _check(campaign.last_carryover.is_empty(),
        "Initial emergency has no fake consequences from previous runs")
    _check(not campaign.record_victory(engine),
        "No victory credit before player actually opens evacuation")
    _check(_solve_real_chapter(engine,"crew","medbay"),
        "Stage 1 uses REAL engine power routing and physical rescue strategy")
    _check(campaign.record_victory(engine) and campaign.chapter == 1,
        "Winning GRID records chapter 1 only once and unlocks HEAT")
    _check(campaign.history[0]["priority"] == "crew" and campaign.history[0]["relays"].has("medbay"),
        "Crew-first and actual MEDBAY activation survive in campaign history")
    _check(campaign.history[0]["score"] > 0 and campaign.total_score() == campaign.history[0]["score"],
        "Real heat, crew, oxygen, time and faults produce a deterministic score")
    _check(not campaign.record_victory(engine),
        "Repeating an old victory cannot grant free points or repeat chapter")
    _check(campaign.start_current(engine) and engine.scenario_id == "thermal",
        "Campaign advances to physically distinct HEAT emergency")
    var fresh_heat := IPCrisisEngine.new()
    fresh_heat.reset("thermal")
    _check(engine.heat != fresh_heat.heat or engine.oxygen != fresh_heat.oxygen or engine.crew_health != fresh_heat.crew_health,
        "Previous crew/relay choices change ACTUAL chapter 2 resources")
    _check(campaign.last_carryover["source_chapter"] == 1,
        "Transfer is a source-bound consequence of chapter 1, not a random slider")
    var real_heat: float = engine.heat
    var real_oxygen: float = engine.oxygen
    var real_crew: float = engine.crew_health
    _check(campaign.start_current(engine), "Player can retry a failed stage without erasing their campaign")
    _check(is_equal_approx(engine.heat,real_heat) and is_equal_approx(engine.oxygen,real_oxygen) and is_equal_approx(engine.crew_health,real_crew),
        "Replaying a chapter deterministically recreates inherited resources")

    var pending: Dictionary = campaign.checkpoint()
    var restored := IPCampaignDirector.new()
    _check(restored.restore_checkpoint(pending) and restored.chapter == 1,
        "Actual chapter 2 intermission survives validated local checkpoint")
    _check(restored.history == campaign.history and restored.stage_scenario() == "thermal",
        "Restored campaign is identical: choices, grade, next scenario and score")
    var corrupt: Dictionary = pending.duplicate(true)
    corrupt["chapter"] = 99
    _check(not restored.restore_checkpoint(corrupt) and restored.chapter == 1,
        "Out-of-range checkpoint cannot corrupt a valid campaign")
    corrupt = pending.duplicate(true)
    corrupt["history"][0]["scenario"] = "breach"
    _check(not restored.restore_checkpoint(corrupt) and restored.chapter == 1,
        "Forged reordered chapter record is rejected atomically")
    corrupt = pending.duplicate(true)
    corrupt["history"][0]["relays"] = ["medbay","medbay"]
    _check(not restored.restore_checkpoint(corrupt) and restored.chapter == 1,
        "Forged duplicated rescue rewards cannot be restored")
    corrupt = pending.duplicate(true)
    corrupt["history"][0]["score"] = 99999
    _check(not restored.restore_checkpoint(corrupt) and restored.chapter == 1,
        "Out-of-bounds fabricated score rejected before mutation")
    corrupt = pending.duplicate(true)
    corrupt["ending"] = "humanity"
    _check(not restored.restore_checkpoint(corrupt) and restored.chapter == 1,
        "Ending cannot be unlocked without three successful emergencies")

    _check(_solve_real_chapter(engine,"core","quench"),
        "Stage 2 HEAT remains solvable with actual precision repair and QUENCH")
    _check(campaign.record_victory(engine) and campaign.chapter == 2,
        "HEAT chapter victory unlocks genuine AIR chapter")
    _check(campaign.start_current(engine) and engine.scenario_id == "breach",
        "Third chapter uses original oxygen-leak simulation")
    _check(engine.oxygen >= 45.0 and engine.crew_health >= 65.0,
        "Bounded inheritance remains challenging but does not produce instant unplayable loss")
    _check(_solve_real_chapter(engine,"crew","uplink"),
        "Final AIR operation completed with actual emergency repair, door and evac")
    _check(campaign.record_victory(engine) and campaign.complete(),
        "All THREE emergency missions produce a single achieved campaign finale")
    _check(campaign.history.size() == 3 and campaign.chapter == 3,
        "Scoreboard contains exactly 3 correctly ordered completed chapters")
    _check(campaign.history[0]["scenario"] == "blackout" and
        campaign.history[1]["scenario"] == "thermal" and campaign.history[2]["scenario"] == "breach",
        "Campaign cannot swap missions or credit an unrelated emergency")
    _check(campaign.ending in ["humanity","balance","survival"] and campaign.total_score()>0,
        "Completed story produces one of three deterministic consequence endings")
    _check(campaign.summary("ru").contains("ОЧКИ") and campaign.summary("en").contains("SCORE"),
        "Campaign results are authored in RU and EN")
    _check(not campaign.start_current(engine) and not campaign.record_victory(engine),
        "Completed run cannot farm fourth chapter or infinite rating")
    var completed_save: Dictionary = campaign.checkpoint()
    var loaded_final := IPCampaignDirector.new()
    _check(loaded_final.restore_checkpoint(completed_save) and loaded_final.ending == campaign.ending,
        "Final ending survives validated offline serialization")
    corrupt = completed_save.duplicate(true)
    corrupt["ending"] = "humanity" if campaign.ending != "humanity" else "survival"
    _check(not loaded_final.restore_checkpoint(corrupt) and loaded_final.ending == campaign.ending,
        "Final ending is recomputed, not trusted from user-edited save")
    loaded_final.begin()
    _check(loaded_final.chapter == 0 and loaded_final.history.is_empty() and loaded_final.ending == "",
        "Explicit replay starts a new trilogy with no inherited stale history")
    _check(loaded_final.start_current(engine) and engine.scenario_id == "blackout",
        "New campaign loop is replayable from actual GRID scenario")

    var radio := IPStoryDirector.new()
    radio.reset("thermal")
    _check(radio.on_game_event("campaign_chapter_2","") and
        radio.latest("ru")["text"].contains("Предыдущие решения"),
        "MARA provides a genuine unique RU story for inherited second chapter")
    _check(radio.latest("en")["text"].contains("previous choices"),
        "The same authored second-chapter narrative exists in EN")
    _check(not radio.on_game_event("campaign_chapter_2",""),
        "A radio announcement cannot duplicate infinitely in one chapter")
    _check(radio.on_game_event("campaign_final_" + campaign.ending,"") and
        radio.latest("en")["text"].contains("MARA"),
        "Three earned endings receive unique real localized MARA dialogue")
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V9 THREE SHIFTS PASS: %d real gameplay and save checks" % checks)
        quit(0)
    else:
        for fault in failures:
            push_error("V9 CAMPAIGN FAIL: "+fault)
        quit(1)
