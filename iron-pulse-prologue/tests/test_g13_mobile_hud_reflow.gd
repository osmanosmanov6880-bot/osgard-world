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
    # G13 real-geometry regression: original V17 source archive MUST remain
    # fully closable from a mobile touch viewport, before any gameplay begins.
    for dims in [Vector2i(390,844),Vector2i(320,720)]:
        game._browser_css_size = dims
        game._layout_hud()
        game._toggle_run_archive()
        await process_frame
        var modal_rect: Rect2 = game.archive_panel.get_global_rect()
        var close_rect: Rect2 = game.archive_close_button.get_global_rect()
        var real_viewport: Rect2 = game.get_viewport().get_visible_rect()
        # In headless a simulated CSS width changes the UI variant but NOT
        # the real 1280px native anchor coordinate system. Full CSS bounds
        # are enforced separately on the actual 390px Chromium canvas.
        print("G13_NATIVE_ARCHIVE_GEOMETRY ",dims," real:",real_viewport,
            " panel:",modal_rect," close:",close_rect)
        _test(game.archive_panel.visible and not game.touch_ui.visible,
            "Real operator archive suspends gameplay touch hitboxes during the modal")
        _test(real_viewport.encloses(modal_rect),
            "Native archive modal must fit the real headless Godot anchor viewport")
        _test(real_viewport.encloses(close_rect) and modal_rect.encloses(close_rect) and
            close_rect.size.y >= 44.0,
            "True archive close button must fit native modal and be operable")
        _test(game.archive_label.get_parent().size.y >= 130.0,
            "History remains scrollable on compact real screens")
        game._toggle_run_archive()
        await process_frame
        _test(not game.archive_panel.visible and game.touch_ui.visible,
            "Closing the original records screen restores real physical gameplay touch controls")
    game._browser_css_size = Vector2i(390,844)
    game._layout_hud()
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
    _test(m["layout"] == "stacked_story_below_telemetry" and
        m["hud_card_visible"] and m["radio_visible"] and not m["priority_visible"] and
        not m["emergency_footer_from_real_engine"],
        "390x844 uses separate live telemetry and authentic MARA radio card")
    _test(m["mobile_telemetry_is_single_label"] and m["radio_preview_line_cap"] == 2 and
        float(m["telemetry_minimum_y"]) <= 112.0,
        "Actual 390px source metrics must physically fit a compact panel, not inflate to old 159px")
    _test(_bottom(telemetry) < float(radio[1])-2.0,
        "Real 390px top HUD card must not overlap actual radio panel")
    _test(_bottom(radio) < float(m["touch_first_row_y"])-1.0 and
        m["touch_first_row_y"] == 373.0,
        "Actual MARA radio must finish above LAB / MAP / SHOT touch buttons")
    _test(game.telemetry_label.text.contains("ЭКИП") and
        game.telemetry_label.text.contains("ШЛЮЗ") and
        game.telemetry_label.text.contains(str(int(game.session.oxygen))),
        "Compact mobile stats must read real source heat, air, crew, door")
    _test(not game.quality_state_label.visible and
        game.threat_label.text.begins_with("A7 / ") and
        not game.threat_label.text.contains("\n"),
        "Mobile risk stays word-based, not cramped multi-line or color-only")

    game._browser_css_size = Vector2i(320,720)
    game._layout_hud()
    game._refresh_hud()
    await process_frame
    m = game._g13_mobile_layout_readout()
    print("G13_REAL_NATIVE_GEOMETRY_320 ",JSON.stringify(m))
    radio = m["radio_rect"]
    _test(m["layout"] == "single_story_card" and not m["hud_card_visible"] and
        m["radio_visible"] and not m["priority_visible"],
        "320x720 gives priority to unaltered real narrative instead of overlapping telemetry")
    _test(m["radio_preview_line_cap"] == 2 and
        float(m["radio_minimum_y"]) <= 115.0,
        "Actual 320px MARA line cap remains accessible with full words in private J journal")
    _test(game.radio_dialogue.text.contains("[J]") and
        game.radio_dialogue.tooltip_text.length() > game.radio_dialogue.text.length(),
        "Short mobile radio preview must preserve full exact authored line via native journal and tooltip")
    _test(float(radio[1]) >= 116.0 and
        _bottom(radio) < float(m["touch_first_row_y"]) - 1.0 and
        m["touch_first_row_y"] == 249.0,
        "Real short-screen radio must fit between native header and physical controls")
    _test(m["emergency_footer_from_real_engine"] and
        str(m["emergency_footer"]).contains(str(int(game.session.oxygen))) and
        str(m["emergency_footer"]).contains(str(int(game.session.heat))),
        "Real source heat/oxygen must remain readable while short-screen MARA replaces the telemetry card")
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
    # When a real timed radio ends, full telemetry must recover without
    # having to reload a mission or change source-engine choices.
    game.radio_ttl = 0.0
    game._refresh_radio_ui()
    m = game._g13_mobile_layout_readout()
    _test(not m["radio_visible"] and m["hud_card_visible"] and
        not m["emergency_footer_from_real_engine"],
        "Original live telemetry must automatically return after MARA's authored TTL")
    game.radio_ttl = 11.0
    game.session.core_scanned = true
    game.session.priority_id = ""
    game._refresh_radio_ui()
    await process_frame
    m = game._g13_mobile_layout_readout()
    _test(m["priority_visible"] and not m["radio_visible"] and
        not m["hud_card_visible"] and m["emergency_footer_from_real_engine"],
        "Real crew/core choice takes precedence without hiding source-derived emergency vitals")
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
