extends SceneTree
## R44.1: honest physical light energies and visually distinct 22:00 sky.
const GRADE = preload("res://scripts/horizon_light_grade.gd")
var passed := 0
var failed := 0
func check(ok: bool,label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("R44.1 REAL NIGHT FAILURE: "+label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	var sky := ProceduralSkyMaterial.new()
	GRADE.apply_to(env,sun,sky,"clear","cinematic",1.0)
	var day_ambient: float = env.ambient_light_energy
	var day_sun: float = sun.light_energy
	var day_top: Color = sky.sky_top_color
	GRADE.apply_night_overlay(env,sun,sky,12.0)
	check(is_equal_approx(day_ambient,env.ambient_light_energy),"12:00 retains original daylight")
	check(is_equal_approx(day_sun,sun.light_energy),"12:00 sun remains original")
	check(sky.sky_top_color==day_top,"12:00 sky stays as authored")
	check(GRADE.night_fraction(19.0)>0.45 and GRADE.night_fraction(19.0)<0.55,"dusk smoothly interpolates")
	check(GRADE.night_fraction(22.0)==1.0 and GRADE.night_fraction(3.0)==1.0,"dark evening and dawn are nighttime")
	check(GRADE.night_fraction(NAN)==0.0,"invalid time never corrupts sky")
	GRADE.apply_night_overlay(env,sun,sky,22.0)
	check(env.ambient_light_energy < day_ambient*0.32 and env.ambient_light_energy>0.15,"real night ambient is restrained and not black")
	check(sun.light_energy < day_sun*0.05 and sun.light_energy>0.0,"real night sun no longer makes roads look like noon")
	check(env.adjustment_brightness<=0.87 and env.adjustment_brightness>=0.80,"night exposure retains playable contrast")
	check(sky.sky_top_color.r<day_top.r*0.20,"actual procedurally shaded night sky becomes midnight blue")
	var script: Variant = load("res://scripts/world_builder.gd")
	check(script is Script and script.can_instantiate(),"real playable world compiles with twilight")
	if script is Script and script.can_instantiate():
		var world: Node3D = script.new()
		root.add_child(world)
		world.call("update_daynight",12.0)
		var wenv: Environment = world.sky_environment.environment
		var midday: float = wenv.ambient_light_energy
		world.call("update_daynight",22.0)
		check(wenv.ambient_light_energy < midday*0.32,"actual city renderer uses true night exposure")
		check(world.sun.light_energy <= 0.03,"actual city has physically dimmed sun at 22:00")
		check(world.horizon_scenic.active_night_lights<=4,"night lighting stays strictly GPU bounded")
		world.call("update_daynight",12.0)
		check(wenv.ambient_light_energy>midday*0.98,"real-time sunrise restores daylight energy")
		world.queue_free()
	var source: String = FileAccess.get_file_as_string("res://scripts/world_builder.gd")
	check(source.contains("LIGHT_GRADE.apply_night_overlay("),"real live game invokes sky/ambient night overlay")
	print("EMPIRE OMEGA R44.1 NIGHT NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
