extends RefCounted
class_name IPCrisisEngine
## IRON PULSE BLACKOUT V4 — THREE distinct, deterministic fictional emergencies.
## No real-world machine procedures. Original BLACKOUT gameplay remains compatible.

const SYSTEMS: Array[String] = ["coolant", "life", "door"]
const SCENARIOS: Array[String] = ["blackout", "thermal", "breach"]
const RELAYS: Array[String] = ["medbay","quench","uplink"]
const MAX_RELAYS: int = 2
const MAX_TIME: float = 330.0
const CHARGE_REQUIRED: float = 95.0
const LOG_LIMIT: int = 32

var scenario_id: String = "blackout"
var repair_method: String = ""
var priority_id: String = ""
var relays_activated: Array[String] = []
var thermal_shield: bool = false
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
var thermal_pulses: int = 0
var next_pulse_at: float = 45.0
var won: bool = false
var lost: bool = false
var elapsed: float = 0.0
var switches: int = 0
var faults: int = 0
var event_log: Array[String] = []
var last_event: String = "shift_started"

func reset(next_scenario: String = "blackout") -> void:
    scenario_id = next_scenario if SCENARIOS.has(next_scenario) else "blackout"
    time_left = MAX_TIME
    heat = 48.0
    oxygen = 93.0
    crew_health = 100.0
    if scenario_id == "thermal":
        time_left = 265.0
        heat = 72.0
        oxygen = 88.0
    elif scenario_id == "breach":
        time_left = 245.0
        heat = 52.0
        oxygen = 68.0
        crew_health = 92.0
    door_charge = 0.0
    bus_a = "coolant"
    bus_b = "life"
    core_scanned = false
    coolant_repaired = false
    override_set = false
    surge_triggered = false
    thermal_pulses = 0
    next_pulse_at = 45.0
    repair_method = ""
    priority_id = ""
    relays_activated.clear()
    thermal_shield = false
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
    if event_log.size() > LOG_LIMIT:
        event_log.pop_front()

func powered(system_name: String) -> bool:
    return bus_a == system_name or bus_b == system_name

func finished() -> bool:
    return won or lost

func tick(delta: float) -> void:
    if finished() or delta <= 0.0:
        return
    # Bounded steps preserve outcomes on 30/60/144 Hz and prevent large-dt bypass.
    var remaining: float = minf(delta, 360.0)
    while remaining > 0.0 and not finished():
        var step: float = minf(remaining, 0.1)
        _integrate_step(step)
        remaining -= step

func _integrate_step(dt: float) -> void:
    time_left -= dt
    elapsed += dt
    if powered("coolant"):
        var cool_rate: float = -0.52 if coolant_repaired else 0.25
        if coolant_repaired and scenario_id == "thermal" and repair_method == "deep_stabilize":
            cool_rate = -0.82
        heat += cool_rate * dt
    else:
        heat += 1.55 * dt
    if powered("life"):
        oxygen += 0.14 * dt
        crew_health += 0.06 * dt
    else:
        oxygen -= 0.76 * dt
        crew_health -= 1.05 * dt

    # Sector-specific systemic pressure: leak affects powered and unpowered LIFE.
    # A rapid patch leaves an ongoing micro-leak: a consequential second strategy.
    if scenario_id == "breach":
        if not coolant_repaired:
            oxygen -= 0.70 * dt
            crew_health -= 0.16 * dt
        elif repair_method == "rapid_patch":
            oxygen -= 0.18 * dt

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
    if scenario_id == "thermal" and elapsed >= next_pulse_at:
        thermal_pulses += 1
        next_pulse_at += 55.0
        var pulse: float = 12.0 if thermal_pulses == 1 else 7.0
        heat += pulse * (0.55 if thermal_shield else 1.0)
        _record("thermal_pulse")
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
    if scenario_id == "thermal":
        # Precision repair spends simulated time but retains crew resources.
        tick(15.0)
        if finished():
            return false
        repair_method = "deep_stabilize"
        heat = maxf(heat - 7.0, 0.0)
        _record("thermal_stabilized")
    elif scenario_id == "breach":
        # Full seal takes time; permanent oxygen restoration is the reward.
        tick(10.0)
        if finished():
            return false
        repair_method = "full_seal"
        oxygen = maxf(oxygen - 3.0, 0.0)
        heat = maxf(heat - 4.0, 0.0)
        _record("breach_sealed")
    else:
        repair_method = "standard"
        heat = maxf(heat - 4.0, 0.0)
        _record("coolant_repaired")
    coolant_repaired = true
    return true

func emergency_repair() -> bool:
    # Player presses Q (or the dedicated touch action) at the SAME repair unit.
    # Fast intervention truly changes the simulation; not a cosmetic menu choice.
    if finished() or not core_scanned or coolant_repaired or scenario_id == "blackout":
        return _reject()
    if scenario_id == "thermal":
        heat = maxf(heat - 22.0, 0.0)
        oxygen = maxf(oxygen - 18.0, 0.0)
        crew_health = maxf(crew_health - 10.0, 0.0)
        repair_method = "rapid_purge"
        _record("thermal_purged")
    else:
        heat += 8.0
        oxygen = maxf(oxygen - 12.0, 0.0)
        crew_health = maxf(crew_health - 15.0, 0.0)
        repair_method = "rapid_patch"
        _record("breach_patched")
    coolant_repaired = true
    return true

func choose_priority(choice: String) -> bool:
    # A new, one-time moral/mechanical choice after scanning the real core.
    if finished() or not core_scanned or override_set or priority_id != "" or choice not in ["crew","core"]:
        return _reject()
    # Both alternatives take equal time; the costs are not decorative.
    tick(8.0)
    if finished():
        return false
    priority_id = choice
    if choice == "crew":
        oxygen = minf(100.0,oxygen+9.0)
        crew_health = minf(100.0,crew_health+8.0)
        heat = minf(110.0,heat+4.0)
    else:
        heat = maxf(0.0,heat-13.0)
        oxygen = maxf(0.0,oxygen-7.0)
        crew_health = maxf(0.0,crew_health-4.0)
    _record("priority_" + choice)
    return true

func activate_relay(relay_id: String) -> bool:
    # An optional strategic layer: activate only two out of three site-based
    # systems; every activation consumes real simulated time and resources.
    if finished() or not core_scanned or not RELAYS.has(relay_id) or relays_activated.has(relay_id) or relays_activated.size() >= MAX_RELAYS:
        return _reject()
    tick(6.0)
    if finished():
        return false
    match relay_id:
        "medbay":
            oxygen = minf(100.0,oxygen+13.0)
            crew_health = minf(100.0,crew_health+18.0)
            heat = minf(110.0,heat+4.0)
        "quench":
            heat = maxf(0.0,heat-18.0)
            oxygen = maxf(0.0,oxygen-5.0)
            thermal_shield = true
        "uplink":
            time_left = minf(MAX_TIME,time_left+40.0)
            door_charge = minf(100.0,door_charge+12.0)
            crew_health = maxf(0.0,crew_health-4.0)
    relays_activated.append(relay_id)
    _record("relay_" + relay_id)
    return true

func authorize_field_seal() -> bool:
    # A costly real emergency action, not an infinite free safety button.
    # The independent physical field model enforces 2-of-3 spatial choices.
    if finished() or not core_scanned or oxygen < 12.0:
        return _reject()
    tick(7.0)
    if finished():
        return false
    oxygen = maxf(0.0, oxygen-6.0)
    return true

func fail_suit_integrity() -> bool:
    # The operator is physically exposed in the playable world. A collapsed
    # suit makes the original mission fail and feeds existing ending logic.
    if finished() or not core_scanned:
        return false
    lost = true
    _record("suit_failure")
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
        "scenario": scenario_id, "repair_method": repair_method,
        "priority":priority_id,
        "relays":relays_activated.duplicate(),"relay_count":relays_activated.size(),
        "thermal_shield":thermal_shield,
        "thermal_pulses": thermal_pulses, "next_pulse": next_pulse_at,
        "leak_active": scenario_id == "breach" and (not coolant_repaired or repair_method == "rapid_patch"),
        "objective": objective_id(), "time_left": time_left, "heat": heat,
        "oxygen": oxygen, "crew_health": crew_health, "door_charge": door_charge,
        "bus_a": bus_a, "bus_b": bus_b, "scanned": core_scanned,
        "repaired": coolant_repaired, "override": override_set,
        "surge": surge_triggered, "won": won, "lost": lost,
        "switches": switches, "faults": faults, "elapsed": elapsed,
        "last_event": last_event
    }


func checkpoint() -> Dictionary:
    # Serialize only the gameplay state needed to resume the real simulation.
    # No engine internals, scripts, executable instructions or private data.
    return {
        "schema":"IRON_PULSE_ENGINE_V6",
        "scenario":scenario_id, "repair_method":repair_method,
        "priority":priority_id,
        "relays_activated":relays_activated.duplicate(),
        "thermal_shield":thermal_shield,
        "time_left":time_left, "heat":heat, "oxygen":oxygen,
        "crew_health":crew_health, "door_charge":door_charge,
        "bus_a":bus_a, "bus_b":bus_b,
        "core_scanned":core_scanned, "coolant_repaired":coolant_repaired,
        "override_set":override_set, "surge_triggered":surge_triggered,
        "thermal_pulses":thermal_pulses, "next_pulse_at":next_pulse_at,
        "won":won, "lost":lost, "elapsed":elapsed,
        "switches":switches, "faults":faults,
        "event_log":event_log.duplicate(), "last_event":last_event
    }

func _valid_number(input: Variant, low: float, high: float) -> bool:
    if typeof(input) != TYPE_FLOAT and typeof(input) != TYPE_INT:
        return false
    var n: float = float(input)
    return n == n and n >= low and n <= high

func restore_checkpoint(data: Dictionary) -> bool:
    # Validate the entire save before mutating *any* gameplay field.
    if data.get("schema") != "IRON_PULSE_ENGINE_V6":
        return false
    var saved_scenario: String = str(data.get("scenario",""))
    if not SCENARIOS.has(saved_scenario):
        return false
    var saved_repair: String = str(data.get("repair_method",""))
    var valid_methods: Array[String] = ["","standard","deep_stabilize","rapid_purge","full_seal","rapid_patch"]
    if not valid_methods.has(saved_repair):
        return false
    if saved_repair != "":
        if (saved_scenario == "blackout" and saved_repair != "standard") or (saved_scenario == "thermal" and saved_repair not in ["deep_stabilize","rapid_purge"]) or (saved_scenario == "breach" and saved_repair not in ["full_seal","rapid_patch"]):
            return false
    var saved_priority: String = str(data.get("priority",""))
    if saved_priority not in ["","crew","core"]:
        return false
    # Previously verified V6 saves lack relay fields: restore them as empty,
    # and validate any V7 relay entries without mutating active state.
    var saved_relays: Variant = data.get("relays_activated",[])
    if not saved_relays is Array or saved_relays.size() > MAX_RELAYS:
        return false
    var checked_relays: Array[String] = []
    for relay in saved_relays:
        if not relay is String or not RELAYS.has(str(relay)) or checked_relays.has(str(relay)):
            return false
        checked_relays.append(str(relay))
    var stored_shield: Variant = data.get("thermal_shield",false)
    if typeof(stored_shield) != TYPE_BOOL or (bool(stored_shield) and not checked_relays.has("quench")):
        return false
    for key in ["time_left","heat","oxygen","crew_health","door_charge","elapsed","next_pulse_at"]:
        var max_value: float = 1000.0
        if key == "heat":
            max_value = 110.0
        elif key == "oxygen" or key == "crew_health" or key == "door_charge":
            max_value = 100.0
        elif key == "time_left":
            max_value = MAX_TIME
        if not _valid_number(data.get(key,null),0.0,max_value):
            return false
    for key in ["switches","faults","thermal_pulses"]:
        if not _valid_number(data.get(key,null),0.0,1000.0):
            return false
    for key in ["core_scanned","coolant_repaired","override_set","surge_triggered","won","lost"]:
        if typeof(data.get(key,null)) != TYPE_BOOL:
            return false
    var saved_bus_a: String = str(data.get("bus_a",""))
    var saved_bus_b: String = str(data.get("bus_b",""))
    if not SYSTEMS.has(saved_bus_a) or not SYSTEMS.has(saved_bus_b):
        return false
    var scanned: bool = bool(data["core_scanned"])
    var repaired: bool = bool(data["coolant_repaired"])
    var overridden: bool = bool(data["override_set"])
    if (repaired and not scanned) or (overridden and not repaired) or (saved_repair != "" and not repaired):
        return false
    if saved_priority != "" and not scanned:
        return false
    if data["won"] and (not overridden or data["lost"]):
        return false
    var events: Variant = data.get("event_log",null)
    if not events is Array or events.size() > LOG_LIMIT:
        return false
    var checked_events: Array[String] = []
    for value in events:
        if not value is String or value.length() > 64:
            return false
        checked_events.append(str(value))
    var most_recent: String = str(data.get("last_event",""))
    if most_recent.length() > 64:
        return false
    scenario_id = saved_scenario
    repair_method = saved_repair
    priority_id = saved_priority
    relays_activated = checked_relays
    thermal_shield = bool(stored_shield)
    time_left = float(data["time_left"])
    heat = float(data["heat"])
    oxygen = float(data["oxygen"])
    crew_health = float(data["crew_health"])
    door_charge = float(data["door_charge"])
    bus_a = saved_bus_a
    bus_b = saved_bus_b
    core_scanned = scanned
    coolant_repaired = repaired
    override_set = overridden
    surge_triggered = bool(data["surge_triggered"])
    won = bool(data["won"])
    lost = bool(data["lost"])
    elapsed = float(data["elapsed"])
    thermal_pulses = int(data["thermal_pulses"])
    next_pulse_at = float(data["next_pulse_at"])
    switches = int(data["switches"])
    faults = int(data["faults"])
    event_log = checked_events
    last_event = most_recent
    return true
