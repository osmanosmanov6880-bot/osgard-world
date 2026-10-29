extends SceneTree
## Source-bound strategic layer tests: three distinct power-budget decisions.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)

func _run() -> void:
    var locked := IPCrisisEngine.new()
    locked.reset()
    _check(not locked.activate_relay("medbay") and locked.relays_activated.is_empty(),
        "Cannot activate rescue infrastructure before scanning actual reactor")
    _check(not locked.activate_relay("unknown"), "Unlisted rescue command is rejected")
    locked.scan_core()

    var medical := IPCrisisEngine.new()
    medical.reset("thermal")
    medical.scan_core()
    medical.oxygen = 60.0
    medical.crew_health = 65.0
    var medical_heat: float = medical.heat
    _check(medical.activate_relay("medbay"), "Medbay is a real accessible secondary intervention")
    _check(medical.relays_activated == ["medbay"] and medical.elapsed >= 5.99,
        "Medbay costs time and uses exactly one rescue-network slot")
    _check(medical.oxygen >= 72.0 and medical.crew_health >= 82.0,
        "Medbay genuinely heals crew and restores oxygen")
    _check(medical.heat >= medical_heat+4.0, "Medical intervention has a measurable thermal downside")
    _check(not medical.activate_relay("medbay"), "Rescue relay cannot be reactivated for infinite resources")

    var shielded := IPCrisisEngine.new()
    var bare := IPCrisisEngine.new()
    shielded.reset("thermal")
    bare.reset("thermal")
    shielded.scan_core()
    bare.scan_core()
    _check(shielded.activate_relay("quench") and shielded.thermal_shield,
        "Heat suppressor enables actual persistent reactor protection")
    _check(shielded.heat < bare.heat-15.0, "Heat suppressor lowers real reactor temperature")
    shielded.tick(40.0)
    bare.tick(46.0)
    _check(shielded.thermal_pulses == 1 and bare.thermal_pulses == 1,
        "Both independent runs experience first scripted thermal surge")
    _check(shielded.heat <= bare.heat-19.0,
        "Quench reduces the actual magnitude of later thermal shocks")

    var uplink := IPCrisisEngine.new()
    uplink.reset("breach")
    uplink.scan_core()
    uplink.crew_health = 80.0
    var time_before: float = uplink.time_left
    _check(uplink.activate_relay("uplink"), "Evacuation uplink can be activated in active AIR scenario")
    _check(uplink.time_left > time_before+30.0, "Uplink trades resources for genuine additional mission time")
    _check(uplink.door_charge >= 12.0 and uplink.crew_health < 80.0,
        "Extra evacuation capacitor/time is purchased with real crew condition")

    var limited := IPCrisisEngine.new()
    limited.reset()
    limited.scan_core()
    _check(limited.activate_relay("medbay") and limited.activate_relay("quench"),
        "Player may choose any two of the three rescue options")
    _check(limited.relays_activated.size() == IPCrisisEngine.MAX_RELAYS,
        "Two-out-of-three limitation enforces real opportunity cost")
    _check(not limited.activate_relay("uplink") and limited.relays_activated.size() == 2,
        "Third rescue station is physically locked after two choices")
    _check(limited.diagnostic_snapshot()["relay_count"] == 2 and limited.diagnostic_snapshot()["thermal_shield"],
        "Read-only telemetry reflects the actual rescue decisions")

    limited.repair_coolant()
    limited.cycle_bus(1)
    limited.tick(25.0)
    limited.cycle_bus(1)
    limited.cycle_bus(1)
    _check(limited.activate_override() and limited.escape(),
        "Rescue puzzle integrates with original two-bus evacuation win path")

    var saved: Dictionary = limited.checkpoint()
    var resumed := IPCrisisEngine.new()
    _check(resumed.restore_checkpoint(saved), "V7 two-out-of-three choice survives actual core checkpoint restore")
    _check(resumed.relays_activated == ["medbay","quench"] and resumed.thermal_shield,
        "Reloaded rescue budget and protection preserve gameplay state")
    var cheated: Dictionary = saved.duplicate(true)
    cheated["relays_activated"] = ["medbay","quench","uplink"]
    _check(not resumed.restore_checkpoint(cheated), "Fabricated third rescue activation is refused")
    _check(resumed.relays_activated.size() == 2, "Invalid relay restore does not partly mutate progress")
    cheated = saved.duplicate(true)
    cheated["relays_activated"] = ["medbay","medbay"]
    _check(not resumed.restore_checkpoint(cheated), "Duplicate relay reward injection is blocked")
    cheated = saved.duplicate(true)
    cheated["relays_activated"] = ["medbay"]
    cheated["thermal_shield"] = true
    _check(not resumed.restore_checkpoint(cheated), "Fake thermal protection without QUENCH activation is blocked")

    var legacy: Dictionary = saved.duplicate(true)
    legacy.erase("relays_activated")
    legacy.erase("thermal_shield")
    var old_save := IPCrisisEngine.new()
    _check(old_save.restore_checkpoint(legacy), "Previously verified V6 checkpoint remains backwards compatible")
    _check(old_save.relays_activated.is_empty() and not old_save.thermal_shield,
        "V6 missing fields correctly resolve to unused rescue network")
    old_save.reset("blackout")
    _check(old_save.relays_activated.is_empty() and not old_save.thermal_shield,
        "Restart clears all rescue choices without changing default scenario")

    var narrative := IPStoryDirector.new()
    narrative.reset("thermal")
    _check(narrative.on_game_event("relay_medbay","") and narrative.latest_key == "relay_medbay",
        "Authored radio receives actual medical intervention")
    _check(narrative.on_game_event("relay_quench","") and narrative.latest("en")["text"].contains("Heat suppressor"),
        "Heat suppressor has its own translated narrative consequence")
    _check(narrative.on_game_event("relay_budget","") and narrative.latest("ru")["text"].contains("Сеть спасения"),
        "Crew knows when two rescue decisions exhausted their budget")
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V7 RESCUE NETWORK PASS: %d deterministic checks" % checks)
        quit(0)
    else:
        for item in failures:
            push_error("V7 RESCUE FAIL: "+item)
        quit(1)
