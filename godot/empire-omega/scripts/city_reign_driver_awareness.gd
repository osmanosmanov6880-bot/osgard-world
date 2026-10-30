extends RefCounted
## CITY REIGN R162 — read-only, bounded near-lane safety advisor.
## Reuses true visible Node3D traffic velocity and pedestrian planned_velocity.
## This is NOT collision prevention, autopilot, enforcement or sensor hardware.
## No new colliders, physics raycasts, global allocations or reward writes.
const RANGE_M: float = 48.0
const MAX_TTC_SECONDS: float = 3.2
const URGENT_TTC_SECONDS: float = 1.35
const MIN_DRIVING_SPEED: float = 3.0
const MAX_TRAFFIC_SAMPLES: int = 18
const MAX_WALKER_SAMPLES: int = 42

static func inspect(relative: Vector3,heading: Vector3,our_speed: float,
        obstacle_velocity: Vector3,kind: String) -> Dictionary:
    if not relative.is_finite() or not heading.is_finite() or not is_finite(our_speed) or not obstacle_velocity.is_finite():
        return {}
    if our_speed<MIN_DRIVING_SPEED or kind!="vehicle" and kind!="pedestrian":
        return {}
    var forward: Vector2 = Vector2(heading.x,heading.z)
    if forward.length_squared()<0.001:
        return {}
    forward = forward.normalized()
    var rel: Vector2 = Vector2(relative.x,relative.z)
    var along: float = rel.dot(forward)
    if along<=0.0 or along>RANGE_M:
        return {}
    var moving: Vector2 = Vector2(obstacle_velocity.x,obstacle_velocity.z)
    var closing: float = our_speed-moving.dot(forward)
    if closing<=0.75:
        return {}
    var ttc: float = along/closing
    if ttc>MAX_TTC_SECONDS:
        return {}
    # A true route crossing is evaluated at future closest approach. A
    # pedestrian alongside the road moving parallel must not warn.
    var future: Vector2 = rel+moving*minf(ttc,MAX_TTC_SECONDS)
    var sideways: Vector2 = Vector2(-forward.y,forward.x)
    var lane: float = 2.35 if kind=="pedestrian" else 2.8
    if absf(future.dot(sideways))>lane:
        return {}
    return {
        "kind":kind,
        "urgency":"urgent" if ttc<URGENT_TTC_SECONDS else "caution",
        "seconds":ttc,
        "distance_m":along
    }

static func _better(candidate: Dictionary,current: Dictionary) -> bool:
    if candidate.is_empty(): return false
    if current.is_empty(): return true
    return float(candidate.get("seconds",MAX_TTC_SECONDS))<float(current.get("seconds",MAX_TTC_SECONDS))

static func scan(origin: Vector3,angle: float,speed: float,
        vehicles: Array,walkers: Array) -> Dictionary:
    if not origin.is_finite() or not is_finite(angle) or not is_finite(speed) or speed<MIN_DRIVING_SPEED:
        return {}
    var forward: Vector3 = Vector3(-sin(angle),0.0,-cos(angle))
    var best: Dictionary = {}
    for i in range(mini(vehicles.size(),MAX_TRAFFIC_SAMPLES)):
        var other: Variant = vehicles[i]
        if not is_instance_valid(other) or not other is Node3D or not (other as Node3D).visible:
            continue
        var vel: Variant = other.get("velocity")
        if not vel is Vector3: continue
        var risk: Dictionary = inspect((other as Node3D).global_position-origin,
            forward,speed,vel,"vehicle")
        if _better(risk,best): best=risk
    for i in range(mini(walkers.size(),MAX_WALKER_SAMPLES)):
        var person: Variant = walkers[i]
        if not is_instance_valid(person) or not person is Node3D or not (person as Node3D).visible:
            continue
        var motion: Variant = person.get("planned_velocity")
        if not motion is Vector3: continue
        var risk: Dictionary = inspect((person as Node3D).global_position-origin,
            forward,speed,motion,"pedestrian")
        if _better(risk,best): best=risk
    return best

static func localized(state: Dictionary,locale: String) -> String:
    if state.is_empty(): return ""
    var lang: String = locale if ["ru","en","zh"].has(locale) else "ru"
    # R184: native short legal 90km/h hint, strictly LESS urgent than
    # actual R162 collision, pedestrian or R178 red-signal awareness.
    if str(state.get("kind",""))=="road_closed":
        if lang=="ru":return "⚠ ДОРОГА ПЕРЕКРЫТА · ОБЪЕЗД"
        if lang=="en":return "⚠ ROAD CLOSED · DETOUR"
        return "⚠ 道路封闭 · 请绕行"
    if str(state.get("kind",""))=="junction_blocked":
        if lang=="ru":return "⚠ ПЕРЕКРЁСТОК ЗАНЯТ"
        if lang=="en":return "⚠ JUNCTION OCCUPIED"
        return "⚠ 路口被占用"
    if str(state.get("kind",""))=="speed_limit":
        var limit: int=int(state.get("limit_kmh",90))
        if lang=="ru":return "⚠ ОГРАНИЧЕНИЕ %d КМ/Ч" % limit
        if lang=="en":return "⚠ SPEED LIMIT %d KM/H" % limit
        return "⚠ 限速 %d 公里/小时" % limit
    # The same original signal phase that stops REAL NPC cars also informs
    # the physical human driver. This advisor does not control player input.
    if str(state.get("kind",""))=="signal":
        var amber: bool=str(state.get("phase",""))=="amber"
        if lang=="ru": return "⚠ ЖЁЛТЫЙ СИГНАЛ ВПЕРЕДИ" if amber else "⚠ КРАСНЫЙ СИГНАЛ ВПЕРЕДИ"
        if lang=="en": return "⚠ AMBER SIGNAL AHEAD" if amber else "⚠ RED SIGNAL AHEAD"
        return "⚠ 前方黄灯" if amber else "⚠ 前方红灯"
    var urgent: bool = str(state.get("urgency",""))=="urgent"
    var pedestrian: bool = str(state.get("kind",""))=="pedestrian"
    if lang=="ru":
        return ("⚠ ВНИМАНИЕ: " if urgent else "⚠ ") + (
            "ПЕШЕХОД ВПЕРЕДИ" if pedestrian else "МАШИНА ВПЕРЕДИ")
    if lang=="en":
        return ("⚠ CAUTION: " if urgent else "⚠ ") + (
            "PEDESTRIAN AHEAD" if pedestrian else "VEHICLE AHEAD")
    return ("⚠ 注意：" if urgent else "⚠ ") + ("前方行人" if pedestrian else "前方车辆")
