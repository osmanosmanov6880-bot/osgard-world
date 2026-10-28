extends Node3D
## CITY REIGN AAA A17: ORIGINAL volumetric metropolitan traffic signal art.
## Two REAL direction-specific heads at each of the 16 original junctions.
## ONE shared source mesh for all signal heads; no PNGs, assets or collision.
## 16 steel arms + 32 3D housings + 96 real convex LED lenses in NINE
## GPU MultiMesh batches. Legacy original box signs remain as LOW fallback.
const INTERSECTIONS = [-156.0,-52.0,52.0,156.0]
const DIRECTIONS = ["x","z"]
const COLOURS = ["red","amber","green"]
const MAX_BATCHES: int = 9
const INSTANCES_PER_DIRECTION: int = 16
const TOTAL_LENS_INSTANCES: int = 96
const LED_HEIGHTS = {"red":0.52,"amber":0.0,"green":-0.52}
const DARK = {"red":Color("491a21"),"amber":Color("45371d"),"green":Color("15372e")}
# Real Chromium image review found the original bright red washed to pink
# and emerald washed to cyan-white under energy 2.8. Use physically richer
# pigments and a lower emission power for color-critical traffic readability.
const BRIGHT = {"red":Color("c91d2a"),"amber":Color("d89c37"),"green":Color("0b9c59")}
const ACTIVE_LED_RADIANCE: float = 1.25
var batches: Dictionary = {}
var finishes: Dictionary = {}
var placements: Dictionary = {}
var lamp_state: Dictionary = {}
var last_phase: int = -1
var warning: bool = false
var detail: String = "standard"

static func _face(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,tint: Color) -> void:
	st.set_color(tint)
	for vertex in [a,b,c,a,c,d]:
		st.add_vertex(vertex)

static func _box(st: SurfaceTool,center: Vector3,half: Vector3,tint: Color) -> void:
	var low: Vector3 = center-half
	var high: Vector3 = center+half
	_face(st,Vector3(low.x,low.y,low.z),Vector3(high.x,low.y,low.z),
		Vector3(high.x,high.y,low.z),Vector3(low.x,high.y,low.z),tint)
	_face(st,Vector3(high.x,low.y,high.z),Vector3(low.x,low.y,high.z),
		Vector3(low.x,high.y,high.z),Vector3(high.x,high.y,high.z),tint)
	_face(st,Vector3(low.x,low.y,high.z),Vector3(low.x,low.y,low.z),
		Vector3(low.x,high.y,low.z),Vector3(low.x,high.y,high.z),tint)
	_face(st,Vector3(high.x,low.y,low.z),Vector3(high.x,low.y,high.z),
		Vector3(high.x,high.y,high.z),Vector3(high.x,high.y,low.z),tint)
	_face(st,Vector3(low.x,high.y,low.z),Vector3(high.x,high.y,low.z),
		Vector3(high.x,high.y,high.z),Vector3(low.x,high.y,high.z),tint)
	_face(st,Vector3(low.x,low.y,high.z),Vector3(high.x,low.y,high.z),
		Vector3(high.x,low.y,low.z),Vector3(low.x,low.y,low.z),tint)

static func support_mesh() -> ArrayMesh:
	# Original roadside metal pole, top cap and two genuine cantilever arms.
	# Signal faces stand OUTSIDE the existing 10m asphalt/road collider.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st,Vector3(0,1.95,0),Vector3(0.105,1.95,0.105),Color("697982"))
	_box(st,Vector3(-0.62,4.03,0),Vector3(0.67,0.082,0.085),Color("778891"))
	_box(st,Vector3(0,4.03,-0.62),Vector3(0.085,0.082,0.67),Color("778891"))
	_box(st,Vector3(0,3.96,0),Vector3(0.17,0.22,0.17),Color("303f49"))
	_box(st,Vector3(0,4.20,0),Vector3(0.145,0.045,0.145),Color("adb7ba"))
	st.generate_normals()
	return st.commit()

static func housing_mesh() -> ArrayMesh:
	# Original one-surface die-cast housing. Lens apertures are THREE real
	# faceted metal rolled rims and each has a physical sun hood lip.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st,Vector3.ZERO,Vector3(0.405,0.86,0.31),Color("101a22"))
	_box(st,Vector3(0,0.0,-0.32),Vector3(0.345,0.82,0.019),Color("27353e"))
	_box(st,Vector3(0,0.0,0.34),Vector3(0.30,0.59,0.08),Color("586875"))
	for y in [0.52,0.0,-0.52]:
		# Each physically rolled annular metal ring has a shaded bevel
		# and a cantilevered real visor, not a painted emissive square.
		for segment in range(16):
			var a: float = TAU*float(segment)/16.0
			var b: float = TAU*float(segment+1)/16.0
			var inner: float = 0.225
			var outer: float = 0.303
			var p0 := Vector3(cos(a)*inner,y+sin(a)*inner,-0.375)
			var p1 := Vector3(cos(b)*inner,y+sin(b)*inner,-0.375)
			var p2 := Vector3(cos(b)*outer,y+sin(b)*outer,-0.392)
			var p3 := Vector3(cos(a)*outer,y+sin(a)*outer,-0.392)
			_face(st,p0,p1,p2,p3,Color("8d9ca4"))
			if segment>=8:
				# One physical sunshade tube along the top-facing semicircle.
				var q0 := Vector3(cos(a)*outer,y+sin(a)*outer,-0.392)
				var q1 := Vector3(cos(b)*outer,y+sin(b)*outer,-0.392)
				var q2 := Vector3(cos(b)*outer,y+sin(b)*outer,-0.605)
				var q3 := Vector3(cos(a)*outer,y+sin(a)*outer,-0.605)
				_face(st,q0,q1,q2,q3,Color("293a44"))
	st.generate_normals()
	return st.commit()

static func convex_lens_mesh() -> ArrayMesh:
	# Painted luminous surface is REAL concave-profiled 3D geometry with
	# front-facing triangles and a small raised center (WebGL compatible).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0,0,-0.046)
	for segment in range(20):
		var a: float = TAU*float(segment)/20.0
		var b: float = TAU*float(segment+1)/20.0
		st.add_vertex(center)
		st.add_vertex(Vector3(cos(a)*0.214,sin(a)*0.214,0))
		st.add_vertex(Vector3(cos(b)*0.214,sin(b)*0.214,0))
	st.generate_normals()
	return st.commit()

static func _finish(color: Color,metallic: float,roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

func _make_batch(id: String,mesh: Mesh,poses: Array,finish: StandardMaterial3D) -> void:
	assert(poses.size()==INSTANCES_PER_DIRECTION)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = poses.size()
	for i in range(poses.size()):
		multimesh.set_instance_transform(i,poses[i])
	var draw := MultiMeshInstance3D.new()
	draw.name = "CityReignSignal_"+id
	draw.multimesh = multimesh
	draw.material_override = finish
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.custom_aabb = AABB(Vector3(-224,0,-224),Vector3(448,5.5,448))
	add_child(draw)
	batches[id] = draw
	finishes[id] = finish
	placements[id] = poses.duplicate()

func _ready() -> void:
	name = "CityReignOriginalSignalNetwork"
	var posts: Array = []
	var xheads: Array = []
	var zheads: Array = []
	var leds: Dictionary = {}
	for axis in DIRECTIONS:
		for color_id in COLOURS:
			leds[axis+"_"+color_id] = []
	for ix in INTERSECTIONS:
		for iz in INTERSECTIONS:
			var corner := Vector3(ix+7.5,0,iz+7.5)
			posts.append(Transform3D(Basis.IDENTITY,corner))
			for axis in DIRECTIONS:
				# The Z head faces arriving -Z drivers; the X head faces
				# arriving -X drivers, exactly as original AI distinguishes them.
				var rot := Basis(Vector3.UP,PI*0.5 if axis=="x" else 0.0)
				var offset := Vector3(0,4.03,-1.10) if axis=="x" else Vector3(-1.10,4.03,0)
				var position: Vector3 = corner+offset
				var head := Transform3D(rot,position)
				if axis=="x":
					xheads.append(head)
				else:
					zheads.append(head)
				for color_id in COLOURS:
					var local: Vector3 = Vector3(0,float(LED_HEIGHTS[color_id]),-0.425)
					leds[axis+"_"+color_id].append(Transform3D(rot,position+rot*local))
	var solid: ArrayMesh = support_mesh()
	var box: ArrayMesh = housing_mesh()
	var glass: ArrayMesh = convex_lens_mesh()
	var steel: StandardMaterial3D = _finish(Color.WHITE,0.77,0.38)
	steel.vertex_color_use_as_albedo = true
	var die_cast: StandardMaterial3D = _finish(Color.WHITE,0.26,0.48)
	die_cast.vertex_color_use_as_albedo = true
	_make_batch("post",solid,posts,steel)
	_make_batch("x_body",box,xheads,die_cast)
	_make_batch("z_body",box,zheads,die_cast)
	for axis in DIRECTIONS:
		for color_id in COLOURS:
			var material: StandardMaterial3D = _finish(DARK[color_id],0.03,0.23)
			material.emission_enabled = true
			material.emission = BRIGHT[color_id]
			material.emission_energy_multiplier = 0.0
			_make_batch(axis+"_"+color_id,glass,leds[axis+"_"+color_id],material)
	set_quality("standard")
	sync_phase(0,false)

func sync_phase(phase: int,is_warning: bool) -> void:
	# The SAME two-phase state as TrafficSignalGrid.permitted. Yellow
	# appears only in the last 1.5s of the current green direction, and
	# never changes route permission, route rewards or driver timing.
	last_phase = posmod(phase,2)
	warning = is_warning
	for axis in DIRECTIONS:
		var moving: bool = (axis=="x" and last_phase==0) or (axis=="z" and last_phase==1)
		for color_id in COLOURS:
			var on: bool = (color_id=="red" and not moving) or (
				color_id=="green" and moving and not is_warning) or (
				color_id=="amber" and moving and is_warning)
			var id: String = axis+"_"+color_id
			lamp_state[id] = on
			var mat: StandardMaterial3D = finishes[id]
			mat.albedo_color = BRIGHT[color_id] if on else DARK[color_id]
			mat.emission_energy_multiplier = ACTIVE_LED_RADIANCE if on else 0.0

func set_quality(tier: String) -> void:
	detail = tier if ["low","standard","cinematic"].has(tier) else "standard"
	visible = detail!="low"

func geometry_is_bounded() -> bool:
	if batches.size()!=MAX_BATCHES or get_child_count()!=MAX_BATCHES:
		return false
	if placements.size()!=MAX_BATCHES:
		return false
	var n: int = 0
	for id in batches:
		var draw: MultiMeshInstance3D = batches[id]
		if draw==null or draw.multimesh==null or draw.multimesh.instance_count!=16:
			return false
		if draw.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
		if placements[id].size()!=16:
			return false
		n += draw.multimesh.instance_count
	if n!=MAX_BATCHES*INSTANCES_PER_DIRECTION:
		return false
	if not find_children("*","CollisionShape3D",true,false).is_empty():
		return false
	return (batches["x_body"].multimesh.mesh is ArrayMesh and
		batches["x_red"].multimesh.mesh is ArrayMesh and
		batches["post"].multimesh.mesh is ArrayMesh)
