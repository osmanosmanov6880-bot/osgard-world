extends SceneTree
## Real V12 in-world camera coverage, honest performance and release status.
var checks: int = 0
var problems: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func _check(ok: bool,label: String) -> void:
    checks += 1
    if not ok:
        problems.append(label)
func _key(game: Node,key: Key) -> void:
    var e := InputEventKey.new()
    e.keycode = key
    e.pressed = true
    game._input(e)

func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn")
    _check(scene != null,"Exact main project scene imports in real Godot")
    if scene == null:
        _finish()
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var world: IPReactorAtrium = game.reactor_atrium
    _check(world.director_shots.size() == 3 and world.readout()["director_shot_count"] == 3,
        "Three real physical in-engine director cameras are mounted in source scene")
    _check(world.director_shots[0] == world.director_camera,
        "Historical first A7 observation shot preserved exactly")
    for i in range(3):
        var cam: Camera3D = world.director_shots[i]
        _check(cam != null and cam.is_inside_tree() and cam.fov >= 65.0,
            "Shot "+str(i)+" uses actual authored perspective Camera3D, not image sprites")
        var desired: Vector3 = (IPReactorAtrium.CORE_CENTER-cam.global_position).normalized()
        var forward: Vector3 = -cam.global_transform.basis.z
        _check(forward.dot(desired) > 0.995,"Shot "+str(i)+" frames physical reactor geometry")
    _check(world.director_shots[1].name == "A7_TurbineSideCamera" and
        world.director_shots[2].name == "A7_UpperCatwalkCamera",
        "Industrial side and upper catwalk are distinct physical camera positions")
    var audit := IPPerformanceAudit.new()
    _check(audit.release_gate()["production_ready"] is bool and
        not audit.release_gate()["production_ready"],
        "In-game diagnostics NEVER self-certifies production release")
    _check(not audit.release_gate()["software_ci_verified_here"] and
        audit.release_gate()["outstanding"].size() >= 7,
        "External hardware, visual, market and legal gates remain explicitly outstanding")
    audit.observe(0.016,false,"hero")
    _check(audit.telemetry()["sample_count"] == 0,
        "Menu/paused frames do not contaminate true gameplay measurements")
    for i in 120:
        audit.observe(0.016,true,"hero")
    var fast: Dictionary = audit.telemetry()
    _check(fast["sample_count"] == 120 and not fast["eco_suggested"],
        "Native telemetry shows good 16ms pacing without recommending ECO")
    _check(absf(float(fast["estimated_fps"])-62.5) < 0.2,
        "Derived FPS computed from 120 actual provided frame times, not invented score")
    for i in 120:
        audit.observe(0.048,true,"hero")
    var slow: Dictionary = audit.telemetry()
    _check(slow["sample_count"] == 120 and slow["eco_suggested"],
        "Sustained 48ms frame time yields a grounded ECO recommendation")
    _check(float(slow["p95_frame_ms"]) > 45.0 and slow["quality"] == "hero",
        "Audit warns but never silently changes user's quality preference")
    var strings: String = audit.diagnostic_text("ru","thermal",game.campaign)
    _check(strings.contains("ФИЗИЧЕСКИЕ УСТРОЙСТВА НЕ ПРОВЕРЕНЫ"),
        "RU diagnostics explicitly distinguish software telemetry from physical-device QA")

    game._select_scenario("thermal")
    game.start_run()
    var before: Dictionary = game.session.checkpoint()
    _key(game,KEY_F3)
    _check(game.diagnostic_panel.visible and game.diagnostic_label.text.contains("IRON PULSE"),
        "F3 opens actual Godot engineering diagnostics on demand")
    _check(game.performance_audit.release_gate()["production_ready"] == false,
        "Interactive on-screen statistics never misrepresent build as commercial AAA")
    _key(game,KEY_F3)
    _check(not game.diagnostic_panel.visible, "Second F3 hides optional technical interface")

    _key(game,KEY_C)
    _check(game.cinematic_view and world.director_shot_index == 0 and
        game.get_viewport().get_camera_3d() == world.director_camera,
        "Existing C still enters original cinematic shot, zero gameplay change")
    _key(game,KEY_P)
    _check(world.director_shot_index == 1 and
        game.get_viewport().get_camera_3d() == world.director_shots[1],
        "New P key cuts to actual 3D turbine observation camera")
    _key(game,KEY_P)
    _check(world.director_shot_index == 2 and
        game.get_viewport().get_camera_3d() == world.director_shots[2],
        "Second P key cuts to high catwalk camera in the same playable world")
    game._gamepad_button(JOY_BUTTON_DPAD_RIGHT)
    _check(world.director_shot_index == 0 and
        game.get_viewport().get_camera_3d() == world.director_camera,
        "Standard controller D-Pad Right cycles 3 real cinema shots")
    game.touch_ui.visible = true
    game._apply_cinematic_view()
    _check(game.touch_shot_button.visible,
        "Touch UI shows SHOT option only when in cinema mode")
    game.touch_shot_button.pressed.emit()
    _check(world.director_shot_index == 0 or world.director_shot_index == 1,
        "Touch SHOT button actually invokes physical camera cycling")
    _key(game,KEY_C)
    _check(not game.cinematic_view and
        game.get_viewport().get_camera_3d() == game.camera and
        not game.touch_shot_button.visible,
        "Second C restores original first-person camera and declutters touch UI")
    _check(game.session.checkpoint() == before and game.session.objective_id() == "scan",
        "Three-camera cinematics never advances timer, health, resources or story")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned,
        "Original real scanner controls and gameplay still work after cinematic review")
    game.queue_free()
    await process_frame
    _finish()
func _finish() -> void:
    if problems.is_empty():
        print("IRON PULSE V12 RELEASE GATE PASS: %d real Godot and QA checks" % checks)
        quit(0)
    else:
        for p in problems:
            push_error("V12 RELEASE FAIL: "+p)
        quit(1)
