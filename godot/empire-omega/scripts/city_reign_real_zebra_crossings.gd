extends Node3D
## CITY REIGN R182: 64 genuine road zebras for 16 source junctions.
## 6 native painted strips per approach, 384 positions in TWO GPU batches.
## No new colliders, third-party textures, shadow maps, tile streams, roads,
## scripted signals, artificial pedestrians or paid crossing replacements.
const ROAD=preload("res://scripts/city_reign_intersection_policy.gd")
const JUNCTIONS: int=16
const APPROACHES_PER_AXIS: int=2
const STRIPES_PER_APPROACH: int=6
const STRIPES_PER_AXIS: int=JUNCTIONS*APPROACHES_PER_AXIS*STRIPES_PER_APPROACH
const GPU_BATCHES: int=2
const STRIPE_SPACING_M: float=0.41
const SOURCE_ROAD_OFFSET_M: float=5.3
const SOURCE_STOP_OFFSET_M: float=ROAD.STOP_LINE_M
const PAINT_HEIGHT_M: float=0.209
const PAINT_LENGTH_M: float=8.7
var paint_instances: Dictionary={}
var paint_finishes: Dictionary={}
var current_quality: String="standard"
var current_power: int=100
var current_hour: float=12.0
var sync_changes: int=0

static func stripe_transform(x: float,z: float,axis: String,
		sign: int,stripe: int) -> Transform3D:
	if not ROAD.JUNCTIONS.has(x) or not ROAD.JUNCTIONS.has(z) or
		not ["x","z"].has(axis) or abs(sign)!=1 or
		stripe<0 or stripe>=STRIPES_PER_APPROACH:
		return Transform3D.IDENTITY
	var offset: float=(float(stripe)-2.5)*STRIPE_SPACING_M
	var along: float=float(sign)*SOURCE_ROAD_OFFSET_M+offset
	if axis=="x":
		return Transform3D(Basis.IDENTITY,Vector3(x+along,PAINT_HEIGHT_M,z))
	return Transform3D(Basis(Vector3.UP,PI*0.5),
		Vector3(x,PAINT_HEIGHT_M,z+along))

func _batch(id: String,mesh: Mesh,transforms: Array[Transform3D]) -> void:
	var instances:=MultiMesh.new()
	instances.transform_format=MultiMesh.TRANSFORM_3D
	instances.mesh=mesh
	instances.instance_count=transforms.size()
	for i in range(transforms.size()):
		instances.set_instance_transform(i,transforms[i])
	var geometry:=MultiMeshInstance3D.new()
	geometry.name="R182OriginalZebra_"+id
	geometry.multimesh=instances
	geometry.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	geometry.custom_aabb=AABB(Vector3(-220,0,-220),Vector3(440,1,440))
	var paint:=StandardMaterial3D.new()
	paint.albedo_color=Color("c9d4ce")
	paint.metallic=0.04
	paint.roughness=0.80
	paint.cull_mode=BaseMaterial3D.CULL_DISABLED
	geometry.material_override=paint
	add_child(geometry)
	paint_instances[id]=geometry
	paint_finishes[id]=paint

func _ready() -> void:
	name="R182_ActualPedestrianRoadZebra"
	var x_stripes: Array[Transform3D]=[]
	var z_stripes: Array[Transform3D]=[]
	for x in ROAD.JUNCTIONS:
		for z in ROAD.JUNCTIONS:
			for sign in [-1,1]:
				for s in range(STRIPES_PER_APPROACH):
					x_stripes.append(stripe_transform(float(x),float(z),"x",sign,s))
					z_stripes.append(stripe_transform(float(x),float(z),"z",sign,s))
	var shared_mesh:=BoxMesh.new()
	shared_mesh.size=Vector3(0.27,0.016,PAINT_LENGTH_M)
	_batch("x",shared_mesh,x_stripes)
	_batch("z",shared_mesh,z_stripes)
	set_quality(current_quality)
	sync_world(100,12.0)

func sync_world(power: int,hour: float) -> void:
	if not is_finite(hour):return
	var level: int=clampi(power,0,100)
	var clock: float=fposmod(hour,24.0)
	if current_power==level and is_equal_approx(clock,current_hour):
		return
	current_power=level
	current_hour=clock
	sync_changes+=1
	var dark: bool=clock>=19.0 or clock<6.0
	for mat in paint_finishes.values():
		var finish: StandardMaterial3D=mat
		finish.albedo_color=Color("c1c9bf") if dark else Color("d3d8d0")
		finish.emission_enabled=dark and level>=15 and current_quality!="low"
		finish.emission=Color("637b6c")
		finish.emission_energy_multiplier=0.09*float(level)/100.0

func set_quality(tier: String) -> void:
	current_quality=tier if ["low","standard","cinematic"].has(tier) else "standard"
	# Actual physical road-marking safety remains visible in LOW, just
	# like source R178 original stopbars; remove only premium emission.
	for draw in paint_instances.values():
		(draw as MultiMeshInstance3D).visible=true
	current_hour=-1.0
	sync_world(current_power,12.0 if current_hour<0 else current_hour)

func source_geometry_valid() -> bool:
	if not ROAD.source_grid_valid() or get_child_count()!=GPU_BATCHES or
			paint_instances.size()!=GPU_BATCHES or paint_finishes.size()!=GPU_BATCHES:
		return false
	if SOURCE_ROAD_OFFSET_M+STRIPE_SPACING_M*2.5>=SOURCE_STOP_OFFSET_M:
		return false
	for axis in ["x","z"]:
		var instance: MultiMeshInstance3D=paint_instances.get(axis)
		if instance==null or instance.multimesh==null or
			instance.multimesh.instance_count!=STRIPES_PER_AXIS or
			not instance.visible or instance.get_child_count()!=0 or
			instance.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
	return find_children("*","CollisionShape3D",true,false).is_empty()
