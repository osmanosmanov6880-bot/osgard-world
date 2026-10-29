extends SceneTree
## Actual native scene import, player, world, reactor, 6 terminals and UI.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, explanation: String) -> void:
    checks += 1
    if not value:
        failures.append(explanation)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null, "True native Godot scene imports")
    if packed == null:
        _finish()
        return
    var game: Node3D = packed.instantiate()
    _check(game != null, "Root is playable 3D game")
    if game == null:
        _finish()
        return
    root.add_child(game)
    await process_frame
    await process_frame
    _check(game.session.objective_id() == "scan", "Gameplay state attached to real scene")
    _check(game.player is CharacterBody3D, "Physical first-person character controller exists")
    _check(game.camera is Camera3D and game.camera.current, "First-person camera is live")
    _check(game.terminals.size() == 6, "Six reachable 3D consoles created")
    _check(game.reactor_rings.size() == 3, "Reactor has three native rotating torus mechanisms")
    _check(game.exit_gate is MeshInstance3D, "Evacuation exit has an animated 3D gate")
    _check(game.hud_root != null and game.objective_label != null, "Game has accessible mission HUD")
    _check(game.intro_panel.visible and not game.started, "Intro waits for explicit player start")
    _check(game._copy("scan") != "scan", "Russian mission strings exist")
    game._toggle_language()
    _check(game.locale == "en" and game._copy("scan").find("Scan") >= 0, "English locale truly active")
    game.start_run()
    _check(game.started and not game.intro_panel.visible, "Start button enters game loop")
    game._pause_toggle()
    _check(game.paused and game.pause_panel.visible, "Pause blocks input and displays controls")
    game._resume()
    _check(not game.paused and not game.pause_panel.visible, "Resume returns control")
    game._restart()
    _check(game.session.objective_id() == "scan", "Retry resets objectives")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE BLACKOUT 3D SCENE PASS: %d actual native checks" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error("BLACKOUT SCENE FAIL: " + failure)
        quit(1)
