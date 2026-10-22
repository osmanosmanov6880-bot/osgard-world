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

func _ready() -> void:
    var mesh := SphereMesh.new()
    mesh.radius = 1.25
    mesh.height = 2.5
    body = MeshInstance3D.new()
    body.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.82,0.18,0.34) if hostile else Color(0.15,0.74,0.88)
    mat.metallic = 0.50
    mat.roughness = 0.3
    mat.emission_enabled = true
    mat.emission = mat.albedo_color
    mat.emission_energy_multiplier = 1.4
    body.material_override = mat
    add_child(body)
    var wing := BoxMesh.new()
    wing.size = Vector3(4.6,0.18,0.68)
    var part := MeshInstance3D.new()
    part.mesh = wing
    part.material_override = mat
    add_child(part)

func _process(delta: float) -> void:
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

func hit(damage: float) -> void:
    health -= damage
    if health <= 0.0:
        destroyed.emit(self)
        queue_free()
