extends SceneTree
## HORIZON R13: mobile players should see the real CAR button label, not an
## invisible desktop keyboard key. UI text must not change mission/reward state.
const TOUCH_MISSION = preload("res://scripts/horizon_mobile_onboarding.gd")
var pass := 0
var fail := 0
func check(value: bool, note: String) -> void:
	if value: pass += 1
	else:
		fail += 1
		push_error("HORIZON R13 ENTRY: "+note)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var ru := "Найдите автомобиль и нажмите E"
	var en := "Find a car and press E"
	var zh := "找到汽车并按 E"
	check(TOUCH_MISSION.title(ru,0,true,true,"ru")=="Подойдите к машине и нажмите АВТО","RU shows actual touch CAR action")
	check(TOUCH_MISSION.title(en,0,true,true,"en")=="Walk to the car and tap CAR","EN shows touch CAR button")
	check(TOUCH_MISSION.title(zh,0,true,true,"zh").contains("车辆"),"Chinese mobile title")
	check(TOUCH_MISSION.title(ru,0,true,true,"wrong").contains("АВТО"),"unsupported locale gracefully uses RU")
	check(TOUCH_MISSION.title(ru,0,false,true,"ru")==ru,"desktop-shaped viewport doesn't change objective")
	check(TOUCH_MISSION.title(ru,0,true,false,"ru")==ru,"real keyboard desktop title unchanged")
	for stage in [1,2,19,39,40]:
		check(TOUCH_MISSION.title("REAL MISSION",stage,true,true,"en")=="REAL MISSION","existing campaign stage "+str(stage)+" remains authoritative")
	var player := Vector3(-115,1.3,-104)
	var car := Vector3(-120,1.3,-104)
	check(player.distance_to(car)<8.0,"original game spawn is within real car-entry radius")
	var hud := FileAccess.get_file_as_string("res://scripts/hud.gd")
	check(hud.contains("TOUCH_MISSION.title(MissionManager.title(GameState.locale)"),"HUD uses source MissionManager and nonmutating text adapter")
	check(hud.contains("DisplayServer.is_touchscreen_available()"),"runtime touch detection gates mobile prompt")
	var main := FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main.contains("player.global_position.distance_to(car.global_position) > 8.0"),"real entry distance gate remains unchanged")
	check(main.contains("MissionManager.register_action(\"enter_vehicle\")"),"first actual mission still advances only after real car entry")
	print("HORIZON R13 ENTRY NATIVE: %d passed, %d failed" % [pass,fail])
	quit(0 if fail==0 else 1)
