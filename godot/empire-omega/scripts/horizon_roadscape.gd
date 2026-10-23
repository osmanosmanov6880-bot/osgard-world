extends Node3D
const R7_LEAF_WIND = preload("res://shaders/horizon_r7_canopy_wind.gdshader")
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
	var richer_scenery: Node3D = preload("res://scripts/horizon_scenery_r4.gd").new()
	add_child(richer_scenery)

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
	if label == "LeafCanopyBatch" or label == "LeafConeBatch":
		var breeze := ShaderMaterial.new()
		breeze.shader = R7_LEAF_WIND
		breeze.set_shader_parameter("wind_strength",.40)
		visual.material_override = breeze
	else:
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
	# Original broadleaf clusters: 7 scaled lobes rather than one giant green sphere.
	# One MultiMesh per leaf/branch family; 1300+ animated canopies cost ~2 draw calls.
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
			var center := Vector3(-182.0+float(ix)*52.0,0,-182.0+float(iz)*52.0)
			for i in range(3):
				var offset_x: float = (17.0 if i != 1 else -17.0)+rng.randf_range(-2.0,2.0)
				var offset_z: float = (17.0 if i != 2 else -17.0)+rng.randf_range(-2.0,2.0)
				var stem: float = rng.randf_range(3.0,4.3)
				var point: Vector3 = center+Vector3(offset_x,0,offset_z)
				trunks.append(Transform3D(Basis().scaled(Vector3(.27,stem,.27)),point+Vector3(0,stem*.5,0)))
				trunk_colors.append(Color("504c43"))
				# Lobe layout is deterministic, asymmetrical and modestly wind animated.
				for n in range(7):
					var theta: float = TAU*float(n)/7.0 + rng.randf_range(-.15,.15)
					var spread: float = rng.randf_range(.38,1.52)
					var h: float = stem + rng.randf_range(.46,1.64)
					var size: float = rng.randf_range(.88,1.40)
					var branch_position := point+Vector3(cos(theta)*spread,h,sin(theta)*spread)
					leaves.append(Transform3D(Basis(Vector3.UP,theta).scaled(Vector3(size,size*.84,size)),branch_position))
					leaf_colors.append(Color("4c7251") if (ix+iz+n)%3==0 else (Color("557c57") if (ix+n)%2==0 else Color("648666")))
				# A few taller evergreen silhouettes, but never pyramid mountains.
				if (ix+iz+i)%4==0:
					for layer in range(2):
						var breadth: float = 1.18-float(layer)*.31
						conifers.append(Transform3D(Basis().scaled(Vector3(breadth,1.0,breadth)),point+Vector3(0,stem+1.05+float(layer)*.76,0)))
						conifer_colors.append(Color("4a6b56") if layer==0 else Color("5a7a5c"))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = .31
	trunk_mesh.bottom_radius = .48
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 10
	_batch("TrunkBatch",trunk_mesh,trunks,trunk_colors)
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = .84
	crown_mesh.height = 1.42
	crown_mesh.radial_segments = 13
	crown_mesh.rings = 8
	_batch("LeafCanopyBatch",crown_mesh,leaves,leaf_colors)
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 0.0
	top_mesh.bottom_radius = .9
	top_mesh.height = 1.0
	top_mesh.radial_segments = 11
	_batch("LeafConeBatch",top_mesh,conifers,conifer_colors)
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

func _horizon_r7_peak(angle: float, belt: int) -> Vector3:
	# Smooth coastline ridges around the city, not isolated triangular pyramids.
	var radius: float = 390.0 + float(belt)*44.0
	radius += sin(angle*11.0+float(belt)*.29)*4.0
	var ridge: float = 66.0 + 18.0*sin(angle*3.0+.25)
	ridge += 13.0*sin(angle*7.0+1.39)
	ridge += 7.0*sin(angle*13.0-1.5)
	ridge += 3.0*sin(angle*29.0+.33)
	var slope: Array[float] = [.0,.09,.28,.56,.88,.95,.52,.06]
	var vertical: float = -12.0 + ridge*slope[belt]
	return Vector3(cos(angle)*radius,vertical,sin(angle)*radius)

func _build_mountains() -> void:
	# 7 concentric terrain belts x 256 angular subdivisions => smooth silhouette.
	# ~3600 triangles instead of 42 disconnected one-triangle backdrop spikes.
	# Distant art only: no collisions, no physics, and one mesh draw surface.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 256
	var belts: int = 8
	var moss := Color("536b64")
	var limestone := Color("8a8e86")
	for i in range(segments):
		var t0: float = TAU*float(i)/float(segments)
		var t1: float = TAU*float(i+1)/float(segments)
		var t_mid: float = .5*(t0+t1)
		for ring in range(belts-1):
			var a: Vector3 = _horizon_r7_peak(t0,ring)
			var b: Vector3 = _horizon_r7_peak(t1,ring)
			var c: Vector3 = _horizon_r7_peak(t0,ring+1)
			var d: Vector3 = _horizon_r7_peak(t1,ring+1)
			var weathering: float = .44 + .25*sin(t_mid*17.0+float(ring)*.62)
			weathering += .09*sin(t_mid*51.0-float(ring)*1.3)
			var rock: Color = moss.lerp(limestone,clampf(weathering+.055*float(ring),0.0,1.0))
			for vertex in [a,c,b,c,d,b]:
				surface.set_color(rock)
				surface.add_vertex(vertex)
	surface.generate_normals()
	var mountains := MeshInstance3D.new()
	mountains.name = "SurroundingMountainRange" # Stable public node contract, R7 geometry inside.
	mountains.mesh = surface.commit()
	var strata := _mat(Color.WHITE,0.0,.95)
	strata.vertex_color_use_as_albedo = true
	strata.cull_mode = BaseMaterial3D.CULL_DISABLED
	mountains.material_override = strata
	mountains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mountains)

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
