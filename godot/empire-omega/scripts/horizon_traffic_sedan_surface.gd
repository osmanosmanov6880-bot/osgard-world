extends RefCounted
## EMPIRE OMEGA R126: original real 3D AI/patrol sedan surfaces, NOT stock photos.
## Replaces only TWO original rigid body/cabin BoxMeshes and the four boxes
## shaped as wheels. Retains exactly original SIX traffic draw nodes per car,
## original physical CharacterBody3D collider and deterministic routes.
## All source meshes are cached across the full 12-car urban fleet + patrol.
const RING = [
	Vector2(0.0,1.0),Vector2(-0.54,1.0),Vector2(-0.82,0.94),
	Vector2(-0.98,0.78),Vector2(-1.0,0.24),Vector2(-0.84,0.09),
	Vector2(-0.50,0.015),Vector2(0.0,0.0),
	Vector2(0.50,0.015),Vector2(0.84,0.09),
	Vector2(1.0,0.24),Vector2(0.98,0.78),
	Vector2(0.82,0.94),Vector2(0.54,1.0)
]
# Coordinates are LOCAL TO ORIGINAL CarBody (.35m offset):
# 4.05m long, 2.25m max width, 0.05..0.8m real world vertical chassis.
const BODY = [
	Vector4(-2.025,0.72,0.14,-0.29),
	Vector4(-1.90,0.98,0.32,-0.35),
	Vector4(-1.50,1.08,0.39,-0.37),
	Vector4(-1.12,1.105,0.38,-0.36),
	Vector4(-0.54,1.095,0.31,-0.36),
	Vector4(0.35,1.095,0.29,-0.37),
	Vector4(1.20,1.105,0.33,-0.36),
	Vector4(1.70,1.02,0.32,-0.35),
	Vector4(2.025,0.74,0.11,-0.30)
]
# Physically sloped panoramic windshield and rear glass. LOCAL TO CABIN
# original y=.98; side glass and roof are colored regions of ONE mesh.
const CABIN = [
	Vector4(-1.14,0.77,-0.22,-0.34),
	Vector4(-0.88,0.84,0.22,-0.30),
	Vector4(-0.49,0.83,0.37,-0.30),
	Vector4(0.25,0.82,0.38,-0.30),
	Vector4(0.71,0.81,0.31,-0.31),
	Vector4(1.12,0.72,-0.22,-0.32)
]
const WHEEL_SEGMENTS: int = 16
static var _body: ArrayMesh
static var _cabin: ArrayMesh
static var _wheel: ArrayMesh
static var _wheel_finish: StandardMaterial3D
# A5: four recognizable urban silhouettes share only 2 source surfaces
# per vehicle, without adding new MeshInstance3D or changing the collider.
const VISUAL_STYLES = ["sedan","taxi","courier","executive"]
static var _body_variants: Dictionary = {}
static var _cabin_variants: Dictionary = {}

static func _point(profile: Vector4, index: int) -> Vector3:
	var uv: Vector2 = RING[index]
	var dome: float = 0.019*(1.0-absf(uv.x))
	return Vector3(profile.y*uv.x,lerpf(profile.w,profile.z,uv.y)+dome,profile.x)

static func _tri(st: SurfaceTool, a: Vector3,b: Vector3,c: Vector3,tint: Color) -> void:
	st.set_color(tint)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,tint: Color) -> void:
	_tri(st,a,b,c,tint)
	_tri(st,a,c,d,tint)

static func _box(st: SurfaceTool,centre: Vector3,half: Vector3,tint: Color) -> void:
	var x0: float=centre.x-half.x
	var x1: float=centre.x+half.x
	var y0: float=centre.y-half.y
	var y1: float=centre.y+half.y
	var z0: float=centre.z-half.z
	var z1: float=centre.z+half.z
	_quad(st,Vector3(x0,y0,z0),Vector3(x1,y0,z0),Vector3(x1,y1,z0),Vector3(x0,y1,z0),tint)
	_quad(st,Vector3(x1,y0,z1),Vector3(x0,y0,z1),Vector3(x0,y1,z1),Vector3(x1,y1,z1),tint)
	_quad(st,Vector3(x0,y0,z1),Vector3(x0,y0,z0),Vector3(x0,y1,z0),Vector3(x0,y1,z1),tint)
	_quad(st,Vector3(x1,y0,z0),Vector3(x1,y0,z1),Vector3(x1,y1,z1),Vector3(x1,y1,z0),tint)
	_quad(st,Vector3(x0,y1,z0),Vector3(x1,y1,z0),Vector3(x1,y1,z1),Vector3(x0,y1,z1),tint)
	_quad(st,Vector3(x0,y0,z1),Vector3(x1,y0,z1),Vector3(x1,y0,z0),Vector3(x0,y0,z0),tint)

# Extra real 3D detail is fused INTO the original closed body or cabin
# mesh. No billboard, texture generated image or extra per-car draw calls.
static func _city_reign_detail(st: SurfaceTool, kind: String, is_cabin: bool) -> void:
	match kind:
		"taxi":
			if is_cabin:
				# Glowing billboard ads are intentionally rejected; this is a
				# physically shaded three-dimensional municipal taxi roof lamp.
				_box(st,Vector3(0.0,0.50,-0.16),
					Vector3(0.34,0.11,0.23),Color("d8bf80"))
				_box(st,Vector3(0.0,0.39,-0.16),
					Vector3(0.43,0.035,0.27),Color("1e313b"))
			else:
				# A beltline color block, one actual colored mesh surface.
				for side in [-1.0,1.0]:
					_box(st,Vector3(float(side)*1.099,0.075,0.20),
						Vector3(0.013,0.070,1.13),Color("d8b975"))
		"courier":
			if is_cabin:
				# An authored luggage/service roof pod with twin metal rails,
				# lower than overhead city geometry and above cabin glass.
				_box(st,Vector3(0.0,0.51,0.15),
					Vector3(0.70,0.13,0.78),Color("546f7a"))
				for side in [-1.0,1.0]:
					_box(st,Vector3(float(side)*0.73,0.50,0.15),
						Vector3(0.034,0.13,0.83),Color("a9b7b5"))
			else:
				# Real rear freight bumper with a recessed center step.
				_box(st,Vector3(0.0,-0.24,2.045),
					Vector3(0.68,0.065,0.048),Color("667e86"))
				_box(st,Vector3(0.0,-0.16,2.095),
					Vector3(0.35,0.027,0.023),Color("263d49"))
		"executive":
			if is_cabin:
				# Satin roof perimeter and real dark panoramic glass.
				_box(st,Vector3(0.0,0.412,0.08),
					Vector3(0.44,0.011,0.43),Color("1c333d"))
				for side in [-1.0,1.0]:
					_box(st,Vector3(float(side)*0.69,0.402,0.07),
						Vector3(0.025,0.017,0.76),Color("c0c3b7"))
			else:
				for x in [-0.46,0.0,0.46]:
					_box(st,Vector3(float(x),-0.035,-2.058),
						Vector3(0.12,0.098,0.019),Color("879ba3"))
				for side in [-1.0,1.0]:
					_box(st,Vector3(float(side)*1.106,-0.055,0.13),
						Vector3(0.014,0.033,1.15),Color("adb5b3"))

static func _sculpt(profile: Array, is_cabin: bool, kind: String = "sedan") -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int=RING.size()
	for layer in range(profile.size()-1):
		for index in range(count):
			var next: int=(index+1)%count
			var a: Vector3=_point(profile[layer],index)
			var b: Vector3=_point(profile[layer],next)
			var c: Vector3=_point(profile[layer+1],index)
			var d: Vector3=_point(profile[layer+1],next)
			var tint: Color=Color(0.88,0.90,0.93,1.0)
			if is_cabin:
				# Colored actual physical glass on side/windshield, steel roof in
				# same original Cabin draw pass. No transparent sorting artifacts.
				tint=Color(0.20,0.33,0.40) if index>=3 and index<=10 else Color(0.67,0.73,0.77)
				if layer==0 or layer==profile.size()-2:
					tint=Color(0.17,0.30,0.39)
			elif index==0 or index==count-1:
				tint=Color(0.80,0.86,0.87)
			else:
				var shade: float=0.82+float((layer+index)%3)*0.06
				tint=Color(shade,shade,shade*1.02)
			_tri(st,a,b,c,tint)
			_tri(st,b,d,c,tint)
	# Close both ends so cars are authentic CLOSED volumetric 3D.
	for cap in [0,profile.size()-1]:
		var p: Vector4=profile[cap]
		var mid:=Vector3(0.0,(p.z+p.w)*0.5,p.x)
		for index in range(count):
			var next: int=(index+1)%count
			if cap==0:
				_tri(st,mid,_point(p,index),_point(p,next),Color(0.28,0.32,0.37))
			else:
				_tri(st,mid,_point(p,next),_point(p,index),Color(0.32,0.34,0.37))
	if is_cabin:
		# Both side mirrors and slim metallic A-pillar hardware are geometry
		# in the ORIGINAL Cabin draw, not per-car side mirror nodes.
		for side in [-1.0,1.0]:
			var sign_side: float=float(side)
			_box(st,Vector3(sign_side*0.95,-0.03,-0.80),
				Vector3(0.115,0.090,0.16),Color(0.31,0.38,0.42))
			_box(st,Vector3(sign_side*0.837,0.025,-0.75),
				Vector3(0.020,0.22,0.035),Color(0.60,0.66,0.70))
	else:
		# Dark recessed frontal grille and rear real metal trim on same mesh.
		_box(st,Vector3(0.0,-0.03,-2.024),
			Vector3(0.65,0.095,0.014),Color(0.16,0.21,0.24))
		_box(st,Vector3(0.0,0.12,2.024),
			Vector3(0.76,0.036,0.012),Color(0.57,0.64,0.68))
	if kind != "sedan":
		_city_reign_detail(st,kind,is_cabin)
	st.generate_normals()
	return st.commit()

static func body_mesh() -> ArrayMesh:
	if _body==null:
		_body=_sculpt(BODY,false)
	return _body

static func cabin_mesh() -> ArrayMesh:
	if _cabin==null:
		_cabin=_sculpt(CABIN,true)
	return _cabin

static func _valid_style(style: String) -> String:
	return style if VISUAL_STYLES.has(style) else "sedan"

static func body_mesh_for(style: String) -> ArrayMesh:
	var normalized: String = _valid_style(style)
	if normalized == "sedan":
		return body_mesh()
	if not _body_variants.has(normalized):
		_body_variants[normalized] = _sculpt(BODY,false,normalized)
	return _body_variants[normalized]

static func cabin_mesh_for(style: String) -> ArrayMesh:
	var normalized: String = _valid_style(style)
	if normalized == "sedan":
		return cabin_mesh()
	if not _cabin_variants.has(normalized):
		_cabin_variants[normalized] = _sculpt(CABIN,true,normalized)
	return _cabin_variants[normalized]

static func total_cached_variant_meshes() -> int:
	return _body_variants.size()+_cabin_variants.size()

static func _wheel_vertex(angle: float, x: float, radius: float) -> Vector3:
	return Vector3(x,cos(angle)*radius,sin(angle)*radius)

static func wheel_mesh() -> ArrayMesh:
	if _wheel!=null:
		return _wheel
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rubber:=Color(0.09,0.11,0.13)
	var wall:=Color(0.16,0.18,0.20)
	var alloy:=Color(0.67,0.73,0.77)
	var hub:=Color(0.32,0.40,0.45)
	for i in range(WHEEL_SEGMENTS):
		var angle0: float=TAU*float(i)/float(WHEEL_SEGMENTS)
		var angle1: float=TAU*float(i+1)/float(WHEEL_SEGMENTS)
		# Physically circular tyre tread, with axle along LOCAL X. Therefore
		# original wheel.rotate_x(travelled/0.34) spins the actual round tyre.
		_quad(st,_wheel_vertex(angle0,-0.15,0.34),_wheel_vertex(angle1,-0.15,0.34),
			_wheel_vertex(angle1,0.15,0.34),_wheel_vertex(angle0,0.15,0.34),rubber)
		for side in [-1.0,1.0]:
			var x: float=0.15*float(side)
			_quad(st,_wheel_vertex(angle0,x,0.34),_wheel_vertex(angle1,x,0.34),
				_wheel_vertex(angle1,x,0.235),_wheel_vertex(angle0,x,0.235),wall)
			_quad(st,_wheel_vertex(angle0,x+0.003*float(side),0.235),
				_wheel_vertex(angle1,x+0.003*float(side),0.235),
				_wheel_vertex(angle1,x+0.003*float(side),0.11),
				_wheel_vertex(angle0,x+0.003*float(side),0.11),alloy)
			_tri(st,_wheel_vertex(angle0,x+0.005*float(side),0.11),
				_wheel_vertex(angle1,x+0.005*float(side),0.11),
				Vector3(x+0.005*float(side),0.0,0.0),hub)
	st.generate_normals()
	_wheel=st.commit()
	return _wheel

static func wheel_finish() -> StandardMaterial3D:
	if _wheel_finish==null:
		_wheel_finish=StandardMaterial3D.new()
		_wheel_finish.albedo_color=Color.WHITE
		_wheel_finish.vertex_color_use_as_albedo=true
		_wheel_finish.metallic=0.31
		_wheel_finish.roughness=0.62
		_wheel_finish.cull_mode=BaseMaterial3D.CULL_DISABLED
	return _wheel_finish

static func vertex_budget() -> Dictionary:
	return {"body":body_mesh().surface_get_array_len(0),
		"cabin":cabin_mesh().surface_get_array_len(0),
		"wheel":wheel_mesh().surface_get_array_len(0)}
