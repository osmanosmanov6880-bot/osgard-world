extends Node3D
## CITY REIGN A1: actual source-native architectural art for the ORIGINAL
## 3D building locations. Four GPU MultiMesh batches: no collision, scripts
## modifying currency, extra building lots, navigation blockers or fake art.
const MAX_BUILDINGS: int = 128
const BATCH_LIMIT: int = 4
const STONE = {
	"forum": Color("b4b7b1"),"housing": Color("87979c"),
	"lower": Color("858480"),"aqueduct": Color("91a5a7")
}
const METAL = {
	"forum": Color("a99a79"),"housing": Color("819ca6"),
	"lower": Color("ad9878"),"aqueduct": Color("6faaa9")
}
var building_count: int = 0
var roof: Array[Transform3D] = []
var roof_colors: Array[Color] = []
var entrance: Array[Transform3D] = []
var entrance_colors: Array[Color] = []
var jambs: Array[Transform3D] = []
var jamb_colors: Array[Color] = []
var plant: Array[Transform3D] = []
var plant_colors: Array[Color] = []
var groups: Dictionary = {}
var quality: String = "standard"
var accent_finish: StandardMaterial3D

func _ready() -> void:
	name = "CityReignCinematicArchitecture"

static func _pose(position: Vector3,size: Vector3,yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,yaw).scaled(size),position)

func record(center: Vector3,width: float,height: float,district: String,face: int) -> void:
	if building_count >= MAX_BUILDINGS or not STONE.has(district):
		return
	if not center.is_finite() or not is_finite(width) or not is_finite(height):
		return
	if width < 9.0 or width > 20.0 or height < 8.0 or height > 76.0:
		return
	if face < 0 or face > 3:
		return
	var stone: Color = STONE[district]
	var brass: Color = METAL[district]
	var y: float = center.y + height*0.5 + 0.43
	# Four solid rooftop parapets add actual depth to the real silhouette.
	for sign in [-1.0,1.0]:
		roof.append(_pose(Vector3(center.x,y,center.z+float(sign)*(width*0.5+0.05)),
			Vector3(width+0.65,0.56,0.36)))
		roof_colors.append(stone)
		roof.append(_pose(Vector3(center.x+float(sign)*(width*0.5+0.05),y,center.z),
			Vector3(0.36,0.56,width+0.65)))
		roof_colors.append(stone.darkened(0.10))
	var yaw: float = float(face)*PI*0.5
	var orientation := Basis(Vector3.UP,yaw)
	var origin := Vector3(center.x,0.0,center.z)
	# Keep actual original storefront windows/door/sign unobscured:
	# original shop-sign ends at 3.92m; reveal begins above 4.19m.
	var band: Vector3 = origin+orientation*Vector3(0.0,4.33,-width*0.5-0.42)
	entrance.append(_pose(band,Vector3(width*0.80,0.28,0.62),yaw))
	entrance_colors.append(brass)
	for side in [-1.0,1.0]:
		var edge: Vector3 = origin+orientation*Vector3(
			float(side)*(width*0.5-0.46),2.36,-width*0.5-0.20)
		jambs.append(_pose(edge,Vector3(0.11,4.25,0.19),yaw))
		jamb_colors.append(brass.lerp(stone,0.28))
	# Authored rooftop service body on every fourth real building.
	if building_count%4 == 0:
		plant.append(_pose(Vector3(center.x,y+1.18,center.z),
			Vector3(3.6,1.78,2.5)))
		plant_colors.append(Color("566775"))
	building_count += 1

func _batch(id: String,poses: Array[Transform3D],tints: Array[Color],
		roughness: float,metallic: float) -> void:
	assert(poses.size()==tints.size(),"One physical tint per facade instance")
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.mesh = cube
	mesh.instance_count = poses.size()
	for i in range(poses.size()):
		mesh.set_instance_transform(i,poses[i])
		mesh.set_instance_color(i,tints[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = id
	instance.multimesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.custom_aabb = AABB(Vector3(-243.0,0.0,-243.0),Vector3(486.0,81.0,486.0))
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color.WHITE
	material.roughness = roughness
	material.metallic = metallic
	instance.material_override = material
	add_child(instance)
	groups[id] = instance
	if id == "CinematicEntryBands": accent_finish = material

func finalize() -> void:
	assert(groups.is_empty(),"Facade art may be batched only once")
	assert(building_count <= MAX_BUILDINGS)
	assert(roof.size() == building_count*4)
	assert(entrance.size() == building_count)
	assert(jambs.size() == building_count*2)
	_batch("CinematicRoofCornices",roof,roof_colors,0.68,0.16)
	_batch("CinematicEntryBands",entrance,entrance_colors,0.38,0.43)
	_batch("CinematicVerticalJambs",jambs,jamb_colors,0.47,0.31)
	_batch("CinematicRooftopPlants",plant,plant_colors,0.55,0.27)
	set_quality(quality)

func set_quality(tier: String) -> void:
	quality = tier if ["low","standard","cinematic"].has(tier) else "standard"
	if groups.is_empty(): return
	groups["CinematicRoofCornices"].visible = quality != "low"
	groups["CinematicEntryBands"].visible = quality != "low"
	groups["CinematicVerticalJambs"].visible = quality == "cinematic"
	groups["CinematicRooftopPlants"].visible = quality == "cinematic"

func update_ambience(hour: float,power: int) -> void:
	if accent_finish == null: return
	var night: float = 0.0
	if is_finite(hour):
		var h: float = fposmod(hour,24.0)
		if h >= 19.5 or h < 5.5: night = 1.0
		elif h >= 17.5: night = clampf((h-17.5)/2.0,0.0,1.0)
		elif h < 7.0: night = clampf((7.0-h)/1.5,0.0,1.0)
	var intensity: float = night*clampf(float(power)/50.0,0.0,1.0)
	intensity *= 0.42 if quality=="cinematic" else (0.20 if quality=="standard" else 0.0)
	accent_finish.emission_enabled = intensity > 0.001
	accent_finish.emission = Color("bca77c")
	accent_finish.emission_energy_multiplier = intensity

func instance_count() -> int:
	return roof.size()+entrance.size()+jambs.size()+plant.size()

func graphics_are_bounded() -> bool:
	if groups.size() != BATCH_LIMIT or get_child_count() != BATCH_LIMIT:
		return false
	if building_count > MAX_BUILDINGS or instance_count() > MAX_BUILDINGS*8:
		return false
	for id in groups:
		var batch: MultiMeshInstance3D = groups[id]
		if batch.multimesh == null or batch.get_child_count() != 0:
			return false
		if batch.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
	return roof.size() == building_count*4 and entrance.size() == building_count
