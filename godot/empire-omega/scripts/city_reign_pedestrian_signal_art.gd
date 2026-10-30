extends Node3D
## CITY REIGN R180 — source-animated physical WALK / WAIT crossing heads.
## 16 original intersections, 2 directional heads each, 5 shared real
## MultiMesh GPU batches (32 metal housings, 32 green pedestrian bodies,
## 32 red waiting hands). ZERO new colliders, shadows or remote art.
const RULE=preload("res://scripts/city_reign_pedestrian_right_of_way.gd")
const JUNCTIONS=RULE.SIGNAL.JUNCTIONS
const MAX_BATCHES: int=5
const BOXES_PER_SYMBOL: int=7
var drawings: Dictionary={}
var finishes: Dictionary={}
var states: Dictionary={}
var sampled_elapsed: float=0.0
var sampled_power: int=100
var sampled_hour: float=12.0
var quality: String="standard"
var updates: int=0

static func _face(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	for v in [a,b,c,a,c,d]:st.add_vertex(v)

static func _box(st: SurfaceTool,center: Vector3,half: Vector3) -> void:
	var lo: Vector3=center-half
	var hi: Vector3=center+half
	_face(st,Vector3(lo.x,lo.y,lo.z),Vector3(hi.x,lo.y,lo.z),
		Vector3(hi.x,hi.y,lo.z),Vector3(lo.x,hi.y,lo.z))
	_face(st,Vector3(hi.x,lo.y,hi.z),Vector3(lo.x,lo.y,hi.z),
		Vector3(lo.x,hi.y,hi.z),Vector3(hi.x,hi.y,hi.z))
	_face(st,Vector3(lo.x,lo.y,hi.z),Vector3(lo.x,lo.y,lo.z),
		Vector3(lo.x,hi.y,lo.z),Vector3(lo.x,hi.y,hi.z))
	_face(st,Vector3(hi.x,lo.y,lo.z),Vector3(hi.x,lo.y,hi.z),
		Vector3(hi.x,hi.y,hi.z),Vector3(hi.x,hi.y,lo.z))
	_face(st,Vector3(lo.x,hi.y,lo.z),Vector3(lo.x,hi.y,hi.z),
		Vector3(hi.x,hi.y,hi.z),Vector3(hi.x,hi.y,lo.z))
	_face(st,Vector3(lo.x,lo.y,hi.z),Vector3(lo.x,lo.y,lo.z),
		Vector3(hi.x,lo.y,lo.z),Vector3(hi.x,lo.y,hi.z))

static func symbol_mesh(walking: bool) -> ArrayMesh:
	# A real 3D 7-part walk silhouette or stop hand. The source-authored
	# volume is lit by physically consistent native emissive PBR materials.
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if walking:
		_box(st,Vector3(0,0.23,0),Vector3(0.09,0.085,0.035))
		_box(st,Vector3(0,0.0,0),Vector3(0.055,0.16,0.035))
		_box(st,Vector3(-0.13,0.02,0),Vector3(0.10,0.036,0.035))
		_box(st,Vector3(0.11,-0.015,0),Vector3(0.08,0.035,0.035))
		_box(st,Vector3(-0.095,-0.225,0),Vector3(0.043,0.105,0.035))
		_box(st,Vector3(0.08,-0.24,0),Vector3(0.045,0.095,0.035))
		_box(st,Vector3(0.19,-0.29,0),Vector3(0.10,0.028,0.035))
	else:
		_box(st,Vector3(0,-0.01,0),Vector3(0.145,0.115,0.035))
		for i in range(4):
			_box(st,Vector3(-0.105+float(i)*0.072,0.15,0),
				Vector3(0.030,0.13,0.035))
		_box(st,Vector3(-0.16,-0.17,0),Vector3(0.065,0.13,0.035))
		_box(st,Vector3(0.08,-0.19,0),Vector3(0.060,0.10,0.035))
	st.generate_normals()
	return st.commit()

static func pose(x: float,z: float,axis: String,part: String) -> Transform3D:
	var heading: Basis=Basis(Vector3.UP,PI*0.5 if axis=="z" else 0.0)
	var horizontal: Vector3=Vector3(x+7.1,2.50,z+7.1)
	if axis=="z":horizontal+=Vector3(-0.65,0.0,0.0)
	var vertical: float=0.29 if part=="wait" else -0.28
	var offset: Vector3=heading*Vector3(0,vertical,-0.155)
	return Transform3D(heading,horizontal+offset)

func _batch(id: String,mesh: Mesh,positions: Array[Transform3D],
		base: Color) -> void:
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=mesh
	mm.instance_count=positions.size()
	for i in range(positions.size()):
		mm.set_instance_transform(i,positions[i])
	var child:=MultiMeshInstance3D.new()
	child.name="R180_TrueCrossing_"+id
	child.multimesh=mm
	child.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	child.custom_aabb=AABB(Vector3(-224,0,-224),Vector3(448,5,448))
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=base
	mat.metallic=0.13 if id=="housing" else 0.25
	mat.roughness=0.42 if id=="housing" else 0.27
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	child.material_override=mat
	add_child(child)
	drawings[id]=child
	finishes[id]=mat

func _ready() -> void:
	name="R180_PhysicalPedestrianWalkWaitNetwork"
	var housing: Array[Transform3D]=[]
	var directions: Dictionary={
		"x_walk":[],"x_wait":[],"z_walk":[],"z_wait":[]}
	for x in JUNCTIONS:
		for z in JUNCTIONS:
			for axis in ["x","z"]:
				var position: Transform3D=pose(float(x),float(z),axis,"body")
				housing.append(position)
				(directions[axis+"_walk"] as Array).append(
					pose(float(x),float(z),axis,"walk"))
				(directions[axis+"_wait"] as Array).append(
					pose(float(x),float(z),axis,"wait"))
	var case_mesh:=BoxMesh.new()
	case_mesh.size=Vector3(0.52,1.22,0.25)
	_batch("housing",case_mesh,housing,Color("18262f"))
	for axis in ["x","z"]:
		_batch(axis+"_walk",symbol_mesh(true),directions[axis+"_walk"],
			Color("17a46e"))
		_batch(axis+"_wait",symbol_mesh(false),directions[axis+"_wait"],
			Color("d16d5b"))
	set_quality(quality)
	sync_phase(0.0,100,12.0)

func sync_phase(elapsed: float,power: int,hour: float) -> void:
	if not is_finite(elapsed) or not is_finite(hour):return
	var current: Dictionary={
		"x":RULE.face_state(elapsed,"x"),
		"z":RULE.face_state(elapsed,"z")}
	var level: int=clampi(power,0,100)
	var clock: float=fposmod(hour,24.0)
	if states==current and level==sampled_power and
			is_equal_approx(clock,sampled_hour):
		return
	states=current
	sampled_elapsed=elapsed
	sampled_power=level
	sampled_hour=clock
	updates+=1
	var dark: bool=clock>=19.0 or clock<6.0
	for axis in ["x","z"]:
		var is_walk: bool=str(states[axis])=="walk"
		var mat_walk: StandardMaterial3D=finishes[axis+"_walk"]
		var mat_wait: StandardMaterial3D=finishes[axis+"_wait"]
		mat_walk.albedo_color=Color("24b984") if is_walk else Color("234f40")
		mat_wait.albedo_color=Color("5e3338") if is_walk else Color("d17e65")
		for id in [axis+"_walk",axis+"_wait"]:
			var material: StandardMaterial3D=finishes[id]
			var active: bool=(id.ends_with("_walk") and is_walk) or (
				id.ends_with("_wait") and not is_walk)
			material.emission_enabled=level>=15 and quality!="low"
			material.emission=material.albedo_color
			material.emission_energy_multiplier=(
				(1.15 if dark else 0.65)*float(level)/100.0
				if active else 0.035)
	var base: StandardMaterial3D=finishes["housing"]
	base.albedo_color=Color("223039") if dark else Color("293944")

func set_quality(tier: String) -> void:
	quality=tier if ["low","standard","cinematic"].has(tier) else "standard"
	for draw in drawings.values():
		(draw as MultiMeshInstance3D).visible=quality!="low"
	states.clear()
	sync_phase(sampled_elapsed,sampled_power,sampled_hour)

func batches_are_bounded() -> bool:
	if not RULE.consistent_with_original_grid() or drawings.size()!=MAX_BATCHES or
			get_child_count()!=MAX_BATCHES:
		return false
	if (drawings["housing"] as MultiMeshInstance3D).multimesh.instance_count!=32:
		return false
	for axis in ["x","z"]:
		for id in [axis+"_walk",axis+"_wait"]:
			if (drawings[id] as MultiMeshInstance3D).multimesh.instance_count!=16:
				return false
	for item in drawings.values():
		var node: MultiMeshInstance3D=item
		if node.get_child_count()>0 or
				node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
	return find_children("*","CollisionShape3D",true,false).is_empty()

func matches_source(elapsed: float) -> bool:
	return (states.get("x","") == RULE.face_state(elapsed,"x") and
		states.get("z","") == RULE.face_state(elapsed,"z"))
