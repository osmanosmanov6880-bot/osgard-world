extends SceneTree
## HORIZON R26: bounded 3D wet asphalt details, actual native Godot scene.
const PUDDLES = preload("res://scripts/horizon_rain_puddles.gd")
var pass_count:=0
var fail_count:=0

func check(ok: bool, message: String) -> void:
	if ok: pass_count+=1
	else:
		fail_count+=1
		push_error("HORIZON R26 FAILED: "+message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var texture: ImageTexture=PUDDLES.make_mask()
	check(texture.get_width()==48 and texture.get_height()==48,"single puddle alpha mask is 48x48")
	var image: Image=texture.get_image()
	check(image.get_pixel(24,24).a>0.30,"puddle polygon has visible soft centre")
	check(image.get_pixel(0,0).a<0.02 and image.get_pixel(47,47).a<0.02,"puddle polygon edges are transparent")
	var layer: MultiMeshInstance3D=PUDDLES.new()
	root.add_child(layer)
	check(layer.material_is_bounded(),"PBR road detail has a strict 72-polygon cap")
	check(layer.multimesh.instance_count==72,"72 deterministic road instances all share one mesh")
	check(layer.multimesh.mesh is PlaneMesh,"puddle uses polygon mesh rather than costly physics volume")
	check(layer.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"transparent road details do not add shadow overhead")
	var p: StandardMaterial3D=layer.multimesh.mesh.material as StandardMaterial3D
	check(p!=null and p.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"actual smooth alpha-textured puddle material")
	check(p!=null and p.roughness<=0.22,"water finish has visually different roughness to dry road")
	check(not layer.visible,"clear weather never displays non-existing puddles")
	layer.set_conditions("rain","standard")
	check(layer.visible,"rain displays actual instanced puddles")
	layer.set_conditions("storm","cinematic")
	check(layer.visible,"storm displays road moisture")
	layer.set_conditions("rain","low")
	check(not layer.visible,"LOW mobile graphics disables transparent overlay draw")
	layer.set_conditions("cloudy","cinematic")
	check(not layer.visible,"clouds alone do not generate puddles")
	layer.set_conditions("rain","cinematic")
	check(layer.multimesh.instance_count==72,"repeated weather cycles do not allocate additional GPU instances")
	for i in range(72):
		var xform: Transform3D=layer.multimesh.get_instance_transform(i)
		if i<3: print("R26 PUDDLE DEBUG idx=",i," origin=",xform.origin," basis=",xform.basis)
		check(xform.origin.is_finite() and xform.origin.y>0.176 and xform.origin.y<0.20,"each puddle stays slightly above playable asphalt")
		check(absf(xform.origin.x)<225.0 and absf(xform.origin.z)<225.0,"all puddles remain inside actual roadway map")
	layer.queue_free()
	var world_script: Variant=load("res://scripts/world_builder.gd")
	check(world_script!=null,"real world script including R25 materials and R26 puddles parses")
	if world_script!=null:
		var world: Node3D=world_script.new()
		root.add_child(world)
		var road: MultiMeshInstance3D=world.get("road_puddles")
		check(road!=null and road.get_parent()==world.get("city_root"),"live city owns the one real GPU water detail layer")
		check(road!=null and not road.visible,"real clear-weather game has no visible puddles")
		world.update_weather("rain")
		check(road.visible,"actual game weather displays moisture on real road")
		check(world.asphalt_pbr.roughness<0.50,"wet asphalt material is still active under puddle geometry")
		world.apply_visual_budget("low")
		check(not road.visible,"live mobile governor removes transparent road work")
		world.apply_visual_budget("standard")
		check(road.visible,"upgrading back to STANDARD restores puddles")
		world.update_weather("clear")
		check(not road.visible and world.asphalt_pbr.roughness>0.70,"clearing skies removes moisture and restores dry road")
		var facade: MultiMeshInstance3D=world.get("facade_frames")
		check(facade!=null and facade.multimesh.instance_count>300,"R25 PBR metal window frame batch retained")
		world.queue_free()
	var main: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main.contains("SAFE_CAMERA.solve(focus,ideal,camera.global_position"),"live camera remains collision-safe")
	print("HORIZON R26 NATIVE: %d passed, %d failed" % [pass_count,fail_count])
	quit(0 if fail_count==0 else 1)
