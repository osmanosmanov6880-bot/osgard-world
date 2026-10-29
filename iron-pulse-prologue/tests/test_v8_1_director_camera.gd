extends SceneTree
## V8.1 source-bound, live Godot camera / procedural plasma validation.
## The actual reactor is viewed from an authored physical security camera, not
## a pre-rendered image, fake screenshot or teleported player.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)

func _key(game: Node, code: Key) -> void:
    var input := InputEventKey.new()
    input.keycode = code
    input.pressed = true
    game._input(input)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null, "Actual Godot player scene remains loadable")
    if packed == null:
        _finish()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var atrium: IPReactorAtrium = game.reactor_atrium
    var camera: Camera3D = atrium.director_camera
    _check(camera != null and camera.name == "A7_ServiceObservationCamera",
        "A second actual in-world security Camera3D exists")
    _check(camera != null and camera.is_inside_tree(), "Director camera belongs to real render scene")
    if camera != null:
        _check(camera.global_position.x > 0.0 and camera.global_position.x < 6.4,
            "The camera is physically mounted INSIDE the player-accessible gallery")
        _check(camera.global_position.z < -9.0 and camera.global_position.z > -31.0,
            "Real camera faces the authentic 22m reactor viewing aperture")
        var view_ray: Vector3 = (IPReactorAtrium.CORE_CENTER-camera.global_position).normalized()
        _check((-camera.global_transform.basis.z).dot(view_ray) >= 0.995,
            "The security camera is framed onto the actual industrial reactor")
    _check(game.reactor_core.material_override is ShaderMaterial,
        "Live playable reactor sphere has GPU original plasma shader material")
    _check(game.reactor_core.material_override == atrium.core_plasma_material,
        "Shader comes from mounted cinematic environment, not a fake texture")
    _check(atrium.core_plasma_material.shader.code.contains("smoothstep"),
        "Author-created procedural turbulence shader exists on GPU")
    _check(atrium.core_plasma_material.shader.code.contains("thermal_bias"),
        "Dynamic emergency temperature directly affects material coloring")
    _check(atrium.readout()["security_director_camera"] and atrium.readout()["plasma_shader_live"],
        "QA readout exposes real security camera and live shader")

    atrium.update_alarm("thermal",96.0,80.0,10.0,false)
    var heat_bias: float = float(atrium.core_plasma_material.get_shader_parameter("thermal_bias"))
    var heat_phase: float = float(atrium.core_plasma_material.get_shader_parameter("motion_clock"))
    _check(heat_bias >= 0.99 and heat_phase > 0.0,
        "HEAT emergency makes plasma red and animated, not a blue static ball")
    _check(float(atrium.core_plasma_material.get_shader_parameter("crisis")) >= 0.85,
        "GPU receives high risk value from true thermal simulation")
    atrium.update_alarm("breach",48.0,15.0,21.0,true)
    _check(float(atrium.core_plasma_material.get_shader_parameter("thermal_bias")) <= 0.01,
        "Low-oxygen AIR scenario shifts reactor back to cool emergency spectrum")
    _check(is_equal_approx(float(atrium.core_plasma_material.get_shader_parameter("motion_clock")),heat_phase),
        "Reduced-motion accessibility stops shader turbulence animation")
    atrium.update_alarm("breach",48.0,15.0,52.0,true)
    _check(is_equal_approx(float(atrium.core_plasma_material.get_shader_parameter("motion_clock")),heat_phase),
        "Changing elapsed time cannot restart animation while motion reduction is active")

    game._select_scenario("thermal")
    game.start_run()
    var original_pos: Vector3 = game.player.position
    var initial_sim: Dictionary = game.session.checkpoint()
    _check(game.get_viewport().get_camera_3d() == game.camera,
        "First-person camera is the active view during normal gameplay")
    _key(game,KEY_C)
    _check(game.cinematic_view and game.get_viewport().get_camera_3d() == camera,
        "Actual C key switches the real viewport to the reactor security camera")
    _check(not game.header_panel.visible and not game.side_panel.visible and not game.vitals_panel.visible,
        "Reactor view is clear of gameplay HUD overlays")
    _check(game.session.scenario_id == "thermal" and game.session.objective_id() == "scan",
        "Switching cameras cannot advance, reset or skip mission objectives")
    _check(game.player.position == original_pos and game.session.checkpoint() == initial_sim,
        "Camera switch NEVER teleports player or mutates resources/time")
    _key(game,KEY_C)
    _check(not game.cinematic_view and game.get_viewport().get_camera_3d() == game.camera,
        "Second C returns to the original gameplay Camera3D")
    _check(game.header_panel.visible and game.side_panel.visible,
        "Full actual mission guidance is restored on return")
    _check(game.player.position == original_pos and game.session.checkpoint() == initial_sim,
        "Returning from camera never modifies checkpoint or simulation")

    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned and game.story.latest_key == "scan",
        "Real scanner and original MARA story still operate after cinema mode")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V8.1 DIRECTOR CAMERA PASS: %d source-bound Godot checks" % checks)
        quit(0)
    else:
        for message in failures:
            push_error("V8.1 DIRECTOR FAIL: "+message)
        quit(1)
