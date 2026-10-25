extends SceneTree
## W24 sound privacy/accessibility acceptance using native Godot event signals.
## This is virtual sound waveform QA, not physical-speaker or hearing certification.
func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("W24 ACCESSIBLE AUDIO FAILED: " + reason)
    quit(1)


func _run() -> void:
    # Use isolated deterministic opt-in state; older saves are never touched.
    var path: String = ProjectSettings.globalize_path("user://r135_audio_preferences_v1.cfg")
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)
    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    if packed == null:
        _fail("Real OSGARD Godot 3D scene absent")
        return
    var scene: Node = packed.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame
    var sound: Node = scene.get("audio_cues") as Node
    var course: Control = scene.get("premium_intro") as Control
    var rig: Node = scene.get("controller") as Node
    if sound == null or course == null or rig == null:
        _fail("Actual game, sound node and native player panel not connected")
        return
    if not bool(sound.get("muted")) or not bool(sound.call("snapshot").get("simulation_only")):
        _fail("Audio must start muted and operate in simulation only")
        return
    var player: AudioStreamPlayer = sound.get("player") as AudioStreamPlayer
    if player == null or player.autoplay:
        _fail("Actual Godot player must never autoplay")
        return
    var audio_button: Button = course.get("settings_audio_button") as Button
    if audio_button == null or audio_button.focus_mode != Control.FOCUS_ALL:
        _fail("Audio opt-in must be real keyboard/touch-accessible Control")
        return
    if audio_button.custom_minimum_size.y < 43.0:
        _fail("Audio accessibility control must have touch-friendly size")
        return
    # W20 preferences are saved across native smoke steps; test RU explicitly.
    scene.call("_set_locale", "ru")
    sound.call("cue", "drive_stop")
    var state: Dictionary = sound.call("snapshot")
    if int(state.get("cue_count", 0)) != 1 or int(state.get("audible_count", 0)) != 0:
        _fail("Muted audio should still generate a caption without playback")
        return
    if not str(state.get("caption", "")).contains("Привод"):
        _fail("Real first-run Russian sound caption is missing")
        return
    scene.call("_set_locale", "en")
    if not str(sound.call("snapshot").get("caption", "")).contains("Virtual"):
        _fail("Audio caption must switch language without replaying the sound")
        return
    audio_button.pressed.emit()
    if bool(sound.get("muted")) or not bool(sound.call("snapshot").get("saved")):
        _fail("Genuine opt-in button did not persist explicit audio preference")
        return
    var wav: AudioStreamWAV = sound.call("_wave", "scan") as AudioStreamWAV
    if wav == null or wav.data.size() < 2000 or wav.mix_rate != 22050:
        _fail("Original synthesized WAV has invalid PCM length or mix rate")
        return
    scene.call("_start_mission")
    scene.call("_toggle_hatch") # virtual safety interlock rejects this click.
    state = sound.call("snapshot")
    if str(state.get("last_cue")) != "blocked" or int(state.get("audible_count", 0)) < 2:
        _fail("Safe interlock must trigger opt-in warning, not a fictional success tone")
        return
    if not str(rig.call("summary").get("mission_feedback", "")).begins_with("SAFETY INTERLOCK"):
        _fail("Audio integration bypassed the actual machine lockout")
        return
    var saved_runs: int = int(rig.call("summary").get("mission_attempts", 0))
    scene.call("_toggle_motion")
    if str(sound.call("snapshot").get("last_cue")) != "drive_stop":
        _fail("Real stopped drive must create matching audio/caption event")
        return
    audio_button.pressed.emit()
    if not bool(sound.get("muted")):
        _fail("Player unable to turn audio off")
        return
    scene.call("_toggle_hatch")
    if int(rig.call("summary").get("mission_attempts", 0)) != saved_runs:
        _fail("W24 sounds changed actual simulation mission counter")
        return
    if int(sound.call("snapshot").get("audible_count", -1)) < 2:
        _fail("Genuine opted-in sound never played")
        return
    scene.queue_free()
    await process_frame

    var again: Node = packed.instantiate()
    root.add_child(again)
    await process_frame
    await process_frame
    var restored: Node = again.get("audio_cues") as Node
    if restored == null or not bool(restored.get("muted")):
        _fail("W24 local audio preference did not survive actual scene reinitialization")
        return
    if int(restored.call("snapshot").get("schema", -1)) != 1 or \
        bool(restored.call("snapshot").get("autoplay", true)):
        _fail("Persistent audio version or autoplay contract violated")
        return
    print("W24 ACCESSIBLE AUDIO PASS: original quiet WAV, real opt-in, muting, bilingual captions, safe interlocks, isolated saved state")
    again.queue_free()
    quit(0)
