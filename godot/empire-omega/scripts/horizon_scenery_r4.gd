extends Node3D
## OSGARD HORIZON R4 - original scenic roadside dressing for native Godot.
## One MultiMesh per object type: visual only, no gameplay collision changes.

var batch_count := 0
var shrub_count := 0
var reflector_count := 0
var sign_count := 0

func _ready() -> void:
	name = "HorizonSceneryR4"
	_build_parkland()
	_build_perimeter_safety()
	_build_wayfinding()

func _material(tint: Color, glowing: bool = false) -> StandardMaterial3D:
	var finish := StandardMaterial3D.new()
	finish.albedo_color = tint
	finish.roughness = 0.78 if not glowing else 0.35
	finish.metallic = 0.04 if not glowing else 0.35
	finish.vertex_color_use_as_albedo = true
	if glowing:
		finish.emission_enabled = true
		finish.emission = Color("75988a")
		finish.emission_energy_multiplier = 0.35
	return finish

func _batch(id: String, mesh: Mesh, placements: Array[Transform3D], colors: Array[Color], glow: bool = false) -> void:
	if placements.is_empty(): return
	assert(placements.size() == colors.size(),"Scenery transforms and palette must match")
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = placements.size()
	for index in range(placements.size()):
		multimesh.set_instance_transform(index,placements[index])
		multimesh.set_instance_color(index,colors[index])
	var node := MultiMeshInstance3D.new()
	node.name = id
	node.multimesh = multimesh
	node.material_override = _material(Color.WHITE,glow)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	batch_count += 1

func _build_parkland() -> void:
	# Parks on block edges, outside the car lanes and building cores.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261024
	var shrubs: Array[Transform3D] = []
	var greens: Array[Color] = []
	var flower_heads: Array[Transform3D] = []
	var petals: Array[Color] = []
	var flower_stems: Array[Transform3D] = []
	var stalk_colors: Array[Color] = []
	for quarter_x in range(8):
		for quarter_z in range(8):
			var x: float = -182.0 + float(quarter_x)*52.0
			var z: float = -182.0 + float(quarter_z)*52.0
			for j in range(4):
				var side: float = -1.0 if j%2==0 else 1.0
				var edge_x: float = x+side*18.5 if j < 2 else x+rng.randf_range(-17.0,17.0)
				var edge_z: float = z+rng.randf_range(-17.0,17.0) if j < 2 else z+side*18.5
				var height: float = rng.randf_range(0.72,1.45)
				shrubs.append(Transform3D(Basis().scaled(Vector3(height*1.5,height*0.85,height*1.45)),Vector3(edge_x,height*0.37,edge_z)))
				greens.append(Color("47845c") if (quarter_x+j)%3==0 else (Color("668c56") if quarter_z%2==0 else Color("376b5a")))
				shrub_count += 1
				for flower in range(2):
					var fx: float = edge_x+rng.randf_range(-2.4,2.4)
					var fz: float = edge_z+rng.randf_range(-2.4,2.4)
					var flower_height: float = rng.randf_range(.25,.48)
					flower_stems.append(Transform3D(Basis().scaled(Vector3(.07,flower_height,.07)),Vector3(fx,flower_height*.5,fz)))
					stalk_colors.append(Color("417d50"))
					flower_heads.append(Transform3D(Basis().scaled(Vector3(.23,.14,.23)),Vector3(fx,flower_height+.08,fz)))
					var color_index: int = (quarter_x+quarter_z+j+flower)%4
					petals.append([Color("f9c66a"),Color("dca9ce"),Color("e9e8d2"),Color("df8272")][color_index])
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = .6
	crown_mesh.height = 1.2
	crown_mesh.radial_segments = 8
	crown_mesh.rings = 4
	_batch("ParkShrubMasses",crown_mesh,shrubs,greens)
	var stem := CylinderMesh.new()
	stem.top_radius = .5
	stem.bottom_radius = .6
	stem.radial_segments = 5
	stem.height = 1.0
	_batch("WildflowerStems",stem,flower_stems,stalk_colors)
	var blossom := SphereMesh.new()
	blossom.radius = .5
	blossom.height = 1.0
	blossom.radial_segments = 7
	blossom.rings = 4
	_batch("WildflowerPetals",blossom,flower_heads,petals)

func _build_perimeter_safety() -> void:
	# Guardrails sit beyond the outside edge of the furthest roads.
	var anchors: Array[Transform3D] = []
	var post_colors: Array[Color] = []
	var beams: Array[Transform3D] = []
	var beam_colors: Array[Color] = []
	var reflectors: Array[Transform3D] = []
	var reflector_colors: Array[Color] = []
	for side in [-1.0,1.0]:
		for index in range(-34,35):
			var span: float = float(index)*6.0
			for vertical in [false,true]:
				var x: float = side*216.0 if vertical else span
				var z: float = span if vertical else side*216.0
				anchors.append(Transform3D(Basis().scaled(Vector3(.16,1.05,.16)),Vector3(x,.53,z)))
				post_colors.append(Color("536977"))
				reflectors.append(Transform3D(Basis().scaled(Vector3(.37,.11,.37)),Vector3(x,1.04,z)))
				reflector_colors.append(Color("e7ceb0") if index%2==0 else Color("a5c6b8"))
				if index < 34:
					beams.append(Transform3D(Basis().scaled(Vector3(.12,.24,6.0) if vertical else Vector3(6.0,.24,.12)),Vector3(x,.88,z+3.0 if vertical else z)))
					if not vertical:
						beams[beams.size()-1].origin = Vector3(x+3.0,.88,z)
					beam_colors.append(Color("899aa2"))
	var block := BoxMesh.new()
	block.size = Vector3.ONE
	_batch("RoadGuardrailPosts",block,anchors,post_colors)
	_batch("RoadGuardrailBeams",block,beams,beam_colors)
	_batch("RoadGuardrailReflectors",block,reflectors,reflector_colors,true)
	reflector_count = reflectors.size()

func _build_wayfinding() -> void:
	# Signs are simple geometric hints (no unrenderable glyphs / no billboards).
	var sign_panels: Array[Transform3D] = []
	var sign_colors: Array[Color] = []
	var poles: Array[Transform3D] = []
	var pole_colors: Array[Color] = []
	var arrowheads: Array[Transform3D] = []
	var arrow_colors: Array[Color] = []
	for ix in range(-3,4,2):
		for iz in range(-3,4,2):
			var x: float = float(ix)*52.0+8.0
			var z: float = float(iz)*52.0+8.0
			poles.append(Transform3D(Basis().scaled(Vector3(.16,5.2,.16)),Vector3(x,2.6,z)))
			pole_colors.append(Color("6f858d"))
			sign_panels.append(Transform3D(Basis().scaled(Vector3(4.0,1.15,.19)),Vector3(x+2.0,5.15,z)))
			sign_colors.append(Color("205e63"))
			arrowheads.append(Transform3D(Basis().scaled(Vector3(1.25,.11,.24)),Vector3(x+2.3,5.15,z-.14)))
			arrow_colors.append(Color("d6f2d7"))
			sign_count += 1
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	_batch("WayfindingPoles",unit,poles,pole_colors)
	_batch("WayfindingOverheadPanels",unit,sign_panels,sign_colors)
	_batch("WayfindingArrows",unit,arrowheads,arrow_colors)
