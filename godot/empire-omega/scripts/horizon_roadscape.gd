extends Node3D
## OSGARD HORIZON ROADSCAPE - GPU-instanced scenic environment for HTML5.
## Original procedural road decoration, low-poly foliage and skyline.
## It deliberately has no colliders: traffic and missions retain their geometry.

var tree_count := 0
var marking_count := 0
var scenic_batches := 0

func _ready() -> void:
	name = "HorizonRoadscape"
	_build_crosswalks()
	_build_trees()
	_build_lamps()
	_build_mountains()
	_build_festival_gate()

func _mat(color: Color, metal: float = 0.0, rough: float = 0.8, glow: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	material.metallic = metal
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.2
	return material

func _batch(label: String, mesh: Mesh, placements: Array[Transform3D], colors: Array[Color], glowing: bool = false) -> void:
	if placements.is_empty(): return
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = placements.size()
	for index in range(placements.size()):
		instances.set_instance_transform(index,placements[index])
		instances.set_instance_color(index,colors[index])
	var visual := MultiMeshInstance3D.new()
	visual.name = label
	visual.multimesh = instances
	var paint := _mat(Color.WHITE,0.04,0.9,glowing)
	paint.vertex_color_use_as_albedo = true
	visual.material_override = paint
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	scenic_batches += 1

func _build_crosswalks() -> void:
	var stripes: Array[Transform3D] = []
	var stripe_color: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022
	for xi in range(-4,5):
		for zi in range(-4,5):
			var x: float = float(xi) * 52.0
			var z: float = float(zi) * 52.0
			for lane in [-12.5,12.5]:
				for mark in range(5):
					var offset: float = float(mark-2) * 1.4
					stripes.append(Transform3D(Basis().scaled(Vector3(.90,.018,2.25)),Vector3(x+offset,.208,z+lane)))
					stripe_color.append(Color("e8e2d0"))
					stripes.append(Transform3D(Basis().scaled(Vector3(2.25,.018,.90)),Vector3(x+lane,.208,z+offset)))
					stripe_color.append(Color("e8e2d0"))
	var block := BoxMesh.new()
	block.size = Vector3.ONE
	marking_count = stripes.size()
	_batch("CrosswalkBatch",block,stripes,stripe_color)
	# Continuous warning reflectors at road boundaries, batched in one draw call.
	var edge: Array[Transform3D] = []
	var edge_colors: Array[Color] = []
	for road in range(-4,5):
		for point in range(-10,11):
			var at: float = float(point)*21.0
			for side in [-1.0,1.0]:
				var p: float = float(road)*52.0
				edge.append(Transform3D(Basis().scaled(Vector3(0.2,.04,1.30)),Vector3(p+side*5.1,.22,at)))
				edge_colors.append(Color("d6c7a0"))
				edge.append(Transform3D(Basis().scaled(Vector3(1.30,.04,.2)),Vector3(at,.22,p+side*5.1)))
				edge_colors.append(Color("d6c7a0"))
	_batch("RoadReflectors",block,edge,edge_colors,true)

func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1042026
	var trunks: Array[Transform3D] = []
	var trunk_colors: Array[Color] = []
	var leaves: Array[Transform3D] = []
	var leaf_colors: Array[Color] = []
	var conifers: Array[Transform3D] = []
	var conifer_colors: Array[Color] = []
	for ix in range(8):
		for iz in range(8):
			var center: Vector3 = Vector3(-182.0+float(ix)*52.0,0,-182.0+float(iz)*52.0)
			for i in range(3):
				var offset_x: float = (17.0 if i != 1 else -17.0) + rng.randf_range(-2.0,2.0)
				var offset_z: float = (17.0 if i != 2 else -17.0) + rng.randf_range(-2.0,2.0)
				var height: float = rng.randf_range(2.7,4.3)
				var point := center + Vector3(offset_x,0.0,offset_z)
				trunks.append(Transform3D(Basis().scaled(Vector3(0.34,height,0.34)),point+Vector3(0,height*0.5,0)))
				trunk_colors.append(Color("594a40"))
				var crown_scale: float = rng.randf_range(2.6,3.6)
				leaves.append(Transform3D(Basis().scaled(Vector3(crown_scale,2.2,crown_scale)),point+Vector3(0,height+0.75,0)))
				leaf_colors.append(Color("3c7a53") if (ix+iz)%3==0 else Color("589264"))
				conifers.append(Transform3D(Basis().scaled(Vector3(crown_scale*.70,2.4,crown_scale*.70)),point+Vector3(0,height+2.1,0)))
				conifer_colors.append(Color("2d694e") if (ix+iz)%3==0 else Color("3a8158"))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.4
	trunk_mesh.bottom_radius = 0.55
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	_batch("TrunkBatch",trunk_mesh,trunks,trunk_colors)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.8
	crown_mesh.height = 1.6
	crown_mesh.radial_segments = 9
	crown_mesh.rings = 5
	_batch("LeafCanopyBatch",crown_mesh,leaves,leaf_colors)
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.92
	tip_mesh.height = 1.0
	tip_mesh.radial_segments = 7
	_batch("LeafConeBatch",tip_mesh,conifers,conifer_colors)
	tree_count = trunks.size()

func _build_lamps() -> void:
	var posts: Array[Transform3D] = []
	var post_color: Array[Color] = []
	var lanterns: Array[Transform3D] = []
	var lantern_color: Array[Color] = []
	for ix in range(-4,5):
		for iz in range(-4,5):
			for side in [-1.0,1.0]:
				var x: float = float(ix)*52.0+side*7.6
				var z: float = float(iz)*52.0+17.0
				posts.append(Transform3D(Basis().scaled(Vector3(.15,5.2,.15)),Vector3(x,2.6,z)))
				post_color.append(Color("334753"))
				lanterns.append(Transform3D(Basis().scaled(Vector3(.56,.23,.56)),Vector3(x,5.23,z)))
				lantern_color.append(Color("ffe2a5"))
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.45
	pole_mesh.bottom_radius = 0.6
	pole_mesh.height = 1.0
	pole_mesh.radial_segments = 8
	_batch("LampPoleBatch",pole_mesh,posts,post_color)
	var lantern_mesh := SphereMesh.new()
	lantern_mesh.radius = .85
	lantern_mesh.height = 1.15
	lantern_mesh.radial_segments = 8
	lantern_mesh.rings = 4
	_batch("LanternBatch",lantern_mesh,lanterns,lantern_color,true)

func _build_mountains() -> void:
	var mesh_builder := SurfaceTool.new()
	mesh_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 42
	for i in range(segments):
		var t0: float = float(i) / float(segments) * TAU
		var t1: float = float(i+1) / float(segments) * TAU
		var tm: float = (t0+t1)*0.5
		var radius: float = 430.0
		var lower_a := Vector3(cos(t0)*radius,-14.0,sin(t0)*radius)
		var lower_b := Vector3(cos(t1)*radius,-14.0,sin(t1)*radius)
		var height: float = 28.0 + float((i*13)%9)*7.0
		var ridge := Vector3(cos(tm)*(radius+50.0),height,sin(tm)*(radius+50.0))
		mesh_builder.set_color(Color("597c79") if i%2==0 else Color("728d85"))
		mesh_builder.add_vertex(lower_a)
		mesh_builder.add_vertex(ridge)
		mesh_builder.add_vertex(lower_b)
	mesh_builder.generate_normals()
	var mountain := MeshInstance3D.new()
	mountain.name = "SurroundingMountainRange"
	mountain.mesh = mesh_builder.commit()
	var rock_mat := _mat(Color.WHITE,0.0,1.0)
	rock_mat.vertex_color_use_as_albedo = true
	rock_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mountain.material_override = rock_mat
	mountain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mountain)

func _sculpture_piece(id: String, size: Vector3, point: Vector3, tint: Color, emissive: bool = false) -> void:
	var cube := BoxMesh.new()
	cube.size = size
	var art := MeshInstance3D.new()
	art.name = id
	art.mesh = cube
	art.position = point
	art.material_override = _mat(tint,0.25,0.31,emissive)
	art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(art)

func _build_festival_gate() -> void:
	# Landmark immediately near the first-drive area; no gameplay collisions.
	var c := Color("1b4650")
	var light := Color("ffe5a5")
	_sculpture_piece("FestivalLeftPillar",Vector3(.60,9,.70),Vector3(-119.0,4.5,-90.0),c)
	_sculpture_piece("FestivalRightPillar",Vector3(.60,9,.70),Vector3(-105.0,4.5,-90.0),c)
	_sculpture_piece("FestivalRoof",Vector3(15,.68,.94),Vector3(-112.0,9.0,-90.0),c)
	_sculpture_piece("FestivalNeonBar",Vector3(14.6,.12,1.03),Vector3(-112.0,8.7,-90.0),light,true)
