extends SceneTree
## R168 actual sun, sky, night and source road landscape acceptance.
const OPTICS = preload("res://scripts/city_reign_atmospheric_optics.gd")
const GRADE = preload("res://scripts/horizon_light_grade.gd")
const WORLD = preload("res://scripts/world_builder.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,reason: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("CITY REIGN R168 SOLAR FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(OPTICS.solar_fraction(12.0)>0.98 and OPTICS.solar_fraction(22.0)==0.0,
		"actual solar elevation peaks at noon, not midnight")
	check(OPTICS.sun_orientation(12.0).x<-50.0 and
		OPTICS.sun_orientation(6.0).x>-20.0 and
		OPTICS.sun_orientation(17.0).y>OPTICS.sun_orientation(8.0).y,
		"the one original physical directional sunlight rotates with real day time")
	check(OPTICS.hour_safe(NAN)==12.0 and OPTICS.hour_safe(INF)==12.0,
		"invalid solar clock cannot corrupt saved world atmosphere")
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	var sky := ProceduralSkyMaterial.new()
	GRADE.apply_to(env,sun,sky,"clear","cinematic",1.0)
	GRADE.apply_night_overlay(env,sun,sky,12.0)
	var original_sun: float = sun.light_energy
	OPTICS.apply_sky(env,sun,sky,12.0,"clear","cinematic")
	check(is_equal_approx(original_sun,sun.light_energy) and
		env.reflected_light_source==Environment.REFLECTION_SOURCE_BG,
		"original real environment irradiance stays physically light-driven, without SSR")
	var noon_angle: Vector3 = sun.rotation_degrees
	GRADE.apply_to(env,sun,sky,"clear","cinematic",1.0)
	GRADE.apply_night_overlay(env,sun,sky,18.0)
	OPTICS.apply_sky(env,sun,sky,18.0,"clear","cinematic")
	check(sun.rotation_degrees!=noon_angle and
		OPTICS.twilight_fraction(18.0)>0.65,
		"authentic dusk changes 3D shadow direction and horizon optics")
	GRADE.apply_to(env,sun,sky,"clear","cinematic",1.0)
	GRADE.apply_night_overlay(env,sun,sky,22.0)
	var original_night: float = sun.light_energy
	OPTICS.apply_sky(env,sun,sky,22.0,"clear","cinematic")
	check(is_equal_approx(original_night,sun.light_energy) and original_night < 0.04,
		"R44 nocturnal exposure remains authoritative")
	var world: Node3D = WORLD.new()
	root.add_child(world)
	world.update_daynight(12.0)
	var midday: Vector3 = world.sun.rotation_degrees
	world.update_daynight(18.0)
	var evening: Vector3 = world.sun.rotation_degrees
	check(midday.x < evening.x and not is_equal_approx(midday.y,evening.y),
		"R168 optical system is executed by real original playable city")
	world.apply_visual_budget("low")
	check(not world.sky_environment.environment.fog_enabled and
		world.sun.shadow_enabled==world.sun.shadow_enabled,
		"mobile LOW retains sky without new fog/render graph")
	world.queue_free()
	await process_frame
	print("CITY REIGN R168 ACTUAL SKY: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
