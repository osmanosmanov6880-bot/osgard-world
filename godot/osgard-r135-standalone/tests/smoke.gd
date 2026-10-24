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
    print("R135 SMOKE PASS: ECO/HERO scene, camera, motion pause, hatch, and resource swap")
    quit(0)
