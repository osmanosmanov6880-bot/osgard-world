extends CharacterBody3D
## R21: physics-based, responsive flight-assist instead of per-frame rotate/
## instant speed clamp. Keeps player progression and the R5-R14 hero model.
const ShipVisualR5Script = preload("res://scripts/ship_visual_r5.gd")

signal fired(origin: Vector3, direction: Vector3)

const FORWARD_ACCEL: float = 70.0
const REVERSE_ACCEL: float = 38.0
const SIDE_THRUST: float = 32.0
const LINEAR_DAMP: float = 0.43
const NORMAL_SPEED: float = 96.0
const AFTERBURNER_SPEED: float = 152.0
const TURN_RESPONSE: float = 6.5
const FLIGHT_MIN_HEIGHT: float = 4.5
const FLIGHT_MAX_HEIGHT: float = 280.0

var shield: float = 100.0
var hull: float = 100.0
var boost: float = 100.0
var engine_rank: int = 0
var weapon_rank: int = 0
var turn_speed: float = 1.9
var cooldown: float = 0.0
var visual: Node3D
var engine_flames: Array[MeshInstance3D] = []
var glow_time: float = 0.0
var controls_locked: bool = false
var touch_enabled: bool = false
var touch_steering: Vector2 = Vector2.ZERO
var touch_throttle: float = 0.0
var touch_vertical: float = 0.0
var touch_boost: bool = false
var touch_fire: bool = false
var yaw_rate: float = 0.0
var pitch_rate: float = 0.0
var roll_angle: float = 0.0
var collision_impacts: int = 0
var last_impact_speed: float = 0.0
var flight_distance: float = 0.0
var was_flying: bool = false
var thruster_power: float = 0.0
## R23: physical keyboard layouts, browser-native scancodes and an explicit
## mouse-click launch fallback all feed the SAME genuine inertial physics.
const KEY_THRUST = 1
const KEY_REVERSE = 2
const KEY_LEFT = 4
const KEY_RIGHT = 8
const KEY_ASCEND = 16
const KEY_DESCEND = 32
const KEY_NOSE_UP = 64
const KEY_NOSE_DOWN = 128
const KEY_BOOST = 256
const KEY_FIRE = 512
var browser_input_mask: int = 0
var cruise_assist: bool = false
var last_pilot_throttle: float = 0.0
var last_pilot_yaw: float = 0.0
var keyboard_samples: int = 0
var browser_input_samples: int = 0
var cruise_distance: float = 0.0

func _ready() -> void:
    motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
    max_slides = 8
    safe_margin = 0.05
    visual = Node3D.new()
    visual.name = "AnimatedShip"
    add_child(visual)
    visual.scale = Vector3.ONE * 1.25
    var model := ShipVisualR5Script.new()
    model.name = "HighDetailInterceptorR5"
    visual.add_child(model)
    engine_flames = model.engine_flames
    # The R8 wing span is large, but collision uses a conservative swept
    # body to preserve flight corridors without an overly sticky hull.
    var shape := SphereShape3D.new()
    shape.radius = 1.75
    var collider := CollisionShape3D.new()
    collider.name = "ShipCollision"
    collider.shape = shape
    add_child(collider)

func set_touch_controls(steering: Vector2, throttle: float, vertical: float,
        boosting: bool, firing: bool) -> void:
    touch_enabled = true
    touch_steering = steering.limit_length(1.0)
    touch_throttle = clampf(throttle, -1.0, 1.0)
    touch_vertical = clampf(vertical, -1.0, 1.0)
    touch_boost = boosting
    touch_fire = firing

func clear_touch_controls() -> void:
    touch_steering = Vector2.ZERO
    touch_throttle = 0.0
    touch_vertical = 0.0
    touch_boost = false
    touch_fire = false

func set_cruise_assist(active: bool) -> void:
    cruise_assist = active and not controls_locked

func _browser_mask() -> int:
    if not OS.has_feature("web"):
        return 0
    # One read per physical tick, not a costly JS bridge call per key.
    # window key listeners use KeyboardEvent.code, unaffected by RU/EN layout.
    browser_input_samples += 1
    var result: Variant = JavaScriptBridge.eval("Number(window.__nebulaPilotMask || 0)")
    return int(result) if result != null else 0

func _physical_key(code: Key) -> bool:
    # KEY_W is a *logical character* and maps to Cyrillic Ц on a Russian
    # keyboard. Physical scan codes preserve movement on all keyboard layouts.
    return Input.is_physical_key_pressed(code) or Input.is_key_pressed(code)

func _pilot_axes() -> Vector4:
    browser_input_mask = _browser_mask()
    keyboard_samples += 1
    var b: int = browser_input_mask
    var yaw: float = float(_physical_key(KEY_D) or (b & KEY_RIGHT) != 0) - float(
        _physical_key(KEY_A) or (b & KEY_LEFT) != 0)
    var pitch: float = float(_physical_key(KEY_DOWN) or (b & KEY_NOSE_DOWN) != 0) - float(
        _physical_key(KEY_UP) or (b & KEY_NOSE_UP) != 0)
    var throttle: float = float(_physical_key(KEY_W) or (b & KEY_THRUST) != 0) - float(
        _physical_key(KEY_S) or (b & KEY_REVERSE) != 0)
    var altitude: float = float(_physical_key(KEY_E) or (b & KEY_ASCEND) != 0) - float(
        _physical_key(KEY_Q) or (b & KEY_DESCEND) != 0)
    if touch_enabled:
        if absf(touch_steering.x) > absf(yaw):
            yaw = touch_steering.x
        if absf(touch_steering.y) > absf(pitch):
            pitch = touch_steering.y
        if absf(touch_throttle) > absf(throttle):
            throttle = touch_throttle
        if absf(touch_vertical) > absf(altitude):
            altitude = touch_vertical
    # An actual pilot-controlled cruise assist button ensures the player can
    # move with a mouse even if browser focus/keyboard capture is unavailable.
    if throttle < -0.05:
        cruise_assist = false
    elif cruise_assist and throttle < 0.05:
        throttle = 1.0
    last_pilot_throttle = throttle
    last_pilot_yaw = yaw
    return Vector4(yaw, pitch, throttle, altitude)

func _physics_process(delta: float) -> void:
    if controls_locked:
        velocity = Vector3.ZERO
        yaw_rate = move_toward(yaw_rate, 0.0, delta * TURN_RESPONSE)
        pitch_rate = move_toward(pitch_rate, 0.0, delta * TURN_RESPONSE)
        boost = minf(100.0, boost + 15.0 * delta)
        cooldown = maxf(0.0, cooldown - delta)
        return
    var axes: Vector4 = _pilot_axes()
    var yaw: float = axes.x
    var pitch: float = axes.y
    var throttle: float = axes.z
    var climb: float = axes.w
    var afterburner: bool = (
        (_physical_key(KEY_SHIFT) or (browser_input_mask & KEY_BOOST) != 0 or touch_boost)
        and throttle > 0.05 and boost > 1.0
    )
    # Angular acceleration and damping make heavy craft bank and settle.
    var angular_alpha: float = 1.0 - exp(-TURN_RESPONSE * delta)
    yaw_rate = lerpf(yaw_rate, -yaw * turn_speed, angular_alpha)
    pitch_rate = lerpf(pitch_rate, pitch * turn_speed * 0.40, angular_alpha)
    rotate_y(yaw_rate * delta)
    rotate_object_local(Vector3.RIGHT, pitch_rate * delta)
    if absf(pitch) < 0.08:
        rotation.x = lerp_angle(rotation.x, 0.0, 1.0 - exp(-1.0 * delta))
    # Prevent inversion and loss of spatial orientation in tight city flight.
    rotation.x = clampf(rotation.x, -0.56, 0.56)
    rotation.z = 0.0
    var forward: Vector3 = -global_transform.basis.z
    var strength: float = (FORWARD_ACCEL + float(engine_rank) * 8.0)
    var acceleration: float = strength * (1.8 if afterburner else 1.0)
    var forward_acceleration: float = acceleration if throttle >= 0.0 else REVERSE_ACCEL
    velocity += forward * throttle * forward_acceleration * delta
    velocity += Vector3.UP * climb * SIDE_THRUST * delta
    velocity *= exp(-LINEAR_DAMP * delta)
    velocity = velocity.limit_length(AFTERBURNER_SPEED if afterburner else NORMAL_SPEED)
    thruster_power = absf(throttle) * (1.0 if afterburner else 0.55)
    boost = clampf(boost + (-23.0 if afterburner else 16.0) * delta, 0.0, 100.0)
    cooldown = maxf(0.0, cooldown - delta)
    if (
        (_physical_key(KEY_SPACE) or (browser_input_mask & KEY_FIRE) != 0 or touch_fire)
        and cooldown <= 0.0
    ):
        cooldown = maxf(0.10, 0.30 - float(weapon_rank) * 0.05)
        fired.emit(global_position + forward * 2.2, forward)
    var pre_collision_velocity: Vector3 = velocity
    var previous_position: Vector3 = global_position
    move_and_slide()
    var frame_distance: float = global_position.distance_to(previous_position)
    flight_distance += frame_distance
    if cruise_assist:
        cruise_distance += frame_distance
    was_flying = throttle > 0.05 or velocity.length_squared() > 20.0
    # Damage scales with the closing component of the impact, rather than
    # arbitrary frame count; a scrape is gentler than a head-on collision.
    var largest_impact: float = 0.0
    for i in get_slide_collision_count():
        var impact: KinematicCollision3D = get_slide_collision(i)
        var closing_speed: float = maxf(0.0,
            -pre_collision_velocity.dot(impact.get_normal()))
        largest_impact = maxf(largest_impact, closing_speed)
    if largest_impact > 14.0:
        collision_impacts += 1
        last_impact_speed = largest_impact
        take_damage(clampf((largest_impact - 14.0) * 0.11, 0.0, 14.0))
    # A bounded playable aerospace region without teleporting through walls.
    var bounded: Vector3 = global_position
    bounded.y = clampf(bounded.y, FLIGHT_MIN_HEIGHT, FLIGHT_MAX_HEIGHT)
    bounded.x = clampf(bounded.x, -1800.0, 1800.0)
    bounded.z = clampf(bounded.z, -1800.0, 1800.0)
    if bounded.y != global_position.y:
        velocity.y = 0.0
    global_position = bounded
    roll_angle = lerpf(roll_angle, -yaw * 0.24,
        1.0 - exp(-5.5 * delta))
    visual.rotation.z = roll_angle
    visual.rotation.x = lerp_angle(visual.rotation.x, -pitch * 0.07,
        1.0 - exp(-4.5 * delta))
    glow_time += delta
    for jet in engine_flames:
        if is_instance_valid(jet):
            jet.scale.y = 0.75 + thruster_power * 0.70                 + 0.10 * sin(glow_time * 16.0) + (0.7 if afterburner else 0.0)

func take_damage(amount: float) -> void:
    var remaining: float = maxf(0.0, amount)
    if shield > 0.0:
        var absorbed: float = minf(shield, remaining)
        shield -= absorbed
        remaining -= absorbed
    hull = maxf(0.0, hull - remaining)
