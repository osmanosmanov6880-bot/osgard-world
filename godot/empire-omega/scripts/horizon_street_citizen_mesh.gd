extends RefCounted
## R123: physically shaded, low-cost street pedestrians for the ORIGINAL city.
## One common 3D ArrayMesh draw surface per citizen; all four wardrobe colors
## and four authored limb poses are cached globally, not built every frame.
## Existing agents keep their routes, car-yield forecast, IDs and culling.
const STYLES: int = 4
const GAIT_FRAMES: int = 4
const HEAD_LONGITUDE: int = 10
const HEAD_LATITUDE: int = 6
static var _cached: Dictionary = {}
static var _material: StandardMaterial3D

static func shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color.WHITE
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.81
		_material.metallic = 0.035
		# Genuine two-sided faceted source, never a billboard/transparent quad.
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material

static func cached_meshes() -> int:
	return _cached.size()

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, tint: Color) -> void:
	st.set_color(tint)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, tint: Color) -> void:
	_triangle(st,a,b,c,tint)
	_triangle(st,a,c,d,tint)

static func _box(st: SurfaceTool, at: Vector3, half: Vector3, tint: Color) -> void:
	var x0: float = at.x-half.x
	var x1: float = at.x+half.x
	var y0: float = at.y-half.y
	var y1: float = at.y+half.y
	var z0: float = at.z-half.z
	var z1: float = at.z+half.z
	_quad(st,Vector3(x0,y0,z0),Vector3(x0,y1,z0),
		Vector3(x1,y1,z0),Vector3(x1,y0,z0),tint)
	_quad(st,Vector3(x1,y0,z1),Vector3(x1,y1,z1),
		Vector3(x0,y1,z1),Vector3(x0,y0,z1),tint)
	_quad(st,Vector3(x0,y0,z1),Vector3(x0,y1,z1),
		Vector3(x0,y1,z0),Vector3(x0,y0,z0),tint)
	_quad(st,Vector3(x1,y0,z0),Vector3(x1,y1,z0),
		Vector3(x1,y1,z1),Vector3(x1,y0,z1),tint)
	_quad(st,Vector3(x0,y1,z0),Vector3(x0,y1,z1),
		Vector3(x1,y1,z1),Vector3(x1,y1,z0),tint)
	_quad(st,Vector3(x0,y0,z1),Vector3(x0,y0,z0),
		Vector3(x1,y0,z0),Vector3(x1,y0,z1),tint)

static func _taper(st: SurfaceTool, bottom: Vector3, top: Vector3,
		base_size: Vector2, tip_size: Vector2, tint: Color) -> void:
	var a := Vector3(bottom.x-base_size.x,bottom.y,bottom.z-base_size.y)
	var b := Vector3(bottom.x+base_size.x,bottom.y,bottom.z-base_size.y)
	var c := Vector3(bottom.x+base_size.x,bottom.y,bottom.z+base_size.y)
	var d := Vector3(bottom.x-base_size.x,bottom.y,bottom.z+base_size.y)
	var e := Vector3(top.x-tip_size.x,top.y,top.z-tip_size.y)
	var f := Vector3(top.x+tip_size.x,top.y,top.z-tip_size.y)
	var g := Vector3(top.x+tip_size.x,top.y,top.z+tip_size.y)
	var h := Vector3(top.x-tip_size.x,top.y,top.z+tip_size.y)
	_quad(st,a,e,f,b,tint)
	_quad(st,c,g,h,d,tint)
	_quad(st,d,h,e,a,tint)
	_quad(st,b,f,g,c,tint)
	_quad(st,e,h,g,f,tint)
	_quad(st,d,a,b,c,tint)

static func _head_point(center: Vector3, theta: float, azimuth: float,
		width: float, height: float, depth: float) -> Vector3:
	return center + Vector3(
		sin(theta)*cos(azimuth)*width,
		cos(theta)*height,
		sin(theta)*sin(azimuth)*depth)

static func _head(st: SurfaceTool, skin: Color, hair: Color) -> void:
	var centre := Vector3(0.0,0.60,0.0)
	var width: float = 0.19
	var height: float = 0.225
	var depth: float = 0.185
	for lat in range(HEAD_LATITUDE):
		var t0: float = PI*float(lat)/float(HEAD_LATITUDE)
		var t1: float = PI*float(lat+1)/float(HEAD_LATITUDE)
		for longitude in range(HEAD_LONGITUDE):
			var p0: float = TAU*float(longitude)/float(HEAD_LONGITUDE)
			var p1: float = TAU*float(longitude+1)/float(HEAD_LONGITUDE)
			var a: Vector3 = _head_point(centre,t0,p0,width,height,depth)
			var b: Vector3 = _head_point(centre,t0,p1,width,height,depth)
			var c: Vector3 = _head_point(centre,t1,p0,width,height,depth)
			var d: Vector3 = _head_point(centre,t1,p1,width,height,depth)
			var tint: Color = hair if lat==0 else skin
			if lat==0:
				_triangle(st,a,d,c,tint)
			elif lat==HEAD_LATITUDE-1:
				_triangle(st,a,b,c,tint)
			else:
				_triangle(st,a,b,c,tint)
				_triangle(st,b,d,c,tint)
	# One short fringe over the face and raised, shaded brow.
	_box(st,Vector3(0.0,0.766,-0.122),Vector3(0.155,0.032,0.081),hair)
	for side in [-1.0,1.0]:
		_box(st,Vector3(float(side)*0.069,0.646,-0.185),
			Vector3(0.018,0.016,0.013),Color("283038"))

static func mesh_for(citizen_id: int, gait_frame: int = 0) -> ArrayMesh:
	var style: int = posmod(citizen_id,STYLES)
	var frame: int = posmod(gait_frame,GAIT_FRAMES)
	var key: int = style*GAIT_FRAMES+frame
	if _cached.has(key):
		return _cached[key]
	var coats: Array[Color] = [
		Color("33495c"),Color("675249"),Color("4b5c50"),Color("606674")
	]
	var pants: Array[Color] = [
		Color("252e36"),Color("3c3532"),Color("293b37"),Color("303743")
	]
	var skins: Array[Color] = [
		Color("d3aa88"),Color("af8064"),Color("deb796"),Color("b58e74")
	]
	var jacket: Color = coats[style]
	var trousers: Color = pants[style]
	var skin: Color = skins[style]
	var hair: Color = Color("242b30") if style%2==0 else Color("40352f")
	var stride: float = sin(float(frame)*PI*0.5)*0.16
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Feet are at y=-0.88..-0.70 relative to original y=+0.90 anchor.
	# Coat tapers at the waist, giving a human rather than capsule outline.
	_taper(surface,Vector3(0.0,-0.11,0.005),Vector3(0.0,0.42,0.0),
		Vector2(0.24,0.18),Vector2(0.31,0.20),jacket)
	_box(surface,Vector3(0.0,-0.11,0.0),
		Vector3(0.246,0.042,0.198),jacket.darkened(0.18))
	_box(surface,Vector3(0.0,0.398,-0.195),
		Vector3(0.18,0.045,0.030),Color("a6aca9"))
	_taper(surface,Vector3(0.0,0.42,0.0),Vector3(0.0,0.514,0.0),
		Vector2(0.108,0.103),Vector2(0.096,0.098),skin)
	for side in [-1.0,1.0]:
		var sign_side: float = float(side)
		var foot_step: float = -stride*sign_side
		var leg_x: float = sign_side*0.145
		_taper(surface,Vector3(leg_x,-0.714,foot_step),
			Vector3(leg_x,-0.10,0.0),Vector2(0.113,0.12),
			Vector2(0.137,0.144),trousers)
		_box(surface,Vector3(leg_x,-0.786,foot_step-0.046),
			Vector3(0.133,0.095,0.218),Color("1b232a"))
		var arm_x: float = sign_side*0.390
		_taper(surface,Vector3(arm_x,-0.146,-foot_step*0.77),
			Vector3(arm_x,0.365,0.0),Vector2(0.103,0.106),
			Vector2(0.132,0.132),jacket.darkened(0.05))
		_box(surface,Vector3(arm_x,-0.198,-foot_step*0.77),
			Vector3(0.088,0.071,0.089),skin)
	_head(surface,skin,hair)
	# Collar/shirt detail is real geometry inside the original single surface.
	_box(surface,Vector3(0.0,0.354,-0.209),
		Vector3(0.077,0.125,0.024),Color("c6cbc7"))
	surface.generate_normals()
	var result: ArrayMesh = surface.commit()
	_cached[key] = result
	return result

static func triangle_budget() -> int:
	# Return exactly the actual shared, native material surface geometry.
	return int(mesh_for(0,0).surface_get_array_len(0)/3)
