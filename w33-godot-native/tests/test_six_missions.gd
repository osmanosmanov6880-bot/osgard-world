extends SceneTree
## Execute with Godot 4.4.1 after import:
## godot --headless --path godot --script res://tests/test_six_missions.gd
## Every test uses a private test save; no active player's file is touched.

const Core = preload("res://scripts/OSGARDCore.gd")
const TEST_SAVE = "user://osgard_fieldlab_w32_native_test_only.cfg"
const BASE = [[68, 44], [80, 75], [48, 55]]
const RECOVERY = [[56, 62], [90, 86], [62, 40]]
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("run_all")

func _check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        failures.append(message)

func _tick_n(core: Object, count: int) -> void:
    for i in range(count):
        core.tick(0.1)

func _mission(core: Object, mission: int, expected: Dictionary) -> void:
    var base: int = mission % 3
    var advanced: bool = mission >= 3
    _check(core.begin_case(mission), "Mission %d should start" % mission)
    _check(core.toggle_engine(), "Mission %d drive stop" % mission)
    _tick_n(core, 14)
    _check(float(core.snapshot()["rpm"]) <= 80.0, "Mission %d rotor below 80" % mission)
    _check(core.toggle_hatch(), "Mission %d open hatch" % mission)
    _tick_n(core, 11)
    _check(int(core.snapshot()["step"]) == 2, "Mission %d hatch full and inspection unlocked" % mission)
    _check(core.set_view(2 if base == 0 else 1), "Mission %d correct camera" % mission)
    _check(core.adjust_calibration("a", BASE[base][0]), "Mission %d axis A" % mission)
    _check(core.adjust_calibration("b", BASE[base][1]), "Mission %d axis B" % mission)
    if advanced:
        _tick_n(core, 3)
        _check(bool(core.snapshot()["incident_triggered"]), "Mission %d scripted fault should trigger" % mission)
        _check(int(core.snapshot()["incident_count"]) == 1, "Mission %d only one scripted event" % mission)
        _check(core.adjust_calibration("a", RECOVERY[base][0]), "Mission %d recovery A" % mission)
        _check(core.adjust_calibration("b", RECOVERY[base][1]), "Mission %d recovery B" % mission)
        _tick_n(core, 14)
    else:
        _tick_n(core, 5)
    _check(bool(core.snapshot()["calibration"]["ready"]), "Mission %d must truly stabilize" % mission)
    _check(core.scan(), "Mission %d scan real stable readings" % mission)
    _check(core.toggle_hatch(), "Mission %d hatch close" % mission)
    _tick_n(core, 11)
    _check(int(core.snapshot()["step"]) == 4, "Mission %d hatch sealed" % mission)
    _check(core.toggle_engine(), "Mission %d safe restart" % mission)
    var snap: Dictionary = core.snapshot()
    _check(bool(snap["complete"]), "Mission %d clears" % mission)
    _check(int(snap["score"]) == int(expected["score"]), "Mission %d score parity: got %d expected %d" % [mission, snap["score"], expected["score"]])
    _check(int(snap["incident_count"]) == int(expected["incident_count"]), "Mission %d incident parity" % mission)
    _check(int(snap["errors"]) == 0, "Mission %d no false penalty" % mission)

func _run_negative(message: String, operation: int, expected_code: String) -> void:
    var path: String = "user://osgard_w32_negative_case_%d.cfg" % operation
    var demo := Core.new(path)
    demo.clear_data()
    var accepted := demo.begin_case(0)
    _check(accepted, "Negative %s setup" % message)
    var outcome: bool = true
    if operation == 0:
        outcome = demo.toggle_hatch()
    elif operation == 1:
        outcome = demo.scan()
    else:
        demo.toggle_engine()
        _tick_n(demo, 14)
        demo.toggle_hatch()
        _tick_n(demo, 11)
        if operation == 2:
            outcome = demo.toggle_engine()
        elif operation == 3:
            outcome = demo.adjust_calibration("a", 68)
        elif operation == 4:
            demo.set_view(2)
            outcome = demo.scan()
    _check(not outcome, "%s must be rejected" % message)
    _check(str(demo.snapshot()["feedback"]) == expected_code, "%s exact reason" % message)
    demo.clear_data()

func run_all() -> void:
    var reference: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/w31_reference_fixtures.json"))
    if not reference is Dictionary:
        push_error("W32 native QA cannot open true W31 reference fixture")
        quit(1)
        return
    var fixture: Dictionary = reference
    var c := Core.new(TEST_SAVE)
    c.clear_data()
    _check(not c.begin_case(3), "Advanced mission locked before base")
    _check(c.set_setting("metrics_consent", true), "Consent can be enabled locally")
    _check(c.set_setting("reduced_motion", true), "Accessibility motion preference")
    for i in range(6):
        _mission(c, i, fixture["missions"][i])
    var result: Dictionary = c.snapshot()
    _check(int(result["cleared_count"]) == 3, "Three base missions persisted")
    _check(int(result["shift_cleared_count"]) == 3, "Three shifts persisted")
    _check(int(result["metrics"]["completed"]) == 6, "Consent-only event count")
    _check(int(result["mastery_count"]) == 3, "Earned score based proficiency")
    for i in range(3):
        _check(int(result["records"]["best"][i]) == 148, "Independent base score %d" % i)
        _check(int(result["shifts"]["best"][i]) == 147, "Independent shift score %d" % i)
    # Verify true local file persistence after reconstruction.
    var reloaded := Core.new(TEST_SAVE)
    _check(int(reloaded.snapshot()["cleared_count"]) == 3, "Base save survives a new engine model")
    _check(int(reloaded.snapshot()["shift_cleared_count"]) == 3, "Advanced save survives reload")
    _check(str(reloaded.settings["locale"]) == "ru", "RU locale persists")
    _check(reloaded.set_setting("metrics_consent", false), "Explicit privacy opt-out")
    var private_reload := Core.new(TEST_SAVE)
    _check(int(private_reload.metrics["completed"]) == 0, "No saved private counters after revocation")
    for i in range(6):
        var row: Dictionary = fixture["matrix"][i]
        var analysis: Dictionary = private_reload.analyze(int(row["case"]), {"a":int(row["target_a"]), "b":int(row["target_b"])}, 1.25 if bool(row["incident"]) else 0.45, bool(row["incident"]), 1.25 if bool(row["incident"]) else 0.45)
        _check(bool(analysis["ready"]), "W31 source calibration %d must become ready" % i)
        _check(int(analysis["quality"]) == int(row["valid"]["quality"]), "W31 exact signal quality parity %d" % i)
        _check(int(analysis["hold_percent"]) == int(row["valid"]["holdPercent"]), "W31 hold percent parity %d" % i)
    _run_negative("hatch with powered drive", 0, "safetyInterlock")
    _run_negative("scan before stopping", 1, "wrongOrder")
    _run_negative("restart with open hatch", 2, "safetyInterlock")
    _run_negative("calibrate from wrong view", 3, "wrongView")
    _run_negative("scan before calibration", 4, "calibrationNeeded")
    _check(private_reload.clear_data(), "Safe total erase")
    var cleared := Core.new(TEST_SAVE)
    _check(int(cleared.snapshot()["cleared_count"]) == 0, "No records after wipe")
    _check(int(cleared.snapshot()["shift_cleared_count"]) == 0, "No shift records after wipe")
    _check(int(cleared.metrics["completed"]) == 0, "No retained private metrics")
    if failures.is_empty():
        print("W32 NATIVE SIX-MISSION PARITY PASS: %d real assertions; 6 completions, 3 incidents, W31 scores, guards, persistence, privacy" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error("W32 FAILED: " + failure)
        push_error("W32 native %d / %d assertions failed" % [failures.size(), checks])
        quit(1)
