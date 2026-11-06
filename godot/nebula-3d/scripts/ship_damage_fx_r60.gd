extends Node3D
## NEBULA R60 live hull-condition visualization. An honest damage state,
## reading current physical hull and cap; no animation in a healthy garage.
const SOOT_COUNT: int = 4
const SPARK_COUNT: int = 3
const SMOKE_COUNT: int = 2
var followed_ship: Node3D
var damage_band_r60: int = 0
var update_clock: float = 0.0
var visual_clock: float = 0.0
var soot: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var fumes: Array[MeshInstance3D] = []
var low_detail: bool = false

func follow_real_ship(ship: Node3D) -> void:
    followed_ship = ship
    low_detail = get_viewport().get_visible_rect().size.x < 680

func _ready() -> void:
    name = "R60_HullConditionActualMeshEffects"
    var carbon := StandardMaterial3D.new()
    carbon.albedo_color = Color(0.045, 0.049, 0.055, 0.86)
    carbon.roughness = 0.92
    carbon.metallic = 0.10
    for i in SOOT_COUNT:
        var plate := MeshInstance3D.new()
        plate.name = "R60_PhysicalHullScorch_%d" % (i + 1)
        var shape := BoxMesh.new()
        shape.size = Vector3(1.0, 0.024, 1.4)
        plate.mesh = shape
        plate.material_override = carbon
        var side: float = -1.0 if i % 2 == 0 else 1.0
        plate.position = Vector3(side * (
            1.5 + float(i / 2) * 1.15), 0.44, -1.9 + float(i) * 0.98)
        plate.rotation_degrees = Vector3(0, side * 9.0, side * 5.0)
        plate.visible = false
        add_child(plate)
        soot.append(plate)
    var spark_material := StandardMaterial3D.new()
    spark_material.albedo_color = Color(1.0, 0.34, 0.07)
    spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    spark_material.emission_enabled = true
    spark_material.emission = Color(1.0, 0.35, 0.09)
    spark_material.emission_energy_multiplier = 1.8
    for i in SPARK_COUNT:
        var spark := MeshInstance3D.new()
        spark.name = "R60_ActualDamageArc_%d" % (i + 1)
        var bar := BoxMesh.new()
        bar.size = Vector3(0.095, 0.06, 0.5)
        spark.mesh = bar
        spark.material_override = spark_material
        spark.position = Vector3(-1.0 + float(i), 0.88, 1.0)
        spark.visible = false
        add_child(spark)
        sparks.append(spark)
    var smoke_material := StandardMaterial3D.new()
    smoke_material.albedo_color = Color(0.23, 0.27, 0.31, 0.39)
    smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for i in SMOKE_COUNT:
        var plume := MeshInstance3D.new()
        plume.name = "R60_RealScorchedEngineFume_%d" % (i + 1)
        var cloud := SphereMesh.new()
        cloud.radius = 0.60
        cloud.height = 1.2
        plume.mesh = cloud
        plume.material_override = smoke_material
        plume.position = Vector3(
            -1.1 if i == 0 else 1.1, 0.72, 3.8)
        plume.scale = Vector3(0.8, 1.1, 1.8)
        plume.visible = false
        add_child(plume)
        fumes.append(plume)

func _process(delta: float) -> void:
    if not is_instance_valid(followed_ship):
        return
    update_clock += delta
    visual_clock += delta
    if update_clock >= 0.12:
        update_clock = 0.0
        var hull: float = maxf(0.0, float(followed_ship.get("hull")))
        var cap: float = maxf(1.0, float(followed_ship.get("hull_cap_r60")))
        var fraction: float = clampf(hull / cap, 0.0, 1.0)
        var new_band: int = (
            3 if fraction < 0.20 else (
            2 if fraction < 0.43 else (1 if fraction < 0.75 else 0)))
        if new_band != damage_band_r60:
            damage_band_r60 = new_band
            for plate in soot:
                plate.visible = new_band >= 1
            for spark in sparks:
                spark.visible = new_band >= 2
            for fume in fumes:
                fume.visible = new_band >= 3 and not low_detail
    if damage_band_r60 >= 2:
        for i in sparks.size():
            var spark: MeshInstance3D = sparks[i]
            spark.visible = fmod(visual_clock * 5.0 + float(i) * 0.9, 1.0) > 0.20
            spark.scale.z = 0.48 + 0.33 * sin(
                visual_clock * 11.0 + float(i))
    if damage_band_r60 >= 3 and not low_detail:
        for i in fumes.size():
            var plume: MeshInstance3D = fumes[i]
            plume.position.y = 0.72 + fmod(
                visual_clock * (1.3 + float(i) * 0.3), 2.0)
            plume.scale = Vector3.ONE * (
                0.8 + 0.25 * sin(visual_clock * 2.8 + float(i)))

func scorch_mesh_count() -> int:
    return soot.size() + sparks.size() + fumes.size()
