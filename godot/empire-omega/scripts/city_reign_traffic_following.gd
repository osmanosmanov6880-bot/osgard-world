extends RefCounted
## R163 / CITY REIGN. Deterministic, bounded following for ACTUAL AI
## CharacterBody3D traffic. This is complementary to original physical
## raycast, signal, pedestrian and civic-speed limits; never increases them.
const SAFETY = preload("res://scripts/traffic_safety.gd")
const MAX_NEIGHBORS: int = 16
const FOLLOW_RANGE: float = 44.0
const LANE_HALF_WIDTH: float = 2.55
const MAX_VERTICAL_DIFFERENCE: float = 2.8
const LEADER_HALF_LENGTH: float = 2.05

static func speed_cap(follower: Vector3,heading: Vector3,follower_speed: float,
        leader: Vector3,leader_velocity: Vector3,cruise: float,wetness: float) -> float:
    var allowed: float = maxf(0.0,cruise) if is_finite(cruise) else 0.0
    if not follower.is_finite() or not heading.is_finite() or not leader.is_finite() or not leader_velocity.is_finite():
        return allowed
    if not is_finite(follower_speed) or not is_finite(wetness):
        return allowed
    if absf(follower.y-leader.y)>MAX_VERTICAL_DIFFERENCE:
        return allowed
    var forward := Vector2(heading.x,heading.z)
    if forward.length_squared()<0.001:
        return allowed
    forward = forward.normalized()
    var offset := Vector2(leader.x-follower.x,leader.z-follower.z)
    var along: float = offset.dot(forward)
    if along<=0.0 or along>FOLLOW_RANGE:
        return allowed
    var side := Vector2(-forward.y,forward.x)
    if absf(offset.dot(side))>LANE_HALF_WIDTH:
        return allowed
    var other := Vector2(leader_velocity.x,leader_velocity.z)
    # Cars crossing perpendicularly (or going the other way) are handled
    # by the ORIGINAL Godot physics ray. Only SAME-LANE flow is paced here.
    if other.length_squared()>1.0 and other.normalized().dot(forward)<0.65:
        return allowed
    var available: float = maxf(0.0,along-LEADER_HALF_LENGTH*2.0)
    var headway: float = SAFETY.MIN_GAP+clampf(maxf(0.0,follower_speed)*0.66,0.0,13.0)
    var leader_speed: float = maxf(0.0,other.dot(forward))
    var smooth_target: float = leader_speed+maxf(0.0,available-headway)*0.76
    var stop_bound: float = SAFETY.safe_speed(available,allowed,wetness)
    return clampf(minf(allowed,minf(smooth_target,stop_bound)),0.0,allowed)

static func scan(car: Node3D,neighbors: Array,heading: Vector3,
        own_speed: float,cruise: float,wetness: float) -> float:
    var allowed: float = maxf(0.0,cruise) if is_finite(cruise) else 0.0
    if car==null or not is_instance_valid(car):
        return allowed
    if not car.global_position.is_finite():
        return allowed
    for i in range(mini(MAX_NEIGHBORS,neighbors.size())):
        var other: Variant = neighbors[i]
        if not is_instance_valid(other) or not other is Node3D:
            continue
        var vehicle: Node3D = other as Node3D
        if vehicle==car or not vehicle.visible:
            continue
        var velocity_value: Variant = vehicle.get("velocity")
        if not velocity_value is Vector3:
            continue
        allowed = minf(allowed,speed_cap(car.global_position,heading,own_speed,
            vehicle.global_position,velocity_value,cruise,wetness))
        if allowed<SAFETY.STOP_EPSILON:
            return 0.0
    return allowed
