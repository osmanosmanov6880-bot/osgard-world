extends RefCounted
## Deterministic 3D ballistic motion constrained to one play plane.
## This single integrator is used by BOTH runtime and the trajectory preview.

const GRAVITY: float = 9.8
const DRAG: float = 0.065
const MAX_FIELD_ACCEL: float = 16.0
const MAGNET_SOFTENING: float = 5.5
const FLOOR_Y: float = 0.85
const EXIT_X: float = 13.1
const STEP: float = 1.0 / 120.0

static func acceleration(position: Vector3, magnet: Vector3, polarity: int, field_strength: float) -> Vector3:
    var delta: Vector3 = magnet - position
    delta.z = 0.0
    var distance_squared: float = delta.length_squared()
    if distance_squared < 0.00001:
        return Vector3(0.0, -GRAVITY, 0.0)
    var field_accel: float = minf(field_strength * 8.0 / (distance_squared + MAGNET_SOFTENING), MAX_FIELD_ACCEL)
    return Vector3(0.0, -GRAVITY, 0.0) + delta.normalized() * field_accel * float(polarity)

static func step(position: Vector3, velocity: Vector3, magnet: Vector3, polarity: int, field_strength: float, delta: float) -> Dictionary:
    var acceleration_now: Vector3 = acceleration(position, magnet, polarity, field_strength) - velocity * DRAG
    var velocity_next: Vector3 = velocity + acceleration_now * delta
    var position_next: Vector3 = position + velocity_next * delta
    position_next.z = 0.0
    velocity_next.z = 0.0
    return {"position": position_next, "velocity": velocity_next}

static func reached_target(position: Vector3, target: Vector3) -> bool:
    return position.distance_to(target) <= 1.05

static func is_lost(position: Vector3) -> bool:
    return position.y <= FLOOR_Y or position.x > EXIT_X or position.y > 14.0 or position.x < -12.0

static func simulate(start: Vector3, launch_velocity: Vector3, magnet: Vector3, polarity: int, field_strength: float, target: Vector3, count: int = 280, stride: int = 3) -> Dictionary:
    var samples: Array[Vector3] = [start]
    var position: Vector3 = start
    var velocity: Vector3 = launch_velocity
    var outcome: String = "flying"
    for i in range(count):
        var next_state: Dictionary = step(position, velocity, magnet, polarity, field_strength, STEP)
        position = next_state.position
        velocity = next_state.velocity
        if i % maxi(stride, 1) == 0:
            samples.append(position)
        if reached_target(position, target):
            outcome = "reached"
            samples.append(position)
            break
        if is_lost(position):
            outcome = "lost"
            samples.append(position)
            break
    return {"samples": samples, "outcome": outcome, "end": position}