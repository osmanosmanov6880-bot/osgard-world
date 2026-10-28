extends SceneTree
const CHEVRON = preload("res://scripts/city_reign_route_chevron.gd")
const NAV = preload("res://scripts/city_reign_drive_navigation.gd")
const ROAD = preload("res://scripts/city_reign_road_guidance.gd")
var passed := 0
var failed := 0

func check(ok: bool,why: String) -> void:
    if ok: passed+=1
    else:
        failed+=1
        push_error("R163 REAL ASPHALT CHEVRON FAIL: "+why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var mark: MeshInstance3D = CHEVRON.new()
    root.add_child(mark)
    check(mark.mesh!=null and mark.mesh.get_surface_count()==1,
        "real Godot MeshInstance3D uses just one native road surface")
    var geometry: PackedVector3Array = mark.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    check(geometry.size()==9,"one 3-triangle arrow with no remote assets")
    var route: Array[Vector3] = [Vector3(0,0.8,52),Vector3(0,0.8,0),
        Vector3(52,0.8,0),Vector3(52,0.8,-52)]
    var turn: Dictionary = NAV.snapshot(route,Vector3(0,0.8,40))
    check(str(turn.get("kind",""))=="right" and turn.has("turn_world"),
        "arrow reads genuine source route turn location")
    mark.call("show_from_route",route,Vector3(0,0.8,40),"standard",true)
    check(mark.visible and bool(mark.get("active")),
        "physical turn arrow appears at real road junction")
    check(absf(mark.global_position.x-5)<0.1 and absf(mark.global_position.z)<0.1,
        "arrow is placed five metres ON asphalt after the actual junction")
    check(ROAD.is_road_segment(Vector3.ZERO,Vector3(mark.global_position.x,0,mark.global_position.z)),
        "GPS arrow never cuts across mission buildings")
    var builds: int = mark.get("mesh_builds")
    mark.call("set_quality","low")
    check(int(mark.get("mesh_builds"))==builds,
        "mobile quality changes color without geometry allocations")
    mark.call("show_from_route",route,Vector3(0,0.8,40),"standard",false)
    check(not mark.visible and not bool(mark.get("active")),
        "no 3D directions in non-spatial civic missions")
    mark.call("show_from_route",route,Vector3(700,0,700),"standard",true)
    check(not mark.visible,"off-route navigation never paints a false arrow")
    var main: String = FileAccess.get_file_as_string("res://scripts/main.gd")
    check(main.contains("route_chevron.show_from_route(") and
        main.contains("route_chevron.clear_turn()"),
        "actual main game uses same authoritative graph and clears obsolete arrows")
    mark.queue_free()
    await process_frame
    print("CITY REIGN R163 TRUE ROAD WAYFINDING: %d PASS %d FAIL" % [passed,failed])
    quit(0 if failed==0 else 1)
