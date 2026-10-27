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
## Active worksites are derived from the authoritative save; they never own money,
## turn counters, jobs or completion state. Maximum two by civic_initiatives.valid.
var construction := {}
var current_language := "ru"

func sync_projects(finished: Array, active: Dictionary = {}) -> void:
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

	# The player sees municipal decisions in the actual street BEFORE a
	# project is completed. Loading/resetting never leaves phantom scaffolds.
	for previous in construction.keys():
		if not active.has(previous) or finished.has(previous):
			var obsolete: Node3D = construction[previous]["root"]
			construction.erase(previous)
			obsolete.queue_free()
	for project_id in INITIATIVES.ORDER:
		if finished.has(project_id) or not active.has(project_id):
			continue
		var record: Variant = active[project_id]
		if not (record is Dictionary):
			continue
		if not construction.has(project_id):
			construction[project_id] = _create_construction(project_id)
		var total: int = int(INITIATIVES.PROJECTS[project_id]["turns"])
		var remaining: int = clampi(int(record.get("remaining",total)),1,total)
		var entry: Dictionary = construction[project_id]
		entry["remaining"] = remaining
		var progress: float = 0.20 + 0.80 * float(total - remaining) / float(total)
		var core: MeshInstance3D = entry["core"]
		core.scale.y = progress
		core.position.y = 0.3 + 3.3 * progress
	update_language(current_language)

func _worksite_box(parent: Node3D, part_name: String, size: Vector3,
		place: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var shape := BoxMesh.new()
	shape.size = size
	part.mesh = shape
	part.position = place
	part.material_override = _material(color,0.74,false)
	parent.add_child(part)

func _create_construction(project_id: String) -> Dictionary:
	# Original low-poly site model; no collision shapes, physics, save keys,
	# external assets or unbounded animation costs.
	var node := Node3D.new()
	node.name = "Construction_" + project_id
	node.position = POSITIONS[project_id]
	add_child(node)
	var base := MeshInstance3D.new()
	base.name = "SiteFoundation"
	var slab := CylinderMesh.new()
	slab.top_radius = 6.2
	slab.bottom_radius = 6.2
	slab.height = 0.35
	base.mesh = slab
	base.position.y = 0.23
	base.material_override = _material(Color("334550"),0.86,false)
	node.add_child(base)
	var brass := Color("cba66a")
	var steel := Color("506677")
	for x in [-3.5,3.5]:
		for z in [-3.5,3.5]:
			_worksite_box(node,"ScaffoldPost",Vector3(0.24,7.1,0.24),
				Vector3(x,3.7,z),steel)
	for y in [2.1,5.7]:
		for z in [-3.5,3.5]:
			_worksite_box(node,"ScaffoldRailX",Vector3(7.2,0.22,0.22),
				Vector3(0,y,z),brass)
		for x in [-3.5,3.5]:
			_worksite_box(node,"ScaffoldRailZ",Vector3(0.22,0.22,7.2),
				Vector3(x,y,0),brass)
	var core := MeshInstance3D.new()
	core.name = "WorkInProgress"
	var body := CylinderMesh.new()
	body.top_radius = 1.6
	body.bottom_radius = 2.35
	body.height = 6.6
	core.mesh = body
	core.material_override = _material(Color("688b91"),0.42,false)
	node.add_child(core)
	var sign := Label3D.new()
	sign.name = "ConstructionSign"
	sign.position = Vector3(0,9.1,0)
	sign.font_size = 42
	sign.pixel_size = 0.008
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("f1d9ab")
	node.add_child(sign)
	return {"root":node,"core":core,"sign":sign,"remaining":int(INITIATIVES.PROJECTS[project_id]["turns"])}

func update_language(lang: String) -> void:
	current_language = lang if ["ru","en","zh"].has(lang) else "ru"
	for project_id in created:
		var node: Node3D = created[project_id]
		var sign: Label3D = node.get_node_or_null("Label3D") as Label3D
		if sign != null:
			sign.text = str(INITIATIVES.PROJECTS[project_id].get(current_language,INITIATIVES.PROJECTS[project_id]["ru"]))
	for project_id in construction:
		var entry: Dictionary = construction[project_id]
		var sign: Label3D = entry["sign"]
		if sign == null:
			continue
		var total: int = int(INITIATIVES.PROJECTS[project_id]["turns"])
		var complete: int = total - int(entry["remaining"])
		var phase: String = "СТРОИТЕЛЬСТВО" if current_language == "ru" else ("CONSTRUCTION" if current_language == "en" else "施工中")
		sign.text = str(INITIATIVES.PROJECTS[project_id].get(current_language,INITIATIVES.PROJECTS[project_id]["ru"])) + "\n" + phase + "  %d/%d" % [complete,total]

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
