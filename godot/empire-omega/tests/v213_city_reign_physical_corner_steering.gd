extends SceneTree
## R188 native source: direction-aligned physical turning, wet traction,
## no 90° sideways instant motion, true original 9x9 asphalt geometry.
const STEER=preload("res://scripts/city_reign_physical_corner_steering.gd")
const LANE=preload("res://scripts/city_reign_vehicle_lane_routing.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R188 ACTUAL SOURCE PHYSICAL STEERING FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(STEER.source_integrity() and LANE.source_integrity(),
		"true original 9x9 road, 52m source legs, 2m right lane and actual 2.25m physics car")
	check(is_equal_approx(STEER.yaw_of(Vector3.RIGHT),-PI/2.0) and
		is_equal_approx(STEER.yaw_of(Vector3.BACK),PI),
		"native -Z forward Godot chassis consistently faces actual X and Z 3D route direction")
	var start:=Vector3(-110,0.8,-154)
	var turn:=Vector3(-106,0.8,-154)
	var onward:=Vector3(-106,0.8,-104)
	var expected: Vector3=STEER.source_aim(start,turn,onward)
	check(expected.z>turn.z and expected.z<turn.z+2.35 and
		STEER.source_road_footprint_safe(expected),
		"real 90 degree right-hand turn is anticipated within original paved junction")
	check(STEER.source_aim(Vector3(-126,0.8,-154),turn,onward)==turn and
		STEER.source_aim(start,turn,Vector3(-54,0.8,-154))==turn,
		"remote/straight real AStar points do not invent an imaginary curved shortcut")
	check(STEER.source_aim(start,turn,start)==turn and
		STEER.source_aim(start,turn,Vector3(NAN,0,0))==turn,
		"source U turn and non-finite next waypoint fail safely to original AStar")
	var result: Dictionary=STEER.steer(-PI/2.0,start,expected,6.0,0.1,1.0)
	check(result.get("valid",false) and
		float(result["actual_yaw_step"])>0.0 and
		float(result["actual_yaw_step"])<0.20 and
		absf((result["direction"] as Vector3).length()-1.0)<0.001,
		"real physical yaw turns gradually toward next native road segment, not instantly 90 degrees")
	var facing:=Vector3(-sin(float(result["yaw"])),0,-cos(float(result["yaw"])))
	check(facing.distance_to(result["direction"])<0.0001,
		"the real 3D chassis forward AND native physical velocity share the same yaw")
	check(absf(float(result["wheel_radians"]))<=STEER.MAX_FRONT_WHEEL_RAD and
		float(result["wheel_radians"])>0.01,
		"original existing two front wheel meshes receive genuine bounded corner articulation")
	var dry: Dictionary=STEER.steer(-PI/2.0,start,Vector3(-110,0.8,-145),
		12.0,0.1,1.0)
	var rain: Dictionary=STEER.steer(-PI/2.0,start,Vector3(-110,0.8,-145),
		12.0,0.1,0.4)
	check(dry["valid"] and rain["valid"] and
		float(rain["actual_yaw_step"])<float(dry["actual_yaw_step"]) and
		float(dry["actual_yaw_step"])<=0.20,
		"genuine wet weather reduces attainable real lateral yaw at equal vehicle speed")
	check(STEER.safe_next_step(start,result["direction"],6.0,0.1) and
		STEER.source_road_footprint_safe(start),
		"car's FULL 2.25m original collision chassis stays inside actual city asphalt through gradual turn")
	var edge:=Vector3(-99.2,0.8,-151.2)
	check(LANE.on_original_asphalt(edge) and
		not STEER.source_road_footprint_safe(edge),
		"centre in asphalt is insufficient: native BoxShape half-width must fit before allowing motion")
	check(not STEER.safe_next_step(edge,Vector3.RIGHT,8.0,0.1),
		"road-edge failure refuses physical movement, never clipping native collision into sidewalk")
	check(not STEER.steer(NAN,start,turn,6.0,0.1,1.0)["valid"] and
		not STEER.steer(0,start,turn,6.0,NAN,1.0)["valid"] and
		not STEER.safe_next_step(start,Vector3(NAN,0,0),6.0,0.1),
		"invalid road physics and corrupted browser frame cannot invent a steering command")
	var huge: Dictionary=STEER.steer(-PI/2.0,start,Vector3(-110,0.8,-145),
		12.0,3.0,1.0)
	check(float(huge["actual_yaw_step"])<=
		STEER.MAX_YAW_RATE_RAD_S*STEER.MAX_FRAME_STEP_S+0.0001,
		"backgrounded browser frame cannot instantly rotate physical traffic chassis")
	print("CITY REIGN R188 TRUE ORIGINAL TRAFFIC STEERING PURE: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
