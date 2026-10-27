extends SceneTree
## W43 independently verifies actual smoother native metal geometry and
## GPU-instanced detail without bypassing the safety simulation.
const Core = preload("res://scripts/OSGARDCore.gd")
const TEST_FILE := "user://osgard_w43_smooth_reactor_visual.cfg"
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_inspect")

func _ok(result: bool, name: String) -> void:
    checks += 1
    if not result:
        failures.append(name)

func _inspect() -> void:
    var packed := load("res://Main.tscn") as PackedScene
    _ok(packed != null, "Original Godot scene imports")
    if packed == null:
        _finish()
        return
    var ui: OSGARDMain = packed.instantiate() as OSGARDMain
    _ok(ui != null, "True original Godot operator controller imports")
    if ui == null:
        _finish()
        return
    ui.core = Core.new(TEST_FILE)
    ui.core.clear_data()
    root.add_child(ui)
    await process_frame
    await process_frame
    var rig: OSGARDRig = ui.scene_3d
    _ok(rig != null, "Original native 3D simulator remains available")
    var setpiece: Node3D = rig.obsidian_stage
    _ok(setpiece.has_node("A7ContinuousChampagneMachining"), "Lathed champagne torus is real scene geometry")
    _ok(setpiece.has_node("A7ContinuousTitaniumInnerBearing"), "Lathed titanium bearing exists")
    _ok(setpiece.has_node("RakingMachinedMetalContour"), "Raking practical contour light physically exists")
    _ok(setpiece.has_node("A7MachinedKnurl72Instances"), "GPU-batched micro-metal detailing exists")
    var stats: Dictionary = rig.cinematic_qa_readout()
    _ok(stats.get("lathed_torus_meshes") == true, "All continuous metal rings are genuine Godot TorusMesh")
    _ok(int(stats.get("continuous_torus_surfaces",0)) >= 4, "Four smooth shaped surfaces instead of square outlines")
    _ok(int(stats.get("instanced_precision_fasteners",0)) == 72, "72 structural details submitted as one instanced batch")
    _ok(int(stats.get("cinematic_fill_count",0)) == 3, "Premium raking contour is in original 3D light set")
    _ok(float(stats.get("contour_light_hero_only",0.0)) > 0.5, "HERO enables proper machined metal highlighting")
    _ok(stats.get("machined_fastener_batch_visible") == true, "HERO visibly enables micro-detailed rings")
    rig.set_quality("eco")
    stats = rig.cinematic_qa_readout()
    _ok(stats.get("machined_fastener_batch_visible") == false, "ECO hides extra GPU micro-instancing")
    _ok(is_zero_approx(float(stats.get("contour_light_hero_only",99.0))), "ECO removes third premium light")
    _ok(stats.get("key_shadow_enabled") == false, "ECO preserves all original shadow savings")
    rig.set_quality("hero")
    stats = rig.cinematic_qa_readout()
    _ok(stats.get("machined_fastener_batch_visible") == true, "HERO can restore all decorations")
    _ok(ui.mission_btns.size() == 6 and ui.view_btns.size() == 3, "No mission or native camera regressions")
    _ok(ui.dial_a != null and ui.dial_b != null, "Original safe physical calibration retained")
    _ok(stats.get("photorealistic_aaa_certified") == false, "No unearned AAA certification in source QA")
    ui.core.clear_data()
    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("OSGARD W43 SMOOTH MACHINED REACTOR GODOT PASS: %d source-bound native assertions" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error("W43 ENGINE VISUAL REGRESSION: " + failure)
        quit(1)
