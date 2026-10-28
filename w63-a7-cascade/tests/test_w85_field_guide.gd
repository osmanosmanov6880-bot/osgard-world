extends SceneTree
## W85 acceptance: COMPLETE original ORIGINAL five-phase 3D mission, solely
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
    var guide: A7MissionFieldGuide = ui.w85_field_guide
    var studio: A7MobileControlStudio = ui.w84_studio
    _check(guide != null and guide.get_parent()==ui.stage_shell and
        guide.mission==mission and guide.operator==operator and
        guide.equipment==equipment and guide.navigation==ui.w82_nav_cockpit,
        "Original A7 mission and W70 physics source preserved by W85")
    _check(guide.progress_pips.size()==5 and guide.steps.size()==3 and
        guide.gameplay_actions_issued==0,
        "Source-only guide has five real phases, three human steps and no autowin")
    _check(not guide.visible and not guide.opened,
        "No W85 guide obstructs the original 3D introduction")
    guide.entry_button.emit_signal("pressed")
    _check(guide.blocked_inactive_opens>=1 and
        ui.model.snapshot()["history"].is_empty(),
        "W85 cannot open before source mission is active")
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
    _check(guide.visible and not guide.opened and guide.current_phase==0 and
        guide.source_goal=="core" and guide.current_distance_m>3.2 and
        guide.objective_label.text.contains("КЛАПАН"),
        "Initial real reactor objective and 3.2m range shown, not invented")
    (old_touch.controls["forward"] as Button).emit_signal("button_down")
    _check(operator.held_keys.get(KEY_W,false),
        "W78 original native touch starts physical W70 WALK before help")
    guide.entry_button.emit_signal("pressed")
    await process_frame
    _check(guide.opened and guide.panel.visible and
        ui.w83_dual_touch.input_suspended and not studio.settings_button.visible,
        "W85 real modal blocks camera and prevents simultaneous W84 options")
    _check(not old_touch.visible and not deck.visible and
        not operator.held_keys.get(KEY_W,false),
        "Reading actual goal stops held walk and hides all real mission commands")
    guide.close_button.emit_signal("pressed")
    await process_frame
    _check(not guide.opened and not ui.w83_dual_touch.input_suspended and
        old_touch.visible and deck.visible and studio.settings_button.visible,
        "Returning from native guide restores every original source touch control")
    _check(ui.model.snapshot()["history"].is_empty() and mission.phase==0,
        "Human-readable source guide does not cause game decisions")

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
    guide._paint_source()
    _check(guide.current_phase==0 and guide.within_source_range and
        guide.current_distance_m<3.2 and guide.distance_label.text.contains("РЯДОМ"),
        "Actual original W70 body makes physical guide READY near reactor")
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
    guide._paint_source()
    _check(guide.current_phase==1 and guide.source_goal=="decisions" and
        guide.objective_label.text.contains("ДВА РЕШЕНИЯ"),
        "Physical E really advances guide to first two player decisions")
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
    guide._paint_source()
    _check(guide.current_phase==2 and guide.source_goal=="relay" and
        guide.source_history_count==2 and guide.objective_label.text.contains("РЕЛЕ"),
        "W85 reads the actual two source decisions and physically gated relay phase")

    (deck.save_button as Button).emit_signal("pressed")
    _check(deck.save_requests==1 and ui.checkpoint.saves>=1,
        "Mobile save invokes actual SHA-checked W73 source-game user checkpoint")
    (deck.load_button as Button).emit_signal("pressed")
    _check(deck.load_requests==1 and ui.checkpoint.successful_restores>=1,
        "Mobile load restores actual original source-validated W73 checkpoint")
    _check(mission.phase==2 and ui.model.snapshot()["history"].size()==2,
        "Checkpoint load cannot invent/lose physical mission stage and original actions")
    guide._paint_source()
    _check(guide.current_phase==2 and guide.source_history_count==2,
        "Field guide stays truthful after original SHA-verified checkpoint load")

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
    guide._paint_source()
    _check(guide.current_phase==3 and guide.source_goal=="decisions" and
        guide.objective_label.text.contains("ШЕСТЬ ЦИКЛОВ"),
        "True source relay inspection shows the six-cycle stage")

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
    guide._paint_source()
    _check(guide.current_phase==4 and guide.source_goal=="core" and
        guide.source_history_count==12 and
        guide.objective_label.text.contains("ВОЗВРАЩЕНИЕ"),
        "Only after all 12 original decisions does guide show reactor return")
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
    guide._paint_source()
    _check(guide.current_phase==5 and guide.source_history_count==12 and
        guide.objective_label.text.contains("МИССИЯ ПРОЙДЕНА") and
        guide.gameplay_actions_issued==0,
        "Victory guidance appears ONLY after original A7 physical final sync and E")
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
    _check(guide.locale=="en" and
        guide.objective_label.text.contains("MISSION COMPLETE") and
        guide.subtitle_label.text.contains("NO AUTOPLAY"),
        "Guide translates verified original victory RU and EN")
    ui.size=Vector2(1366,900)
    ui._layout_stage()
    _check(not deck.visible and not old_touch.visible,
        "Desktop does not show dense mobile controls over the genuine world")
    _check(not guide.visible and not guide.opened,
        "Desktop hides touch-specific guide, preserving original PC interface")
    ui.size=Vector2(320,700)
    ui._layout_stage()
    _check(deck.visible and deck.slots[0].custom_minimum_size.x<=38,
        "320px live Godot small-screen has source-driven concise touch actions")
    var entry320: Rect2=guide.entry_button.get_global_rect()
    var menu320: Rect2=ui.w80_full_bleed.exit_button.get_global_rect()
    var compass320: Rect2=ui.w82_nav_cockpit.frame.get_global_rect()
    _check(entry320.size.y>=44 and
        not entry320.intersects(menu320) and
        not entry320.intersects(compass320),
        "320px native W85 guide entry CANNOT overlap original MENU or W82 compass")
    guide.entry_button.emit_signal("pressed")
    await process_frame
    var panel320: Rect2=guide.panel.get_global_rect()
    var stage320: Rect2=ui.stage_shell.get_global_rect()
    _check(panel320.position.x>=stage320.position.x-2 and
        panel320.end.x<=stage320.end.x+2 and
        panel320.position.y>=stage320.position.y and
        panel320.end.y<=stage320.end.y+2,
        "320px actual Godot five-phase guide fits within live 3D screen")
    _check(guide.opened and not deck.visible and
        not studio.settings_button.visible,
        "Narrow-screen modal safely hides dangerous source buttons and W84 entry")
    guide.close_button.emit_signal("pressed")
    studio.settings_button.emit_signal("pressed")
    _check(studio.opened and not guide.entry_button.visible and
        ui.w83_dual_touch.input_suspended,
        "Real W84 settings and W85 help never overlap or leave camera active")
    studio.done_button.emit_signal("pressed")
    await process_frame
    _check(not studio.opened and guide.entry_button.visible and
        not ui.w83_dual_touch.input_suspended,
        "Closing W84 restores W85 entry without stuck W70 source input")
    ui.size=Vector2(844,390)
    ui._layout_stage()
    await process_frame
    guide.entry_button.emit_signal("pressed")
    await process_frame
    var panel844: Rect2=guide.panel.get_global_rect()
    var stage844: Rect2=ui.stage_shell.get_global_rect()
    _check(panel844.position.x>=stage844.position.x-2 and
        panel844.end.x<=stage844.end.x+2 and
        panel844.position.y>=stage844.position.y and
        panel844.end.y<=stage844.end.y+2,
        "844x390 source mission guide remains fully within landscape stage")
    _check(guide.opens>=3 and guide.gameplay_actions_issued==0,
        "Original guide has repeated native opens but zero fabricated gameplay")
    guide.close_button.emit_signal("pressed")
    ui.size=Vector2(320,700)
    ui._layout_stage()
    await process_frame
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
        print("LAST FRONTIER W85 REAL ORIGINAL FIELD GUIDE FIVE-PHASE GODOT PASS: %d checks" % checked)
        quit(0)
        return
    for reason in errors:
        push_error("W85 REAL FIELD GUIDE AND COMPLETE MOBILE MISSION: "+reason)
    quit(1)
