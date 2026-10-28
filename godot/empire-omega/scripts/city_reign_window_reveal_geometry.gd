extends RefCounted
## CITY REIGN B54 — physically hollow, shaded aluminium 3D window surrounds.
## Replaces only the shared mesh resource INSIDE original window-frame GPU
## MultiMesh. Every 3D window remains one original transform and original
## one-per-family draw batch. The existing glass is not replaced or obscured.
const MAX_VERTICES: int = 180
static var _cinematic: ArrayMesh

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	var normal: Vector3 = (b-a).cross(c-a).normalized()
	for vertex in [a,b,c,a,c,d]:
		st.set_normal(normal)
		st.add_vertex(vertex)

static func _box(st: SurfaceTool,minimum: Vector3,maximum: Vector3) -> void:
	var p: Array[Vector3] = [
		Vector3(minimum.x,minimum.y,minimum.z),
		Vector3(maximum.x,minimum.y,minimum.z),
		Vector3(maximum.x,minimum.y,maximum.z),
		Vector3(minimum.x,minimum.y,maximum.z),
		Vector3(minimum.x,maximum.y,minimum.z),
		Vector3(maximum.x,maximum.y,minimum.z),
		Vector3(maximum.x,maximum.y,maximum.z),
		Vector3(minimum.x,maximum.y,maximum.z)
	]
	_quad(st,p[0],p[1],p[2],p[3])
	_quad(st,p[4],p[7],p[6],p[5])
	_quad(st,p[0],p[4],p[5],p[1])
	_quad(st,p[1],p[5],p[6],p[2])
	_quad(st,p[2],p[6],p[7],p[3])
	_quad(st,p[3],p[7],p[4],p[0])

static func cinematic_mesh() -> ArrayMesh:
	if _cinematic!=null:
		return _cinematic
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# This rectangular *HOLE* leaves original 1.05 x 1.38m glass visible.
	# A solid BoxMesh gave every window the appearance of a metal slab
	# and can cover the existing dark-glass shader on narrow camera angles.
	_box(st,Vector3(-0.635,-0.80,-0.063),
		Vector3(-0.530,0.80,0.058))
	_box(st,Vector3(0.530,-0.80,-0.063),
		Vector3(0.635,0.80,0.058))
	_box(st,Vector3(-0.530,-0.80,-0.063),
		Vector3(0.530,-0.686,0.058))
	_box(st,Vector3(-0.530,0.686,-0.063),
		Vector3(0.530,0.80,0.058))
	# Source-native low-profile projecting sill, 0.08m below the glass;
	# no per-window scene object or high-cost transparency sorting.
	_box(st,Vector3(-0.695,-0.852,-0.17),
		Vector3(0.695,-0.782,0.058))
	_cinematic = st.commit()
	assert(_cinematic.surface_get_array_len(0)==MAX_VERTICES)
	return _cinematic

static func geometry_is_real_and_bounded(mesh: Mesh) -> bool:
	if not (mesh is ArrayMesh) or mesh.get_surface_count()!=1:
		return false
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if vertices.size()!=MAX_VERTICES or normals.size()!=MAX_VERTICES:
		return false
	var y_min: float = INF
	var z_min: float = INF
	for i in range(vertices.size()):
		var v: Vector3 = vertices[i]
		var n: Vector3 = normals[i]
		if not v.is_finite() or not n.is_finite() or absf(n.length()-1.0)>0.03:
			return false
		if absf(v.x)>0.71 or absf(v.y)>0.87 or absf(v.z)>0.19:
			return false
		y_min = minf(y_min,v.y)
		z_min = minf(z_min,v.z)
	return y_min<-0.83 and z_min<-0.16
