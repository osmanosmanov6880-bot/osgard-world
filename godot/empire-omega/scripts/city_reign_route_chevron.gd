extends MeshInstance3D
## R163: one native 3D road-painted arrow anchored at an AUTHENTIC routed
## intersection, not a waypoint on or through a building. One 9-vertex
## triangle surface, no collider, no ticking, no runtime texture downloads.
const NAV = preload("res://scripts/city_reign_drive_navigation.gd")
const ROAD = preload("res://scripts/city_reign_road_guidance.gd")
const MAX_VISIBLE_TURN_METRES: float = 70.0
const ROAD_Y: float = 0.202
var active: bool = false
var quality: String = "standard"
var mesh_builds: int = 0

func _ready() -> void:
    name = "CityReignRouteChevron"
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    material_override = mat
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Local -Z points forward; wide arrowhead and short body together use
    # only three triangles and never intersect existing road collision.
    for point in [
        Vector3(0,0,-2.25),Vector3(-1.12,0,0.15),Vector3(1.12,0,0.15),
        Vector3(-0.32,0,0.12),Vector3(0.32,0,0.12),Vector3(0.32,0,1.72),
        Vector3(-0.32,0,0.12),Vector3(0.32,0,1.72),Vector3(-0.32,0,1.72)
    ]:
        st.add_vertex(point)
    mesh = st.commit()
    mesh_builds+=1
    set_quality("standard")
    clear_turn()

func set_quality(tier: String) -> void:
    quality = tier if ["low","standard","cinematic"].has(tier) else "standard"
    var material: StandardMaterial3D = material_override as StandardMaterial3D
    if material!=null:
        material.albedo_color = Color(0.97,0.82,0.49,0.55 if quality=="low" else 0.80)

func clear_turn() -> void:
    active = false
    visible = false

func show_from_route(path: Array[Vector3],at: Vector3,tier: String,allowed: bool) -> void:
    set_quality(tier)
    if not allowed:
        clear_turn()
        return
    var state: Dictionary = NAV.snapshot(path,at)
    if not ["left","right","uturn"].has(str(state.get("kind",""))):
        clear_turn()
        return
    if float(state.get("turn_m",INF))>MAX_VISIBLE_TURN_METRES:
        clear_turn()
        return
    var corner: Vector3 = state.get("turn_world",Vector3.INF)
    var forward: Vector3 = state.get("turn_out",Vector3.ZERO)
    if not corner.is_finite() or not forward.is_finite() or forward.length_squared()<0.25:
        clear_turn()
        return
    forward.y = 0.0
    forward = forward.normalized()
    var position_after_turn: Vector3 = corner+forward*5.0
    if not ROAD.is_road_segment(corner,position_after_turn):
        clear_turn()
        return
    global_position = Vector3(position_after_turn.x,ROAD_Y,position_after_turn.z)
    rotation.y = atan2(-forward.x,-forward.z)
    active = true
    visible = true
