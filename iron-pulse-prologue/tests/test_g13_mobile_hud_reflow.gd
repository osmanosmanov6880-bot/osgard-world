extends SceneTree
## G13: real native Godot panel geometry, not web CSS or screenshot fiction.
## Emulates viewport geometry only; not physical iPhone/Android certification.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _test(ok: bool,reason: String) -> void:
    checks += 1
    if not ok:
        failures.append(reason)

func _bottom(rect: Array) -> float:
    return float(rect[1])+float(rect[3]) if rect.size() == 4 else 100000.0

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE G13 REAL MOBILE HUD PASS: %d real source panel geometry and story/player nonmutation checks" % checks)
        quit(0)
        return
    for e in failures:
        push_error("G13 MOBILE HUD FAIL: "+e)
    quit(1)

func _run() -> void:
    var main: PackedScene = load("res://Main.tscn")
    _test(main != null,"Actual source Godot Main.tscn must parse and instantiate")
    if main == null:
        _finish()
        return
    var game = main.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    game.start_run()
    var engine_actions: Dictionary = game.session.checkpoint()

    game._browser_css_size = Vector2i(390,844)
    game._layout_hud()
    game._refresh_hud()
    await process_frame
    var m: Dictionary = game._g13_mobile_layout_readout()
    print("G13_REAL_NATIVE_GEOMETRY_390 ",JSON.stringify(m))
    var radio: Array = m["radio_rect"]
    var telemetry: Array = m["telemetry_rect"]
    _test(m["schema"] == "IRON_PULSE_MOBILE_HUD_REFLOW_G13" and
        typeof(m["source_engine_mutated"]) == TYPE_BOOL and m["source_engine_mutated"] == false,
        "G13 must honestly derive scene positions and never change IPCrisisEngine")
    _test(m["layout"] == "single_story_card" and
        not m["hud_card_visible"] and m["radio_visible"] and not m["priority_visible"],
        "390x844 must display exactly one true story/telemetry primary card")
    var header: Array = game._hud_rect(game.header_panel)
    _test(float(radio[1]) > _bottom(header)+4.0 and
        _bottom(radio) < float(m["touch_first_row_y"])-2.0 and
        m["touch_first_row_y"] == 373.0,
        "390px story card must clear actual header and LAB/MAP touch zones")
    _test(m["emergency_footer_from_real_engine"] and
        m["emergency_footer"].contains(str(int(game.session.crew_health))) and
        m["emergency_footer"].contains(str(int(game.session.door_charge))),
        "Live footer must expose source crew, door, air, heat and timer")
    _test(game.telemetry_label.text.contains("ЭКИП") and
        game.telemetry_label.text.contains("ШЛЮЗ") and
        game.telemetry_label.text.contains(str(int(game.session.oxygen))),
        "Compact mobile stats must read real source heat, air, crew, door")
    _test(not game.quality_state_label.visible and
        game.threat_label.text.begins_with("A7 / ") and
        not game.threat_label.text.contains("\n"),
        "Mobile risk stays word-based, not cramped multi-line or color-only")

    # When the source event timer expires, native full telemetry returns.
    game.radio_ttl = 0.0
    game._refresh_radio_ui()
    var after_story: Dictionary = game._g13_mobile_layout_readout()
    _test(after_story["hud_card_visible"] and not after_story["radio_visible"] and
        not after_story["emergency_footer_from_real_engine"],
        "390px must restore real numerical card after original MARA radio expires")
    game.radio_ttl = 11.0
    game._refresh_radio_ui()
    game._browser_css_size = Vector2i(320,720)
    game._layout_hud()
    game._refresh_hud()
    await process_frame
    m = game._g13_mobile_layout_readout()
    radio = m["radio_rect"]
    print("G13_REAL_NATIVE_GEOMETRY_320 ",JSON.stringify(m))
    _test(m["layout"] == "single_story_card" and not m["hud_card_visible"] and
        m["radio_visible"] and not m["priority_visible"],
        "320x720 gives priority to unaltered real narrative instead of overlapping telemetry")
    _test(float(radio[1]) >= 116.0 and
        _bottom(radio) < float(m["touch_first_row_y"]) - 1.0,
        "Real short-screen radio must fit between native header and physical controls")
    _test(game.radio_dialogue.text.contains("МАРА") and
        game.session.checkpoint()["switches"] == engine_actions["switches"],
        "Reflow keeps original MARA text and cannot switch a real power bus")
    game._toggle_language()
    game._refresh_hud()
    _test(game.telemetry_label.text.contains("AIR") and
        game.radio_dialogue.text.contains("MARA") and
        game._g13_mobile_layout_readout()["layout"] == "single_story_card",
        "True RU/EN story and engine data remain source-backed on 320px")

    # Source-only scenario fixture: show a real-game priority selection panel,
    # not a fake completion, player identity or external telemetry.
    game.session.core_scanned = true
    game.session.priority_id = ""
    game._refresh_radio_ui()
    await process_frame
    m = game._g13_mobile_layout_readout()
    _test(m["priority_visible"] and not m["radio_visible"] and
        not m["hud_card_visible"],
        "Critical real crew/core decision must take visual precedence over radio")
    _test(_bottom(m["priority_rect"]) <= float(m["touch_first_row_y"])-1.0,
        "Real native priority buttons must remain above touch actions at 320px")
    _test(game.crew_priority_button.get_rect().size.y >= 44 and
        game.core_priority_button.get_rect().size.y >= 44,
        "Physical decision choices remain finger-sized and operable")
    game.session.core_scanned = false
    game._refresh_radio_ui()

    game._browser_css_size = Vector2i(1366,768)
    game._layout_hud()
    game._refresh_hud()
    await process_frame
    m = game._g13_mobile_layout_readout()
    _test(m["layout"] == "desktop" and m["hud_card_visible"] and
        not m["compact"] and game.quality_state_label.visible,
        "Original full desktop telemetry and original world layout preserved")
    _test(game.telemetry_label.text.contains("TIME") or
        game.telemetry_label.text.contains("ВРЕМЯ") or
        game.telemetry_label.text.contains(" | "),
        "Full desktop details remain, including real session timer")
    _test(game.session.checkpoint()["switches"] == engine_actions["switches"] and
        game.session.checkpoint()["faults"] == engine_actions["faults"] and
        game.session.checkpoint()["priority"] == engine_actions["priority"],
        "HUD reflow must NEVER make choices or complete mission automatically")
    game.queue_free()
    _finish()
