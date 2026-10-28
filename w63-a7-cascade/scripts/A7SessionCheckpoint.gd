extends RefCounted
class_name A7SessionCheckpoint
## W73: local user:// session save/resume of ORIGINAL deterministic 6-shift
## A7 game AND the optional W71/W72 field mission. It stores a bounded
## journal of real accepted player events, NEVER mutable arbitrary engine
## pointers. Recovery REPLAYS every event into a separate real Godot sandbox
## scene and compares source-derived states before altering a live session.
##
## SHA256 detects accidental corruption/version drift; unkeyed SHA256 is NOT
## anti-tamper security. There is no network, real machine or backend.

const FILE_PATH: String = "user://last_frontier_a7_w73_checkpoint.json"
const SCHEMA: String = "LAST_FRONTIER_W73_LOCAL_CHECKPOINT_REPLAY_V1"
const LIMIT_BYTES: int = 65536
const MAX_EVENTS: int = 160
const SAVE_KEYS := ["start_normal","start_extended","action",
    "inspect","valve","relay","sync"]

var events: Array[Dictionary] = []
var replaying: bool = false
var saves: int = 0
var successful_restores: int = 0
var rejected_loads: int = 0
var last_status: String = "empty"
var last_read_bytes: int = 0
var last_replay_steps: int = 0

func clear() -> void:
    if replaying:
        return
    events.clear()
    last_status = "cleared"

func _proof(ui: A7CascadeScreen) -> Dictionary:
    var state: Dictionary = ui.model.snapshot()
    var mission: A7SpatialMission = ui.stage_3d.spatial_mission
    var field: A7FieldOperations = ui.stage_3d.field_operations
    return {
        "status": str(state["status"]),
        "shift": int(state["shift"]),
        "actions_left": int(state["actions_left"]),
        "last_event": str(state["last_event"]),
        "history": state["history"],
        "metrics": state["metrics"],
        "mission_active": mission.active,
        "extended_mode": mission.extended_mode,
        "mission_phase": mission.phase,
        "mission_changes": mission.progress_events,
        "real_inspections": mission.real_inspections,
        "field_enabled": field.enabled,
        "valve_index": field.valve_index,
        "valve_target": field.valve_target,
        "relay_mask": field.relay_mask,
        "relay_target": field.relay_target,
        "sync_step": field.sync_step,
        "sync_mistakes": field.sync_mistakes,
        "sync_solved": field.sync_solved,
    }

func _valid_event(kind: String, value: Variant) -> bool:
    if not SAVE_KEYS.has(kind):
        return false
    if kind in ["start_normal","start_extended"]:
        return value == 0
    if kind == "action":
        return value is String and A7CascadeCore.ACTIONS.has(value)
    if kind == "inspect":
        return value is String and ["CORE","RELAY"].has(value)
    if kind == "valve":
        return (value is int or value is float) and (
            float(value) == float(int(value))) and [1,-1].has(int(value))
    if kind in ["relay","sync"]:
        return (value is int or value is float) and (
            float(value) == float(int(value))) and int(value) >= 0 and int(value) <= 2
    return false

func note(kind: String, value: Variant, ui: A7CascadeScreen) -> void:
    if replaying or not _valid_event(kind,value) or events.size() >= MAX_EVENTS:
        return
    events.append({
        "kind":kind,
        "value":value,
        "proof_sha256":JSON.stringify(_proof(ui)).sha256_text(),
    })

func _snapshot(ui: A7CascadeScreen) -> Dictionary:
    var actor: A7FirstPersonOperator = ui.stage_3d.first_person
    var pos: Vector3 = actor.body.position
    return {
        "events":events.duplicate(true),
        "proof_sha256":JSON.stringify(_proof(ui)).sha256_text(),
        "world_position":[pos.x,pos.y,pos.z],
        "world_yaw":actor.body.rotation.y,
        "world_pitch":actor.head_camera.rotation.x,
        "piloting":actor.piloting,
        "locale":ui.locale,
        "quality":ui.quality,
        "reduced_motion":ui.reduced_motion,
    }

func create_packet(ui: A7CascadeScreen) -> Dictionary:
    var content: String = JSON.stringify(_snapshot(ui))
    return {
        "schema":SCHEMA,
        "payload":content,
        "sha256":content.sha256_text(),
        "integrity_kind":"SHA256_CORRUPTION_ONLY_NOT_SECURITY",
        "fictional_offline_only":true,
    }

func write_packet(ui: A7CascadeScreen) -> bool:
    if replaying or events.size() > MAX_EVENTS or ui.stage_3d == null:
        return false
    var serialized: String = JSON.stringify(create_packet(ui))
    if serialized.length() > LIMIT_BYTES:
        last_status = "exceeds_64kb"
        return false
    var file: FileAccess = FileAccess.open(FILE_PATH,FileAccess.WRITE)
    if file == null:
        last_status = "file_access_failed"
        return false
    file.store_string(serialized)
    file.flush()
    file.close()
    saves += 1
    last_status = "saved"
    return true

func _verify_packet(raw: String) -> Dictionary:
    if raw.length() > LIMIT_BYTES or raw.length() < 60:
        return {}
    var outer: Variant = JSON.parse_string(raw)
    if not (outer is Dictionary):
        return {}
    var p: Dictionary = outer as Dictionary
    if str(p.get("schema","")) != SCHEMA or not (p.get("payload") is String):
        return {}
    var stored_payload: String = str(p["payload"])
    if str(p.get("sha256","")).length() != 64 or (
            stored_payload.sha256_text() != str(p["sha256"])):
        return {}
    var decoded: Variant = JSON.parse_string(stored_payload)
    if not (decoded is Dictionary):
        return {}
    var content: Dictionary = decoded
    if not (content.get("events") is Array) or (
            content["events"] as Array).size() > MAX_EVENTS:
        return {}
    if str(content.get("proof_sha256","")).length() != 64:
        return {}
    if not (content.get("world_position") is Array) or (
            content["world_position"] as Array).size() != 3:
        return {}
    var coords: Array = content["world_position"]
    for i in range(3):
        if not (coords[i] is float or coords[i] is int):
            return {}
        if is_inf(float(coords[i])) or is_nan(float(coords[i])):
            return {}
    # Physical world bounds (never read a loaded position outside facility).
    if absf(float(coords[0])) > 18.0 or (
            float(coords[1]) < -1.0 or float(coords[1]) > 8.0) or (
            float(coords[2]) < -8.0 or float(coords[2]) > 34.0):
        return {}
    if str(content.get("locale","")) not in ["ru","en"] or (
            str(content.get("quality","")) not in ["eco","hero"]):
        return {}
    for key in ["world_yaw","world_pitch"]:
        if not (content.get(key) is float or content.get(key) is int) or (
                not is_finite(float(content[key]))):
            return {}
    if absf(float(content["world_yaw"])) > 10000.0 or (
            absf(float(content["world_pitch"])) > 2.0):
        return {}
    if is_nan(float(content["world_yaw"])) or (
            is_nan(float(content["world_pitch"]))):
        return {}
        return {}
    if not (content.get("piloting") is bool) or (
            not (content.get("reduced_motion") is bool)):
        return {}
    for item in content["events"]:
        if not (item is Dictionary):
            return {}
        var e: Dictionary = item
        if not _valid_event(str(e.get("kind","")),e.get("value")) or (
                str(e.get("proof_sha256","")).length() != 64):
            return {}
    return content

func read_packet() -> Dictionary:
    if not FileAccess.file_exists(FILE_PATH):
        last_status = "absent"
        return {}
    var file: FileAccess = FileAccess.open(FILE_PATH,FileAccess.READ)
    if file == null:
        last_status = "unreadable"
        return {}
    if file.get_length() > LIMIT_BYTES:
        last_status = "oversized"
        file.close()
        return {}
    var raw: String = file.get_as_text()
    file.close()
    last_read_bytes = raw.length()
    var result: Dictionary = _verify_packet(raw)
    if result.is_empty():
        last_status = "corrupt_or_mismatched"
    return result

func _play_event(ui: A7CascadeScreen, e: Dictionary) -> bool:
    var kind: String = str(e["kind"])
    var value: Variant = e["value"]
    var player: A7FirstPersonOperator = ui.stage_3d.first_person
    var before: Dictionary = _proof(ui)
    # Every spatial / mechanical event is replayed at its ORIGINAL real
    # certified physical station, with the existing distance gate still
    # enforced by W71/W72. This is a restore, not new player progression.
    if kind in ["inspect","valve","sync"]:
        player.body.position = A7FieldOperations.CORE + Vector3(0,0.13,0) if (
            str(value) == "CORE" or kind != "inspect") else (
            A7FieldOperations.RELAY + Vector3(0,0.13,0))
    elif kind == "relay":
        player.body.position = A7FieldOperations.RELAY + Vector3(0,0.13,0)
    if kind == "start_normal":
        ui._start_spatial_mission()
    elif kind == "start_extended":
        ui._start_extended_mission()
    elif kind == "action":
        ui._on_action(str(value))
    elif kind == "inspect":
        ui._pilot_inspect()
    elif kind == "valve":
        ui._field_valve(int(value))
    elif kind == "relay":
        ui._field_relay(int(value))
    elif kind == "sync":
        ui._field_sync(int(value))
    else:
        return false
    var after: Dictionary = _proof(ui)
    return after != before and (
        JSON.stringify(after).sha256_text() == str(e["proof_sha256"]))

func _replay_to(ui: A7CascadeScreen, content: Dictionary) -> bool:
    var local_checkpoint: A7SessionCheckpoint = ui.checkpoint
    local_checkpoint.replaying = true
    ui._restart()
    var player: A7FirstPersonOperator = ui.stage_3d.first_person
    player.set_active(true)
    var ok: bool = true
    var checked_steps: int = 0
    for item in content["events"]:
        if not _play_event(ui,item):
            ok = false
            break
        checked_steps += 1
    if ok and (
            JSON.stringify(_proof(ui)).sha256_text() !=
            str(content["proof_sha256"])):
        ok = false
    if ok:
        var xyz: Array = content["world_position"]
        player.body.position = Vector3(float(xyz[0]),float(xyz[1]),float(xyz[2]))
        player.body.rotation.y = float(content["world_yaw"])
        player.head_camera.rotation.x = float(content["world_pitch"])
        player.set_active(bool(content["piloting"]))
        if not player.piloting:
            ui.stage_3d.set_camera(ui.stage_3d.camera_index)
        if ui.locale != str(content["locale"]):
            ui._toggle_locale()
        if ui.quality != str(content["quality"]):
            ui._toggle_quality()
        if ui.reduced_motion != bool(content["reduced_motion"]):
            ui._toggle_motion()
        ui._render(ui.model.snapshot())
    local_checkpoint.replaying = false
    last_replay_steps = checked_steps
    return ok

func restore_into(ui: A7CascadeScreen) -> bool:
    if replaying or ui == null or ui.stage_3d == null:
        return false
    var content: Dictionary = read_packet()
    if content.is_empty():
        rejected_loads += 1
        return false
    # Transactional preflight in a SEPARATE actual Godot scene; a corrupt or
    # fabricated journal cannot alter the currently playing session.
    var sandbox: A7CascadeScreen = A7CascadeScreen.new()
    sandbox.visible = false
    ui.get_tree().root.add_child(sandbox)
    var validated: bool = _replay_to(sandbox,content)
    sandbox.queue_free()
    if not validated:
        rejected_loads += 1
        last_status = "replay_mismatch_no_live_change"
        return false
    if not _replay_to(ui,content):
        rejected_loads += 1
        last_status = "live_replay_failed"
        ui._restart()
        return false
    events.clear()
    for e in content["events"]:
        events.append((e as Dictionary).duplicate(true))
    successful_restores += 1
    last_status = "loaded"
    return true

func qa_readout() -> Dictionary:
    return {
        "schema":SCHEMA,
        "relative_local_path":FILE_PATH,
        "event_count":events.size(),
        "saves":saves,
        "successful_restores":successful_restores,
        "rejected_loads":rejected_loads,
        "last_status":last_status,
        "latest_replay_steps":last_replay_steps,
        "last_read_bytes":last_read_bytes,
        "max_recorded_events":MAX_EVENTS,
        "max_file_bytes":LIMIT_BYTES,
        "checksum_is_tamper_protection":false,
        "transactional_sandbox_preflight":true,
        "online_server_storage":false,
        "real_industrial_hardware":false,
    }
