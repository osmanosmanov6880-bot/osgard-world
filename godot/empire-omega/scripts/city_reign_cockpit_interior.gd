extends Node3D
## R164: actual driver cockpit built from original 3D triangles.
## One dashboard, one real rotating steering wheel, one moving speed needle.
## THREE draw meshes; ZERO extra collision objects, dynamic lights, textures,
## physics rays, autoloads or money/state writes. All meshes built only once.
const RING_SEGMENTS: int = 24
const R169_MIX = preload("res://scripts/city_reign_acoustic_mix.gd")
var panel: MeshInstance3D
var steering_wheel: MeshInstance3D
var speed_needle: MeshInstance3D
var active: bool = false
var mesh_builds: int = 0
var last_speed: float = 0.0
var last_steering: float = 0.0
var last_brake_response: float = 0.0
var last_lateral_motion: float = 0.0
var last_reduced_motion: bool = false

static func _face(st: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,
        d: Vector3,tint: Color) -> void:
    st.set_color(tint)
    for point in [a,b,c,a,c,d]:
        st.add_vertex(point)

static func _block(st: SurfaceTool,centre: Vector3,half: Vector3,tint: Color) -> void:
    var lo: Vector3 = centre-half
    var hi: Vector3 = centre+half
    _face(st,Vector3(lo.x,lo.y,lo.z),Vector3(hi.x,lo.y,lo.z),
        Vector3(hi.x,hi.y,lo.z),Vector3(lo.x,hi.y,lo.z),tint)
    _face(st,Vector3(hi.x,lo.y,hi.z),Vector3(lo.x,lo.y,hi.z),
        Vector3(lo.x,hi.y,hi.z),Vector3(hi.x,hi.y,hi.z),tint)
    _face(st,Vector3(lo.x,lo.y,hi.z),Vector3(lo.x,lo.y,lo.z),
        Vector3(lo.x,hi.y,lo.z),Vector3(lo.x,hi.y,hi.z),tint)
    _face(st,Vector3(hi.x,lo.y,lo.z),Vector3(hi.x,lo.y,hi.z),
        Vector3(hi.x,hi.y,hi.z),Vector3(hi.x,hi.y,lo.z),tint)
    _face(st,Vector3(lo.x,hi.y,lo.z),Vector3(hi.x,hi.y,lo.z),
        Vector3(hi.x,hi.y,hi.z),Vector3(lo.x,hi.y,hi.z),tint)
    _face(st,Vector3(lo.x,lo.y,hi.z),Vector3(hi.x,lo.y,hi.z),
        Vector3(hi.x,lo.y,lo.z),Vector3(lo.x,lo.y,lo.z),tint)

static func _finish() -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.WHITE
    mat.vertex_color_use_as_albedo = true
    mat.metallic = 0.38
    mat.roughness = 0.42
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    return mat

func _mesh(id: String,st: SurfaceTool) -> MeshInstance3D:
    st.generate_normals()
    var visual := MeshInstance3D.new()
    visual.name = id
    visual.mesh = st.commit()
    visual.material_override = _finish()
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(visual)
    mesh_builds += 1
    return visual

func _ready() -> void:
    name = "CockpitInterior"
    var dash := SurfaceTool.new()
    dash.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Lower double-layer leather/metal instrument binnacle at real car scale.
    _block(dash,Vector3(0,0.095,-0.93),Vector3(1.035,0.125,0.215),Color("172329"))
    _block(dash,Vector3(0,0.228,-0.982),Vector3(0.998,0.023,0.163),Color("425158"))
    _block(dash,Vector3(-0.56,0.244,-0.912),Vector3(0.35,0.082,0.019),Color("0b151e"))
    _block(dash,Vector3(-0.56,0.248,-0.891),Vector3(0.28,0.052,0.008),Color("254955"))
    _block(dash,Vector3(0.42,0.239,-0.920),Vector3(0.34,0.064,0.012),Color("101d23"))
    # Three restrained metallic climate/center-console details are fused
    # into the SAME dashboard surface, no per-button objects or GPU draws.
    for index in range(3):
        _block(dash,Vector3(0.18+float(index)*0.23,0.242,-0.901),
            Vector3(0.071,0.017,0.009),Color("9ca9a8"))
    # Real analogue dial tick marks are authored into the EXISTING panel
    # surface rather than twenty separate draw calls or DOM overlays.
    for tick in range(11):
        var theta: float = -2.42+float(tick)*0.17
        var x: float = -0.68+cos(theta)*0.161
        var y: float = 0.245+sin(theta)*0.161
        _face(dash,Vector3(x-0.008,y-0.009,-0.866),
            Vector3(x+0.008,y-0.009,-0.866),
            Vector3(x+0.008,y+0.009,-0.866),
            Vector3(x-0.008,y+0.009,-0.866),Color("d8b77f"))
    panel = _mesh("PhysicalDashboard",dash)

    var ring := SurfaceTool.new()
    ring.begin(Mesh.PRIMITIVE_TRIANGLES)
    for index in range(RING_SEGMENTS):
        var theta_a: float = TAU*float(index)/float(RING_SEGMENTS)
        var theta_b: float = TAU*float(index+1)/float(RING_SEGMENTS)
        var outer_a := Vector3(cos(theta_a)*0.292,sin(theta_a)*0.292,0.0)
        var inner_a := Vector3(cos(theta_a)*0.241,sin(theta_a)*0.241,0.0)
        var outer_b := Vector3(cos(theta_b)*0.292,sin(theta_b)*0.292,0.0)
        var inner_b := Vector3(cos(theta_b)*0.241,sin(theta_b)*0.241,0.0)
        _face(ring,outer_a,outer_b,inner_b,inner_a,Color("111b21"))
    _block(ring,Vector3(0,0,0.0),Vector3(0.085,0.070,0.026),Color("77868c"))
    _block(ring,Vector3(0,0,0.015),Vector3(0.24,0.018,0.015),Color("33434a"))
    _block(ring,Vector3(0,-0.125,0.015),Vector3(0.020,0.14,0.013),Color("33434a"))
    steering_wheel = _mesh("SteeringWheel",ring)
    steering_wheel.position = Vector3(-0.57,0.245,-0.725)

    var needle := SurfaceTool.new()
    needle.begin(Mesh.PRIMITIVE_TRIANGLES)
    _face(needle,Vector3(-0.011,-0.01,0.0),Vector3(0.011,-0.01,0.0),
        Vector3(0.009,0.086,0.0),Vector3(-0.009,0.086,0.0),Color("e3a25b"))
    speed_needle = _mesh("ActualSpeedNeedle",needle)
    speed_needle.position = Vector3(-0.68,0.245,-0.868)
    visible = false

func set_active(value: bool,vehicle_shell: Node3D) -> void:
    if active==value:
        return
    active = value
    visible = value
    if vehicle_shell==null:
        return
    # The original opaque windshield/canopy otherwise obscures the road
    # from INSIDE the actual car. Restore every mesh on exterior views.
    for id in ["AerodynamicGreenhouse","SlopedWindshield",
            "LeftSideGlass","RightSideGlass"]:
        var part: Node3D = vehicle_shell.get_node_or_null(id) as Node3D
        if part!=null:
            part.visible = not value

func set_live_data(forward_speed: float,steering: float,braking: float = 0.0,
        lateral_motion: float = 0.0,reduced_motion: bool = false) -> void:
    if not active or not is_finite(forward_speed) or not is_finite(steering) or not is_finite(braking) or not is_finite(lateral_motion):
        return
    last_speed = forward_speed
    last_steering = clampf(steering,-1.0,1.0)
    last_brake_response = clampf(braking,0.0,1.0)
    last_lateral_motion = lateral_motion
    last_reduced_motion = reduced_motion
    # Physically situated wheel reacts to actual lateral motion and brake
    # pressure, without a new mesh, additional collision or camera shake.
    # Reduced-motion zeroes all newly introduced tilt and fore/aft motion.
    steering_wheel.rotation.x = R169_MIX.cockpit_slip(lateral_motion,reduced_motion)
    steering_wheel.position.z = -0.725-R169_MIX.cockpit_brake(braking,reduced_motion)
    steering_wheel.rotation.z = -last_steering*0.55
    speed_needle.rotation.z = -0.95+clampf(absf(forward_speed)/29.0,0.0,1.0)*1.90
    # Amber speed needle reacts to pedal effort and turns warmer on heavy
    # braking, without new material instances or meshes per frame.
    var needle_finish: StandardMaterial3D = speed_needle.material_override as StandardMaterial3D
    if needle_finish!=null:
        needle_finish.albedo_color = Color.WHITE.lerp(Color("ff9576"),last_brake_response*0.80)
