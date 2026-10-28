extends SceneTree
## IRON PULSE V9 — deterministic, source-bound timed cascade game rules.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool,label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _run() -> void:
    var blocked := IPCrisisEngine.new()
    blocked.reset("blackout")
    _check(not blocked.begin_cascade(), "Cascade cannot start without original scanner and coolant repair")
    _check(blocked.cascade_state == "idle", "Rejected premature start cannot alter optional mission progress")
    blocked.scan_core()
    _check(not blocked.begin_cascade(), "Scanning alone cannot bypass actual physical repair")
    blocked.repair_coolant()
    _check(blocked.begin_cascade(), "Actual repaired reactor arms optional 78-second mission")
    _check(blocked.cascade_state == "active" and blocked.cascade_phase == 0,
        "Arming enters real ACTIVE state at phase 0")
    _check(absf(blocked.cascade_remaining-IPCrisisEngine.CASCADE_WINDOW)<0.01,
        "Real secondary mission starts with an actual 78-second deadline")
    _check(blocked.event_log.has("cascade_started"), "New challenge emits engine event for original story/radio system")
    var time_before: float = blocked.time_left
    blocked.tick(9.0)
    _check(blocked.cascade_remaining<70.0 and blocked.time_left<time_before-8.0,
        "Cascade deadline and main emergency countdown both advance in game time")
    var phase_before: int = blocked.cascade_phase
    _check(not blocked.advance_cascade("lock"), "Incorrect station order denied by authoritative game engine")
    _check(blocked.cascade_phase == phase_before, "Invalid action cannot skip ahead in mission")
    _check(blocked.advance_cascade("bridge"), "First physical BRIDGE intervention can complete after travel")
    _check(blocked.cascade_phase == 1 and blocked.last_event == "cascade_bridge",
        "Bridge action advances one real stage and announces its own radio beat")
    _check(not blocked.advance_cascade("bridge") and blocked.cascade_phase == 1,
        "One-shot bridge cannot be exploited for duplicate rewards")
    _check(blocked.advance_cascade("sync"), "Service-to-evacuation synchronizer is reachable and operable")
    _check(blocked.cascade_phase == 2 and blocked.last_event == "cascade_sync",
        "Synchronized field advances the real mission to final return path")
    var heat_before: float = blocked.heat
    var air_before: float = blocked.oxygen
    var door_before: float = blocked.door_charge
    _check(blocked.advance_cascade("lock"), "Return to A7 completes real three-node containment loop")
    _check(blocked.cascade_state == "completed" and blocked.cascade_phase == 3,
        "All three interventions record a single irreversible SUCCESS")
    _check(blocked.heat <= heat_before-14.0 and blocked.oxygen >= air_before+6.0,
        "Success measurably cools true reactor and restores actual life-support resources")
    _check(blocked.door_charge >= door_before+14.0 and blocked.event_log.has("cascade_complete"),
        "Success directly adds door-capacitor charge and story completion event")
    _check(not blocked.advance_cascade("lock") and not blocked.begin_cascade(),
        "Completed optional task cannot farm infinite resources")
    var after_once: float = blocked.heat
    blocked.tick(8.0)
    _check(blocked.cascade_state == "completed" and blocked.heat <= after_once,
        "Permanent completion remains stored; no surprise expiry after finishing")

    var timeout := IPCrisisEngine.new()
    timeout.reset("blackout")
    timeout.scan_core()
    timeout.repair_coolant()
    timeout.begin_cascade()
    timeout.advance_cascade("bridge")
    _check(timeout.cascade_phase == 1, "Partial mission progress exists before deadline")
    timeout.tick(IPCrisisEngine.CASCADE_WINDOW+3.0)
    _check(timeout.cascade_state == "failed" and timeout.cascade_remaining <= 0.01,
        "Real elapsed time independently expires optional operation")
    _check(timeout.event_log.has("cascade_failed"),
        "Expired optional operation emits irreversible loss radio story event")
    _check(not timeout.finished(), "Timed side mission failure does NOT force full game loss")
    var faults_now: int = timeout.faults
    _check(not timeout.advance_cascade("sync") and timeout.faults == faults_now+1,
        "After deadline, player cannot silently finish old cascade")
    _check(not timeout.begin_cascade(), "Only one rescue attempt per run")
    var fail_count: int = timeout.event_log.count("cascade_failed")
    timeout.tick(3.0)
    _check(timeout.event_log.count("cascade_failed") == fail_count,
        "Expired cascade never repeats its resource penalty every frame")

    # One successful run may be resumed in offline saves, not only in RAM.
    var source: Dictionary = blocked.checkpoint()
    _check(source.get("cascade_state") == "completed" and source.get("cascade_phase")==3,
        "Native checkpoint includes authoritative V9 state")
    var loaded := IPCrisisEngine.new()
    loaded.reset("breach")
    _check(loaded.restore_checkpoint(source), "New V9 state restores cleanly into same exact gameplay engine")
    var actual_json: Variant = JSON.parse_string(JSON.stringify(source))
    var json_reloaded := IPCrisisEngine.new()
    _check(actual_json is Dictionary and json_reloaded.restore_checkpoint(actual_json),
        "Actual Godot JSON integer/float conversion preserves all V9 checkpoint fields")
    _check(json_reloaded.cascade_phase == 3 and json_reloaded.cascade_state == "completed",
        "Completed physical cascade survives a genuine offline JSON roundtrip")
    _check(loaded.cascade_state=="completed" and loaded.cascade_phase==3,
        "Completed optional event persists after actual restart and save load")
    _check(loaded.scenario_id == "blackout" and loaded.relays_activated.is_empty(),
        "New episode progress does not invent earlier rescue choices")

    var active_source := IPCrisisEngine.new()
    active_source.reset("thermal")
    active_source.scan_core()
    active_source.repair_coolant()
    active_source.begin_cascade()
    active_source.advance_cascade("bridge")
    var partial: Dictionary = active_source.checkpoint()
    var resumed := IPCrisisEngine.new()
    _check(resumed.restore_checkpoint(partial), "Partially completed timed stage can be saved and resumed")
    _check(resumed.cascade_state == "active" and resumed.cascade_phase == 1 and resumed.cascade_remaining < IPCrisisEngine.CASCADE_WINDOW,
        "Pending target and correct remaining deadline survive reload")
    _check(resumed.advance_cascade("sync") and resumed.advance_cascade("lock"),
        "Restored mid-cascade mission still has a genuinely winnable path")

    # Previously verified V6/V7/V8 files do not contain V9 keys.
    var legacy: Dictionary = source.duplicate(true)
    legacy.erase("cascade_state")
    legacy.erase("cascade_phase")
    legacy.erase("cascade_remaining")
    var earlier := IPCrisisEngine.new()
    _check(earlier.restore_checkpoint(legacy), "Legacy V6–V8 save files remain backwards compatible")
    _check(earlier.cascade_state=="idle" and earlier.cascade_phase==0 and earlier.cascade_remaining==IPCrisisEngine.CASCADE_WINDOW,
        "Missing V9 fields become a fresh optional mission, not corrupt progress")

    # Reject impossible and malicious / corrupted partial progress atomically.
    var cheat: Dictionary = source.duplicate(true)
    cheat["cascade_state"] = "completed"
    cheat["cascade_phase"] = 1
    var before: Dictionary = earlier.checkpoint()
    _check(not earlier.restore_checkpoint(cheat), "Fabricated success with only one stage is rejected")
    _check(earlier.checkpoint() == before, "Invalid cascade progress never partially mutates restored resources")
    cheat = source.duplicate(true)
    cheat["cascade_state"] = "active"
    cheat["cascade_phase"] = 1.5
    _check(not earlier.restore_checkpoint(cheat), "Fractional fake stage rejected even if Godot JSON accepts floating numbers")
    cheat = source.duplicate(true)
    cheat["cascade_state"] = "active"
    cheat["cascade_phase"] = 3
    _check(not earlier.restore_checkpoint(cheat), "Active mission cannot report more phases than real nodes")
    cheat = source.duplicate(true)
    cheat["cascade_state"] = "active"
    cheat["cascade_phase"] = 1
    cheat["cascade_remaining"] = 0.0
    _check(not earlier.restore_checkpoint(cheat), "Running mission cannot be resumed with expired timer")
    cheat = source.duplicate(true)
    cheat["cascade_state"] = "completed"
    cheat["cascade_phase"] = 3
    cheat["coolant_repaired"] = false
    _check(not earlier.restore_checkpoint(cheat), "Impossible completion without basic reactor repair rejected")
    cheat = source.duplicate(true)
    cheat["cascade_state"] = "active"
    cheat["cascade_phase"] = 1
    cheat["cascade_remaining"] = float("nan")
    _check(not earlier.restore_checkpoint(cheat), "NaN challenge countdown rejected by strict checkpoint bounds")
    earlier.reset("breach")
    _check(earlier.cascade_state == "idle" and earlier.cascade_phase == 0,
        "Starting another emergency resets optional mission state")

    var narrative := IPStoryDirector.new()
    narrative.reset("thermal")
    _check(narrative.on_game_event("cascade_started","") and narrative.latest("ru")["text"].contains("КАСКАД"),
        "Original MARA gives bilingual challenge briefing")
    _check(narrative.on_game_event("cascade_bridge","") and narrative.latest("en")["text"].contains("bridge"),
        "Each real intermediate station gets authored English story response")
    _check(narrative.on_game_event("cascade_sync","") and narrative.latest("ru")["text"].contains("Синхронизация"),
        "Third operation stage receives localized Russian radio")
    _check(narrative.on_game_event("cascade_complete","") and narrative.latest_key == "cascade_complete",
        "Full success triggers independent Act 3 story resolution")
    _check(narrative.latest("en")["text"].contains("Cascade stabilized"),
        "English success voice subtitle is authored, not template content")
    _check(narrative.journal_localized("ru").contains("МАРА"),
        "Original player radio archive retains complete operation history")
    var loss_story := IPStoryDirector.new()
    loss_story.reset("thermal")
    _check(loss_story.on_game_event("cascade_failed","") and loss_story.latest("en")["text"].contains("expired"),
        "Failure delivers original narrative consequence with no mission hard lock")
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V9 CASCADE RULES PASS: %d deterministic engine/save/story checks" % checks)
        quit(0)
    else:
        for fail in failures:
            push_error("V9 CASCADE RULES FAIL: "+fail)
        quit(1)
