extends RefCounted
## CITY REIGN WORLD EDITION B49 - source-native sculpted real building bodies.
##
## The EXISTING player-facing Building_### MeshInstance keeps its original
## original BoxShape3D collider, named scene path, road clearances, texture
## family, city finance authority, original window placement and camera.
## All alternate LODs are true closed Godot ArrayMeshes; not billboards,
## photos, shell clones, extra draw nodes or additional building instances.
const MAX_BUILDINGS: int = 128
const MAX_VERTICES_PER_CINEMATIC: int = 2400
const MAX_VERTICES_PER_STANDARD: int = 600
const FLOOR_SPACING: float = 4.4

const PALETTE: Dictionary = {
	"forum": Color(0.99,0.965,0.915),
	"housing": Color(0.925,0.955,0.985),
	"lower": Color(0.955,0.935,0.905),
	"aqueduct": Color(0.905,0.975,0.965)
}

static func _triangle(st: SurfaceTool,a: Vector3,b: Vector3,
		c: Vector3,tint: Color) -> void:
	var n: Vector3 = (b-a).cross(c-a)
	if n.length_squared() < 0.0000001:
		return
	n = n.normalized()
	for point in [a,b,c]:
		st.set_color(tint)
		st.set_normal(n)
		st.add_vertex(point)

static func _quad(st: SurfaceTool,a: Vector3,b: Vector3,
		c: Vector3,d: Vector3,tint: Color) -> void:
	_triangle(st,a,b,c,tint)
	_triangle(st,a,c,d,tint)

static func _box(st: SurfaceTool,minimum: Vector3,maximum: Vector3,
		tint: Color) -> void:
	# Closed architectural volume with six correctly oriented face normals.
	var low: Vector3 = minimum
	var high: Vector3 = maximum
	if high.x <= low.x or high.y <= low.y or high.z <= low.z:
		return
	var p: Array[Vector3] = [
		Vector3(low.x,low.y,low.z),Vector3(high.x,low.y,low.z),
		Vector3(high.x,low.y,high.z),Vector3(low.x,low.y,high.z),
		Vector3(low.x,high.y,low.z),Vector3(high.x,high.y,low.z),
		Vector3(high.x,high.y,high.z),Vector3(low.x,high.y,high.z)
	]
	_quad(st,p[0],p[1],p[2],p[3],tint)
	_quad(st,p[4],p[7],p[6],p[5],tint)
	_quad(st,p[0],p[4],p[5],p[1],tint)
	_quad(st,p[1],p[5],p[6],p[2],tint)
	_quad(st,p[2],p[6],p[7],p[3],tint)
	_quad(st,p[3],p[7],p[4],p[0],tint)

static func _prism(st: SurfaceTool,width: float,height: float,
		chamfer: float,tint: Color) -> void:
	var half: float = width*0.5
	var h: float = height*0.5
	var c: float = minf(chamfer,half*0.13)
	# Eight true perimeter sides, with 4 chamfered corners.
	# The center of each real facade is still EXACTLY x/z=+/-width/2.
	# Thus existing upper windows remain directly on the physical wall.
	var ring: Array[Vector2] = [
		Vector2(-half+c,-half),Vector2(half-c,-half),
		Vector2(half,-half+c),Vector2(half,half-c),
		Vector2(half-c,half),Vector2(-half+c,half),
		Vector2(-half,half-c),Vector2(-half,-half+c)
	]
	for i in range(ring.size()):
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i+1)%ring.size()]
		var bottom_a := Vector3(a.x,-h,a.y)
		var bottom_b := Vector3(b.x,-h,b.y)
		var top_a := Vector3(a.x,h,a.y)
		var top_b := Vector3(b.x,h,b.y)
		_quad(st,bottom_a,top_a,top_b,bottom_b,tint)
		_triangle(st,Vector3(0,h,0),top_b,top_a,tint)
		_triangle(st,Vector3(0,-h,0),bottom_a,bottom_b,tint)

static func _perimeter_course(st: SurfaceTool,width: float,
		at_y: float,thickness: float,tint: Color) -> void:
	var h: float = width*0.5
	# 9cm real stone relief catches side lighting; it is not a separate draw.
	# Window sightlines stay clear: courses lie between 4.4m story rows.
	var outside: float = 0.085
	var inside: float = 0.17
	_box(st,Vector3(-h,at_y,-h-outside),
		Vector3(h,at_y+thickness,-h+inside),tint)
	_box(st,Vector3(-h,at_y,h-inside),
		Vector3(h,at_y+thickness,h+outside),tint)
	_box(st,Vector3(-h-outside,at_y,-h),
		Vector3(-h+inside,at_y+thickness,h),tint)
	_box(st,Vector3(h-inside,at_y,-h),
		Vector3(h+outside,at_y+thickness,h),tint)

static func _vertical_reveals(st: SurfaceTool,width: float,
		bottom: float,top: float,tint: Color) -> void:
	if top-bottom < 2.0:
		return
	var h: float = width*0.5
	# Render-only stone piers at real building edges, never at the
	# authoritative central glass/door or existing +/-0.27w window rows.
	for side in [-1.0,1.0]:
		var x: float = float(side)*(h-0.31)
		var z: float = float(side)*(h-0.31)
		_box(st,Vector3(x-0.12,bottom,-h-0.12),
			Vector3(x+0.12,top,-h+0.08),tint)
		_box(st,Vector3(x-0.12,bottom,h-0.08),
			Vector3(x+0.12,top,h+0.12),tint)
		_box(st,Vector3(-h-0.12,bottom,z-0.12),
			Vector3(-h+0.08,top,z+0.12),tint)
		_box(st,Vector3(h-0.08,bottom,z-0.12),
			Vector3(h+0.12,top,z+0.12),tint)

static func _roof_equipment(st: SurfaceTool,width: float,
		height: float,typology: String,variation: int,
		tint: Color) -> void:
	var h: float = width*0.5
	var y: float = height*0.5
	var industrial: bool = typology=="lower" or typology=="aqueduct"
	# Pinned non-interactive rooftop mechanical volumes ABOVE the
	# previously unchanged BoxShape3D. Nothing can touch the road grid.
	var cap_height: float = 0.82 if industrial else 0.54
	var axis: float = 0.28 if variation%2==0 else -0.28
	_box(st,Vector3(-1.4,y+0.34,-1.05+axis),
		Vector3(1.4,y+cap_height+0.34,1.05+axis),
		tint.darkened(0.14))
	if industrial:
		_box(st,Vector3(-0.68,y+cap_height+0.34,-0.68+axis),
			Vector3(0.68,y+cap_height+0.91,0.68+axis),
			tint.darkened(0.24))
	else:
		for side in [-1.0,1.0]:
			var xx: float = float(side)*(h-0.65)
			_box(st,Vector3(xx-0.26,y+0.20,-0.26),
				Vector3(xx+0.26,y+0.89,0.26),tint.lightened(0.055))

static func make_mesh(width: float,height: float,district: String,
		variation: int,cinematic: bool) -> ArrayMesh:
	assert(width>=10.0 and width<=16.0 and height>=8.0 and height<=76.0)
	assert(PALETTE.has(district))
	var tint: Color = PALETTE[district]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var chamfer: float = 0.24 if district=="housing" else (
		0.40 if district=="forum" else 0.34)
	_prism(st,width,height,chamfer,tint)
	var ground: float = -height*0.5
	var top: float = height*0.5
	# Standard mode contains fewer than 600 source vertices: upgraded core,
	# true base, true silhouette cornice. Low mode keeps original BoxMesh.
	var base: Color = tint.darkened(0.055) if district=="lower" else tint.lightened(0.015)
	_perimeter_course(st,width,ground+0.22,0.24,base)
	_perimeter_course(st,width,top-0.52,0.24,base)
	if cinematic:
		_vertical_reveals(st,width,ground+5.8,top-1.05,tint.darkened(0.075))
		# Floor courses sit in the actual 4.4m spacing between source
		# windows. 8.8m repetition avoids overdraw and excessive detail.
		var elevation: float = 5.13 + float(posmod(variation,3))*0.11
		while elevation < height-1.65:
			var alpha: float = 0.045 if district=="forum" else 0.075
			var course: Color = tint.darkened(alpha)
			_perimeter_course(st,width,ground+elevation,0.14,course)
			elevation += FLOOR_SPACING*2.0
		_roof_equipment(st,width,height,district,variation,tint)
	var mesh: ArrayMesh = st.commit()
	assert(mesh != null and mesh.get_surface_count()==1)
	var count: int = mesh.surface_get_array_len(0)
	assert(count%3==0)
	assert(count>0 and count<=(MAX_VERTICES_PER_CINEMATIC if cinematic else MAX_VERTICES_PER_STANDARD))
	return mesh

static func vertices_for(mesh: Mesh) -> int:
	return mesh.surface_get_array_len(0) if mesh != null and mesh.get_surface_count()>0 else 0

static func valid_mesh(mesh: Mesh,width: float,height: float,
		cinematic: bool) -> bool:
	if not (mesh is ArrayMesh) or mesh.get_surface_count()!=1:
		return false
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	if vertices.size()> (MAX_VERTICES_PER_CINEMATIC if cinematic else MAX_VERTICES_PER_STANDARD):
		return false
	if vertices.size()<96 or vertices.size()%3!=0:
		return false
	if normals.size()!=vertices.size() or colors.size()!=vertices.size():
		return false
	var horizontal_limit: float = width*0.5+0.13
	var vertical_limit: float = height*0.5+(1.9 if cinematic else 0.05)
	for i in range(vertices.size()):
		var v: Vector3 = vertices[i]
		var n: Vector3 = normals[i]
		if not v.is_finite() or not n.is_finite() or absf(n.length()-1.0)>0.03:
			return false
		if absf(v.x)>horizontal_limit or absf(v.z)>horizontal_limit:
			return false
		if absf(v.y)>vertical_limit:
			return false
	return true
