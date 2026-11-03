extends Node3D
## Native enemy drone with a world-space chase and simple shield/hull interaction.
signal destroyed(drone: Node3D)
signal fired(origin: Vector3, target_position: Vector3)

var target: Node3D
var health: float = 9.0
var speed: float = 19.0
var hostile: bool = true
var activation_distance: float = 340.0
var elapsed: float = 0.0
var body: MeshInstance3D
var laser_cooldown: float = 0.6
var crashing: bool = false
var crash_velocity: Vector3 = Vector3.ZERO
var crash_time: float = 0.0
var crash_impacted: bool = false

func _metal(tint: Color, energy: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tint
    m.metallic = 0.72
    m.roughness = 0.27
    if energy > 0.0:
        m.emission_enabled = true
        m.emission = tint
        m.emission_energy_multiplier = energy
    return m

func _part(size: Vector3, offset: Vector3, material: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size=size
    part.mesh=mesh
    part.material_override=material
    part.position=offset
    add_child(part)
    return part

func _ready() -> void:
    var primary: Color = Color(0.82,0.28,0.31) if hostile else Color(0.18,0.64,0.86)
    var hull_mat := _metal(Color(0.12,0.20,0.30))
    var neon := _metal(primary,2.0)
    var sphere := SphereMesh.new()
    sphere.radius=1.12
    sphere.height=2.24
    body=MeshInstance3D.new()
    body.mesh=sphere
    body.scale=Vector3(1.0,0.48,1.6)
    body.material_override=hull_mat
    add_child(body)
    _part(Vector3(4.8,0.16,0.74),Vector3(0,0,0.42),hull_mat)
    _part(Vector3(3.1,0.12,0.12),Vector3(0,0.14,0.46),neon)
    for x in [-2.24,2.24]:
        _part(Vector3(0.54,0.44,0.98),Vector3(x,-0.11,0.55),hull_mat)
        _part(Vector3(0.34,0.30,0.24),Vector3(x,0.0,1.14),neon)
    _part(Vector3(0.25,0.22,0.88),Vector3(0,0.32,-0.62),neon)

func _process(delta: float) -> void:
    if crash_impacted:
        return
    if crashing:
        crash_time += delta
        crash_velocity += Vector3.DOWN * 18.0 * delta
        var previous: Vector3 = global_position
        var next_position: Vector3 = previous + crash_velocity * delta
        # Raycast the actual crash path so wrecks strike city structures and
        # flightways instead of vanishing at an arbitrary screen-space height.
        var query := PhysicsRayQueryParameters3D.create(previous, next_position, 1)
        var impact: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
        if not impact.is_empty():
            global_position = impact["position"]
            _crash_flash()
            return
        global_position = next_position
        rotate_object_local(Vector3.FORWARD, 2.4 * delta)
        rotate_object_local(Vector3.RIGHT, 1.1 * delta)
        if global_position.y <= 2.0:
            _crash_flash()
        elif crash_time >= 8.0:
            queue_free()
        return
    elapsed += delta
    laser_cooldown = maxf(0.0,laser_cooldown-delta)
    if not is_instance_valid(target):
        return
    var delta_pos: Vector3 = target.global_position - global_position
    if hostile and delta_pos.length() < activation_distance:
        var ideal := target.global_position + Vector3(sin(elapsed * 0.9) * 22.0, 6.0 + sin(elapsed * 1.4) * 3.0, 16.0)
        global_position = global_position.move_toward(ideal, speed * delta)
        if delta_pos.length_squared() > 4.0:
            look_at(target.global_position, Vector3.UP)
        if delta_pos.length() < 195.0 and laser_cooldown <= 0.0:
            laser_cooldown = 2.3 + fmod(elapsed,1.4)
            fired.emit(global_position, target.global_position)
        if delta_pos.length() < 6.0 and target.has_method("take_damage"):
            target.call("take_damage",12.0 * delta)
    else:
        position += Vector3(cos(elapsed * 0.3),sin(elapsed) * 0.22,sin(elapsed * 0.3)) * delta

func _crash_flash() -> void:
    crash_impacted = true
    for child in get_children():
        child.queue_free()
    var flash := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    flash.mesh = sphere
    flash.material_override = _metal(Color(1.0, 0.37, 0.06), 3.0)
    add_child(flash)
    var tween := create_tween()
    tween.tween_property(flash, "scale", Vector3.ONE * 7.0, 0.45)
    tween.tween_callback(queue_free)

func hit(damage: float) -> void:
    if crashing:
        return
    health -= damage
    if health <= 0.0:
        crashing = true
        hostile = false
        crash_velocity = -global_basis.z * speed * 0.7 + Vector3.DOWN * 3.0
        destroyed.emit(self)
