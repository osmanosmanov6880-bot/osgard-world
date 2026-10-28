extends RefCounted
class_name IPCheckpointStore
## V6 — offline local checkpoint journal; no networks, accounts or telemetry.
## SHA-256 detects accidental corruption; it is NOT a cryptographic signature.
const FORMAT: String = "IRON_PULSE_OFFLINE_SAVE_V6"
const VERSION: int = 1
const DEFAULT_PATH: String = "user://iron_pulse_campaign_v6.json"
const MAX_BYTES: int = 150000

func _valid_path(path: String) -> bool:
    # Prevent traversing parent paths; never write into res:// or external storage.
    return path.begins_with("user://") and not path.contains("..") and not path.contains("\\") and path.length() <= 160

func save(payload: Dictionary, path: String = DEFAULT_PATH) -> bool:
    if not _valid_path(path):
        return false
    var encoded_payload: String = JSON.stringify(payload)
    if encoded_payload.length() < 10 or encoded_payload.length() > MAX_BYTES / 2:
        return false
    var wrapper: Dictionary = {
        "format":FORMAT,
        "version":VERSION,
        "payload_json":encoded_payload,
        "sha256":encoded_payload.sha256_text()
    }
    var serialized: String = JSON.stringify(wrapper)
    if serialized.length() > MAX_BYTES:
        return false
    var temporary: String = path + ".tmp"
    var file: FileAccess = FileAccess.open(temporary,FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(serialized)
    file.flush()
    file.close()
    # Atomic replacement: the old slot stays available until the entire new
    # record has reached the temp file.
    var tmp_absolute: String = ProjectSettings.globalize_path(temporary)
    var path_absolute: String = ProjectSettings.globalize_path(path)
    if DirAccess.rename_absolute(tmp_absolute,path_absolute) != OK:
        # Do not partially overwrite a valid checkpoint when rename fails.
        DirAccess.remove_absolute(tmp_absolute)
        return false
    return true

func load_checkpoint(path: String = DEFAULT_PATH) -> Dictionary:
    if not _valid_path(path) or not FileAccess.file_exists(path):
        return {}
    var file: FileAccess = FileAccess.open(path,FileAccess.READ)
    if file == null:
        return {}
    if file.get_length() > MAX_BYTES:
        file.close()
        return {}
    var raw: String = file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(raw)
    if not parsed is Dictionary:
        return {}
    var record: Dictionary = parsed as Dictionary
    if record.get("format") != FORMAT or record.get("version") != VERSION:
        return {}
    var payload_str: Variant = record.get("payload_json",null)
    var digest: Variant = record.get("sha256",null)
    if not payload_str is String or not digest is String:
        return {}
    if payload_str.length() > MAX_BYTES / 2 or payload_str.sha256_text() != digest:
        return {}
    var value: Variant = JSON.parse_string(payload_str)
    if not value is Dictionary:
        return {}
    return value as Dictionary

func clear(path: String = DEFAULT_PATH) -> bool:
    if not _valid_path(path):
        return false
    if not FileAccess.file_exists(path):
        return true
    return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
