extends SceneTree
## G2: real 3D field station choices with actual resource costs, persistent
## campaign effects, old save compatibility and honest A7 black-box evidence.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool,why: String) -> void:
    checks += 1
    if not ok:
        failures.append(why)

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE G2 PHYSICAL FIELD PROTOCOLS PASS: %d source, campaign, save and 3D checks" % checks)
        quit(0)
        return
    for failure in failures:
        push_error("G2 FIELD FAIL: "+failure)
    quit(1)

func _win(engine: IPCrisisEngine) -> bool:
    if engine.finished() or not engine.core_scanned:
        return false
    if not engine.coolant_repaired:
        if not engine.repair_coolant():
            return false
    if not engine.powered("door"):
        engine.cycle_bus(1)
    engine.tick(25.0)
    engine.cycle_bus(1)
    engine.cycle_bus(1)
    return engine.activate_override() and engine.escape()

func _run() -> void:
    var locked := IPCrisisEngine.new()
    locked.reset("blackout")
    var before: Dictionary=locked.checkpoint()
    _check(not locked.activate_field_protocol("sink") and locked.field_protocol=="",
        "Unscanned real reactor cannot activate optional sink")
    _check(not locked.activate_field_protocol("air") and locked.field_protocol=="",
        "No air buffer before actual scanner")
    _check(not locked.activate_field_protocol("admin") and locked.field_protocol=="",
        "Unknown field activation must be rejected")
    _check(locked.heat==before["heat"] and locked.oxygen==before["oxygen"],
        "Rejected command gives no free heat or oxygen resources")

    var sink := IPCrisisEngine.new()
    sink.reset("thermal")
    sink.scan_core()
    var sink_heat: float=sink.heat
    var sink_air: float=sink.oxygen
    _check(sink.activate_field_protocol("sink"),"Heat sink is a real source-engine decision")
    _check(sink.field_protocol=="sink" and sink.elapsed>=IPCrisisEngine.SINK_TIME and
        sink.heat<sink_heat-10 and sink.oxygen<sink_air-6,
        "Sink exchanges actual time+air for core cooling")
    var status: Dictionary=sink.diagnostic_snapshot()
    _check(status["field_protocol"]=="sink" and status["last_event"]=="field_sink",
        "Read-only actual simulation now reveals the real player choice")
    _check(not sink.activate_field_protocol("air") and sink.field_protocol=="sink",
        "Sink locks competing air procedure; never grants both rewards")
    _check(not sink.activate_field_protocol("sink"),"Same field terminal cannot be farmed twice")
    var heat_after: float=sink.heat
    sink.tick(8.0)
    var passive_sink := IPCrisisEngine.new()
    passive_sink.reset("thermal")
    passive_sink.scan_core()
    passive_sink.tick(IPCrisisEngine.SINK_TIME+8.0)
    _check(sink.heat<passive_sink.heat-16.0 and sink.heat < heat_after+5.0,
        "Sink provides a true continuing slower heat increase, not an icon")

    var air := IPCrisisEngine.new()
    air.reset("breach")
    air.scan_core()
    air.emergency_repair()
    var air_before: float=air.oxygen
    var heat_before: float=air.heat
    _check(air.activate_field_protocol("air"),"Field air buffer activates after real AIR patch")
    _check(air.field_protocol=="air" and air.oxygen>air_before+12 and
        air.heat>heat_before+5 and air.crew_health<77.0,
        "Air buffer restores oxygen but increases actual heat and harms crew")
    var air_saved: Dictionary=air.checkpoint()
    _check(air_saved["schema"]=="IRON_PULSE_ENGINE_V6" and air_saved["field_protocol"]=="air",
        "Existing V6 engine format retains actual optional field choice")
    var resumed := IPCrisisEngine.new()
    _check(resumed.restore_checkpoint(air_saved) and resumed.field_protocol=="air",
        "True field effects survive save/restore without an untested format migration")
    var invalid: Dictionary=air_saved.duplicate(true)
    invalid["field_protocol"]="both"
    var stable: Dictionary=resumed.checkpoint()
    _check(not resumed.restore_checkpoint(invalid) and resumed.checkpoint()==stable,
        "Malformed double strategy rejected atomically")
    invalid=air_saved.duplicate(true)
    invalid["field_protocol"]=["sink","air"]
    _check(not resumed.restore_checkpoint(invalid) and resumed.checkpoint()==stable,
        "Array injection does not trick the save parser")
    invalid=air_saved.duplicate(true)
    invalid["core_scanned"]=false
    _check(not resumed.restore_checkpoint(invalid) and resumed.checkpoint()==stable,
        "Cannot forge field intervention in unscanned saves")
    var legacy: Dictionary=air_saved.duplicate(true)
    legacy.erase("field_protocol")
    var old_engine := IPCrisisEngine.new()
    _check(old_engine.restore_checkpoint(legacy) and old_engine.field_protocol=="",
        "Real V6/V9 save missing G2 key loads with NO extra resources")
    old_engine.reset("blackout")
    _check(old_engine.field_protocol=="" and old_engine.core_scanned==false,
        "Restart clears optional field choice completely")

    var seeded := IPCrisisEngine.new()
    for scenario in IPCrisisEngine.SCENARIOS:
        for protocol in IPCrisisEngine.FIELD_PROTOCOLS:
            seeded.reset(scenario)
            _check(seeded.scan_core(),"Each scenario truly scans before playing its field branch")
            _check(seeded.activate_field_protocol(protocol),"Every field path works in "+scenario)
            _check(_win(seeded) and seeded.won and seeded.field_protocol==protocol,
                "Original two-bus 3D mission remains winnable after "+scenario+"/"+protocol)

    var story := IPStoryDirector.new()
    story.reset("thermal")
    _check(story.on_game_event("field_sink","") and story.latest_key=="field_sink" and
        story.latest("en")["text"].contains("heat sink"),
        "Original MARA voice responds to actual sink choice")
    story.reset("breach")
    _check(story.on_game_event("field_air","") and story.latest("ru")["text"].contains("воздуха"),
        "Original authored RU radio explains oxygen/heat tradeoff")
    var blackbox := IPAfterActionReview.new()
    var review: Dictionary=blackbox.review(seeded)
    _check(review.get("field_protocol")=="air" and
        review["history"].has("field_air") and
        blackbox.localized(review,"en").contains("FIELD PROTOCOL"),
        "Finished true mission black box reflects real field choices")
    var archived := IPRunArchive.new()
    review["run_number"]=1
    _check(archived._valid_entry(review),"New real field result is legal in existing private V17 archive")
    var older: Dictionary=review.duplicate(true)
    older.erase("field_protocol")
    _check(archived._valid_entry(older),"Existing V17 records without a G2 key stay valid")
    review["field_protocol"]="both"
    _check(not archived._valid_entry(review),"Forged both-at-once protocol is rejected from local history")

    var campaign := IPCampaignFlow.new()
    campaign.begin()
    var first := IPCrisisEngine.new()
    first.reset(campaign.current_scenario())
    first.scan_core()
    first.activate_field_protocol("sink")
    _check(_win(first) and campaign.record_victory(first),"Real GRID win with field sink enters genuine three-act campaign")
    _check(campaign.records[0].get("field_protocol")=="sink" and campaign.advance(),
        "Real sink choice persists and chapter two must be unlocked by victory")
    var effects: Dictionary=campaign.next_modifier()
    _check(float(effects["heat"])<=-3.0 and float(effects["oxygen"])<=-2.0,
        "Player's field costs/benefits carry across chapter boundary")
    var next := IPCrisisEngine.new()
    next.reset(campaign.current_scenario())
    var base_heat: float=next.heat
    var base_air: float=next.oxygen
    _check(campaign.apply_to_next(next) and
        next.heat<base_heat and next.oxygen<base_air,
        "Cross-chapter field consequences alter the true next emergency")
    var save_campaign: Dictionary=campaign.checkpoint()
    var loaded := IPCampaignFlow.new()
    _check(loaded.restore(save_campaign) and loaded.records[0]["field_protocol"]=="sink",
        "Campaign keeps actual field choice after app restart")
    var old_campaign: Dictionary=save_campaign.duplicate(true)
    old_campaign["records"][0].erase("field_protocol")
    var legacy_campaign := IPCampaignFlow.new()
    _check(legacy_campaign.restore(old_campaign) and
        legacy_campaign.next_modifier().has("oxygen"),
        "Saved V9 campaign results without field key still load")
    var forged_campaign: Dictionary=save_campaign.duplicate(true)
    forged_campaign["records"][0]["field_protocol"]="godmode"
    var snapshot: Dictionary=loaded.checkpoint()
    _check(not loaded.restore(forged_campaign) and loaded.checkpoint()==snapshot,
        "Invalid campaign protocol cannot silently override real history")

    var packed: PackedScene=load("res://Main.tscn")
    _check(packed!=null,"Existing full 3D level remains loadable")
    if packed==null:
        _finish()
        return
    var game=packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _check(game.field_stations.size()==2 and
        game.field_stations[0]["id"]=="sink" and game.field_stations[1]["id"]=="air",
        "Both original G2 terminals are actually in the full physical Godot scene")
    _check(game.get_node_or_null("G2_PhysicalProtocol_sink")!=null and
        game.get_node_or_null("G2_PhysicalProtocol_air")!=null,
        "Two distinct on-map physical stations, not website-only fake metadata")
    game.start_run()
    game.session.scan_core()
    game.player.position=Vector3(-4.2,1.1,-32.5)
    game._refresh_hud()
    _check(game._nearest_field_station().get("id")=="sink" and
        game.interaction_label.text.contains("ТЕПЛОВОЙ"),
        "Actual 3D proximity gives correct contextual E target on service spine")
    game._interact()
    _check(game.session.field_protocol=="sink" and
        game.story.latest_key=="field_sink" and game.session.elapsed>=IPCrisisEngine.SINK_TIME,
        "Real Godot E activates source engine with costs and original MARA response")
    var chosen_readout: Dictionary=game.session.diagnostic_snapshot()
    game.player.position=Vector3(4.2,1.1,-49.0)
    game._refresh_hud()
    _check(game.interaction_label.text.contains("ЗАФИКСИРОВАН"),
        "The physically separate AIR station shows an already committed decision")
    game._interact()
    _check(game.session.field_protocol=="sink" and
        game.session.faults>=1 and game.session.diagnostic_snapshot()["field_protocol"]=="sink",
        "True other on-map station cannot double-dip or bypass the one-of-two limit")
    var checkpoint: Dictionary=game._checkpoint_payload()
    _check(checkpoint.get("schema")=="IRON_PULSE_CAMPAIGN_V6" and
        checkpoint["engine"].get("field_protocol")=="sink" and chosen_readout["field_protocol"]=="sink",
        "Authentic G2 choice lives inside original V6 player checkpoint")
    game.queue_free()
    await process_frame
    _finish()
