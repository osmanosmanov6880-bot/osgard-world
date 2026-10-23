extends SceneTree
var failures := 0
func _init() -> void:
    call_deferred("_run")
func _check(valid: bool, label: String) -> void:
    if valid:
        print("WAVE10 VECTOR PASS: ",label)
    else:
        push_error("WAVE10 VECTOR FAIL: "+label)
        failures += 1
func _run() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    _check(packed != null,"original playable 3D scene available")
    if packed == null:
        quit(1)
        return
    var game := packed.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    var director := game.get_node_or_null("Wave10ArtDirection") as Node3D
    _check(director != null,"cinematic art director is installed")
    var petals := game.get_node_or_null("ReceiverAssembly/Wave10PrecisionReceiver/KineticTwelveJawIris") as MultiMeshInstance3D
    _check(petals != null and petals.multimesh.instance_count == 12,"12 animated jaws use one MultiMesh draw")
    var magnet := game.get_node_or_null("MagnetAssembly/PolarityFeedbackRing") as MeshInstance3D
    _check(magnet != null and magnet.material_override is StandardMaterial3D,"physical reactive magnetic ring exists")
    var hint := game.get_node_or_null("RussianGameHUD/TipPanel") as PanelContainer
    _check(hint != null and hint.anchor_top == 0.0,"hint is moved out of launcher zone")
    game._toggle_polarity()
    director._process(0.016)
    _check(game.polarity == -1,"original physical polarity control is intact")
    var mat := magnet.material_override as StandardMaterial3D
    _check(mat != null and mat.albedo_color.r > 0.9,"repulsion visibly turns amber")
    _check(game.state == "aiming","game state is preserved")
    game.queue_free()
    print("WAVE10 VECTOR FINAL:", "PASS" if failures == 0 else "FAIL")
    quit(0 if failures == 0 else 1)
