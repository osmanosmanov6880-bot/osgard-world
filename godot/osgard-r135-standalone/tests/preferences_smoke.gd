extends SceneTree
## W20 native QA: real Godot UI signals, settings isolation and reload.
## Runs in Actions ephemeral user://; restores any preexisting local settings.

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("W20 PREFERENCES FAILED: " + message)
    quit(1)


func _run() -> void:
    var prefs = preload("res://R135PlayerPreferences.gd")
    var fixture := "user://r135_w20_settings_fixture.cfg"
    var profile := str(prefs.SAVE_PATH)
    var old_exists: bool = FileAccess.file_exists(profile)
    var old_bytes := FileAccess.get_file_as_bytes(profile) if old_exists else PackedByteArray()
    # Bad file/schema cannot inject arbitrary locale, quality or motion.
    var defaults: Dictionary = prefs.load_local(true, fixture)
    if str(defaults["locale"]) != "ru" or int(defaults["quality"]) != 0 or not bool(defaults["reduced_motion"]):
        _fail("Clean profile should be Russian ECO, with OS motion preference")
        return
    var invalid := ConfigFile.new()
    invalid.set_value("settings", "schema", 17)
    invalid.set_value("settings", "locale", "es")
    invalid.set_value("settings", "quality", 9)
    invalid.set_value("settings", "reduced_motion", "false")
    if invalid.save(fixture) != OK:
        _fail("Cannot create isolated malformed-profile fixture")
        return
    defaults = prefs.load_local(true, fixture)
    if bool(defaults["loaded"]) or int(defaults["quality"]) != 0 or str(defaults["locale"]) != "ru":
        _fail("Mismatched schema must fall back to bounded defaults")
        return
    invalid.set_value("settings", "schema", 1)
    invalid.save(fixture)
    defaults = prefs.load_local(true, fixture)
    if str(defaults["locale"]) != "ru" or int(defaults["quality"]) != 0 or not bool(defaults["reduced_motion"]):
        _fail("Malformed keys leaked unsafe settings into player profile")
        return
    if prefs.save_local("es", 2, false, fixture) or prefs.save_local("ru", 17, false, fixture):
        _fail("Invalid locale or quality was stored")
        return
    if not prefs.save_local("en", 2, true, fixture):
        _fail("Valid settings could not be saved")
        return
    var restored: Dictionary = prefs.load_local(false, fixture)
    if not bool(restored["loaded"]) or str(restored["locale"]) != "en" or int(restored["quality"]) != 2 or not bool(restored["reduced_motion"]):
        _fail("Settings did not survive an actual local file reload")
        return

    if not prefs.save_local("ru", 0, false):
        _fail("Cannot initialize predictable temporary native game state")
        return
    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    if packed == null:
        _fail("Real Godot game scene absent")
        return
    var scene: Node = packed.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame
    var luxury: Control = scene.get("premium_intro") as Control
    var director: Node = scene.get("controller") as Node
    if luxury == null or director == null:
        _fail("Interactive premium user settings lost main scene")
        return
    var settings_button: Button = luxury.get("settings_button") as Button
    var quality_button: Button = luxury.get("settings_quality_button") as Button
    var motion_button: Button = luxury.get("settings_motion_button") as Button
    var language_button: Button = luxury.get("language_button") as Button
    var settings_panel: PanelContainer = luxury.get("settings_panel") as PanelContainer
    if settings_button == null or quality_button == null or motion_button == null or language_button == null or settings_panel == null:
        _fail("User settings must expose real focusable, connected Godot buttons")
        return
    if settings_button.custom_minimum_size.x < 44 or not settings_button.focus_mode == Control.FOCUS_ALL:
        _fail("W20 settings is not keyboard and touch accessible")
        return
    var commands: Array = scene.get("action_buttons")
    if commands.size() != 8:
        _fail("Player settings replaced original eight functional operator commands")
        return
    settings_button.pressed.emit()
    await process_frame
    if not bool(luxury.get("settings_open")) or not settings_panel.visible or bool((luxury.get("card") as PanelContainer).visible):
        _fail("W20 settings button not switching to real scrollable card")
        return
    quality_button.pressed.emit()
    await process_frame
    var selected: Dictionary = prefs.load_local()
    if int(scene.get("quality")) != 2 or int(selected["quality"]) != 2 or not bool(scene.get("preferences_save_ok")):
        _fail("HERO graphics toggle did not persist from the actual UI signal")
        return
    if not str(director.call("summary").get("loaded", "")).ends_with("service_spine_hero.glb"):
        _fail("Graphics toggle must switch real source model, not text alone")
        return
    motion_button.pressed.emit()
    selected = prefs.load_local()
    if not bool(scene.get("reduced_motion")) or not bool(selected["reduced_motion"]):
        _fail("Accessibility setting did not save")
        return
    language_button.pressed.emit()
    selected = prefs.load_local()
    if str(scene.get("ui_locale")) != "en" or str(selected["locale"]) != "en":
        _fail("RU/EN button did not save selected player language")
        return
    if not str((luxury.get("settings_title") as Label).text).contains("PLAYER"):
        _fail("English settings was not applied to real controls")
        return
    settings_button.pressed.emit()
    if bool(luxury.get("settings_open")) or not (luxury.get("card") as PanelContainer).visible:
        _fail("Settings cannot return to existing actual six-chapter course")
        return
    scene.queue_free()
    await process_frame
    var resumed: Node = packed.instantiate()
    root.add_child(resumed)
    await process_frame
    await process_frame
    if str(resumed.get("ui_locale")) != "en" or int(resumed.get("quality")) != 2 or not bool(resumed.get("reduced_motion")):
        _fail("Actual new Godot scene did not restore user profile after restart")
        return
    var saved_director: Node = resumed.get("controller") as Node
    if not str(saved_director.call("summary").get("loaded", "")).ends_with("service_spine_hero.glb"):
        _fail("Restored display profile did not load real HERO GLB")
        return
    resumed.queue_free()
    await process_frame
    if old_exists:
        var stream := FileAccess.open(profile, FileAccess.WRITE)
        if stream == null:
            _fail("Unable to restore existing local player settings")
            return
        stream.store_buffer(old_bytes)
        stream.close()
    else:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(profile))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
    print("W20 PLAYER SETTINGS PASS: real controls, strict validation, persistence, W14/W19 progress isolated")
    quit(0)
