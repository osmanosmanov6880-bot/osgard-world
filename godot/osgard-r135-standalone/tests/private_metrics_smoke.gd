extends SceneTree
## W26 real Godot native privacy acceptance. No cloud analytics are implied.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("W26 PRIVATE METRICS FAILED: " + reason)
    quit(1)


func _run() -> void:
    var metrics_file: String = ProjectSettings.globalize_path("user://r135_private_learning_metrics_v1.cfg")
    if FileAccess.file_exists(metrics_file):
        DirAccess.remove_absolute(metrics_file)
    var game: PackedScene = load("res://Main.tscn") as PackedScene
    if game == null:
        _fail("Real Godot game is missing")
        return
    var scene: Node = game.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame
    var metrics: Node = scene.get("privacy_metrics") as Node
    var rig: Node = scene.get("controller") as Node
    var ui: Control = scene.get("premium_intro") as Control
    if metrics == null or rig == null or ui == null:
        _fail("Actual player interface, rig and private metrics node disconnected")
        return
    if bool(metrics.get("consent")) or int(metrics.call("total")) != 0:
        _fail("Real new user must have opt-out and zero counters")
        return
    var before: Dictionary = rig.call("summary")
    var attempts: int = int(before.get("mission_attempts", 0))
    scene.call("_start_mission")
    if int(metrics.call("total")) != 0:
        _fail("Unconsented real gameplay must never be logged")
        return
    var ui_button: Button = ui.get("settings_privacy_button") as Button
    if ui_button == null or ui_button.focus_mode != Control.FOCUS_ALL:
        _fail("Explicit analytics consent must be a focusable actual Godot button")
        return
    ui_button.pressed.emit()
    if not bool(metrics.get("consent")) or not bool(metrics.call("snapshot").get("saved")):
        _fail("Genuine user opt-in not persisted")
        return
    var bad: bool = bool(metrics.call("record", "hardware_location"))
    if bad or int(metrics.call("total")) != 0:
        _fail("Unapproved personal event accepted")
        return
    scene.call("_start_mission")
    var snap: Dictionary = metrics.call("snapshot")
    if int(snap.get("training_started", 0)) != 1:
        _fail("Actual training should increment only after explicit consent")
        return
    scene.call("_toggle_hatch")
    snap = metrics.call("snapshot")
    if int(snap.get("safety_blocked", 0)) < 1:
        _fail("Actual unsafe training hatch not tracked as anonymous count")
        return
    if not str(rig.call("summary").get("mission_feedback", "")).begins_with("SAFETY INTERLOCK"):
        _fail("Privacy counters must not weaken virtual safety interlocks")
        return
    scene.call("_toggle_motion")
    scene.call("_toggle_hatch")
    for tick in range(125):
        rig.call("_physics_process", 1.0/60.0)
    scene.call("_toggle_hatch")
    for tick in range(125):
        rig.call("_physics_process", 1.0/60.0)
    scene.call("_toggle_motion")
    if not bool(rig.call("summary").get("mission_completed", false)):
        _fail("Real safety-first mission did not complete")
        return
    var finished: int = int(metrics.call("snapshot").get("training_completed", 0))
    if finished != 1:
        _fail("A real completed mission did not produce exactly one local aggregate")
        return
    for i in range(10):
        scene.call("_refresh_status")
    if int(metrics.call("snapshot").get("training_completed", 0)) != finished:
        _fail("Repeated UI refresh counted same completion more than once")
        return
    scene.call("_start_challenge")
    if int(metrics.call("snapshot").get("diagnosis_started", 0)) != 1:
        _fail("Real diagnostic event not recorded after consent")
        return
    if int(rig.call("summary").get("mission_attempts", 0)) < attempts:
        _fail("Counter change damaged pre-existing W14 mission record")
        return

    # Clearing all local analytics must preserve consent state and real game.
    scene.call("_erase_private_metrics")
    if int(metrics.call("total")) != 0 or not bool(metrics.get("consent")):
        _fail("Player cannot clear private event counters without losing choice")
        return
    scene.call("_start_challenge")
    if int(metrics.call("total")) == 0:
        _fail("Recording stopped after erase despite still having consent")
        return
    ui_button.pressed.emit()
    if bool(metrics.get("consent")) or int(metrics.call("total")) != 0:
        _fail("Opt-out must purge counters immediately")
        return
    scene.queue_free()
    await process_frame
    var again: Node = game.instantiate()
    root.add_child(again)
    await process_frame
    await process_frame
    var restored: Node = again.get("privacy_metrics") as Node
    if restored == null or bool(restored.get("consent")) or int(restored.call("total")) != 0:
        _fail("Real restart restored counters after explicit opt-out")
        return
    var facts: Dictionary = restored.call("snapshot")
    if int(facts.get("network_uploads", -1)) != 0 or \
        bool(facts.get("timestamps_stored", true)) or \
        bool(facts.get("user_identifiers_stored", true)):
        _fail("Private metrics invented a user identity, clock or network upload")
        return
    print("W26 PRIVACY PASS: default OFF, 0 identifiers/net, real safety counters, single completion and permanent opt-out purge")
    again.queue_free()
    quit(0)
