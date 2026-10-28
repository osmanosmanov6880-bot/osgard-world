extends SceneTree
## IRON PULSE V9: real Godot 3D stage, physical controller interaction,
## exact save/reload and backwards compatible legacy campaign data.
var checks: int = 0
var failed: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool,msg: String) -> void:
    checks += 1
    if not ok:
        failed.append(msg)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null, "Godot Main scene remains importable")
    if packed == null:
        _finish()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var fields: IPContainmentRun = game.containment_run
    _check(fields != null and fields.name == "A7_ThreeStageContainmentRun",
        "Physically placed 3D containment run is attached to the existing level")
    if fields == null:
        game.queue_free()
        await process_frame
        _finish()
        return
    _check(game.terminals.size() == 6 and game.relay_terminals.size() == 3 and
        fields.interaction_points.size() == 3,
        "All nine previous engineering stations retained alongside three new hazard gates")
    _check(game.suit_label is Label and game.suit_label.text.contains("КОСТЮМ"),
        "Suit integrity has a localized HUD readout rather than a hidden damage counter")
    for i in range(fields.interaction_points.size()):
        var terminal: Dictionary = fields.interaction_points[i]
        var console: Node3D = terminal["node"]
        _check(console.get_node_or_null("PermanentConsoleBody") is MeshInstance3D,
            "Real 3D console with persistent state: "+str(i))
        _check(console.get_node_or_null("SealStationLabel") is Label3D,
            "In-world safety station label exists: "+str(i))
        _check((terminal["arch"] as Node3D).get_node_or_null("Crossbeam") is MeshInstance3D,
            "Real warning architecture visible at the hazard: "+str(i))

    game._select_scenario("thermal")
    game.start_run()
    var damage_before: float = fields.suit_integrity
    game.player.position = Vector3(0,1.1,-22.5)
    game._process(1.0)
    _check(fields.suit_integrity == damage_before,
        "Existing gameplay brief cannot hurt suit before reactor is scanned")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned, "Original physical reactor scan still unlocks main mission")
    game.player.position = Vector3(0,1.1,-22.5)
    var crew_before: float = game.session.crew_health
    game._process(1.0)
    _check(fields.suit_integrity < damage_before and game.session.crew_health == crew_before,
        "Actual world exposure affects operator suit but not fictional crew resources")
    _check(game.story.latest_key == "field_enter_reactor",
        "Entry to a real danger zone triggers authored MARA radio")
    _check(game.suit_label.text.contains("КОСТЮМ"),
        "In-game suit HUD remains visible with actual damaged value")
    var suit_before: float = fields.suit_integrity

    game.player.position = Vector3(4.7,1.1,-25.6)
    game._interact()
    _check(fields.seals == ["reactor"] and game.session.last_event == "field_seal_reactor",
        "Actual E action at 3D control physically isolates the reactor zone")
    _check(game.story.latest_key == "field_seal_reactor",
        "Field isolation is reflected by localized crew dialogue")
    _check((fields.interaction_points[0]["indicator"] as MeshInstance3D).material_override == fields._sealed_material,
        "3D safety console changes from orange to green when used")
    game.player.position = Vector3(0,1.1,-22.5)
    game._process(0.7)
    _check(is_equal_approx(fields.suit_integrity,suit_before),
        "Physical re-entry into a sealed hazard no longer damages the operator")

    # B triggers the same real interaction as keyboard E.
    game.player.position = Vector3(-4.7,1.1,-42.4)
    var pad := InputEventJoypadButton.new()
    pad.button_index = JOY_BUTTON_A
    pad.pressed = true
    game._input(pad)
    _check(fields.seals == ["reactor","service"],
        "Mapped controller A performs the same real 3D field-isolation action")
    _check(game.suit_label.text.contains("2/2"), "HUD exposes the actual global seal budget")
    var faults_before: int = game.session.faults
    game.player.position = Vector3(4.7,1.1,-52.8)
    game._interact()
    _check(fields.seals.size() == 2 and game.session.faults == faults_before+1,
        "Third real 3D safety console denies action after two resource allocations")
    _check(game.story.latest_key == "field_budget",
        "Radio operator narrates the locked third route choice")
    _check(fields.risk_for("evacuation","thermal",game.session.heat,game.session.oxygen) > 0.0,
        "Evacuation sector remains physically risky when player protected first two")
    game.player.position = Vector3(0,1.1,-52.1)
    var before_unsealed: float = fields.suit_integrity
    game._process(0.7)
    _check(fields.suit_integrity < before_unsealed,
        "Unprotected third stage measurably injures player while standing in real space")

    game.quality_mode = "hero"
    fields.set_quality("hero")
    var key := InputEventKey.new()
    key.keycode = KEY_G
    key.pressed = true
    game._input(key)
    _check(fields.readout()["quality"] == "eco", "Existing G changes real V9 world quality")
    game._input(key)
    _check(fields.readout()["quality"] == "hero", "Existing G restores actual 3D HERO detail")

    var path: String = "user://iron_pulse_v9_native_scene_test.json"
    game.checkpoint_path = path
    game.checkpoint_store.clear(path)
    var payload: Dictionary = game._checkpoint_payload()
    _check(payload.has("field_state") and payload["field_state"]["seals"].size() == 2,
        "Actual campaign checkpoint includes spatial suit/field decisions")
    _check(game.checkpoint_store.save(payload,path), "Offline campaign store writes real V9 checkpoint")
    game.session.reset("breach")
    fields.reset()
    game.story.reset("breach")
    game.selected_scenario = "breach"
    game.player.position = Vector3(0,1.1,2.0)
    _check(game._continue_checkpoint(), "True existing Continue command resumes V9 save")
    _check(game.session.scenario_id == "thermal" and fields.seals == ["reactor","service"],
        "Saved current mission and irreversible safety choices really round-trip")
    _check(fields.suit_integrity < 100.0 and
        fields.interaction_points[1]["indicator"].material_override == fields._sealed_material,
        "Reload keeps accumulated damage and real 3D console visual states")

    var bad: Dictionary = payload.duplicate(true)
    bad["field_state"]["seals"] = ["reactor","service","evacuation"]
    _check(game.checkpoint_store.save(bad,path), "Corrupted-but-checksummed test save written for integrity QA")
    var current_integrity: float = fields.suit_integrity
    _check(not game._continue_checkpoint() and
        fields.seals == ["reactor","service"] and fields.suit_integrity == current_integrity,
        "Fabricated third safety seal is refused atomically without altering active game")

    var old: Dictionary = payload.duplicate(true)
    old.erase("field_state")
    _check(game.checkpoint_store.save(old,path), "Previously verified V6-compatible campaign structure stored")
    _check(game._continue_checkpoint(), "Real V6-V8.6 payload without V9 field data loads safely")
    _check(fields.seals.is_empty() and fields.suit_integrity == 100.0,
        "Legacy saves gain fresh suit instead of inheriting random hazard state")
    _check(game.checkpoint_store.clear(path), "Regression test save cleaned up")

    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failed.is_empty():
        print("IRON PULSE V9 PHYSICAL CAMPAIGN PASS: %d real scene/controller/save checks" % checks)
        quit(0)
    else:
        for item in failed:
            push_error("V9 PHYSICAL FAIL: "+item)
        quit(1)
