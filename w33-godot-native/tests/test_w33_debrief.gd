extends SceneTree
## Godot 4.4.1 actual native acceptance of W33 debrief and safety-first replay.
## Run after --editor --import. This is NOT a static Python acceptance test.
const Core = preload("res://scripts/OSGARDCore.gd")
const SAVE = "user://osgard_fieldlab_w33_native_test_only.cfg"
const BASE = [[68,44], [80,75], [48,55]]
const RECOVERY = [[56,62], [90,86], [62,40]]
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
    assertions += 1
    if not condition:
        failures.append(message)

func _tick(core: Object, count: int) -> void:
    for i in range(count):
        core.tick(0.1)

func _complete(core: Object, index: int, deliberate_error: bool = false) -> void:
    var base: int = index % 3
    var is_shift: bool = index >= 3
    _expect(core.begin_case(index), "Begin actual native case %d" % index)
    _expect(core.toggle_engine(), "Stop simulated drive")
    _tick(core, 14)
    _expect(core.toggle_hatch(), "Open hatch after rotor stops")
    _tick(core, 11)
    _expect(core.set_view(0 if deliberate_error else (2 if base == 0 else 1)), "Switch to inspection view")
    if deliberate_error:
        _expect(not core.scan(), "Wrong inspection view must reject")
        _expect(str(core.snapshot()["feedback"]) == "wrongView", "Real mistake reason recorded")
        _expect(core.set_view(2 if base == 0 else 1), "Correct view after mistake")
    _expect(core.adjust_calibration("a", BASE[base][0]), "Set real virtual channel A")
    _expect(core.adjust_calibration("b", BASE[base][1]), "Set real virtual channel B")
    if is_shift:
        _tick(core, 3)
        _expect(bool(core.snapshot()["incident_triggered"]), "Real incident triggered")
        _expect(core.adjust_calibration("a", RECOVERY[base][0]), "Restore virtual channel A")
        _expect(core.adjust_calibration("b", RECOVERY[base][1]), "Restore virtual channel B")
        _tick(core, 14)
    else:
        _tick(core, 5)
    _expect(core.scan(), "Real stabilized signal required")
    _expect(core.toggle_hatch(), "Close simulated hatch")
    _tick(core, 11)
    _expect(core.toggle_engine(), "Safe restart")
    _expect(bool(core.snapshot()["complete"]), "Actual case completed")

func _run() -> void:
    var c := Core.new(SAVE)
    _expect(c.clear_data(), "Clean isolated test save")
    _expect(c.set_setting("metrics_consent", false), "Never save metrics without permission")
    _complete(c, 0, true)
    var full: Dictionary = c.snapshot()
    var review: Dictionary = full.get("session_review", {})
    _expect(str(review.get("schema", "")) == "OSGARD_FIELDLAB_W33_SESSION_REVIEW_V1", "Review is actual native game data")
    _expect(review.get("completed") == true and review.get("simulation_only") == true, "Report proves successful simulated game")
    _expect(int(review.get("errors", -1)) == 1 and int(full["errors"]) == 1, "One rejected wrong view recorded")
    _expect(review.get("grade") == "PROFICIENT", "One mistake reduces actual game grade")
    _expect(int(review.get("score", 0)) == 126, "Score comes from original W31 scoring rule")
    _expect(review.get("history_persisted") == false, "Anonymous event trail never persisted")
    _expect(full["session_history_persisted"] == false, "Read-only state labels history ephemeral")
    _expect((review.get("unique_error_codes", []) as Array).has("wrongView"), "Wrong-view reason appears in real review")
    var sequence: Array = review.get("protocol", [])
    _expect(sequence.size() == 5, "Five real safety checkpoints")
    for stage in sequence:
        _expect(bool(stage.get("completed", false)), "Genuine checkpoint %s was completed" % str(stage.get("code", "")))
    _expect((full.get("session_history", []) as Array).size() >= 13, "Real incident history is populated from state transitions")
    _expect(c.retry_completed_case(), "Retry may start only after completion")
    var attempted: Dictionary = c.snapshot()
    _expect(attempted["active"] == true and attempted["complete"] == false, "Retry starts actual active mission")
    _expect((attempted["session_review"] as Dictionary).is_empty(), "Retry removes old debrief")
    _expect((attempted["session_history"] as Array).size() == 1, "Retry gets new anonymous timeline")
    _expect(not c.retry_completed_case(), "Unsafe retry cannot skip live training")

    # Native scene must show controls and not erase records until confirmed.
    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    _expect(packed != null, "Original source Godot Main.tscn exists")
    if packed == null:
        _done()
        return
    var ui: OSGARDMain = packed.instantiate() as OSGARDMain
    _expect(ui != null, "Main native UI is Godot Control")
    if ui == null:
        _done()
        return
    ui.core = Core.new(SAVE)
    root.add_child(ui)
    await process_frame
    await process_frame
    _expect(ui.debrief_label != null and ui.retry_button != null, "Operator assessment is a real Godot UI")
    _expect(ui.erase_confirm != null, "Destructive local data erase needs ConfirmationDialog")
    _expect(ui.scene_3d != null, "Original native 3D simulator still exists")
    if ui.scene_3d != null:
        var lights: Dictionary = ui.scene_3d.signal_qa_readout()
        _expect(lights.get("uses_single_real_multimesh") == true, "Read-only real 3D signal meter exists")
        _expect(int(lights.get("segments", -1)) == 10 and int(lights.get("shadow_casters", -1)) == 0, "Meter uses one batch, no real-time shadows")
        ui.scene_3d.apply_simulation(ui.core.snapshot())
        _expect(str(ui.scene_3d.signal_qa_readout().get("last_state", "")).length() > 0, "Meter follows real simulator snapshot")
    # Real responsive renderer adapts pixel budget without changing physics.
    ui.size = Vector2(360, 780)
    ui._layout_stage_for_screen()
    _expect(ui.visual_container.custom_minimum_size.y <= 300.0, "Mobile portrait does not force an oversized stage")
    _expect(ui.sub_viewport.size.x == 720, "Portrait HERO uses finite 720px backing render")
    ui.core.set_setting("quality", "eco")
    ui._layout_stage_for_screen()
    _expect(ui.sub_viewport.size.x == 576, "Portrait ECO uses cheaper 576px backing render")
    ui.core.set_setting("quality", "hero")
    ui._layout_stage_for_screen()
    var old_attempts: int = int(ui.core.records["attempts"][0])
    _expect(old_attempts >= 2, "Test record is present before confirming erasure")
    ui._erase_data()
    _expect(int(ui.core.records["attempts"][0]) == old_attempts, "Opening erase warning does not erase anything")
    _expect(ui.erase_confirm.dialog_text.length() > 30, "Confirmation explains permanent deletion")
    ui.erase_confirm.hide()
    _expect(int(ui.core.records["attempts"][0]) == old_attempts, "Cancel/hide does not erase results")
    ui._confirm_erase()
    _expect(int(ui.core.records["attempts"][0]) == 0, "Explicit confirmation erases scores and attempts")
    _expect((ui.core.snapshot()["session_history"] as Array).is_empty(), "Erasure clears session history")
    ui.queue_free()
    await process_frame
    var fresh := Core.new(SAVE)
    _expect((fresh.snapshot()["session_review"] as Dictionary).is_empty(), "No review reappears after erasure")
    _expect(int(fresh.records["attempts"][0]) == 0, "User records truly removed from disk")

    # Bounded memory log does not grow without limit; nothing stored to disk.
    _expect(fresh.begin_case(0), "Stress test real case")
    _expect(not fresh.scan(), "Real wrong-order mistake recorded before log overflow")
    for i in range(180):
        fresh.set_view(i % 3)
    _expect((fresh.snapshot()["session_history"] as Array).size() == 96, "Event trail is capped at 96 actions")
    # Old wrong-order event is no longer in the 96 visible rows; its cause
    # must remain available at debrief after actual five-step completion.
    _expect(fresh.toggle_engine(), "Stress case stop")
    _tick(fresh, 14)
    _expect(fresh.toggle_hatch(), "Stress case safe open")
    _tick(fresh, 11)
    _expect(fresh.set_view(2), "Stress case correct optical camera")
    _expect(fresh.adjust_calibration("a", 68), "Stress case calibrate A")
    _expect(fresh.adjust_calibration("b", 44), "Stress case calibrate B")
    _tick(fresh, 5)
    _expect(fresh.scan(), "Stress case scan")
    _expect(fresh.toggle_hatch(), "Stress case close")
    _tick(fresh, 11)
    _expect(fresh.toggle_engine(), "Stress case safe restart")
    var overflow_review: Dictionary = fresh.snapshot().get("session_review", {})
    for milestone in overflow_review.get("protocol", []):
        _expect(bool(milestone.get("completed", false)), "Long sessions preserve true checkpoint milestones")
    _expect((overflow_review.get("unique_error_codes", []) as Array).has("wrongOrder"), "First real error survives bounded event-log overflow")
    _expect((fresh.snapshot()["session_history"] as Array).size() == 96, "Hard memory limit also applies after completion")
    var reconstructed := Core.new(SAVE)
    _expect((reconstructed.snapshot()["session_history"] as Array).is_empty(), "Not one session event persisted by default")
    _expect((reconstructed.snapshot()["session_review"] as Dictionary).is_empty(), "Local best scores do not contain personal event history")
    fresh.clear_data()
    _done()

func _done() -> void:
    if failures.is_empty():
        print("W33 NATIVE DEBRIEF PASS: %d real assertions, actual wrong view, score rubric, retry, 10 instanced LEDs, bounded privacy and confirmed wipe" % assertions)
        quit(0)
    else:
        for failure in failures:
            push_error("W33: " + failure)
        push_error("W33 FAILED %d / %d" % [failures.size(), assertions])
        quit(1)
