extends SceneTree
const TELEMETRY = preload("res://scripts/horizon_compact_telemetry.gd")
var passed := 0
var failed := 0
func check(ok: bool, message: String) -> void:
    if ok: passed += 1
    else:
        failed += 1
        push_error("HORIZON R8 FAILED: "+message)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    for locale in ["ru","en","zh","unknown"]:
        var line: String = TELEMETRY.speed_lines(22.0,"D",78.0,89.0,false,0,0.0,0.0,locale)
        check(line.split("\n").size()==2,"exactly two lines "+locale)
        check(line.contains("79"),"speed shown "+locale)
    check(TELEMETRY.speed_lines(18.0,"D",20.0,55.0,true,50,0.8,0.4,"ru").contains("РУЧНИК"),"handbrake takes priority")
    check(TELEMETRY.speed_lines(18.0,"D",20.0,55.0,false,50,0.8,0.4,"en").contains("DRIFT"),"drift feedback priority")
    check(TELEMETRY.speed_lines(18.0,"D",20.0,55.0,false,0,0.2,0.0,"en").contains("GRIP"),"actual traction aid visible")
    check(TELEMETRY.speed_lines(18.0,"D",20.0,55.0,false,0,0.0,0.0,"ru").contains("Т20%"),"fuel visible at rest")
    check(TELEMETRY.speed_lines(18.0,"D",20.0,55.0,false,0,0.0,0.0,"ru").contains("К55%"),"condition visible at rest")
    check(TELEMETRY.speed_lines(-18.0,"R",20.0,55.0,false,0,0.0,0.0,"ru").begins_with("65"),"reverse speed absolute")
    var hud: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
    check(hud.contains("COMPACT_TELEMETRY.speed_lines"),"live HUD uses bounded mobile formatter")
    check(hud.contains("volume_slider.custom_minimum_size = Vector2(0,44)"),"settings use fluid width")
    check(hud.contains("if map_panel != null and map_panel.visible: map.queue_redraw()"),"hidden minimap skips draw")
    print("HORIZON R8 MOBILE HUD NATIVE: %d passed, %d failed" % [passed,failed])
    quit(0 if failed==0 else 1)
