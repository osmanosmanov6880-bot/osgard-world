extends SceneTree
## HORIZON R18 native visual QA: GL-friendly anti-glare atmosphere and PBR car.
const GRADE = preload("res://scripts/horizon_light_grade.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed := 0
var failed := 0

func verify(ok: bool, desc: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("R18 LIGHTING FAILED: "+desc)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	var sky := ProceduralSkyMaterial.new()
	GRADE.apply_to(env,sun,sky,"clear","cinematic",1.0)
	verify(env.adjustment_enabled,"color grading enabled on 3D environment")
	verify(env.adjustment_brightness < 1.0 and env.adjustment_brightness >= 0.85,"brightness is lowered but playable")
	verify(env.adjustment_contrast >= 1.0 and env.adjustment_contrast <= 1.10,"highlight separation stays bounded")
	verify(env.adjustment_saturation >= 0.90 and env.adjustment_saturation < 1.0,"sky grading avoids oversaturated neon")
	verify(env.fog_enabled and env.fog_density>0.0 and env.fog_density<0.001,"clear day haze is restrained")
	verify(sun.light_energy > 0.75 and sun.light_energy < 1.10,"sunlit world retains legible daylight")
	var clear_light: float = sun.light_energy
	var clear_top: Color = sky.sky_top_color
	GRADE.apply_to(env,sun,sky,"rain","standard",1.0)
	verify(sun.light_energy < clear_light,"rain reduces harsh direct sunlight")
	verify(sky.sky_top_color != clear_top,"rain changes actual sky material")
	verify(env.fog_density > GRADE.fog_density("clear","cinematic"),"rain has more distance haze")
	var rain_sun: float = sun.light_energy
	GRADE.apply_to(env,sun,sky,"storm","cinematic",1.0)
	verify(sun.light_energy < rain_sun and sun.light_energy > 0.3,"storm lighting stays visible")
	verify(env.fog_density > GRADE.fog_density("rain","cinematic"),"storm distance mist responds to weather")
	GRADE.apply_to(env,sun,sky,"storm","low",1.0)
	verify(not env.fog_enabled and is_zero_approx(env.fog_density),"low preset removes fog work")
	GRADE.apply_to(env,sun,sky,"clear","standard",INF)
	verify(is_finite(sun.light_energy) and is_finite(env.ambient_light_energy),"nonfinite sunlight input fails safely")
	var script: Variant = load("res://scripts/world_builder.gd")
	verify(script!=null,"live city world can be loaded under native Godot")
	if script!=null:
		var world: Node3D = script.new()
		root.add_child(world)
		world.apply_visual_budget("low")
		verify(not world.sky_environment.environment.fog_enabled,"world's actual low preset disables atmosphere")
		world.apply_visual_budget("cinematic")
		world.update_weather("rain")
		verify(world.sky_environment.environment.fog_enabled,"real world enables rain atmosphere at cinematic tier")
		verify(world.sky_environment.environment.fog_density > 0.0010,"live weather updates actual environment")
		verify(world.asphalt_pbr.roughness < 0.50,"R15 wet road material survives R18")
		world.update_daynight(10.0)
		verify(is_finite(world.sun.light_energy) and world.sun.light_energy > 0.30,"live simulated time gives bounded sunlight")
		world.update_weather("clear")
		verify(world.asphalt_pbr.roughness > 0.7,"clearing weather restores dry roadway")
		world.queue_free()
	var car: CharacterBody3D = CAR.new()
	root.add_child(car)
	var art: Node3D = car.get_node_or_null("HorizonCoupe")
	verify(art!=null,"actual driveable sports car has original art")
	if art!=null:
		var shell := art.get_node_or_null("FlowBody") as MeshInstance3D
		verify(shell!=null,"sports car has real sculpted exterior mesh")
		if shell!=null:
			var paint: StandardMaterial3D = shell.material_override as StandardMaterial3D
			verify(paint!=null and paint.clearcoat_enabled,"visible car paint has real clearcoat")
			verify(paint.clearcoat>=0.60 and paint.clearcoat<=0.8,"paint highlight coating is restrained")
			verify(paint.roughness >= 0.24 and paint.roughness<=0.3,"pigmented base does not behave like a mirror")
		car.apply_variant("compact")
		var selected: StandardMaterial3D = shell.material_override as StandardMaterial3D
		verify(selected!=null and selected.clearcoat_enabled,"garage color switches retain PBR lacquer")
	car.queue_free()
	var world_source: String = FileAccess.get_file_as_string("res://scripts/world_builder.gd")
	verify(world_source.contains("LIGHT_GRADE.apply_to("),"live scene uses centralized weather grade")
	print("HORIZON R18 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
