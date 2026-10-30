extends Node3D
## CITY REIGN R178: road-painted REAL signal stop bars at original 16 junctions.
## Three GPU batches total: 64 zero-collision painted stop bars and 32
## physical reflector studs per axis. No new route, invented traffic state,
## physics body, shadow map, download, texture, building or per-frame mesh.
const POLICY=preload("res://scripts/city_reign_intersection_policy.gd")
const STOP_BARS: int=64
const STUDS_PER_AXIS: int=32
const MAX_BATCHES: int=3
const ASPHALT_Y: float=0.204
var draws: Dictionary={}
var paints: Dictionary={}
var synced_states: Dictionary={}
var synced_elapsed: float=0.0
var synced_power: int=100
var synced_hour: float=12.0
var quality: String="standard"
var changed: int=0

static func source_position(x: float,z: float,axis: String,side: int) -> Transform3D:
	if not POLICY.JUNCTIONS.has(x) or not POLICY.JUNCTIONS.has(z):
		return Transform3D.IDENTITY
	if not ["x","z"].has(axis) or abs(side)!=1:
		return Transform3D.IDENTITY
	var orient: Basis=Basis(Vector3.UP,PI*0.5 if axis=="x" else 0.0)
	var coordinate: Vector3=Vector3(
		x+float(side)*POLICY.STOP_LINE_M if axis=="x" else x,
		ASPHALT_Y,
		z+float(side)*POLICY.STOP_LINE_M if axis=="z" else z)
	return Transform3D(orient,coordinate)

func _batch(id: String,mesh: Mesh,poses: Array[Transform3D],
		base: Color) -> void:
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=mesh
	mm.instance_count=poses.size()
	for i in range(poses.size()):
		mm.set_instance_transform(i,poses[i])
	var item:=MultiMeshInstance3D.new()
	item.name="R178_Authentic_"+id
	item.multimesh=mm
	item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.custom_aabb=AABB(Vector3(-225.0,0.0,-225.0),
		Vector3(450.0,1.0,450.0))
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=base
	mat.metallic=0.08 if id=="white_stop_lines" else 0.45
	mat.roughness=0.72 if id=="white_stop_lines" else 0.38
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	item.material_override=mat
	add_child(item)
	draws[id]=item
	paints[id]=mat

func _ready() -> void:
	name="CityReignR178AuthenticIntersectionStopBars"
	var lines: Array[Transform3D]=[]
	var east: Array[Transform3D]=[]
	var north: Array[Transform3D]=[]
	var marker_offset: Vector3=Vector3(4.18,0.018,0.0)
	for x in POLICY.JUNCTIONS:
		for z in POLICY.JUNCTIONS:
			for sign in [-1,1]:
				var xpose: Transform3D=source_position(float(x),float(z),"x",sign)
				var zpose: Transform3D=source_position(float(x),float(z),"z",sign)
				lines.append(xpose)
				lines.append(zpose)
				east.append(Transform3D(xpose.basis,xpose.origin+xpose.basis*marker_offset))
				north.append(Transform3D(zpose.basis,zpose.origin+zpose.basis*marker_offset))
	var stripe:=BoxMesh.new()
	stripe.size=Vector3(7.86,0.027,0.17)
	_batch("white_stop_lines",stripe,lines,Color("c0c9c8"))
	var studs:=BoxMesh.new()
	studs.size=Vector3(0.31,0.035,0.27)
	_batch("x_reflectors",studs,east,Color("547963"))
	_batch("z_reflectors",studs,north,Color("547963"))
	set_quality(quality)
	sync_phase(0.0,100,12.0)

static func shade(phase: String) -> Color:
	match phase:
		"red": return Color("c17d65")
		"amber": return Color("d4b16c")
		"green": return Color("81bd9c")
	return Color("777d81")

func sync_phase(elapsed: float,power: int,hour: float) -> void:
	if not is_finite(elapsed) or not is_finite(hour):return
	var level: int=clampi(power,0,100)
	var clock: float=fposmod(hour,24.0)
	var now: Dictionary={
		"x":POLICY.state_at(elapsed,Vector3(1,0,0)),
		"z":POLICY.state_at(elapsed,Vector3(0,0,1))}
	if now==synced_states and synced_power==level and is_equal_approx(synced_hour,clock):
		return
	synced_states=now
	synced_elapsed=elapsed
	synced_power=level
	synced_hour=clock
	changed+=1
	var dark: bool=clock>=19.0 or clock<6.0
	var strength: float=(0.18 if quality=="standard" else 0.35) * clampf(float(level)/65.0,0.0,1.0)
	for axis in ["x","z"]:
		var mat: StandardMaterial3D=paints.get(axis+"_reflectors")
		if mat==null:continue
		mat.albedo_color=shade(str(now[axis]))
		mat.emission_enabled=dark and level>=15 and quality!="low"
		mat.emission=shade(str(now[axis]))
		mat.emission_energy_multiplier=strength
	var white: StandardMaterial3D=paints.get("white_stop_lines")
	if white!=null:
		white.albedo_color=Color("c6d0d2") if dark else Color("d2d5d1")
		white.emission_enabled=false

func set_quality(tier: String) -> void:
	quality=tier if ["low","standard","cinematic"].has(tier) else "standard"
	if draws.has("white_stop_lines"):
		draws["white_stop_lines"].visible=true
	for axis in ["x","z"]:
		if draws.has(axis+"_reflectors"):
			draws[axis+"_reflectors"].visible=quality!="low"
	# Recompute real PBR emission on any quality switch even if phase holds.
	synced_states.clear()
	sync_phase(synced_elapsed,synced_power,synced_hour)

func source_budget_ok() -> bool:
	if get_child_count()!=MAX_BATCHES or draws.size()!=MAX_BATCHES or paints.size()!=MAX_BATCHES:
		return false
	if not POLICY.source_grid_valid():return false
	if not draws.has("white_stop_lines") or draws["white_stop_lines"].multimesh.instance_count!=STOP_BARS:
		return false
	for axis in ["x","z"]:
		var node: MultiMeshInstance3D=draws.get(axis+"_reflectors")
		if node==null or node.multimesh.instance_count!=STUDS_PER_AXIS:
			return false
	for item in draws.values():
		var node: MultiMeshInstance3D=item
		if (node.get_child_count()!=0 or node.multimesh==null or
			node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF):
			return false
	return find_children("*","CollisionShape3D",true,false).is_empty()

func phases_match(elapsed: float) -> bool:
	return (synced_states.get("x","") == POLICY.state_at(elapsed,Vector3.RIGHT) and
		synced_states.get("z","") == POLICY.state_at(elapsed,Vector3.BACK))
