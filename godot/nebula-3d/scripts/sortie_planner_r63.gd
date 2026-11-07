extends RefCounted
## R63: real flight-planning intelligence, never pays/unlocks anything.
const PatrolR57 = preload("res://scripts/patrol_contracts_r57.gd")
const CareerR58 = preload("res://scripts/career_prestige_r58.gd")
const CaptainsR42 = preload("res://scripts/captain_roster_r42.gd")
const AcademyR54 = preload("res://scripts/pilot_academy_r54.gd")
const ASSUMED_CRUISE_MPS: float = 70.0
const MAX_SAVED_DISTANCE: int = 250000
const MAX_SAVED_SECONDS: int = 36000

static func _distance(start: Vector3, points: Array[Vector3]) -> float:
    var total: float = 0.0
    var previous: Vector3 = start
    for point in points:
        total += previous.distance_to(point)
        previous = point
    return total

static func plan(mission_index: int, missions: Array, contract: String,
        risk: int, counts: Dictionary, pilot_id: String,
        academy_roster: Dictionary, launch_position: Vector3,
        rockets: int, wingmen: int) -> Dictionary:
    var result: Dictionary = {
        "mode": "free", "title": "СВОБОДНЫЙ ПОЛЁТ",
        "objective": "Шесть районов Авроры без обязательной цели",
        "route_m": 0, "estimated_seconds": 0,
        "waypoints": 0, "credits": 0, "xp": 0,
        "time_limit_sec": 0, "risk_tier": 0,
        "route_points": [], "rocket_count": maxi(0, rockets),
        "wingmen": clampi(wingmen, 0, 2), "mission_type": "free"
    }
    if mission_index < 0:
        return result
    var rank: int = AcademyR54.rank(academy_roster.get(pilot_id, 0))
    var points: Array[Vector3] = []
    if mission_index < missions.size():
        var raw: Variant = missions[mission_index]
        if typeof(raw) != TYPE_DICTIONARY:
            return result
        var m: Dictionary = raw
        var raw_target: Variant = m.get("position", Vector3.ZERO)
        if typeof(raw_target) != TYPE_VECTOR3:
            return result
        points.append(raw_target)
        var base_cr: int = clampi(int(m.get("reward", 0)), 0, 999999)
        result["mode"] = "campaign"
        result["title"] = str(m.get("title", "СЮЖЕТНОЕ ЗАДАНИЕ"))
        result["objective"] = str(m.get("hint", "Достигни цели"))
        result["mission_type"] = str(m.get("type", "reach"))
        # Staged missions change targets in play; this is the initial goal.
        result["credits"] = CaptainsR42.reward(base_cr, pilot_id) + (
            AcademyR54.credit_bonus(base_cr, pilot_id, rank))
        result["xp"] = 150 + mission_index * 65
    elif not contract.is_empty() and PatrolR57.valid_contract(contract):
        var tier: int = CareerR58.safe_selected_tier(risk, counts)
        points = CareerR58.challenge_route(contract, tier)
        var base_cr: int = CareerR58.earned_credits(contract, tier)
        result["mode"] = "contract"
        result["title"] = str(PatrolR57.CATALOG[contract]["name"])
        result["objective"] = str(
            PatrolR57.CATALOG[contract]["description"])
        result["mission_type"] = "patrol"
        result["risk_tier"] = tier
        result["time_limit_sec"] = ceili(
            CareerR58.available_seconds(contract, tier))
        result["credits"] = base_cr + AcademyR54.credit_bonus(
            base_cr, pilot_id, rank)
        result["xp"] = CareerR58.earned_xp(contract, tier)
    if not points.is_empty():
        var route_m: float = _distance(launch_position, points)
        result["route_m"] = roundi(route_m)
        result["estimated_seconds"] = ceili(
            route_m / ASSUMED_CRUISE_MPS)
        result["route_points"] = points
        result["waypoints"] = points.size()
    return result

static func course(position: Vector3, forward: Vector3,
        objective: Vector3, speed_mps: float) -> Dictionary:
    var gap: Vector3 = objective - position
    var distance_m: float = gap.length()
    var horizontal: Vector3 = Vector3(gap.x, 0.0, gap.z)
    if distance_m < 2.0 or horizontal.length_squared() < 0.01:
        return {"has_target": false, "distance_m": roundi(distance_m),
            "bearing_deg": 0, "eta_sec": 0, "side": "ПРЯМО"}
    var flat_forward: Vector3 = Vector3(forward.x, 0.0, forward.z)
    if flat_forward.length_squared() < 0.001:
        flat_forward = Vector3.FORWARD
    flat_forward = flat_forward.normalized()
    var flat_right: Vector3 = flat_forward.cross(Vector3.UP).normalized()
    var direction: Vector3 = horizontal.normalized()
    var angle: int = roundi(rad_to_deg(atan2(
        direction.dot(flat_right), direction.dot(flat_forward))))
    return {
        "has_target": true, "distance_m": roundi(distance_m),
        "bearing_deg": angle,
        "side": ("ПРЯМО" if absi(angle) <= 7 else
            "ВПРАВО" if angle > 0 else "ВЛЕВО"),
        "eta_sec": ceili(distance_m / maxf(8.0, speed_mps))
            if speed_mps >= 8.0 else 0
    }

static func course_label(value: Dictionary, compact: bool = false) -> String:
    if not bool(value.get("has_target", false)):
        return "НАВИГАЦИЯ · ОЖИДАНИЕ ЦЕЛИ"
    var angle: int = absi(int(value.get("bearing_deg", 0)))
    var direction: String = str(value.get("side", "ПРЯМО"))
    var distance: int = maxi(0, int(value.get("distance_m", 0)))
    var eta: int = maxi(0, int(value.get("eta_sec", 0)))
    var text: String = "КУРС %s" % direction
    if angle > 7:
        text += " %d°" % angle
    text += " · %d М" % distance
    if eta > 0 and not compact:
        text += " · ≈%d С" % eta
    return text

static func _safe_metric(input: Variant, limit: int) -> int:
    if typeof(input) != TYPE_INT and typeof(input) != TYPE_FLOAT:
        return 0
    var v: float = float(input)
    return clampi(int(v), 0, limit) if is_finite(v) else 0

static func safe_debrief(input: Variant) -> Dictionary:
    if typeof(input) != TYPE_DICTIONARY:
        return {}
    var data: Dictionary = input
    var pilot: String = str(data.get("pilot", ""))
    var status: String = str(data.get("outcome", ""))
    var mode: String = str(data.get("mode", ""))
    if not CaptainsR42.valid_id(pilot) or not (
            status in ["success", "failed"]) or not (
            mode in ["campaign", "contract", "free"]):
        return {}
    return {
        "pilot": pilot, "outcome": status, "mode": mode,
        "distance_m": _safe_metric(data.get("distance_m", 0),
            MAX_SAVED_DISTANCE),
        "seconds": _safe_metric(data.get("seconds", 0),
            MAX_SAVED_SECONDS),
    }

static func debrief_text(input: Variant) -> String:
    var report: Dictionary = safe_debrief(input)
    if report.is_empty():
        return "ПОСЛЕДНИЙ ВЫЛЕТ · ПОКА НЕТ"
    var names: Dictionary = {"ada":"АДА", "kai":"КАЙ", "leya":"ЛЕЯ"}
    return "ПОСЛЕДНИЙ ВЫЛЕТ · %s · %s\n%s · %d М · %d С" % [
        str(names[report["pilot"]]),
        "ВЫПОЛНЕН" if report["outcome"] == "success" else "НЕУДАЧА",
        {"campaign":"СЮЖЕТ", "contract":"КОНТРАКТ",
        "free":"СВОБОДНЫЙ ПОЛЁТ"}[report["mode"]],
        int(report["distance_m"]), int(report["seconds"])
    ]
