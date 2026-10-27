extends Node
class_name IPSoundscape
## Offline original procedural WAV score, no microphone/network/analytics.

var ambient: AudioStreamPlayer
var cue_player: AudioStreamPlayer
var muted: bool = false
var active: bool = false
var _cues: Dictionary = {}

func _ready() -> void:
    name = "IRON_PULSE_OriginalSoundscape"
    ambient = AudioStreamPlayer.new()
    ambient.name = "ReactorAmbientLoop"
    ambient.volume_db = -20.0
    var ambient_stream: AudioStreamWAV = load("res://audio/reactor_ambience.wav") as AudioStreamWAV
    if ambient_stream != null:
        ambient_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        ambient.stream = ambient_stream
    add_child(ambient)

    cue_player = AudioStreamPlayer.new()
    cue_player.name = "EventCue"
    cue_player.volume_db = -11.0
    add_child(cue_player)
    _cues = {
        "confirm": load("res://audio/terminal_confirm.wav"),
        "alarm": load("res://audio/containment_alarm.wav"),
        "victory": load("res://audio/evacuation_success.wav")
    }

func _exit_tree() -> void:
    # Explicitly release streaming WAV playback before SceneTree teardown.
    # Godot headless QA is fail-closed on leaked audio resources.
    if ambient != null:
        ambient.stop()
        ambient.stream = null
    if cue_player != null:
        cue_player.stop()
        cue_player.stream = null
    _cues.clear()

func set_active(should_play: bool) -> void:
    active = should_play
    if DisplayServer.get_name() == "headless":
        # Run the native simulation and verify audio resources, but never open
        # an audio device in headless test processes.
        return
    if active and not muted and ambient.stream != null and not ambient.playing:
        ambient.play()
    elif (not active or muted) and ambient.playing:
        ambient.stop()

func set_muted(value: bool) -> void:
    muted = value
    cue_player.stop()
    set_active(active)

func cue(kind: String) -> void:
    if muted or not active or DisplayServer.get_name() == "headless":
        return
    var requested: String = "confirm"
    if kind == "surge" or kind == "failure" or kind == "denied":
        requested = "alarm"
    elif kind == "victory":
        requested = "victory"
    var sound: AudioStream = _cues.get(requested) as AudioStream
    if sound != null:
        cue_player.stop()
        cue_player.stream = sound
        cue_player.play()

func set_tension(heat: float, oxygen: float) -> void:
    if ambient != null:
        var stress: float = maxf(clampf((heat-63.0)/37.0,0,1),clampf((40.0-oxygen)/40.0,0,1))
        ambient.pitch_scale = 0.94 + stress*0.15

func readout() -> Dictionary:
    return {"muted":muted,"active":active,"has_ambience":ambient != null and ambient.stream != null,
        "cue_count":_cues.size()}
