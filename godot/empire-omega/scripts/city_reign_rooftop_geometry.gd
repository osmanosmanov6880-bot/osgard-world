extends Node3D
## CITY REIGN: real instanced rooftop silhouettes for the existing R90 skyline.
## Geometric detail only; no claims of photogrammetry or licensed AAA assets.
## One MultiMesh draw group; deterministic and bounded across reloads.

const MAX_ROOFTOPS := 72
var roof_units: MultiMeshInstance3D
var quality := "standard"

func build_from_skyline(plan: Array[Transform3D]) -> void:
	if roof_units != null:
		remove_child(roof_units)
		roof_units.queue_free()
	var count: int = mini(plan.size(), MAX_ROOFTOPS)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("46515a")
	material.metallic = 0.32
	material.roughness = 0.77
	box.material = material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = box
	instances.instance_count = count
	for i in range(count):
		var tower: Transform3D = plan[i]
		var dimensions: Vector3 = tower.basis.get_scale()
		var center: Vector3 = tower.origin
		var roof_y: float = center.y + dimensions.y * 0.5
		var width: float = minf(dimensions.x * 0.32, 5.0)
		var depth: float = minf(dimensions.z * 0.29, 4.0)
		var elevation: float = 1.0 + float(i % 4) * 0.22
		var side: float = -0.21 if i % 2 == 0 else 0.21
		var position := Vector3(center.x + dimensions.x * side, roof_y + elevation * 0.5, center.z)
		var basis := Basis().scaled(Vector3(width, elevation, depth))
		instances.set_instance_transform(i, Transform3D(basis, position))
	roof_units = MultiMeshInstance3D.new()
	roof_units.name = "RealInstancedRooftopMechanicalHousings"
	roof_units.multimesh = instances
	roof_units.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	roof_units.custom_aabb = AABB(Vector3(-356, 0, -356), Vector3(712, 120, 712))
	add_child(roof_units)
	set_quality(quality)

func set_quality(tier: String) -> void:
	quality = tier if ["low", "standard", "cinematic"].has(tier) else "standard"
	if roof_units != null:
		roof_units.visible = quality != "low"

func graphics_are_bounded() -> bool:
	return roof_units != null and roof_units.multimesh != null and roof_units.multimesh.instance_count <= MAX_ROOFTOPS
