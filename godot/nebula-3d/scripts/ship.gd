extends CharacterBody3D
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

func _ready() -> void:
    visual = Node3D.new()
    visual.name = "AnimatedShip"
    add_child(visual)
    _make_ship()
    var shape := SphereShape3D.new()
    shape.radius = 1.9
    var collision := CollisionShape3D.new()
    collision.name = "ShipCollision"
    collision.shape = shape
    add_child(collision)

func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.72
    mat.roughness = 0.27
    if emissive:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 3.0
    return mat

func _box(size: Vector3, offset: Vector3, color: Color, light: bool = false) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = _material(color, light)
    instance.position = offset
    visual.add_child(instance)

func _make_ship() -> void:
    _box(Vector3(1.65, 0.65, 5.0), Vector3.ZERO, Color(0.13,0.25,0.40))
    _box(Vector3(7.4, 0.20, 1.50), Vector3(0, -0.02, 0.5), Color(0.16,0.36,0.58))
    _box(Vector3(1.15, 0.52, 2.05), Vector3(0,0.48,-0.75), Color(0.23,0.69,0.92))
    _box(Vector3(0.70, 0.22, 2.55), Vector3(-2.55,-0.02,0.4), Color(0.08,0.20,0.32))
    _box(Vector3(0.70, 0.22, 2.55), Vector3(2.55,-0.02,0.4), Color(0.08,0.20,0.32))
    for x in [-1.1, 1.1]:
        _box(Vector3(0.48, 0.42, 0.65), Vector3(x,-0.05,2.48), Color(0.12,0.85,1.0), true)
    var light := OmniLight3D.new()
    light.light_color = Color(0.1,0.8,1.0)
    light.light_energy = 1.2
    light.omni_range = 9.0
    light.position = Vector3(0,0,2.5)
    visual.add_child(light)

func _physics_process(delta: float) -> void:
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
    visual.rotation.z = lerp_angle(visual.rotation.z, -steer * 0.16, minf(1.0, delta * 5.0))

func take_damage(amount: float) -> void:
    var remaining: float = maxf(0.0, amount)
    if shield > 0.0:
        var absorbed: float = minf(shield,remaining)
        shield -= absorbed
        remaining -= absorbed
    hull = maxf(0.0,hull-remaining)
