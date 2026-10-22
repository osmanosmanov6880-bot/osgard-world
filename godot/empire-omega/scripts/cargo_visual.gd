extends Node3D
## Simple visible payload on the active car. This is a procedural prototype,
## intentionally independent from save format and physics/vehicle mass.
var crates: Array[MeshInstance3D] = []
var cargo_text: Label3D

func _ready() -> void:
	name = "CargoOnVehicle"
	for index in range(3):
		var crate := MeshInstance3D.new()
		crate.name = "CargoBox%d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.72,0.48,0.85)
		crate.mesh = mesh
		crate.position = Vector3(-0.75 + float(index)*0.75,1.17,0.38)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("5b795e")
		material.roughness = 0.75
		crate.material_override = material
		add_child(crate)
		crates.append(crate)
	var label := Label3D.new()
	label.name = "FreightCondition"
	label.position = Vector3(0.0,1.85,0.25)
	label.font_size = 34
	label.pixel_size = 0.005
	label.outline_size = 10
	label.modulate = Color("e9eddc")
	add_child(label)
	cargo_text = label
	visible = false

func sync_state(state: Dictionary, locale: String = "ru") -> void:
	var active: Dictionary = state.get("active_contract",{})
	visible = not active.is_empty()
	if not visible:
		return
	var progress: Dictionary = active.get("cargo_progress",{})
	var quality: int = clampi(roundi(float(progress.get("condition",100.0))),5,100)
	var color: Color = Color("498872").lerp(Color("ae534e"),1.0 - float(quality)/100.0)
	for crate in crates:
		var material: StandardMaterial3D = crate.material_override as StandardMaterial3D
		material.albedo_color = color
	cargo_text.text = ("ГРУЗ" if locale == "ru" else ("FREIGHT" if locale == "en" else "货物")) + "  %d%%" % quality
