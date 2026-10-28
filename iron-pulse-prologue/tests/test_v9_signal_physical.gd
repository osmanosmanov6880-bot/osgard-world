extends SceneTree
## Actual 3D player acceptance: four in-world terminals and checkpoint recovery.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool,label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn")
    _check(scene != null,"Real 3D Godot game scene remains loadable")
    if scene == null:
        _finish()
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _check(game.signal_sites is IPSignalSites and game.signal_campaign is IPSignalCampaign,
        "Actual V9 mission systems are mounted in live native game")
    _check(game.signal_sites.sites.size()==4 and game.signal_sites.diagnostic()["real_signal_consoles"]==4,
        "Four separately placed original 3D signal terminals exist")
    for i in range(4):
        var site: Dictionary = game.signal_sites.sites[i]
        var node: Node3D = site["node"]
        _check(node != null and node.get_node_or_null("VerticalMachinedHousing") is MeshInstance3D,
            "Source-made industrial console has real mesh body")
        _check(node.get_node_or_null("SourceAuthoredMachineLabel") is Label3D,
            "Real three-dimensional engineering signage marks each station")
        _check(site["status"] is MeshInstance3D and site["number"] is Label3D,
            "Station has actual dynamic in-world state light and number")
    _check(game.terminals.size()==6 and game.relay_terminals.size()==3,
        "Original six story consoles and optional three rescue relays remain unchanged")
    _check(game.signal_sites.diagnostic()["hero_precision_fins"]==20,
        "Fine-machined HERO detail exists in actual 3D environment")
    _check(game.signal_campaign.collected.is_empty() and not game.signal_campaign.route_unlocked(),
        "No unearned campaign progression appears on new game menu")

    game._select_scenario("blackout")
    game.start_run()
    game.player.position = Vector3(4.8,1.1,-18.0)
    game._interact()
    _check(game.signal_campaign.collected.is_empty() and game.session.faults >= 1,
        "Real E cannot exploit a signal console before original reactor scan")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned and game.story.latest_key=="scan",
        "Original scanner unlocks source-bound V9 signal chain")
    var elapsed_before: float = game.session.elapsed
    game.player.position = Vector3(4.8,1.1,-18.0)
    game._interact()
    _check(game.signal_campaign.collected==["resonance"] and game.story.latest_key=="signal_resonance",
        "Physical E at reactor signal terminal changes real game and plays authored MARA")
    _check(game.session.elapsed >= elapsed_before+5.9,
        "Physical console incurs actual simulation time and power costs")
    _check(game.signal_sites.sites[0]["status"].material_override==game.signal_sites._done_mat,
        "Station LED in live 3D scene turns success green")
    game.player.position = Vector3(-4.6,1.1,-42.0)
    game._interact()
    _check(game.signal_campaign.collected==["resonance","atmosphere"] and game.story.latest_key=="signal_atmosphere",
        "Distinct physical AIR telemetry machine works in actual service sector")
    game.player.position = Vector3(4.6,1.1,-51.0)
    game._interact()
    _check(game.signal_campaign.route_unlocked() and game.story.latest_key=="signal_transit",
        "Visiting evacuation sector unlocks finale after third real console")
    _check(game.signal_sites.sites[3]["status"].material_override==game.signal_sites._ready_mat,
        "Final directive console visibly unlocks only with three signals")
    _check(game.allocation_label.text.contains("3/3"),
        "New completion counter is present in real native game HUD")
    game.player.position = Vector3(4.8,1.1,-46.0)
    game._refresh_hud()
    _check(game.interaction_label.text.contains("[Q]") and game.interaction_label.text.contains("[E]"),
        "Final E/Q choice is explained by actual localized player prompt")
    game._interact(true)
    _check(game.signal_campaign.directive=="core" and game.story.latest_key=="directive_core",
        "Real existing Q input selects the irreversible alternative reactor strategy")
    _check(game.signal_sites.sites[3]["status"].material_override==game.signal_sites._done_mat,
        "Final physical console changes luminous state when directive committed")
    var first_directive_state: Dictionary = game.signal_campaign.checkpoint()
    game._interact()
    _check(game.signal_campaign.checkpoint()==first_directive_state,
        "Player cannot double-collect final one-shot reward in real scene")
    var file: String = "user://iron_pulse_v9_native_campaign_ci.json"
    game.checkpoint_path = file
    game.checkpoint_store.clear(file)
    var original: Dictionary = game._checkpoint_payload()
    _check(game.checkpoint_store.save(original,file),"V9 progress writes through real atomic offline save store")
    game.session.reset("breach")
    game.story.reset("breach")
    game.signal_campaign.reset()
    game.signal_sites.update_campaign(game.signal_campaign)
    game.player.position=Vector3(0.0,1.1,0.0)
    _check(game._continue_checkpoint(),"Real V6 Continue entry point restores enriched V9 save")
    _check(game.signal_campaign.collected.size()==3 and game.signal_campaign.directive=="core",
        "Three physical signals plus final decision survive full offline reload")
    _check(game.session.scenario_id=="blackout" and game.story.latest_key=="directive_core",
        "Reopen restores same actual emergency, authored story and consequences")
    _check(game.signal_sites.sites[3]["status"].material_override==game.signal_sites._done_mat,
        "V9 save restore also updates actual 3D terminal illumination")
    _check(game.player.position.distance_to(Vector3(4.8,1.1,-46.0))<0.02,
        "Player resumes at real last signal-console position")

    var forged: Dictionary = original.duplicate(true)
    forged["signal_chain"]={"schema":IPSignalCampaign.FORMAT,"signals":["resonance"],"directive":"crew"}
    _check(game.checkpoint_store.save(forged,file),"Tampered but SHA-consistent file can be created for adversarial QA")
    var core_before: Dictionary = game.session.checkpoint()
    var mission_before: Dictionary = game.signal_campaign.checkpoint()
    _check(not game._continue_checkpoint(),
        "Forged final-directive save with missing signals is rejected by game")
    _check(game.session.checkpoint()==core_before and game.signal_campaign.checkpoint()==mission_before,
        "Rejected source-bound V9 checkpoint cannot partially mutate real player state")

    var legacy: Dictionary = original.duplicate(true)
    legacy.erase("signal_chain")
    _check(game.checkpoint_store.save(legacy,file),"A historical V6 checkpoint is representable without V9 data")
    _check(game._continue_checkpoint(),"All prior V6/V7/V8 checkpoints continue to work in V9")
    _check(game.signal_campaign.collected.is_empty() and game.signal_campaign.directive=="",
        "Legacy saves correctly start optional signal mission with no fake rewards")
    _check(game.signal_sites.sites[3]["status"].material_override==game.signal_sites._locked_mat,
        "Legacy save resets actual final terminal to physically locked state")
    _check(game.checkpoint_store.clear(file),"All test save state cleaned up")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V9 PHYSICAL CAMPAIGN PASS: %d source-bound native scene checks" % checks)
        quit(0)
    else:
        for item in failures:
            push_error("V9 PHYSICAL FAIL: "+item)
        quit(1)
