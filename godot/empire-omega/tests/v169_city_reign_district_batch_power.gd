extends SceneTree
## R173 source-authored MultiMesh quality, dynamic electricity and weather.
const ID=preload("res://scripts/city_reign_district_identity.gd")
var pass_count: int=0
var fail_count: int=0
func check(ok: bool,why: String) -> void:
	if ok: pass_count+=1
	else:
		fail_count+=1
		push_error("CITY REIGN R173 POWERED GPU FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var old: Dictionary=sim.data.duplicate(true)
	var art: Node3D=ID.new()
	root.add_child(art)
	for i in range(128):
		var sector: String=ID.DISTRICTS[i%4]
		var at: Vector3=Vector3(float(i%16)*13.0-120.0,23.0,
			float(i/16)*13.0-90.0)
		art.call("record",at,12.5,23.0,sector,i%4)
	art.call("record",Vector3(NAN,0,0),12.0,23.0,"forum",0)
	art.call("record",Vector3.ZERO,12.0,23.0,"fictional",0)
	art.call("finalize")
	check(int(art.get("count"))==128 and art.graphics_are_bounded(),
		"all 128 original source locations have bounded genuine batches")
	check(art.get_child_count()==5 and art.triangle_count()<=ID.MAX_TRIANGLES,
		"four district draw batches and one light batch, never per-building nodes")
	for sector in ID.DISTRICTS:
		var model: MultiMeshInstance3D=art.get_node("District_"+sector)
		check(model.multimesh.instance_count==32,
			"each real 3D district identity shares one GPU draw: "+sector)
		check(model.multimesh.get_instance_transform(0).origin.is_finite(),
			"true rotated native 3D instance pose "+sector)
	art.set_quality("low")
	check(not (art.get_node("PoweredDistrictSigns") as Node3D).visible,
		"LOW removes original new glow draw")
	for sector in ID.DISTRICTS:
		check(not (art.get_node("District_"+sector) as Node3D).visible,
			"LOW removes discretionary actual 3D art for "+sector)
	art.set_quality("cinematic")
	art.update_ambience(22.0,100,"clear")
	var light: MultiMeshInstance3D=art.get_node("PoweredDistrictSigns")
	var mat: StandardMaterial3D=light.material_override
	check(light.visible and mat.emission_enabled and
		mat.emission_energy_multiplier>=0.5,
		"real night emits energy-dependent original architectural light")
	art.update_ambience(22.0,0,"clear")
	check(not light.visible and not mat.emission_enabled,
		"real zero-energy city power cut turns off new real-light batch")
	art.update_ambience(12.0,100,"clear")
	check(not light.visible,"daylight removes decorative emission")
	art.update_ambience(22.0,100,"storm")
	check(light.visible and mat.emission_energy_multiplier<0.78,
		"actual storm dims native façade light without secondary GPU pass")
	check(ID.night_factor(18.0)>0.0 and ID.night_factor(NAN)==0.0,
		"physically coherent sunset and safe malformed daylight")
	check(sim.data==old and art.graphics_are_bounded(),
		"material changes cannot mutate original game money, saves or missions")
	art.queue_free()
	await process_frame
	print("CITY REIGN R173 PBR ELECTRICITY: %d PASS %d FAIL" % [pass_count,fail_count])
	quit(0 if fail_count==0 else 1)
