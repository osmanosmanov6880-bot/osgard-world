extends SceneTree
## CITY REIGN AAA A14–A15 genuine Godot authored stage, budget,
## sky/reflections, night/day toggle, and real 4-car game integration.
## All original purchase/traffic physics/world state remain authoritative.
const STAGE = preload("res://scripts/city_reign_studio_architecture.gd")
const SHOWROOM = preload("res://scripts/city_reign_hero_showroom.gd")
const CATALOG = preload("res://scripts/vehicle_catalog.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN AAA STUDIO FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	check(state!=null,"actual authoritative original city GameState autoload")
	if state==null:
		quit(2)
		return
	var save: Dictionary = state.data.duplicate(true)
	var locale_before: String = str(state.locale)
	var stage: Node3D = STAGE.new()
	root.add_child(stage)
	check(stage.name=="CityReignArchitectedStudio" and
		bool(stage.call("geometry_is_bounded")),
		"exact 3 original drawable geometry nodes, no collision")
	var ring: MeshInstance3D = stage.get("ring") as MeshInstance3D
	var wall: MeshInstance3D = stage.get("backwall") as MeshInstance3D
	var fins: MultiMeshInstance3D = stage.get("fins") as MultiMeshInstance3D
	check(ring!=null and wall!=null and fins!=null and stage.get_child_count()==3,
		"3 real architectural GPU draw nodes, not fake in-game image")
	if ring!=null and ring.mesh!=null:
		check(ring.mesh is ArrayMesh and ring.mesh.get_surface_count()==1 and
			ring.mesh.surface_get_array_len(0)==STAGE.MAX_MARKING_VERTICES,
			"72 original physical plated brass arcs and 12 true 3D floor ticks")
		var points: PackedVector3Array = ring.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = ring.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
		check(points.size()==504 and colors.size()==504,
			"bounded one-shot genuine original 3D shape vertex color")
		for index in range(points.size()):
			var p: Vector3 = points[index]
			check(p.is_finite() and absf(p.y+0.832)<0.004 and
				Vector2(p.x,p.z).length()<3.50,
				"authored metallized floor pieces are finite/inside actual podium")
	var ring_material: StandardMaterial3D = stage.get("gold_material") as StandardMaterial3D
	check(ring_material!=null and ring_material.vertex_color_use_as_albedo and
		ring_material.metallic>=0.60 and ring_material.emission_enabled,
		"original hand-machined metallic finish uses true PBR material")
	if fins!=null:
		check(fins.multimesh!=null and
			fins.multimesh.instance_count==STAGE.FIN_COUNT and
			fins.multimesh.mesh is BoxMesh,
			"seven real architectural copper/bronze fins share one GPU mesh")
		var xs: Dictionary = {}
		var original_transforms: Array = stage.get("authored_fin_transforms")
		check(original_transforms.size()==STAGE.FIN_COUNT,
			"same finite CPU source transforms submitted to all seven GPU instances")
		for index in range(STAGE.FIN_COUNT):
			var t: Transform3D = original_transforms[index]
			xs[snappedf(t.origin.x,0.001)] = true
			check(is_equal_approx(t.origin.z,4.22),
				"real metal fins safely remain behind the 3D car")
		check(xs.size()==7,"all seven fins have unique physical positions")
	check(wall!=null and wall.position.z>=4.2 and
		wall.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"real satin basalt architectural wall never covers original player vehicle")
	stage.call("set_compact",true)
	check(not wall.visible and not fins.visible and ring.visible,
		"mobile drops two backdrop draw calls and keeps physical turntable")
	stage.call("set_compact",false)
	check(wall.visible and fins.visible,
		"original desktop cinematic environment retains authored architecture")
	stage.call("set_night",true)
	check(bool(stage.get("night")) and
		ring_material.emission_energy_multiplier>=0.70,
		"real night circuit physically increases brass dial emissive output")
	stage.call("set_night",false)
	check(not bool(stage.get("night")) and
		ring_material.emission_energy_multiplier<=0.12,
		"daytime original stage returns to low energy and avoids fake neon")
	check(bool(stage.call("geometry_is_bounded")) and
		stage.find_children("*","CollisionShape3D",true,false).is_empty(),
		"fidelity enhancement did not introduce pedestrian/vehicle collisions")
	stage.queue_free()
	await process_frame
	# The interactive actual source gallery creates ONE genuinely separate
	# World3D, one original sculpted car and no imported media/colliders.
	var studio: VBoxContainer = SHOWROOM.new()
	root.add_child(studio)
	studio.call("build","ru",false,true,"executive")
	await process_frame
	var viewport: SubViewport = studio.get("renderer") as SubViewport
	var room: WorldEnvironment = studio.get("studio_environment") as WorldEnvironment
	var key: DirectionalLight3D = studio.get("studio_key") as DirectionalLight3D
	var fill: DirectionalLight3D = studio.get("studio_fill") as DirectionalLight3D
	var set_stage: Node3D = studio.get("studio_stage") as Node3D
	check(viewport!=null and bool(studio.call("graphics_are_bounded")) and
		viewport.size==SHOWROOM.DESKTOP_SIZE,
		"actual original PC viewport bounded and physical source stage built")
	check(room!=null and room.environment!=null and room.environment.sky!=null and
		room.environment.reflected_light_source==Environment.REFLECTION_SOURCE_SKY,
		"real original procedural sky drives true PBR reflections on car metal")
	check(room.environment.background_mode==Environment.BG_COLOR and
		room.environment.ambient_light_source==Environment.AMBIENT_SOURCE_COLOR,
		"cinematic softbox reflection sky does not replace actual black studio")
	check(key!=null and fill!=null and not key.shadow_enabled and not fill.shadow_enabled,
		"two physical studio light sources, zero real-time phone shadow maps")
	check(set_stage!=null and bool(set_stage.call("geometry_is_bounded")) and
		bool(studio.get("enabled")),
		"staged original car and 3 additional physical geometric batches")
	var toggle: Button = studio.find_child("CityReignShowroomLightingToggle",true,false) as Button
	check(toggle!=null and not toggle.disabled and toggle.custom_minimum_size.y>=46.0,
		"native daylight/nightlight tactile button is accessible")
	if toggle!=null:
		toggle.pressed.emit()
	check(bool(studio.get("studio_night")) and
		is_equal_approx(room.environment.ambient_light_energy,0.52) and
		is_equal_approx(key.light_energy,0.92) and
		is_equal_approx(fill.light_energy,0.34),
		"night truly changes original PBR environment and both realtime lights")
	check(viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS and
		bool(set_stage.get("night")),
		"lighting only requests one GPU frame, stage metal reacts to actual mode")
	if toggle!=null:
		toggle.pressed.emit()
	check(not bool(studio.get("studio_night")) and
		is_equal_approx(room.environment.ambient_light_energy,0.97) and
		not bool(set_stage.get("night")),
		"two-way day/night is visually reversible in true Godot camera")
	check(state.data==save,
		"lighting preview never modifies vehicle ownership, treasury or missions")
	studio.queue_free()
	await process_frame
	# Phone lazy allocation: no background scene nor glowing metal UI until
	# actual user interaction; source model remains selectable before purchase.
	var phone: VBoxContainer = SHOWROOM.new()
	root.add_child(phone)
	phone.call("build","zh",true,true,"compact")
	check(phone.get("renderer")==null,
		"real original mobile zero additional GPU passes before inspection")
	check(phone.call("preview_vehicle","utility") and
		bool(phone.call("graphics_are_bounded")),
		"actual source-owned mobile showroom is built only after player request")
	var compact_stage: Node3D = phone.get("studio_stage") as Node3D
	check(compact_stage!=null and
		not (compact_stage.get("fins") as MultiMeshInstance3D).visible and
		not (compact_stage.get("backwall") as MeshInstance3D).visible,
		"real mobile mode hides heavy background architecture but retains original car")
	phone.call("toggle_lighting")
	check(bool(phone.get("studio_night")) and
		bool(compact_stage.get("night")),
		"touch-friendly native lighting contrast still available on compact display")
	check((phone.get("renderer") as SubViewport).render_target_update_mode
		!=SubViewport.UPDATE_ALWAYS,
		"phone never uses an unchecked idle-animated second GPU render loop")
	check(state.data==save,"no VIP car or money is ever granted by inspecting locked models")
	phone.queue_free()
	await process_frame
	state.data=save
	state.locale=locale_before
	print("CITY REIGN AAA native architectural studio: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
