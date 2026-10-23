extends CharacterBody3D
const ShipVisualR5Script = preload("res://scripts/ship_visual_r5.gd")
## Physics-driven spacecraft used by the optional native 3D prototype.

signal fired(origin: Vector3, direction: Vector3)

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

func _ready() -> void:
    visual = Node3D.new()
    visual.name = "AnimatedShip"
    add_child(visual)
    visual.scale=Vector3.ONE*1.25
    var model := ShipVisualR5Script.new()
    model.name = "HighDetailInterceptorR5"
    visual.add_child(model)
    engine_flames = model.engine_flames
    var shape := SphereShape3D.new()
    shape.radius = 1.9
    var collision := CollisionShape3D.new()
    collision.name = "ShipCollision"
    collision.shape = shape
    add_child(collision)

# Detailed R5 model geometry is authored in ship_visual_r5.gd.
# Ship input, combat, inertia, and persistence remain here.

func _physics_process(delta: float) -> void:
    if controls_locked:
        # A docked hangar is a real modal: keyboard input cannot fire weapons
        # or accelerate while the player is buying and selecting equipment.
        velocity = Vector3.ZERO
        boost = minf(100.0, boost + 14.0 * delta)
        cooldown = maxf(0.0, cooldown - delta)
        return
    var steer: float = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    var pitch: float = float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP))
    var thrust: float = float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
    var ascend: float = float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
    var afterburner: bool = Input.is_key_pressed(KEY_SHIFT) and thrust > 0.0 and boost > 1.0
    var acceleration: float = (40.0 + engine_rank * 6.0) * (2.15 if afterburner else 1.0)
    rotate_y(-steer * turn_speed * delta)
    rotate_object_local(Vector3.RIGHT, pitch * turn_speed * 0.44 * delta)
    var forward: Vector3 = -global_transform.basis.z
    velocity += forward * thrust * acceleration * delta
    velocity += Vector3.UP * ascend * acceleration * 0.6 * delta
    velocity *= exp(-1.65 * delta)
    velocity = velocity.limit_length(70.0 if afterburner else 43.0)
    boost = clampf(boost + (-27.0 if afterburner else 14.0) * delta, 0.0, 100.0)
    cooldown = maxf(0.0, cooldown - delta)
    if Input.is_key_pressed(KEY_SPACE) and cooldown <= 0.0:
        cooldown = maxf(0.1, 0.30 - weapon_rank * 0.05)
        fired.emit(global_position + forward * 2.2, forward)
    move_and_slide()
    global_position.y = clampf(global_position.y, 4.0, 160.0)
    global_position.x = clampf(global_position.x, -1800.0, 1800.0)
    global_position.z = clampf(global_position.z, -1800.0, 1800.0)
    visual.rotation.z = lerp_angle(visual.rotation.z, -steer * 0.19, minf(1.0, delta * 5.0))
    visual.rotation.x = lerp_angle(visual.rotation.x, -pitch * 0.08, minf(1.0,delta*4.0))
    glow_time += delta
    for jet in engine_flames:
        jet.scale.y = 1.0 + 0.3*sin(glow_time*19.0) + (0.95 if afterburner else 0.0)

func take_damage(amount: float) -> void:
    var remaining: float = maxf(0.0, amount)
    if shield > 0.0:
        var absorbed: float = minf(shield,remaining)
        shield -= absorbed
        remaining -= absorbed
    hull = maxf(0.0,hull-remaining)
