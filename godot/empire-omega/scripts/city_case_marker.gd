extends Node3D
## In-world holographic case beacon. No external models or shaders needed.
const CASES = preload("res://scripts/city_cases.gd")
const SITE_POSITIONS = {
	"cityhall":Vector3(-130.0,0.0,-130.0),
	"market":Vector3(130.0,0.0,-130.0),
	"depot":Vector3(-130.0,0.0,130.0),
	"power":Vector3(130.0,0.0,130.0)
}
var halo: MeshInstance3D
var inscription: Label3D
var pulse_time := 0.0

func _ready() -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("59dcd3")
	glow.emission_enabled = true
	glow.emission = Color("2ddacf")
	glow.emission_energy_multiplier = 3.3
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color.a = 0.85
	halo = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.4
	cylinder.bottom_radius = 1.4
	cylinder.height = 17.0
	halo.mesh = cylinder
	halo.material_override = glow
	add_child(halo)
	inscription = Label3D.new()
	inscription.position = Vector3(0.0,13.5,0.0)
	inscription.font_size = 52
	inscription.pixel_size = 0.011
	inscription.modulate = Color("bffcf4")
	inscription.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	inscription.no_depth_test = true
	add_child(inscription)
	var simulation: Variant = get_node_or_null('/root/GameState')
	if simulation != null: sync_state(simulation.data)

func sync_state(state: Dictionary) -> void:
	var case: Dictionary = CASES.current(state)
	var place: String = str(case.get("site", ""))
	visible = SITE_POSITIONS.has(place)
	set_process(visible)
	if not visible: return
	var at: Vector3 = SITE_POSITIONS[place]
	position = at + Vector3(0.0,36.0,0.0)
	var simulation: Variant = get_node_or_null('/root/GameState')
	var locale: String = str(simulation.locale) if simulation != null else "ru"
	inscription.text = str(case["title"].get(locale,case["title"]["ru"])) + "\n[C]"

func _process(delta: float) -> void:
	pulse_time += delta
	if halo != null:
		halo.scale.x = 1.0 + 0.07 * sin(pulse_time * 2.5)
		halo.scale.z = halo.scale.x
		halo.rotate_y(delta * 0.25)
