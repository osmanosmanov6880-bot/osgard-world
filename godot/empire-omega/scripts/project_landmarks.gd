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
		# Eight distinct ORIGINAL structures signal which real service was built.
		# The old universal obelisk/crystal incorrectly made all projects equal.
		_add_signature(node,project_id)
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

func _add_tank(parent: Node3D, part_name: String, radius: float,
		height: float, place: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	part.mesh = mesh
	part.position = place
	part.material_override = _material(color,0.38,false)
	parent.add_child(part)

func _add_canopy(parent: Node3D, part_name: String,
		radius: float, place: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	part.mesh = mesh
	part.position = place
	part.material_override = _material(color,0.78,false)
	parent.add_child(part)

func _add_signature(holder: Node3D, project_id: String) -> void:
	# Real saved projects already drive creation/removal. All extra mesh pieces
	# are collision-free, deterministic and never modify money, travel or AI.
	var node := Node3D.new()
	node.name = "Signature_" + project_id
	holder.add_child(node)
	var midnight := Color("233842")
	var stone := Color("a6b3b1")
	var gold := Color("c5a068")
	var cyan := Color("60b9bc")
	var leaf := Color("487a65")
	match project_id:
		"open_records":
			# Public budget archive: four columns, transparent data panels,
			# a wide civic canopy that replaces the obsolete glowing trophy.
			for x in [-3.2,3.2]:
				for z in [-2.2,2.2]:
					_worksite_box(node,"ArchiveColumn",Vector3(0.55,5.6,0.55),
						Vector3(x,3.2,z),stone)
			_worksite_box(node,"ArchiveRoof",Vector3(8.5,0.5,6.0),Vector3(0,6.25,0),gold)
			for x in [-1.9,1.9]:
				_worksite_box(node,"BudgetScreen",Vector3(2.8,3.1,0.13),
					Vector3(x,3.4,-2.32),cyan)
		"civic_hospital":
			_worksite_box(node,"HospitalWard",Vector3(8.4,5.0,6.3),Vector3(0,3.1,0),stone)
			_worksite_box(node,"HospitalEntry",Vector3(3.6,2.5,1.3),Vector3(0,1.8,-3.6),midnight)
			_worksite_box(node,"HospitalCrossVertical",Vector3(0.65,2.8,0.15),Vector3(0,5.3,-3.25),cyan)
			_worksite_box(node,"HospitalCrossHorizontal",Vector3(2.5,0.7,0.15),Vector3(0,5.3,-3.35),cyan)
			for x in [-2.8,2.8]:
				_worksite_box(node,"ClinicWindow",Vector3(1.6,1.1,0.15),Vector3(x,3.1,-3.25),midnight)
		"safe_crossings":
			_worksite_box(node,"CrossingRoad",Vector3(10.0,0.18,6.5),Vector3(0,0.52,0),midnight)
			for i in range(6):
				_worksite_box(node,"CrosswalkStripe",Vector3(0.9,0.08,5.0),
					Vector3(-3.8+float(i)*1.5,0.65,0),stone)
			for x in [-4.5,4.5]:
				_worksite_box(node,"CrossingSignalPole",Vector3(0.22,5.0,0.22),
					Vector3(x,3.0,-2.8),gold)
				_worksite_box(node,"CrossingSignalHead",Vector3(0.72,0.9,0.5),
					Vector3(x,5.0,-2.8),cyan)
		"community_park":
			_add_tank(node,"ParkGreen",5.1,0.2,Vector3(0,0.6,0),leaf)
			for x in [-3.1,3.1]:
				for z in [-3.1,3.1]:
					_add_tank(node,"ParkTreeTrunk",0.3,2.6,Vector3(x,1.9,z),gold)
					_add_canopy(node,"ParkTreeCanopy",1.35,Vector3(x,4.0,z),leaf)
			_add_tank(node,"ParkFountainBasin",1.7,0.45,Vector3(0,0.86,0),stone)
			_add_tank(node,"ParkFountainWater",1.0,0.18,Vector3(0,1.18,0),cyan)
		"factory_safety":
			_worksite_box(node,"SafeFactoryHall",Vector3(8.5,3.4,7.0),Vector3(0,2.3,0),midnight)
			for x in [-3.0,0.0,3.0]:
				_add_tank(node,"SafetyFilter",0.75,3.6,Vector3(x,5.6,1.3),stone)
			_worksite_box(node,"SafetyVentilation",Vector3(8.3,0.5,1.3),Vector3(0,4.25,-2.7),cyan)
			_worksite_box(node,"FactoryWarningBand",Vector3(8.6,0.3,0.2),Vector3(0,1.1,-3.6),gold)
		"freight_terminal":
			_worksite_box(node,"FreightWarehouse",Vector3(7.0,3.4,7.0),Vector3(0,2.3,1.2),midnight)
			_worksite_box(node,"FreightDock",Vector3(8.5,0.6,3.0),Vector3(0,0.75,-3.2),stone)
			for x in [-3.8,3.8]:
				_worksite_box(node,"CraneSupport",Vector3(0.35,6.8,0.35),
					Vector3(x,3.9,-3.5),gold)
			_worksite_box(node,"CraneBeam",Vector3(8.1,0.4,0.6),Vector3(0,7.2,-3.5),gold)
			_worksite_box(node,"FreightPallet",Vector3(2.2,1.4,2.0),Vector3(0,1.6,-3.1),stone)
		"clean_network":
			for x in [-2.8,0.0,2.8]:
				_add_tank(node,"CleanWaterTank",1.2,4.0,Vector3(x,2.7,0.3),stone)
				_add_tank(node,"CleanTankCap",1.3,0.25,Vector3(x,4.8,0.3),cyan)
			_worksite_box(node,"WaterSupplyPipe",Vector3(8.0,0.65,0.65),Vector3(0,1.1,-2.4),cyan)
			_worksite_box(node,"WaterControlRoom",Vector3(2.8,2.4,2.0),Vector3(0,1.6,3.1),midnight)
		"smart_substation":
			for x in [-2.7,2.7]:
				_worksite_box(node,"TransformerTower",Vector3(1.7,4.2,2.2),
					Vector3(x,2.7,0),midnight)
				for y in [2.0,3.2,4.4]:
					_worksite_box(node,"TransformerCopper",Vector3(2.0,0.2,2.4),
						Vector3(x,y,0),gold)
				_add_tank(node,"HighVoltageInsulator",0.45,1.5,Vector3(x,5.5,0),cyan)
			_worksite_box(node,"PowerBus",Vector3(7.5,0.2,0.35),Vector3(0,6.35,0),gold)

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
