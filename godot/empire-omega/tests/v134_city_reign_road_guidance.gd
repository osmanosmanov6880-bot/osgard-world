extends SceneTree
## R161: actual road geometry must be finite, bounded, truthful and cullable.
const GUIDANCE = preload("res://scripts/city_reign_road_guidance.gd")
const ROUTER = preload("res://scripts/street_router.gd")
var passed := 0
var failed := 0

func check(ok: bool,why: String) -> void:
    if ok:
        passed+=1
    else:
        failed+=1
        push_error("CITY REIGN R161 ROAD GUIDANCE FAIL: "+why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Node = root.get_node_or_null("GameState")
    check(game!=null,"original financial GameState autoload is present")
    if game==null:
        quit(2)
        return
    var guide: MeshInstance3D = GUIDANCE.new()
    root.add_child(guide)
    check(guide.mesh==null and not guide.visible,"no fabricated route in free play")
    var a := Vector3(-156,0.8,-156)
    var b := Vector3(-52,0.8,-156)
    var route: Array[Vector3] = ROUTER.find_route(a,b,game.get("data"))
    check(route.size()>2,"genuine closure-aware road solver provides a path")
    guide.call("sync_route",route,a,true,"standard")
    check(guide.visible and guide.mesh!=null,"source route draws real 3D triangles")
    check(int(guide.get("drawn_dashes"))>0 and int(guide.get("drawn_dashes"))<=90,
        "one bounded draw with no long repeated GPU path")
    if guide.mesh != null:
        check(guide.mesh.get_surface_count()==1,"one actual geometry draw surface")
        var verts: PackedVector3Array = guide.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
        check(verts.size()==int(guide.get("drawn_dashes"))*6,
            "real asphalt dashes are two triangles each")
        var grounded := true
        for p in verts:
            if not p.is_finite() or absf(p.y-GUIDANCE.SURFACE_HEIGHT)>0.001:
                grounded=false
        check(grounded,"every rendered dash hugs the genuine road plane")
    check(not GUIDANCE.is_road_segment(Vector3(104,0,104),Vector3(130,0,130)),
        "destination off asphalt never draws false shortcut across buildings")
    check(not GUIDANCE.is_road_segment(Vector3(NAN,0,0),Vector3.ZERO),
        "bad coordinates never render geometry")
    var builds: int = guide.get("build_count")
    guide.call("set_quality","low")
    check(guide.visible and int(guide.get("build_count"))==builds,
        "quality changes only paint, never rebuild a road mesh")
    guide.call("sync_route",route,a,false,"cinematic")
    check(not guide.visible and guide.mesh==null,"governance/non-spatial missions immediately hide guidance")
    var none: Array[Vector3] = [a]
    guide.call("sync_route",none,a,true,"standard")
    check(guide.mesh==null,"disconnected route does not invent a path")
    var master: Script = load("res://scripts/main.gd")
    check(master!=null and master.can_instantiate(),"real 3D playable world compiles")
    check(FileAccess.get_file_as_string("res://scripts/main.gd").contains("road_guidance.sync_route("),
        "original live playable game consumes its REAL mapped route")
    guide.queue_free()
    await process_frame
    print("CITY REIGN R161 REAL ROAD GUIDANCE: %d PASS %d FAIL" % [passed,failed])
    quit(0 if failed==0 else 1)
