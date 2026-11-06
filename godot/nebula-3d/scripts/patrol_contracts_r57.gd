extends RefCounted
## NEBULA R57: repeatable post-campaign flight contracts.
## Nothing pays when accepting a job, reaching one point, dying, or timing out.
## Real world physics, flight inputs and mission navigation drive every step.
const CONTRACT_IDS: Array[String] = ["aurora","neon","rift"]
const CHECKPOINT_RADIUS_M: float = 54.0
const CHECKPOINT_HOLD_SEC: float = 1.50
const MAX_FINISHES: int = 99999
const CATALOG: Dictionary = {
    "aurora": {
        "name": "ОБХОД АВРОРЫ",
        "description": "Облети сервисные маяки и вернись к родному доку.",
        "credits": 380, "xp": 90, "limit_sec": 420.0,
        "route": [
            Vector3(170.0, 34.0, -220.0),
            Vector3(-180.0, 32.0, -120.0),
            Vector3(0.0, 42.0, 60.0),
        ],
    },
    "neon": {
        "name": "НОЧНОЙ ДОЗОР",
        "description": "Проверь навигацию двух кварталов и порт.",
        "credits": 650, "xp": 160, "limit_sec": 660.0,
        "route": [
            Vector3(330.0, 43.0, -195.0),
            Vector3(610.0, 56.0, -330.0),
            Vector3(200.0, 48.0, -140.0),
            Vector3(0.0, 41.0, 55.0),
        ],
    },
    "rift": {
        "name": "РУБЕЖ РАЗЛОМА",
        "description": "Пройди дальнюю дугу Разлома и доставь разведданные.",
        "credits": 980, "xp": 260, "limit_sec": 1000.0,
        "route": [
            Vector3(300.0, 60.0, 350.0),
            Vector3(480.0, 72.0, 940.0),
            Vector3(210.0, 58.0, 650.0),
            Vector3(0.0, 41.0, 58.0),
        ],
    },
}

var active: bool = false
var active_id: String = ""
var checkpoint_index: int = 0
var checkpoint_hold: float = 0.0
var elapsed_seconds: float = 0.0
var finished: bool = false
var last_result: String = "idle"
var route_points_r58: Array[Vector3] = []
var limit_seconds_r58: float = 0.0
var risk_tier_r58: int = 0

static func valid_contract(id: String) -> bool:
    return CONTRACT_IDS.has(id)

static func safe_selection(candidate: Variant) -> String:
    var id: String = str(candidate) if typeof(candidate) == TYPE_STRING else ""
    return id if valid_contract(id) else ""

static func safe_finish_counts(candidate: Variant) -> Dictionary:
    var result: Dictionary = {"aurora":0, "neon":0, "rift":0}
    if typeof(candidate) != TYPE_DICTIONARY:
        return result
    for key in CONTRACT_IDS:
        var raw: Variant = candidate.get(key, 0)
        if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
            continue
        var number: float = float(raw)
        if is_finite(number):
            result[key] = clampi(int(number), 0, MAX_FINISHES)
    return result

static func catalog() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for id in CONTRACT_IDS:
        var cfg: Dictionary = CATALOG[id]
        result.append({
            "id": id,
            "title": str(cfg["name"]),
            "description": str(cfg["description"]),
            "credits": int(cfg["credits"]),
            "xp": int(cfg["xp"]),
            "duration_sec": float(cfg["limit_sec"]),
            "checkpoints": (cfg["route"] as Array).size(),
        })
    return result

static func reward_credits(id: String) -> int:
    return int(CATALOG[id]["credits"]) if valid_contract(id) else 0

static func reward_xp(id: String) -> int:
    return int(CATALOG[id]["xp"]) if valid_contract(id) else 0

static func checkpoint_count(id: String) -> int:
    return (CATALOG[id]["route"] as Array).size() if valid_contract(id) else 0

func begin(id: String) -> bool:
    if active or not valid_contract(id):
        return false
    active = true
    active_id = id
    checkpoint_index = 0
    checkpoint_hold = 0.0
    elapsed_seconds = 0.0
    finished = false
    last_result = "active"
    route_points_r58.clear()
    var base: Array = CATALOG[id]["route"]
    for coordinate in base:
        route_points_r58.append(coordinate as Vector3)
    limit_seconds_r58 = float(CATALOG[id]["limit_sec"])
    risk_tier_r58 = 0
    return true

func configure_challenge_r58(points: Array[Vector3],
        time_seconds: float, tier: int) -> bool:
    # A route's additional difficulty must be genuine physical waypoints.
    # It may only be bound before the first real physics frame.
    if not active or tier < 0 or tier > 2 or (
            elapsed_seconds > 0.0 or checkpoint_index != 0):
        return false
    var base: Array = CATALOG[active_id]["route"]
    if points.size() != base.size() + tier:
        return false
    for i in base.size():
        if points[i].distance_to(base[i] as Vector3) > 0.01:
            return false
    if tier >= 1 and points[base.size()].distance_to(
            base[base.size() - 2] as Vector3) > 0.01:
        return false
    if tier >= 2 and points[base.size() + 1].distance_to(
            base[base.size() - 3] as Vector3) > 0.01:
        return false
    var ratios: Array[float] = [1.0, 0.85, 0.70]
    var expected: float = float(CATALOG[active_id]["limit_sec"]) * ratios[tier]
    if not is_finite(time_seconds) or absf(expected - time_seconds) > 0.02:
        return false
    route_points_r58.clear()
    for point in points:
        route_points_r58.append(point)
    risk_tier_r58 = tier
    limit_seconds_r58 = time_seconds
    return true

func route_size_r58() -> int:
    return route_points_r58.size() if active or finished else 0

func objective_position() -> Vector3:
    if not active or not valid_contract(active_id):
        return Vector3.ZERO
    if checkpoint_index < 0 or checkpoint_index >= route_points_r58.size():
        return Vector3.ZERO
    return route_points_r58[checkpoint_index]

func seconds_remaining() -> float:
    if not active or not valid_contract(active_id):
        return 0.0
    return maxf(0.0, limit_seconds_r58 - elapsed_seconds)

func tick(raw_dt: float, ship_position: Vector3) -> String:
    if not active or not valid_contract(active_id):
        return "idle"
    var dt: float = clampf(raw_dt, 0.0, 0.25)
    if dt <= 0.0:
        return "active"
    elapsed_seconds += dt
    if elapsed_seconds >= limit_seconds_r58:
        active = false
        last_result = "failed"
        return "failed"
    var at_checkpoint: bool = ship_position.distance_to(
        objective_position()) <= CHECKPOINT_RADIUS_M
    if at_checkpoint:
        checkpoint_hold += dt
    else:
        checkpoint_hold = 0.0
    if checkpoint_hold < CHECKPOINT_HOLD_SEC:
        return "active"
    checkpoint_hold = 0.0
    checkpoint_index += 1
    if checkpoint_index >= route_points_r58.size():
        active = false
        finished = true
        last_result = "success"
        return "success"
    last_result = "checkpoint"
    return "checkpoint"

func abandon() -> void:
    active = false
    checkpoint_index = 0
    checkpoint_hold = 0.0
    finished = false
    last_result = "abandoned"
