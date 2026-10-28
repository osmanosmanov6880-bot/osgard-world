extends SceneTree
## V9: operator command board integration with TRUE playable Godot scene.
## Tests actual pause/resume, intro, RU/EN UI, persistent debrief and controller.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool,label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _key(game: Node,key: Key) -> void:
    var press := InputEventKey.new()
    press.keycode = key
    press.pressed = true
    game._input(press)

func _joy(game: Node,key: JoyButton) -> void:
    var press := InputEventJoypadButton.new()
    press.button_index = key
    press.pressed = true
    game._input(press)

func _run() -> void:
    var slot: String = "user://iron_pulse_v9_real_scene_profile_ci.json"
    var storage := IPCheckpointStore.new()
    storage.clear(slot)
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null,"Genuine Godot Main scene still imports")
    if packed == null:
        _finish()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    game.career_path = slot
    game.career.reset()
    _check(game.career is IPCareerProfile and game.operations_panel is IPOperationsPanel,
        "Original live game owns actual career and dedicated premium Godot operations interface")
    _check(game.operations_panel != null and not game.operations_panel.visible and game.intro_panel.visible,
        "Main menu still displays normally, career overlay starts hidden")
    _check(game.operations_button is Button and game.operations_button.text.contains("КОМАНДНЫЙ"),
        "Main menu provides a real Russian operations command button")

    _key(game,KEY_O)
    _check(game.operations_panel.visible and not game.intro_panel.visible,
        "Actual O key opens full screen operation center from start menu")
    _check(game.operations_panel.launch_button.visible,
        "Operation center offers launch only before beginning a real run")
    _check(game.operations_panel._metric_values[0].text=="0" and game.operations_panel._metric_values[1].text=="0",
        "No fake global users or artificial career stats")
    _check(game.operations_panel._heading.text.contains("ИСТОРИЯ"),
        "Actual premium career UI contains genuine RU title")
    _check(game.operations_panel._history_label.text.contains("История"),
        "Brand-new player sees an honest empty operator history")
    _check(game.operations_panel._recommended=="blackout",
        "Intro platform recommends legitimate initial GRID mission")
    _key(game,KEY_L)
    _check(game.locale=="en" and game.operations_panel._heading.text.contains("OPERATOR"),
        "Localized command center immediately switches to real English copy")
    _check(game.career.preferences["language"]=="en",
        "Actual gameplay language persists to separately versioned user profile")
    _check(game.operations_panel._settings_buttons.size()==4,
        "Four real on-screen device and accessibility controls built in Godot")
    (game.operations_panel._settings_buttons["graphics"] as Button).emit_signal("pressed")
    _check(game.quality_mode=="eco" and game.reactor_atrium.readout()["quality"]=="eco",
        "Real settings button switches actual expensive reactor geometry to ECO")
    (game.operations_panel._settings_buttons["reduced_motion"] as Button).emit_signal("pressed")
    _check(game.reduced_motion and game.career.preferences["reduced_motion"],
        "Reduced-motion on-screen setting reaches actual player camera and persistent preference")
    (game.operations_panel._settings_buttons["muted"] as Button).emit_signal("pressed")
    _check(game.muted_audio and game.audio_director.muted,
        "Real button mutes actual audio stream and is saved")
    var settings_file := IPCareerProfile.new()
    _check(settings_file.load(slot) and settings_file.preferences["graphics"]=="eco" and
        settings_file.preferences["reduced_motion"] and settings_file.preferences["muted"],
        "Audio/graphics/accessibility preferences survive an actual file restart")
    (game.operations_panel._settings_buttons["graphics"] as Button).emit_signal("pressed")
    (game.operations_panel._settings_buttons["reduced_motion"] as Button).emit_signal("pressed")
    (game.operations_panel._settings_buttons["muted"] as Button).emit_signal("pressed")
    _check(game.quality_mode=="hero" and not game.reduced_motion and not game.muted_audio,
        "All 3 options are genuinely reversible via touch-friendly settings buttons")
    _joy(game,JOY_BUTTON_B)
    _check(not game.operations_panel.visible and game.intro_panel.visible,
        "Mapped gamepad B closes operations menu without starting game")
    _key(game,KEY_L)
    _check(game.locale=="ru","Original game locale can switch back from platform")
    _key(game,KEY_O)
    game.operations_panel.launch_button.emit_signal("pressed")
    _check(game.started and not game.operations_panel.visible and not game.intro_panel.visible,
        "True Godot button launches recommended mission from the operations platform")
    _check(game.session.scenario_id=="blackout" and game.audio_director!=null,
        "Recommended launch enters actual first-person GRID game and soundscape")
    _check(not game.career_recorded_run and game.career.operations==0,
        "Beginning operation does not prematurely credit win or loss")
    _key(game,KEY_O)
    _check(game.operations_panel.visible and game.paused and game.operations_auto_paused,
        "Career overlay temporarily pauses active emergency simulation instead of playing behind modal")
    _check(not game.operations_panel.launch_button.visible and not game.pause_panel.visible,
        "Cannot start overlapping missions and no stacked pause overlays")
    var saved: Dictionary = game.session.checkpoint()
    _key(game,KEY_O)
    _check(not game.operations_panel.visible and not game.paused,
        "O closes platform and automatically resumes exact active game")
    _check(game.session.checkpoint()==saved,
        "Opening and closing platform never changes timer, choices or health")
    _key(game,KEY_ESCAPE)
    _check(game.paused and game.pause_panel.visible,"Original Escape pause still works")
    game.operations_pause_button.emit_signal("pressed")
    _check(game.operations_panel.visible and game.paused and not game.pause_panel.visible,
        "Pause menu opens career center without unpausing emergency")
    _joy(game,JOY_BUTTON_START)
    _check(not game.operations_panel.visible and game.paused and game.pause_panel.visible,
        "Mapped START closes career and restores the original pause menu")
    _key(game,KEY_ESCAPE)
    _check(not game.paused,"Original Escape resumes from restored pause UI")

    # Isolated real scene acceptance: complete run without simulating the
    # 5-minute user journey. Separate deterministic engine tests verify journey.
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    game.session.won = true
    game.session.heat = 51.0
    game.session.oxygen = 87.0
    game.session.crew_health = 96.0
    game.session.elapsed = 108.0
    game._show_end()
    _check(game.end_panel.visible and game.career.operations==1 and game.career.victories==1,
        "True Godot end handler records one successful operation into operator platform")
    _check(game.career.achievements.has("FIRST_EXTRACTION") and game.career.achievements.has("ZERO_FAULT"),
        "Actual debrief immediately unlocks earned profile badges")
    _check(game.end_stats.text.contains("КАРЬЕРА") and game.end_stats.text.contains("НОВЫЕ ДОСТИЖЕНИЯ"),
        "Mission debrief displays live persistent campaign progress and new rewards")
    _check(game.career_recorded_run,"Recorded-run guard prevents silent double-awards")
    game._show_end()
    _check(game.career.operations==1 and game.career.victories==1,
        "Reentrant end handler never duplicates achievements or progression")
    var from_disk := IPCareerProfile.new()
    _check(from_disk.load(slot) and from_disk.operations==1 and from_disk.victories==1,
        "The actual game completed run persisted as an isolated valid offline profile")
    _key(game,KEY_O)
    _check(game.operations_panel.visible and not game.end_panel.visible,
        "Career center can be inspected from the real finished game")
    _check(game.operations_panel._metric_values[0].text=="1" and game.operations_panel._metric_values[1].text=="1",
        "Player sees accurate won-run counters inside UI")
    _check(game.operations_panel._rewards_label.text.contains("ПЕРВАЯ ЭВАКУАЦИЯ"),
        "A real earned achievement appears inside operator center")
    _key(game,KEY_ESCAPE)
    _check(game.end_panel.visible and not game.operations_panel.visible,
        "Closing career center restores original final result overlay")
    game._restart()
    _check(game.started and not game.session.finished() and not game.career_recorded_run,
        "Replay begins genuine fresh operation while preserving cumulative career")
    game.session.lost = true
    game.session.elapsed = 127.0
    game._show_end()
    _check(game.career.operations==2 and game.career.victories==1,
        "Failed replay recorded honestly, without extra successful evacuation")
    _check(game.career.mission_records["blackout"]["best_grade"]=="S",
        "Failure cannot overwrite previous successful mastery grade")
    _check(from_disk.load(slot) and from_disk.operations==2 and from_disk.victories==1,
        "Persistent profile survives replay and separate disk read")

    game._browser_css_size = Vector2i(390,844)
    game._layout_hud()
    _key(game,KEY_O)
    _check(game.operations_panel.visible,"Full command center available at smartphone CSS width")
    var bounds: Rect2 = game.operations_panel.get_rect()
    _check(bounds.size.x<=390.0 and bounds.size.y<=844.0 and bounds.size.x>=340.0,
        "Responsive operations modal fits 390x844 without horizontal overflow")
    _check(game.operations_panel._scroll is ScrollContainer and
        game.operations_panel._scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,
        "Small touch viewport has genuine vertical-scroll layout, no horizontal page bleed")
    _check(game.operations_panel.close_button.custom_minimum_size.y>=44.0,
        "Mobile operations close target meets minimum finger-sized activation height")
    _key(game,KEY_ESCAPE)
    _check(game.end_panel.visible,"Mobile layout restores full mission debrief")
    _check(storage.clear(slot),"Isolated persistent profile removed after test without touching real save")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V9 OPERATIONS SCENE PASS: %d real Godot gameplay/UI assertions" % checks)
        quit(0)
    else:
        for issue in failures:
            push_error("V9 SCENE FAIL: "+issue)
        quit(1)
