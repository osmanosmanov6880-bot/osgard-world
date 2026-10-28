extends SceneTree
## Native V10 world-anchored objective guidance, localization and save QA.
var count: int = 0
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func _check(ok: bool,message: String) -> void:
    count += 1
    if not ok:
        failures.append(message)
func _key(game: Node,key: Key) -> void:
    var e := InputEventKey.new()
    e.keycode = key
    e.pressed = true
    game._input(e)
func _run() -> void:
    var p: PackedScene = load("res://Main.tscn")
    _check(p != null,"Full native scene remains loadable")
    if p == null:
        _finish()
        return
    var game = p.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var guide: IPWayfinding = game.wayfinder
    _check(guide != null and guide.name == "A7_InWorldObjectiveMarker",
        "Optional 3D objective marker is physically mounted in Godot")
    _check(guide.halo.mesh is TorusMesh and guide.marker is Node3D,
        "Real waypoint is a 3D mesh, never a fake floating HUD image")
    _check(guide._stations.size() == 6,"Six actual physical original terminals are connected to waypoint logic")
    _check(not guide.marker.visible,"No misleading objective beacon on unstarted mission")
    game.start_run()
    game._process(0.016)
    _check(guide.readout()["target"] == "scan" and guide.marker.visible,
        "Real player start shows physically placed reactor scanner objective")
    var terminal: Vector3 = guide._stations["scan"]
    _check(guide.marker.global_position.distance_to(terminal+Vector3(0,2.75,0)) < 0.01,
        "3D marker has genuine source-bound terminal position")
    _check(guide.readout()["distance_m"] > 10.0 and guide.nameplate.text.contains("ЦЕЛЬ"),
        "RU geometry shows distance calculated from actual player location")
    var before: Dictionary = game.session.checkpoint()
    _key(game,KEY_H)
    _check(not guide.enabled and not guide.marker.visible,
        "Player H hides real 3D objective without touching rest of HUD")
    _check(game.session.checkpoint() == before,
        "Wayfinding preference never changes mission resources or timer")
    _key(game,KEY_H)
    game._process(0.016)
    _check(guide.enabled and guide.marker.visible, "Second H restores 3D guidance")
    _key(game,KEY_L)
    game._process(0.016)
    _check(guide.readout()["locale"] == "en" and guide.nameplate.text.contains("OBJECTIVE"),
        "English language toggle truly updates physical world signage")
    _key(game,KEY_V)
    game._process(0.016)
    var calm_scale: float = guide.halo.scale.x
    game._process(12.0)
    _check(game.reduced_motion and is_equal_approx(guide.halo.scale.x,calm_scale),
        "Reduced motion completely freezes optional waypoint pulse")
    _key(game,KEY_G)
    game._process(0.016)
    _check(game.quality_mode == "eco" and guide.nameplate.visible == false and guide.halo.visible,
        "ECO preserves minimalist geometry while reducing text detail")
    _key(game,KEY_G)
    game._process(0.016)
    _check(game.quality_mode == "hero" and guide.nameplate.visible,
        "HERO restores detailed object label")
    _key(game,KEY_C)
    game._process(0.016)
    _check(game.cinematic_view and not guide.marker.visible,
        "Cinematic director camera never has floating navigation marker over hero scene")
    _key(game,KEY_C)
    game._process(0.016)
    _check(not game.cinematic_view and guide.marker.visible,
        "Returning to player camera restores optional waypoint automatically")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    game._process(0.016)
    _check(game.session.core_scanned and guide.readout()["target"] == "repair",
        "Wayfinding genuinely follows the next unlocked original gameplay objective")
    game.player.position = Vector3(3.0,1.1,-28.0)
    game._process(0.016)
    _check(not guide.marker.visible or guide.readout()["distance_m"] <= 3.5,
        "Wayfinding does not overwhelm player with giant marker at the terminal")
    var save_file: String = "user://iron_pulse_v10_wayfinding_ci.json"
    game.checkpoint_path = save_file
    game.checkpoint_store.clear(save_file)
    _key(game,KEY_H)
    _check(game.checkpoint_store.save(game._checkpoint_payload(),save_file),
        "True V10 user settings persist in existing offline validated V6 container")
    guide.enabled = true
    _check(game._continue_checkpoint() and not guide.enabled,
        "Actual original Continue loads saved player preference without regressions")
    _check(game.checkpoint_store.clear(save_file),"No test settings left in actual user slot")
    game.queue_free()
    await process_frame
    _finish()
func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V10 WAYFINDING PASS: %d native 3D accessibility checks" % count)
        quit(0)
    else:
        for issue in failures:
            push_error("V10 WAYFINDING FAIL: "+issue)
        quit(1)
