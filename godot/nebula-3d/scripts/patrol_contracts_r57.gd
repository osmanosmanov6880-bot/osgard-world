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
    return true

func objective_position() -> Vector3:
    if not active or not valid_contract(active_id):
        return Vector3.ZERO
    var route: Array = CATALOG[active_id]["route"]
    if checkpoint_index < 0 or checkpoint_index >= route.size():
        return Vector3.ZERO
    return route[checkpoint_index]

func seconds_remaining() -> float:
    if not active or not valid_contract(active_id):
        return 0.0
    return maxf(0.0, float(CATALOG[active_id]["limit_sec"]) - elapsed_seconds)

func tick(raw_dt: float, ship_position: Vector3) -> String:
    if not active or not valid_contract(active_id):
        return "idle"
    var dt: float = clampf(raw_dt, 0.0, 0.25)
    if dt <= 0.0:
        return "active"
    elapsed_seconds += dt
    if elapsed_seconds >= float(CATALOG[active_id]["limit_sec"]):
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
    if checkpoint_index >= checkpoint_count(active_id):
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
