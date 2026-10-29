extends SceneTree
## V13 real world-portal launch contract and original 3-act Godot scene.
var checks: int = 0
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(good: bool, reason: String) -> void:
    checks += 1
    if not good:
        errors.append(reason)

func _run() -> void:
    var safe: Dictionary = IPWorldLaunch.parse("?scenario=thermal&lang=en")
    _check(safe["scenario"]=="thermal" and safe["lang"]=="en" and not safe["campaign"],
        "Real website URL resolves to actual thermal scenario and English")
    var air: Dictionary = IPWorldLaunch.parse("?lang=ru&scenario=breach")
    _check(air["scenario"]=="breach" and air["lang"]=="ru","AIR scenario real deep link")
    var trio: Dictionary = IPWorldLaunch.parse("?campaign=1&lang=en&scenario=breach")
    _check(trio["campaign"] and trio["scenario"]=="blackout" and trio["lang"]=="en",
        "A campaign link cannot bypass initial GRID chapter")
    _check(IPWorldLaunch.parse("?campaign=0&scenario=breach")["campaign"]==false,
        "Explicit solo mode cannot silently enable campaign")
    _check(IPWorldLaunch.parse("?scenario=unsafe&lang=xx")["scenario"]=="blackout" and
        IPWorldLaunch.parse("?scenario=unsafe&lang=xx")["lang"]=="ru",
        "Unlisted gameplay/languages rejected with safe defaults")
    _check(not IPWorldLaunch.parse("?campaign=true")["campaign"],
        "Only explicit bounded campaign=1 is enabled")
    _check(not IPWorldLaunch.parse("?campaign=1&x="+("a".repeat(300)))["campaign"],
        "Excessive URL input cannot trigger a mission")
    _check(IPWorldLaunch.parse("?scenario=thermal&dev=win&win=1&started=true")["scenario"]=="thermal",
        "Unknown command-like keys cannot affect legitimate choice")
    var path: PackedScene = load("res://Main.tscn")
    _check(path != null, "Real 3D Godot engine scene loads")
    if path == null:
        _finish()
        return
    var game = path.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _check(not game.started and not game.campaign.active and game.session.scenario_id=="blackout",
        "Direct desktop launch preserves historical standalone BLACKOUT state")
    game._apply_world_launch("?scenario=thermal&lang=en")
    _check(game.selected_scenario=="thermal" and game.session.scenario_id=="thermal",
        "Actual game physics engine receives portal HEAT launch")
    _check(game.locale=="en" and game.story.scenario=="thermal",
        "Real bilingual MARA narrative follows portal language/scenario")
    _check(game.session.heat>=70.0 and game.session.heat<=75.0,
        "HEAT URL changes real reactor temperature, not a fake frontend label")
    _check(not game.started and game.intro_panel.visible,
        "Deep link does not auto-start, teleport or award points")
    _check(not game.campaign.active and game.campaign.records.is_empty(),
        "Standalone URL does not fabricate campaign progression")
    game._apply_world_launch("?campaign=1&lang=en&scenario=breach")
    _check(game.campaign.active and game.campaign.index==0 and game.campaign.records.is_empty(),
        "Actual three-act campaign initialized with no pre-awarded victories")
    _check(game.selected_scenario=="blackout" and game.session.scenario_id=="blackout",
        "Campaign URL attempts to skip final act are blocked by source game")
    _check(game.world_launch["campaign"] and game.world_launch["lang"]=="en",
        "Read-only launch state reflects intentional campaign mode")
    _check(game._checkpoint_payload()["campaign"]["schema"]==IPCampaignFlow.FORMAT,
        "Original V9-V12 atomic save format survives world integration")
    game._select_scenario("breach")
    _check(not game.campaign.active and game.selected_scenario=="breach",
        "Explicitly choosing solo AIR cancels previous campaign launch")
    game._apply_world_launch("?campaign=1&lang=ru")
    game.start_run()
    _check(game.started and game.campaign.active and game.session.scenario_id=="blackout",
        "Start button begins actual GRID story campaign with correct rules")
    var initial: Dictionary = game.session.checkpoint()
    game._apply_world_launch("?scenario=breach&lang=en")
    _check(game.started and game.campaign.active and game.locale=="ru",
        "Untrusted new URL cannot replace an already running actual mission")
    _check(game.session.checkpoint()==initial,
        "Deep-link parser cannot cheat ongoing reactor resources/timer")
    _check(game.terminals.size()==6 and game.relay_terminals.size()==3,
        "Physical engineering and rescue terminals preserved")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if errors.is_empty():
        print("IRON PULSE V13 WORLD LAUNCH PASS: %d native integration checks" % checks)
        quit(0)
    else:
        for issue in errors:
            push_error("V13 WORLD LAUNCH FAIL: "+issue)
        quit(1)
