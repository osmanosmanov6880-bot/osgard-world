extends SceneTree
## W55 — actual native OSGARD RU/EN typography and mobile protocol copy.
## Original GitHub W48 screenshot at 390x844 showed U+2192 tofu/box glyphs.
## Never alter physical simulations, mission buttons or their protections.
const Core = preload("res://scripts/OSGARDCore.gd")
const SAVE = "user://osgard_w55_readable_ui_test.cfg"
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, explanation: String) -> void:
    assertions += 1
    if not value:
        failures.append(explanation)

func _no_unsupported_glyphs(ui: OSGARDMain, caption: String) -> void:
    for kind in ["Label", "Button"]:
        var controls: Array[Node] = ui.find_children("*", kind, true, false)
        for node in controls:
            var text_value: String = str(node.get("text"))
            _check(not text_value.contains("→") and not text_value.contains("✓"),
                caption + " has no WebGL-unsupported U+2192/U+2713 in " + node.name)

func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn") as PackedScene
    _check(scene != null, "Original Godot scene loads from disk")
    if scene == null:
        _done()
        return
    var ui: OSGARDMain = scene.instantiate() as OSGARDMain
    _check(ui != null, "Native OSGARDMain control can instantiate")
    if ui == null:
        _done()
        return
    ui.core = Core.new(SAVE)
    ui.core.clear_data()
    root.add_child(ui)
    await process_frame
    await process_frame
    _check(ui.scroll != null, "Original native mobile ScrollContainer is present")
    _check(ui.mission_btns.size() == 6, "All six genuine mission buttons are preserved")
    _check(ui._legible_copy("STOP→HATCH") == "STOP > HATCH",
        "ASCII direction preserves protocol sequence and eliminates boxed arrow")
    var original_mission: int = int(ui.core.snapshot()["mission"])
    var original_score: int = int(ui.core.snapshot()["score"])

    for lang in ["ru", "en"]:
        ui.core.settings["locale"] = lang
        ui.size = Vector2(390, 844)
        ui._layout_stage_for_screen()
        ui._refresh()
        await process_frame
        await process_frame
        _check(ui.progress_text.text.count(" > ") == 4,
            lang + ": five real steps have exactly four legible direction markers")
        _check(ui.progress_text.text.contains("0/3 + 0/3"),
            lang + ": original three-plus-three progression is visible")
        _check(not ui._t("intro").contains("→") and ui._t("intro").contains(" > "),
            lang + ": localized safety-instruction sequence contains no tofu arrow")
        _check(ui.hint != null and not ui.hint.text.contains("→"),
            lang + ": instructional coach remains legible")
        _check(ui.progress_text.autowrap_mode != TextServer.AUTOWRAP_OFF,
            lang + ": phone protocol text wraps instead of overflowing")
        # W58: RU/EN live Godot telemetry never strands '|' at 390px.
        var telemetry_rows: PackedStringArray = ui.telemetry.text.split("\n")
        _check(telemetry_rows.size() == 3, lang + ": 390px live telemetry has three complete groups")
        _check(not ui.telemetry.text.contains("|"), lang + ": 390px has no orphan separators")
        if telemetry_rows.size() == 3:
            _check(telemetry_rows[0].contains(ui._t("rpm")) and telemetry_rows[0].contains("RPM"),
                lang + ": rotor label and actual RPM preserved")
            _check(telemetry_rows[1].contains(ui._t("hatch")) and telemetry_rows[1].contains("%"),
                lang + ": hatch label and actual percent preserved")
            _check(telemetry_rows[2].contains(ui._t("score")) and telemetry_rows[2].contains("/150"),
                lang + ": score label and actual score preserved")
        for key in ["reduced_motion", "sound", "captions", "metrics_consent"]:
            ui.core.settings[key] = true
        ui._refresh()
        var suffix_on: String = " / ВКЛ" if lang == "ru" else " / ON"
        for btn in [ui.motion_btn, ui.sound_btn, ui.captions_btn, ui.metrics_btn]:
            _check(btn.text.ends_with(suffix_on), lang + ": accessible positive state")
        for key in ["reduced_motion", "sound", "captions", "metrics_consent"]:
            ui.core.settings[key] = false
        ui._refresh()
        var suffix_off: String = " / ВЫКЛ" if lang == "ru" else " / OFF"
        for btn in [ui.motion_btn, ui.sound_btn, ui.captions_btn, ui.metrics_btn]:
            _check(btn.text.ends_with(suffix_off), lang + ": accessible negative state")
        _no_unsupported_glyphs(ui, lang + " 390px")
        _check(ui.mission_btns.size() == 6, lang + ": all six original missions remain present")
        _check(int(ui.core.snapshot()["mission"]) == original_mission and
            int(ui.core.snapshot()["score"]) == original_score,
            lang + ": typography update never changes simulated mission state")
        ui.size = Vector2(1366, 768)
        ui._layout_stage_for_screen()
        ui._refresh()
        await process_frame
        _no_unsupported_glyphs(ui, lang + " desktop")
        _check(ui.telemetry.text.count("     |     ") == 2 and not ui.telemetry.text.contains("\n"),
            lang + ": desktop keeps its original two readable separators")
        ui.size = Vector2(320, 760)
        ui._layout_stage_for_screen()
        ui._refresh()
        await process_frame
        _check(ui.telemetry.text.split("\n").size() == 3 and not ui.telemetry.text.contains("|"),
            lang + ": 320px compact telemetry has no orphan separator")
    ui.core.clear_data()
    ui.queue_free()
    await process_frame
    _done()

func _done() -> void:
    if failures.is_empty():
        print("OSGARD W55 REAL GODOT RU/EN GLYPH AND MOBILE PROTOCOL COPY PASS: %d assertions" % assertions)
        quit(0)
    else:
        for problem in failures:
            push_error("W55 TEXT LEGIBILITY REGRESSION: " + problem)
        quit(1)
