extends RefCounted
class_name A7CascadeCore
## W63 independent original gameplay experiment. Entirely fictional.
## Do not use it to make decisions about physical industrial equipment.

signal changed(state: Dictionary)

const MAX_SHIFTS: int = 6
const ACTIONS: Dictionary = {
    "PUMP": {"heat": -20, "pressure": 8, "energy": -6},
    "VENT": {"heat": -6, "pressure": -23, "seal": -5, "energy": -2},
    "SEAL": {"pressure": 4, "seal": 24, "energy": -7},
    "SCAN": {"heat": 5, "signal": 22, "energy": -7},
    "POWER": {"heat": 3, "pressure": 4, "signal": -3, "energy": 28},
}
const INCIDENTS: Array[Dictionary] = [
    {"heat": 12, "pressure": 6, "seal": -4, "signal": -5},
    {"heat": 18, "seal": -4, "energy": -4},
    {"heat": 7, "pressure": 7, "signal": -16},
    {"heat": 8, "pressure": 17, "seal": -13},
    {"heat": 7, "pressure": 6, "signal": -7, "energy": -18},
    {"heat": 16, "pressure": 7, "seal": -8, "signal": -5},
]

var metrics: Dictionary = {}
var shift: int = 0
var actions_left: int = 2
var status: String = "playing"
var last_event: String = "begin"
var action_history: Array[Dictionary] = []
var incidents_survived: int = 0

func _init() -> void:
    reset()

func reset() -> void:
    metrics = {"heat": 62, "pressure": 48, "seal": 68, "signal": 44, "energy": 85, "integrity": 100}
    shift = 0
    actions_left = 2
    status = "playing"
    last_event = "begin"
    action_history.clear()
    incidents_survived = 0
    changed.emit(snapshot())

func _modify(delta: Dictionary) -> void:
    for key in delta.keys():
        var number: int = int(metrics.get(key, 0))
        metrics[key] = clampi(number + int(delta[key]), 0, 100)

func choose(action: String) -> bool:
    if status != "playing" or actions_left <= 0 or not ACTIONS.has(action):
        return false
    _modify(ACTIONS[action])
    action_history.append({"shift": shift, "action": action})
    actions_left -= 1
    last_event = "action_" + action.to_lower()
    if actions_left == 0:
        _advance_shift()
    changed.emit(snapshot())
    return true

func _advance_shift() -> void:
    _modify(INCIDENTS[shift])
    shift += 1
    incidents_survived += 1
    last_event = "incident_%d" % shift
    var damage: int = 0
    if int(metrics["heat"]) > 85:
        damage += 15
    if int(metrics["pressure"]) > 85:
        damage += 18
    if int(metrics["seal"]) < 35:
        damage += 12
    if int(metrics["signal"]) < 30:
        damage += 8
    if int(metrics["energy"]) < 25:
        damage += 12
    if damage > 0:
        metrics["integrity"] = maxi(0, int(metrics["integrity"]) - damage)
        last_event = "damage_%d" % damage
    else:
        metrics["integrity"] = mini(100, int(metrics["integrity"]) + 3)
    if int(metrics["integrity"]) <= 0 or int(metrics["heat"]) >= 100 or \
            int(metrics["pressure"]) >= 100 or int(metrics["seal"]) <= 0 or \
            int(metrics["energy"]) <= 0:
        status = "failed"
        last_event = "containment_failure"
    elif shift >= MAX_SHIFTS:
        if _safe_end_state():
            status = "won"
            last_event = "contained"
        else:
            status = "unstable"
            last_event = "unstable"
    else:
        actions_left = 2

func _safe_end_state() -> bool:
    return int(metrics["heat"]) <= 75 and int(metrics["pressure"]) <= 75 and \
        int(metrics["seal"]) >= 50 and int(metrics["signal"]) >= 50 and \
        int(metrics["energy"]) >= 30 and int(metrics["integrity"]) >= 55

func snapshot() -> Dictionary:
    return {
        "schema": "A7_CASCADE_LOCAL_SINGLE_PLAYER_V1",
        "metrics": metrics.duplicate(true),
        "shift": shift, "actions_left": actions_left,
        "status": status, "last_event": last_event,
        "incidents_survived": incidents_survived,
        "history": action_history.duplicate(true),
        "offline_only": true, "connected_to_real_equipment": false,
        "production_ready": false,
    }
