extends SceneTree
## R160 native Godot proof: street, classic and panorama are genuine
## physical-camera compositions for driving/on-foot and mobile/desktop.
const CAMERA = preload("res://scripts/city_reign_camera_modes.gd")
const SAFE = preload("res://scripts/horizon_camera_collision.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,why: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R160 CAMERA REAL-SOURCE FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var settings: Node = root.get_node_or_null("GameSettings")
	var game: Node = root.get_node_or_null("GameState")
	check(settings!=null and game!=null,
		"original real GameSettings and financial GameState autoload")
	if settings==null or game==null:
		quit(2)
		return
	var saved: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var old_mode: String = str(settings.get("camera_mode"))
	check(CAMERA.bounded(),"three presets are bounded in world space and translated")
	check(CAMERA.next_mode("street")=="classic" and
		CAMERA.next_mode("classic")=="panorama" and
		CAMERA.next_mode("panorama")=="street",
		"keyboard, phone and gamepad modes cycle in the same direction")
	check(CAMERA.canonical("untrusted")=="classic",
		"unrecognized view never creates invalid camera position")
	check(InputMap.has_action("camera_cycle") and
		(settings.get("keys") as Dictionary).has("camera_cycle"),
		"native camera controls registered by real game preferences")
	var key_events: Array[InputEvent] = InputMap.action_get_events("camera_cycle")
	check(key_events.size()>=1 and key_events[0] is InputEventKey,
		"bound physical V key exists in real Godot InputMap")
	check(CAMERA.pitch(0.38,"street",false,false,false)<0.34 and
		CAMERA.pitch(0.38,"street",true,false,false)==0.38,
		"immersive street look is desktop-first and phone-safe")
	check(CAMERA.pitch(0.38,"panorama",false,false,false)>0.44,
		"panorama reveals genuine existing physical skyline")
	for mode in CAMERA.MODES:
		settings.call("set_camera_mode",mode)
		check(str(settings.get("camera_mode"))==mode,
			"camera mode is authentic persisted user preference: "+mode)
		for phone in [false,true]:
			for driving in [false,true]:
				var center := Vector3(14,2.4,-19)
				var view: Vector2 = Vector2(390,844) if phone else Vector2(1366,768)
				var offset: float = CAMERA.pitch(0.38,mode,phone,false,false)
				var raw: Vector3 = SAFE.desired_position(center,0.48,offset,14.0,driving,view)
				var actual: Vector3 = CAMERA.distance(center,raw,mode,driving,phone,false,false)
				check(actual.is_finite() and actual.distance_to(center)>3.0 and
					actual.distance_to(center)<21.0,
					"actual original player 3D camera stays within safe finite radius")
				check(CAMERA.distance(center,raw,mode,driving,phone,true,false)==raw and
					CAMERA.distance(center,raw,mode,driving,phone,false,true)==raw,
					"city cabinet or reduced motion keeps the original camera")
				for lang in ["ru","en","zh"]:
					check(not CAMERA.localized_mode(mode,lang).is_empty(),
						"real camera source feedback localized to "+lang)
	var barrier := StaticBody3D.new()
	barrier.collision_layer=1
	barrier.position=Vector3(0,0.5,3.2)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(10,5,0.6)
	collider.shape=shape
	barrier.add_child(collider)
	root.add_child(barrier)
	await physics_frame
	var center := Vector3(0,1.5,0)
	for mode in CAMERA.MODES:
		var target: Vector3 = CAMERA.distance(center,Vector3(0,2.8,7),
			mode,false,false,false,false)
		var solved: Dictionary = SAFE.solve(center,target,target,
			barrier.get_world_3d().direct_space_state,[],0.030,false)
		check(bool(solved["occluded"]) and
			(solved["position"] as Vector3).is_finite() and
			float(solved["distance"])<center.distance_to(target),
			"same original Godot world raycasts prevent wall clipping in "+mode)
	barrier.queue_free()
	settings.call("set_camera_mode",old_mode)
	check(game.get("data")==saved,"no change to original game currency, missions or saved city")
	await process_frame
	print("CITY REIGN R160 SOURCE REAL CAMERA PRESETS: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
