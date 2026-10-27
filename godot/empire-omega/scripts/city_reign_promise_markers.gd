extends Node3D
## CITY REIGN: two original, collision-free 3D proposal boards. They are
## open-world invitations only; actual spending happens exclusively in the
## original GameState.start_initiative transaction through the live HUD.
const PROMISE = preload("res://scripts/city_reign_first_promise.gd")
const LANDMARKS = preload("res://scripts/project_landmarks.gd")

var boards: Dictionary = {}
var current_locale: String = "ru"

func sync_state(state: Dictionary, lang: String) -> void:
	current_locale = lang if ["ru","en","zh"].has(lang) else "ru"
	var done: Array = state.get("projects_done",[])
	var active: Dictionary = state.get("projects_active",{})
	for id in PROMISE.CHOICES:
		var should_show: bool = not done.has(id) and not active.has(id)
		if not should_show:
			if boards.has(id):
				var obsolete: Node3D = boards[id]["root"]
				boards.erase(id)
				obsolete.queue_free()
			continue
		if not boards.has(id):
			boards[id] = _build(id)
		var label: Label3D = boards[id]["label"]
		var project: Dictionary = PROMISE.INITIATIVES.PROJECTS[id]
		var headline: String = "ПРОЕКТ ГОРОДА" if current_locale == "ru" else ("CITY PROPOSAL" if current_locale == "en" else "城市规划")
		var action: String = "РЕШЕНИЕ: TAB" if current_locale == "ru" else ("DECIDE: TAB" if current_locale == "en" else "决策: TAB")
		label.text = headline + "\n" + str(project.get(current_locale,project["ru"])) + "\n" + action

func _material(color: Color, illuminated: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.46
	mat.roughness = 0.36
	if illuminated:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.0
	return mat

func _beam(node: Node3D, id: String, size: Vector3, where: Vector3,
		color: Color, glow: bool = false) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = id
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = where
	mesh_node.material_override = _material(color,glow)
	node.add_child(mesh_node)

func _build(id: String) -> Dictionary:
	var post := Node3D.new()
	post.name = "Proposal_" + id
	post.position = LANDMARKS.POSITIONS[id]
	add_child(post)
	var frame: Color = Color("263c45")
	var gold: Color = Color("bb985c") if id == "open_records" else Color("5bbdb6")
	_beam(post,"ProposalBase",Vector3(4.0,0.28,2.4),Vector3(0,0.55,0),frame)
	for x in [-1.55,1.55]:
		_beam(post,"ProposalPost",Vector3(0.18,4.0,0.18),Vector3(x,2.6,0),gold)
	_beam(post,"ProposalFrame",Vector3(3.6,0.22,0.2),Vector3(0,4.54,0),gold)
	_beam(post,"ProposalPanel",Vector3(3.4,2.2,0.22),Vector3(0,3.3,0),frame)
	_beam(post,"ProposalLight",Vector3(2.7,0.15,0.25),Vector3(0,4.4,-0.17),gold,true)
	var sign := Label3D.new()
	sign.name = "ProposalLabel"
	sign.position = Vector3(0,5.7,0)
	sign.font_size = 45
	sign.pixel_size = 0.008
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.modulate = Color("f6e8cb")
	post.add_child(sign)
	return {"root":post,"label":sign}
