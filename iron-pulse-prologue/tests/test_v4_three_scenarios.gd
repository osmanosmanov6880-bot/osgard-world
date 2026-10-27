extends SceneTree
## V4 deterministic, source-bound gameplay tests: three hazards + two real strategies.
var checks: int = 0
var problems: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(value: bool, label: String) -> void:
    checks += 1
    if not value:
        problems.append(label)

func _run() -> void:
    var baseline := IPCrisisEngine.new()
    baseline.reset()
    _assert(baseline.scenario_id == "blackout", "Classic mission remains default")
    _assert(absf(baseline.heat-48.0) < 0.01 and baseline.time_left == 330.0, "Historical default initial conditions unchanged")
    _assert(not baseline.emergency_repair(), "Classic route cannot bypass its original repair")
    _assert(baseline.faults == 1, "Illegal Q shortcut generates a real mistake")
    _assert(baseline.scan_core() and baseline.repair_coolant(), "Historical classic scan and repair still work")
    _assert(baseline.repair_method == "standard", "Historical classic repair is preserved")

    var careful_heat := IPCrisisEngine.new()
    careful_heat.reset("thermal")
    _assert(careful_heat.heat == 72.0 and careful_heat.time_left == 265.0, "Thermal cascade has unique initial hazard and timer")
    _assert(careful_heat.scan_core() and careful_heat.repair_coolant(), "Thermal deep repair is available")
    _assert(careful_heat.repair_method == "deep_stabilize" and careful_heat.elapsed >= 14.9, "Careful thermal method spends real simulation time")
    _assert(careful_heat.oxygen > 85.0 and careful_heat.crew_health > 99.0, "Deep stabilization preserves oxygen and crew")
    _assert(careful_heat.cycle_bus(1), "Thermal route can charge bulkhead")
    careful_heat.tick(25.0)
    _assert(careful_heat.door_charge >= 95.0, "Deep thermal path has a solvable power-routing objective")
    _assert(careful_heat.cycle_bus(1) and careful_heat.cycle_bus(1), "Restore both critical buses after charging")
    _assert(careful_heat.activate_override() and careful_heat.escape(), "Careful thermal scenario can be won")
    _assert(careful_heat.won and careful_heat.grade() != "UNRATED", "Thermal win has meaningful score")

    var fast_heat := IPCrisisEngine.new()
    fast_heat.reset("thermal")
    fast_heat.scan_core()
    _assert(fast_heat.emergency_repair(), "Thermal fast Q operation is real gameplay")
    _assert(fast_heat.repair_method == "rapid_purge" and fast_heat.elapsed == 0.0, "Fast thermal alternative saves time")
    _assert(fast_heat.heat < 55.0 and fast_heat.oxygen <= 70.0 and fast_heat.crew_health <= 90.0, "Fast thermal operation costs oxygen and crew for lower heat")
    _assert(fast_heat.oxygen < careful_heat.oxygen, "Different thermal strategies have different resource consequences")
    fast_heat.cycle_bus(1)
    fast_heat.tick(25.0)
    fast_heat.cycle_bus(1)
    fast_heat.cycle_bus(1)
    _assert(fast_heat.activate_override() and fast_heat.escape(), "Fast thermal route can also reach a real win")

    var pulse := IPCrisisEngine.new()
    pulse.reset("thermal")
    pulse.scan_core()
    pulse.emergency_repair()
    pulse.tick(46.0)
    _assert(pulse.thermal_pulses == 1 and pulse.event_log.has("thermal_pulse"), "Recurring thermal surge is a distinct timed incident")
    pulse.tick(55.0)
    _assert(pulse.thermal_pulses == 2, "Second thermal pulse actually fires")
    _assert(pulse.event_log.size() <= IPCrisisEngine.LOG_LIMIT, "Incident log remains bounded")

    var careful_air := IPCrisisEngine.new()
    careful_air.reset("breach")
    _assert(careful_air.oxygen == 68.0 and careful_air.crew_health == 92.0, "Oxygen breach begins with its own resource envelope")
    careful_air.tick(10.0)
    _assert(careful_air.oxygen < 66.0 and careful_air.powered("life"), "Unsealed leak drains air even with life support powered")
    _assert(careful_air.scan_core() and careful_air.repair_coolant(), "Permanent breach seal works")
    _assert(careful_air.repair_method == "full_seal" and careful_air.elapsed >= 19.9, "Permanent seal spends time")
    var oxygen_before := careful_air.oxygen
    careful_air.tick(10.0)
    _assert(careful_air.oxygen > oxygen_before, "After permanent seal, powered life support actually restores oxygen")
    careful_air.cycle_bus(1)
    careful_air.tick(25.0)
    careful_air.cycle_bus(1)
    careful_air.cycle_bus(1)
    _assert(careful_air.activate_override() and careful_air.escape(), "Permanent seal route has a full win")

    var fast_air := IPCrisisEngine.new()
    fast_air.reset("breach")
    fast_air.scan_core()
    _assert(fast_air.emergency_repair(), "Rapid patch is a distinct player-selected solution")
    _assert(fast_air.repair_method == "rapid_patch" and fast_air.crew_health == 77.0, "Rapid patch actually injures crew")
    _assert(fast_air.diagnostic_snapshot()["leak_active"], "Rapid patch leaves a persistent micro-leak")
    var oxygen_before_patch := fast_air.oxygen
    fast_air.tick(10.0)
    _assert(fast_air.oxygen < oxygen_before_patch, "Patched breach still drains oxygen even when LIFE is online")
    fast_air.cycle_bus(1)
    fast_air.tick(25.0)
    fast_air.cycle_bus(1)
    fast_air.cycle_bus(1)
    _assert(fast_air.activate_override() and fast_air.escape(), "Rapid patch risk-reward choice can also be won")

    var invalid := IPCrisisEngine.new()
    invalid.reset("unknown")
    _assert(invalid.scenario_id == "blackout", "Invalid scenario fails closed to original gameplay")
    invalid.reset("thermal")
    invalid.scan_core()
    invalid.emergency_repair()
    invalid.reset("thermal")
    _assert(invalid.scenario_id == "thermal" and invalid.repair_method == "" and invalid.thermal_pulses == 0, "Retry resets incidents without silently changing selected scenario")
    invalid.tick(0.0)
    invalid.tick(-1.0)
    _assert(invalid.elapsed == 0.0, "Zero and negative delta cannot shortcut time")

    var once := IPCrisisEngine.new()
    var stepped := IPCrisisEngine.new()
    once.reset("breach")
    stepped.reset("breach")
    once.scan_core()
    stepped.scan_core()
    once.emergency_repair()
    stepped.emergency_repair()
    once.tick(20.0)
    for i in 200:
        stepped.tick(0.1)
    _assert(absf(once.oxygen-stepped.oxygen) < 0.07 and absf(once.heat-stepped.heat) < 0.07,
        "Fixed-step emergency simulation agrees with 200 independent 0.1s updates")
    _finish()

func _finish() -> void:
    if problems.is_empty():
        print("IRON PULSE V4 THREE SCENARIOS PASS: %d deterministic checks" % checks)
        quit(0)
    else:
        for message in problems:
            push_error("V4 SCENARIOS FAIL: " + message)
        quit(1)
