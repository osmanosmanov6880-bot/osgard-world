extends Node3D
## R91 original native 3D architectural geometry — no image backdrops.
## Shared deterministic seed/shape sequence with the R90 outer skyline.
const COUNT: int = 72
const ROW_CAP: int = 12
const ROOF_DETAIL = preload("res://scripts/city_reign_rooftop_geometry.gd")
var facade_glass: MultiMeshInstance3D
var rooftop_crowns: MultiMeshInstance3D
var rooftop_standard_mesh: ArrayMesh
var rooftop_cinematic_mesh: ArrayMesh
var source_skyline: MultiMeshInstance3D
var original_tower_transforms: Array[Transform3D] = []
var original_rooftop_transforms: Array[Transform3D] = []

func set_source_skyline(towers: MultiMeshInstance3D,planned: Array[Transform3D]) -> void:
	source_skyline = towers
	original_tower_transforms = planned.duplicate()

func _ready() -> void:
	name = "R91SkylineArchitecturalDetail"
	if source_skyline == null or source_skyline.multimesh == null or original_tower_transforms.size() != COUNT:
		push_error("R91 requires the original built R90 tower meshes")
		return
	_build_geometry()
	set_quality("standard")

# CITY REIGN: two genuine mesh LODs share the ORIGINAL roof MultiMesh.
# STANDARD remains byte-for-byte the original four box silhouette budget.
# CINEMATIC adds roofline parapets and mechanical equipment with actual depth,
# colored PBR vertices and face normals. Both keep 72 source transforms.
static func _architectural_roof_mesh(cinematic: bool = false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	ROOF_DETAIL.append_geometry(st, cinematic)
	return st.commit()

# R119: real front + rear glazing with physical recessed glass and
# four thin corner metal mullions on EACH face. In contrast to a white
# floating BoxMesh, both sides have genuine geometry and physically shaded
# surfaces. ONE shared 20-triangle ArrayMesh; same original MultiMesh batch,
# original deterministic 4-sided window coordinates, no per-pane scene nodes.
static func _window_quad(st: SurfaceTool, x0: float, x1: float,
		y0: float, y1: float, z: float, tint: Color) -> void:
	var a := Vector3(x0,y0,z)
	var b := Vector3(x1,y0,z)
	var c := Vector3(x1,y1,z)
	var d := Vector3(x0,y1,z)
	var outward: float = 1.0 if z > 0.0 else -1.0
	st.set_normal(Vector3(0.0,0.0,outward))
	st.set_color(tint)
	if z > 0.0:
		for vertex in [a,b,c,a,c,d]:
			st.add_vertex(vertex)
	else:
		for vertex in [a,c,b,a,d,c]:
			st.add_vertex(vertex)

static func _architectural_window_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Original R91 pane extents: 1.35m wide, 1.90m high.
	# Two-sided physical front glass at +/-0.025, metal at +/-0.050.
	# Frame colors multiply original per-instance warm/cool window states.
	var glazing := Color(0.94,0.97,1.0,1.0)
	var anodized := Color(0.25,0.30,0.37,1.0)
	for face in [1.0,-1.0]:
		var sign_z: float = float(face)
		var glass_z: float = 0.025*sign_z
		var frame_z: float = 0.050*sign_z
		_window_quad(st,-0.585,0.585,-0.860,0.860,glass_z,glazing)
		_window_quad(st,-0.675,-0.585,-0.950,0.950,frame_z,anodized)
		_window_quad(st,0.585,0.675,-0.950,0.950,frame_z,anodized)
		_window_quad(st,-0.585,0.585,0.860,0.950,frame_z,anodized)
		_window_quad(st,-0.585,0.585,-0.950,-0.860,frame_z,anodized)
	return st.commit()

func _build_geometry() -> void:
	var windows: Array[Transform3D] = []
	var shades: Array[Color] = []
	# R114: an actual stepped rooftop pavilion/vents in the SAME one GPU batch.
	# Draw-instance count and collision behavior are strictly unchanged.
	rooftop_standard_mesh = _architectural_roof_mesh(false)
	rooftop_cinematic_mesh = _architectural_roof_mesh(true)
	var roofs := MultiMesh.new()
	roofs.transform_format = MultiMesh.TRANSFORM_3D
	roofs.mesh = rooftop_standard_mesh
	roofs.instance_count = COUNT
	original_rooftop_transforms.clear()
	for i in range(COUNT):
		# The *identical* CPU transform that constructed the original tower.
		# On a headless GL runner MultiMesh readback can be identity/undefined;
		# reading it here lost scale and produced floating windows.
		var original: Transform3D = original_tower_transforms[i]
		var center: Vector3 = original.origin
		var width: float = original.basis.x.length()
		var height: float = original.basis.y.length()
		var depth: float = original.basis.z.length()
		var cap := Transform3D(
			Basis().scaled(Vector3(width*0.91,0.65,depth*0.91)),
			Vector3(center.x,center.y+height*0.5+0.38,center.z))
		original_rooftop_transforms.append(cap)
		roofs.set_instance_transform(i,cap)
		var floors: int = mini(ROW_CAP,maxi(3,floori((height-4.0)/4.2)))
		for floor_index in range(floors):
			var y: float = 3.8+float(floor_index)*4.1
			if y>height-1.0:
				continue
			for facing in range(4):
				var east_west: bool = facing>=2
				var sign_side: float = -1.0 if facing%2==0 else 1.0
				for column in range(2):
					var lane: float = float(column*2-1)
					var at: Vector3
					var basis := Basis()
					if east_west:
						at = Vector3(center.x+sign_side*(width*0.5+0.075),
							y,center.z+lane*depth*0.24)
						basis = Basis(Vector3.UP,PI*0.5)
					else:
						at = Vector3(center.x+lane*width*0.24,
							y,center.z+sign_side*(depth*0.5+0.075))
					windows.append(Transform3D(basis,at))
					var lit: bool = posmod(i*3+floor_index*11+facing*5+column*7,9)<4
					shades.append(Color("cbaa75") if lit else Color("31495b"))
	var pane := _architectural_window_mesh()
	var glass_batch := MultiMesh.new()
	glass_batch.transform_format = MultiMesh.TRANSFORM_3D
	glass_batch.use_colors = true
	glass_batch.mesh = pane
	glass_batch.instance_count = windows.size()
	for k in range(windows.size()):
		glass_batch.set_instance_transform(k,windows[k])
		glass_batch.set_instance_color(k,shades[k])
	facade_glass = MultiMeshInstance3D.new()
	facade_glass.name = "OriginalFourSideWindowMeshes"
	facade_glass.multimesh = glass_batch
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color.WHITE
	finish.vertex_color_use_as_albedo = true
	# Real metal/glass response uses the same original environment lighting,
	# with no new reflection probes, lights, shaders, colliders or draw passes.
	finish.metallic = 0.24
	finish.roughness = 0.27
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	facade_glass.material_override = finish
	facade_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	facade_glass.custom_aabb = AABB(Vector3(-340,0,-340),Vector3(680,116,680))
	add_child(facade_glass)
	rooftop_crowns = MultiMeshInstance3D.new()
	rooftop_crowns.name = "Original3DRooftopMeshes"
	rooftop_crowns.multimesh = roofs
	var crown_material := StandardMaterial3D.new()
	crown_material.albedo_color = Color.WHITE
	crown_material.vertex_color_use_as_albedo = true
	crown_material.metallic = 0.51
	crown_material.roughness = 0.35
	rooftop_crowns.material_override = crown_material
	rooftop_crowns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rooftop_crowns.custom_aabb = AABB(Vector3(-340,0,-340),Vector3(680,116,680))
	add_child(rooftop_crowns)

func set_quality(tier: String) -> void:
	var show_art: bool = tier != "low"
	if facade_glass != null:
		facade_glass.visible = show_art
	if rooftop_crowns != null:
		rooftop_crowns.visible = show_art
		# Changing the shared mesh keeps one draw batch and every original
		# instance transform. No new nodes, physics or saved-state writes.
		var desired: ArrayMesh = rooftop_cinematic_mesh if tier == "cinematic" else rooftop_standard_mesh
		if desired != null and rooftop_crowns.multimesh.mesh != desired:
			rooftop_crowns.multimesh.mesh = desired

func graphics_are_bounded() -> bool:
	return (source_skyline != null and
		source_skyline.multimesh != null and
		source_skyline.multimesh.instance_count == COUNT and
		facade_glass != null and rooftop_crowns != null and
		facade_glass.multimesh.instance_count >= 2000 and
		facade_glass.multimesh.instance_count <= COUNT*ROW_CAP*8 and
		rooftop_crowns.multimesh.instance_count == COUNT and
		rooftop_standard_mesh != null and rooftop_cinematic_mesh != null and
		rooftop_standard_mesh.get_surface_count() == 1 and
		rooftop_cinematic_mesh.get_surface_count() == 1 and
		get_child_count() == 2 and
		original_tower_transforms.size() == COUNT and
		original_rooftop_transforms.size() == COUNT)
