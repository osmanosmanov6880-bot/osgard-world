extends SceneTree
## Actual V8.2 camera-art gate: important physical objects may NOT hide
## the authored moving 3D reactor from the genuine mounted camera.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, description: String) -> void:
    checks += 1
    if not ok:
        failures.append(description)

func _run() -> void:
    var loaded: PackedScene = load("res://Main.tscn")
    _check(loaded != null, "Actual Godot game remains importable")
    if loaded == null:
        _finish()
        return
    var game = loaded.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var vault: IPReactorAtrium = game.reactor_atrium
    var world: IPWorldSectors = game.world_sectors
    var director: Camera3D = vault.director_camera
    _check(vault != null and world != null and director != null,
        "Art gate operates on real scene, not a diagram")
    var bridge: MeshInstance3D = world.get_node_or_null("HERO_SectorGeometry/GalleryCatwalkBeam") as MeshInstance3D
    var ribbon: MeshInstance3D = world.get_node_or_null("HERO_SectorGeometry/GalleryObservationRibbon") as MeshInstance3D
    var coolant: MeshInstance3D = world.get_node_or_null("HERO_SectorGeometry/GalleryCoolantDrum_R") as MeshInstance3D
    var board: MeshInstance3D = vault.get_node_or_null("PermanentShell/ObservationHeaderPanel") as MeshInstance3D
    _check(bridge != null and ribbon != null and coolant != null and board != null,
        "Original scenic objects are preserved as actual 3D meshes")
    if bridge != null:
        _check(bridge.position.x < -2.0 and (bridge.mesh as BoxMesh).size.x <= 3.5,
            "Old full-width gallery beam cannot dominate security-camera composition")
    if ribbon != null:
        _check(ribbon.position.x < -2.0 and (ribbon.mesh as BoxMesh).size.x < 3.5,
            "Oversized cyan ribbon no longer cuts across reactor")
    if coolant != null:
        _check(coolant.position.x > 15.0 and coolant.position.z > -16.0,
            "Coolant drum moved to meaningful far mechanical service corner")
        _check(coolant.mesh is CylinderMesh, "Actual original coolant drum retains mechanical cylinder geometry")
    if board != null:
        _check(board.position.x > 17.0 and board.position.y > 12.0,
            "Warning sign panel relocated from foreground to far upper vault wall")
        _check((board.mesh as BoxMesh).size.z >= 6.0,
            "Full original reactor warning sign still exists and remains readable")
    var sign: Label3D = vault.get_node_or_null("PermanentShell/WarningMain") as Label3D
    _check(sign != null and sign.position.x > 17.0,
        "Diegetic A7 signage is still physically present without blocking the view")

    var from_camera: Vector3 = director.global_position
    var to_core: Vector3 = game.reactor_core.global_position
    var core_ray: Vector3 = (to_core-from_camera).normalized()
    _check((-director.global_transform.basis.z).dot(core_ray) > 0.995,
        "Camera still looks directly at the REAL illuminated 3D core")
    _check(game.reactor_core.material_override == vault.core_plasma_material,
        "Core still uses live, heat-aware procedural GPU plasma")
    # The old large obstructions must lie outside the camera->core segment.
    var max_x: float = maxf(from_camera.x,to_core.x)
    _check(bridge == null or bridge.position.x < from_camera.x-2.0,
        "Former gallery catwalk lies outside camera-to-core ray")
    _check(coolant == null or coolant.position.x > max_x+2.0,
        "Cooling machinery is BEYOND core instead of directly in front")
    _check(board == null or board.position.x > max_x+2.0,
        "Decorative sign is BEHIND core, not between camera and sphere")

    game._select_scenario("thermal")
    game.start_run()
    var prior_state: Dictionary = game.session.checkpoint()
    var prior_pos: Vector3 = game.player.position
    var event := InputEventKey.new()
    event.keycode = KEY_C
    event.pressed = true
    game._input(event)
    _check(game.get_viewport().get_camera_3d() == director and game.cinematic_view,
        "Pressing C displays physically unobstructed reactor observation shot")
    _check(game.session.checkpoint() == prior_state and game.player.position == prior_pos,
        "Art-direction camera still never mutates the emergency/gameplay")
    game._input(event)
    _check(game.get_viewport().get_camera_3d() == game.camera and not game.cinematic_view,
        "Returning to first-person resumes exact original play state")
    _check(game.session.checkpoint() == prior_state,
        "Cinematics never cheat player mission time or damage")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V8.2 CLEAR SIGHTLINES PASS: %d source-bound Godot checks" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error("V8.2 ART FAIL: " + failure)
        quit(1)
