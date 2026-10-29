extends SceneTree
## R167 source-authored grille, intake and THREE native headlamp LED bands.
## Authentic original Godot MeshInstance3D/PBR, zero UI screenshot props.
const ART=preload("res://scripts/horizon_vehicle_art.gd")
const PRECISION=preload("res://scripts/city_reign_precision_bodywork.gd")
var passed:=0
var failed:=0

func check(ok: bool,reason: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R167 PRECISION OPTICS FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(PRECISION.bounded(),"original source geometry stays within strict original GPU dimensions")
	var art: Node3D=ART.new()
	root.add_child(art)
	var trim: MeshInstance3D=art.get_node("R167PrecisionAeroSurface")
	var body: MeshInstance3D=art.get_node("FlowBody")
	var left: MeshInstance3D=art.get_node("LeftLED")
	var right: MeshInstance3D=art.get_node("RightLED")
	check(trim!=null and body!=null and left!=null and right!=null,
		"actual player car retains original body plus ONE source aero surface and original two LEDs")
	var original_children: int=art.get_child_count()
	var detail_arrays: Array=trim.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=detail_arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray=detail_arrays[Mesh.ARRAY_COLOR]
	var normals: PackedVector3Array=detail_arrays[Mesh.ARRAY_NORMAL]
	check(trim.mesh.get_surface_count()==1 and vertices.size()>=400 and
		vertices.size()<=PRECISION.MAX_BODY_VERTICES,
		"carbon/aluminium intakes and hood contours share ONE bounded PBR draw")
	check(colors.size()==vertices.size() and normals.size()==vertices.size(),
		"real physically lit source metal facets carry correct vertex colors and normals")
	var bright:=0.0
	var dark:=1.0
	for color in colors:
		bright=maxf(bright,color.r)
		dark=minf(dark,color.r)
	check(dark<0.09 and bright>0.48,
		"dark recessed intakes and bright machined blade highlights physically differentiated")
	var finish: StandardMaterial3D=trim.material_override as StandardMaterial3D
	check(finish.vertex_color_use_as_albedo and finish.clearcoat_enabled and
		finish.metallic>0.35 and finish.roughness<0.42,
		"original Godot directional light contributes PBR clearcoat, not billboard UI art")
	check(trim.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"single detail surface never creates extra shadow-map budget")
	check(left.mesh==right.mesh and left.mesh==PRECISION.light_mesh() and
		left.mesh.get_surface_count()==1 and
		left.mesh.surface_get_array_len(0)==108,
		"both ORIGINAL headlights reuse ONE cached source-created 3-band optical mesh")
	check((left.material_override as StandardMaterial3D).emission_enabled and
		(right.material_override as StandardMaterial3D).emission_enabled,
		"headlamp brightness remains genuine emissive 3D material, not a PNG")
	art.set_detail_quality("low")
	check(not trim.visible and left.visible and right.visible,
		"mobile low tier removes optional detail but retains road-visible LEDs")
	art.set_detail_quality("cinematic")
	check(trim.visible,"cinematic returns same real geometric detailing")
	var original_trim_mesh: Mesh=trim.mesh
	var original_lamp_mesh: Mesh=left.mesh
	for i in range(40):
		var mode: String="low" if i%2==0 else "standard"
		art.set_detail_quality(mode)
	check(trim.mesh==original_trim_mesh and left.mesh==original_lamp_mesh and
		art.get_child_count()==original_children,
		"40 adaptive GPU tier cycles cannot allocate new meshes or render nodes")
	for variant in ["compact","courier","executive","utility"]:
		art.set_visual_variant(variant)
		check(trim.mesh==original_trim_mesh and body.mesh!=null,
			"four authentic garage variants share original source aero geometry")
	art.set_visual_variant("compact")
	check(not ((art.get_node("FrontSplitter") as MeshInstance3D).mesh is BoxMesh),
		"R129 machined aerodynamics and original glass remain unchanged")
	art.queue_free()
	await process_frame
	print("CITY REIGN R167 REAL PRECISION OPTICS: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
