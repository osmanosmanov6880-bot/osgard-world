extends RefCounted
## R61: independently earned flight records. Only real sortie completion
## writes to this record; no wallet, paid entitlements or account IDs.
const VALID_PILOTS: Array[String] = ["ada", "kai", "leya"]
const MAX_FLIGHTS: int = 99999
const MAX_METRIC: int = 99999999
const MAX_SORTIE_SECONDS: int = 36000
const MAX_SORTIE_DISTANCE: int = 250000

static func _safe_counter(value: Variant, cap: int) -> int:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return 0
    var number: float = float(value)
    if not is_finite(number):
        return 0
    return int(floorf(clampf(number, 0.0, float(cap)) + 0.5))

static func blank() -> Dictionary:
    return {
        "flights": 0, "successes": 0, "failures": 0,
        "distance_m": 0, "seconds": 0, "best_m": 0,
        "last_m": 0, "last_seconds": 0, "last_result": ""
    }

static func safe_record(value: Variant) -> Dictionary:
    var source: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
    var safe: Dictionary = blank()
    safe["flights"] = _safe_counter(source.get("flights", 0), MAX_FLIGHTS)
    safe["successes"] = mini(safe["flights"],
        _safe_counter(source.get("successes", 0), MAX_FLIGHTS))
    safe["failures"] = mini(safe["flights"] - safe["successes"],
        _safe_counter(source.get("failures", 0), MAX_FLIGHTS))
    safe["distance_m"] = _safe_counter(source.get("distance_m", 0), MAX_METRIC)
    safe["seconds"] = _safe_counter(source.get("seconds", 0), MAX_METRIC)
    safe["best_m"] = mini(safe["distance_m"],
        _safe_counter(source.get("best_m", 0), MAX_SORTIE_DISTANCE))
    safe["last_m"] = mini(safe["distance_m"],
        _safe_counter(source.get("last_m", 0), MAX_SORTIE_DISTANCE))
    safe["last_seconds"] = mini(safe["seconds"],
        _safe_counter(source.get("last_seconds", 0), MAX_SORTIE_SECONDS))
    var last: String = str(source.get("last_result", ""))
    safe["last_result"] = last if last in ["success", "failed"] else ""
    return safe

static func safe_roster(source: Variant) -> Dictionary:
    var raw: Dictionary = source if typeof(source) == TYPE_DICTIONARY else {}
    var safe: Dictionary = {}
    for pilot in VALID_PILOTS:
        safe[pilot] = safe_record(raw.get(pilot, {}))
    return safe

static func record(roster: Variant, pilot: String, outcome: String,
        distance_m: float, elapsed_seconds: float) -> Dictionary:
    var safe: Dictionary = safe_roster(roster)
    if not VALID_PILOTS.has(pilot) or not outcome in ["success", "failed"]:
        return safe
    var entry: Dictionary = safe[pilot]
    if int(entry["flights"]) >= MAX_FLIGHTS:
        return safe
    var metres: int = _safe_counter(distance_m, MAX_SORTIE_DISTANCE)
    var seconds: int = _safe_counter(elapsed_seconds, MAX_SORTIE_SECONDS)
    entry["flights"] = int(entry["flights"]) + 1
    if outcome == "success":
        entry["successes"] = int(entry["successes"]) + 1
    else:
        entry["failures"] = int(entry["failures"]) + 1
    entry["distance_m"] = mini(MAX_METRIC, int(entry["distance_m"]) + metres)
    entry["seconds"] = mini(MAX_METRIC, int(entry["seconds"]) + seconds)
    entry["best_m"] = maxi(int(entry["best_m"]), metres)
    entry["last_m"] = metres
    entry["last_seconds"] = seconds
    entry["last_result"] = outcome
    safe[pilot] = entry
    return safe

static func qualification(record_value: Variant) -> String:
    var item: Dictionary = safe_record(record_value)
    var completed: int = int(item["successes"])
    var distance: int = int(item["distance_m"])
    if completed >= 12 and distance >= 40000:
        return "АС ЭСКАДРИЛЬИ"
    if completed >= 5 and distance >= 12000:
        return "ОПЫТНЫЙ"
    if completed >= 1 and distance >= 1000:
        return "ПОДГОТОВЛЕН"
    return "КУРСАНТ"

static func summary(roster: Variant, pilot: String) -> String:
    var safe: Dictionary = safe_roster(roster)
    var id: String = pilot if VALID_PILOTS.has(pilot) else "ada"
    var record_item: Dictionary = safe[id]
    return "ЛЁТНАЯ КНИЖКА · %s\nВЫЛЕТОВ %d · ПОБЕД %d · АВАРИЙ %d · %0.1f КМ" % [
        qualification(record_item), int(record_item["flights"]),
        int(record_item["successes"]), int(record_item["failures"]),
        float(record_item["distance_m"]) / 1000.0
    ]
