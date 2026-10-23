extends Node
## Additive autoload for the existing Godot Empire Omega city game.
## No changes to GameState.save_game() or its v4 save file.
signal dynasty_changed
const SAVE_FILE = "user://osman_world_dominion_dynasty_v1.json"
const MISSIONS = [
    {"id":"makhachkala_origin","title":"Начало в Махачкале","asset":"Организация","influence":5,"governance":1},
    {"id":"family_charter","title":"Хартия династии","asset":"Команда руководителей","influence":7,"governance":2},
    {"id":"caspian_estate","title":"Недвижимость Каспийска","asset":"Офис","influence":10,"governance":4},
    {"id":"first_venture","title":"Первая корпорация","asset":"Технологическая компания","influence":12,"governance":3},
    {"id":"ai_command","title":"Центр ИИ","asset":"Лаборатория ИИ","influence":16,"governance":5},
    {"id":"boardroom","title":"Совет директоров","asset":"Совет директоров","influence":11,"governance":8},
    {"id":"international_market","title":"Международный рынок","asset":"Экспортный офис","influence":21,"governance":7},
    {"id":"rival_corporation","title":"Соперничество корпораций","asset":"Альянс","influence":15,"governance":9},
    {"id":"global_influence","title":"Глобальная сеть","asset":"Сеть союзников","influence":25,"governance":12},
    {"id":"dynasty_ending","title":"Финал династии","asset":"Наследие","influence":30,"governance":10}
]
var dynasty = {"schema":1,"influence":0,"reputation":50,"governance":0,"completed":[],"assets":[],"decisions":{}}

func _ready() -> void:
    load_dynasty()

func next_mission() -> Dictionary:
    var n: int = dynasty["completed"].size()
    if n >= MISSIONS.size():
        return {}
    return MISSIONS[n].duplicate(true)

func complete_mission(mission_id: String, decision: String = "cooperate") -> bool:
    var mission: Dictionary = next_mission()
    if mission.is_empty() or mission["id"] != mission_id or not ["cooperate","compete","negotiate"].has(decision):
        return false
    var next_state: Dictionary = dynasty.duplicate(true)
    next_state["completed"].append(mission_id)
    next_state["assets"].append(mission["asset"])
    next_state["decisions"][mission_id] = decision
    next_state["influence"] += int(mission["influence"])
    next_state["governance"] += int(mission["governance"])
    next_state["reputation"] = clampi(int(next_state["reputation"]) + (2 if decision == "cooperate" else -3 if decision == "compete" else 1),0,100)
    if not _save_state(next_state):
        return false
    dynasty = next_state
    dynasty_changed.emit()
    return true

func ending() -> String:
    if dynasty["completed"].size() < MISSIONS.size():
        return "IN_PROGRESS"
    if int(dynasty["reputation"]) >= 65:
        return "DIPLOMATIC_TECHNOCRACY"
    if int(dynasty["reputation"]) < 40:
        return "COMPETITIVE_EMPIRE"
    return "BALANCED_DYNASTY"

func _valid(value: Variant) -> bool:
    if not value is Dictionary or value.get("schema") != 1:
        return false
    var completed: Variant = value.get("completed",null)
    if not completed is Array or completed.size() > MISSIONS.size():
        return false
    for i in range(completed.size()):
        if completed[i] != MISSIONS[i]["id"]:
            return false
    return value.get("assets") is Array and value.get("decisions") is Dictionary and int(value.get("influence",-1)) >= 0 and int(value.get("governance",-1)) >= 0 and int(value.get("reputation",-1)) >= 0 and int(value.get("reputation",101)) <= 100

func _save_state(value: Dictionary) -> bool:
    var file: FileAccess = FileAccess.open(SAVE_FILE + ".pending", FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(value))
    file.flush()
    file.close()
    var dir: DirAccess = DirAccess.open("user://")
    if dir == null:
        return false
    # Durable replacement separate from the legacy OSGARD save path.
    if dir.file_exists(SAVE_FILE.get_file()):
        if dir.copy(SAVE_FILE.get_file(),SAVE_FILE.get_file()+".backup") != OK:
            return false
        if dir.remove(SAVE_FILE.get_file()) != OK:
            return false
    return dir.rename(SAVE_FILE.get_file()+".pending",SAVE_FILE.get_file()) == OK

func load_dynasty() -> bool:
    if not FileAccess.file_exists(SAVE_FILE):
        return false
    var file: FileAccess = FileAccess.open(SAVE_FILE,FileAccess.READ)
    if file == null:
        return false
    var candidate: Variant = JSON.parse_string(file.get_as_text())
    if not _valid(candidate):
        return false
    dynasty = candidate
    dynasty_changed.emit()
    return true
