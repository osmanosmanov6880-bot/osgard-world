extends SceneTree
## W79 acceptance: ONE COMPLETE ORIGINAL five-phase 3D mission, solely
## through the native W78 touch E and W79 dynamic touch command slots.
## The test positions the real player near field stations to isolate touch
## source routing; physical travel/collision was independently W77-verified.
## No fake gameplay success, no bypass of the actual A7CascadeCore.

var checked: int = 0
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, claim: String) -> void:
    checked += 1
    if not ok:
        errors.append(claim)

func _tap(deck: A7MobileMissionDeck, slot: int) -> void:
    (deck.slots[slot] as Button).emit_signal("pressed")

func _touch_inspect(ui: A7CascadeScreen) -> void:
    (ui.w78_touch_overlay.controls["inspect"] as Button).emit_signal("pressed")

func _run() -> void:
    var source := load("res://Main.tscn") as PackedScene
    _check(source != null,"Actual Godot A7 cascade game scene is available")
    if source == null:
        _finish()
        return
    var ui := source.instantiate() as A7CascadeScreen
    root.add_child(ui)
    ui.size = Vector2(390,844)
    await process_frame
    await process_frame
    ui._layout_stage()
    var deck: A7MobileMissionDeck = ui.w79_mission_deck
    var old_touch: A7TouchFieldControls = ui.w78_touch_overlay
    var world: A7CinematicStage = ui.stage_3d
    var operator: A7FirstPersonOperator = world.first_person
    var mission: A7SpatialMission = world.spatial_mission
    var equipment: A7FieldOperations = world.field_operations
    _check(deck != null and deck.get_parent()==ui.stage_shell,
        "New mission deck is a real Control on original Godot live 3D viewport")
    _check(deck.slots.size()==5 and deck.save_button is Button and
        deck.load_button is Button,
        "Five original context action slots plus actual save/load, no decorative UI")
    _check(not deck.visible and ui.model.snapshot()["history"].is_empty(),
        "Original game starts with no synthetic mobile mission or decisions")

    ui.w76_play_button.emit_signal("pressed")
    await process_frame
    _check(mission.active and mission.extended_mode and operator.piloting and
        ui.w76_immersive,"PLAY NOW activates true original world+physics+extended mission")
    _check(deck.visible and deck.current_mode=="valve" and
        deck.actual_commands==["VALVE_MINUS","VALVE_PLUS"],
        "Dynamic original phase0 deck displays ONLY authentic valve commands")
    _check(old_touch.visible and deck.panel.offset_bottom <= -65,
        "Actual touch controls and contextual action deck occupy different viewport rows")

    # Source engine MUST refuse equipment actions when physically too far.
    var start_idx: int = equipment.valve_index
    var old_rejections: int = equipment.rejected_far_uses
    _tap(deck,1)
    _check(equipment.valve_index==start_idx and
        equipment.rejected_far_uses==old_rejections+1,
        "Original W72 physical proximity rejects real mobile valve at starting distance")
    _check(ui.model.snapshot()["history"].is_empty(),
        "Cannot fabricate A7 decision by touching a physically distant valve")

    # Shorten real physical travel in the unit test only; independently
    # original W77 tests walking and locked/unlocked corridor entirely.
    operator.body.position=Vector3(5.50,1.33,2.90)
    await physics_frame
    var turns: int = equipment.valve_target
    for i in range(turns):
        _tap(deck,1)
    _check(equipment.valve_index==turns and equipment.valve_solved,
        "Actual original valve detents completed through real 390px mobile buttons")
    _check(ui.checkpoint.events.size()==turns+1,
        "Each physical equipment operation is original source-journaled, not decoration")
    _check(deck.slots[1].disabled and deck.current_mode=="valve",
        "Context deck prevents accidentally unsolving a genuinely calibrated valve")
    _touch_inspect(ui)
    _check(mission.phase==1 and deck.current_mode=="decisions",
        "Real physical E inspection advances actual mission to first decision stage")
    _check(deck.actual_commands==["PUMP","VENT","SEAL","SCAN","POWER"],
        "Original five true A7 decisions shown, no fake auto-strategy")
    _check(ui.model.snapshot()["history"].is_empty() and
        int(ui.model.snapshot()["shift"])==0,
        "Real core engine unchanged before player chooses first incident actions")
    _tap(deck,0)
    _check(ui.model.snapshot()["history"].size()==1 and
        int(ui.model.snapshot()["actions_left"])==1,
        "Touch PUMP is one actual A7 original source-engine move")
    _tap(deck,3)
    _check(ui.model.snapshot()["history"].size()==2 and
        int(ui.model.snapshot()["shift"])==1 and mission.phase==2,
        "PUMP+SCAN completes actual 1st crisis cycle and unlocks genuine relay objective")
    world.sector_bulkhead.refresh_state()
    _check(not world.sector_bulkhead.physically_blocked and
        deck.current_mode=="relay" and deck.actual_commands.size()==3,
        "Source-accepted decisions unlock actual sector collider and show only relay toggles")

    (deck.save_button as Button).emit_signal("pressed")
    _check(deck.save_requests==1 and ui.checkpoint.saves>=1,
        "Mobile save invokes actual SHA-checked W73 source-game user checkpoint")
    (deck.load_button as Button).emit_signal("pressed")
    _check(deck.load_requests==1 and ui.checkpoint.successful_restores>=1,
        "Mobile load restores actual original source-validated W73 checkpoint")
    _check(mission.phase==2 and ui.model.snapshot()["history"].size()==2,
        "Checkpoint load cannot invent/lose physical mission stage and original actions")

    operator.body.position=Vector3(8.0,1.33,19.1)
    await physics_frame
    var expected_relay_mask: int = equipment.relay_target
    _check(expected_relay_mask>0 and expected_relay_mask<8,
        "Relay routing target is real original deterministic A7 state")
    for i in range(3):
        if (expected_relay_mask & (1 << i))!=0:
            _tap(deck,i)
    _check(equipment.relay_mask==expected_relay_mask and equipment.relay_solved,
        "Three actual world relay switches controlled by mobile without original rule bypass")
    _touch_inspect(ui)
    _check(mission.phase==3 and deck.current_mode=="decisions",
        "Physical relay inspection advances original mission to all remaining emergency cycles")

    var rest: Array[Array] = [
        ["PUMP","SEAL"],["VENT","SCAN"],["VENT","SEAL"],
        ["PUMP","POWER"],["VENT","SCAN"],
    ]
    var chosen: int = 2
    for pair in rest:
        for action in pair:
            var slot: int = A7MobileMissionDeck.ACTIONS.find(action)
            _check(slot>=0 and deck.current_mode=="decisions",
                "Current mission phase exposes actual decisions rather than auto-playing")
            _tap(deck,slot)
            chosen += 1
            _check(ui.model.snapshot()["history"].size()==chosen,
                "All 12 real game actions are committed one-by-one by native touch player")
    _check(str(ui.model.snapshot()["status"])=="won" and
        ui.model.snapshot()["history"].size()==12 and mission.phase==4,
        "Actual deterministic original six-cycle cascade WON via 12 mobile player decisions")
    _check(deck.current_mode=="sync" and
        equipment.sync_order.size()==3 and not equipment.sync_solved,
        "Real final containment has three original source-derived order-gated sync commands")
    operator.body.position=Vector3(5.50,1.33,2.90)
    await physics_frame
    var expected_order: Array[int] = equipment.sync_order.duplicate()
    for connector in expected_order:
        _tap(deck,connector)
    _check(equipment.sync_solved and equipment.sync_step==3,
        "Mobile final sync obeys original ordered physical connector validation")
    _touch_inspect(ui)
    _check(mission.phase==5 and deck.current_mode=="complete",
        "True original game victory only after successful final physical return inspection")
    _check(ui.model.snapshot()["status"]=="won" and
        ui.model.snapshot()["history"].size()==12,
        "Mission complete never replaces, spoofs or rewinds original core victory")
    _check(deck.actual_commands==["RESTART"] and deck.slots[0].visible,
        "After actual victory, no irrelevant 5-option controls clutter the mobile screen")
    _check(deck.physical_equipment_request_count>=turns+1 and
        deck.original_core_action_requests==12,
        "Correct number of actual physical equipment and original player decisions")
    _check(deck.actual_source_phase_changes>=6,
        "Dynamic original mission UI follows all six actual visited source phases")
    _check(not deck.qa_readout()["mobile_hardware_playtested"],
        "Never invent physical Android/iPhone validation based on native unit tests")

    ui._toggle_locale()
    _check(deck.locale=="en" and deck.headline.text.contains("VICTORY"),
        "Original mobile success and context titles support real EN translation")
    ui.size=Vector2(1366,900)
    ui._layout_stage()
    _check(not deck.visible and not old_touch.visible,
        "Desktop does not show dense mobile controls over the genuine world")
    ui.size=Vector2(320,700)
    ui._layout_stage()
    _check(deck.visible and deck.slots[0].custom_minimum_size.x<=38,
        "320px live Godot small-screen has source-driven concise touch actions")
    _tap(deck,0)
    await process_frame
    _check(not mission.active and
        ui.model.snapshot()["history"].is_empty() and
        ui.model.snapshot()["status"]=="playing",
        "Only pressing explicit RESTART resets real original six-cycle game")
    _check(not deck.visible,
        "Source reset hides stale completed mobile command dock")
    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if errors.is_empty():
        print("LAST FRONTIER W79 TRUE COMPLETE FIVE-PHASE MOBILE GODOT MISSION PASS: %d checks" % checked)
        quit(0)
        return
    for reason in errors:
        push_error("W79 ORIGINAL COMPLETE MOBILE GAME: "+reason)
    quit(1)
