extends SceneTree
## G1 real objective onboarding integrated into the original Godot campaign.
## Never invokes artificial win, skip, simulated score or external APIs.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool,what: String) -> void:
    checks += 1
    if not ok:
        failures.append(what)

func _press(game: Node,key: Key) -> void:
    var event := InputEventKey.new()
    event.keycode = key
    event.pressed = true
    game._input(event)

func _run() -> void:
    var guide := IPOperatorGuide.new()
    var engine := IPCrisisEngine.new()
    engine.reset("blackout")
    guide.reset(engine)
    var original: Dictionary = engine.checkpoint()
    var first: Dictionary = guide.request(engine,"ru")
    _assert(first.get("schema")=="IRON_PULSE_OPERATOR_GUIDE_G1" and
        first.get("objective")=="scan" and first.get("tier")==1,
        "Real GRID operation starts with actual scanner objective")
    _assert(str(first["text"]).contains("СКАНИРОВАНИЕ") and
        not str(first["text"]).contains("ПРОВАЛ"),
        "RU onboarding is genuinely contextual, not a fake outcome")
    _assert(first.get("source_derived") and not first.get("real_gameplay_modified") and
        not first.get("telemetry_uploaded"),"Hints are strictly read-only and offline")
    _assert(engine.checkpoint()==original,"Getting an operator hint never changes simulation")
    var second: Dictionary = guide.request(engine,"ru")
    var third: Dictionary = guide.request(engine,"en")
    _assert(second["tier"]==2 and third["tier"]==3 and
        str(third["text"]).contains("REACTOR SCAN"),
        "Pressing F1 progressively reveals three bilingual real-source hints")
    _assert(guide.request(engine,"en")["tier"]==3,"Hints never grow without bound")
    for i in range(155):
        guide.observe(0.2,engine,true)
    _assert(guide.readout(engine)["stuck_hint_available"] and
        guide.seconds_on_objective>=IPOperatorGuide.STUCK_SECONDS,
        "Only observed 30s without stage progress offers an optional extra hint")
    var before_pause: float=guide.seconds_on_objective
    guide.observe(1.0,engine,true)
    guide.observe(0.1,engine,false)
    _assert(is_equal_approx(guide.seconds_on_objective,before_pause),
        "Suspended/paused frames cannot falsely mark player as idle")
    _assert(engine.scan_core(),"Real original GRID scanner is usable")
    guide.observe(0.0,engine,false)
    _assert(guide.objective=="repair" and guide.tier==0 and
        is_zero_approx(guide.seconds_on_objective),
        "Actual gameplay progress immediately resets the contextual hint tier")
    _assert(guide.request(engine,"en")["objective"]=="repair","Repair hint follows authentic engine stage")
    _assert(engine.repair_coolant(),"Real scanner progression unlocks original coolant repair")
    guide.observe(0.0,engine,false)
    var charge: Dictionary = guide.request(engine,"en")
    _assert(charge["objective"]=="charge" and str(charge["text"]).contains("DOOR"),
        "Next guidance reflects real two-power-bus/door-charge objective")
    _assert(engine.cycle_bus(1),"Original physical bus B can power door after actual repair")
    _assert(engine.powered("door"),"Native power route is now actually charging")
    _assert(str(guide.request(engine,"en")["text"]).contains("DOOR POWER: ON"),
        "Tier-2 guidance reads real DOOR power, not fake tutorial data")
    _assert(engine.checkpoint().get("schema")!=IPOperatorGuide.FORMAT,
        "Hint feature does not alter the engine save format")

    var thermal := IPCrisisEngine.new()
    thermal.reset("thermal")
    _assert(thermal.scan_core(),"HEAT scan opens a genuinely separate repair scenario")
    guide.reset(thermal)
    guide.request(thermal,"en")
    guide.request(thermal,"en")
    var heat_hint: Dictionary=guide.request(thermal,"en")
    _assert(str(heat_hint["text"]).contains("rapid Q lowers heat") and
        str(heat_hint["text"]).contains("crew"),
        "HEAT advice correctly discloses costly real emergency action")
    var breach := IPCrisisEngine.new()
    breach.reset("breach")
    _assert(breach.scan_core(),"AIR scan opens actual sealing rule")
    guide.reset(breach)
    guide.request(breach,"ru")
    guide.request(breach,"ru")
    var air_hint: Dictionary=guide.request(breach,"ru")
    _assert(str(air_hint["text"]).contains("микроутечк"),
        "AIR advice explains genuine persistent rapid-patch leak")
    var g_win := IPCrisisEngine.new()
    g_win.reset("blackout")
    g_win.scan_core()
    g_win.choose_priority("crew")
    g_win.repair_coolant()
    g_win.cycle_bus(1)
    g_win.tick(25.0)
    g_win.cycle_bus(1)
    g_win.cycle_bus(1)
    g_win.activate_override()
    g_win.escape()
    _assert(g_win.won,"Completion originates from real source-engine win path")
    _assert(guide.request(g_win,"ru").is_empty() and guide.readout(g_win).is_empty(),
        "No guide can falsely open after real mission victory")

    # Native Godot HUD, keyboard, touch, language, real 3D navigation
    var scene: PackedScene=load("res://Main.tscn")
    _assert(scene!=null,"Original Godot 3D scene still imports")
    if scene == null:
        _finish()
        return
    var game=scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _assert(game.guide_panel!=null and not game.guide_panel.visible and
        game.touch_guide_button.get_global_rect().size.y>=44 and
        game.touch_navigation_button.get_global_rect().size.y>=44,
        "Real game mounts optional help overlay, hidden at intro")
    _press(game,KEY_F1)
    _assert(not game.guide_panel.visible,"F1 cannot fabricate in-game help before start")
    game.start_run()
    var native_start: Dictionary=game.session.checkpoint()
    _press(game,KEY_F1)
    _assert(game.guide_panel.visible and game.guide_label.text.contains("СКАНИРОВАНИЕ"),
        "Actual keyboard F1 opens current Godot mission guidance")
    _assert(game.session.checkpoint()==native_start and
        game.operator_guide.requests==1 and game.operator_guide.tier==1,
        "In-game operator help neither pauses nor mutates the original mission")
    _press(game,KEY_F1)
    _assert(game.operator_guide.tier==2 and game.guide_label.text.contains("навигац"),
        "Repeated real keyboard input advances to contextual level 2")
    _press(game,KEY_L)
    _assert(game.locale=="en" and game.guide_label.text.contains("REACTOR SCAN") and
        game.guide_close_button.text.contains("CLOSE"),
        "Open real Godot help immediately switches with RU/EN")
    _press(game,KEY_ESCAPE)
    _assert(not game.guide_panel.visible and not game.paused,
        "ESC closes the help surface without opening pause or altering physics")
    game.touch_guide_button.pressed.emit()
    _assert(game.guide_panel.visible and game.guide_next_button.custom_minimum_size.y>=44 and
        game.guide_close_button.custom_minimum_size.y>=44,
        "Native touch GUIDE opens with real 52px next/close targets")
    game.guide_next_button.pressed.emit()
    _assert(game.operator_guide.tier==3 and game.guide_label.text.contains("The scan"),
        "Real next-step touchscreen button reveals valid escalation")
    game.guide_close_button.pressed.emit()
    _assert(not game.guide_panel.visible,"Physical touch close dismisses native guide")
    var way_before: bool=game.wayfinder.enabled
    game.touch_navigation_button.pressed.emit()
    _assert(game.wayfinder.enabled!=way_before and game.session.checkpoint()==native_start,
        "Native mobile NAV/H toggles actual 3D wayfinding, no mission changes")
    game._pause_toggle()
    _press(game,KEY_F1)
    _assert(game.paused and not game.guide_panel.visible,
        "No guide can bypass the paused control layer")
    game._resume()
    _press(game,KEY_F1)
    _assert(game.guide_panel.visible,"Guidance remains available after resume")
    game._restart()
    _assert(not game.guide_panel.visible and game.operator_guide.requests==0,
        "Restart resets tutorial history without carrying a fake previous mission")
    var saved: Dictionary=game._checkpoint_payload()
    _assert(saved.get("schema")=="IRON_PULSE_CAMPAIGN_V6" and
        not saved.has("operator_guide") and not saved.has("guided_onboarding"),
        "G1 onboarding preserves historic V6/V9 checkpoint schema")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE G1 REAL OPERATOR ONBOARDING PASS: %d engine, native HUD and mobile-access checks" % checks)
        quit(0)
        return
    for failure in failures:
        push_error("G1 ONBOARDING FAIL: "+failure)
    quit(1)
