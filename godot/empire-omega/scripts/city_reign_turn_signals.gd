extends RefCounted
## CITY REIGN R161 — deterministic, allocation-free turn intent and flash.
## World directions use X/Z. This is cosmetic driving feedback only:
## no money, fines, collisions, road routing or save-state authority.
const PERIOD: float = 0.88
const ON_SECONDS: float = 0.44
const APPROACH_METRES: float = 24.0
const MIN_TURN_RADIANS: float = 0.34

static func normalized_mode(value: String) -> String:
    return value if ["off","left","right","hazard"].has(value) else "off"

static func toggle(current: String,requested: String) -> String:
    var next: String = normalized_mode(requested)
    if next=="off":
        return normalized_mode(current)
    return "off" if normalized_mode(current)==next else next

static func phase_after(phase: float,seconds: float) -> float:
    if not is_finite(phase) or not is_finite(seconds):
        return 0.0
    return fposmod(phase+clampf(seconds,0.0,0.20),PERIOD)

static func side_on(mode: String,side: String,phase: float) -> bool:
    if side!="left" and side!="right":
        return false
    if not is_finite(phase):
        return false
    var active: String = normalized_mode(mode)
    return (active=="hazard" or active==side) and fposmod(phase,PERIOD)<ON_SECONDS

static func upcoming(first: Vector3,second: Vector3,metres: float) -> String:
    if not first.is_finite() or not second.is_finite() or not is_finite(metres):
        return "off"
    if metres<0.0 or metres>APPROACH_METRES:
        return "off"
    var a: Vector2 = Vector2(first.x,first.z)
    var b: Vector2 = Vector2(second.x,second.z)
    if a.length_squared()<0.001 or b.length_squared()<0.001:
        return "off"
    a = a.normalized()
    b = b.normalized()
    # With Godot front=-Z, cross(a,b)>0 is a RIGHT turn.
    var signed: float = atan2(a.x*b.y-a.y*b.x,a.dot(b))
    if absf(signed)<MIN_TURN_RADIANS or absf(signed)>PI*0.92:
        return "off"
    return "right" if signed>0.0 else "left"
