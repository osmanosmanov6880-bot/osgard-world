extends SceneTree

func _initialize() -> void:
    call_deferred("_run_smoke")

func _run_smoke() -> void:
    var source: PackedScene = load("res://scenes/Main.tscn")
    if source == null:
        push_error("R136 scene missing")
        quit(1)
        return
    var instance: Node3D = source.instantiate()
    root.add_child(instance)
    await process_frame
    var names := ["ServiceCarriage", "HingedSafetyDoor", "FanRotor_00", "HeroMicroDetails"]
    if instance.get_node_or_null("PrecisionServiceFrame/HeroMicroDetails") == null:
        push_error("R136 HERO detail source not present")
        quit(1)
        return
    for name in names:
        if name == "HeroMicroDetails":
            continue
        if instance.get_node_or_null(name) == null:
            push_error("Missing physical mechanism: " + name)
            quit(1)
            return
    instance.set_emergency_stop(true)
    if not instance.emergency_stopped:
        push_error("Emergency stop failed")
        quit(1)
        return
    instance.set_detail(false)
    if instance.hero_enabled:
        push_error("ECO detail switch failed")
        quit(1)
        return
    instance.set_emergency_stop(false)
    print("PASS R136 native scene smoke and safety controls")
    quit(0)
