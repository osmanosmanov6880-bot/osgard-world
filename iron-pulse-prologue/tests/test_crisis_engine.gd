extends SceneTree
## Pure gameplay regression. No dependency on rendering, timers or wall clock.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, explanation: String) -> void:
    checks += 1
    if not value:
        failures.append(explanation)

func _run() -> void:
    var e := IPCrisisEngine.new()
    e.reset()
    _check(e.objective_id() == "scan", "First objective is scan")
    _check(e.powered("coolant") and e.powered("life") and not e.powered("door"), "Two buses cannot power all three systems")
    _check(not e.repair_coolant(), "No repair without scan")
    _check(not e.activate_override(), "Cannot skip locked objective")
    _check(e.scan_core(), "Scan can complete")
    _check(e.objective_id() == "repair", "Scanner unlocks coolant fault")
    _check(e.repair_coolant(), "Coolant repair works")
    _check(e.objective_id() == "charge", "Next objective is routing door charge")
    _check(not e.activate_override(), "No override when capacitor empty")
    _check(e.cycle_bus(1), "Bus B switches from LIFE to DOOR")
    _check(e.bus_b == "door" and e.bus_a == "coolant", "Routing state is exact")
    e.tick(25.0)
    _check(e.door_charge >= 95.0, "Door charges in 25 simulated seconds")
    _check(e.surge_triggered, "Scripted power surge actually triggered")
    _check(e.oxygen < 93.0 and e.crew_health < 100.0, "Life-support outage has real consequences")
    _check(e.objective_id() == "override", "Correct puzzle transition after charging")
    _check(not e.activate_override(), "Cannot approve without both cooling and life support")
    _check(e.cycle_bus(1) and e.bus_b == "coolant", "Cycle B via duplicate cooling")
    _check(e.cycle_bus(1) and e.bus_b == "life", "Restore life support")
    _check(e.activate_override(), "Valid allocation allows override")
    _check(e.objective_id() == "exit", "Override unlocks exit")
    _check(e.escape() and e.won and e.grade() != "UNRATED", "Evacuation reaches verified victory")
    _check(e.objective_id() == "victory", "Win is terminal")
    var snapshot := e.diagnostic_snapshot()
    _check(snapshot.get("won") == true and snapshot.get("switches") == 3, "Source-bound diagnostics describe real actions")
    _check(e.event_log.size() <= 32, "Event log is bounded")
    e.reset()
    _check(not e.won and e.time_left == IPCrisisEngine.MAX_TIME, "Restart clears old progress")
    _check(not e.escape(), "Cannot escape without objective")
    e.scan_core()
    e.repair_coolant()
    e.cycle_bus(0) # coolant -> life, duplicated life leaves cooling off
    e.tick(38.0)
    _check(e.lost and e.last_event == "reactor_overheat", "Real overheating ends mission")
    e.reset()
    e.scan_core()
    e.repair_coolant()
    e.tick(331.0)
    _check(e.lost and e.last_event == "time_expired", "Real time limit ends mission")
    e.reset()
    e.scan_core()
    e.repair_coolant()
    e.cycle_bus(0) # a becomes life; b stays life
    e.tick(0.0)
    _check(e.door_charge == 0.0, "Zero delta cannot advance game")
    e.tick(-1.0)
    _check(e.time_left == IPCrisisEngine.MAX_TIME, "Negative dt cannot cheat time")
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE BLACKOUT GAMEPLAY PASS: %d deterministic checks" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error("BLACKOUT GAMEPLAY FAIL: " + failure)
        quit(1)
