extends Node3D
## CITY REIGN AAA A14: original physical automotive studio architecture,
## not an imported PNG, copyrighted showroom design or secondary physics.
## Three GPU-backed source nodes: metal inlaid turntable dial, real wall,
## and seven original 3D louvres in a single native GPU MultiMesh batch.
const RING_SEGMENTS: int = 72
const TICKS: int = 12
const FIN_COUNT: int = 7
const MAX_MARKING_VERTICES: int = (RING_SEGMENTS+TICKS)*6
var ring: MeshInstance3D
var backwall: MeshInstance3D
var fins: MultiMeshInstance3D
var gold_material: StandardMaterial3D
var back_material: StandardMaterial3D
var night: bool = false
var mobile: bool = false

static func _face(st: SurfaceTool,a: Vector3,b: Vector3,
		c: Vector3,d: Vector3,tint: Color) -> void:
	st.set_color(tint)
	for vertex in [a,b,c,a,c,d]:
		st.add_vertex(vertex)

static func _tick(angle: float,radius_a: float,radius_b: float,
		width: float,y: float) -> Array:
	var left: float = angle-width*0.5
	var right: float = angle+width*0.5
	return [
		Vector3(cos(left)*radius_a,y,sin(left)*radius_a),
		Vector3(cos(right)*radius_a,y,sin(right)*radius_a),
		Vector3(cos(right)*radius_b,y,sin(right)*radius_b),
		Vector3(cos(left)*radius_b,y,sin(left)*radius_b)
	]

func _ready() -> void:
	name = "CityReignArchitectedStudio"
	_build_machined_dial()
	_build_real_panels()
	_build_rear_louvres()
	set_compact(mobile)

func _build_machined_dial() -> void:
	# This original physical radial dial is 7 mm above the REAL existing
	# platform top: no z-fighting, no shader trick and no new draw per tick.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y: float = -0.832
	for index in range(RING_SEGMENTS):
		var a: float = float(index)*TAU/float(RING_SEGMENTS)
		var b: float = float(index+1)*TAU/float(RING_SEGMENTS)
		var color: Color = Color("c0a476") if index%9==0 else Color("5e625e")
		_face(st,
			Vector3(cos(a)*3.28,y,sin(a)*3.28),
			Vector3(cos(b)*3.28,y,sin(b)*3.28),
			Vector3(cos(b)*3.43,y,sin(b)*3.43),
			Vector3(cos(a)*3.43,y,sin(a)*3.43),color)
	for index in range(TICKS):
		var marker: Array = _tick(float(index)*TAU/float(TICKS),
			3.09,3.25,0.018,y+0.002)
		_face(st,marker[0],marker[1],marker[2],marker[3],
			Color("d6bc8d"))
	st.generate_normals()
	ring = MeshInstance3D.new()
	ring.name = "OriginalMachinedAnnulus72"
	ring.mesh = st.commit()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gold_material = StandardMaterial3D.new()
	gold_material.albedo_color = Color.WHITE
	gold_material.vertex_color_use_as_albedo = true
	gold_material.metallic = 0.64
	gold_material.roughness = 0.33
	gold_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	gold_material.emission_enabled = true
	gold_material.emission = Color("b69a73")
	gold_material.emission_energy_multiplier = 0.11
	ring.material_override = gold_material
	add_child(ring)

func _build_real_panels() -> void:
	backwall = MeshInstance3D.new()
	backwall.name = "OriginalArchitecturalSlab"
	var wall := BoxMesh.new()
	wall.size = Vector3(9.25,3.40,0.08)
	backwall.mesh = wall
	backwall.position = Vector3(0,0.40,4.30)
	backwall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	back_material = StandardMaterial3D.new()
	back_material.albedo_color = Color("131e29")
	back_material.metallic = 0.28
	back_material.roughness = 0.71
	backwall.material_override = back_material
	add_child(backwall)

func _build_rear_louvres() -> void:
	# All seven metal fins share ONE original 3D Mesh and ONE GPU batch.
	fins = MultiMeshInstance3D.new()
	fins.name = "OriginalStudioLouvresGPU"
	var fin := BoxMesh.new()
	fin.size = Vector3(0.068,2.65,0.085)
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color("827763")
	finish.metallic = 0.84
	finish.roughness = 0.39
	fin.material = finish
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = fin
	batch.instance_count = FIN_COUNT
	for index in range(FIN_COUNT):
		var x: float = (float(index)-float(FIN_COUNT-1)*0.5)*1.14
		batch.set_instance_transform(index,
			Transform3D(Basis.IDENTITY,Vector3(x,0.44,4.22)))
	fins.multimesh = batch
	fins.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fins)

func set_compact(value: bool) -> void:
	mobile = value
	# A tiny phone GPU skips the background and seven source metal fins.
	if backwall != null: backwall.visible = not mobile
	if fins != null: fins.visible = not mobile

func set_night(value: bool) -> void:
	night = value
	if gold_material != null:
		gold_material.emission_energy_multiplier = 0.78 if night else 0.11
	if back_material != null:
		back_material.albedo_color = Color("0d1721") if night else Color("131e29")

func geometry_is_bounded() -> bool:
	if get_child_count()!=3 or ring==null or backwall==null or fins==null:
		return false
	if ring.mesh==null or ring.mesh.get_surface_count()!=1:
		return false
	if ring.mesh.surface_get_array_len(0)!=MAX_MARKING_VERTICES:
		return false
	if fins.multimesh==null or fins.multimesh.instance_count!=FIN_COUNT:
		return false
	if not find_children("*","CollisionShape3D",true,false).is_empty():
		return false
	return ring.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and
		fins.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and
		backwall.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
