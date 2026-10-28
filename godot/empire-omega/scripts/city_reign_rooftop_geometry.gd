extends RefCounted
## CITY REIGN: real source-owned rooftop geometry integrated into the EXISTING
## R91 MultiMesh. No extra scene roots, draw batches, colliders or RNG calls.
## The base model preserves original R114 dimensions and exact vertex budget.
## Cinematic adds distinct true-3D parapets, HVAC cabinets, slats and pitched
## rooftop equipment; Standard uses the original lightweight 4-box crown.

const STANDARD_BOXES: int = 4
const CINEMATIC_BOXES: int = 20
const VERTICES_PER_BOX: int = 36

# Every box has twelve triangles, six real shaded faces and per-vertex tint.
# A lightweight optional roof-panel pitch rotates genuine geometry, never UVs.
static func _box(st: SurfaceTool, minimum: Vector3, maximum: Vector3,
		tint: Color, pitch: float = 0.0) -> void:
	var midpoint: Vector3 = (minimum + maximum) * 0.5
	var tilt := Basis(Vector3.RIGHT, pitch)
	var corners: Array[Vector3] = [
		Vector3(minimum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, minimum.z),
		Vector3(maximum.x, minimum.y, maximum.z),
		Vector3(minimum.x, minimum.y, maximum.z),
		Vector3(minimum.x, maximum.y, minimum.z),
		Vector3(maximum.x, maximum.y, minimum.z),
		Vector3(maximum.x, maximum.y, maximum.z),
		Vector3(minimum.x, maximum.y, maximum.z)
	]
	if not is_zero_approx(pitch):
		for i in range(corners.size()):
			corners[i] = midpoint + tilt * (corners[i] - midpoint)
	var quads: Array = [
		[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1],
		[1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]
	]
	for q in quads:
		var a: Vector3 = corners[int(q[0])]
		var b: Vector3 = corners[int(q[1])]
		var c: Vector3 = corners[int(q[2])]
		var d: Vector3 = corners[int(q[3])]
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		for vertex in [a, b, c, a, c, d]:
			st.set_normal(normal)
			st.set_color(tint)
			st.add_vertex(vertex)

static func append_geometry(st: SurfaceTool, cinematic: bool = false) -> void:
	# The four original R114 roof masses and exact boundaries, retained for
	# old save/camera behavior, basic tests and 72 original instance transforms.
	_box(st, Vector3(-0.50, -0.50, -0.50),
		Vector3(0.50, 0.50, 0.50), Color("82919b"))
	_box(st, Vector3(-0.18, 0.50, -0.28),
		Vector3(0.17, 2.60, 0.14), Color("71838d"))
	_box(st, Vector3(-0.25, 2.60, -0.32),
		Vector3(0.24, 2.85, 0.18), Color("a0abb2"))
	_box(st, Vector3(0.22, 0.50, -0.20),
		Vector3(0.32, 3.10, -0.09), Color("54616a"))
	if not cinematic:
		return

	# Raised perimeter parapets change the actual roof silhouette at oblique
	# camera angles. Four independent walls in ONE ArrayMesh surface.
	var stone := Color("9ba4aa")
	_box(st, Vector3(-0.48, 0.50, -0.48), Vector3(0.48, 0.95, -0.44), stone)
	_box(st, Vector3(-0.48, 0.50, 0.44), Vector3(0.48, 0.95, 0.48), stone)
	_box(st, Vector3(-0.48, 0.50, -0.44), Vector3(-0.44, 0.95, 0.44), stone)
	_box(st, Vector3(0.44, 0.50, -0.44), Vector3(0.48, 0.95, 0.44), stone)

	# Two rooftop HVAC housings; positive non-zero volume, no transparent cards.
	var steel := Color("87959c")
	_box(st, Vector3(-0.41, 0.54, 0.15), Vector3(-0.20, 1.48, 0.37), steel)
	_box(st, Vector3(0.19, 0.54, 0.17), Vector3(0.40, 1.38, 0.38), steel)
	var louver := Color("303f4b")
	_box(st, Vector3(-0.39, 0.74, 0.371), Vector3(-0.22, 0.83, 0.395), louver)
	_box(st, Vector3(-0.39, 0.96, 0.371), Vector3(-0.22, 1.05, 0.395), louver)
	_box(st, Vector3(0.21, 0.74, 0.381), Vector3(0.38, 0.83, 0.405), louver)
	_box(st, Vector3(0.21, 0.96, 0.381), Vector3(0.38, 1.05, 0.405), louver)

	# Two tilted equipment/solar panels with physical thickness and edge
	# frames. Their normal vectors are derived from the rotated vertices.
	var glass := Color("304f61")
	var frame := Color("b2babd")
	_box(st, Vector3(-0.43, 0.79, -0.40),
		Vector3(-0.26, 0.85, -0.16), glass, -0.21)
	_box(st, Vector3(0.34, 0.79, -0.40),
		Vector3(0.43, 0.85, -0.16), glass, -0.21)
	_box(st, Vector3(-0.44, 0.70, -0.41),
		Vector3(-0.25, 0.74, -0.15), frame, -0.21)
	_box(st, Vector3(0.33, 0.70, -0.41),
		Vector3(0.44, 0.74, -0.15), frame, -0.21)

	# Service access and roof utility ducts complete the bounded 20 volumes.
	_box(st, Vector3(-0.41, 0.53, -0.07),
		Vector3(-0.28, 1.20, 0.08), Color("63747e"))
	_box(st, Vector3(0.32, 0.53, -0.05),
		Vector3(0.41, 1.17, 0.10), Color("63747e"))

static func expected_vertex_count(cinematic: bool) -> int:
	return (CINEMATIC_BOXES if cinematic else STANDARD_BOXES) * VERTICES_PER_BOX
