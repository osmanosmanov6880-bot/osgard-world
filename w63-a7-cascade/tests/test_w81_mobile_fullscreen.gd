extends SceneTree
## W81: actual GUI geometry QA on native Godot game, not a CSS mockup.
## All 8 physical mobile controls MUST stay inside the actual SubViewport
## game stage and not overlap W79 original five-stage source mission deck.

var checks: int = 0
var failed: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(good: bool, reason: String) -> void:
    checks += 1
    if not good:
        failed.append(reason)

func _bounds(ui: A7CascadeScreen, width: int, height: int) -> void:
    ui.size=Vector2(width,height)
    ui._layout_stage()
    await process_frame
    await process_frame
    var rail: GridContainer = ui.w78_touch_overlay.rail
    var mission: PanelContainer = ui.w79_mission_deck.panel
    var stage: Rect2 = ui.stage_shell.get_global_rect()
    var rail_bounds: Rect2 = rail.get_global_rect()
    var mission_bounds: Rect2 = mission.get_global_rect()
    var compact: bool = width < 640 or (width <= 1100 and height <= 600)
    _check(ui.w80_full_bleed.active and
        ui.w80_full_bleed.qa_readout()["native_stage_area_fraction"]>=0.94,
        "Same original physical Godot SubViewport is truly full-bleed")
    _check(ui.w78_touch_overlay.landscape_layout==(compact and width>=640) and
        ui.w79_mission_deck.landscape_layout==(compact and width>=640),
        "Both native source-controls switch synchronized landscape mode")
    if compact and width>=640:
        _check(rail_bounds.size.x<=432 and mission_bounds.size.x<=532,
            "Real centered landscape thumb and mission widths remain reachable")
    _check(rail.columns==4,
        "W81 source-native actual two-row thumb grid, exactly four columns")
    _check(ui.w78_touch_overlay.controls.size()==8,
        "Every original W78 physical movement/eye/G/E tool remains available")
    _check(ui.w78_touch_overlay.visible==compact and
        ui.w79_mission_deck.visible==compact,
        "Only actual narrow-screen first-person game shows added mobile input")
    if compact:
        _check(stage.size.y>=385,
            "Actual original Godot playable 3D stage has large native mobile viewport")
        _check(mission_bounds.position.y + mission_bounds.size.y + 2 <=
            rail_bounds.position.y,
            "Original mobile five-stage real action deck does NOT intercept thumb buttons")
        _check(rail_bounds.position.x >= stage.position.x-2 and
            rail_bounds.position.x + rail_bounds.size.x <=
                stage.position.x + stage.size.x+2,
            "Whole 4-column thumb rail physically INSIDE visible original 3D stage")
        _check(mission_bounds.position.x >= stage.position.x-2 and
            mission_bounds.position.x + mission_bounds.size.x <=
                stage.position.x + stage.size.x+2,
            "Source mission panel physically INSIDE actual viewport")
        for action in ui.w78_touch_overlay.controls.keys():
            var button: Button = ui.w78_touch_overlay.controls[action] as Button
            var rect: Rect2 = button.get_global_rect()
            _check(rect.size.y >= 44 and rect.size.y <= 65,
                "True %dpx Godot mobile control %s 48px-class target" % [width,action])
            _check(rect.position.x >= stage.position.x-2 and
                rect.position.x+rect.size.x <= stage.position.x+stage.size.x+2,
                "Actual %dpx %s touch button NEVER overflows left/right original 3D world" % [width,action])
            _check(rect.position.y >= stage.position.y and
                rect.position.y+rect.size.y <= stage.position.y+stage.size.y+2,
                "Actual %dpx %s touch button stays inside original physical scene" % [width,action])
        for button in ui.w79_mission_deck.slots:
            if button.visible:
                var rect: Rect2 = button.get_global_rect()
                _check(rect.position.x >= stage.position.x-2 and
                    rect.position.x + rect.size.x <= stage.position.x+stage.size.x+2,
                    "Every currently genuine source mission command fits %dpx" % width)
        _check(not ui.w76_play_button.visible,
            "After actual PLAY NOW no redundant giant play button above 3D game")
        _check(not ui.w76_objective_label.visible,
            "Mobile W79 inline current goal replaces duplicate long caption below stage")
        _check(ui.cinema_caption.text.length() < 30,
            "Original Godot native immersive world caption is concise, not 2 long rows")
    else:
        _check(not ui.w78_touch_overlay.visible and
            not ui.w79_mission_deck.visible,
            "Desktop remains uncluttered: no mobile overlay on wide original stage")

func _run() -> void:
    var scene := load("res://Main.tscn") as PackedScene
    _check(scene != null,"Original real Godot playable world available")
    if scene==null:
        _finish()
        return
    var ui := scene.instantiate() as A7CascadeScreen
    root.add_child(ui)
    ui.size=Vector2(390,844)
    await process_frame
    await process_frame
    _check(not ui.w78_touch_overlay.visible and not ui.w79_mission_deck.visible,
        "Original start has no fake additional action panels")
    ui.w76_play_button.emit_signal("pressed")
    await process_frame
    _check(ui.stage_3d.first_person.piloting and
        ui.stage_3d.spatial_mission.extended_mode and ui.w76_immersive,
        "Original real physics player and complete W79 five-stage mode launched")
    _check(ui.model.snapshot()["history"].is_empty(),
        "No original A7 decisions fabricated by the improved visual grid")
    _check(ui.w80_full_bleed.active and
        ui.stage_shell.get_parent()==ui.w80_full_bleed,
        "Original fullscreen Godot world survives new responsive controls")
    await _bounds(ui,390,844)
    await _bounds(ui,320,700)
    await _bounds(ui,844,390)
    await _bounds(ui,768,900)
    await _bounds(ui,1366,900)
    ui.size=Vector2(390,844)
    ui._layout_stage()
    await process_frame
    _check(ui.w78_touch_overlay.visible and ui.w79_mission_deck.visible,
        "Returning to mobile restores original complete mission and physics controls")
    ui._toggle_locale()
    _check(ui.cinema_caption.text.contains("FIELD MISSION") and
        ui.w79_mission_deck.locale=="en",
        "Concise original ENG 3D mission caption and contextual action deck synchronized")
    var body: A7FirstPersonOperator = ui.stage_3d.first_person
    var start: Vector3 = body.body.global_position
    var arrow: Button = ui.w78_touch_overlay.controls["forward"] as Button
    arrow.emit_signal("button_down")
    for i in range(22):
        await physics_frame
    arrow.emit_signal("button_up")
    _check(body.body.global_position.distance_to(start)>0.4,
        "Two-row layout still actually walks the original collidable W70 player")
    _check(not body.held_keys.get(KEY_W,false),
        "True mobile held physical player input clears immediately on release")
    ui.w76_focus_button.emit_signal("pressed")
    await process_frame
    _check(not ui.w78_touch_overlay.visible and
        not ui.w79_mission_deck.visible and
        ui.w76_play_button.visible,
        "True TAB-style exit restores original top-level controls without stuck touch")
    _check(ui.model.snapshot()["history"].is_empty() and
        ui.stage_3d.spatial_mission.phase==0,
        "No gameplay score, puzzle phase or original action history ever changed by art layout")
    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failed.is_empty():
        print("LAST FRONTIER W81 INTEGRATED FULLSCREEN RESPONSIVE MOBILE GAME PASS: %d assertions" % checks)
        quit(0)
        return
    for issue in failed:
        push_error("W81 ORIGINAL 320/390 GODOT REAL GUI: "+issue)
    quit(1)
