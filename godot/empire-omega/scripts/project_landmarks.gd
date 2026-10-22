extends Node3D
## Procedural visible landmarks: every completed city initiative gains a 3D structure.
## Designed as non-colliding proxies until handcrafted GLB/PBR assets replace them.

const INITIATIVES = preload("res://scripts/civic_initiatives.gd")
const POSITIONS = {
	"open_records":Vector3(-164.0,0.0,-85.0),
	"civic_hospital":Vector3(-87.0,0.0,-164.0),
	"safe_crossings":Vector3(91.0,0.0,-85.0),
	"community_park":Vector3(164.0,0.0,-91.0),
	"factory_safety":Vector3(-166.0,0.0,89.0),
	"freight_terminal":Vector3(-88.0,0.0,166.0),
	"clean_network":Vector3(88.0,0.0,167.0),
	"smart_substation":Vector3(162.0,0.0,88.0)
}
var created := {}

func sync_projects(finished: Array) -> void:
	# Reset/loading a save must remove landmarks no longer constructed.
	for previous in created.keys():
		if not finished.has(previous):
			var obsolete: Node3D = created[previous]
			created.erase(previous)
			obsolete.queue_free()
	for project_id in finished:
		if not INITIATIVES.PROJECTS.has(project_id) or created.has(project_id):
			continue
		var node := Node3D.new()
		node.name = "Landmark_" + str(project_id)
		add_child(node)
		node.position = POSITIONS[project_id]
		var base := MeshInstance3D.new()
		var base_shape := CylinderMesh.new()
		base_shape.top_radius = 5.5
		base_shape.bottom_radius = 5.5
		base_shape.height = 0.5
		base.mesh = base_shape
		base.position.y = 0.3
		base.material_override = _material(Color("244052"),0.55,false)
		node.add_child(base)
		var central := MeshInstance3D.new()
		var tower := CylinderMesh.new()
		tower.top_radius = 1.1
		tower.bottom_radius = 2.6
		tower.height = 7.0
		central.mesh = tower
		central.position.y = 4.0
		central.material_override = _material(Color("bf9b58"),0.15,false)
		node.add_child(central)
		var crystal := MeshInstance3D.new()
		var crown := SphereMesh.new()
		crown.radius = 1.6
		crown.height = 3.2
		crystal.mesh = crown
		crystal.position.y = 8.5
		crystal.material_override = _material(Color("63d5d2"),0.05,true)
		node.add_child(crystal)
		var sign := Label3D.new()
		sign.text = str(INITIATIVES.PROJECTS[project_id]["ru"])
		sign.position = Vector3(0,11.4,0)
		sign.font_size = 44
		sign.pixel_size = 0.008
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.modulate = Color("f2d5a1")
		node.add_child(sign)
		created[project_id] = node

func update_language(lang: String) -> void:
	for project_id in created:
		var node: Node3D = created[project_id]
		var sign: Label3D = node.get_node_or_null("Label3D") as Label3D
		if sign != null:
			sign.text = str(INITIATIVES.PROJECTS[project_id].get(lang,INITIATIVES.PROJECTS[project_id]["ru"]))

func _material(color: Color, roughness: float, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.55
	material.roughness = roughness
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.4
	return material
