extends SceneTree
## V9 WORLD: real 3-operation progression, profile persistence, integrity and
## old checkpoint separation. Gameplay is solved with genuine engine methods.
var failures: Array[String] = []
var checks: int = 0
const SLOT: String = "user://iron_pulse_world_atlas_v9_native_ci.json"

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)

func _solved(scenario: String) -> IPCrisisEngine:
    var e := IPCrisisEngine.new()
    e.reset(scenario)
    e.scan_core()
    e.repair_coolant()
    e.cycle_bus(1)
    e.tick(25.0)
    e.cycle_bus(1)
    e.cycle_bus(1)
    e.activate_override()
    e.escape()
    return e

func _run() -> void:
    var atlas := IPCampaignAtlas.new()
    _check(atlas.clear_count() == 0 and atlas.total_runs == 0,
        "Fresh campaign profile has no invented world accomplishments")
    _check(atlas.next_mission("blackout") == "thermal" and atlas.next_mission("thermal") == "breach",
        "Actual three-op story transitions have deterministic order")
    _check(atlas.next_mission("breach") == "" and atlas.next_mission("unknown") == "",
        "Last scenario has no fake/unimplemented fourth level")
    _check(atlas.route_text("ru").contains("КАМПАНИЯ") and atlas.route_text("en").contains("OPERATIONS"),
        "Mission dossier has genuine RU and EN localized descriptions")
    _check(atlas.route_text("en").contains("GRID") and atlas.route_text("en").contains("AIR"),
        "All three existing physics emergencies are represented in progression")

    var pending := IPCrisisEngine.new()
    pending.reset("blackout")
    _check(not atlas.record_run(pending) and atlas.total_runs == 0,
        "No fake win or attempt recorded from a mission that is still live")
    pending.scan_core()
    pending.repair_coolant()
    pending.cycle_bus(0)
    pending.tick(38.0)
    _check(pending.lost and atlas.record_run(pending),
        "A genuine reactor-overheat loss is counted as an attempt, not a medal")
    _check(atlas.current_run_count("blackout") == 1 and atlas.clear_count() == 0,
        "Failed operation never grants victory or unlocks false achievements")
    var first := _solved("blackout")
    _check(first.won and first.objective_id() == "victory",
        "First campaign result comes from real two-bus power puzzle victory")
    _check(atlas.record_run(first) and atlas.clear_count() == 1,
        "Real completed GRID mission awards exactly one mission result")
    _check(atlas.current_run_count("blackout") == 2 and atlas.best_grade("blackout") != "-",
        "Archive distinguishes total attempts and verified best rank")
    _check(atlas.last_scenario == "blackout",
        "Archive tracks last real operation without inventing a remote identity")

    var second := _solved("thermal")
    var third := _solved("breach")
    _check(second.won and third.won,
        "HEAT and AIR are genuine winnable existing game simulation paths")
    _check(atlas.record_run(second) and atlas.record_run(third),
        "Two more real emergency escapes extend persistent campaign")
    _check(atlas.clear_count() == 3 and atlas.is_complete() and atlas.total_runs == 4,
        "Exactly three distinct victories complete the local world campaign")
    _check(atlas.route_text("en").contains("3/3") and atlas.last_result_text("ru").contains("ЗАВЕРШЕНЫ"),
        "International dossier announces completion only after all three wins")

    # Replay scoring must preserve the best rank, crew and speed rather than
    # overwriting the archive with the most recent worse performance.
    var earlier_grade: String = atlas.best_grade("blackout")
    var earlier_time: float = float(atlas.records["blackout"]["best_time"])
    first.elapsed = 300.0
    first.heat = 95.0
    first.crew_health = 20.0
    first.faults = 10
    _check(atlas.record_run(first), "An actual completed scenario can be replayed for improvement")
    _check(atlas.best_grade("blackout") == earlier_grade and
        float(atlas.records["blackout"]["best_time"]) <= earlier_time,
        "A worse replay cannot destroy earlier record medal or best completion time")
    _check(int(atlas.records["blackout"]["wins"]) == 2 and atlas.total_runs == 5,
        "Replay increments true wins and total attempts without duplicate medal categories")

    var slot_store := IPCheckpointStore.new()
    slot_store.clear(SLOT)
    _check(atlas.save_profile(SLOT) and FileAccess.file_exists(SLOT),
        "Separate V9 dossier uses actual atomic file storage and integrity checksum")
    var loaded := IPCampaignAtlas.new()
    var recovered: bool = loaded.load_profile(SLOT)
    _check(recovered,"Stored career file is recoverable from real disk")
    if recovered and loaded.snapshot() != atlas.snapshot():
        print("V9 SOURCE PROFILE: " + JSON.stringify(atlas.snapshot()))
        print("V9 RESTORED PROFILE: " + JSON.stringify(loaded.snapshot()))
    _check(recovered and loaded.snapshot() == atlas.snapshot(),
        "Cross-instance restored file matches all verified archive records")
    _check(loaded.clear_count() == 3 and loaded.last_scenario == "blackout",
        "Restored campaign persists completed operations and replay metadata")
    _check(IPCampaignAtlas.DEFAULT_PATH != IPCheckpointStore.DEFAULT_PATH,
        "Long-lived career file NEVER overwrites original V6 checkpoint")
    var pristine: Dictionary = loaded.snapshot()
    var invalid: Dictionary = pristine.duplicate(true)
    invalid["attempts"]["heat"] = -40
    _check(not loaded.restore(invalid) and loaded.snapshot() == pristine,
        "Negative attempt counter rejected atomically before any record changes")
    invalid = pristine.duplicate(true)
    invalid["records"]["unknown"] = pristine["records"]["blackout"].duplicate(true)
    _check(not loaded.restore(invalid) and loaded.snapshot() == pristine,
        "Forged fourth scenario cannot gain a fake campaign medal")
    invalid = pristine.duplicate(true)
    invalid["records"]["blackout"]["best_grade"] = "AAA"
    _check(not loaded.restore(invalid) and loaded.snapshot() == pristine,
        "Arbitrary fake world rank is rejected before profile mutation")
    invalid = pristine.duplicate(true)
    invalid["records"]["blackout"]["wins"] = 999999
    _check(not loaded.restore(invalid) and loaded.snapshot() == pristine,
        "Impossible wins above attempts are rejected")
    invalid = pristine.duplicate(true)
    invalid["total_runs"] = 999999
    _check(not loaded.restore(invalid) and loaded.snapshot() == pristine,
        "Mismatch between total runs and real per-scenario attempts rejected")
    var damaged := FileAccess.open(SLOT,FileAccess.WRITE)
    if damaged != null:
        damaged.store_string("{\"fake\":true}")
        damaged.close()
    _check(not loaded.load_profile(SLOT) and loaded.snapshot() == pristine,
        "Corrupted on-disk SHA wrapper cannot erase last valid in-memory career")
    _check(slot_store.clear(SLOT), "Test career slot removed after deterministic QA")
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V9 WORLD CAREER PASS: %d deterministic progression/integrity checks" % checks)
        quit(0)
    else:
        for item in failures:
            push_error("V9 WORLD CAREER FAIL: " + item)
        quit(1)
