extends MultiMeshInstance3D
## HORIZON R25. Single-batch architectural cornices, geometry not billboards.
## R45 extends original R25 crowns with a true stepped, bevelled masonry mesh.
## One shared ArrayMesh and one MultiMesh draw batch for every four-beam roof.
## No shadows, no collisions and no new draw call for each building.
const LIMIT: int = 1024
const TRIANGLES_PER_BEAM: int = 52
const STONE_TINTS = [Color("b5b8b2"),Color("c4bbae"),Color("929fa6")]
var placements: Array[Transform3D] = []
var authored_tints: Array[Color] = []
var source_buildings: int = 0

func record(center: Vector3, width: float, building_height: float) -> void:
	if not center.is_finite() or not is_finite(width) or not is_finite(building_height):
		return
	if width<4.0 or building_height<4.0 or placements.size()+4>LIMIT:
		return
	var roof_y: float = center.y+building_height*0.5+0.13
	var half: float = width*0.5
	var trim: float = 0.36
	var h: float = 0.46
	# Distinct masonry tones are deterministic and require no new draw calls.
	var tint_index: int = posmod(int(floorf(center.x/17.0)+floorf(center.z/23.0)),STONE_TINTS.size())
	var stone_tint: Color = STONE_TINTS[tint_index]
	# Top and bottom edge strips on x faces; 4 solid cornice beams total.
	for side in [-1.0,1.0]:
		placements.append(Transform3D(Basis().scaled(Vector3(width+trim*2.0,h,trim)),
			Vector3(center.x,roof_y,center.z+side*(half+0.08))))
		authored_tints.append(stone_tint)
		placements.append(Transform3D(Basis().scaled(Vector3(trim,h,width+trim*2.0)),
			Vector3(center.x+side*(half+0.08),roof_y,center.z)))
		authored_tints.append(stone_tint)
	source_buildings+=1


# Modelled cross-section: a restrained two-step stone crown, not a neon strip.
# Its bevels are on all four sides so X and Z oriented beams share ONE mesh.
static func _section_vertex(y: float, extent: float, corner: int) -> Vector3:
	match corner:
		0: return Vector3(-extent,y,-extent)
		1: return Vector3(extent,y,-extent)
		2: return Vector3(extent,y,extent)
		_: return Vector3(-extent,y,extent)

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal: Vector3 = (b-a).cross(c-a).normalized()
	for vertex in [a,b,c]:
		st.set_normal(normal)
		st.add_vertex(vertex)

static func _cornice_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels := PackedFloat32Array([-0.50,-0.40,-0.31,-0.22,0.18,0.33,0.50])
	var extents := PackedFloat32Array([0.40,0.44,0.44,0.50,0.50,0.46,0.42])
	for band in range(levels.size()-1):
		for edge in range(4):
			var next_edge: int = (edge+1)%4
			var lower: Vector3 = _section_vertex(levels[band],extents[band],edge)
			var lower_next: Vector3 = _section_vertex(levels[band],extents[band],next_edge)
			var upper: Vector3 = _section_vertex(levels[band+1],extents[band+1],edge)
			var upper_next: Vector3 = _section_vertex(levels[band+1],extents[band+1],next_edge)
			_triangle(st,lower,upper,upper_next)
			_triangle(st,lower,upper_next,lower_next)
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for corner in range(4):
		bottom.append(_section_vertex(levels[0],extents[0],corner))
		top.append(_section_vertex(levels[levels.size()-1],extents[extents.size()-1],corner))
	_triangle(st,bottom[0],bottom[1],bottom[2])
	_triangle(st,bottom[0],bottom[2],bottom[3])
	_triangle(st,top[0],top[3],top[2])
	_triangle(st,top[0],top[2],top[1])
	return st.commit()

func geometry_triangle_budget() -> int:
	return placements.size()*TRIANGLES_PER_BEAM

func _ready() -> void:
	name="ArchitecturalCorniceBatch"

func finalize() -> void:
	assert(placements.size()==authored_tints.size(),"R45 shared crown instance tints must match authored roof geometry")
	assert(geometry_triangle_budget()<=LIMIT*TRIANGLES_PER_BEAM,"R45 bounded skyline triangle budget exceeded")
	var crown: ArrayMesh = _cornice_mesh()
	var grid:=MultiMesh.new()
	grid.transform_format=MultiMesh.TRANSFORM_3D
	grid.use_colors=true
	grid.mesh=crown
	grid.instance_count=placements.size()
	for i in range(placements.size()):
		grid.set_instance_transform(i,placements[i])
		grid.set_instance_color(i,authored_tints[i])
	multimesh=grid
	var paint:=StandardMaterial3D.new()
	paint.albedo_color=Color.WHITE
	paint.vertex_color_use_as_albedo=true
	paint.roughness=0.78
	paint.metallic=0.025
	material_override=paint
	cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# For the fixed 460m-wide city. Avoid per-chunk mesh allocations.
	custom_aabb=AABB(Vector3(-240.0,-4.0,-240.0),Vector3(480.0,80.0,480.0))
