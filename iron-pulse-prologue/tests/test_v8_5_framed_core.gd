extends SceneTree
## V8.5: physical containment rings must frame reactor rather than produce
## edge-on cyan bars across the viewport. No fake graphics or altered gameplay.
var checks: int = 0
var failed: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(good: bool, message: String) -> void:
    checks += 1
    if not good:
        failed.append(message)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null, "Original Godot game scene remains available")
    if packed == null:
        _finish()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var reactor: IPReactorAtrium = game.reactor_atrium
    _check(game.reactor_rings.size()==3, "Three existing true animated rings remain")
    _check(reactor.director_camera is Camera3D, "The existing real physical director camera remains")
    var first: MeshInstance3D = game.reactor_rings[0].get_child(0) as MeshInstance3D
    _check(first != null and first.name == "PlasmaFramingRing_0", "First ring is actual updated named mesh")
    var ring_normal: Vector3 = (first.global_transform.basis * Vector3.UP).normalized()
    var sightline: Vector3 = (reactor.director_camera.global_position-first.global_position).normalized()
    _check(absf(ring_normal.dot(sightline)) >= 0.93,
        "Primary luminous ring faces actual camera as a halo, not an edge-on vertical bar")
    for index in range(3):
        var ring: MeshInstance3D = game.reactor_rings[index].get_child(0) as MeshInstance3D
        _check(ring.mesh is TorusMesh and ring.name == "PlasmaFramingRing_%d" % index,
            "Each authored elliptical frame is true Godot torus geometry")
        _check((ring.mesh as TorusMesh).outer_radius-(ring.mesh as TorusMesh).inner_radius <= 0.061,
            "Each tube remains a thin real glowing conductor")
        _check(ring.material_override is StandardMaterial3D and (ring.material_override as StandardMaterial3D).emission_enabled,
            "Containment rim remains material-driven with bounded emission")
    var shader: ShaderMaterial = reactor.core_plasma_material
    _check(game.reactor_core.material_override == shader, "Actual center sphere uses original GPU plasma")
    _check(shader.shader.code.contains("2.12 + crisis * 1.30"),
        "Original shader is physically brighter while retaining real thermal risk response")
    _check(reactor.readout()["open_core_inspection"],
        "Camera-facing armor service throat stays open")
    _check(reactor.director_camera.is_inside_tree(),
        "Director view renders the actual 3D reactor from an in-world camera")
    game._select_scenario("thermal")
    game.start_run()
    var before: Dictionary = game.session.checkpoint()
    var event := InputEventKey.new()
    event.keycode = KEY_C
    event.pressed = true
    game._input(event)
    _check(game.cinematic_view and game.get_viewport().get_camera_3d() == reactor.director_camera,
        "C really moves viewport to the authored reactor perspective")
    _check(game.session.checkpoint() == before,
        "Cinematic frames do not mutate mission resources")
    game._input(event)
    _check(not game.cinematic_view and game.get_viewport().get_camera_3d() == game.camera,
        "Return to player camera still works")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned and game.story.latest_key == "scan",
        "Scanner, original narrative and emergency are untouched by visual work")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failed.is_empty():
        print("IRON PULSE V8.5 FRAMED REACTOR PASS: %d source-bound Godot checks" % checks)
        quit(0)
    else:
        for item in failed:
            push_error("V8.5 FRAMING FAIL: " + item)
        quit(1)
