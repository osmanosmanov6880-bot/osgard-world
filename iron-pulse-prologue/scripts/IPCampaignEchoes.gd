extends Node3D
class_name IPCampaignEchoes
## V11 — a diegetic, replayable three-chapter record in the real world.
## Every metal plate is an actual 3D MeshInstance3D; script updates only from
## verified completed engine victories, not simulated achievements.
const CHAPTERS: Array[String] = ["GRID","HEAT","AIR"]
const METAL := Color(0.18,0.24,0.29)
const DIM := Color(0.35,0.48,0.54)
const SUCCESS := Color(0.26,0.78,0.66)
const WARNING := Color(0.94,0.50,0.27)
var record_plate: Node3D
var panels: Array[Dictionary] = []
var _verified_completed: int = 0
var _campaign_active: bool = false
var _locale: String = "ru"
var _ending: String = ""
func _ready() -> void:
    name = "A7_CampaignMemoryWall"
    record_plate = Node3D.new()
    record_plate.name = "ThreeOperationPhysicalDebrief"
    # Inside the starter gallery, off the player path and away from reactor
    # sightlines. No x-ray or user-interface overlay.
    record_plate.position = Vector3(-5.85,2.55,-3.6)
    record_plate.rotation_degrees.y = 90.0
    add_child(record_plate)
    _box("MainMemoryWall",Vector3.ZERO,Vector3(2.40,3.40,0.27),METAL)
    var header := Label3D.new()
    header.name = "CampaignDossierHeader"
    header.text = "A7 / OPERATION RECORD"
    header.position = Vector3(0.0,1.35,0.20)
    header.font_size = 36
    header.pixel_size = 0.0023
    header.modulate = Color(0.82,0.92,0.95)
    record_plate.add_child(header)
    for i in range(CHAPTERS.size()):
        var y: float = 0.79-float(i)*0.88
        var panel: MeshInstance3D = _box("OperationStatus_%d" % i,Vector3(0,y,0.19),Vector3(2.0,0.67,0.06),DIM)
        var material := StandardMaterial3D.new()
        material.albedo_color = DIM
        material.roughness = 0.64
        material.metallic = 0.34
        material.emission_enabled = true
        material.emission = DIM
        material.emission_energy_multiplier = 0.20
        panel.material_override = material
        var label := Label3D.new()
        label.name = "OperationResult_%d" % i
        label.position = Vector3(0,y,0.26)
        label.font_size = 38
        label.pixel_size = 0.0024
        label.modulate = Color(0.94,0.97,0.99)
        record_plate.add_child(label)
        panels.append({"mesh":panel,"label":label,"material":material})
    var none: Array[Dictionary] = []
    set_campaign(0,none,"ru",false)

func _box(label: String,at: Vector3,size: Vector3,tint: Color) -> MeshInstance3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.metallic = 0.62
    material.roughness = 0.53
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = mesh
    node.position = at
    node.material_override = material
    record_plate.add_child(node)
    return node

func set_campaign(index: int,records: Array[Dictionary],locale: String,active: bool) -> void:
    _locale = "en" if locale == "en" else "ru"
    _campaign_active = active
    _verified_completed = mini(records.size(),3) if active else 0
    _ending = ""
    for i in range(panels.size()):
        var label: Label3D = panels[i]["label"]
        var material: StandardMaterial3D = panels[i]["material"]
        var status: String = "LOCKED" if _locale == "en" else "ЗАКРЫТО"
        var tint: Color = DIM
        if active and i < records.size():
            var entry: Dictionary = records[i]
            status = str(entry.get("grade",""))
            var priority: String = str(entry.get("priority",""))
            status += " / " + ("CREW" if priority == "crew" else "CORE" if priority == "core" else "—")
            tint = SUCCESS if float(entry.get("crew_health",0.0)) >= 50.0 else WARNING
        elif active and i == index:
            status = "ACTIVE" if _locale == "en" else "В ПРОЦЕССЕ"
            tint = WARNING
        label.text = "%02d   %s\n%s" % [i+1,CHAPTERS[i],status]
        material.albedo_color = tint
        material.emission = tint
        material.emission_energy_multiplier = 0.68 if active and i <= index else 0.18
    if active and records.size() == 3:
        _ending = "THREE MISSIONS COMPLETE"
    record_plate.visible = active

func sync(flow: IPCampaignFlow,locale: String) -> void:
    set_campaign(flow.index,flow.records,locale,flow.active)

func readout() -> Dictionary:
    var entries: Array[String] = []
    for panel in panels:
        entries.append((panel["label"] as Label3D).text)
    return {
        "physical_wall":record_plate != null and (record_plate.get_node_or_null("MainMemoryWall") is MeshInstance3D),
        "panel_count":panels.size(),
        "campaign_active":_campaign_active,
        "verified_victories":_verified_completed,
        "visible":record_plate.visible,
        "locale":_locale,
        "entries":entries,
        "ending":_ending
    }
