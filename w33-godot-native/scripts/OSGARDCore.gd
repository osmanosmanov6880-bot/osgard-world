extends RefCounted
class_name OSGARDCore
## Faithful six-mission offline logic port of W31's src/core.js (Godot 4.4.1).
## All physical values are intentionally *simulated*, not industrial guidance.
## No HTTP, machinery driver, executable code loading or multiplayer access.

signal feedback_sent(code: String, error: bool)
signal snapshot_changed(snapshot: Dictionary)

const SAVE_PATH := "user://osgard_fieldlab_w32_sim_v1.cfg"
const SAVE_SCHEMA := 1
const MAX_ACTION_HISTORY := 96
const PROTOCOL_EVENTS := ["driveStopped", "hatchOpened", "faultConfirmed", "hatchClosed", "caseCompleted"]
const RPM_ACCESS_THRESHOLD := 80.0
const STABILIZE_SECONDS := 0.45
const ADVANCED_HOLD_SECONDS := 1.25
const INCIDENT_AFTER_SECONDS := 0.23
const FAULT_IDS := ["optical", "cooling", "hatch"]
const FAULT_CODES := ["OPTICAL-EDGE +0.7 (SIM)", "AIRFLOW BELOW TARGET (SIM)", "HATCH CONTACT UNSEALED (SIM)"]
const FAULT_VIEWS := [2, 1, 1]
const INIT_PUZZLES := [{"a":14,"b":18}, {"a":18,"b":24}, {"a":13,"b":85}]
const INCIDENT_LABELS := ["OPTIC REFERENCE SHIFT", "THERMAL LOAD INCREASE", "CONTACT REFERENCE SHIFT"]

var save_path: String = SAVE_PATH
var settings: Dictionary = {}
var records: Dictionary = {}
var shifts: Dictionary = {}
var metrics: Dictionary = {}
var s: Dictionary = {}
var last_feedback: String = "idle"
var last_error: bool = false
var event_serial: int = 0
# Ephemeral, privacy-respecting action history for *this* attempt only.
# Never stored to disk and never transmitted outside this simulator.
var session_history: Array[Dictionary] = []
# Derived only from accepted engine events, independent of bounded log length.
var session_protocol: Dictionary = {}
var session_error_reasons: Array[String] = []
var completed_review: Dictionary = {}

func _init(path: String = SAVE_PATH) -> void:
    save_path = path
    settings = _default_settings()
    records = _blank_records()
    shifts = _blank_records()
    metrics = _blank_metrics()
    _new_state()
    load_local()

func _default_settings() -> Dictionary:
    return {"locale":"ru", "quality":"hero", "reduced_motion":false,
        "sound":false, "captions":true, "metrics_consent":false}

func _blank_records() -> Dictionary:
    return {"best":[0,0,0], "attempts":[0,0,0], "cleared":[false,false,false]}

func _blank_metrics() -> Dictionary:
    return {"completed":0, "errors":0, "elapsed_seconds":0, "local_only":true}

func _new_state() -> void:
    s = {"fault":-1, "mission":-1, "advanced":false, "active":false,
        "complete":false, "step":0, "errors":0, "score":0, "seconds":0.0,
        "drive_on":true, "rpm":1480.0, "hatch":0.0, "hatch_target":0.0,
        "view":0, "rotor_angle":0.0, "puzzle":{"a":0,"b":0},
        "hold":0.0, "incident_triggered":false, "incident_count":0}
    last_feedback = "idle"
    last_error = false
    session_history.clear()
    session_protocol.clear()
    session_error_reasons.clear()
    completed_review.clear()

func _valid_records(candidate: Variant) -> bool:
    if not (candidate is Dictionary):
        return false
    for key in ["best", "attempts", "cleared"]:
        if not candidate.has(key) or not (candidate[key] is Array) or candidate[key].size() != 3:
            return false
    for i in range(3):
        var best: Variant = candidate["best"][i]
        var attempts: Variant = candidate["attempts"][i]
        if not (best is int) or best < 0 or best > 150:
            return false
        if not (attempts is int) or attempts < 0 or attempts > 1000000:
            return false
        if not (candidate["cleared"][i] is bool):
            return false
    return true

func _valid_settings(candidate: Variant) -> bool:
    if not (candidate is Dictionary):
        return false
    for key in _default_settings().keys():
        if not candidate.has(key):
            return false
    if candidate["locale"] not in ["ru", "en"]:
        return false
    if candidate["quality"] not in ["hero", "eco"]:
        return false
    for key in ["reduced_motion", "sound", "captions", "metrics_consent"]:
        if not (candidate[key] is bool):
            return false
    return true

func _valid_metrics(candidate: Variant) -> bool:
    if not (candidate is Dictionary) or candidate.get("local_only") != true:
        return false
    for key in ["completed", "errors", "elapsed_seconds"]:
        var number: Variant = candidate.get(key)
        if not (number is int) or number < 0 or number > 10000000:
            return false
    return true

func load_local() -> void:
    var config := ConfigFile.new()
    if config.load(save_path) != OK or config.get_value("meta", "schema", -1) != SAVE_SCHEMA:
        return
    var saved_settings: Variant = config.get_value("player", "settings", null)
    var saved_records: Variant = config.get_value("player", "records", null)
    var saved_shifts: Variant = config.get_value("player", "shifts", null)
    var saved_metrics: Variant = config.get_value("player", "metrics", null)
    if _valid_settings(saved_settings):
        settings = (saved_settings as Dictionary).duplicate(true)
    if _valid_records(saved_records):
        records = (saved_records as Dictionary).duplicate(true)
    if _valid_records(saved_shifts):
        shifts = (saved_shifts as Dictionary).duplicate(true)
    if bool(settings.get("metrics_consent", false)) and _valid_metrics(saved_metrics):
        metrics = (saved_metrics as Dictionary).duplicate(true)
    else:
        metrics = _blank_metrics()

func save_local() -> bool:
    var config := ConfigFile.new()
    config.set_value("meta", "schema", SAVE_SCHEMA)
    config.set_value("player", "settings", settings.duplicate(true))
    config.set_value("player", "records", records.duplicate(true))
    config.set_value("player", "shifts", shifts.duplicate(true))
    # Never save private statistics without explicit affirmative opt-in.
    if bool(settings["metrics_consent"]):
        config.set_value("player", "metrics", metrics.duplicate(true))
    return config.save(save_path) == OK

func set_setting(key: String, value: Variant) -> bool:
    var revised := settings.duplicate(true)
    if not revised.has(key):
        return _event("invalidSettings", true)
    revised[key] = value
    if not _valid_settings(revised):
        return _event("invalidSettings", true)
    var was_consent: bool = bool(settings["metrics_consent"])
    settings = revised
    if not bool(settings["metrics_consent"]) or not was_consent:
        metrics = _blank_metrics()
    save_local()
    return _event("settingsSaved")

func clear_data() -> bool:
    settings = _default_settings()
    records = _blank_records()
    shifts = _blank_records()
    metrics = _blank_metrics()
    _new_state()
    # Remove the entire storage file so revoked consent leaves no statistics.
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(save_path)
    return _event("dataCleared")

func _event(code: String, error: bool = false) -> bool:
    last_feedback = code
    last_error = error
    event_serial += 1
    # Keep only an anonymous, bounded in-memory timeline. Nothing persists.
    if int(s.get("mission", -1)) >= 0:
        if session_history.size() >= MAX_ACTION_HISTORY:
            session_history.pop_front()
        session_history.append({
            "event": code, "error": error,
            "step": int(s["step"]), "mission": int(s["mission"]),
            "seconds": snappedf(float(s["seconds"]), 0.1)
        })
        if not error and code in PROTOCOL_EVENTS:
            session_protocol[code] = true
        if error and not session_error_reasons.has(code) and session_error_reasons.size() < 32:
            session_error_reasons.append(code)
    if code == "caseCompleted" and bool(s["complete"]):
        completed_review = _create_session_review()
    feedback_sent.emit(code, error)
    snapshot_changed.emit(snapshot())
    return not error

func _create_session_review() -> Dictionary:
    var achieved: Array[Dictionary] = []
    # A long sequence of wrong actions can trim the latest 96 visible events,
    # but it must NEVER erase a legitimately completed protocol checkpoint.
    for goal in PROTOCOL_EVENTS:
        achieved.append({"code": goal, "completed": bool(session_protocol.get(goal, false))})
    var score: int = int(s["score"])
    var result := "EXCELLENT" if score >= 140 else "PROFICIENT" if score >= 100 else "PRACTICE"
    return {
        "schema":"OSGARD_FIELDLAB_W33_SESSION_REVIEW_V1",
        "mission": int(s["mission"]),
        "fault": int(s["fault"]),
        "advanced": bool(s["advanced"]),
        "simulation_only": true,
        "completed": bool(s["complete"]),
        "score": score,
        "grade": result,
        "errors": int(s["errors"]),
        "duration_seconds": snappedf(float(s["seconds"]), 0.1),
        "incident_count": int(s["incident_count"]),
        "protocol": achieved,
        "unique_error_codes": session_error_reasons.duplicate(),
        "history_persisted": false
    }

func retry_completed_case() -> bool:
    if bool(s["active"]) or not bool(s["complete"]) or int(s["mission"]) < 0:
        return _event("retryUnavailable", true)
    var last_mission: int = int(s["mission"])
    # begin_case respects the original advanced-case unlock and resets only
    # ephemeral session state, never prior attempts, records or settings.
    return begin_case(last_mission)

func _mistake(code: String) -> bool:
    if bool(s["active"]):
        s["errors"] = mini(9999, int(s["errors"]) + 1)
    return _event(code, true)

func begin_case(index: int) -> bool:
    if index < 0 or index >= 6:
        return _event("invalidFault", true)
    if bool(s["active"]):
        return _event("alreadyActive", true)
    var is_advanced := index >= 3
    var base: int = index - 3 if is_advanced else index
    if is_advanced and not bool(records["cleared"][base]):
        return _event("shiftLocked", true)
    _new_state()
    s["fault"] = base
    s["mission"] = index
    s["advanced"] = is_advanced
    s["active"] = true
    s["puzzle"] = INIT_PUZZLES[base].duplicate(true)
    var board: Dictionary = shifts if is_advanced else records
    board["attempts"][base] = mini(1000000, int(board["attempts"][base]) + 1)
    save_local()
    return _event("shiftStarted" if is_advanced else "caseStarted")

func set_view(index: int) -> bool:
    if index < 0 or index > 2:
        return _event("invalidView", true)
    s["view"] = index
    s["hold"] = 0.0
    return _event("cameraChanged")

func adjust_calibration(axis: String, value: int) -> bool:
    if axis not in ["a", "b"] or value < 0 or value > 100:
        return _event("invalidCalibration", true)
    if not bool(s["active"]) or int(s["step"]) != 2 or bool(s["drive_on"]) or float(s["rpm"]) > RPM_ACCESS_THRESHOLD or float(s["hatch"]) < 0.995 or float(s["hatch_target"]) != 1.0:
        return _mistake("calibrationLocked")
    if int(s["view"]) != FAULT_VIEWS[int(s["fault"])]:
        return _mistake("wrongView")
    var current: Dictionary = s["puzzle"]
    if int(current[axis]) == value:
        return true
    current[axis] = value
    s["hold"] = 0.0
    return _event("calibrationAdjusted")

func toggle_engine() -> bool:
    if bool(s["drive_on"]):
        s["drive_on"] = false
        if bool(s["active"]) and int(s["step"]) == 0:
            s["step"] = 1
            return _event("driveStopped")
        if bool(s["active"]):
            return _mistake("wrongOrder")
        return _event("driveStopped")
    # Cannot start while the hatch is opening, open, closing or unsealed.
    if float(s["hatch"]) > 0.005 or float(s["hatch_target"]) > 0.0:
        return _mistake("safetyInterlock")
    if bool(s["active"]) and int(s["step"]) != 4:
        return _mistake("wrongOrder")
    s["drive_on"] = true
    if bool(s["active"]) and int(s["step"]) == 4:
        s["step"] = 5
        _finish_case()
        return _event("caseCompleted")
    return _event("driveStarted")

func toggle_hatch() -> bool:
    if bool(s["drive_on"]) or float(s["rpm"]) > RPM_ACCESS_THRESHOLD:
        return _mistake("safetyInterlock")
    # No hatch reversal while in motion.
    if float(s["hatch"]) > 0.005 and float(s["hatch"]) < 0.995:
        return _mistake("hatchInMotion")
    if float(s["hatch_target"]) == 0.0:
        if bool(s["active"]) and int(s["step"]) != 1:
            return _mistake("wrongOrder")
        s["hatch_target"] = 1.0
        return _event("hatchOpening")
    if bool(s["active"]) and int(s["step"]) != 3:
        return _mistake("wrongOrder")
    s["hatch_target"] = 0.0
    return _event("hatchClosing")

func analyze(index: int, values: Dictionary, held: float = 0.0, incident: bool = false, hold_required: float = STABILIZE_SECONDS) -> Dictionary:
    if index < 0 or index > 2 or not values.has("a") or not values.has("b"):
        return {}
    var a: float = float(values["a"])
    var b: float = float(values["b"])
    if a < 0.0 or a > 100.0 or b < 0.0 or b > 100.0:
        return {}
    var good := false
    var quality := 0
    var reading: Dictionary = {}
    if index == 0:
        var target_a := 56.0 if incident else 68.0
        var target_b := 62.0 if incident else 44.0
        var error := sqrt(pow((a - target_a) * 0.16, 2.0) + pow((b - target_b) * 0.23, 2.0))
        var focus := clampf(100.0 - absf(b - target_b) * 1.6, 0.0, 100.0)
        good = absf(a - target_a) <= 4.0 and absf(b - target_b) <= 6.0
        quality = clampi(roundi(100.0 - error * 6.0), 0, 100)
        reading = {"alignment_mm": snappedf((a - target_a) * 0.16, 0.01), "focus_percent": roundi(focus), "error": snappedf(error, 0.01)}
    elif index == 1:
        var temp := (118.0 if incident else 104.0) - 0.56 * a - 0.18 * b
        var flow := 0.61 * a + 0.39 * b
        var temp_min := 46.0 if incident else 45.0
        var temp_max := 55.0 if incident else 56.0
        var flow_min := 84.0 if incident else 64.0
        var flow_max := 93.0 if incident else 92.0
        good = temp >= temp_min and temp <= temp_max and flow >= flow_min and flow <= flow_max
        quality = clampi(roundi(100.0 - absf(temp - 50.0) * 2.0 - absf(flow - 78.0) * 0.8), 0, 100)
        reading = {"outlet_c": snappedf(temp, 0.1), "airflow_percent": roundi(flow)}
    else:
        var target_a_hatch := 62.0 if incident else 48.0
        var target_b_hatch := 40.0 if incident else 55.0
        var left := absf(a - target_a_hatch)
        var right := absf(b - target_b_hatch)
        good = left <= 6.0 and right <= 6.0 and absf((a - b) - (target_a_hatch - target_b_hatch)) <= 7.0
        quality = clampi(roundi(100.0 - (left * 1.3 + right * 1.5)), 0, 100)
        reading = {"left_gap_mm": snappedf(left * 0.09, 0.01), "right_gap_mm": snappedf(right * 0.09, 0.01), "contact_percent": quality}
    var within_hold := clampf(held, 0.0, hold_required)
    return {"type":FAULT_IDS[index], "axis_a":a, "axis_b":b,
        "within_tolerance":good, "ready":good and within_hold >= hold_required - 0.00000001,
        "hold_seconds":snappedf(within_hold, 0.001), "required_seconds":hold_required,
        "hold_percent":roundi(100.0 * within_hold / hold_required), "quality":quality,
        "reading":reading, "incident":incident}

func scan() -> bool:
    if not bool(s["active"]):
        return _event("selectCaseFirst", true)
    if bool(s["drive_on"]) or int(s["step"]) != 2:
        return _mistake("wrongOrder")
    if float(s["hatch"]) < 0.995 or float(s["hatch_target"]) != 1.0:
        return _mistake("waitForHatch")
    if int(s["view"]) != FAULT_VIEWS[int(s["fault"])]:
        return _mistake("wrongView")
    var advanced: bool = bool(s["advanced"])
    var required := ADVANCED_HOLD_SECONDS if advanced else STABILIZE_SECONDS
    var cal := analyze(int(s["fault"]), s["puzzle"], float(s["hold"]), bool(s["incident_triggered"]), required)
    if not bool(cal.get("ready", false)) or (advanced and not bool(s["incident_triggered"])):
        return _mistake("calibrationNeeded")
    s["step"] = 3
    return _event("faultConfirmed")

func _finish_case() -> bool:
    if not bool(s["active"]) or int(s["step"]) != 5:
        return false
    s["active"] = false
    s["complete"] = true
    s["score"] = clampi(150 - 22 * int(s["errors"]) - floori(float(s["seconds"]) * 0.6), 0, 150)
    var fault: int = int(s["fault"])
    var board: Dictionary = shifts if bool(s["advanced"]) else records
    board["cleared"][fault] = true
    board["best"][fault] = maxi(int(board["best"][fault]), int(s["score"]))
    if bool(settings["metrics_consent"]):
        metrics["completed"] = mini(10000000, int(metrics["completed"]) + 1)
        metrics["errors"] = mini(10000000, int(metrics["errors"]) + int(s["errors"]))
        metrics["elapsed_seconds"] = mini(10000000, int(metrics["elapsed_seconds"]) + ceili(float(s["seconds"])))
    save_local()
    return true

func tick(delta: float) -> void:
    if not is_finite(delta) or delta <= 0.0:
        return
    var dt := minf(delta, 0.1)
    var hatch: float = float(s["hatch"])
    var desired: float = float(s["hatch_target"])
    var movement := minf(absf(desired - hatch), dt * 0.95)
    s["hatch"] = clampf(hatch + signf(desired - hatch) * movement, 0.0, 1.0)
    if bool(s["active"]):
        s["seconds"] = minf(18000.0, float(s["seconds"]) + dt)
        if int(s["step"]) == 2:
            var can_hold: bool = not bool(s["drive_on"]) and float(s["rpm"]) <= RPM_ACCESS_THRESHOLD and float(s["hatch"]) >= 0.995 and desired == 1.0 and int(s["view"]) == FAULT_VIEWS[int(s["fault"])]
            var cal := analyze(int(s["fault"]), s["puzzle"], 0.0, bool(s["incident_triggered"]))
            if can_hold and bool(cal.get("within_tolerance", false)):
                var advanced: bool = bool(s["advanced"])
                var required := ADVANCED_HOLD_SECONDS if advanced else STABILIZE_SECONDS
                s["hold"] = minf(required, float(s["hold"]) + dt)
                if advanced and not bool(s["incident_triggered"]) and float(s["hold"]) >= INCIDENT_AFTER_SECONDS:
                    s["incident_triggered"] = true
                    s["incident_count"] = 1
                    s["hold"] = 0.0
                    _event("incidentTriggered")
            else:
                s["hold"] = 0.0
        if int(s["step"]) == 1 and float(s["hatch"]) >= 0.995 and desired == 1.0:
            s["step"] = 2
            _event("hatchOpened")
        if int(s["step"]) == 3 and float(s["hatch"]) <= 0.005 and desired == 0.0:
            s["step"] = 4
            _event("hatchClosed")
    var desired_rpm := 1480.0 if bool(s["drive_on"]) else 0.0
    s["rpm"] = float(s["rpm"]) + (desired_rpm - float(s["rpm"])) * minf(1.0, dt * 3.2)
    if absf(float(s["rpm"])) < 0.2:
        s["rpm"] = 0.0
    s["rotor_angle"] = fposmod(float(s["rotor_angle"]) + dt * float(s["rpm"]) * 0.012, TAU)

func snapshot() -> Dictionary:
    var out: Dictionary = s.duplicate(true)
    out["schema"] = "OSGARD_FIELDLAB_R135_W32_SIM"
    out["simulation_only"] = true
    out["settings"] = settings.duplicate(true)
    out["records"] = records.duplicate(true)
    out["shifts"] = shifts.duplicate(true)
    out["metrics"] = metrics.duplicate(true)
    out["fault_code"] = FAULT_CODES[int(s["fault"])] if int(s["fault"]) >= 0 else ""
    out["target_view"] = FAULT_VIEWS[int(s["fault"])] if int(s["fault"]) >= 0 else -1
    out["feedback"] = last_feedback
    out["last_error"] = last_error
    out["event_id"] = event_serial
    out["calibration"] = analyze(int(s["fault"]), s["puzzle"], float(s["hold"]), bool(s["incident_triggered"]), ADVANCED_HOLD_SECONDS if bool(s["advanced"]) else STABILIZE_SECONDS)
    out["cleared_count"] = records["cleared"].count(true)
    out["shift_cleared_count"] = shifts["cleared"].count(true)
    out["mastery_count"] = 0
    out["shift_mastery_count"] = 0
    for i in range(3):
        if bool(records["cleared"][i]) and int(records["best"][i]) >= 100:
            out["mastery_count"] += 1
        if bool(shifts["cleared"][i]) and int(shifts["best"][i]) >= 100:
            out["shift_mastery_count"] += 1
    # W33 report is derived only from real game actions. It is not a saved
    # user profile and therefore vanishes on restart/erase/new attempt.
    out["session_review"] = completed_review.duplicate(true)
    out["session_history"] = session_history.duplicate(true)
    out["session_history_persisted"] = false
    out["interlock_active"] = bool(s["drive_on"]) or float(s["hatch"]) > 0.005 or float(s["hatch_target"]) > 0.0
    out["hatch_sealed"] = float(s["hatch"]) <= 0.005 and float(s["hatch_target"]) == 0.0
    out["inspection_allowed"] = bool(s["active"]) and int(s["step"]) == 2 and not bool(s["drive_on"]) and float(s["rpm"]) <= RPM_ACCESS_THRESHOLD and float(s["hatch"]) >= 0.995 and float(s["hatch_target"]) == 1.0 and int(s["view"]) == FAULT_VIEWS[int(s["fault"])]
    return out
