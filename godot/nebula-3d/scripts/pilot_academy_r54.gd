extends RefCounted
## R54: local game-credit pilot training. No real-money entitlements and no
## second rewards ledger. Every captain keeps an independent saved rank.
const MAX_RANK: int = 3
const TRAINING_COSTS: Array[int] = [650, 1100, 1800]
const VALID_PILOTS: Array[String] = ["ada", "kai", "leya"]

static func valid_pilot(id: String) -> bool:
    return VALID_PILOTS.has(id)

static func rank(value: Variant) -> int:
    if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
        return 0
    var number: float = float(value)
    if not is_finite(number):
        return 0
    return clampi(int(number), 0, MAX_RANK)

static func cost(current_rank: int) -> int:
    var current: int = clampi(current_rank, 0, MAX_RANK)
    return TRAINING_COSTS[current] if current < MAX_RANK else 0

static func damage_multiplier(captain_id: String,
        base_multiplier: float, current_rank: int) -> float:
    if captain_id != "ada":
        return base_multiplier
    return maxf(0.79, base_multiplier - float(rank(current_rank)) * 0.03)

static func thrust_multiplier(captain_id: String,
        base_multiplier: float, current_rank: int) -> float:
    if captain_id != "kai":
        return base_multiplier
    return minf(1.20, base_multiplier + float(rank(current_rank)) * 0.04)

static func credit_bonus(base_credits: int, captain_id: String,
        current_rank: int) -> int:
    if captain_id != "leya":
        return 0
    return maxi(0, roundi(float(maxi(0, base_credits)) *
        0.04 * float(rank(current_rank))))

static func describe(captain_id: String, current_rank: int) -> String:
    var value: int = rank(current_rank)
    match captain_id:
        "ada":
            return "ТАКТИКА · ДОПОЛНИТЕЛЬНАЯ ЗАЩИТА %d%%" % (value * 3)
        "kai":
            return "ПИЛОТИРОВАНИЕ · ДОП. ТЯГА +%d%%" % (value * 4)
        "leya":
            return "ЛОГИСТИКА · ДОП. КРЕДИТЫ +%d%%" % (value * 4)
        _:
            return "НЕИЗВЕСТНЫЙ ПИЛОТ"

static func safe_roster(source: Variant) -> Dictionary:
    var safe: Dictionary = {"ada":0, "kai":0, "leya":0}
    if typeof(source) != TYPE_DICTIONARY:
        return safe
    for id in VALID_PILOTS:
        safe[id] = rank(source.get(id, 0))
    return safe
