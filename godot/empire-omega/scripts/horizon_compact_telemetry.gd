extends RefCounted
## HORIZON R8: deterministic two-line mobile telemetry. The compact speed card
## has space for two lines, not a desktop-size stack of status messages.
## Game state, physics, fuel and damage are NOT modified by formatting.
const LOCALES = {
    "ru": {"speed":"км/ч", "brake":"РУЧНИК", "drift":"ДРИФТ", "grip":"СЦЕП", "fuel":"Т", "health":"К"},
    "en": {"speed":"km/h", "brake":"PARK", "drift":"DRIFT", "grip":"GRIP", "fuel":"F", "health":"C"},
    "zh": {"speed":"公里", "brake":"手刹", "drift":"漂移", "grip":"抓地", "fuel":"油", "health":"车"}
}

static func speed_lines(speed: float, gear: String, fuel: float, condition: float,
        handbrake: bool, drift_score: int, assist_power: float, assist_steering: float,
        locale: String = "ru") -> String:
    var tr: Dictionary = LOCALES.get(locale, LOCALES["ru"])
    var safe_speed: float = absf(speed) if is_finite(speed) else 0.0
    var safe_fuel: float = fuel if is_finite(fuel) else 0.0
    var safe_health: float = condition if is_finite(condition) else 0.0
    var first: String = "%d %s · %s" % [roundi(minf(safe_speed * 3.6, 999.0)),tr["speed"],gear.strip_edges().left(3)]
    var intervention: float = clampf(maxf(assist_power,assist_steering*3.0),0.0,1.0)
    var second: String = ""
    if handbrake:
        second = str(tr["brake"])
    elif drift_score >= 12:
        second = "%s %d" % [tr["drift"],maxi(0,drift_score)]
    elif intervention >= 0.025:
        second = "%s %d%%" % [tr["grip"],roundi(intervention*100.0)]
    else:
        second = "%s%d%% · %s%d%%" % [tr["fuel"],roundi(clampf(safe_fuel,0.0,100.0)),tr["health"],roundi(clampf(safe_health,0.0,100.0))]
    return first+"\n"+second
