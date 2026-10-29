extends RefCounted
## OSGARD HORIZON R4: original sports-coupe surface built from longitudinal
## cross-sections, not stacked primitive cubes. All coordinates are in metres.
## This is an original stylized mesh, not a licensed production car model.

# Vector4(z_position, half_width, upper_surface_height, lower_surface_height).
const BODY_PROFILE = [
	Vector4(-2.64,1.00,-0.30,-0.62),
	Vector4(-2.46,1.17,-0.20,-0.69),
	Vector4(-2.13,1.28,-0.11,-0.70),
	Vector4(-1.62,1.30,-0.10,-0.70),
	Vector4(-1.25,1.27,-0.11,-0.69),
	Vector4(-0.60,1.25,-0.17,-0.68),
	Vector4(0.15,1.27,-0.17,-0.69),
	Vector4(0.90,1.27,-0.12,-0.70),
	Vector4(1.65,1.30,-0.10,-0.69),
	Vector4(2.18,1.26,-0.18,-0.68),
	Vector4(2.52,1.17,-0.27,-0.63),
	Vector4(2.64,1.00,-0.33,-0.61)
]

const CANOPY_PROFILE = [
	Vector4(-1.28,0.95,0.09,-0.13),
	Vector4(-1.02,0.99,0.36,-0.14),
	Vector4(-0.72,0.93,0.72,-0.15),
	Vector4(-0.48,0.90,0.82,-0.15),
	Vector4(0.45,0.90,0.81,-0.15),
	Vector4(0.76,0.94,0.67,-0.15),
	Vector4(1.13,0.98,0.15,-0.16)
]

# Winding visits top centre -> left shoulder -> left side -> underside
# -> right side -> right shoulder -> top centre.
const RING = [
	Vector2(0.0,1.0),Vector2(-0.55,0.98),
	Vector2(-0.84,0.96),Vector2(-0.98,0.78),
	Vector2(-1.0,0.24),Vector2(-0.89,0.09),
	Vector2(-0.56,0.015),Vector2(0.0,0.0),
	Vector2(0.56,0.015),Vector2(0.89,0.09),
	Vector2(1.0,0.24),Vector2(0.98,0.78),
	Vector2(0.84,0.96),Vector2(0.55,0.98)
]

# R167: authored, bounded Hermite longitudinal panel smoothing. The
# SAME one-surface MeshInstance is kept for original garage and gameplay.
# Each source cross section remains within its original bounds to prevent
# wheel/collider overlap and roof changes from modifying physical authority.
const PROFILE_SUBDIVISIONS: int = 3
const MAX_VERTEX_BUDGET: int = 3400

static func _bounded_section(profile: Array,segment: int,t: float) -> Vector4:
	var first: Vector4 = profile[segment]
	var last: Vector4 = profile[segment+1]
	if t<=0.0: return first
	if t>=1.0: return last
	var prev: Vector4 = profile[maxi(segment-1,0)]
	var next: Vector4 = profile[mini(segment+2,sections.size()-1)]
	var m0: Vector4 = (last-prev)*0.5
	var m1: Vector4 = (next-first)*0.5
	var t2: float = t*t
	var t3: float = t2*t
	var smooth: Vector4 = first*(2.0*t3-3.0*t2+1.0)+m0*(t3-2.0*t2+t)+last*(-2.0*t3+3.0*t2)+m1*(t3-t2)
	return Vector4(
		clampf(smooth.x,minf(first.x,last.x),maxf(first.x,last.x)),
		clampf(smooth.y,minf(first.y,last.y),maxf(first.y,last.y)),
		clampf(smooth.z,minf(first.z,last.z),maxf(first.z,last.z)),
		clampf(smooth.w,minf(first.w,last.w),maxf(first.w,last.w)))

static func refined_profile(profile: Array,steps: int = PROFILE_SUBDIVISIONS) -> Array[Vector4]:
	var result: Array[Vector4] = []
	if profile.size()<2: return result
	var bounded_steps: int = clampi(steps,1,PROFILE_SUBDIVISIONS)
	for segment in range(profile.size()-1):
		for sub in range(bounded_steps):
			result.append(_bounded_section(profile,segment,float(sub)/float(bounded_steps)))
	result.append(profile[profile.size()-1])
	return result

static func _point(section: Vector4, ring_index: int) -> Vector3:
	var contour: Vector2 = RING[ring_index]
	var half_width: float = section.y
	var deck: float = section.z
	var bottom: float = section.w
	# Slight centre crown catches reflections without making another box.
	var crowning: float = 0.045*(1.0-absf(contour.x))
	return Vector3(contour.x*half_width,lerpf(bottom,deck,contour.y)+crowning,section.x)

static func _vertex(st: SurfaceTool, at: Vector3, uv: Vector2) -> void:
	st.set_uv(uv)
	st.add_vertex(at)

static func sculpt(name: String, profile: Array, finish: Material,
		steps: int = PROFILE_SUBDIVISIONS) -> MeshInstance3D:
	var sections: Array[Vector4] = refined_profile(profile,steps)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var count: int = RING.size()
	for row in range(sections.size()-1):
		for segment in range(count):
			var next: int = (segment+1)%count
			var a: Vector3 = _point(sections[row],segment)
			var b: Vector3 = _point(sections[row],next)
			var c: Vector3 = _point(sections[row+1],segment)
			var d: Vector3 = _point(sections[row+1],next)
			var u0: float = float(segment)/float(count)
			var u1: float = float(segment+1)/float(count)
			var v0: float = float(row)/float(sections.size()-1)
			var v1: float = float(row+1)/float(sections.size()-1)
			_vertex(st,a,Vector2(u0,v0))
			_vertex(st,b,Vector2(u1,v0))
			_vertex(st,c,Vector2(u0,v1))
			_vertex(st,b,Vector2(u1,v0))
			_vertex(st,d,Vector2(u1,v1))
			_vertex(st,c,Vector2(u0,v1))
	# Close both ends so the sports car is solid when viewed from the road.
	for cap_index in [0,sections.size()-1]:
		var end: Vector4 = sections[cap_index]
		var mid := Vector3(0.0,(end.z+end.w)*0.5,end.x)
		for index in range(count):
			var following: int = (index+1)%count
			if cap_index == 0:
				_vertex(st,mid,Vector2(0.5,0.5))
				_vertex(st,_point(end,index),Vector2(0,0))
				_vertex(st,_point(end,following),Vector2(1,0))
			else:
				_vertex(st,mid,Vector2(0.5,0.5))
				_vertex(st,_point(end,following),Vector2(1,0))
				_vertex(st,_point(end,index),Vector2(0,0))
	# Smooth cross-sections have stable normals and generated tangents for
	# original PBR clearcoat; the physical car and its collision do not change.
	st.generate_normals()
	st.generate_tangents()
	var visual := MeshInstance3D.new()
	visual.name = name
	visual.mesh = st.commit()
	visual.material_override = finish
	return visual

static func profile_bounds(profile: Array) -> AABB:
	var minimum := Vector3(INF,INF,INF)
	var maximum := Vector3(-INF,-INF,-INF)
	for section in profile:
		for index in range(RING.size()):
			var vertex: Vector3 = _point(section,index)
			minimum = minimum.min(vertex)
			maximum = maximum.max(vertex)
	return AABB(minimum,maximum-minimum)
