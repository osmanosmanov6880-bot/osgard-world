extends RefCounted
## R64: actual hull-penetrating hits produce permanent local airframe wear.
## Per-hull service uses only existing game CR, never premium entitlements.
const HULLS: Array[String] = ["ship_scout", "ship_interceptor", "ship_guardian"]
const SYSTEMS: Array[String] = ["engine", "controls", "plating"]
const SERVICE_COSTS := {"engine": 150, "controls": 120, "plating": 100}
const WEAR_RATIOS := {"engine": 0.30, "controls": 0.20, "plating": 0.55}
const MAX_INTEGRITY: int = 100

static func valid_hull(id: String) -> bool:
    return HULLS.has(id)

static func valid_system(id: String) -> bool:
    return SYSTEMS.has(id)

static func condition(input: Variant) -> int:
    if typeof(input) != TYPE_INT and typeof(input) != TYPE_FLOAT:
        return MAX_INTEGRITY
    var number: float = float(input)
    if not is_finite(number):
        return MAX_INTEGRITY
    return clampi(roundi(number), 0, MAX_INTEGRITY)

static func fresh() -> Dictionary:
    return {"engine": 100, "controls": 100, "plating": 100}

static func safe_row(input: Variant) -> Dictionary:
    var source: Dictionary = input if typeof(input) == TYPE_DICTIONARY else {}
    var out: Dictionary = fresh()
    for system_id in SYSTEMS:
        out[system_id] = condition(source.get(system_id, 100))
    return out

static func safe_roster(input: Variant) -> Dictionary:
    var source: Dictionary = input if typeof(input) == TYPE_DICTIONARY else {}
    var result: Dictionary = {}
    for hull_id in HULLS:
        result[hull_id] = safe_row(source.get(hull_id, {}))
    return result

static func row_for(roster: Variant, hull_id: String) -> Dictionary:
    var safe: Dictionary = safe_roster(roster)
    var id: String = hull_id if valid_hull(hull_id) else "ship_scout"
    return (safe[id] as Dictionary).duplicate(true)

static func strike(roster: Variant, hull_id: String, actual_hull_damage: float) -> Dictionary:
    var safe: Dictionary = safe_roster(roster)
    if not valid_hull(hull_id) or not is_finite(actual_hull_damage) or (
            actual_hull_damage <= 0.0):
        return safe
    var hit: float = clampf(actual_hull_damage, 0.0, 160.0)
    var row: Dictionary = safe[hull_id]
    for system_id in SYSTEMS:
        var loss: int = clampi(ceili(hit * float(WEAR_RATIOS[system_id])), 1, 35)
        row[system_id] = maxi(0, int(row[system_id]) - loss)
    safe[hull_id] = row
    return safe

static func quote(roster: Variant, hull_id: String, system_id: String) -> int:
    if not valid_hull(hull_id) or not valid_system(system_id):
        return 0
    var row: Dictionary = row_for(roster, hull_id)
    var lost: int = MAX_INTEGRITY - int(row[system_id])
    return ceili(float(lost) / 10.0) * int(SERVICE_COSTS[system_id])

static func repair(roster: Variant, hull_id: String, system_id: String) -> Dictionary:
    var safe: Dictionary = safe_roster(roster)
    var cost: int = quote(safe, hull_id, system_id)
    var result: Dictionary = {"ok": false, "cost": cost, "roster": safe}
    if cost <= 0:
        return result
    var row: Dictionary = safe[hull_id]
    row[system_id] = MAX_INTEGRITY
    safe[hull_id] = row
    result["ok"] = true
    result["roster"] = safe
    return result

static func engine_factor(input: Variant) -> float:
    return 0.74 + 0.26 * float(condition(input)) / 100.0

static func steering_factor(input: Variant) -> float:
    return 0.76 + 0.24 * float(condition(input)) / 100.0

static func armor_factor(input: Variant) -> float:
    return 1.0 + 0.20 * (1.0 - float(condition(input)) / 100.0)

static func system_label(system_id: String) -> String:
    match system_id:
        "engine": return "ДВИГАТЕЛЬ"
        "controls": return "ПРИВОДЫ УПРАВЛЕНИЯ"
        "plating": return "ОБШИВКА"
        _: return "НЕИЗВЕСТНЫЙ УЗЕЛ"

static func summary(roster: Variant, hull_id: String) -> String:
    var row: Dictionary = row_for(roster, hull_id)
    return "ДВИГАТЕЛЬ %d%% · РУЛИ %d%% · ОБШИВКА %d%%" % [
        int(row["engine"]), int(row["controls"]), int(row["plating"])]
