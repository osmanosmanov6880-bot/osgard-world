extends SceneTree
## W24: functional audio generator, no autoplay, real interlock captions,
## 44px keyboard/touch settings and independent safe on-disk preferences.
func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("W24 AUDIO ACCESSIBILITY FAILED: " + message)
    quit(1)


func _run() -> void:
    var prefs = preload("res://R135AudioPreferences.gd")
    var test_file := "user://w24_audio_test_isolation.cfg"
    var base: Dictionary = prefs.load_local(test_file)
    if base.get("schema") != 1 or base.get("sound_enabled") != false or base.get("captions_enabled") != true:
        _fail("Default audio is not explicitly opt-in with readable text captions")
        return
    if prefs.save_local(true, false, 0.85, test_file):
        _fail("Unsafe excessive volume must be rejected")
        return
    if not prefs.save_local(true, true, 0.25, test_file):
        _fail("Safe local audio profile failed to save")
        return
    var restored: Dictionary = prefs.load_local(test_file)
    if not restored.get("sound_enabled", false) or not restored.get("captions_enabled", false) or not is_equal_approx(float(restored.get("volume", -1)), 0.25):
        _fail("Actual local audio profile did not survive file reload")
        return
    DirAccess.remove_absolute(ProjectSettings.globalize_path(test_file))

    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    if packed == null:
        _fail("Real W19 Godot scene missing")
        return
    var scene: Node3D = packed.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame
    scene.call("_set_locale", "ru")
    var cue: Node = scene.get("audio_cues") as Node
    var course: Control = scene.get("premium_intro") as Control
    var rig: Node = scene.get("controller") as Node
    if cue == null or course == null or rig == null:
        _fail("Actual simulator, course and sound director not connected")
        return
    var sound: AudioStreamPlayer = cue.get("player") as AudioStreamPlayer
    if sound == null or sound.autoplay or sound.playing or int(cue.get("event_count")) != 0:
        _fail("Forbidden autoplay or unauthenticated sound on first launch")
        return
    var buttons: Array[Button] = [
        course.get("settings_audio_button") as Button,
        course.get("settings_volume_button") as Button,
        course.get("settings_caption_button") as Button
    ]
    for control in buttons:
        if control == null or control.focus_mode != Control.FOCUS_ALL or control.disabled:
            _fail("Actual audio settings must be keyboard/touch operable")
            return
    var wav: AudioStreamWAV = cue.call("_wave", "scan") as AudioStreamWAV
    if wav == null or wav.mix_rate != 22050 or wav.format != AudioStreamWAV.FORMAT_16_BITS:
        _fail("Original scan cue must be native, deterministic mono 16-bit PCM")
        return
    var raw: PackedByteArray = wav.data
    if raw.size() < 7000 or raw.size() > 14000:
        _fail("Cue duration or audio data bandwidth outside bounded budget")
        return
    var nonzero: bool = false
    for sample in raw:
        if sample != 0:
            nonzero = true
            break
    if not nonzero:
        _fail("Generated sound does not contain real audio samples")
        return

    scene.call("_set_audio_enabled", false)
    scene.call("_set_audio_captions", true)
    scene.call("_start_mission")
    if int(cue.get("event_count")) != 0:
        _fail("Starting lesson may not autoplay sounds")
        return
    scene.call("_toggle_hatch") # Actual moving drive must reject unsafe open.
    var machine: Dictionary = rig.call("summary")
    if not str(machine.get("mission_feedback", "")).begins_with("SAFETY INTERLOCK"):
        _fail("Real machine refused to report unsafe hatch opening")
        return
    var state: Dictionary = cue.call("snapshot")
    if str(state["last_event"]) != "interlock" or not str(state["caption"]).contains("ЗАЩИТА") or int(state["play_attempts"]) != 0:
        _fail("Safety refusal must always have text and never require audio")
        return
    scene.call("_toggle_motion")
    if str(cue.get("last_event")) != "drive_stop" or not str(cue.get("last_caption")).contains("ОСТАНОВЛЕН"):
        _fail("Real simulated safe drive stop did not announce its state")
        return
    scene.call("_toggle_hatch")
    if str(cue.get("last_event")) != "hatch" or float(rig.call("summary").get("lid_target", 0.0)) != 1.0:
        _fail("Real hatch movement does not trigger localized action cue")
        return

    # Real Godot button toggles, not injected UI flags.
    (buttons[0] as Button).pressed.emit()
    if not bool(cue.get("sounds_enabled")) or not bool(prefs.load_local().get("sound_enabled", false)):
        _fail("Mouse/touch sound button failed to persist user's opt-in")
        return
    (buttons[1] as Button).pressed.emit()
    if float(cue.get("volume")) < 0.0 or float(cue.get("volume")) > 0.65:
        _fail("True volume settings exceeded 65% cap")
        return
    (buttons[2] as Button).pressed.emit()
    if bool(cue.get("captions_enabled")):
        _fail("Real captions button failed to toggle preference")
        return
    (buttons[2] as Button).pressed.emit()
    if not bool(cue.get("captions_enabled")):
        _fail("Accessible captions could not be restored")
        return
    (buttons[0] as Button).pressed.emit()
    if bool(cue.get("sounds_enabled")):
        _fail("Player cannot mute sound through actual settings")
        return

    scene.call("_set_locale", "en")
    scene.call("_toggle_hatch") # a stopped open hatch => safely closes.
    if str(cue.get("last_event")) != "hatch" or not str(cue.get("last_caption")).contains("HATCH"):
        _fail("English accessible text is not localized to action")
        return
    if bool(cue.call("snapshot").get("autoplay", true)) or not bool(cue.call("snapshot").get("local_only", false)):
        _fail("Audio cues may not autoplay or access external services")
        return
    var audio: Dictionary = cue.call("snapshot")
    if int(audio["events_from_user_actions"]) < 4:
        _fail("Real operator audio is not counting actual game commands")
        return
    var caption: Label = course.get("audio_caption_label") as Label
    if caption == null or not caption.visible or not caption.text.contains("HATCH"):
        _fail("Readable text alternative not present in the real Godot training panel")
        return
    if not bool(rig.call("summary").get("simulation_only", false)):
        _fail("Audio must not convert game mechanics to physical telemetry")
        return
    print("W24 ORIGINAL AUDIO PASS: no autoplay, deterministic PCM, physical safety interlocks, UI volume/mute/captions, RU/EN and isolated save")
    scene.queue_free()
    quit(0)
