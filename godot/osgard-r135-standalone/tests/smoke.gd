extends SceneTree
## Fails closed: a parser error, missing GLB, or dead control breaks the build.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("R135 SMOKE FAILED: " + message)
    quit(1)

func _run() -> void:
    var packed: Resource = load("res://Main.tscn")
    if not (packed is PackedScene):
        _fail("Main.tscn did not import")
        return
    var instance: Node = (packed as PackedScene).instantiate()
    if instance == null:
        _fail("Main.tscn did not instantiate")
        return
    root.add_child(instance)
    await process_frame
    await process_frame
    var rig: Node = instance.get_node_or_null("R135ServiceSpine")
    if rig == null:
        _fail("R135ServiceSpine controller missing")
        return
    var first: Dictionary = rig.call("summary")
    if int(first.get("loading_failures", 0)) != 0 or int(first.get("load_count", 0)) < 1:
        _fail("ECO mesh did not load: " + str(first))
        return
    if not str(first.get("loaded","")).ends_with("service_spine_eco.glb"):
        _fail("ECO boot preset not selected")
        return
    instance.call("_toggle_quality")
    await process_frame
    var second: Dictionary = rig.call("summary")
    if int(second.get("loading_failures", 0)) != 0:
        _fail("HERO mesh failed: " + str(second))
        return
    if not str(second.get("loaded","")).ends_with("service_spine_hero.glb"):
        _fail("HERO preset did not load")
        return
    instance.call("_toggle_motion")
    if bool(rig.call("summary").get("motion_enabled", true)):
        _fail("Pause control did not stop mechanism")
        return
    instance.call("_toggle_hatch")
    if int(rig.call("summary").get("inspect_count", 0)) < 1:
        _fail("Hatch action did not register")
        return
    instance.call("_toggle_quality")
    await process_frame
    var final: Dictionary = rig.call("summary")
    if int(final.get("loading_failures", 0)) != 0 or int(final.get("load_count", 0)) < 3:
        _fail("HERO-ECO-HERO switching failed: " + str(final))
        return
    # A player must be able to complete a deterministic, four-action mission.
    # Out-of-order input changes the rig but MUST NOT unlock fake mission progress.
    instance.call("_start_mission")
    var opened: Dictionary = rig.call("summary")
    if not bool(opened.get("mission_active", false)) or int(opened.get("mission_step", -1)) != 0:
        _fail("Mission did not reset correctly")
        return
    instance.call("_toggle_motion") # Wrong order: pause before opening hatch.
    if int(rig.call("summary").get("mission_step", -1)) != 0:
        _fail("Out-of-order pause advanced the mission")
        return
    instance.call("_toggle_motion") # Resume before beginning the correct sequence.
    instance.call("_toggle_hatch")
    if int(rig.call("summary").get("mission_step", -1)) != 1:
        _fail("Opening the hatch did not clear the first checkpoint")
        return
    instance.call("_toggle_motion")
    if int(rig.call("summary").get("mission_step", -1)) != 2:
        _fail("Pausing the drive did not clear the second checkpoint")
        return
    instance.call("_toggle_hatch")
    if int(rig.call("summary").get("mission_step", -1)) != 3:
        _fail("Closing the hatch did not clear the third checkpoint")
        return
    instance.call("_toggle_motion")
    var complete: Dictionary = rig.call("summary")
    if not bool(complete.get("mission_completed", false)) or int(complete.get("mission_step", 0)) != 4:
        _fail("Full four-step mission did not complete: " + str(complete))
        return
    if not bool(complete.get("motion_enabled", false)) or float(rig.get("lid_target")) > 0.5:
        _fail("Mission completed with unsafe simulated state")
        return
    instance.call("_next_view")
    if int(instance.get("view_index")) != 1:
        _fail("NEXT VIEW did not select the service deck")
        return
    instance.call("_next_view")
    if int(instance.get("view_index")) != 2:
        _fail("NEXT VIEW did not select the optical head")
        return
    instance.call("_reset_view")
    if int(instance.get("view_index")) != 0:
        _fail("RESET VIEW did not return to overview")
        return
    var operator_controls: Node = instance.get_node_or_null("R135ResponsiveOperatorHUD/OperatorControls")
    if operator_controls == null:
        _fail("Responsive mission controls missing")
        return
    print("R135 SMOKE PASS: ECO/HERO resources, strict 4-step mission, camera presets, accessible action panel")
    quit(0)
