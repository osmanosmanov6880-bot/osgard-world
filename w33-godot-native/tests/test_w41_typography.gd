extends SceneTree
## W41 native regression: real screenshots uncovered a one-character-per-line
## simulation badge on 1366px desktop plus oversized mobile page heading.
const Core = preload("res://scripts/OSGARDCore.gd")
const SAVE = "user://osgard_w41_real_render_review.cfg"
var checks: int = 0
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        errors.append(message)

func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn") as PackedScene
    _assert(scene != null, "Actual Godot scene can be loaded")
    if scene == null:
        _finish()
        return
    var game: OSGARDMain = scene.instantiate() as OSGARDMain
    _assert(game != null, "Operator interface is native Godot")
    if game == null:
        _finish()
        return
    game.core = Core.new(SAVE)
    game.core.clear_data()
    root.add_child(game)
    await process_frame
    await process_frame
    _assert(game.brand_mark != null, "Separate visible brand label exists")
    _assert(game.stage_section_heading != null, "Scene section heading exists")
    _assert(game.stage_edition != null and game.stage_kicker != null, "Native in-scene labels exist")
    _assert(game.stage_edition.autowrap_mode == TextServer.AUTOWRAP_OFF, "Simulation badge cannot wrap vertically")
    _assert(game.stage_edition.custom_minimum_size.x >= 185.0, "Simulation badge reserves actual width")
    _assert(game.stage_edition.clip_text, "Badge clips before drawing off canvas")
    _assert(game.stage_kicker.autowrap_mode == TextServer.AUTOWRAP_OFF, "Facility classification remains one line")
    game.size = Vector2(1366, 768)
    game._layout_stage_for_screen()
    game._refresh()
    await process_frame
    await process_frame
    _assert(game.stage_edition.visible, "Full desktop width shows genuine simulation status")
    _assert(game.stage_edition.size.y <= 32.0, "Desktop simulator badge has one-line height")
    _assert(game.stage_kicker.size.y <= 34.0, "Desktop classification is not vertically stacked")
    _assert(game.brand_mark.text == game._t("brand_desktop"), "Full desktop shows approved localized game identity")
    _assert(game.mission_btns.size() == 6 and game.view_btns.size() == 3, "Original game controls retained")
    game.size = Vector2(390, 844)
    game._layout_stage_for_screen()
    game._refresh()
    await process_frame
    await process_frame
    _assert(not game.stage_edition.visible, "Phone hides secondary simulation badge")
    _assert(game.brand_mark.text == game._t("brand_mobile"), "Phone shows compact LAST FRONTIER identity")
    _assert(game.heading.text == game._t("reactor_title_short"), "Localized phone headline avoids wasted lines")
    _assert(game.stage_section_heading.text == game._t("stage_narrow"), "Phone stage classification remains localized")
    _assert(game.stage_shell.custom_minimum_size.y <= 310.0, "Phone reserves room for working controls")
    _assert(game.control_grid.columns == 1, "Phone operator console remains single column")
    game.core.clear_data()
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if errors.is_empty():
        print("W41 REAL ORIGINAL FRAME LAYOUT REGRESSION PASS: %d assertions" % checks)
        quit(0)
    else:
        for problem in errors:
            push_error("W41 FRAME QA FAILED: "+problem)
        quit(1)
