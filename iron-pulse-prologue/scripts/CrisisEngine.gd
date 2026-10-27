extends RefCounted
class_name IPCrisisEngine
## IRON PULSE: BLACKOUT. Pure, deterministic gameplay rules; no real hardware interfaces.
## All values, procedures and hazards are deliberately fictional.

const SYSTEMS: Array[String] = ["coolant", "life", "door"]
const MAX_TIME: float = 330.0
const CHARGE_REQUIRED: float = 95.0

var time_left: float = MAX_TIME
var heat: float = 48.0
var oxygen: float = 93.0
var crew_health: float = 100.0
var door_charge: float = 0.0
var bus_a: String = "coolant"
var bus_b: String = "life"
var core_scanned: bool = false
var coolant_repaired: bool = false
var override_set: bool = false
var surge_triggered: bool = false
var won: bool = false
var lost: bool = false
var elapsed: float = 0.0
var switches: int = 0
var faults: int = 0
var event_log: Array[String] = []
var last_event: String = "shift_started"

func reset() -> void:
    time_left = MAX_TIME
    heat = 48.0
    oxygen = 93.0
    crew_health = 100.0
    door_charge = 0.0
    bus_a = "coolant"
    bus_b = "life"
    core_scanned = false
    coolant_repaired = false
    override_set = false
    surge_triggered = false
    won = false
    lost = false
    elapsed = 0.0
    switches = 0
    faults = 0
    event_log.clear()
    _record("shift_started")

func _record(event_name: String) -> void:
    last_event = event_name
    event_log.append(event_name)
    if event_log.size() > 32:
        event_log.pop_front()

func powered(system_name: String) -> bool:
    return bus_a == system_name or bus_b == system_name

func finished() -> bool:
    return won or lost

func tick(delta: float) -> void:
    if finished() or delta <= 0.0:
        return
    # A bounded integration step makes the same timeline predictable at 30/60/144 FPS.
    var remaining: float = minf(delta, 360.0)
    while remaining > 0.0 and not finished():
        var step: float = minf(remaining, 0.1)
        _integrate_step(step)
        remaining -= step

func _integrate_step(dt: float) -> void:
    time_left -= dt
    elapsed += dt
    if powered("coolant"):
        heat += (-0.52 if coolant_repaired else 0.25) * dt
    else:
        heat += 1.55 * dt
    if powered("life"):
        oxygen += 0.14 * dt
        crew_health += 0.06 * dt
    else:
        oxygen -= 0.76 * dt
        crew_health -= 1.05 * dt
    heat = clampf(heat, 0.0, 110.0)
    oxygen = clampf(oxygen, 0.0, 100.0)
    crew_health = clampf(crew_health, 0.0, 100.0)
    if coolant_repaired and powered("door"):
        door_charge = minf(100.0, door_charge + 4.2 * dt)
    else:
        door_charge = maxf(0.0, door_charge - 0.10 * dt)
    if not surge_triggered and door_charge >= 50.0:
        surge_triggered = true
        heat += 8.0
        _record("surge")
    if heat >= 100.0:
        lost = true
        _record("reactor_overheat")
    elif oxygen <= 0.0 or crew_health <= 0.0:
        lost = true
        _record("life_support_lost")
    elif time_left <= 0.0:
        lost = true
        _record("time_expired")

func scan_core() -> bool:
    if finished() or core_scanned:
        return _reject()
    core_scanned = true
    _record("core_scanned")
    return true

func repair_coolant() -> bool:
    if finished() or not core_scanned or coolant_repaired:
        return _reject()
    coolant_repaired = true
    heat = maxf(heat - 4.0, 0.0)
    _record("coolant_repaired")
    return true

func cycle_bus(bus_index: int) -> bool:
    if finished() or not coolant_repaired or (bus_index != 0 and bus_index != 1):
        return _reject()
    var current: String = bus_a if bus_index == 0 else bus_b
    var next: String = SYSTEMS[(SYSTEMS.find(current) + 1) % SYSTEMS.size()]
    if bus_index == 0:
        bus_a = next
    else:
        bus_b = next
    switches += 1
    _record("bus_switched")
    return true

func activate_override() -> bool:
    if finished() or not coolant_repaired or door_charge < CHARGE_REQUIRED:
        return _reject()
    # This is the central power-routing trade-off: the door capacitor must be
    # charged, then BOTH reactor cooling and life support must be restored.
    if not powered("coolant") or not powered("life") or heat >= 85.0 or oxygen < 20.0:
        return _reject()
    if override_set:
        return _reject()
    override_set = true
    _record("override_authorized")
    return true

func escape() -> bool:
    if finished() or not override_set or door_charge < 60.0:
        return _reject()
    won = true
    _record("crew_evacuated")
    return true

func _reject() -> bool:
    faults += 1
    _record("action_denied")
    return false

func objective_id() -> String:
    if won:
        return "victory"
    if lost:
        return "failure"
    if not core_scanned:
        return "scan"
    if not coolant_repaired:
        return "repair"
    if door_charge < CHARGE_REQUIRED:
        return "charge"
    if not override_set:
        return "override"
    return "exit"

func grade() -> String:
    if not won:
        return "UNRATED"
    if heat < 70.0 and oxygen >= 65.0 and crew_health >= 75.0 and faults <= 2:
        return "S"
    if heat < 85.0 and crew_health >= 50.0:
        return "A"
    return "B"

func diagnostic_snapshot() -> Dictionary:
    return {
        "objective": objective_id(), "time_left": time_left, "heat": heat,
        "oxygen": oxygen, "crew_health": crew_health, "door_charge": door_charge,
        "bus_a": bus_a, "bus_b": bus_b, "scanned": core_scanned,
        "repaired": coolant_repaired, "override": override_set,
        "surge": surge_triggered, "won": won, "lost": lost,
        "switches": switches, "faults": faults, "elapsed": elapsed,
        "last_event": last_event
    }
