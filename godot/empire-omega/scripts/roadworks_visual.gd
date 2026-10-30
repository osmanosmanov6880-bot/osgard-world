extends Node3D
## CITY REIGN R188 — ORIGINAL source-driven physical roadwork operations.
## Source of truth: CityMobility 12 genuine A* blocked 52m edges and the
## ORIGINAL GameState repair_road() treasury/materials/action transaction.
## Keeps the original markers/closest_hazard API and physical collision.
## No new incident IDs, gameplay money, road graph, third-party asset,
## real-time shadow light, player telemetry, or unnecessary site rebuild.
const MOBILITY=preload("res://scripts/city_mobility.gd")
const SOURCE=preload("res://scripts/city_reign_roadwork_operations.gd")
const SAFETY=preload("res://scripts/city_reign_intersection_policy.gd")
const SOURCE_BARRICADE_WIDTH_M: float=9.8
const SOURCE_BARRICADE_HEIGHT_M: float=1.6
const SOURCE_COLLIDER_DEPTH_M: float=0.82
const ACTIVE_GPU_BATCHES_PER_SITE: int=4
const WARNING_REFLECTOR_COUNT: int=7
const REAL_CONES_PER_SITE: int=12
const BRACE_COUNT: int=2
const BEAM_COUNT: int=2
var markers: Dictionary={}
var batches: Dictionary={}
var materials: Dictionary={}
var shared_meshes: Dictionary={}
var quality: String="standard"
var power: int=100
var hour: float=12.0
var actual_site_creations: int=0
var actual_site_removals: int=0
var unchanged_syncs: int=0
var material_syncs: int=0

func _ready() -> void:
	name="OriginalRealRoadworkOperations"
	var state: Node=get_node_or_null("/root/GameState")
	if state!=null:
		sync_state(state.get("data"))

func _shared_mesh(part: String) -> Mesh:
	if shared_meshes.has(part):
		return shared_meshes[part]
	var mesh: Mesh
	if part=="cones":
		var cone:=CylinderMesh.new()
		cone.top_radius=0.07
		cone.bottom_radius=0.24
		cone.height=0.70
		cone.radial_segments=10
		mesh=cone
	else:
		var bar:=BoxMesh.new()
		match part:
			"beam":bar.size=Vector3(9.4,0.47,0.30)
			"reflectors":bar.size=Vector3(0.69,0.50,0.34)
			"braces":bar.size=Vector3(0.30,1.32,0.34)
		mesh=bar
	shared_meshes[part]=mesh
	return mesh

func _batch(parent: Node3D,id: String,part: String,
		poses: Array[Transform3D],paint: Color) -> void:
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=_shared_mesh(part)
	mm.instance_count=poses.size()
	for i in range(poses.size()):
		mm.set_instance_transform(i,poses[i])
	var draw:=MultiMeshInstance3D.new()
	draw.name="R188SourceRoadwork_"+part
	draw.multimesh=mm
	draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.custom_aabb=AABB(Vector3(-6,0,-5),Vector3(12,4,10))
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=paint
	mat.metallic=0.12 if part=="braces" else 0.02
	mat.roughness=0.67
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	draw.material_override=mat
	parent.add_child(draw)
	var group: Dictionary=batches[id]
	group[part]=draw
	batches[id]=group
	var finishes: Dictionary=materials[id]
	finishes[part]=mat
	materials[id]=finishes

func _source_marker(id: String,source: Dictionary) -> void:
	var center: Vector3=source["center"]
	var root:=Node3D.new()
	root.name="RoadClosure_"+id
	# True original asphalt height is near 0.175m. Unlike old elevated
	# roadwork props these real cones stand ON the existing 10m road.
	root.position=Vector3(center.x,0.18,center.z)
	root.rotation.y=float(source["yaw"])
	add_child(root)
	markers[id]=root
	batches[id]={}
	materials[id]={}
	# The ONLY collision body — original middle-of-52m closed road.
	# The A* uses that exact same source segment and cannot traverse it.
	var body:=StaticBody3D.new()
	body.name="RoadClosureCollider"
	body.collision_layer=1
	body.collision_mask=0
	body.position.y=0.88
	root.add_child(body)
	var collision:=CollisionShape3D.new()
	collision.name="OriginalPhysicalRoadClosure"
	var physical:=BoxShape3D.new()
	physical.size=Vector3(SOURCE_BARRICADE_WIDTH_M,
		SOURCE_BARRICADE_HEIGHT_M,SOURCE_COLLIDER_DEPTH_M)
	collision.shape=physical
	body.add_child(collision)
	var beam_poses: Array[Transform3D]=[]
	for height in [0.85,1.55]:
		beam_poses.append(Transform3D(Basis.IDENTITY,Vector3(0,height,0)))
	_batch(root,id,"beam",beam_poses,Color("d1a752"))
	var reflectors: Array[Transform3D]=[]
	for i in range(WARNING_REFLECTOR_COUNT):
		reflectors.append(Transform3D(Basis.IDENTITY,
			Vector3(float(i-3)*1.35,1.55,0.18)))
	_batch(root,id,"reflectors",reflectors,Color("a83c32"))
	var braces: Array[Transform3D]=[]
	for x in [-4.5,4.5]:
		braces.append(Transform3D(Basis.IDENTITY,Vector3(float(x),0.72,0)))
	_batch(root,id,"braces",braces,Color("303940"))
	var cones: Array[Transform3D]=[]
	for side in [-1,1]:
		for x in [-4.2,-3.3,-2.4,2.4,3.3,4.2]:
			cones.append(Transform3D(Basis.IDENTITY,
				Vector3(float(x),0.35,float(side)*2.15)))
	_batch(root,id,"cones",cones,Color("d86e35"))
	actual_site_creations+=1
	_apply_quality(id)

func _apply_quality(id: String) -> void:
	if not batches.has(id):return
	var groups: Dictionary=batches[id]
	# Mobile LOW preserves solid collision and legible reflective beam,
	# hides optional detail only, never conceals the road closure.
	(groups["beam"] as MultiMeshInstance3D).visible=true
	(groups["reflectors"] as MultiMeshInstance3D).visible=true
	(groups["braces"] as MultiMeshInstance3D).visible=quality!="low"
	(groups["cones"] as MultiMeshInstance3D).visible=quality!="low"

func set_quality(value: String) -> void:
	quality=value if ["low","standard","cinematic"].has(value) else "standard"
	for id in markers:
		_apply_quality(str(id))
	_refresh_materials()

func sync_city(state: Dictionary) -> void:
	var level: int=clampi(int(state.get("energy",100)),0,100)
	var current: float=float(state.get("day_clock",12.0))
	if not is_finite(current):return
	power=level
	hour=fposmod(current,24.0)
	_refresh_materials()

func _refresh_materials() -> void:
	var dark: bool=hour>=19.0 or hour<6.0
	for per_site in materials.values():
		var group: Dictionary=per_site
		for part in group:
			var paint: StandardMaterial3D=group[part]
			paint.emission_enabled=dark and power>=15 and quality!="low" and (
				part=="reflectors" or part=="cones")
			paint.emission=paint.albedo_color
			paint.emission_energy_multiplier=0.20*float(power)/100.0
	material_syncs+=1

func sync_state(state: Dictionary) -> void:
	# Source game events can emit many no-op state updates. Do NOT
	# destroy/recreate physical barriers, GPU buffers or materials
	# unless the canonical A* closure set itself changed.
	var next: Dictionary={}
	for source in SOURCE.active_sites(state):
		next[str(source["id"])]=source
	var changed: bool=false
	for id in markers.keys():
		if next.has(id):continue
		var root: Node3D=markers[id]
		if is_instance_valid(root):
			# Deferred-safe collision removal in a player physics callback.
			var collider: CollisionShape3D=root.get_node_or_null(
				"RoadClosureCollider/OriginalPhysicalRoadClosure")
			if collider!=null:collider.set_deferred("disabled",true)
			root.queue_free()
		markers.erase(id)
		batches.erase(id)
		materials.erase(id)
		actual_site_removals+=1
		changed=true
	for id in next:
		if markers.has(id):continue
		_source_marker(str(id),next[id])
		changed=true
	if not changed:unchanged_syncs+=1
	sync_city(state)

func driver_warning(at: Vector3,yaw: float,speed: float) -> Dictionary:
	# Only actual physically rendered and still ACTIVE source barriers,
	# never a fabricated dashboard warning or already-repaired incident.
	var active: Array[Dictionary]=[]
	for id in markers:
		var incident: Dictionary=MOBILITY.incident_by_id(str(id))
		if not incident.is_empty():active.append(incident)
	return SOURCE.driver_warning(at,yaw,speed,active)

func closest_hazard(point: Vector3,radius: float=9.0) -> String:
	if not point.is_finite() or not is_finite(radius) or radius<=0.0:
		return ""
	var found: String=""
	var best: float=radius*radius
	for id in markers:
		var root: Node3D=markers[id]
		if not is_instance_valid(root):continue
		var distance: float=root.global_position.distance_squared_to(point)
		if distance<best:
			best=distance
			found=str(id)
	return found

func source_integrity(state: Dictionary) -> bool:
	if not SOURCE.catalog_integrity():return false
	var expected: Array[Dictionary]=SOURCE.active_sites(state)
	if expected.size()!=markers.size() or
			markers.size()!=batches.size() or
			markers.size()!=materials.size():
		return false
	for source in expected:
		var id: String=str(source["id"])
		if not markers.has(id):return false
		var root: Node3D=markers[id]
		if not is_instance_valid(root) or root.get_child_count()!=5:
			return false
		var center: Vector3=source["center"]
		if root.global_position.distance_to(
				Vector3(center.x,0.18,center.z))>0.001:
			return false
		if not is_equal_approx(root.rotation.y,float(source["yaw"])):
			return false
		var body: StaticBody3D=root.get_node_or_null("RoadClosureCollider")
		if body==null or body.collision_layer!=1 or body.collision_mask!=0:
			return false
		var collision: CollisionShape3D=body.get_node_or_null(
			"OriginalPhysicalRoadClosure")
		if collision==null or not collision.shape is BoxShape3D or
				collision.disabled:
			return false
		var physics: BoxShape3D=collision.shape
		if not physics.size.is_equal_approx(Vector3(
				SOURCE_BARRICADE_WIDTH_M,SOURCE_BARRICADE_HEIGHT_M,
				SOURCE_COLLIDER_DEPTH_M)):
			return false
		var group: Dictionary=batches[id]
		if group.size()!=ACTIVE_GPU_BATCHES_PER_SITE:return false
		for part in ["beam","reflectors","braces","cones"]:
			var draw: MultiMeshInstance3D=group.get(part)
			var count: int=BEAM_COUNT if part=="beam" else (
				WARNING_REFLECTOR_COUNT if part=="reflectors" else (
				BRACE_COUNT if part=="braces" else REAL_CONES_PER_SITE))
			if (draw==null or draw.multimesh==null or
				draw.multimesh.instance_count!=count or
				draw.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF):
				return false
			if part in ["beam","reflectors"] and not draw.visible:
				return false
			if part in ["braces","cones"] and draw.visible==(quality=="low"):
				return false
		if not root.find_children("*","OmniLight3D",true,false).is_empty():
			return false
	return true
