extends SceneTree
## W65 actual Godot narrative causality, original generated audio and mute.
## This is not consumer speaker quality or published soundtrack certification.
var assertions: int = 0
var failed: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, description: String) -> void:
    assertions += 1
    if not value:
        failed.append(description)

func _run() -> void:
    var core := A7CascadeCore.new()
    var untouched: Dictionary = core.snapshot()
    for locale in ["ru", "en"]:
        var ids: Array[String] = []
        for index in range(6):
            var fixture: Dictionary = untouched.duplicate(true)
            fixture["shift"] = index
            var chapter: Dictionary = A7IncidentDirector.describe(locale, fixture)
            _check(not str(chapter.get("title", "")).is_empty(),
                "Six narrative beat titles localized in %s/%d" % [locale, index])
            _check(str(chapter.get("body", "")).length() > 24,
                "Six distinct descriptive chapter bodies in %s/%d" % [locale, index])
            ids.append(str(chapter["id"]))
        _check(ids.size() == 6 and ids[0] != ids[5] and ids[2] != ids[3],
            "Six genuine non-duplicate progression entries per language")
        for outcome in ["won", "failed", "unstable"]:
            var scene_state: Dictionary = untouched.duplicate(true)
            scene_state["status"] = outcome
            var finale: Dictionary = A7IncidentDirector.describe(locale, scene_state)
            _check(str(finale["id"]) == outcome,
                "Terminal outcome uses actual state, %s/%s" % [locale, outcome])
            _check(str(finale["body"]).length() > 25,
                "Game has a distinct readable outcome explanation")

    var all_state: Dictionary = untouched["metrics"].duplicate(true)
    for action in ["PUMP", "VENT", "SEAL", "SCAN", "POWER"]:
        for locale in ["ru", "en"]:
            var before: Dictionary = all_state.duplicate(true)
            var forecast: Dictionary = A7IncidentDirector.preview(locale, action, all_state)
            _check(bool(forecast.get("valid", false)), "Real rule exists for %s/%s" % [locale, action])
            _check(not str(forecast["body"]).is_empty(), "Direct effect preview explains tradeoff")
            _check(all_state == before, "Forecast cannot silently mutate existing model")
            var projected: Dictionary = forecast["projected"]
            for key in A7CascadeCore.ACTIONS[action].keys():
                _check(int(projected[key]) ==
                    clampi(int(before[key]) + int(A7CascadeCore.ACTIONS[action][key]), 0, 100),
                    "Preview agrees with actual original rule for %s/%s" % [locale, key])
            _check(not bool(forecast["industrial_advice"]), "Not real industrial equipment advice")
    var bad: Dictionary = A7IncidentDirector.preview("ru", "ILLEGAL_COMMAND", all_state)
    _check(not bool(bad["valid"]), "Preview rejects nonexistent commands")
    _check(core.snapshot() == untouched, "Entire original game state remains unchanged by narrative queries")

    var risky: Dictionary = {
        "heat": 93, "pressure": 92, "seal": 8,
        "signal": 12, "energy": 11, "integrity": 70,
    }
    var danger: Dictionary = A7IncidentDirector.preview("en", "POWER", risky)
    _check(bool(danger["risk"]), "Preview warns on genuine elevated pressure")
    _check(str(danger["headline"]).contains("RISK"), "Danger is distinguishable in text, not just color")

    var scene: PackedScene = load("res://Main.tscn") as PackedScene
    _check(scene != null, "Actual full Godot A7 gameplay scene loads")
    if scene == null:
        _finish()
        return
    var ui: A7CascadeScreen = scene.instantiate() as A7CascadeScreen
    _check(ui != null, "Actual native game has W65 screen")
    if ui == null:
        _finish()
        return
    root.add_child(ui)
    await process_frame
    await process_frame
    _check(ui.stage_3d != null, "Actual W64 cinema remains intact")
    _check(ui.model.snapshot()["status"] == "playing", "Real W63 game retained")
    _check(ui.narrative_title != null and ui.narrative_body != null and
        ui.forecast_label != null, "Native W65 readable story and action preview labels")
    _check(ui.narrative_title.text.contains("ТИХИЙ"), "First original RU story visibly displayed")
    _check(ui.sound_bus != null and ui.sound_button != null, "Native sound source and player controls")
    _check(bool(ui.sound_bus.qa_readout()["real_stream"]), "Real Godot AudioStreamGenerator instantiated")
    _check(not bool(ui.sound_bus.qa_readout()["uses_external_music"]), "No licensed external music assets")
    _check(not bool(ui.sound_bus.qa_readout()["uses_microphone"]), "No microphone recording")
    _check(not ui.sound_bus.cue("UNTRUSTED"), "Unknown SFX event is rejected")
    _check(ui.sound_bus.accepted_cues == 0, "No synthetic fake audio events on game load")

    var before_preview: Dictionary = ui.model.snapshot()
    ui.action_buttons["PUMP"].emit_signal("mouse_entered")
    _check(ui.forecast_label.text.contains("тепло"), "Native mouse hover explains heat tradeoff")
    _check(ui.model.snapshot() == before_preview, "Hover cannot secretly perform gameplay command")
    ui.action_buttons["PUMP"].emit_signal("mouse_exited")
    _check(ui.forecast_label.text.contains("ВЫБЕРИТЕ"), "Preview resets on actual mouse exit")
    ui.action_buttons["VENT"].emit_signal("focus_entered")
    _check(ui.forecast_label.text.contains("давление"), "Accessible keyboard focus explains action cost")
    ui.action_buttons["VENT"].emit_signal("focus_exited")

    ui.sound_button.emit_signal("pressed")
    _check(ui.sound_bus.muted, "Actual mute button disables procedural audio")
    _check(ui.sound_button.text.contains("ВЫКЛ"), "Mute status visible in native RU")
    ui.action_buttons["PUMP"].emit_signal("pressed")
    _check(int(ui.model.snapshot()["metrics"]["heat"]) == 42, "Underlying W63 decision is still real")
    _check(ui.sound_bus.last_cue == "action", "Valid action causes original event cue")
    _check(ui.sound_bus.audible_requests == 0, "Muted sound requests do not trigger playback")
    ui.sound_button.emit_signal("pressed")
    _check(not ui.sound_bus.muted, "Actual sound button restores audio")
    ui.action_buttons["SCAN"].emit_signal("pressed")
    _check(ui.model.snapshot()["shift"] == 1, "Real next incident advances")
    _check(ui.narrative_title.text.contains("ТЕПЛОВОЙ"), "Next native RU chapter follows real incident")
    _check(ui.sound_bus.last_cue == "incident", "Incident triggers distinct original sound event")
    _check(ui.sound_bus.audible_requests == 1, "Actual sound request follows player gesture")

    ui.language_button.emit_signal("pressed")
    _check(ui.locale == "en", "Player can switch language without resetting scenario")
    _check(ui.narrative_title.text.contains("THERMAL"), "English story is independent original copy")
    ui.action_buttons["POWER"].emit_signal("mouse_entered")
    _check(ui.forecast_label.text.contains("pressure"), "EN action prediction remains readable")
    ui.action_buttons["POWER"].emit_signal("mouse_exited")
    _check(ui.model.snapshot()["shift"] == 1, "Localized previews cannot change incident cycle")

    ui.restart_button.emit_signal("pressed")
    _check(ui.narrative_title.text.contains("SILENT"), "Restart resets narrative to real first chapter")
    _check(ui.model.snapshot()["shift"] == 0, "Original gameplay reset unaffected")
    _check(ui.sound_bus.last_cue == "restart", "Restart is an original distinct tone request")

    var winning_actions: Array[String] = [
        "PUMP", "SCAN", "PUMP", "SEAL", "VENT", "SCAN",
        "VENT", "SEAL", "PUMP", "POWER", "VENT", "SCAN",
    ]
    for action in winning_actions:
        ui.action_buttons[action].emit_signal("pressed")
    _check(ui.model.snapshot()["status"] == "won", "Original deterministic W63 victory unchanged")
    _check(ui.narrative_title.text.contains("STABILIZED"), "Actual winning ending is narrated in EN")
    _check(ui.sound_bus.last_cue == "win", "Winning original game gets distinct synth cue")
    _check(ui.model.snapshot()["history"].size() == 12, "Exactly 12 meaningful player decisions")

    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failed.is_empty():
        print("LAST FRONTIER W65 ORIGINAL GAME CAUSAL STORY + SYNTH AUDIO PASS: %d assertions" % assertions)
        quit(0)
    else:
        for issue in failed:
            push_error("W65 STORY/AUDIO: " + issue)
        quit(1)
