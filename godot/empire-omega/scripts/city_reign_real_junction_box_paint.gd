extends Node3D
## CITY REIGN R187: authentic 16 physical 3D keep-clear boxes painted
## directly on the ORIGINAL 10m asphalt under original R186 occupancy.
## 64 perimeter + 80 clipped diagonal slats in 2 MultiMesh GPU batches.
## Real readable warm yellow in LOW, no text sprites, duplicate roads,
## shadows, new traffic clocks, physics colliders or network imagery.
const BOX=preload("res://scripts/city_reign_junction_box_clearance.gd")
const SIGNAL=preload("res://scripts/city_reign_intersection_policy.gd")
const ORIGINAL_JUNCTIONS: int=16
const OUTLINES_PER_JUNCTION: int=4
const DIAGONALS_PER_JUNCTION: int=5
const OUTLINE_INSTANCES: int=ORIGINAL_JUNCTIONS*OUTLINES_PER_JUNCTION
const HATCH_INSTANCES: int=ORIGINAL_JUNCTIONS*DIAGONALS_PER_JUNCTION
const PAINT_GPU_BATCHES: int=2
const ROAD_PAINT_HALF_M: float=4.3
const Y_ABOVE_ORIGINAL_ASPHALT_M: float=0.212
const OUTLINE_PAINT_WIDTH_M: float=0.11
const HATCH_PAINT_WIDTH_M: float=0.085
const HATCH_OFFSETS=[-6.0,-3.0,0.0,3.0,6.0]
var painted: Dictionary={}
var materials: Dictionary={}
var current_tier: String="standard"
var city_power: int=100
var city_hour: float=12.0
var material_updates: int=0

static func outline_transform(x: float,z: float,
		orientation: String,edge: int) -> Transform3D:
	if (not SIGNAL.JUNCTIONS.has(x) or not SIGNAL.JUNCTIONS.has(z) or
		not ["x","z"].has(orientation) or abs(edge)!=1):
		return Transform3D.IDENTITY
	# Each source border lies completely ON TOP of the original
	# 10-metre-wide asphalt at its real 16 physical junctions.
	if orientation=="x":
		return Transform3D(Basis.IDENTITY,
			Vector3(x+float(edge)*ROAD_PAINT_HALF_M,
				Y_ABOVE_ORIGINAL_ASPHALT_M,z))
	return Transform3D(Basis(Vector3.UP,PI*0.5),
		Vector3(x,Y_ABOVE_ORIGINAL_ASPHALT_M,
			z+float(edge)*ROAD_PAINT_HALF_M))

static func hatch_transform(x: float,z: float,
		hatch: int) -> Transform3D:
	if (not SIGNAL.JUNCTIONS.has(x) or not SIGNAL.JUNCTIONS.has(z) or
			hatch<0 or hatch>=DIAGONALS_PER_JUNCTION):
		return Transform3D.IDENTITY
	var constant: float=float(HATCH_OFFSETS[hatch])
	var start: Vector2
	var finish: Vector2
	# Analytically clip the ORIGINAL 45-degree x+z=constant hatch
	# against the 8.6m asphalt square. No marks in building blocks.
	if constant>=0.0:
		start=Vector2(constant-ROAD_PAINT_HALF_M,ROAD_PAINT_HALF_M)
		finish=Vector2(ROAD_PAINT_HALF_M,constant-ROAD_PAINT_HALF_M)
	else:
		start=Vector2(-ROAD_PAINT_HALF_M,constant+ROAD_PAINT_HALF_M)
		finish=Vector2(constant+ROAD_PAINT_HALF_M,-ROAD_PAINT_HALF_M)
	var line: Vector2=finish-start
	var midpoint: Vector2=(start+finish)*0.5
	var yaw: float=atan2(line.x,line.y)
	var basis:=Basis(Vector3.UP,yaw)
	# The hatch mesh is a 1m strip scaled by actual clipped physical
	# length, so all 80 native strips share just ONE source 3D mesh.
	# Local-space z-axis scaling: global Basis.scaled() distorts the
	# rotated 45-degree strip and would paint beyond original asphalt.
	basis.z=basis.z*line.length()
	return Transform3D(basis,
		Vector3(x+midpoint.x,Y_ABOVE_ORIGINAL_ASPHALT_M,
			z+midpoint.y))

func _add_batch(name: String,width: float,length: float,
		locations: Array[Transform3D]) -> void:
	var bar:=BoxMesh.new()
	bar.size=Vector3(width,0.013,length)
	var array:=MultiMesh.new()
	array.transform_format=MultiMesh.TRANSFORM_3D
	array.mesh=bar
	array.instance_count=locations.size()
	for i in range(locations.size()):
		array.set_instance_transform(i,locations[i])
	var draw:=MultiMeshInstance3D.new()
	draw.name="R187OriginalPhysicalKeepClear_"+name
	draw.multimesh=array
	draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.custom_aabb=AABB(Vector3(-219,0,-219),Vector3(438,1,438))
	var paint:=StandardMaterial3D.new()
	paint.albedo_color=Color("d2ad65") if name=="outline" else Color("b29a63")
	paint.roughness=0.85
	paint.metallic=0.025
	paint.cull_mode=BaseMaterial3D.CULL_DISABLED
	draw.material_override=paint
	add_child(draw)
	painted[name]=draw
	materials[name]=paint

func _ready() -> void:
	name="R187OriginalRealKeepClearJunctions"
	var borders: Array[Transform3D]=[]
	var diagonals: Array[Transform3D]=[]
	for x in SIGNAL.JUNCTIONS:
		for z in SIGNAL.JUNCTIONS:
			for axis in ["x","z"]:
				for edge in [-1,1]:
					borders.append(outline_transform(float(x),float(z),axis,edge))
			for hatch in range(DIAGONALS_PER_JUNCTION):
				diagonals.append(hatch_transform(float(x),float(z),hatch))
	_add_batch("outline",OUTLINE_PAINT_WIDTH_M,
		ROAD_PAINT_HALF_M*2.0,borders)
	_add_batch("diagonal",HATCH_PAINT_WIDTH_M,1.0,diagonals)
	set_quality(current_tier)
	sync_city(100,12.0)

func set_quality(tier: String) -> void:
	current_tier=tier if ["low","standard","cinematic"].has(tier) else "standard"
	# Real safety boundary is always readable in LOW. The optional
	# in-box premium hatch is removed for a simpler low-spec HUD scene.
	(painted["outline"] as MultiMeshInstance3D).visible=true
	(painted["diagonal"] as MultiMeshInstance3D).visible=current_tier!="low"
	var clock: float=city_hour
	city_hour=-1.0
	sync_city(city_power,clock)

func sync_city(power: int,hour: float) -> void:
	if not is_finite(hour):return
	var level: int=clampi(power,0,100)
	var clock: float=fposmod(hour,24.0)
	if level==city_power and is_equal_approx(clock,city_hour):return
	city_power=level
	city_hour=clock
	material_updates+=1
	var night: bool=clock>=19.0 or clock<6.0
	for part in ["outline","diagonal"]:
		var paint: StandardMaterial3D=materials[part]
		paint.emission_enabled=night and level>=15 and current_tier!="low"
		paint.emission=Color("b59a61")
		paint.emission_energy_multiplier=0.075*float(level)/100.0

func source_geometry_valid() -> bool:
	if (not BOX.source_integrity() or not SIGNAL.source_grid_valid() or
		painted.size()!=PAINT_GPU_BATCHES or get_child_count()!=PAINT_GPU_BATCHES):
		return false
	# Keep the physical road paint INSIDE actual original asphalt AND
	# the 6.4m box measured by the real R186 collision-prevention rule.
	if (ROAD_PAINT_HALF_M+OUTLINE_PAINT_WIDTH_M*0.5>=SIGNAL.ROAD_HALF_WIDTH_M or
		ROAD_PAINT_HALF_M>=BOX.SOURCE_BOX_HALF_M or
		ROAD_PAINT_HALF_M>=SIGNAL.STOP_LINE_M):
		return false
	for part in ["outline","diagonal"]:
		var node: MultiMeshInstance3D=painted.get(part)
		var expected: int=OUTLINE_INSTANCES if part=="outline" else HATCH_INSTANCES
		if (node==null or node.multimesh==null or
			node.multimesh.instance_count!=expected or
			node.get_child_count()!=0 or
			node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF):
			return false
	if not (painted["outline"] as MultiMeshInstance3D).visible:return false
	if (painted["diagonal"] as MultiMeshInstance3D).visible==(current_tier=="low"):
		return false
	return find_children("*","CollisionShape3D",true,false).is_empty()
