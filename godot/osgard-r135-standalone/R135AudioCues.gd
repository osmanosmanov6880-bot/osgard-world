extends Node
## W24: locally synthesized original, low-amplitude short audio cues.
## Never reads microphones, devices, telemetry, external media or network.
## Audio is an enhancement: the real mission and safety messages stay textual.

const SAMPLE_RATE: int = 22050
const SUPPORTED: Array[String] = ["drive_start", "drive_stop", "hatch", "scan", "success", "interlock"]
const DURATION: Dictionary = {
    "drive_start": 0.16, "drive_stop": 0.18, "hatch": 0.21,
    "scan": 0.23, "success": 0.28, "interlock": 0.20
}
const RU: Dictionary = {
    "drive_start": "УЧЕБНЫЙ ПРИВОД ЗАПУЩЕН",
    "drive_stop": "УЧЕБНЫЙ ПРИВОД ОСТАНОВЛЕН",
    "hatch": "ИЗМЕНИЛОСЬ ПОЛОЖЕНИЕ СЕРВИСНОГО ЛЮКА",
    "scan": "УЧЕБНОЕ СКАНИРОВАНИЕ ВЫПОЛНЕНО",
    "success": "ДИАГНОСТИКА ЗАВЕРШЕНА",
    "interlock": "ЗАЩИТА: КОМАНДА ОТКЛОНЕНА"
}
const EN: Dictionary = {
    "drive_start": "SIMULATED DRIVE STARTED",
    "drive_stop": "SIMULATED DRIVE STOPPED",
    "hatch": "VIRTUAL SERVICE HATCH MOVED",
    "scan": "SIMULATED DIAGNOSTIC SCAN COMPLETED",
    "success": "DIAGNOSTIC CASE COMPLETED",
    "interlock": "SAFETY INTERLOCK: ACTION REJECTED"
}

var player: AudioStreamPlayer
var sounds_enabled: bool = true
var captions_enabled: bool = true
var volume: float = 0.55
var last_event: String = ""
var last_caption: String = ""
var event_count: int = 0
var audio_play_attempts: int = 0
var sound_cache: Dictionary = {}


func _ready() -> void:
    player = AudioStreamPlayer.new()
    player.name = "LocalNoAutoplayAccessibilityPlayer"
    player.autoplay = false
    add_child(player)
    _configure_player()


func set_options(enabled: bool, captions: bool, level: float) -> void:
    sounds_enabled = enabled
    captions_enabled = captions
    volume = clampf(level, 0.0, 0.65)
    if player != null:
        _configure_player()
        if not sounds_enabled or volume <= 0.0:
            player.stop()


func _configure_player() -> void:
    # The game's original cue is deliberately capped to -3.7 dBFS at max.
    player.volume_db = linear_to_db(maxf(0.001, volume))


func _wave(event: String) -> AudioStreamWAV:
    if sound_cache.has(event):
        return sound_cache[event] as AudioStreamWAV
    if event not in SUPPORTED:
        return null
    var dur: float = float(DURATION[event])
    var total: int = int(ceil(dur * float(SAMPLE_RATE)))
    var pcm := PackedByteArray()
    pcm.resize(total * 2)
    var seed: int = 1739
    for i in range(total):
        var sec: float = float(i) / float(SAMPLE_RATE)
        var progress: float = float(i) / float(maxi(1, total - 1))
        var attack: float = minf(1.0, sec / 0.018)
        var release: float = pow(1.0 - progress, 2.1)
        var envelope: float = attack * release
        var freq: float = 270.0
        var value: float = 0.0
        match event:
            "drive_start":
                freq = 170.0 + 130.0 * progress
                value = sin(TAU * freq * sec) * 0.23
            "drive_stop":
                freq = 300.0 - 190.0 * progress
                value = sin(TAU * freq * sec) * 0.23
            "hatch":
                seed = (seed * 1103515245 + 12345) & 0x7fffffff
                var noise: float = (float(seed) / 1073741824.0) - 1.0
                value = sin(TAU * (320.0 - 90.0 * progress) * sec) * 0.19 + noise * 0.018
            "scan":
                freq = 610.0 + 280.0 * progress
                value = sin(TAU * freq * sec) * 0.20 + sin(TAU * 2.0 * freq * sec) * 0.045
            "success":
                freq = 587.3 if progress < 0.49 else 784.0
                value = sin(TAU * freq * sec) * 0.21
            "interlock":
                freq = 195.0 if int(progress * 6.0) % 2 == 0 else 144.0
                value = sin(TAU * freq * sec) * 0.24
        var sample: int = clampi(int(roundf(value * envelope * 32767.0)), -32768, 32767)
        if sample < 0:
            sample += 65536
        pcm[2 * i] = sample & 255
        pcm[2 * i + 1] = (sample >> 8) & 255
    var result := AudioStreamWAV.new()
    result.format = AudioStreamWAV.FORMAT_16_BITS
    result.mix_rate = SAMPLE_RATE
    result.stereo = false
    result.loop_mode = AudioStreamWAV.LOOP_DISABLED
    result.data = pcm
    sound_cache[event] = result
    return result


func announce(event: String, locale: String = "ru") -> bool:
    if event not in SUPPORTED:
        return false
    last_event = event
    last_caption = str(EN[event]) if locale == "en" else str(RU[event])
    event_count += 1
    if sounds_enabled and volume > 0.0 and player != null:
        var clip: AudioStreamWAV = _wave(event)
        if clip != null:
            player.stream = clip
            player.play()
            audio_play_attempts += 1
    return true


func clear_caption() -> void:
    last_caption = ""


func snapshot() -> Dictionary:
    return {
        "schema": "OSGARD_R135_AUDIO_W24_V1",
        "simulation_only": true,
        "sounds_enabled": sounds_enabled,
        "captions_enabled": captions_enabled,
        "volume": volume,
        "caption": last_caption if captions_enabled else "",
        "last_event": last_event,
        "events_from_user_actions": event_count,
        "play_attempts": audio_play_attempts,
        "autoplay": false,
        "local_only": true
    }
