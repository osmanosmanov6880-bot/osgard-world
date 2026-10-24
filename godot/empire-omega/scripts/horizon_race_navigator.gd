extends RefCounted
## HORIZON R9. Pure presentation of the real driving academy state.
## Progress and rewards remain exclusively in driving_trials.gd and GameState.
const DIRECTIONS = {
    "ru":{"ahead":"ПРЯМО","left":"НАЛЕВО","right":"НАПРАВО","back":"РАЗВОРОТ","goal":"ТОЧКА"},
    "en":{"ahead":"STRAIGHT","left":"LEFT","right":"RIGHT","back":"TURN BACK","goal":"GATE"},
    "zh":{"ahead":"直行","left":"左转","right":"右转","back":"掉头","goal":"关卡"}
}

static func view(route: Dictionary, active: Dictionary, player_position: Vector3,
        vehicle_yaw: float, locale: String = "ru", compact: bool = false) -> Dictionary:
    if route.is_empty() or active.is_empty() or not is_finite(vehicle_yaw):
        return {}
    var points: Variant = route.get("checkpoints",[])
    if not (points is Array) or points.is_empty():
        return {}
    var step: int = int(active.get("step",-1))
    if step < 0 or step >= points.size():
        return {}
    var pair: Variant = points[step]
    if not (pair is Array) or pair.size() != 2:
        return {}
    var target_x: float = float(pair[0])
    var target_z: float = float(pair[1])
    if not is_finite(target_x) or not is_finite(target_z):
        return {}
    var difference := Vector2(target_x-player_position.x,target_z-player_position.z)
    var distance: float = difference.length()
    if not is_finite(distance):
        return {}
    var heading := Vector2(-sin(vehicle_yaw),-cos(vehicle_yaw))
    var right := Vector2(cos(vehicle_yaw),-sin(vehicle_yaw))
    var ahead: float = difference.dot(heading)
    var side: float = difference.dot(right)
    var tr: Dictionary = DIRECTIONS.get(locale,DIRECTIONS["ru"])
    var direction: String = str(tr["ahead"])
    if distance <= 10.0:
        direction = str(tr["goal"])
    elif ahead < -absf(side)*0.65:
        direction = str(tr["back"])
    elif side > absf(ahead)*0.50:
        direction = str(tr["right"])
    elif side < -absf(ahead)*0.50:
        direction = str(tr["left"])
    var limit_seconds: float = maxf(0.0,float(route.get("limit_seconds",0)))
    var elapsed: float = maxf(0.0,float(active.get("elapsed",0)))
    var remaining: int = maxi(0,ceili(limit_seconds-elapsed))
    var title_map: Dictionary = route.get("title",{})
    var title: String = str(title_map.get(locale,title_map.get("ru","DRIVING TRIAL")))
    var checkpoint: String = "%d/%d" % [step+1,points.size()]
    var heading_text: String = (title.left(16)+"…") if compact and title.length()>16 else title
    var label: String = "%s · %s" % [heading_text,checkpoint]
    var details: String = "%s · %d м · %d с" % [direction,roundi(distance),remaining]
    return {"title":label,"details":details,"checkpoint":step+1,
        "total":points.size(),"direction":direction,"distance":distance,
        "seconds":remaining}
