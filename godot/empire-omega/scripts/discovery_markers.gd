extends Node3D
## Small emissive monuments: no extra physics bodies, no external art pipeline.
const DISCOVERY = preload("res://scripts/city_discovery.gd")
var monuments: Dictionary = {}

func _ready() -> void:
	for site in DISCOVERY.sites():
		var monument := Node3D.new()
		monument.name = "Secret_" + str(site["id"])
		monument.position = DISCOVERY.position(site)
		add_child(monument)
		var pedestal := MeshInstance3D.new()
		pedestal.name = "Pedestal"
		var base := CylinderMesh.new()
		base.top_radius = 0.85
		base.bottom_radius = 1.15
		base.height = 0.3
		pedestal.mesh = base
		pedestal.position.y = -0.55
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color("4b606c")
		metal.metallic = 0.7
		metal.roughness = 0.24
		pedestal.material_override = metal
		monument.add_child(pedestal)
		var crystal := MeshInstance3D.new()
		crystal.name = "MemoryCore"
		var prism := CylinderMesh.new()
		prism.top_radius = 0.16
		prism.bottom_radius = 0.42
		prism.height = 2.1
		crystal.mesh = prism
		crystal.position.y = 0.7
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("64ebc8")
		material.emission_enabled = true
		material.emission = Color("47c7bd")
		material.emission_energy_multiplier = 1.9
		crystal.material_override = material
		monument.add_child(crystal)
		monuments[str(site["id"])] = monument
	sync_state(GameState.data)

func sync_state(state: Dictionary) -> void:
	var completed: Array = state.get("discovered_sites",[])
	for id in monuments:
		var monument: Node3D = monuments[id]
		# Completed sites stay visible as dark monuments, not glowing objectives.
		var core: MeshInstance3D = monument.get_node("MemoryCore") as MeshInstance3D
		var material: StandardMaterial3D = core.material_override as StandardMaterial3D
		var done: bool = completed.has(id)
		material.emission_energy_multiplier = 0.0 if done else 1.9
		material.albedo_color = Color("425466") if done else Color("64ebc8")
