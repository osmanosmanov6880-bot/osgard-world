extends Node3D
## Twelve genuinely walkable procedural interiors: city hall, market, depot, power station.
## Geometry is kept independent from the exterior camera and economy model.

const INTERIORS = ["cityhall", "market", "depot", "power", "council", "clinic", "academy", "homes", "school", "gardens", "factory", "purifier"]
const PUBLIC_INTERIORS = ["cityhall", "market", "depot", "power"]
const CENTERS = {
	"cityhall":Vector3(700.0,0.0,-800.0),
	"market":Vector3(750.0,0.0,-800.0),
	"depot":Vector3(800.0,0.0,-800.0),
	"power":Vector3(850.0,0.0,-800.0),
	"council":Vector3(900.0,0.0,-800.0),"clinic":Vector3(950.0,0.0,-800.0),
	"academy":Vector3(1000.0,0.0,-800.0),"homes":Vector3(1050.0,0.0,-800.0),
	"school":Vector3(1100.0,0.0,-800.0),"gardens":Vector3(1150.0,0.0,-800.0),
	"factory":Vector3(1200.0,0.0,-800.0),"purifier":Vector3(1250.0,0.0,-800.0)
}
const PALETTE = {
	"cityhall":Color("756442"),"market":Color("315b54"),
	"depot":Color("495e70"),"power":Color("686047"),
	"council":Color("9a815b"),"clinic":Color("51796f"),
	"academy":Color("5e6587"),"homes":Color("856b65"),
	"school":Color("586c8a"),"gardens":Color("58784e"),
	"factory":Color("756b55"),"purifier":Color("557a87")
}
const LABELS = {
	"cityhall":{"ru":"Дворец правителя","en":"City Hall","zh":"市政厅"},
	"market":{"ru":"Торговая галерея","en":"Market Gallery","zh":"贸易中心"},
	"depot":{"ru":"Логистический терминал","en":"Logistics Depot","zh":"物流中心"},
	"power":{"ru":"Электростанция","en":"Power Station","zh":"发电站"},
	"council":{"ru":"Зал совета","en":"Council Chamber","zh":"议事厅"},
	"clinic":{"ru":"Клиника","en":"Clinic","zh":"诊所"},
	"academy":{"ru":"Академия","en":"Academy","zh":"学院"},
	"homes":{"ru":"Жилой дом","en":"Residence","zh":"住宅"},
	"school":{"ru":"Школа","en":"School","zh":"学校"},
	"gardens":{"ru":"Ботанический павильон","en":"Garden Pavilion","zh":"园艺馆"},
	"factory":{"ru":"Производственный цех","en":"Factory Workshop","zh":"车间"},
	"purifier":{"ru":"Центр очистки воды","en":"Water Treatment","zh":"净水厂"}
}

var active_kind := ""
var exit_return := Vector3.ZERO
var room_nodes := {}

func _ready() -> void:
	for id in INTERIORS:
		_create_room(id)

func _block(parent: Node3D, id: String, size: Vector3, at: Vector3, paint: Color, solid: bool = true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.name = id
	parent.add_child(body)
	body.position = at
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = paint
	material.metallic = 0.15
	material.roughness = 0.66
	visual.material_override = material
	body.add_child(visual)
	return body

func _create_room(id: String) -> void:
	var center: Vector3 = CENTERS[id]
	var room := Node3D.new()
	room.name = "Interior_" + id
	room.position = center
	add_child(room)
	room_nodes[id] = room
	var accent: Color = PALETTE[id]
	_block(room,"WalkableFloor",Vector3(23,1.0,25),Vector3(0,-0.55,0),Color("28303b"))
	_block(room,"BackWall",Vector3(23,9,0.65),Vector3(0,4.5,-12.5),accent.darkened(0.5))
	_block(room,"LeftWall",Vector3(0.65,9,25),Vector3(-11.5,4.5,0),accent.darkened(0.55))
	_block(room,"RightWall",Vector3(0.65,9,25),Vector3(11.5,4.5,0),accent.darkened(0.55))
	# Split front wall around the clearly visible exit.
	_block(room,"FrontLeft",Vector3(8.1,9,0.65),Vector3(-7.45,4.5,12.5),accent.darkened(0.55))
	_block(room,"FrontRight",Vector3(8.1,9,0.65),Vector3(7.45,4.5,12.5),accent.darkened(0.55))
	_block(room,"FrontLintel",Vector3(6.8,5.5,0.65),Vector3(0,6.25,12.5),accent.darkened(0.55))
	_block(room,"Walkway",Vector3(7,0.08,16),Vector3(0,0.015,3.0),accent.darkened(0.20),false)
	_block(room,"ExitMarker",Vector3(4.0,0.04,2.2),Vector3(0,0.085,10.0),Color("b7a46e"),false)
	for i in range(4):
		var offset: float = -7.5 + float(i) * 5.0
		_block(room,"Workstation_%d" % i,Vector3(3.8,1.2,2.5),Vector3(offset,0.65,-5.0),accent.lightened(0.18))
		_block(room,"Display_%d" % i,Vector3(1.8,1.1,0.12),Vector3(offset,1.65,-5.8),Color("8cadb2"),false)
	# Context-specific, collision-aware props make the rooms more than palette swaps.
	if id == "clinic":
		for slot in range(3):
			_block(room,"TreatmentBed",Vector3(2.5,0.8,4.2),Vector3(-7.0+float(slot)*6.0,0.7,3.0),Color("c5dbd5"))
	elif id == "factory" or id == "purifier" or id == "power":
		for slot in range(3):
			_block(room,"MachineBay",Vector3(3.2,3.0,4.5),Vector3(-7.5+float(slot)*7.0,1.8,3.0),accent.lightened(0.25))
			_block(room,"MachineMonitor",Vector3(1.3,0.9,0.15),Vector3(-7.5+float(slot)*7.0,2.4,0.65),Color("63c2c3"),false)
	elif id == "school" or id == "academy" or id == "council":
		for row in range(2):
			for column in range(3):
				_block(room,"ReadingDesk",Vector3(2.4,0.7,1.8),Vector3(-6.0+float(column)*6.0,0.75,1.0+float(row)*4.5),accent.lightened(0.2))
	elif id == "gardens":
		for slot in range(5):
			_block(room,"Planter",Vector3(2.1,0.8,2.1),Vector3(-8.0+float(slot)*4.0,0.7,3.0),Color("486a4e"))
			_block(room,"Plant",Vector3(1.0,2.2,1.0),Vector3(-8.0+float(slot)*4.0,2.0,3.0),Color("7aaf72"),false)
	elif id == "homes":
		_block(room,"DiningTable",Vector3(4,0.7,2.2),Vector3(0,0.8,3.0),Color("986d51"))
		_block(room,"Sofa",Vector3(5.0,1.25,1.8),Vector3(-3.0,0.85,7.0),Color("576b81"))
	var light := OmniLight3D.new()
	light.position = Vector3(0,7,0)
	light.omni_range = 27.0
	light.light_energy = 2.0
	light.light_color = accent.lightened(0.65)
	room.add_child(light)

func is_inside() -> bool:
	return active_kind != ""

func can_enter(id: String) -> bool:
	if not CENTERS.has(id):
		return false
	if id in PUBLIC_INTERIORS:
		return true
	if GameState.BUILDINGS.has(id):
		return int(GameState.data["buildings"].get(id,0)) > 0
	return true

func room_title(id: String, locale: String) -> String:
	return str(LABELS.get(id,{}).get(locale,id))

func enter(id: String, character: Node3D) -> bool:
	if not can_enter(id) or is_inside():
		return false
	exit_return = character.global_position
	active_kind = id
	character.global_position = CENTERS[id] + Vector3(0,1.6,6.0)
	return true

func leave(character: Node3D) -> bool:
	if not is_inside():
		return false
	active_kind = ""
	character.global_position = exit_return + Vector3(0,0.1,0)
	return true

func at_exit(position: Vector3) -> bool:
	if not is_inside():
		return false
	var door: Vector3 = CENTERS[active_kind] + Vector3(0,1.0,10.0)
	return position.distance_to(door) <= 5.0

func at_service_desk(position: Vector3) -> bool:
	if not is_inside():
		return false
	var desk: Vector3 = CENTERS[active_kind] + Vector3(0,1.0,-4.0)
	return position.distance_to(desk) <= 6.0
