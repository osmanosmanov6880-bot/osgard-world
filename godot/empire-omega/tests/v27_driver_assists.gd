extends SceneTree
## Native Godot 4.4.1: HORIZON R5 input authority, weather grip, stability,
## reverse response, drift bypass and binding into the actual drivable car.
const ASSISTS = preload("res://scripts/horizon_driver_assists.gd")
const DYNAMICS = preload("res://scripts/driving_dynamics.gd")
const TIRES = preload("res://scripts/horizon_tire_model.gd")
const VEHICLE = preload("res://scripts/vehicle_controller.gd")
var checks := 0
var failures := 0

func require(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("HORIZON R5 DRIVER ASSISTS FAILED: "+description)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	require(is_equal_approx(ASSISTS.drive_power(1.0,18.0,0.0,1.0,false),1.0),"no torque loss during straight-line drive")
	var dry_power: float = ASSISTS.drive_power(1.0,20.0,5.0,1.0,false)
	var wet_power: float = ASSISTS.drive_power(1.0,20.0,5.0,0.6,false)
	require(dry_power < 1.0 and dry_power > 0.4,"lateral slip gently reduces engine torque")
	require(wet_power < dry_power and wet_power > 0.4,"wet road calls for earlier torque reduction")
	require(is_equal_approx(ASSISTS.drive_power(-0.8,20.0,6.0,0.6,false),-0.8),"driver brake and reverse input are never overridden")
	require(is_equal_approx(ASSISTS.drive_power(1.0,18.0,7.0,0.6,true),1.0),"handbrake drift retains deliberate driver control")
	require(is_equal_approx(ASSISTS.drive_power(1.0,3.0,3.0,0.6,false),1.0),"parking speed is unaffected")
	require(ASSISTS.drive_power(1.0,28.0,19.0,0.35,false) >= 1.0-ASSISTS.MAX_POWER_REDUCTION,"torque correction has a strict lower bound")
	var dry_steer: float = ASSISTS.stabilize_steering(0.6,18.0,4.0,1.0,false)
	var wet_steer: float = ASSISTS.stabilize_steering(0.6,18.0,4.0,0.6,false)
	require(dry_steer < 0.6 and dry_steer > 0.3,"sideways momentum triggers modest steering correction")
	require(wet_steer < dry_steer,"wet loss of grip strengthens mild stability aid")
	require(ASSISTS.stabilize_steering(0.6,18.0,-4.0,1.0,false)>0.6,"lateral direction correctly changes correction direction")
	require(is_equal_approx(ASSISTS.stabilize_steering(0.6,18.0,4.0,0.6,true),0.6),"handbrake disables automatic counter-steering")
	require(ASSISTS.stabilize_steering(0.6,-18.0,4.0,0.6,false)>0.6,"reverse gear flips stability correction")
	require(is_equal_approx(ASSISTS.stabilize_steering(0.5,4.0,3.0,0.4,false),0.5),"small maneuvers are not disturbed")
	require(absf(ASSISTS.stabilize_steering(1.0,35.0,-20.0,0.35,false)) <= 1.0,"steering output stays inside legitimate input range")
	# Integrate the pure aid with the existing frame-catch-up-safe driving models.
	var speed: float = 12.0
	var sideways: float = 3.0
	for i in range(180):
		var command: float = ASSISTS.drive_power(1.0,speed,sideways,0.7,false)
		speed = DYNAMICS.speed_step(speed,command,0.7,1.0,29.0,9.0,9.5,10.5,2.4,false,1.0/60.0)
		var turn: float = ASSISTS.stabilize_steering(0.6,speed,sideways,0.7,false)
		var yaw: float = DYNAMICS.yaw_rate(speed,turn,0.7,false)
		sideways = TIRES.step_lateral(sideways,speed,yaw,0.7,false,1.0/60.0)
	require(is_finite(speed) and speed > 12.0 and speed <= 29.0,"180-frame wet-road acceleration is stable")
	require(is_finite(sideways) and absf(sideways) < TIRES.MAX_SLIP_SPEED,"180-frame lateral response remains bounded")
	var car: CharacterBody3D = VEHICLE.new()
	root.add_child(car)
	require(bool(car.get("assists_enabled")),"assists are enabled on the actual drivable car")
	require(car.get("power_assist_reduction") != null,"actual car exposes drive-power intervention telemetry")
	require(car.get("steering_assist_correction") != null,"actual car exposes yaw intervention telemetry")
	car.set("assists_enabled",false)
	require(not bool(car.get("assists_enabled")),"developers can disable aids for unassisted driving")
	car.queue_free()
	print("HORIZON R5 NATIVE: %d passed, %d failed" % [checks-failures,failures])
	quit(0 if failures==0 else 1)
