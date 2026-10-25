extends SceneTree
## W23 source-backed Godot acceptance. Real 3D scene and both quality modes.
## Never claims mobile hardware FPS or cinematic AAA certification.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("W23 ART QA FAILED: " + reason)
    quit(1)


func _run() -> void:
    var src = preload("res://R135ArtDirection.gd")
    var env := Environment.new()
    var key := DirectionalLight3D.new()
    var rim := DirectionalLight3D.new()
    var fill := OmniLight3D.new()
    var eco: Dictionary = src.apply(0, env, key, rim, fill)
    if not bool(eco.get("valid")) or str(eco.get("profile")) != "ECO":
        _fail("ECO profile not applied to genuine Godot light objects")
        return
    if absf(float(eco["fill_energy"]) - 3.8) > 0.001:
        _fail("ECO must preserve prior legible W11 inspection fill")
        return
    var hero: Dictionary = src.apply(2, env, key, rim, fill)
    if str(hero.get("profile")) != "HERO" or float(hero["key_energy"]) <= float(eco["key_energy"]):
        _fail("HERO must create visible, measurable new key-light hierarchy")
        return
    if float(hero["rim_energy"]) <= float(eco["rim_energy"]) or float(hero["fill_energy"]) < 3.8:
        _fail("HERO must preserve illuminated fault markers and side-light definition")
        return
    for profile in [eco, hero]:
        if bool(profile.get("key_shadow_enabled")) or bool(profile.get("rim_shadow_enabled")) or \
            bool(profile.get("fill_shadow_enabled")) or bool(profile.get("gpu_bloom_or_ssr_enabled")):
            _fail("A WebGL profile enabled extra shadow casters or fake expensive SSR/glow")
            return
        if bool(profile.get("physical_telemetry", true)):
            _fail("Visual-only art cannot claim to control real equipment")
            return
    var back: Dictionary = src.apply(0, env, key, rim, fill)
    if absf(float(back["rim_energy"]) - float(eco["rim_energy"])) > 0.001:
        _fail("Returning to ECO must restore deterministic lightweight lighting")
        return

    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    if packed == null:
        _fail("Real R135 Godot scene missing")
        return
    var game: Node = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var lights: Array = []
    for node in game.get_children():
        if node is Light3D:
            lights.append(node)
    if lights.size() != 3:
        _fail("Existing stage must use exactly three lights; no hidden extra render passes")
        return
    var stage: Node = game.get("studio") as Node
    var rig: Node = game.get("controller") as Node
    var art: Dictionary = game.get("art_profile")
    if stage == null or rig == null or str(art.get("profile")) not in ["ECO","HERO"]:
        _fail("Actual studio, simulator and real art profile not connected")
        return
    var baseline: Dictionary = stage.call("render_budget")
    if int(baseline.get("luxury_draw_batches", 0)) != 5 or \
        int(baseline.get("grid_draw_batches", 0)) != 2 or \
        int(baseline.get("detail_draw_batches", 0)) != 3:
        _fail("W23 changed optimized original ECO/HERO batch count")
        return
    var start_mode: int = int(game.get("quality"))
    game.call("_toggle_quality")
    var changed: Dictionary = game.get("art_profile")
    if int(changed.get("mode", -1)) == start_mode:
        _fail("Actual W20 quality control did not update existing stage lighting")
        return
    game.call("_toggle_quality")
    if int(game.get("quality")) != start_mode:
        _fail("Original persisted player setting did not restore")
        return
    var after: Dictionary = stage.call("render_budget")
    for key_name in ["luxury_draw_batches", "grid_draw_batches", "detail_draw_batches", "single_mesh_nodes"]:
        if int(after.get(key_name, -1)) != int(baseline[key_name]):
            _fail("Quality toggle created more 3D GPU draw calls: " + key_name)
            return
    var before: Dictionary = rig.call("summary")
    game.call("_start_mission")
    game.call("_toggle_hatch")
    var unsafe: Dictionary = rig.call("summary")
    if int(unsafe.get("mission_step", -1)) != 0 or \
        not str(unsafe.get("mission_feedback", "")).begins_with("SAFETY INTERLOCK"):
        _fail("Art pass accidentally bypassed real safe-stop hatch interlock")
        return
    if not bool(before.get("simulation_only", false)) or bool(before.get("physical_telemetry_connected", true)):
        _fail("Original industrial controller must remain a virtual training simulator")
        return
    print("W23 REAL ART PASS: ECO/HERO light grading, exact 3-light/10-batch budget, stable preferences and safety")
    game.queue_free()
    quit(0)
