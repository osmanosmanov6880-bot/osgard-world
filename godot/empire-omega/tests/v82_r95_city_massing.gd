extends SceneTree
## R95 city vertical skyline massing: same roads, locations and RNG cardinality.
const MASSING = preload("res://scripts/horizon_r95_city_massing.gd")
var passed := 0
var failed := 0

func check(ok: bool,why: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		push_error("R95 HEIGHT MASSING FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var boundaries: Dictionary = MASSING.BOUNDS
	check(boundaries.size()==4,"four existing playable districts remain")
	for district in boundaries:
		var limits: Vector2 = boundaries[district]
		for i in range(101):
			var sample: float = float(i)/100.0
			var height: float = MASSING.height_for(str(district),sample,i%8,i/8,i%2)
			check(is_finite(height) and height>=limits.x and height<=limits.y,
				"source-grounded tower height is within gameplay bounds")
			check(height==MASSING.height_for(str(district),sample,i%8,i/8,i%2),
				"fixed original seed must produce deterministic silhouettes")
	check(MASSING.height_for("forum",0.80,0,0,0)>=54.0,
		"modern forum supports actual skyline buildings, not old 8–35m-only blocks")
	check(MASSING.height_for("lower",1.0,0,0,0)<=30.0,
		"historic lower quarter retains hierarchy and navigation context")
	check(MASSING.height_for("forum",NAN,0,0,0)>25.0,
		"bad external data fails closed without NaN geometry")
	check(MASSING.passes_mobile_budget(),"bounded WebGL 3D window instance cost")
	check(MASSING.predicted_window_limit(128)<=30000,
		"existing two GPU instancing batches stay bounded")
	var actual_world: String = FileAccess.get_file_as_string("res://scripts/world_builder.gd")
	check(actual_world.contains("R95_MASSING.height_for(id,rng.randf(),ix,iz,n)"),
		"actual game city uses approved vertical massing")
	check(actual_world.contains("_box(chunk,\"Building_%03d\""),
		"native static-building collision remains the original gameplay authority")
	check(actual_world.contains("ROAD_INTERVAL"),
		"original physical road network is not replaced by image-based geometry")
	print("EMPIRE Omega R95 playable city vertical silhouette: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
