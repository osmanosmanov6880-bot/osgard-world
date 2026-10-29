extends SceneTree
## R166: true Godot native deterministic normalized brake-energy tests.
## Heat is VISUAL only; never pretend physical Celsius or calibrated ABS.
const THERMAL = preload("res://scripts/city_reign_rotor_thermal.gd")
const MOTION = preload("res://scripts/driving_dynamics.gd")
var passed := 0
var failed := 0

func check(ok: bool,what: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R166 ROTOR MODEL FAIL: "+what)

func _initialize() -> void:
	call_deferred("_run")

static func brake_run(grip: float,hz: int) -> Vector2:
	var speed: float = 23.0
	var heat: Vector2 = Vector2.ZERO
	var dt: float = 1.0/float(hz)
	var contacts: Array[bool] = [true,true,true,true]
	# Measure early braking before both normalized heat gauges saturate at 1.0.
	# A later explicit bound check proves that the long-term limit remains safe.
	for i in range(roundi(float(hz)*0.48)):
		var old: float = speed
		speed = MOTION.speed_step(speed,-1.0,grip,1.0,29.0,9.0,9.5,10.5,2.4,false,dt)
		heat = THERMAL.step(heat,old,speed,1.0,grip,0.61,contacts,dt)
	return heat

func _run() -> void:
	var full: Array[bool] = [true,true,true,true]
	var empty: Array[bool] = [false,false,false,false]
	check(THERMAL.dissipated_energy(20.0,18.0,1.0)>75.0,
		"actual kinetic energy loss after pressured braking is observed")
	check(THERMAL.dissipated_energy(20.0,18.0,0.0)==0.0,
		"drag, coasting or collision without pedal cannot heat rotors")
	check(THERMAL.dissipated_energy(18.0,20.0,1.0)==0.0,
		"acceleration is not wrongly represented as brake energy")
	check(THERMAL.dissipated_energy(NAN,12.0,1.0)==0.0 and
		THERMAL.dissipated_energy(INF,11.0,1.0)==0.0,
		"nonfinite velocity never enters the thermal model")
	check(THERMAL.supported_axles(full)==Vector2.ONE,
		"four physical road contacts deliver both full axle supports")
	check(THERMAL.supported_axles([true,false,false,true])==Vector2(0.5,0.5),
		"front and rear support use existing LF LR RF RR ordering")
	check(THERMAL.supported_axles(empty)==Vector2.ZERO,
		"airborne car cannot generate fictitious road heat")
	var brake: Vector2 = THERMAL.step(Vector2.ZERO,23.0,22.2,1.0,1.0,0.62,full,1.0/60.0)
	check(brake.x>brake.y and THERMAL.valid(brake),
		"front axle receives more actual pressure energy on a stable road")
	var air: Vector2 = THERMAL.step(Vector2.ZERO,23.0,22.2,1.0,1.0,0.62,empty,1.0/60.0)
	check(air==Vector2.ZERO,
		"full deceleration with no tire support produces zero rotor road heating")
	var no_brake: Vector2 = THERMAL.step(brake,22.2,22.0,0.0,1.0,0.62,full,1.0/60.0)
	check(no_brake.x<brake.x and no_brake.y<brake.y,
		"existing rotor energy cools when the actual pedal is released")
	var wet: Vector2 = THERMAL.step(brake,0.0,0.0,0.0,0.45,0.62,full,1.0/60.0)
	var dry: Vector2 = THERMAL.step(brake,0.0,0.0,0.0,1.0,0.62,full,1.0/60.0)
	check(wet.x<dry.x and wet.y<dry.y,
		"wet road reduces normalized rotor heat faster, with no physics writes")
	var h30: Vector2 = brake_run(1.0,30)
	var h60: Vector2 = brake_run(1.0,60)
	var h120: Vector2 = brake_run(1.0,120)
	check(THERMAL.valid(h60) and h60.x>0.25,
		"repeated real kinetic deceleration produces visibly hot front rotor")
	check(h60.x>h60.y and h120.x>h120.y,
		"R46 front load ratio shapes visual heat across simulation frame rates")
	check(h30.distance_to(h60)<0.10 and h60.distance_to(h120)<0.10,
		"30/60/120Hz normalized heat remains within bounded 10% tolerance")
	check(THERMAL.visible_glow(0.0)==0.0 and THERMAL.visible_glow(0.15)==0.0,
		"cold original alloy never glows as a fake neon brake")
	check(THERMAL.visible_glow(0.7)>0.0 and THERMAL.visible_glow(1.0)==1.0,
		"sustained high-input braking produces bounded amber/red glow")
	check(THERMAL.step(Vector2(INF,-1.0),12.0,10.0,1.0,NAN,NAN,full,0.0)==Vector2.ZERO,
		"invalid state and negative data are bounded before visual update")
	print("CITY REIGN R166 REAL ROTOR ENERGY: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
