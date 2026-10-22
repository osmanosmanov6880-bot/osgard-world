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
var engine_flames: Array[MeshInstance3D] = []
var glow_time: float = 0.0

func _ready() -> void:
    visual = Node3D.new()
    visual.name = "AnimatedShip"
    add_child(visual)
    visual.scale=Vector3.ONE*1.35
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

func _wedge(coords: Array[Vector3], faces: Array, color: Color) -> void:
    var tool := SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for face in faces:
        for index in face:
            tool.add_vertex(coords[int(index)])
    tool.generate_normals()
    var mesh := tool.commit()
    var instance := MeshInstance3D.new()
    instance.mesh=mesh
    instance.material_override=_material(color)
    visual.add_child(instance)

func _canopy(offset: Vector3, size: Vector3, color: Color) -> void:
    var mesh := SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    var instance := MeshInstance3D.new()
    instance.mesh=mesh
    instance.position=offset
    instance.scale=size
    instance.material_override=_material(color)
    visual.add_child(instance)

func _make_ship() -> void:
    var graphite := Color(0.085,0.12,0.18)
    var titanium := Color(0.32,0.41,0.51)
    var blue_steel := Color(0.13,0.25,0.42)
    var accent := Color(0.91,0.65,0.31)
    # Deliberately asymmetric in Z: a long aerodynamic nose, not box bars.
    var hull_vertices: Array[Vector3]=[
        Vector3(0,0.0,-5.9),Vector3(-1.10,-0.17,-2.05),Vector3(1.10,-0.17,-2.05),
        Vector3(-1.35,0.04,2.8),Vector3(1.35,0.04,2.8),Vector3(0,0.72,-2.45),
        Vector3(0,0.52,2.4),Vector3(0,-0.42,-2.5),Vector3(0,-0.43,2.8)]
    _wedge(hull_vertices,[[0,1,5],[0,5,2],[0,7,1],[0,2,7],[1,3,6],[1,6,5],[5,6,4],[5,4,2],[2,4,8],[2,8,7],[7,8,3],[7,3,1],[3,8,6],[6,8,4]],titanium)
    # Eight swept surfaces form thick left and right wing airfoils.
    for side in [-1.0,1.0]:
        var wing: Array[Vector3]=[
            Vector3(side*0.92,0.06,-1.2),
            Vector3(side*5.15,-0.05,0.50),
            Vector3(side*4.86,-0.08,2.17),
            Vector3(side*1.02,0.02,1.92),
            Vector3(side*0.93,-0.31,-1.2),
            Vector3(side*5.15,-0.28,0.50),
            Vector3(side*4.86,-0.29,2.17),
            Vector3(side*1.02,-0.29,1.92)]
        _wedge(wing,[[0,1,2],[0,2,3],[4,7,6],[4,6,5],[0,4,5],[0,5,1],[1,5,6],[1,6,2],[2,6,7],[2,7,3],[3,7,4],[3,4,0]],blue_steel)
        _box(Vector3(3.5,0.075,0.20),Vector3(side*2.90,0.095,0.78),accent)
        _box(Vector3(0.30,0.40,1.94),Vector3(side*3.73,0.02,1.45),graphite)
        _box(Vector3(0.30,0.36,1.1),Vector3(side*4.35,0.15,1.67),titanium)
        _box(Vector3(0.34,0.25,0.36),Vector3(side*4.35,0.15,2.2),Color(0.21,0.80,0.98),true)
        _box(Vector3(0.24,0.22,1.4),Vector3(side*1.1,0.28,-1.60),accent)
    _canopy(Vector3(0,0.66,-1.65),Vector3(0.72,0.43,1.32),Color(0.17,0.48,0.74))
    _box(Vector3(1.65,0.12,0.15),Vector3(0,1.08,-1.26),accent)
    for x in [-1.03,1.03]:
        _box(Vector3(0.75,0.84,2.14),Vector3(x,-0.26,2.64),graphite)
        var jet := MeshInstance3D.new()
        var flame := CylinderMesh.new()
        flame.top_radius = 0.16
        flame.bottom_radius = 0.50
        flame.height = 1.78
        flame.radial_segments=12
        jet.mesh=flame
        jet.material_override=_material(Color(0.15,0.82,1.0),true)
        jet.rotation.x=PI*0.5
        jet.position=Vector3(x,-0.20,4.01)
        visual.add_child(jet)
        engine_flames.append(jet)
    var engine_light := OmniLight3D.new()
    engine_light.name="IonThrusters"
    engine_light.light_color=Color(0.22,0.73,1.0)
    engine_light.light_energy=1.6
    engine_light.omni_range=13.0
    engine_light.position=Vector3(0,0,3.1)
    visual.add_child(engine_light)

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
