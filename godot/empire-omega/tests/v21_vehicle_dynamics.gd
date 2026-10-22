extends SceneTree
## Must execute in real Godot 4.4.1; portable Python models do not replace this.
const DYNAMICS = preload("res://scripts/driving_dynamics.gd")
const VEHICLE = preload("res://scripts/vehicle_controller.gd")
var passed := 0
var failed := 0

func check(ok: bool, explanation: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("V21 VEHICLE FAILED: " + explanation)

func step(value: float, throttle: float, grip: float = 1.0, park: bool = false) -> float:
	return DYNAMICS.speed_step(value,throttle,grip,1.0,VEHICLE.MAX_FORWARD,VEHICLE.MAX_REVERSE,VEHICLE.ACCELERATION,VEHICLE.BRAKING,VEHICLE.DRAG,park,1.0/60.0)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var speed: float = 0.0
	for i in range(160):
		speed = step(speed,1.0)
	check(speed > 25.0 and speed <= 29.0,"speed must build to safe forward limit")
	var brake_samples: Array[float] = []
	for i in range(240):
		speed = step(speed,-1.0)
		brake_samples.append(speed)
	check(brake_samples[0] < 29.0,"reverse control brakes forward motion")
	check(brake_samples.has(0.0),"vehicle passes through zero before reverse")
	check(speed < 0.0 and speed >= -9.0,"after braking, reverse can engage")
	var parking: float = step(12.0,1.0,1.0,true)
	check(parking < 12.0,"handbrake overrides accelerator")
	var dry: float = step(12.0,-1.0,1.0)
	var rain: float = step(12.0,-1.0,0.6)
	check(dry < rain,"wet surface increases stopping distance")
	check(absf(DYNAMICS.yaw_rate(25.0,1.0,1.0))*25.0 <= 9.501,"high-speed lateral cap")
	check(DYNAMICS.yaw_rate(7.0,0.8,1.0)>0.0 and DYNAMICS.yaw_rate(-7.0,0.8,1.0)<0.0,"reverse steering sign")
	check(DYNAMICS.brake_lamps(6.0,-1.0,false),"brake lamps on deceleration")
	check(not DYNAMICS.brake_lamps(6.0,1.0,false),"no brake lamps while accelerating")
	check(DYNAMICS.gear(-2.0)=="R" and DYNAMICS.gear(0.0)=="N" and DYNAMICS.gear(2.0)=="D","gear selection")
	var car = VEHICLE.new()
	root.add_child(car)
	check(car.brake_lamp_nodes.size() == 2,"both taillights instantiated")
	car._set_brake_lights(true)
	check(car.brake_lights_on,"brake light state shown")
	car._set_brake_lights(false)
	check(not car.brake_lights_on,"brake lights reset")
	car.queue_free()
	print("V21 VEHICLE NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
