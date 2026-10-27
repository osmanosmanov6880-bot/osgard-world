extends SceneTree
## W61 genuine Godot: brand localization + read-only mission progression overlay.
## Zero changes to simulated machinery controls, mission logic or scoring.
const Core = preload("res://scripts/OSGARDCore.gd")
const SAVE = "user://last_frontier_w61_native_test.cfg"
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    assertions += 1
    if not condition:
        failures.append(message)

func _run() -> void:
    _check(str(ProjectSettings.get_setting("application/config/name")) == "LAST FRONTIER | ПОСЛЕДНИЙ РУБЕЖ",
        "Godot application title is the approved bilingual working identity")
    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    _check(packed != null, "Actual playable Godot main scene exists")
    if packed == null:
        _finish()
        return
    var ui: OSGARDMain = packed.instantiate() as OSGARDMain
    _check(ui != null, "Original native game UI remains accessible")
    if ui == null:
        _finish()
        return
    ui.core = Core.new(SAVE)
    ui.core.clear_data()
    root.add_child(ui)
    await process_frame
    await process_frame

    _check(ui.mission_btns.size() == 6, "Original six mission controls survived brand migration")
    _check(ui.view_btns.size() == 3, "Original three real cameras survived brand migration")
    _check(ui.mission_segments.size() == 5, "Five native phase segments exist")
    _check(ui.brand_mark.clip_text, "Brand never overflows the responsive native label")
    _check(ui.stage_edition.text.contains("SIMULATION"), "Simulation disclaimer remains visible on desktop")

    for locale in ["ru", "en"]:
        ui.core.settings["locale"] = locale
        for width in [320, 390, 1366]:
            ui.size = Vector2(width, 800)
            ui._layout_stage_for_screen()
            ui._refresh()
            await process_frame
            var narrow: bool = width < 640
            var expected_brand: String = ui._t("brand_mobile") if narrow else ui._t("brand_desktop")
            _check(ui.brand_mark.text == expected_brand,
                "Responsive localized wordmark %s/%d" % [locale, width])
            _check(not ui.brand_mark.text.contains("OSGARD"),
                "No old OSGARD visible wordmark %s/%d" % [locale, width])
            _check(ui.stage_section_heading.text == (ui._t("stage_narrow") if narrow else ui._t("stage_facility")),
                "Localized reactor facility caption %s/%d" % [locale, width])
            _check(ui.heading.text == (ui._t("reactor_title_short") if narrow else ui._t("reactor_title_long")),
                "Native localized reactor headline %s/%d" % [locale, width])
            _check(ui.stage_live.text == ui._t("stage_idle"),
                "Localized idle state is derived from real snapshot %s/%d" % [locale, width])
            _check(ui.footer.text.contains("LAST FRONTIER"),
                "Simulation safety footer names current project %s/%d" % [locale, width])
            _check(ui.mission_segments.size() == 5,
                "Overlay phases persist on native mobile %s/%d" % [locale, width])
            _check(ui.core.snapshot()["mission"] == -1,
                "Brand UI layout cannot silently begin a mission %s/%d" % [locale, width])

    ui.core.settings["locale"] = "ru"
    ui.size = Vector2(390, 844)
    ui._layout_stage_for_screen()
    ui._refresh()
    for phase in ui.mission_segments:
        _check(phase.color == Color("30414a"), "Idle phase visual remains dim")
        _check(phase.mouse_filter == Control.MOUSE_FILTER_IGNORE,
            "Read-only phase overlay cannot intercept actual touch controls")

    _check(ui.core.begin_case(0), "Original diagnostic mission 01 remains startable")
    ui._refresh()
    _check(ui.stage_live.text == ui._t("stage_active"), "RU real mission active state is localized")
    _check(ui.mission_segments[0].color == Color("84cbbc"),
        "Accepted first mission step lights up in native HUD")
    for i in range(1, 5):
        _check(ui.mission_segments[i].color == Color("30414a"),
            "Unreached mission phase stays dim: %d" % i)
    _check(ui.core.snapshot()["step"] == 0, "HUD did not alter real mission step")
    _check(ui.core.snapshot()["active"], "Original mission is still active after HUD update")

    ui.core.clear_data()
    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W61 NATIVE BRAND AND PHASE HUD PASS: %d checks" % assertions)
        quit(0)
    else:
        for item in failures:
            push_error("W61 BRAND/HUD: " + item)
        quit(1)
