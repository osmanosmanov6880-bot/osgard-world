extends SceneTree
## V3 native Godot 4.4.1 QA: render-aware HUD layout and legibility improvements.
## Browser CI independently checks real pixel rectangles and input.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn")
    _check(scene != null, "Source-bound playable Godot scene loads")
    if scene == null:
        _finish()
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _check(game.header_panel is PanelContainer, "Separate compact mission header exists")
    _check(game.prompt_panel is PanelContainer, "Prompt card exists without full-width world obstruction")
    _check(game.side_panel is PanelContainer, "Live operator readout stays independent")
    _check(game.header_panel.anchor_right == 0.0, "Mission header no longer spans whole desktop")
    _check(game.prompt_panel.anchor_right == 0.0, "Interaction panel no longer covers whole desktop")
    _check(game.legacy_lamps.size() >= 15, "Neutral physical-material readability lights exist")

    var environment: Environment = null
    for node in game.get_children():
        if node is WorldEnvironment:
            environment = node.environment
            break
    _check(environment != null, "Native WorldEnvironment is present")
    if environment != null:
        _check(environment.ambient_light_energy >= 0.65, "Metallic surfaces have non-emissive fill lighting")

    game._browser_css_size = Vector2i(1366,768)
    game._layout_hud()
    await process_frame
    _check(game.vitals_panel.visible, "Full desktop retains four visual vital bars")
    _check(not game.touch_ui.visible, "Desktop does not display touch D-pad")
    _check(game.header_panel.offset_bottom + 5.0 < game.side_panel.offset_top,
        "Desktop mission header and telemetry card have vertical separation")
    _check(game.header_panel.offset_right <= 555.0, "Compact desktop header preserves center scene")
    _check(game.prompt_panel.offset_right <= 555.0, "Compact prompt preserves center scene")

    game._browser_css_size = Vector2i(390,844)
    game._layout_hud()
    await process_frame
    _check(not game.vitals_panel.visible, "Phone hides duplicate vitals to recover 3D space")
    _check(game.touch_ui.visible, "Phone presents real native touch controls")
    _check(not game.subtitle_label.visible, "Phone hides nonessential duplicated subtitle")
    _check(game.header_panel.offset_right <= 390.0-12.0, "Phone mission header respects right safe inset")
    _check(game.side_panel.offset_right <= 390.0-12.0, "Phone telemetry respects right safe inset")
    _check(game.header_panel.offset_bottom + 5.0 < game.side_panel.offset_top,
        "Phone HUD stacks top cards with a safe gap")
    var expected: Array[String] = ["W","A","S","D"]
    for idx in range(4):
        var button: Button = game.touch_ui.get_children()[idx] as Button
        _check(button != null and button.text == expected[idx],
            "Mobile D-pad uses readable Latin controls, not missing arrow glyph %d" % idx)
        _check(button.custom_minimum_size.y <= 54.0, "Mobile touch button does not force excessive height")

    game.start_run()
    game._refresh_hud()
    _check(game.guidance_label.text.find("FWD") >= 0 or game.guidance_label.text.find("LEFT") >= 0 or game.guidance_label.text.find("RIGHT") >= 0,
        "Wayfinding uses fallback-safe direction text instead of unsupported symbols")
    _check(game.session.objective_id() == "scan", "Mission gameplay was not altered by rendering")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V3 READABLE CINEMA PASS: %d native assertions" % checks)
        quit(0)
    else:
        for problem in failures:
            push_error("V3 PRESENTATION FAIL: " + problem)
        quit(1)
