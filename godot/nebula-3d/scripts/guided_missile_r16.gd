extends Node3D
## R16: pooled, visible guided missile. No instant-hit or per-shot allocations.
## All targets are gameplay drones; this is a self-contained visual/gameplay object.
signal impacted(victim: Node3D)

const MAX_LIFETIME: float = 5.5
var armed: bool = false
var target: Node3D
var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 0.0
var impact_damage: float = 14.0
var exhaust: MeshInstance3D

func _ready() -> void:
    visible = false
    set_process(false)
    _build_model()

func _metal(color: Color, emissive: bool = false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = 0.78
    m.roughness = 0.30
    if emissive:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = 3.5
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m

func _part(mesh: Mesh, material: Material, offset: Vector3, tilt: float = 0.0) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.mesh = mesh
    part.material_override = material
    part.position = offset
    part.rotation.x = tilt
    add_child(part)
    return part

func _build_model() -> void:
    var titanium := _metal(Color(0.46, 0.59, 0.66))
    var dark := _metal(Color(0.08, 0.15, 0.23))
    var heat := _metal(Color(0.25, 0.78, 1.0), true)
    var fuselage := CylinderMesh.new()
    fuselage.top_radius = 0.30
    fuselage.bottom_radius = 0.40
    fuselage.height = 2.4
    fuselage.radial_segments = 12
    _part(fuselage, titanium, Vector3.ZERO, -PI * 0.5)
    var nose := CylinderMesh.new()
    nose.top_radius = 0.0
    nose.bottom_radius = 0.30
    nose.height = 0.8
    nose.radial_segments = 12
    _part(nose, dark, Vector3(0.0, 0.0, -1.58), -PI * 0.5)
    var tail := CylinderMesh.new()
    tail.top_radius = 0.36
    tail.bottom_radius = 0.44
    tail.height = 0.32
    tail.radial_segments = 12
    _part(tail, dark, Vector3(0.0, 0.0, 1.15), -PI * 0.5)
    var horizontal := BoxMesh.new()
    horizontal.size = Vector3(1.95, 0.10, 0.70)
    _part(horizontal, titanium, Vector3(0.0, 0.0, 0.80))
    var vertical := BoxMesh.new()
    vertical.size = Vector3(0.10, 1.75, 0.70)
    _part(vertical, titanium, Vector3(0.0, 0.0, 0.80))
    var flame := CylinderMesh.new()
    flame.top_radius = 0.16
    flame.bottom_radius = 0.02
    flame.height = 1.55
    flame.radial_segments = 10
    exhaust = _part(flame, heat, Vector3(0.0, 0.0, 1.90), -PI * 0.5)

func activate(origin: Vector3, direction: Vector3, enemy: Node3D, damage: float) -> bool:
    if not is_instance_valid(enemy):
        return false
    target = enemy
    impact_damage = damage
    lifetime = 0.0
    velocity = direction.normalized() * 78.0
    global_position = origin
    armed = true
    visible = true
    set_process(true)
    return true

func deactivate() -> void:
    armed = false
    target = null
    visible = false
    set_process(false)

func _impact() -> void:
    var victim: Node3D = target
    if is_instance_valid(victim) and victim.has_method("hit"):
        victim.call("hit", impact_damage)
        impacted.emit(victim)
    deactivate()

func _process(delta: float) -> void:
    if not armed:
        return
    lifetime += delta
    if lifetime >= MAX_LIFETIME or not is_instance_valid(target):
        deactivate()
        return
    var displacement: Vector3 = target.global_position - global_position
    if displacement.length_squared() <= 12.25:
        _impact()
        return
    var desired_velocity: Vector3 = displacement.normalized() * minf(185.0, 78.0 + lifetime * 55.0)
    velocity = velocity.lerp(desired_velocity, 1.0 - exp(-6.0 * delta))
    var movement: Vector3 = velocity * delta
    if movement.length_squared() >= displacement.length_squared():
        global_position = target.global_position
        _impact()
        return
    global_position += movement
    if velocity.length_squared() > 0.001:
        look_at(global_position + velocity, Vector3.UP)
    if is_instance_valid(exhaust):
        exhaust.scale.z = 1.0 + 0.22 * sin(lifetime * 34.0)
