extends RefCounted
## CITY REIGN R162 — honest turn-by-turn from the SAME closed-road-aware
## native street route used by the minimap and world paint. Distances are
## measured along the remaining 2D graph polyline, NEVER straight-line GPS.
const ROAD_GUIDANCE = preload("res://scripts/city_reign_road_guidance.gd")
const OFF_ROUTE_METRES: float = 20.0
const ARRIVAL_METRES: float = 17.0
const MIN_TURN_RADIANS: float = 0.43
const MAX_ROUTE_POINTS: int = 128

static func _xz(point: Vector3) -> Vector2:
    return Vector2(point.x,point.z)

static func snapshot(path: Array[Vector3],at: Vector3) -> Dictionary:
    if not at.is_finite() or path.size()<2 or path.size()>MAX_ROUTE_POINTS:
        return {}
    for waypoint in path:
        if not waypoint.is_finite():
            return {}
    var nearest_index: int = -1
    var nearest_sq: float = INF
    var nearest_t: float = 0.0
    for i in range(path.size()-1):
        var first: Vector2 = _xz(path[i])
        var second: Vector2 = _xz(path[i+1])
        var span: Vector2 = second-first
        var length_sq: float = span.length_squared()
        if length_sq<0.01:
            continue
        var t: float = clampf((_xz(at)-first).dot(span)/length_sq,0.0,1.0)
        var distance_sq: float = (_xz(at)-(first+span*t)).length_squared()
        if distance_sq < nearest_sq:
            nearest_index = i
            nearest_sq = distance_sq
            nearest_t = t
    if nearest_index<0:
        return {}
    var separation: float = sqrt(nearest_sq)
    if separation>OFF_ROUTE_METRES:
        return {"kind":"off_route","lateral_m":separation}
    var remaining: float = 0.0
    for i in range(nearest_index,path.size()-1):
        var metres: float = (_xz(path[i+1])-_xz(path[i])).length()
        remaining += metres*(1.0-nearest_t) if i==nearest_index else metres
    if remaining<=ARRIVAL_METRES:
        return {"kind":"arrival","remaining_m":remaining,"lateral_m":separation}
    var first_dist: float = 0.0
    for i in range(nearest_index,path.size()-2):
        var start: Vector3 = path[i]
        var corner: Vector3 = path[i+1]
        var finish: Vector3 = path[i+2]
        var segment_m: float = (_xz(corner)-_xz(start)).length()
        first_dist += segment_m*(1.0-nearest_t) if i==nearest_index else segment_m
        # Ignore diagonal station-to-grid connectors and endpoints on
        # pavements or in mission buildings. Indicate only REAL road turns.
        if not ROAD_GUIDANCE.is_road_segment(start,corner):
            continue
        if not ROAD_GUIDANCE.is_road_segment(corner,finish):
            continue
        var incoming: Vector2 = _xz(corner)-_xz(start)
        var outgoing: Vector2 = _xz(finish)-_xz(corner)
        if incoming.length_squared()<1.0 or outgoing.length_squared()<1.0:
            continue
        incoming = incoming.normalized()
        outgoing = outgoing.normalized()
        var angle: float = atan2(incoming.x*outgoing.y-incoming.y*outgoing.x,
            incoming.dot(outgoing))
        if absf(angle)<MIN_TURN_RADIANS:
            continue
        var direction: String = "uturn" if absf(angle)>2.78 else ("right" if angle>0.0 else "left")
        return {
            "kind":direction,
            "turn_m":minf(remaining,first_dist),
            "remaining_m":remaining,
            "lateral_m":separation
        }
    return {"kind":"continue","remaining_m":remaining,"lateral_m":separation}

static func _distance(metres: float,locale: String) -> String:
    if not is_finite(metres):
        return "—"
    var bounded: float = maxf(0.0,metres)
    if bounded>=1000.0:
        return "%.1f km" % (bounded/1000.0) if locale=="en" else (
            "%.1f 公里" % (bounded/1000.0) if locale=="zh" else "%.1f км" % (bounded/1000.0))
    return "%d m" % roundi(bounded) if locale=="en" else (
        "%d 米" % roundi(bounded) if locale=="zh" else "%d м" % roundi(bounded))

static func localized(state: Dictionary,locale: String,compact: bool = false) -> String:
    if state.is_empty():
        return ""
    var lang: String = locale if ["ru","en","zh"].has(locale) else "ru"
    var kind: String = str(state.get("kind",""))
    if kind=="off_route":
        return "СВЕРЬТЕСЬ С КАРТОЙ" if lang=="ru" else ("CHECK THE MAP" if lang=="en" else "请查看地图")
    var distance: String = _distance(float(state.get("remaining_m",0.0)),lang)
    if kind=="arrival":
        return "ПУНКТ НАЗНАЧЕНИЯ · "+distance if lang=="ru" else (
            "DESTINATION · "+distance if lang=="en" else "即将抵达 · "+distance)
    var direction: String = ""
    match kind:
        "left":
            direction = "НАЛЕВО" if lang=="ru" else ("LEFT" if lang=="en" else "左转")
        "right":
            direction = "НАПРАВО" if lang=="ru" else ("RIGHT" if lang=="en" else "右转")
        "uturn":
            direction = "РАЗВОРОТ" if lang=="ru" else ("U-TURN" if lang=="en" else "掉头")
    if not direction.is_empty():
        var before: String = _distance(float(state.get("turn_m",0.0)),lang)
        if lang=="ru":
            return "ПОВОРОТ "+direction+" ЧЕРЕЗ "+before+("\n"+distance+" ПО МАРШРУТУ" if compact else " · "+distance+" ДО ЦЕЛИ")
        if lang=="en":
            return direction+" IN "+before+("\n"+distance+" ON ROUTE" if compact else " · "+distance+" TO GO")
        return before+" 后"+direction+("\n剩余 "+distance if compact else " · 剩余 "+distance)
    return ("ПО УЛИЦАМ · "+distance if lang=="ru" else (
        "FOLLOW ROAD · "+distance if lang=="en" else "沿道路行驶 · "+distance))
