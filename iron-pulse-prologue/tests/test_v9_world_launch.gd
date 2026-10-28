extends SceneTree
## V9 world portal: only allow explicitly supported URL-configured actual
## Godot missions/languages. Never interpret user strings as script commands.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _run() -> void:
    var default: Dictionary = IPLaunchConfig.parse("")
    _check(default == {"scenario":"blackout","lang":"ru"},
        "No URL parameter always starts current real default GRID/RU game")
    _check(IPLaunchConfig.parse("?scenario=thermal&lang=en") == {"scenario":"thermal","lang":"en"},
        "World portal launch opens actual HEAT in English")
    _check(IPLaunchConfig.parse("?lang=ru&scenario=breach") == {"scenario":"breach","lang":"ru"},
        "World portal launch opens actual AIR in Russian")
    _check(IPLaunchConfig.parse("?scenario=blackout&lang=en") == {"scenario":"blackout","lang":"en"},
        "International GRID mission without another game build")
    _check(IPLaunchConfig.parse("?scenario=not-real&lang=es") == default,
        "Unknown fourth mission and unsupported locale rejected")
    _check(IPLaunchConfig.parse("?scenario=%74hermal&lang=EN") == {"scenario":"thermal","lang":"en"},
        "URL encoding and safe-case normalization supported")
    _check(IPLaunchConfig.parse("?scenario=../../secret&lang=ru") == default,
        "Traversal-looking query cannot choose arbitrary scene paths")
    _check(IPLaunchConfig.parse("?scenario=javascript%3Aalert(1)&lang=%3Cscript%3E") == default,
        "HTML/JS injection strings never enter Godot interface configuration")
    _check(IPLaunchConfig.parse("?" + "x".repeat(IPLaunchConfig.MAX_QUERY+1)) == default,
        "Oversized query ignored without parsing untrusted data")
    _check(IPLaunchConfig.parse("?autoStart=true&quality=god&scenario=thermal")["scenario"] == "thermal",
        "Only documented scenario/lang fields affect actual game")
    _check(IPLaunchConfig.parse("?scenario=unknown&scenario=breach")["scenario"] == "breach",
        "Mixed invalid and valid keys cannot prevent legitimate operations")
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V9 WORLD LAUNCH PASS: %d strict launch-config checks" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error("V9 LAUNCH FAIL: " + failure)
        quit(1)
