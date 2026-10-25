extends Node
## W24: original synthesized sound cues, no third-party audio or web network.
## Always provide visible text equivalents. Muted on first run: browser policy
## requires an actual user gesture and player opt-in before ANY audible cue.
const SAVE_PATH = "user://r135_audio_preferences_v1.cfg"
const SCHEMA_VERSION = 1
const SAMPLE_RATE = 22050
const CUE_DURATIONS = {
    "mission": 0.18, "diagnosis": 0.20,
    "drive_start": 0.15, "drive_stop": 0.14,
    "hatch": 0.16, "scan": 0.20, "blocked": 0.22
}
const CUE_FREQS = {
    "mission": 440.0, "diagnosis": 520.0,
    "drive_start": 460.0, "drive_stop": 285.0,
    "hatch": 335.0, "scan": 660.0, "blocked": 185.0
}
const CAPTIONS_RU = {
    "mission": "Учебная миссия начата",
    "diagnosis": "Запущена диагностика учебного узла",
    "drive_start": "Привод запущен",
    "drive_stop": "Привод остановлен",
    "hatch": "Положение сервисного люка изменено",
    "scan": "Учебное сканирование выполнено",
    "blocked": "Опасное действие заблокировано симулятором"
}
const CAPTIONS_EN = {
    "mission": "Simulated service mission started",
    "diagnosis": "Simulated diagnostic case started",
    "drive_start": "Virtual drive started",
    "drive_stop": "Virtual drive stopped",
    "hatch": "Service hatch target changed",
    "scan": "Simulated target scan completed",
    "blocked": "Unsafe input blocked by the training interlock"
}
var muted: bool = true
var locale: String = "ru"
var last_caption: String = ""
var last_cue: String = ""
var cue_count: int = 0
var audible_count: int = 0
var last_save_ok: bool = true
var player: AudioStreamPlayer
var cues: Dictionary = {}


func _ready() -> void:
    player = AudioStreamPlayer.new()
    player.name = "GenuineOptInProceduralAudio"
    player.autoplay = false
    player.volume_db = -18.0  # Low ceiling; no startling machinery noises.
    add_child(player)
    _load()
    # Never call play() from initialization, page load or scene visibility.


func _load() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        muted = true
        return
    if typeof(cfg.get_value("audio", "schema", null)) != TYPE_INT or \
            int(cfg.get_value("audio", "schema", -1)) != SCHEMA_VERSION:
        muted = true
        return
    var candidate: Variant = cfg.get_value("audio", "muted", null)
    muted = candidate if typeof(candidate) == TYPE_BOOL else true


func set_muted(value: bool) -> void:
    muted = value
    if muted and player != null:
        player.stop()
    var cfg := ConfigFile.new()
    cfg.set_value("audio", "schema", SCHEMA_VERSION)
    cfg.set_value("audio", "muted", muted)
    last_save_ok = cfg.save(SAVE_PATH) == OK


func switch_locale(value: String) -> void:
    locale = "en" if value == "en" else "ru"
    if last_cue in CAPTIONS_RU:
        last_caption = str(CAPTIONS_EN[last_cue] if locale == "en" else CAPTIONS_RU[last_cue])


func cue(code: String) -> void:
    if not (code in CUE_DURATIONS):
        return
    last_cue = code
    last_caption = str(CAPTIONS_EN[code] if locale == "en" else CAPTIONS_RU[code])
    cue_count += 1
    # Visual text is always available; audio is strictly opt-in.
    if muted or player == null:
        return
    if not cues.has(code):
        cues[code] = _wave(code)
    player.stream = cues[code]
    player.play()
    audible_count += 1


func _wave(code: String) -> AudioStreamWAV:
    # Short original decay tones, not recordings of industrial machinery.
    var duration: float = float(CUE_DURATIONS[code])
    var frequency: float = float(CUE_FREQS[code])
    var count: int = maxi(1, roundi(duration * SAMPLE_RATE))
    var sample_bytes := PackedByteArray()
    sample_bytes.resize(count * 2)
    for i in range(count):
        var time: float = float(i) / SAMPLE_RATE
        var progress: float = clampf(float(i) / float(count), 0.0, 1.0)
        var envelope: float = powf(1.0 - progress, 2.0)
        var w: float = sin(TAU * frequency * time)
        var sample: int = clampi(roundi(w * envelope * 11000.0), -32768, 32767)
        sample_bytes[i * 2] = sample & 255
        sample_bytes[i * 2 + 1] = (sample >> 8) & 255
    var result := AudioStreamWAV.new()
    result.format = AudioStreamWAV.FORMAT_16_BITS
    result.mix_rate = SAMPLE_RATE
    result.stereo = false
    result.data = sample_bytes
    return result


func snapshot() -> Dictionary:
    return {
        "schema": SCHEMA_VERSION, "muted": muted,
        "saved": last_save_ok, "caption": last_caption,
        "last_cue": last_cue, "cue_count": cue_count,
        "audible_count": audible_count,
        "autoplay": player.autoplay if player != null else false,
        "volume_db": player.volume_db if player != null else -80.0,
        "simulation_only": true,
        "uses_external_audio": false
    }
