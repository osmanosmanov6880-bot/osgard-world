extends Node3D
## Purely visual non-colliding checkpoint gate: physics alone decides progression.
var animation_time := 0.0
var arch: Node3D

func _ready() -> void:
	arch = Node3D.new()
	add_child(arch)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("4ee4dc")
	material.emission_enabled = true
	material.emission = Color("24b6d0")
	material.emission_energy_multiplier = 2.2
	material.metallic = 0.45
	for placement in [Vector3(-4,2.2,0),Vector3(4,2.2,0),Vector3(0,4.25,0)]:
		var part := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.35,4.2,0.35) if absf(placement.x)>0.1 else Vector3(8.3,0.35,0.35)
		part.mesh = mesh
		part.position = placement
		part.material_override = material
		arch.add_child(part)
	visible = false

func show_at(point: Vector3) -> void:
	global_position = point
	visible = true

func _process(delta: float) -> void:
	if not visible: return
	animation_time += delta
	arch.position.y = sin(animation_time*2.6)*0.12
