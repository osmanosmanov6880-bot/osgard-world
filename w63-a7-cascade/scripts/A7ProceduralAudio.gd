extends Node
class_name A7ProceduralAudio
## W65: original short software-generated tones. No external assets/licenses,
## auto-playing music, microphone permissions, analytics or network connection.

const SAMPLE_RATE := 22050.0
const VALID := ["action", "incident", "danger", "win", "loss", "restart"]

var muted: bool = false
var last_cue: String = ""
var accepted_cues: int = 0
var audible_requests: int = 0
var player: AudioStreamPlayer
var _remaining: float = 0.0
var _total: float = 0.0
var _phase: float = 0.0
var _frequency: float = 440.0
var _gain: float = 0.08
var _emitted_frames: int = 0

func _ready() -> void:
    name = "A7OriginalProceduralEventAudio"
    var stream := AudioStreamGenerator.new()
    stream.mix_rate = SAMPLE_RATE
    stream.buffer_length = 0.16
    player = AudioStreamPlayer.new()
    player.name = "RealGodotLocalToneSource"
    player.stream = stream
    player.volume_db = -13.0
    add_child(player)
    set_process(true)

func set_muted(new_value: bool) -> void:
    muted = new_value
    if muted:
        _remaining = 0.0
        if player != null and player.playing:
            player.stop()

func cue(kind: String) -> bool:
    if not VALID.has(kind):
        return false
    last_cue = kind
    accepted_cues += 1
    if muted:
        return true
    audible_requests += 1
    match kind:
        "action":
            _frequency = 380.0
            _total = 0.10
            _gain = 0.065
        "incident":
            _frequency = 260.0
            _total = 0.18
            _gain = 0.080
        "danger":
            _frequency = 170.0
            _total = 0.30
            _gain = 0.095
        "win":
            _frequency = 570.0
            _total = 0.40
            _gain = 0.076
        "loss":
            _frequency = 140.0
            _total = 0.35
            _gain = 0.070
        "restart":
            _frequency = 310.0
            _total = 0.13
            _gain = 0.058
    _phase = 0.0
    _remaining = _total
    if player != null and not player.playing:
        player.play()
    return true

func _process(_delta: float) -> void:
    if player == null or muted or _remaining <= 0.0 or not player.playing:
        return
    var playback: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
    if playback == null:
        return
    var count: int = mini(playback.get_frames_available(), 4096)
    for i in range(count):
        if _remaining <= 0.0:
            break
        # No prerecorded sounds, no non-public-domain melody playback.
        var elapsed: float = _total - _remaining
        var attack: float = clampf(elapsed / 0.012, 0.0, 1.0)
        var release: float = clampf(_remaining / 0.08, 0.0, 1.0)
        var amplitude: float = _gain * attack * release
        var wave: float = sin(_phase * TAU) * amplitude
        playback.push_frame(Vector2(wave, wave))
        _phase = fposmod(_phase + _frequency / SAMPLE_RATE, 1.0)
        _remaining -= 1.0 / SAMPLE_RATE
        _emitted_frames += 1
    if _remaining <= 0.0:
        player.stop()

func qa_readout() -> Dictionary:
    return {
        "schema": "A7_W65_ORIGINAL_GENERATIVE_SOUND_V1",
        "source": "AudioStreamGenerator", "real_stream": player != null and
            player.stream is AudioStreamGenerator,
        "muted": muted, "last_cue": last_cue,
        "accepted_cues": accepted_cues,
        "audible_requests": audible_requests,
        "frames_generated_in_current_runtime": _emitted_frames,
        "uses_external_music": false, "uses_microphone": false,
        "physical_audio_hardware_verified": false,
    }
