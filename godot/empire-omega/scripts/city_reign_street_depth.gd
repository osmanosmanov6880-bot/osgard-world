extends Node3D
## CITY REIGN B41 — source-native street-level architectural depth.
## Matrix Awakens is a VISUAL QUALITY TARGET, not an asset source.
## Instanced real-world geometry anchored only to existing colliding buildings.
## No new collision, GameState writes, imported copyrighted models or fake views.

const MAX_BUILDINGS: int = 128
const MAX_FLOORS: int = 13
const BATCH_COUNT: int = 4
const DISTRICT_STONE = {
	"forum": Color("b8b6ad"),
	"housing": Color("9cacae"),
	"lower": Color("9d968e"),
	"aqueduct": Color("90aeb0")
}
const DISTRICT_METAL = {
	"forum": Color("917f63"),
	"housing": Color("667e89"),
	"lower": Color("827467"),
	"aqueduct": Color("58868c")
}

var building_count: int = 0
var sill_poses: Array[Transform3D] = []
var sill_colors: Array[Color] = []
var pier_poses: Array[Transform3D] = []
var pier_colors: Array[Color] = []
var fin_poses: Array[Transform3D] = []
var fin_colors: Array[Color] = []
var reveal_poses: Array[Transform3D] = []
var reveal_colors: Array[Color] = []
var groups: Dictionary = {}
var quality: String = "standard"

func _ready() -> void:
	name = "CityReignStreetDepth"

static func _pose(center: Vector3, width: float, yaw: float,
		offset_x: float, y: float, offset_out: float, size: Vector3) -> Transform3D:
	var turn := Basis(Vector3.UP,yaw)
	var at := Vector3(center.x,0.0,center.z)
	at += turn*Vector3(offset_x,y,-(width*0.5+offset_out))
	return Transform3D(turn.scaled(size),at)

func record(center: Vector3,width: float,height: float,district: String,face: int,
		variation: int) -> void:
	if building_count>=MAX_BUILDINGS or not DISTRICT_STONE.has(district):
		return
	if not center.is_finite() or not is_finite(width) or not is_finite(height):
		return
	if width<9.5 or width>20.0 or height<9.0 or height>90.0:
		return
	if face<0 or face>3:
		return
	var yaw: float = float(face)*PI*0.5
	var stone: Color = DISTRICT_STONE[district]
	var metal: Color = DISTRICT_METAL[district]
	var floors: int = mini(MAX_FLOORS,maxi(1,int(height/4.5)))
	# Physically protruding per-window masonry sills sit BELOW the existing
	# real 1.38m window geometry, without drawing over the glass.
	for floor_index in range(1,floors):
		var window_y: float = 2.9+float(floor_index)*4.4
		if window_y>height-1.1:
			break
		for column in range(3):
			var x: float = float(column-1)*width*0.27
			sill_poses.append(_pose(center,width,yaw,x,window_y-0.94,0.20,
				Vector3(1.42,0.15,0.40)))
			sill_colors.append(stone.darkened(0.09 if variation%3==0 else 0.18))
		# Small genuine metal shade fins cast geometric depth along the upper
		# street facade, only every second level to avoid a repeated cage.
		if floor_index%2 == variation%2:
			for side in [-1.0,1.0]:
				fin_poses.append(_pose(center,width,yaw,
					float(side)*width*0.425,window_y,0.18,
					Vector3(0.11,1.92,0.37)))
				fin_colors.append(metal)
	# Narrow physically projecting lower pilasters frame the existing
	# storefront instead of placing new walls or blocking its glass door.
	for side in [-1.0,1.0]:
		pier_poses.append(_pose(center,width,yaw,
			float(side)*(width*0.5-0.42),2.13,0.14,
			Vector3(0.23,4.05,0.32)))
		pier_colors.append(stone)
	# One continuous, recessed shadow reveal above the REAL street sign.
	# Existing sign top is 3.92m and the older entrance band is at 4.33m.
	# Place the dark reveal between, not across the actual shopfront.
	reveal_poses.append(_pose(center,width,yaw,0.0,4.04,0.23,
		Vector3(width*0.71,0.10,0.18)))
	reveal_colors.append(metal.darkened(0.40))
	building_count+=1

func _batch(id: String,poses: Array[Transform3D],tints: Array[Color],
		roughness: float,metallic: float) -> void:
	assert(poses.size()==tints.size(),"Street depth geometry must match tints")
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cube
	mm.instance_count = poses.size()
	for i in range(poses.size()):
		mm.set_instance_transform(i,poses[i])
		mm.set_instance_color(i,tints[i])
	var visual := MultiMeshInstance3D.new()
	visual.name = id
	visual.multimesh = mm
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.custom_aabb = AABB(Vector3(-243.0,0.0,-243.0),Vector3(486.0,95.0,486.0))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = roughness
	mat.metallic = metallic
	visual.material_override = mat
	add_child(visual)
	groups[id]=visual

func finalize() -> void:
	assert(groups.is_empty(),"Street depth may only be finalized once")
	_batch("ArchitecturalWindowSills",sill_poses,sill_colors,0.78,0.06)
	_batch("StreetfrontStonePiers",pier_poses,pier_colors,0.76,0.05)
	_batch("FacadeSolarShadeFins",fin_poses,fin_colors,0.39,0.64)
	_batch("EntranceShadowReveals",reveal_poses,reveal_colors,0.57,0.30)
	set_quality(quality)

func set_quality(tier: String) -> void:
	quality = tier if ["low","standard","cinematic"].has(tier) else "standard"
	if groups.is_empty():
		return
	groups["ArchitecturalWindowSills"].visible = quality!="low"
	groups["StreetfrontStonePiers"].visible = quality!="low"
	groups["FacadeSolarShadeFins"].visible = quality=="cinematic"
	groups["EntranceShadowReveals"].visible = quality=="cinematic"

func instance_count() -> int:
	return sill_poses.size()+pier_poses.size()+fin_poses.size()+reveal_poses.size()

func geometry_is_bounded() -> bool:
	if building_count<1 or building_count>MAX_BUILDINGS:
		return false
	if groups.size()!=BATCH_COUNT or get_child_count()!=BATCH_COUNT:
		return false
	if pier_poses.size()!=building_count*2 or reveal_poses.size()!=building_count:
		return false
	if sill_poses.size()>building_count*(MAX_FLOORS-1)*3:
		return false
	if fin_poses.size()>building_count*MAX_FLOORS:
		return false
	for id in groups:
		var visual: MultiMeshInstance3D = groups[id]
		if visual.multimesh==null or visual.get_child_count()!=0:
			return false
		if visual.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
		if visual.material_override==null:
			return false
	return instance_count()<=MAX_BUILDINGS*(3*(MAX_FLOORS-1)+2+MAX_FLOORS+1)
