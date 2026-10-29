extends RefCounted
## CITY REIGN R167 | original one-batch premium exterior sculpt detail.
## Source-authored PBR polygons ONLY: not a texture, decal, screenshot or
## unlicensed real-world car asset. All original car geometry stays bounded.
## One cached bodywork Mesh, one cached physical optical Mesh; no per-frame
## draw creation, shadow maps, point lights, collisions or gameplay mutation.
static var _body_mesh: ArrayMesh
static var _light_mesh: ArrayMesh
const MAX_BODY_VERTICES: int = 1800
const MAX_LIGHT_VERTICES: int = 240

static func _face(surface: SurfaceTool,a: Vector3,b: Vector3,
		c: Vector3,d: Vector3,tint: Color) -> void:
	var verts: Array[Vector3] = [a,b,c,a,c,d]
	var uvs: Array[Vector2] = [Vector2.ZERO,Vector2(1,0),Vector2.ONE,
		Vector2.ZERO,Vector2.ONE,Vector2(0,1)]
	for i in range(verts.size()):
		surface.set_color(tint)
		surface.set_uv(uvs[i])
		surface.add_vertex(verts[i])

static func _block(s: SurfaceTool,centre: Vector3,half: Vector3,tint: Color) -> void:
	var lo: Vector3 = centre-half
	var hi: Vector3 = centre+half
	_face(s,Vector3(lo.x,lo.y,lo.z),Vector3(hi.x,lo.y,lo.z),
		Vector3(hi.x,hi.y,lo.z),Vector3(lo.x,hi.y,lo.z),tint)
	_face(s,Vector3(hi.x,lo.y,hi.z),Vector3(lo.x,lo.y,hi.z),
		Vector3(lo.x,hi.y,hi.z),Vector3(hi.x,hi.y,hi.z),tint)
	_face(s,Vector3(lo.x,lo.y,hi.z),Vector3(lo.x,lo.y,lo.z),
		Vector3(lo.x,hi.y,lo.z),Vector3(lo.x,hi.y,hi.z),tint)
	_face(s,Vector3(hi.x,lo.y,lo.z),Vector3(hi.x,lo.y,hi.z),
		Vector3(hi.x,hi.y,hi.z),Vector3(hi.x,hi.y,lo.z),tint)
	_face(s,Vector3(lo.x,hi.y,lo.z),Vector3(hi.x,hi.y,lo.z),
		Vector3(hi.x,hi.y,hi.z),Vector3(lo.x,hi.y,hi.z),tint)
	_face(s,Vector3(lo.x,lo.y,hi.z),Vector3(hi.x,lo.y,hi.z),
		Vector3(hi.x,lo.y,lo.z),Vector3(lo.x,lo.y,lo.z),tint)

static func body_mesh() -> ArrayMesh:
	if _body_mesh!=null: return _body_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# Source-shaped, recessed front cooling aperture / carbon lower splitters.
	# Tiny alpha-free dark metal facets read correctly in Godot WebGL.
	_block(st,Vector3(0,-0.443,-2.674),Vector3(0.525,0.100,0.012),Color("0c161b"))
	_block(st,Vector3(0,-0.544,-2.682),Vector3(0.568,0.011,0.009),Color("71858b"))
	for rib in range(7):
		var x: float = -0.420+float(rib)*0.140
		_block(st,Vector3(x,-0.438,-2.690),Vector3(0.009,0.080,0.006),Color("53646b"))
	for side in [-1.0,1.0]:
		var sign_side: float = side
		# Two actual intake mouths to either side of the centre grille.
		_block(st,Vector3(sign_side*0.836,-0.454,-2.671),
			Vector3(0.190,0.074,0.011),Color("10191e"))
		for vane in range(3):
			var x: float = sign_side*(0.740+float(vane)*0.092)
			_block(st,Vector3(x,-0.453,-2.687),
				Vector3(0.010,0.055,0.005),Color("6a7a80"))
		# Long tapered hood pinstripes, actually joined as source triangles.
		# Their limits stay below the original tire/panel envelope.
		var hood0: Vector3 = Vector3(sign_side*0.705,-0.067,-1.515)
		var hood1: Vector3 = Vector3(sign_side*0.793,-0.196,-2.369)
		var offset: Vector3 = Vector3(sign_side*0.010,0.001,0.0)
		_face(st,hood0-offset,hood0+offset,hood1+offset,hood1-offset,
			Color("6e848d"))
		# Two subtle rear vertical vent lines on the original source bumper.
		_block(st,Vector3(sign_side*0.89,-0.397,2.653),
			Vector3(0.042,0.108,0.011),Color("162328"))
		_block(st,Vector3(sign_side*0.88,-0.391,2.670),
			Vector3(0.011,0.075,0.004),Color("8ca0aa"))
	# Original six-blade diffuser reflection highlights, ONE mesh batch.
	for vane in range(6):
		var x: float = -0.94+float(vane)*0.376
		_block(st,Vector3(x,-0.583,2.676),
			Vector3(0.012,0.055,0.008),Color("55636a"))
	st.generate_normals()
	st.generate_tangents()
	_body_mesh = st.commit()
	return _body_mesh

static func light_mesh() -> ArrayMesh:
	if _light_mesh!=null: return _light_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# Three authentic geometric forward LED bands replace one crude BoxMesh,
	# INSIDE each exact original LeftLED/RightLED node and draw/material.
	_block(st,Vector3(0.00,0.043,-0.010),
		Vector3(0.356,0.012,0.016),Color("d7f2ff"))
	_block(st,Vector3(-0.037,-0.021,-0.012),
		Vector3(0.269,0.010,0.013),Color("e0f5ff"))
	_block(st,Vector3(0.295,-0.004,-0.014),
		Vector3(0.031,0.043,0.012),Color("b8e4ff"))
	st.generate_normals()
	_light_mesh = st.commit()
	return _light_mesh

static func build() -> MeshInstance3D:
	var object := MeshInstance3D.new()
	object.name="R167PrecisionAeroSurface"
	object.mesh=body_mesh()
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color.WHITE
	material.vertex_color_use_as_albedo=true
	material.metallic=0.42
	material.roughness=0.36
	material.clearcoat_enabled=true
	material.clearcoat=0.38
	material.clearcoat_roughness=0.26
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	object.material_override=material
	object.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return object

static func bounded() -> bool:
	if body_mesh().get_surface_count()!=1 or light_mesh().get_surface_count()!=1:
		return false
	if body_mesh().surface_get_array_len(0)>MAX_BODY_VERTICES:
		return false
	if light_mesh().surface_get_array_len(0)>MAX_LIGHT_VERTICES:
		return false
	var aabb: AABB=body_mesh().get_aabb()
	return aabb.position.is_finite() and aabb.size.is_finite() and (
		aabb.size.x<2.4 and aabb.size.y<0.7 and aabb.size.z<5.5)
