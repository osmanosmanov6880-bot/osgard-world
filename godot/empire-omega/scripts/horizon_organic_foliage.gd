extends RefCounted
## HORIZON R26: original organic-looking tree silhouettes as shared meshes.
## One deciduous crown mesh and one conifer mesh, instanced across the city.
## No external textures, per-tree resources, collision meshes or particles.

const LEAF_LON: int = 11
const LEAF_LAT: int = 6
const PINE_SIDES: int = 12

static func _vertex_point(theta: float, azimuth: float, center: Vector3, radii: Vector3, phase: float) -> Vector3:
	var direction := Vector3(sin(theta)*cos(azimuth),cos(theta),sin(theta)*sin(azimuth))
	var irregular: float = 1.0 + 0.085*sin(azimuth*3.0+phase) + 0.055*cos(theta*4.0+azimuth*2.0-phase)
	return center + Vector3(direction.x*radii.x,direction.y*radii.y,direction.z*radii.z)*irregular

static func _leaf_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, height: float) -> void:
	# Muted multipliers work with per-tree MultiMesh colors rather than
	# overpowering direct sunlight or creating fluorescent foliage.
	var shade: float = clampf(0.78+0.16*height,0.68,0.99)
	surface.set_color(Color(shade*0.96,shade,shade*0.94))
	surface.add_vertex(a)
	surface.set_color(Color(shade*0.95,shade*0.98,shade*0.94))
	surface.add_vertex(b)
	surface.set_color(Color(shade,shade,shade*0.96))
	surface.add_vertex(c)

static func leaf_canopy() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers: Array[Vector3] = [
		Vector3(0.0,0.10,0.0),Vector3(-0.34,-0.09,0.19),Vector3(0.32,-0.06,-0.20)
	]
	var scales: Array[Vector3] = [
		Vector3(0.77,0.79,0.72),Vector3(0.59,0.61,0.61),Vector3(0.59,0.63,0.58)
	]
	for lobe in range(centers.size()):
		var center: Vector3 = centers[lobe]
		var radius: Vector3 = scales[lobe]
		var phase: float = float(lobe)*1.82+0.37
		for latitude in range(LEAF_LAT):
			var theta0: float = float(latitude)*PI/float(LEAF_LAT)
			var theta1: float = float(latitude+1)*PI/float(LEAF_LAT)
			for longitude in range(LEAF_LON):
				var a0: float = float(longitude)*TAU/float(LEAF_LON)
				var a1: float = float(longitude+1)*TAU/float(LEAF_LON)
				var p00: Vector3 = _vertex_point(theta0,a0,center,radius,phase)
				var p01: Vector3 = _vertex_point(theta0,a1,center,radius,phase)
				var p10: Vector3 = _vertex_point(theta1,a0,center,radius,phase)
				var p11: Vector3 = _vertex_point(theta1,a1,center,radius,phase)
				_leaf_triangle(surface,p00,p01,p10,cos(theta0))
				_leaf_triangle(surface,p01,p11,p10,cos(theta1))
	surface.generate_normals()
	return surface.commit()

static func pine_canopy() -> ArrayMesh:
	# Three overlapping crown whorls: less like a single inverted ice cone.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in range(3):
		var bottom: float = -0.58+float(tier)*0.38
		var height: float = 0.83-float(tier)*0.06
		var radius: float = 0.80-float(tier)*0.18
		for k in range(PINE_SIDES):
			var a: float = TAU*float(k)/float(PINE_SIDES)
			var b: float = TAU*float(k+1)/float(PINE_SIDES)
			var jag_a: float = 0.91+0.09*sin(float(k)*2.4+float(tier)*1.7)
			var jag_b: float = 0.91+0.09*sin(float(k+1)*2.4+float(tier)*1.7)
			var bottom_a := Vector3(cos(a)*radius*jag_a,bottom,sin(a)*radius*jag_a)
			var bottom_b := Vector3(cos(b)*radius*jag_b,bottom,sin(b)*radius*jag_b)
			var crown_tip := Vector3(0.04*sin(float(tier)*2.0),bottom+height,0.04*cos(float(tier)*2.0))
			_leaf_triangle(surface,bottom_a,crown_tip,bottom_b,0.30+float(tier)*0.16)
	surface.generate_normals()
	return surface.commit()

static func leaf_triangle_budget() -> int:
	return 3*LEAF_LAT*LEAF_LON*2

static func pine_triangle_budget() -> int:
	return 3*PINE_SIDES
