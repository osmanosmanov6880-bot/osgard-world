extends Node3D
## NEBULA R10 near-field facade detail and roof equipment.
## Chunked by district, GPU-instanced with distance fade to avoid a world-wide
## always-visible 360-tower batch. Existing tower collisions remain authoritative.

const SurfaceLibraryR9Script = preload("res://scripts/surface_library_r9.gd")
const QUALITY_RANGES := [730.0, 460.0, 250.0]

var quality_mode: int = 0
var facade_count: int = 0
var serviced_towers: int = 0
var chunks: Array[MultiMeshInstance3D] = []

func _mat(color: Color, roughness: float, metallic: float = 0.80) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = roughness
    mat.metallic = metallic
    return mat

func _batch(name: String, items: Array[Transform3D], mat: Material) -> void:
    if items.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = BoxMesh.new()
    mm.instance_count = items.size()
    for i in items.size():
        mm.set_instance_transform(i, items[i])
    var obj := MultiMeshInstance3D.new()
    obj.name = name
    obj.multimesh = mm
    obj.material_override = mat
    obj.extra_cull_margin = 18.0
    add_child(obj)
    chunks.append(obj)
    facade_count += items.size()

func _transform(pos: Vector3, dimensions: Vector3, angle: float = 0.0) -> Transform3D:
    return Transform3D(Basis(Vector3.UP, angle).scaled(dimensions), pos)

func build(tower_data: Array[Dictionary], centres: Array) -> void:
    var facades := SurfaceLibraryR9Script.coat(_mat(Color(0.52, 0.56, 0.62), 0.46), 1)
    var shadow := SurfaceLibraryR9Script.coat(_mat(Color(0.19, 0.24, 0.30), 0.60), 0)
    var ceramic := SurfaceLibraryR9Script.coat(_mat(Color(0.63, 0.65, 0.66), 0.44), 3)
    var bronze := _mat(Color(0.49, 0.30, 0.14), 0.35, 0.86)
    for district in centres.size():
        var bay_windows: Array[Transform3D] = []
        var structural_shadow: Array[Transform3D] = []
        var roofing: Array[Transform3D] = []
        var copper: Array[Transform3D] = []
        var district_towers: int = 0
        for index in tower_data.size():
            var t: Dictionary = tower_data[index]
            if int(t["sector"]) != district or int(index / 6) % 3 == 1:
                continue
            var pos: Vector3 = t["pos"]
            var w: float = t["w"]
            var d: float = t["depth"]
            var h: float = t["h"]
            # No mid-air balconies below 18m and no dense detail in tiny towers.
            if h < 44.0:
                continue
            var bottom: float = pos.y - h * 0.5
            var top: float = pos.y + h * 0.5
            var floors: int = clampi(int(h / 5.6), 5, 20)
            for row in floors:
                var y: float = bottom + 7.0 + float(row) * (h - 14.0) / float(floors)
                if row % 5 == 0:
                    structural_shadow.append(_transform(Vector3(pos.x, y, pos.z + d * 0.52),
                                   Vector3(w * 1.13, 0.28, 0.72)))
                    structural_shadow.append(_transform(Vector3(pos.x, y, pos.z - d * 0.52),
                                   Vector3(w * 1.13, 0.28, 0.72)))
                for col in 4:
                    var u: float = (float(col) - 1.5) / 4.1
                    # Raised aluminum casings and genuinely recessed shadow channels
                    # break the previous flat repeated window texture.
                    var outer: float = (d * 0.5 + 0.41)
                    var x: float = pos.x + u * w
                    bay_windows.append(_transform(Vector3(x, y, pos.z + outer),
                                      Vector3(w * 0.16, 1.42, 0.54)))
                    bay_windows.append(_transform(Vector3(x, y, pos.z - outer),
                                      Vector3(w * 0.16, 1.42, 0.54)))
                    if row % 2 == 0:
                        structural_shadow.append(_transform(
                            Vector3(x, y - 0.92, pos.z + d * 0.5 + 0.45),
                            Vector3(w * 0.19, 0.14, 0.86)))
                if row % 3 == 0:
                    for edge in [-1.0, 1.0]:
                        structural_shadow.append(_transform(
                            Vector3(pos.x + edge * (w * 0.52), y, pos.z),
                            Vector3(0.32, 1.72, d * 0.74)))
            # Architectural crowns, roof setbacks, industrial ventilation.
            roofing.append(_transform(Vector3(pos.x, top + 1.1, pos.z),
                           Vector3(w * 0.87, 2.2, d * 0.87)))
            roofing.append(_transform(Vector3(pos.x, top + 3.6, pos.z),
                           Vector3(w * 0.70, 2.75, d * 0.68)))
            for v in 6:
                var u: float = (float(v) - 2.5) / 6.0
                roofing.append(_transform(Vector3(pos.x + u * w, top + 6.3,
                        pos.z - d * 0.15), Vector3(0.74, 3.2, d * 0.31)))
                copper.append(_transform(Vector3(pos.x + u * w, top + 8.15,
                        pos.z - d * 0.15), Vector3(0.91, 0.26, d * 0.34)))
            for side in [-1.0, 1.0]:
                copper.append(_transform(Vector3(pos.x + side * w * 0.43,
                           top + 3.7, pos.z + d * 0.39),
                           Vector3(0.34, 2.2, 1.9)))
            district_towers += 1
        _batch("R10_D%02d_DeepArchitecturalWindowBays" % district, bay_windows, facades)
        _batch("R10_D%02d_ShadowRecessesAndBalconies" % district, structural_shadow, shadow)
        _batch("R10_D%02d_PBRMechanicalCrown" % district, roofing, ceramic)
        _batch("R10_D%02d_WeatheredCopperEdging" % district, copper, bronze)
        serviced_towers += district_towers
    set_quality(0)

func set_quality(mode: int) -> void:
    quality_mode = clampi(mode, 0, 2)
    for chunk in chunks:
        if is_instance_valid(chunk):
            chunk.visibility_range_end = QUALITY_RANGES[quality_mode]
            chunk.visibility_range_end_margin = 120.0
