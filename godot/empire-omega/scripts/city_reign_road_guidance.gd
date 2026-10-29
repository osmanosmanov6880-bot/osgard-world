extends MeshInstance3D
## CITY REIGN R161 — genuine world-space road directions, not a HUD mock.
## Exactly one small non-colliding triangle surface. Draws ONLY provided
## GameState-authorized road graph paths, never guesses a mission destination.
## No per-frame allocations: rebuild only on the existing 1.25 s route refresh.
const ROAD_SPACING: float = 52.0
const ROAD_WIDTH_HALF: float = 5.0
const SURFACE_HEIGHT: float = 0.192
const DASH_LENGTH: float = 3.0
const DASH_PERIOD: float = 6.0
const HALF_WIDTH: float = 0.16
const VISIBLE_RADIUS: float = 185.0
const MAX_SEGMENT: float = 79.0
const MAX_DASHES: int = 112

var drawn_dashes: int = 0
var build_count: int = 0
var quality: String = "standard"

func _ready() -> void:
    name = "CityReignRoadGuidance"
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var paint := StandardMaterial3D.new()
    paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    paint.cull_mode = BaseMaterial3D.CULL_DISABLED
    material_override = paint
    set_quality("standard")
    clear_route()

func set_quality(tier: String) -> void:
    quality = tier if ["low","standard","cinematic"].has(tier) else "standard"
    var paint: StandardMaterial3D = material_override as StandardMaterial3D
    if paint != null:
        # Subdued metal-gold wayfinding; still one draw in LOW.
        paint.albedo_color = Color(0.85,0.71,0.45,0.54 if quality=="low" else 0.68)

static func _near_road_axis(value: float) -> bool:
    return is_finite(value) and absf(value-roundf(value/ROAD_SPACING)*ROAD_SPACING)<=ROAD_WIDTH_HALF

static func is_road_segment(a: Vector3,b: Vector3) -> bool:
    if not a.is_finite() or not b.is_finite():
        return false
    # Prevent the last router leg from painting through houses to a
    # destination located off the carriageway (City Hall, market, etc).
    var middle: Vector3 = (a+b)*0.5
    return (_near_road_axis(a.x) and _near_road_axis(b.x) and _near_road_axis(middle.x)) or (_near_road_axis(a.z) and _near_road_axis(b.z) and _near_road_axis(middle.z))

func clear_route() -> void:
    if mesh != null:
        mesh = null
    visible = false
    drawn_dashes = 0

func sync_route(path: Array[Vector3],focus: Vector3,allowed: bool,tier: String) -> void:
    set_quality(tier)
    if not allowed or not focus.is_finite() or path.size()<2:
        clear_route()
        return
    var limit: int = 60 if quality=="low" else (90 if quality=="standard" else MAX_DASHES)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var emitted: int = 0
    for index in range(path.size()-1):
        if emitted>=limit:
            break
        var a: Vector3 = path[index]
        var b: Vector3 = path[index+1]
        if not is_road_segment(a,b):
            continue
        var planar: Vector2 = Vector2(b.x-a.x,b.z-a.z)
        var metres: float = planar.length()
        if metres<0.75 or metres>MAX_SEGMENT:
            continue
        var midpoint: Vector2 = Vector2((a.x+b.x)*0.5,(a.z+b.z)*0.5)
        if midpoint.distance_to(Vector2(focus.x,focus.z))>VISIBLE_RADIUS:
            continue
        var ahead: Vector2 = planar/metres
        var across: Vector2 = Vector2(-ahead.y,ahead.x)*HALF_WIDTH
        var cursor: float = 0.0
        while cursor<metres and emitted<limit:
            var length: float = minf(DASH_LENGTH,metres-cursor)
            if length<0.5:
                break
            var p: Vector2 = Vector2(a.x,a.z)+ahead*cursor
            var q: Vector2 = p+ahead*length
            var one := Vector3(p.x-across.x,SURFACE_HEIGHT,p.y-across.y)
            var two := Vector3(p.x+across.x,SURFACE_HEIGHT,p.y+across.y)
            var three := Vector3(q.x+across.x,SURFACE_HEIGHT,q.y+across.y)
            var four := Vector3(q.x-across.x,SURFACE_HEIGHT,q.y-across.y)
            for v in [one,two,three,one,three,four]:
                st.add_vertex(v)
            emitted+=1
            cursor+=DASH_PERIOD
    if emitted==0:
        clear_route()
        return
    mesh = st.commit()
    drawn_dashes = emitted
    build_count+=1
    visible = true
