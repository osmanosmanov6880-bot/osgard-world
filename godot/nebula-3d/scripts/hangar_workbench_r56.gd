extends RefCounted
## R56: local CR-only engineering upgrades bound to each REAL owned hull.
## No premium, billing, third-party entitlements or reward system here.
const SHIP_IDS: Array[String] = ["ship_scout", "ship_interceptor", "ship_guardian"]
const MODULES: Array[String] = ["armor", "shield", "radar"]
const MAX_RANK: int = 3
const COST_BASE: Dictionary = {"armor": 500, "shield": 550, "radar": 400}
const COST_STEP: Dictionary = {"armor": 400, "shield": 450, "radar": 320}
const HULL_GAIN_PER_RANK: float = 20.0
const SHIELD_GAIN_PER_RANK: float = 25.0
const RADAR_GAIN_PER_RANK: float = 100.0
const RADAR_BASE_RANGE: float = 460.0

static func is_valid_ship(ship_id: String) -> bool:
    return SHIP_IDS.has(ship_id)

static func is_valid_module(module_id: String) -> bool:
    return MODULES.has(module_id)

static func sanitized_rank(value: Variant) -> int:
    if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
        return 0
    var n: float = float(value)
    if not is_finite(n):
        return 0
    return clampi(int(n), 0, MAX_RANK)

static func default_roster() -> Dictionary:
    return {
        "ship_scout": {"armor":0, "shield":0, "radar":0},
        "ship_interceptor": {"armor":0, "shield":0, "radar":0},
        "ship_guardian": {"armor":0, "shield":0, "radar":0},
    }

static func safe_roster(raw: Variant) -> Dictionary:
    var result: Dictionary = default_roster()
    if typeof(raw) != TYPE_DICTIONARY:
        return result
    for id in SHIP_IDS:
        var provided: Variant = raw.get(id, {})
        if typeof(provided) != TYPE_DICTIONARY:
            continue
        var values: Dictionary = provided
        var record: Dictionary = result[id]
        for module_id in MODULES:
            record[module_id] = sanitized_rank(values.get(module_id, 0))
    return result

static func rank_of(roster: Dictionary, ship_id: String,
        module_id: String) -> int:
    if not is_valid_ship(ship_id) or not is_valid_module(module_id):
        return 0
    var row: Variant = roster.get(ship_id, {})
    if typeof(row) != TYPE_DICTIONARY:
        return 0
    return sanitized_rank(row.get(module_id, 0))

static func upgrade_cost(module_id: String, current_rank: int) -> int:
    if not is_valid_module(module_id):
        return -1
    var current: int = clampi(current_rank, 0, MAX_RANK)
    if current >= MAX_RANK:
        return 0
    return int(COST_BASE[module_id]) + current * int(COST_STEP[module_id])

static func hull_cap(base_cap: float, armor_rank: int) -> float:
    return maxf(1.0, base_cap) + float(clampi(armor_rank, 0, MAX_RANK)) * HULL_GAIN_PER_RANK

static func shield_cap(base_cap: float, shield_rank: int) -> float:
    return maxf(0.0, base_cap) + float(clampi(shield_rank, 0, MAX_RANK)) * SHIELD_GAIN_PER_RANK

static func radar_range(radar_rank: int) -> float:
    return RADAR_BASE_RANGE + float(clampi(radar_rank, 0, MAX_RANK)) * RADAR_GAIN_PER_RANK

static func module_label(module_id: String) -> String:
    match module_id:
        "armor":
            return "БРОНЯ · +20 КОРПУС"
        "shield":
            return "ЩИТ · +25 ЕД."
        "radar":
            return "РАДАР · +100 М"
        _:
            return "НЕИЗВЕСТНЫЙ МОДУЛЬ"

static func next_delta(module_id: String, current_rank: int) -> String:
    if not is_valid_module(module_id):
        return ""
    if sanitized_rank(current_rank) >= MAX_RANK:
        return "МАКСИМУМ"
    match module_id:
        "armor":
            return "КОРПУС +20"
        "shield":
            return "ЩИТ +25"
        _:
            return "ОБНАРУЖЕНИЕ +100 М"
