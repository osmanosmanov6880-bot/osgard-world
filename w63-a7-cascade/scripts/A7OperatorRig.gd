extends CharacterBody3D
class_name A7OperatorRig
## W67 playable first-person movement within the original fictional A7
## facility. Reads input and describes context; cannot alter game rules.

const SPEED: float = 3.25
const LEFT_LIMIT: float = -5.85
const RIGHT_LIMIT: float = 5.85
const BACK_LIMIT: float = 3.98
const FRONT_LIMIT: float = -3.65
const START := Vector3(0.0, 0.91, 3.45)

var active: bool = false
var move_intent: Vector2 = Vector2.ZERO
var camera_eyes: Camera3D
var capsule_collider: CollisionShape3D
var distance_travelled: float = 0.0
var movement_frames: int = 0
var blocked_attempts: int = 0
var eye_pitch: float = 0.0
var current_sector: String = "central"

func _ready() -> void:
    name = "ActualPlayableA7FirstPersonOperator"
    position = START
    capsule_collider = CollisionShape3D.new()
    capsule_collider.name = "OperatorActualCapsuleCollider"
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.32
    capsule.height = 1.74
    capsule_collider.shape = capsule
    add_child(capsule_collider)
    camera_eyes = Camera3D.new()
    camera_eyes.name = "A7OperatorTrueFirstPersonCamera"
    camera_eyes.position = Vector3(0, 0.69, 0)
    camera_eyes.fov = 72
    camera_eyes.near = 0.08
    camera_eyes.far = 65.0
    camera_eyes.current = false
    add_child(camera_eyes)
    set_physics_process(true)
    _refresh_sector()

func set_active(enabled: bool) -> void:
    active = enabled
    if camera_eyes != null:
        camera_eyes.current = enabled
    if not enabled:
        move_intent = Vector2.ZERO
        velocity = Vector3.ZERO

func set_move_intent(intent: Vector2) -> void:
    if not active:
        move_intent = Vector2.ZERO
        return
    move_intent = intent.limit_length(1.0)

func look_by(yaw_degrees: float, pitch_degrees: float) -> void:
    if not active:
        return
    rotation.y += deg_to_rad(clampf(yaw_degrees, -30.0, 30.0))
    eye_pitch = clampf(eye_pitch + pitch_degrees, -60.0, 60.0)
    if camera_eyes != null:
        camera_eyes.rotation_degrees.x = eye_pitch

func reset_operator() -> void:
    position = START
    rotation.y = 0.0
    velocity = Vector3.ZERO
    move_intent = Vector2.ZERO
    eye_pitch = 0.0
    if camera_eyes != null:
        camera_eyes.rotation_degrees.x = 0.0
    distance_travelled = 0.0
    movement_frames = 0
    blocked_attempts = 0
    _refresh_sector()

func _physics_process(delta: float) -> void:
    if not active:
        return
    var direction: Vector3 = (global_transform.basis.x * move_intent.x -
        global_transform.basis.z * move_intent.y)
    direction.y = 0.0
    direction = direction.normalized() if direction.length() > 0.001 else Vector3.ZERO
    velocity = Vector3(direction.x * SPEED, -0.25, direction.z * SPEED)
    var previous: Vector3 = position
    move_and_slide()
    position.x = clampf(position.x, LEFT_LIMIT, RIGHT_LIMIT)
    position.z = clampf(position.z, FRONT_LIMIT, BACK_LIMIT)
    position.y = clampf(position.y, 0.87, 1.05)
    var displacement: Vector3 = position - previous
    displacement.y = 0.0
    distance_travelled += displacement.length()
    if move_intent.length_squared() > 0.01:
        movement_frames += 1
        if displacement.length_squared() < 0.00001:
            blocked_attempts += 1
    _refresh_sector()

func _refresh_sector() -> void:
    if position.x < -3.10:
        current_sector = "coolant"
    elif position.x > 3.10:
        current_sector = "pressure"
    else:
        current_sector = "central"

func context_action() -> String:
    if not active:
        return ""
    match current_sector:
        "coolant":
            return "PUMP"
        "pressure":
            return "SEAL"
        _:
            return "SCAN"

func qa_readout() -> Dictionary:
    return {
        "schema": "A7_W67_ACTUAL_NATIVE_OPERATOR_WALK_V1",
        "actual_character_body": true,
        "actual_collision_capsule": capsule_collider != null and
            capsule_collider.shape is CapsuleShape3D,
        "actual_first_person_camera": camera_eyes != null,
        "active": active,
        "position": [roundf(position.x * 1000.0) / 1000.0,
            roundf(position.y * 1000.0) / 1000.0,
            roundf(position.z * 1000.0) / 1000.0],
        "sector": current_sector,
        "context_action": context_action(),
        "move_intent": [move_intent.x, move_intent.y],
        "travel_metres": roundf(distance_travelled * 100.0) / 100.0,
        "movement_frames": movement_frames,
        "blocked_attempts": blocked_attempts,
        "real_hardware_certified": false,
        "gameplay_rules_mutated": false,
    }
