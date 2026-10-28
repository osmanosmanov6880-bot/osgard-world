extends SceneTree
## V9 source-bound deterministic game-engine QA for the optional three-sector
## containment circuit. Existing evacuation and checkpoints must still work.
var checks: int = 0
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, meaning: String) -> void:
    checks += 1
    if not condition:
        errors.append(meaning)

func _route(engine: IPCrisisEngine, sequence: Array[String]) -> void:
    for id in sequence:
        _check(engine.operate_containment_coil(id),
            "Real correct circuit coil accepted: "+engine.scenario_id+"/"+id)

func _run() -> void:
    var initial := IPCrisisEngine.new()
    initial.reset("blackout")
    _check(not initial.operate_containment_coil("alpha"),
        "No power routing before actual reactor scan")
    _check(initial.containment_sequence.is_empty() and not initial.containment_online,
        "Premature button cannot activate optional route")
    initial.scan_core()
    _check(not initial.operate_containment_coil("unknown"),
        "Invalid coil ID rejected without arbitrary execution")
    _check(initial.next_containment_coil() == "alpha",
        "GRID opens physically at ALPHA with visible next-coil clue")

    var thermal := IPCrisisEngine.new()
    thermal.reset("thermal")
    thermal.scan_core()
    thermal.heat = 75.0
    thermal.oxygen = 64.0
    thermal.door_charge = 14.0
    _check(thermal.next_containment_coil()=="beta", "HEAT actually needs BETA first")
    _check(thermal.operate_containment_coil("beta"), "First HEAT BETA correct")
    _check(thermal.last_event == "containment_stage" and thermal.containment_sequence == ["beta"],
        "First real coil records authored staged event and physical lock")
    var active_deadline: float = thermal.containment_deadline
    _check(active_deadline > thermal.elapsed+70.0,
        "First coil starts a finite 85s synchronization time window")
    _check(thermal.operate_containment_coil("alpha"), "HEAT follows BETA with ALPHA")
    var before_heat: float = thermal.heat
    var before_air: float = thermal.oxygen
    var before_door: float = thermal.door_charge
    _check(thermal.operate_containment_coil("gamma"), "Final HEAT GAMMA closes real circuit")
    _check(thermal.containment_online and thermal.containment_sequence == ["beta","alpha","gamma"],
        "Completed full 3-sector sequence persists as online not a temporary HUD animation")
    _check(thermal.last_event == "containment_online" and thermal.containment_deadline == 0.0,
        "Success closes time window and emits distinct authored narrative event")
    _check(thermal.heat < before_heat-14.0 and thermal.oxygen > before_air+8.0 and thermal.door_charge > before_door+11.0,
        "Circuit grants real heat, life support, and evacuation capacitor recovery")
    _check(not thermal.operate_containment_coil("gamma") and thermal.containment_online,
        "Cannot farm duplicate rewards after successful routing")

    var failed := IPCrisisEngine.new()
    failed.reset("blackout")
    failed.scan_core()
    var start_heat: float = failed.heat
    var start_air: float = failed.oxygen
    var start_faults: int = failed.faults
    _check(not failed.operate_containment_coil("beta"), "Wrong first coil does not succeed")
    _check(failed.last_event == "containment_misroute" and failed.containment_sequence.is_empty(),
        "Wrong route resets 3D sequence and produces real fault event")
    _check(failed.heat > start_heat+5.0 and failed.oxygen < start_air-3.0 and failed.faults == start_faults+1,
        "Wrong route has measurable heat/oxygen/fault costs, not a decorative shake")
    _route(failed,["alpha","gamma","beta"])
    _check(failed.containment_online, "Correct GRID routing remains attainable after a misroute")
    _check(failed.next_containment_coil() == "", "Completed circuit advertises no additional target")

    var timed := IPCrisisEngine.new()
    timed.reset()
    timed.scan_core()
    timed.operate_containment_coil("alpha")
    _check(timed.containment_sequence.size()==1 and timed.containment_deadline>0.0,
        "Incomplete time-bounded route exists as actual gameplay state")
    timed.tick(IPCrisisEngine.CONTAINMENT_WINDOW+1.0)
    _check(timed.containment_sequence.is_empty() and timed.containment_deadline == 0.0,
        "Real elapsed gameplay seconds expire incomplete circuit route")
    _check(timed.last_event == "containment_expired" and not timed.containment_online,
        "Route timeout is a real narrative/game event with no free stabilization")

    var breath := IPCrisisEngine.new()
    breath.reset("breach")
    breath.scan_core()
    _check(breath.next_containment_coil() == "gamma", "AIR starts at the evacuation side GAMMA")
    _route(breath,["gamma","beta","alpha"])
    _check(breath.containment_online, "AIR requires a physically different full-route solution")

    var energized := IPCrisisEngine.new()
    var baseline := IPCrisisEngine.new()
    energized.reset()
    baseline.reset()
    energized.scan_core()
    baseline.scan_core()
    energized.repair_coolant()
    baseline.repair_coolant()
    _route(energized,["alpha","gamma","beta"])
    energized.heat = 75.0
    baseline.heat = 75.0
    energized.oxygen = 90.0
    baseline.oxygen = 90.0
    energized.tick(10.0)
    baseline.tick(10.0)
    _check(energized.heat < baseline.heat-2.0,
        "Completed coil network increases REAL continuous cooling, not a one-time bonus")
    _check(energized.diagnostic_snapshot()["containment_online"] and energized.diagnostic_snapshot()["containment_step"]==3,
        "Real read-only telemetry matches activated game systems")

    var saved_progress := IPCrisisEngine.new()
    saved_progress.reset("blackout")
    saved_progress.scan_core()
    saved_progress.operate_containment_coil("alpha")
    var partial: Dictionary = saved_progress.checkpoint()
    var resumed := IPCrisisEngine.new()
    _check(resumed.restore_checkpoint(partial), "Partial V9 route is saved and restored natively")
    _check(resumed.containment_sequence == ["alpha"] and resumed.containment_deadline > resumed.elapsed,
        "Restored window retains original deadline, not unlimited extra time")
    resumed.operate_containment_coil("gamma")
    resumed.operate_containment_coil("beta")
    _check(resumed.containment_online, "Player may finish actual route after offline checkpoint resume")
    var complete: Dictionary = resumed.checkpoint()
    var complete_resume := IPCrisisEngine.new()
    _check(complete_resume.restore_checkpoint(complete) and complete_resume.containment_online,
        "Completed stabilization survives legitimate checkpoint restart")
    _check(complete_resume.next_containment_coil()=="", "Restored online network never reopens its rewards")

    var old_v8: Dictionary = partial.duplicate(true)
    old_v8.erase("containment_sequence")
    old_v8.erase("containment_online")
    old_v8.erase("containment_deadline")
    var compatible := IPCrisisEngine.new()
    _check(compatible.restore_checkpoint(old_v8),
        "Every genuine V6–V8 checkpoint missing V9 fields remains compatible")
    _check(compatible.containment_sequence.is_empty() and not compatible.containment_online,
        "Legacy games restore with inactive optional V9 circuit, not forged rewards")

    var corrupt: Dictionary = complete.duplicate(true)
    corrupt["containment_sequence"] = ["alpha","beta","gamma"]
    _check(not compatible.restore_checkpoint(corrupt),
        "Forged full-route order for current scenario rejected atomically")
    _check(not compatible.containment_online and compatible.containment_sequence.is_empty(),
        "Invalid checkpoint leaves active game untouched")
    corrupt = complete.duplicate(true)
    corrupt["containment_sequence"] = ["alpha","gamma"]
    _check(not compatible.restore_checkpoint(corrupt),
        "Online reward without complete three-phase route rejected")
    corrupt = partial.duplicate(true)
    corrupt["containment_deadline"] = 0.0
    _check(not compatible.restore_checkpoint(corrupt),
        "Unlimited partial-route exploit rejected by checkpoint validator")
    corrupt = partial.duplicate(true)
    corrupt["containment_sequence"] = ["alpha","alpha"]
    _check(not compatible.restore_checkpoint(corrupt),
        "Duplicate/incorrect prefix exploit rejected by exact route validator")
    corrupt = partial.duplicate(true)
    corrupt["core_scanned"] = false
    _check(not compatible.restore_checkpoint(corrupt),
        "Unscanned player cannot inject artificial containment progress")
    corrupt = partial.duplicate(true)
    corrupt["elapsed"] = float(corrupt["containment_deadline"])+0.01
    _check(not compatible.restore_checkpoint(corrupt),
        "Expired staged checkpoint cannot be reloaded to reset time pressure")

    var narrative := IPStoryDirector.new()
    narrative.reset("thermal")
    _check(narrative.on_game_event("containment_stage","") and narrative.latest_key=="containment_stage",
        "MARA receives authored RU/EN first-stage coil radio event")
    _check(narrative.latest("ru")["text"].contains("катушка"),
        "Actual Russian radio message explains physical timed sequence")
    _check(narrative.on_game_event("containment_online","") and narrative.latest("en")["text"].contains("synchronized"),
        "Successful full circuit produces original English story dialogue")
    _check(narrative.on_game_event("containment_misroute","") and narrative.latest("ru")["text"].contains("Неверное"),
        "Wrong coil produces meaningful Russian narrative consequence")
    _check(narrative.on_game_event("containment_expired","") and narrative.latest("en")["text"].contains("timed out"),
        "Real timeout is explained in translated local story")

    var old_normal := IPCrisisEngine.new()
    old_normal.reset()
    old_normal.scan_core()
    old_normal.repair_coolant()
    old_normal.cycle_bus(1)
    old_normal.tick(24.0)
    old_normal.cycle_bus(1)
    old_normal.cycle_bus(1)
    _check(old_normal.activate_override() and old_normal.escape(),
        "Original five-stage core evacuation route can still win without V9 optional challenge")
    _check(not old_normal.containment_online and old_normal.won,
        "V9 does not silently change previous scenario win requirement")
    _finish()

func _finish() -> void:
    if errors.is_empty():
        print("IRON PULSE V9 CONTAINMENT CIRCUIT PASS: %d deterministic gameplay checks" % checks)
        quit(0)
    else:
        for issue in errors:
            push_error("V9 CONTAINMENT RULE FAIL: "+issue)
        quit(1)
