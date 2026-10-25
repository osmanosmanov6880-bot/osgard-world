extends Node3D
## R91 original native 3D architectural geometry — no image backdrops.
## Shared deterministic seed/shape sequence with the R90 outer skyline.
const COUNT: int = 72
const ROW_CAP: int = 12
var facade_glass: MultiMeshInstance3D
var rooftop_crowns: MultiMeshInstance3D
var source_skyline: MultiMeshInstance3D

func set_source_skyline(towers: MultiMeshInstance3D) -> void:
	source_skyline = towers

func _ready() -> void:
	name = "R91SkylineArchitecturalDetail"
	if source_skyline == null or source_skyline.multimesh == null:
		push_error("R91 requires the original built R90 tower meshes")
		return
	_build_geometry()
	set_quality("standard")

func _build_geometry() -> void:
	var windows: Array[Transform3D] = []
	var shades: Array[Color] = []
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3.ONE
	var roofs := MultiMesh.new()
	roofs.transform_format = MultiMesh.TRANSFORM_3D
	roofs.mesh = roof_mesh
	roofs.instance_count = COUNT
	for i in range(COUNT):
		# Read the ACTUAL physical skyline transform, never rebuild by seed.
		var original: Transform3D = source_skyline.multimesh.get_instance_transform(i)
		var center: Vector3 = original.origin
		var width: float = original.basis.x.length()
		var height: float = original.basis.y.length()
		var depth: float = original.basis.z.length()
		roofs.set_instance_transform(i,Transform3D(
			Basis().scaled(Vector3(width*0.91,0.65,depth*0.91)),
			Vector3(center.x,center.y+height*0.5+0.38,center.z)))
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
	var pane := BoxMesh.new()
	pane.size = Vector3(1.35,1.90,0.065)
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
	finish.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	facade_glass.material_override = finish
	facade_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	facade_glass.custom_aabb = AABB(Vector3(-340,0,-340),Vector3(680,116,680))
	add_child(facade_glass)
	rooftop_crowns = MultiMeshInstance3D.new()
	rooftop_crowns.name = "Original3DRooftopMeshes"
	rooftop_crowns.multimesh = roofs
	var crown_material := StandardMaterial3D.new()
	crown_material.albedo_color = Color("627082")
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

func graphics_are_bounded() -> bool:
	return (source_skyline != null and
		source_skyline.multimesh != null and
		source_skyline.multimesh.instance_count == COUNT and
		facade_glass != null and rooftop_crowns != null and
		facade_glass.multimesh.instance_count >= 2000 and
		facade_glass.multimesh.instance_count <= COUNT*ROW_CAP*8 and
		rooftop_crowns.multimesh.instance_count == COUNT and
		get_child_count() == 2)
