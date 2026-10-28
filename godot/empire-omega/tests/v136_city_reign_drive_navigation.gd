extends SceneTree
## R162 native proof: source-bound real graph routes, honest distances and
## headings, invalid coordinate fail closed, NO mission/credit mutations.
const NAV = preload("res://scripts/city_reign_drive_navigation.gd")
const ROUTER = preload("res://scripts/street_router.gd")
const GUIDE = preload("res://scripts/city_reign_road_guidance.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,why: String) -> void:
    if ok: passed+=1
    else:
        failed+=1
        push_error("CITY REIGN R162 NAVIGATION FAIL: "+why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Node = root.get_node_or_null("GameState")
    check(game!=null,"actual finance and mission GameState exists")
    if game==null:
        quit(2)
        return
    var before: Dictionary = (game.get("data") as Dictionary).duplicate(true)
    var start := Vector3(0,0.8,36)
    var route: Array[Vector3] = [
        Vector3(0,0.8,52),Vector3(0,0.8,0),
        Vector3(52,0.8,0),Vector3(52,0.8,-52)
    ]
    var current: Dictionary = NAV.snapshot(route,start)
    check(str(current.get("kind",""))=="right","actual grid corner turn orientation is right")
    check(absf(float(current.get("turn_m",0))-36.0)<0.01,
        "distance to turn is along real 52m street, not Euclidean goal")
    check(absf(float(current.get("remaining_m",0))-140.0)<0.01,
        "correct 2-segment path distance to destination")
    check(NAV.snapshot(route,Vector3(0,0.8,0)).get("kind","")=="right",
        "turn at a genuine road junction is not silently skipped at exactly zero metres")
    check(NAV.snapshot(route,Vector3(0,0.8,-60)).get("kind","")=="off_route",
        "20 metre graph deviation never gives a fake next turn")
    check(NAV.snapshot(route,Vector3(52,0.8,-48)).get("kind","")=="arrival",
        "near actual destination gets arrival state")
    check(NAV.snapshot(route,Vector3(NAN,0,0)).is_empty(),
        "NaN position never guides")
    var invalid: Array[Vector3] = [Vector3.ZERO,Vector3(NAN,0,0)]
    check(NAV.snapshot(invalid,start).is_empty(),"invalid waypoints never guide")
    check(NAV.snapshot([start] as Array[Vector3],start).is_empty(),
        "disconnected road path stays blank")
    check(NAV.localized(current,"ru").contains("НАПРАВО") and
        NAV.localized(current,"en").contains("RIGHT") and
        NAV.localized(current,"zh").contains("右转"),
        "three languages describe real source heading")
    var corridor: Array[Vector3] = ROUTER.find_route(Vector3(-156,0.8,-156),
        Vector3(156,0.8,-156),before)
    check(corridor.size()>2 and GUIDE.is_road_segment(corridor[1],corridor[2]),
        "original closure-aware graph supplies authentic road sections")
    var actual: Dictionary = NAV.snapshot(corridor,Vector3(-156,0.8,-156))
    check(not actual.is_empty() and actual.get("kind","")!="off_route",
        "navigation follows actual saved street graph")
    var source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
    check(source.contains("DRIVE_NAV.snapshot(") and source.contains("hud.map.route"),
        "actual player-driven main scene consumes SAME minimap polyline")
    var hud: Variant = load("res://scripts/hud.gd")
    check(hud is Script and hud.can_instantiate(),"original HUD still compiles with real turn by turn")
    check(game.get("data")==before,"routing does not change finances, missions, save state")
    print("CITY REIGN R162 NATIVE ROUTE INTEGRITY: %d PASS 0 FAIL" % passed if failed==0 else
        "CITY REIGN R162 NATIVE ROUTE INTEGRITY: %d PASS %d FAIL" % [passed,failed])
    quit(0 if failed==0 else 1)
