extends Node3D
## CITY REIGN - the actual stored city crisis produces a visible 3D emergency
## landmark. This is environmental feedback, NOT another quest/currency.
## One local worksite at a time, no collision shapes/particles/physics changes.
const INCIDENTS = {
	"drought":{"place":Vector3(134.0,0.0,118.0),
		"ru":"КРИЗИС ВОДЫ","en":"WATER CRISIS","zh":"水资源危机","color":Color("4fa8c8")},
	"strike":{"place":Vector3(-133.0,0.0,118.0),
		"ru":"ЗАБАСТОВКА","en":"LABOR STRIKE","zh":"劳工罢工","color":Color("d39c58")},
	"blackout":{"place":Vector3(131.0,0.0,120.0),
		"ru":"ОТКЛЮЧЕНИЕ ЭНЕРГИИ","en":"POWER OUTAGE","zh":"能源中断","color":Color("f2b45e")},
	"fire":{"place":Vector3(-120.0,0.0,143.0),
		"ru":"ПОЖАРНАЯ ТРЕВОГА","en":"FIRE EMERGENCY","zh":"火灾警报","color":Color("df715c")},
	"epidemic":{"place":Vector3(-125.0,0.0,-116.0),
		"ru":"МЕДИЦИНСКАЯ ТРЕВОГА","en":"HEALTH EMERGENCY","zh":"医疗紧急情况","color":Color("e3a67c")}
}

var current_id: String = ""
var current_visual: Node3D
var sign: Label3D

func sync_state(state: Dictionary, language: String) -> void:
	var next_id: String = str(state.get("incident",""))
	if not INCIDENTS.has(next_id):
		_clear()
		return
	if next_id != current_id or current_visual == null:
		_clear()
		_build(next_id)
	var lang: String = language if ["ru","en","zh"].has(language) else "ru"
	if sign != null:
		sign.text = str(INCIDENTS[next_id][lang])

func _clear() -> void:
	if current_visual != null and is_instance_valid(current_visual):
		current_visual.queue_free()
	current_visual = null
	sign = null
	current_id = ""

func _box(parent: Node3D, tag: String, shape: Vector3, at: Vector3,
		color: Color, glow: bool = false) -> void:
	var item := MeshInstance3D.new()
	item.name = tag
	var m := BoxMesh.new()
	m.size = shape
	item.mesh = m
	item.position = at
	item.material_override = _material(color,glow)
	parent.add_child(item)

func _material(color: Color, glow: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.42
	m.roughness = 0.42
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.1
	return m

func _build(id: String) -> void:
	var info: Dictionary = INCIDENTS[id]
	current_id = id
	current_visual = Node3D.new()
	current_visual.name = "Crisis_" + id
	current_visual.position = info["place"]
	add_child(current_visual)
	var charcoal := Color("253943")
	var brass := Color("b79c6e")
	var alert: Color = info["color"]
	_box(current_visual,"AlertFoundation",Vector3(5.2,0.45,4.2),Vector3(0,0.4,0),charcoal)
	for x in [-2.0,2.0]:
		_box(current_visual,"SafetyPost",Vector3(0.24,4.3,0.24),Vector3(x,2.6,0),brass)
		_box(current_visual,"WarningLantern",Vector3(0.85,0.6,0.85),Vector3(x,4.8,0),alert,true)
	_box(current_visual,"AlertPanel",Vector3(4.2,2.4,0.25),Vector3(0,3.0,0),alert)
	_box(current_visual,"EmergencyStripe",Vector3(5.3,0.25,0.3),Vector3(0,1.0,-2.0),brass)
	# Unique situation-shaped noninteractive source geometry.
	match id:
		"drought":
			_box(current_visual,"WaterGaugingStation",Vector3(2.4,1.2,1.5),Vector3(0,1.5,1.5),charcoal)
		"strike":
			_box(current_visual,"WorkStoppageBarrier",Vector3(4.4,0.9,0.4),Vector3(0,1.4,1.5),brass)
		"blackout":
			_box(current_visual,"EmergencyTransformer",Vector3(2.8,2.0,1.7),Vector3(0,1.8,1.5),charcoal)
		"fire":
			_box(current_visual,"FireResponseBarrier",Vector3(4.0,1.0,0.3),Vector3(0,1.5,1.4),alert)
		"epidemic":
			_box(current_visual,"EmergencyMedicalUnit",Vector3(3.5,2.1,1.5),Vector3(0,1.8,1.5),Color("a6b3b1"))
	sign = Label3D.new()
	sign.name = "EmergencyLabel"
	sign.position = Vector3(0,6.1,0)
	sign.font_size = 46
	sign.pixel_size = 0.009
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("f4dfb6")
	current_visual.add_child(sign)
