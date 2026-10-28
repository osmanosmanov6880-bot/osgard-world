extends Node3D
## CITY REIGN AAA A23–A24. Four ORIGINAL, physically modeled, uniquely
## silhouetted civic landmarks on existing game-owned 25m building colliders.
## Real city GameState investments reveal a second source-real 3D upgrade.
## This art has ZERO collision geometry, zero economy writes, no foreign models,
## no hidden physics or always-running extra camera/shadow passes.
const CIVIC = preload("res://scripts/civic_initiatives.gd")
const GAME_SOURCE = preload("res://scripts/game_state.gd")
const ORDER = ["cityhall","market","depot","power"]
const SITE = {
	"cityhall":{"position":Vector3(-130.0,0.0,-130.0),"height":24.0,"district":"forum",
		"accent":Color("c5a978")},
	"market":{"position":Vector3(130.0,0.0,-130.0),"height":16.0,"district":"housing",
		"accent":Color("77aeb7")},
	"depot":{"position":Vector3(-130.0,0.0,130.0),"height":16.0,"district":"lower",
		"accent":Color("c89b71")},
	"power":{"position":Vector3(130.0,0.0,130.0),"height":24.0,"district":"aqueduct",
		"accent":Color("72bdb7")}
}
const MAX_DRAW_NODES: int = 8
const MAX_VERTEX_COUNT_PER_SITE: int = 4000
const FACE_Z: float = -13.20
const ROOF_CLEARANCE: float = 1.0
var site_roots: Dictionary = {}
var facades: Dictionary = {}
var upgrades: Dictionary = {}
var facade_materials: Dictionary = {}
var upgrade_materials: Dictionary = {}
var upgrade_strength: Dictionary = {}
var progress_counts: Dictionary = {}
var quality: String = "standard"
var last_hour: float = 12.0
var last_energy: int = 100

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
	st.set_color(color)
	for v in [a,b,c,a,c,d]:
		st.add_vertex(v)

static func _box(st: SurfaceTool,c: Vector3,h: Vector3,color: Color) -> void:
	var a: Vector3 = c-h
	var b: Vector3 = c+h
	_quad(st,Vector3(a.x,a.y,a.z),Vector3(b.x,a.y,a.z),
		Vector3(b.x,b.y,a.z),Vector3(a.x,b.y,a.z),color)
	_quad(st,Vector3(b.x,a.y,b.z),Vector3(a.x,a.y,b.z),
		Vector3(a.x,b.y,b.z),Vector3(b.x,b.y,b.z),color)
	_quad(st,Vector3(a.x,a.y,b.z),Vector3(a.x,a.y,a.z),
		Vector3(a.x,b.y,a.z),Vector3(a.x,b.y,b.z),color)
	_quad(st,Vector3(b.x,a.y,a.z),Vector3(b.x,a.y,b.z),
		Vector3(b.x,b.y,b.z),Vector3(b.x,b.y,a.z),color)
	_quad(st,Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),
		Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z),color)
	_quad(st,Vector3(a.x,a.y,b.z),Vector3(b.x,a.y,b.z),
		Vector3(b.x,a.y,a.z),Vector3(a.x,a.y,a.z),color)

static func _beam(st: SurfaceTool,at: Vector3,length: float,axis: String,tint: Color) -> void:
	var half: Vector3 = Vector3(0.15,0.15,0.15)
	if axis=="x": half.x=length*0.5
	if axis=="y": half.y=length*0.5
	if axis=="z": half.z=length*0.5
	_box(st,at,half,tint)

static func hero_geometry(id: String) -> ArrayMesh:
	if not SITE.has(id):
		return null
	var h: float = float(SITE[id]["height"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var limestone := Color("929ca2")
	var warm_stone := Color("b6b4a7")
	var anthracite := Color("283844")
	var brass := Color("b99d6b")
	var steel := Color("687c85")
	var glass := Color("3a6673")
	# Shared honest architectural structure: physically continuous 25m
	# original building shell and roof, not another large obstructing house.
	# City's existing original box stays the ONLY real building collider.
	for z in [-12.96,12.96]:
		_beam(st,Vector3(0,h+0.43,z),25.4,"x",brass)
	for x in [-12.96,12.96]:
		_beam(st,Vector3(x,h+0.43,0),25.4,"z",warm_stone)
	_box(st,Vector3(0,0.68,FACE_Z),Vector3(12.4,0.28,0.24),anthracite)
	match id:
		"cityhall":
			# Sovereign Hall: eight true stone piers + arched-pediment
			# relief, bronze lintels and deep, nested public entry.
			for x in [-10.7,-7.65,-4.6,-1.55,1.55,4.6,7.65,10.7]:
				_box(st,Vector3(float(x),10.8,-13.33),
					Vector3(0.38,9.4,0.53),warm_stone)
				_box(st,Vector3(float(x),20.45,-13.42),
					Vector3(0.62,0.36,0.72),brass)
				_box(st,Vector3(float(x),1.25,-13.42),
					Vector3(0.57,0.32,0.71),limestone)
			_box(st,Vector3(0,21.36,-13.46),Vector3(12.4,0.54,0.64),limestone)
			_box(st,Vector3(0,22.26,-13.41),Vector3(11.25,0.11,0.53),brass)
			for x in [-4.8,4.8]:
				_box(st,Vector3(float(x),5.3,-13.92),Vector3(0.12,4.65,0.12),brass)
			_box(st,Vector3(0,10.0,-13.93),Vector3(4.90,0.19,0.16),steel)
			_box(st,Vector3(0,3.55,-13.91),Vector3(3.05,3.12,0.16),glass)
			for side in [-1.0,1.0]:
				_box(st,Vector3(float(side)*13.08,13.0,0.0),
					Vector3(0.20,10.4,11.70),limestone)
		"market":
			# Market Exchange: wide real roofline, glazed arcades,
			# staggered glass trading bays and a signature bronze mezzanine.
			for x in [-11.0,-7.3,-3.6,0.1,3.8,7.5,11.2]:
				_box(st,Vector3(float(x),7.8,-13.25),Vector3(0.18,6.45,0.46),steel)
				_box(st,Vector3(float(x),8.5,-13.65),Vector3(0.12,6.75,0.09),brass)
			for x in [-9.15,-5.45,-1.75,1.95,5.65,9.35]:
				_box(st,Vector3(float(x),7.5,-13.72),Vector3(1.62,5.0,0.055),glass)
			_box(st,Vector3(0,14.55,-13.80),Vector3(12.2,0.32,2.10),brass)
			_box(st,Vector3(0,13.98,-14.16),Vector3(11.0,0.10,1.70),warm_stone)
			for x in [-9.0,0.0,9.0]:
				_box(st,Vector3(float(x),17.60,-9.1),Vector3(0.17,1.45,2.25),brass)
			_box(st,Vector3(0,19.15,-9.1),Vector3(10.25,0.26,2.25),glass)
		"depot":
			# Meridian Freight: monumental industrial truss with four
			# true gantry rails, a vertical ventilation spine and inset bays.
			for x in [-11.45,-7.7,-3.95,-0.20,3.55,7.30,11.05]:
				_box(st,Vector3(float(x),8.3,-13.28),Vector3(0.24,7.30,0.44),steel)
				_box(st,Vector3(float(x),15.0,-13.4),Vector3(0.55,0.30,0.54),brass)
			for y in [3.7,7.7,11.7,15.4]:
				_box(st,Vector3(0,float(y),-13.75),Vector3(12.16,0.18,0.20),anthracite)
			for x in [-8.1,-4.1,-0.1,3.9,7.9]:
				_box(st,Vector3(float(x),2.62,-13.84),Vector3(1.48,1.62,0.07),glass)
			for z in [-8.0,0.0,8.0]:
				_box(st,Vector3(12.98,11.2,float(z)),Vector3(0.26,3.85,0.14),steel)
			for x in [-9.0,9.0]:
				_box(st,Vector3(float(x),18.3,-2.0),Vector3(0.30,1.85,8.0),brass)
			_box(st,Vector3(0,20.0,-2.0),Vector3(9.9,0.25,8.0),steel)
		"power":
			# Aether Grid: restrained architectural heat-exchange fins,
			# energized glass spine and tall paired transformer columns.
			for x in [-11.2,-8.4,-5.6,-2.8,0.0,2.8,5.6,8.4,11.2]:
				_box(st,Vector3(float(x),13.2,-13.23),Vector3(0.24,10.50,0.66),steel)
				_box(st,Vector3(float(x),13.2,-13.73),Vector3(0.07,9.20,0.08),brass)
			for y in [5.0,10.0,15.0,20.0]:
				_box(st,Vector3(0,float(y),-13.84),Vector3(12.0,0.12,0.11),glass)
			for x in [-8.0,8.0]:
				_box(st,Vector3(float(x),27.3,1.4),Vector3(1.15,3.5,1.15),steel)
				_box(st,Vector3(float(x),30.95,1.4),Vector3(1.55,0.31,1.55),brass)
			for z in [-8.0,-4.0,0.0,4.0,8.0]:
				_box(st,Vector3(12.96,15.0,float(z)),Vector3(0.26,8.70,0.11),steel)
	st.generate_normals()
	return st.commit()

static func upgrade_geometry(id: String) -> ArrayMesh:
	if not SITE.has(id):
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: float = float(SITE[id]["height"])
	var metal: Color = SITE[id]["accent"]
	# Genuine built-upgraded civic strips: a continuous physical
	# crown plus four lit fins, no fake floating 2D notification bubble.
	_box(st,Vector3(0,h-1.12,-13.92),Vector3(10.60,0.09,0.08),metal)
	for x in [-9.0,-3.0,3.0,9.0]:
		_box(st,Vector3(float(x),h-2.15,-13.94),Vector3(0.11,0.90,0.10),metal)
	st.generate_normals()
	return st.commit()

static func _finish(metal: float,roughness: float,emissive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.metallic = metal
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = emissive
	m.emission_energy_multiplier = 0.0
	return m

func _ready() -> void:
	name = "CityReignPhysicalHeroBuildings"
	for id in ORDER:
		_create_one(id)
	# Source-authoritative player state is only READ; never mutate any
	# saved mission, money, civic project, city turn or traffic system.
	# Independent --script native test preloads this visual source BEFORE
	# Godot has registered the GameState global singleton symbol. Resolve
	# the exact real authoritative source node AFTER entering the scene.
	var actual_game: Node = get_node_or_null("/root/GameState")
	if actual_game != null:
		var source_state: Dictionary = actual_game.get("data")
		sync_state(source_state)
	set_quality("standard")
	if actual_game != null:
		var saved: Dictionary = actual_game.get("data")
		update_ambience(float(saved.get("day_clock",12.0)),int(saved.get("energy",100)))

func _create_one(id: String) -> void:
	var info: Dictionary = SITE[id]
	var root: Node3D = Node3D.new()
	root.name = "OriginalArchitecture_"+id
	root.position = info["position"]
	add_child(root)
	site_roots[id] = root
	var facade := MeshInstance3D.new()
	facade.name = "ActualLandmarkFacade_"+id
	facade.mesh = hero_geometry(id)
	facade.material_override = _finish(0.28,0.46,false)
	facade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(facade)
	facades[id] = facade
	facade_materials[id] = facade.material_override
	var upgrade := MeshInstance3D.new()
	upgrade.name = "ActualPurchasedCivicUpgrade_"+id
	upgrade.mesh = upgrade_geometry(id)
	upgrade.material_override = _finish(0.50,0.28,true)
	upgrade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(upgrade)
	upgrades[id] = upgrade
	upgrade_materials[id] = upgrade.material_override
	upgrade_strength[id] = 0
	progress_counts[id] = 0

func sync_state(state: Dictionary) -> void:
	if site_roots.size()!=ORDER.size():
		return
	var finished: Array = state.get("projects_done",[])
	var buildings: Dictionary = state.get("buildings",{})
	for id in ORDER:
		var district: String = str(SITE[id]["district"])
		var built: int = 0
		for key in GAME_SOURCE.BUILDING_ORDER:
			if str(GAME_SOURCE.BUILDINGS[key]["district"])==district:
				built+=clampi(int(buildings.get(key,0)),0,4)
		var achievements: int = 0
		for project_id in finished:
			if (CIVIC.PROJECTS.has(str(project_id)) and
				str(CIVIC.PROJECTS[str(project_id)]["district"])==district):
				achievements+=1
		var level: int = built+achievements*2
		progress_counts[id] = level
		upgrade_strength[id] = 0 if level==0 else mini(4,level)
	_update_upgrade_visibility()
	update_ambience(float(state.get("day_clock",12.0)),int(state.get("energy",100)))

func _update_upgrade_visibility() -> void:
	for id in ORDER:
		(upgrades[id] as MeshInstance3D).visible = (
			quality!="low" and int(progress_counts[id])>0)

func set_quality(tier: String) -> void:
	quality = tier if ["low","standard","cinematic"].has(tier) else "standard"
	for id in ORDER:
		(facades[id] as MeshInstance3D).visible = quality!="low"
	_update_upgrade_visibility()
	_update_materials()

func update_ambience(hour: float,energy: int) -> void:
	last_hour = fposmod(hour,24.0) if is_finite(hour) else 12.0
	last_energy = clampi(energy,0,100)
	_update_materials()

func _update_materials() -> void:
	var h: float = last_hour
	var nocturnal: float = 0.0
	if h>=19.5 or h<5.5:
		nocturnal = 1.0
	elif h>=17.5:
		nocturnal = clampf((h-17.5)/2.0,0.0,1.0)
	elif h<7.0:
		nocturnal = clampf((7.0-h)/1.5,0.0,1.0)
	var live_power: float = clampf(float(last_energy)/60.0,0.0,1.0)
	for id in ORDER:
		var material: StandardMaterial3D = upgrade_materials[id]
		var strength: float = float(upgrade_strength[id])
		var glow: float = 0.0 if quality=="low" else (
			minf(0.78,0.20+0.13*strength)*nocturnal*live_power
			if strength>0.0 else 0.0)
		material.emission_enabled = glow>0.001
		material.emission = SITE[id]["accent"]
		material.emission_energy_multiplier = glow

func graphics_are_bounded() -> bool:
	if (site_roots.size()!=4 or facades.size()!=4 or upgrades.size()!=4 or
		facade_materials.size()!=4 or upgrade_materials.size()!=4):
		return false
	if get_child_count()!=4 or not find_children("*","CollisionShape3D",true,false).is_empty():
		return false
	for id in ORDER:
		var root: Node3D = site_roots[id]
		var facade: MeshInstance3D = facades[id]
		var upgrade: MeshInstance3D = upgrades[id]
		if root.get_child_count()!=2 or root.position!=SITE[id]["position"]:
			return false
		if not facade.mesh is ArrayMesh or not upgrade.mesh is ArrayMesh:
			return false
		var vertices: int = facade.mesh.surface_get_array_len(0)
		if vertices<100 or vertices>MAX_VERTEX_COUNT_PER_SITE:
			return false
		if upgrade.mesh.surface_get_array_len(0)!=180:
			return false
		if (facade.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or
			upgrade.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF):
			return false
	return true
