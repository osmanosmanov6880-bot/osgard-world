extends RefCounted
## R176 actual original machined 3D cargo cases for existing THREE car crates.
## Replaces resource only, not nodes or physical mass/collision.
const MAX_VERTICES: int=620
static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,
		d: Vector3,shade: Color) -> void:
	var norm: Vector3=(b-a).cross(c-a).normalized()
	for v in [a,b,c,a,c,d]:
		st.set_normal(norm)
		st.set_color(shade)
		st.add_vertex(v)

static func _box(st: SurfaceTool,low: Vector3,high: Vector3,tint: Color) -> void:
	var v: Array[Vector3]=[
		Vector3(low.x,low.y,low.z),Vector3(high.x,low.y,low.z),
		Vector3(high.x,low.y,high.z),Vector3(low.x,low.y,high.z),
		Vector3(low.x,high.y,low.z),Vector3(high.x,high.y,low.z),
		Vector3(high.x,high.y,high.z),Vector3(low.x,high.y,high.z)]
	for face in [[0,3,2,1],[4,5,6,7],[0,1,5,4],
			[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
		_quad(st,v[face[0]],v[face[1]],v[face[2]],v[face[3]],tint)

static func physical_crate() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body:=Color("c1c8c4")
	var metal:=Color("d7c5a3")
	var fittings:=Color("667982")
	# Preserve EXACT original 0.72 x 0.48 x 0.85 m envelope.
	_box(st,Vector3(-0.35,-0.23,-0.412),
		Vector3(0.35,0.23,0.412),body)
	for z in [-0.23,0.23]:
		_box(st,Vector3(-0.36,-0.24,z-0.052),
			Vector3(0.36,0.24,z+0.052),metal)
	for x in [-0.27,0.27]:
		_box(st,Vector3(x-0.041,-0.24,-0.425),
			Vector3(x+0.041,0.24,0.425),fittings)
	for x in [-0.28,0.28]:
		for z in [-0.30,0.30]:
			_box(st,Vector3(x-0.061,0.204,z-0.062),
				Vector3(x+0.061,0.24,z+0.062),metal)
	return st.commit()

static func within_original_envelope(mesh: Mesh) -> bool:
	if mesh==null or mesh.get_surface_count()!=1:
		return false
	var bb: AABB=mesh.get_aabb()
	return mesh.surface_get_array_len(0)<=MAX_VERTICES and
		bb.position.x>=-0.37 and bb.end.x<=0.37 and
		bb.position.y>=-0.25 and bb.end.y<=0.25 and
		bb.position.z>=-0.435 and bb.end.z<=0.435
