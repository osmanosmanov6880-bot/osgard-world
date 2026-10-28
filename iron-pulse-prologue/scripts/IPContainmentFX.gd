extends Node3D
class_name IPContainmentFX
## IRON PULSE V8.6: original, fully local environmental event direction.
## Three actual industrial pressure purge stations and one GPU-instanced
## thermal-shock burst are driven by existing IPCrisisEngine gameplay state.
## No remote art, no new mechanics, no changes to saved player resources.
const VENT_Z: Array[float] = [-13.0,-20.5,-28.0]
const SPARK_COUNT: int = 16
const METAL := Color(0.18,0.23,0.27)
const TRIM := Color(0.43,0.51,0.55)
const COOL := Color(0.12,0.78,0.93)
const THERMAL := Color(1.0,0.40,0.16)

var vents: Array[Dictionary] = []
var spark_cluster: MultiMeshInstance3D
var _spark_meshes: MultiMesh
var _mist_material: StandardMaterial3D
var _vent_indicator: StandardMaterial3D
var _quality: String = "hero"
var _risk: float = 0.0
var _valve_angle: float = 0.0
var _active_vapor: bool = false
var _last_surge_count: int = 0
var _burst_started_at: float = -10000.0
var _burst_visible: bool = false
var _reduced_motion: bool = false
var _last_scenario: String = "blackout"
var _last_spark_origin: Vector3 = Vector3(13.0,7.0,-20.5)

func _ready() -> void:
    name = "A7_ReactivePressureRelief"
    _create_original_materials()
    for index in range(VENT_Z.size()):
        _create_industrial_vent(index,VENT_Z[index])
    _create_instanced_sparks()
    set_quality("hero")

func _steel(tint: Color,metal: float = 0.75,rough: float = 0.50) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tint
    m.metallic = metal
    m.roughness = rough
    return m

func _emissive(tint: Color,strength: float) -> StandardMaterial3D:
    var m := _steel(tint,0.06,0.37)
    m.emission_enabled = true
    m.emission = tint
    m.emission_energy_multiplier = strength
    return m

func _create_original_materials() -> void:
    _mist_material = _steel(Color(0.75,0.85,0.90,0.18),0.0,0.96)
    _mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _vent_indicator = _emissive(COOL,0.35)

func _box(parent: Node3D,label: String,location: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var part := MeshInstance3D.new()
    part.name = label
    part.mesh = mesh
    part.position = location
    part.material_override = mat
    parent.add_child(part)
    return part

func _cylinder(parent: Node3D,label: String,location: Vector3,radius: float,height: float,mat: Material) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 16
    var part := MeshInstance3D.new()
    part.name = label
    part.mesh = mesh
    part.position = location
    part.material_override = mat
    parent.add_child(part)
    return part

func _create_industrial_vent(index: int,z: float) -> void:
    # Place *behind* the real core against the distant chamber wall, so steam
    # adds depth without hiding the centered plasma or player route.
    var station := Node3D.new()
    station.name = "ContainmentPressureVent_%d" % index
    station.position = Vector3(17.45,5.15,z)
    add_child(station)
    var steel := _steel(METAL)
    var milled := _steel(TRIM,0.84,0.37)
    _box(station,"PermanentPressureBulkhead",Vector3(0,-0.92,0),Vector3(0.28,3.9,2.65),steel)
    _cylinder(station,"HighPressureMainPipe",Vector3(-0.34,-0.57,0),0.40,3.75,milled)
    _cylinder(station,"TurbineReliefNozzle",Vector3(-0.62,1.38,0),0.58,0.40,steel)
    for clamp_index in range(3):
        _box(station,"MachinedPipeClamp_%d" % clamp_index,
            Vector3(-0.35,-1.90+float(clamp_index)*1.25,0.0),
            Vector3(0.70,0.14,0.90),milled)
    # The vent moves in the actual industrial scene: the valve rotates open
    # in response to risk; it is not a screen-space status bar.
    var shutter := Node3D.new()
    shutter.name = "AnimatedReliefShutter"
    shutter.position = Vector3(-0.85,1.73,0)
    station.add_child(shutter)
    for blade_index in range(3):
        _box(shutter,"VentBlade_%d" % blade_index,
            Vector3(0,float(blade_index)*0.22-0.21,0),
            Vector3(0.12,0.13,0.95),milled)
    _box(station,"RealPressureWarningLamp",Vector3(-0.61,2.05,0),
        Vector3(0.13,0.17,1.25),_vent_indicator)
    var designation := Label3D.new()
    designation.name = "PurgeStationDesignation"
    designation.text = "PURGE 0%d  /  A7" % (index+1)
    designation.font_size = 32
    designation.pixel_size = 0.0021
    designation.position = Vector3(-0.83,-1.88,0.8)
    designation.rotation_degrees.y = -90.0
    designation.modulate = Color(0.78,0.87,0.90)
    station.add_child(designation)
    var vapor := Node3D.new()
    vapor.name = "HeatDrivenSteam_OriginalGeometry"
    vapor.position = Vector3(-0.88,2.03,0)
    station.add_child(vapor)
    var puffs: Array[MeshInstance3D] = []
    for puff_index in range(6):
        var mesh := SphereMesh.new()
        mesh.radius = 0.23
        mesh.height = 0.46
        mesh.radial_segments = 8
        mesh.rings = 4
        var puff := MeshInstance3D.new()
        puff.name = "TranslucentSteamPuff_%02d" % puff_index
        puff.mesh = mesh
        puff.material_override = _mist_material
        vapor.add_child(puff)
        puffs.append(puff)
    vapor.visible = false
    vents.append({
        "unit":station,"shutter":shutter,"vapor":vapor,
        "puffs":puffs,"designation":designation
    })

func _create_instanced_sparks() -> void:
    var tiny := BoxMesh.new()
    tiny.size = Vector3(0.045,0.28,0.045)
    _spark_meshes = MultiMesh.new()
    _spark_meshes.transform_format = MultiMesh.TRANSFORM_3D
    _spark_meshes.mesh = tiny
    _spark_meshes.instance_count = SPARK_COUNT
    for index in range(SPARK_COUNT):
        _spark_meshes.set_instance_transform(index,Transform3D(Basis(),Vector3(13.0,7.0,-20.5)))
    spark_cluster = MultiMeshInstance3D.new()
    spark_cluster.name = "OneDrawCall_ThermalSurgeSparks"
    spark_cluster.multimesh = _spark_meshes
    spark_cluster.material_override = _emissive(Color(1.0,0.47,0.16),1.35)
    spark_cluster.visible = false
    add_child(spark_cluster)

func set_quality(value: String) -> void:
    _quality = "eco" if value == "eco" else "hero"
    _update_visibility()

func _update_visibility() -> void:
    _active_vapor = _quality == "hero" and _risk >= 0.32 and not _reduced_motion
    for station in vents:
        var mist: Node3D = station["vapor"]
        mist.visible = _active_vapor
    if spark_cluster != null:
        spark_cluster.visible = _quality == "hero" and _burst_visible and not _reduced_motion

func update_from_crisis(
        scenario: String,heat: float,oxygen: float,elapsed: float,
        reduced_motion: bool,surges: int,thermal_shield: bool = false,active: bool = true
    ) -> void:
    # All source values come from IPCrisisEngine; VFX NEVER change gameplay.
    if not active:
        return
    _reduced_motion = reduced_motion
    _last_scenario = scenario
    var heat_risk: float = clampf((heat-61.0)/39.0,0.0,1.0)
    var life_risk: float = clampf((58.0-oxygen)/58.0,0.0,1.0)
    _risk = maxf(heat_risk,life_risk)
    # Completing the actual QUENCH rescue relay visually dampens exhaust.
    var effect_risk: float = _risk*(0.72 if thermal_shield else 1.0)
    _valve_angle = 6.0 + 64.0*effect_risk
    var warning_color: Color = THERMAL if scenario == "thermal" else COOL if scenario == "breach" else Color(0.95,0.69,0.28)
    _vent_indicator.emission = warning_color
    _vent_indicator.albedo_color = warning_color
    _vent_indicator.emission_energy_multiplier = 0.38 + 1.15*effect_risk
    _mist_material.albedo_color = Color(0.95,0.73,0.61,0.15) if scenario == "thermal" else Color(0.75,0.87,0.94,0.16)
    for vent_index in range(vents.size()):
        var module: Dictionary = vents[vent_index]
        var shutter: Node3D = module["shutter"]
        shutter.rotation_degrees.x = -_valve_angle
        var puffs: Array = module["puffs"]
        for puff_index in range(puffs.size()):
            var puff: MeshInstance3D = puffs[puff_index] as MeshInstance3D
            var phase: float = 0.0 if reduced_motion else elapsed*0.61
            var height_offset: float = fposmod(phase+float(puff_index)*0.55+float(vent_index)*0.33,3.4)
            var spread: float = 0.1+height_offset*0.17
            puff.position = Vector3(
                -0.1+sin(float(puff_index)*1.1)*spread,
                height_offset,
                sin(float(puff_index)*2.1+float(vent_index))*spread)
            puff.scale = Vector3(0.85+effect_risk*0.65,1.0+0.11*height_offset,0.85+effect_risk*0.65)
    if surges < _last_surge_count:
        _last_surge_count = surges
        _burst_started_at = -10000.0
    elif surges > _last_surge_count:
        _last_surge_count = surges
        _burst_started_at = elapsed
    var burst_age: float = elapsed-_burst_started_at
    _burst_visible = burst_age >= 0.0 and burst_age <= 1.15 and surges > 0
    if _burst_visible and _quality == "hero" and not reduced_motion:
        for index in range(SPARK_COUNT):
            var angle: float = TAU*float(index)/float(SPARK_COUNT)
            var outward: float = 0.38+burst_age*2.1
            var offset := Vector3(
                cos(angle)*outward,
                sin(angle*2.0)*outward*0.6,
                sin(angle)*outward)
            var real_spark_position: Vector3 = Vector3(12.6,7.2,-20.5)+offset
            if index == 0:
                _last_spark_origin = real_spark_position
            _spark_meshes.set_instance_transform(index,
                Transform3D(Basis(),real_spark_position))
    _update_visibility()

func readout() -> Dictionary:
    return {
        "physical_vent_modules":vents.size(),
        "shutters_animated":vents.size(),
        "steam_puffs_original":vents.size()*6,
        "spark_instanced_draw_groups":1 if spark_cluster != null else 0,
        "thermal_spark_instances":SPARK_COUNT,
        "quality":_quality,
        "warning_scenario":_last_scenario,
        "hazard_risk":_risk,
        "shutter_angle":_valve_angle,
        "vapor_visible":_active_vapor,
        "spark_burst_visible":_burst_visible and spark_cluster != null and spark_cluster.visible,
        "actual_surge_count":_last_surge_count,
        "spark_0_render_submission":[_last_spark_origin.x,_last_spark_origin.y,_last_spark_origin.z],
        "reduced_motion":_reduced_motion
    }
