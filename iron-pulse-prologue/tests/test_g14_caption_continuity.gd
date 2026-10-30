extends SceneTree
## G14 real Godot IPStoryDirector read-only caption continuity acceptance.
## Only the fictional story source drives caption contents; timing is local UX.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool,msg: String) -> void:
    checks += 1
    if not ok:
        failures.append(msg)

func _key(game: Node,key: Key) -> void:
    var event := InputEventKey.new()
    event.keycode = key
    event.pressed = true
    game._input(event)

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE G14 SOURCE CAPTIONS PASS: %d real authored story, F4, mobile CC, privacy and original engine checks" % checks)
        quit(0)
        return
    for failure in failures:
        push_error("G14 CAPTIONS FAIL: "+failure)
    quit(1)

func _run() -> void:
    var prefs := IPCaptionContinuity.new()
    var path: String = "user://iron_pulse_g14_ci_caption_fixture.cfg"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    _assert(prefs.mode == "timed" and prefs.duration_seconds(11.0) == 11.0,
        "Default must keep original 11-second caption behavior")
    _assert(prefs.readout()["authored_source_only"] and
        not prefs.readout()["story_events_created"] and
        not prefs.readout()["telemetry_uploaded"],"Subtitles cannot synthesize story or upload telemetry")
    _assert(not prefs.should_display(false,true,50.0,false,false) and
        not prefs.should_display(true,false,50.0,false,false),
        "No captions before actual mission or without original IPStoryDirector text")
    _assert(prefs.should_display(true,true,11.0,false,false) and
        not prefs.should_display(true,true,0.0,false,false),
        "Original captions must disappear when real TTL expires")
    _assert(prefs.cycle()=="extended" and prefs.duration_seconds(9.0)==24.0,
        "Extended captions must last at least 24 seconds")
    _assert(prefs.should_display(true,true,0.01,false,false) and
        not prefs.should_display(true,true,25.0,true,false),
        "Priority crew/core button must take precedence over captions")
    _assert(prefs.cycle()=="pinned" and prefs.should_display(true,true,0.0,false,false) and
        not prefs.should_display(true,true,0.0,false,true),
        "Pinned caption persists after real TTL but not over a modal/paused game")
    _assert(not prefs.should_display(true,true,0.0,true,false),
        "Pinned message must not cover a real priority selection")
    _assert(prefs.label("ru").contains("ЗАКРЕПЛЕНЫ") and
        prefs.label("en").contains("HOLD"),
        "English and Russian localized accessible modes required")
    _assert(prefs.save_to(path),"Local caption choice persists only in user profile")
    var reopened := IPCaptionContinuity.new()
    _assert(reopened.load_from(path) and reopened.mode == "pinned",
        "Local caption setting survives restart without touching game save")
    var poison := ConfigFile.new()
    poison.set_value("presentation","schema",IPCaptionContinuity.FORMAT)
    poison.set_value("presentation","mode","automate_campaign")
    poison.save(path)
    var rejected := IPCaptionContinuity.new()
    _assert(not rejected.load_from(path) and rejected.mode == "timed",
        "Unknown preference cannot create gameplay or force a caption mode")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

    var source: PackedScene = load("res://Main.tscn")
    _assert(source != null,"Actual unchanged playable Godot Main.tscn must import")
    if source == null:
        _finish()
        return
    var game = source.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _assert(game.touch_caption_button != null and game.touch_caption_button.text == "CC / F4" and
        game.captions.mode == "timed",
        "G14 must mount a real 51px native mobile caption control")
    var intro: Dictionary = game.session.checkpoint()
    _key(game,KEY_F4)
    _assert(game.captions.mode == "extended" and
        game.session.checkpoint() == intro,
        "F4 from intro must only change display preference, never start a game")
    _key(game,KEY_F4)
    _assert(game.captions.mode == "pinned",
        "Second real F4 press must switch to pinned source dialogue")
    game.start_run()
    var initial_game: Dictionary = game.session.checkpoint()
    var first_line: Dictionary = game.story.latest(game.locale)
    _assert(not first_line.is_empty() and game.radio_panel.visible and
        game.radio_dialogue.text == str(first_line["text"]),
        "Pinned mode must render original authored MARA story, not synthetic text")
    game.radio_ttl = 0.0
    game._refresh_radio_ui()
    _assert(game.radio_panel.visible and
        game.radio_dialogue.text == str(game.story.latest(game.locale)["text"]),
        "Authentic pinned subtitle remains when the legitimate TTL expires")
    game._toggle_language()
    _assert(game.captions.label(game.locale).contains("HOLD") and
        game.radio_dialogue.text == str(game.story.latest(game.locale)["text"]),
        "Pinned original narrative changes RU/EN with real story localization")

    _key(game,KEY_F4)
    _assert(game.captions.mode=="timed" and not game.radio_panel.visible and
        game.session.checkpoint()==initial_game,
        "Timed mode after expired caption restores original visibility without gameplay mutation")
    _key(game,KEY_F4)
    _assert(game.captions.mode=="extended" and game.radio_ttl>=24.0 and
        game.radio_panel.visible,
        "Extended F4 must genuinely re-open source dialogue for 24 seconds")
    game._toggle_tactical_atlas()
    var atlas_mode: String = game.captions.mode
    _key(game,KEY_F4)
    _assert(game.captions.mode == atlas_mode,
        "F4 must not pass through native G10 pause map to change caption mode")
    game._close_tactical_atlas()

    game._browser_css_size = Vector2i(390,844)
    game._layout_hud()
    await process_frame
    var first_rect: Rect2 = game.touch_caption_button.get_rect()
    _assert(game.touch_caption_button.visible and first_rect.size.y >= 44 and
        first_rect.position.x >= 0 and first_rect.end.x <= 390.0,
        "Real mobile captions accessible on 390px portrait")
    _assert(not first_rect.intersects(game.touch_forecast_button.get_rect()) and
        not first_rect.intersects(game.touch_pause_button.get_rect()),
        "New CC tap must not collide with existing PLAN or PAUSE")
    game.touch_caption_button.pressed.emit()
    _assert(game.captions.mode == "pinned" and game.radio_panel.visible,
        "Actual native mobile button must pin source dialogue")
    game._browser_css_size = Vector2i(320,720)
    game._layout_hud()
    await process_frame
    var small: Rect2 = game.touch_caption_button.get_rect()
    _assert(small.size.y >= 44 and small.end.x <= 320.0 and
        not small.intersects(game.touch_pause_button.get_rect()),
        "Physical CC tap remains usable and nonoverlapping at 320px")
    game.session.core_scanned = true
    game.session.priority_id = ""
    game._refresh_radio_ui()
    _assert(game.priority_panel.visible and not game.radio_panel.visible,
        "Pinned subtitle may never obscure the real crew/core priority buttons")
    game.session.core_scanned = false
    game._refresh_radio_ui()
    _assert(game.radio_panel.visible,
        "Once a true decision is dismissed, pinned authored caption returns")
    _assert(game.session.switches==initial_game["switches"] and
        game.session.faults==initial_game["faults"] and
        game.session.relays_activated==initial_game["relays_activated"],
        "Display preferences may never complete a fictional mission or switch power")
    game.queue_free()
    _finish()
