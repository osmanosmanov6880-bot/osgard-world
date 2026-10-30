extends Node3D
## R184: 64 actual original city road-speed signs. Four GPU Multimeshes
## reuse ONE native 3D geometry per part: pole, white face, red border,
## source-authored raised-black 90 numerals (NOT a font/text/image).
## These physical meshes have no colliders, no billboards, no upload.
const RULE=preload("res://scripts/city_reign_speed_limit_policy.gd")
const ROADS=preload("res://scripts/city_reign_intersection_policy.gd")
const SIGN_PER_JUNCTION: int=4
const SIGN_COUNT: int=64
const BATCH_COUNT: int=4
const FACE_HEIGHT_M: float=2.78
const DISTANCE_BEFORE_JUNCTION_M: float=31.0
const SIDEWALK_OUTER_M: float=7.4
const FACE_RADIUS_M: float=0.57
const SEGMENT_DEPTH_M: float=0.018
const ANGULAR_STEPS: int=24
var art: Dictionary={}
var finishes: Dictionary={}
var tier: String="standard"
var remembered_power: int=100
var remembered_hour: float=12.0
var material_syncs: int=0

static func true_sign_pose(x: float,z: float,axis: String,
		travel_sign: int) -> Transform3D:
	if not ROADS.JUNCTIONS.has(x) or not ROADS.JUNCTIONS.has(z) or
			not ["x","z"].has(axis) or abs(travel_sign)!=1:
		return Transform3D.IDENTITY
	var at: Vector3
	var yaw: float
	if axis=="x":
		at=Vector3(x-float(travel_sign)*DISTANCE_BEFORE_JUNCTION_M,
			0,z+float(travel_sign)*SIDEWALK_OUTER_M)
		yaw=-float(travel_sign)*PI*0.5
	else:
		at=Vector3(x-float(travel_sign)*SIDEWALK_OUTER_M,
			0,z-float(travel_sign)*DISTANCE_BEFORE_JUNCTION_M)
		yaw=PI if travel_sign==1 else 0.0
	return Transform3D(Basis(Vector3.UP,yaw),at)

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	for v in [a,b,c,a,c,d]:
		st.add_vertex(v)

static func _letter_bar(st: SurfaceTool,x: float,y: float,
		width: float,height: float) -> void:
	var left: float=x-width*0.5
	var right: float=x+width*0.5
	var low: float=y-height*0.5
	var high: float=y+height*0.5
	_quad(st,Vector3(left,low,0),Vector3(right,low,0),
		Vector3(right,high,0),Vector3(left,high,0))

static func raised_digits_mesh() -> ArrayMesh:
	# A recognisable in-world 7-segment "90", sculpted once from original
	# SurfaceTool, so speed signage is source-truth rather than a texture.
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for digit in range(2):
		var xc: float=-0.15 if digit==0 else 0.15
		# '9' lights A B C D F G. '0' lights A B C D E F.
		for part in ["a","b","c","d","e","f","g"]:
			if (digit==0 and part=="e") or (digit==1 and part=="g"):
				continue
			var dx: float=0.0
			var dy: float=0.0
			var horizontal: bool=true
			match part:
				"a":dy=0.186
				"g":dy=0.0
				"d":dy=-0.186
				"b":dx=0.088;dy=0.09;horizontal=false
				"c":dx=0.088;dy=-0.09;horizontal=false
				"e":dx=-0.088;dy=-0.09;horizontal=false
				"f":dx=-0.088;dy=0.09;horizontal=false
			_letter_bar(st,xc+dx,dy,
				0.19 if horizontal else 0.047,
				0.047 if horizontal else 0.185)
	st.generate_normals()
	return st.commit()

static func circular_mesh(inner_radius: float,outer_radius: float) -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(ANGULAR_STEPS):
		var a0: float=TAU*float(i)/float(ANGULAR_STEPS)
		var a1: float=TAU*float(i+1)/float(ANGULAR_STEPS)
		_quad(st,
			Vector3(cos(a0)*inner_radius,sin(a0)*inner_radius,0),
			Vector3(cos(a1)*inner_radius,sin(a1)*inner_radius,0),
			Vector3(cos(a1)*outer_radius,sin(a1)*outer_radius,0),
			Vector3(cos(a0)*outer_radius,sin(a0)*outer_radius,0))
	st.generate_normals()
	return st.commit()

static func _instance_transform(base: Transform3D,part: String) -> Transform3D:
	var local: Vector3
	if part=="pole":
		local=Vector3(0,1.24,0)
	elif part=="digits":
		local=Vector3(0,FACE_HEIGHT_M,0.097)
	elif part=="ring":
		local=Vector3(0,FACE_HEIGHT_M,0.065)
	else:
		local=Vector3(0,FACE_HEIGHT_M,0.045)
	return Transform3D(base.basis,base.origin+base.basis*local)

func _make_batch(part: String,source_mesh: Mesh,
		positions: Array[Transform3D],color: Color) -> void:
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=source_mesh
	mm.instance_count=positions.size()
	for i in range(positions.size()):
		mm.set_instance_transform(i,positions[i])
	var node:=MultiMeshInstance3D.new()
	node.name="R184_Real90kph_"+part
	node.multimesh=mm
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb=AABB(Vector3(-214,0,-214),Vector3(428,6,428))
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.metallic=0.1 if part!="pole" else 0.48
	mat.roughness=0.46
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.material_override=mat
	add_child(node)
	art[part]=node
	finishes[part]=mat

func _ready() -> void:
	name="R184OriginalPhysical90SpeedSigns"
	var posts: Array[Transform3D]=[]
	var faces: Array[Transform3D]=[]
	var rings: Array[Transform3D]=[]
	var numerals: Array[Transform3D]=[]
	for x in ROADS.JUNCTIONS:
		for z in ROADS.JUNCTIONS:
			for axis in ["x","z"]:
				for travel_sign in [-1,1]:
					var base: Transform3D=true_sign_pose(float(x),float(z),
						axis,travel_sign)
					posts.append(_instance_transform(base,"pole"))
					faces.append(_instance_transform(base,"face"))
					rings.append(_instance_transform(base,"ring"))
					numerals.append(_instance_transform(base,"digits"))
	var pole_mesh:=BoxMesh.new()
	pole_mesh.size=Vector3(0.085,2.48,0.085)
	_make_batch("pole",pole_mesh,posts,Color("71818a"))
	_make_batch("face",circular_mesh(0.0,FACE_RADIUS_M),
		faces,Color("e9eee8"))
	_make_batch("ring",circular_mesh(0.46,FACE_RADIUS_M),
		rings,Color("c43b3c"))
	_make_batch("digits",raised_digits_mesh(),numerals,Color("101b24"))
	set_quality(tier)
	sync_power(remembered_power,remembered_hour)

func set_quality(value: String) -> void:
	tier=value if ["low","standard","cinematic"].has(value) else "standard"
	# Real rule signs remain legible on LOW. Only optional nighttime
	# material emission is dropped, not the source legal limit.
	for node in art.values():
		(node as MultiMeshInstance3D).visible=true
	var hour: float=remembered_hour
	remembered_hour=-1.0
	sync_power(remembered_power,hour)

func sync_power(power: int,hour: float) -> void:
	if not is_finite(hour):return
	var normalized: int=clampi(power,0,100)
	var clock: float=fposmod(hour,24.0)
	if remembered_power==normalized and is_equal_approx(clock,remembered_hour):
		return
	remembered_power=normalized
	remembered_hour=clock
	material_syncs+=1
	var night: bool=clock>=19.0 or clock<6.0
	for part in ["face","ring","digits"]:
		var mat: StandardMaterial3D=finishes[part]
		mat.emission_enabled=night and normalized>=15 and tier!="low"
		mat.emission=mat.albedo_color
		mat.emission_energy_multiplier=0.10*float(normalized)/100.0

func source_integrity() -> bool:
	if not RULE.source_rule_valid() or not ROADS.source_grid_valid() or
			art.size()!=BATCH_COUNT or get_child_count()!=BATCH_COUNT:
		return false
	if FACE_RADIUS_M<=0.5 or DISTANCE_BEFORE_JUNCTION_M>=ROADS.APPROACH_RANGE_M:
		return false
	for part in ["pole","face","ring","digits"]:
		var node: MultiMeshInstance3D=art.get(part)
		if node==null or node.multimesh==null or
				node.multimesh.instance_count!=SIGN_COUNT or
				not node.visible or
				node.get_child_count()!=0 or
				node.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
	if (art["digits"] as MultiMeshInstance3D).multimesh.mesh is not ArrayMesh:
		return false
	return find_children("*","CollisionShape3D",true,false).is_empty()
