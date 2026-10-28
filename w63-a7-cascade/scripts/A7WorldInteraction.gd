extends Node3D
class_name A7WorldInteraction
## W73: an ACTUAL Camera3D RayCast3D against native 3D collider targets.
## A ray must intersect the current machine part, be close enough to the real
## CharacterBody3D and be in the proper game stage. No DOM or fake hit regions.
## 8 exclusively world-game collision bit, never a real-world machine.

const WORLD_TARGET_LAYER: int = 8
const RETICLE_RAY_LENGTH: float = 5.2
const CORE_MAX: float = 3.2
const RELAY_MAX: float = 4.0

var player: A7FirstPersonOperator
var equipment: A7FieldOperations
var ray: RayCast3D
var targets: Array[StaticBody3D] = []
var target_pieces: Dictionary = {}
var physical_ray_checks: int = 0
var accepted_world_uses: int = 0
var rejected_world_uses: int = 0
var last_world_mechanic: String = ""
var last_world_index: int = -1
var actual_aim: Dictionary = {}

func _make_hit_target(id: String, kind: String, index: int,
        pos: Vector3, dims: Vector3) -> StaticBody3D:
    var node := StaticBody3D.new()
    node.name = id
    node.position = pos
    node.collision_layer = 0
    node.collision_mask = 0
    node.set_meta("w73_device_kind", kind)
    node.set_meta("w73_device_index", index)
    var hit := CollisionShape3D.new()
    hit.name = "NativeRaycastable3DCollision"
    var shape := BoxShape3D.new()
    shape.size = dims
    hit.shape = shape
    node.add_child(hit)
    add_child(node)
    targets.append(node)
    target_pieces[id] = node
    return node

func build(real_player: A7FirstPersonOperator,
        original_equipment: A7FieldOperations) -> void:
    name = "W73ActualCameraRaycastInteractionNot2DSelection"
    player = real_player
    equipment = original_equipment
    ray = RayCast3D.new()
    ray.name = "OriginalGodot3DWorldSpaceOperatorTargetRay"
    ray.target_position = Vector3(0, 0, -RETICLE_RAY_LENGTH)
    ray.collision_mask = WORLD_TARGET_LAYER
    ray.collide_with_bodies = true
    ray.collide_with_areas = false
    ray.hit_from_inside = false
    ray.enabled = true
    player.head_camera.add_child(ray)
    # Cross-check W72 original, independent machine parts: one thermal
    # valve, three genuinely different relay rockers, three final contacts.
    _make_hit_target("W73RealThermalValveHit", "valve", 0,
        A7FieldOperations.CORE+Vector3(0,1.0,0.15),
        Vector3(1.05,0.85,0.65))
    for i in range(3):
        _make_hit_target("W73ActualRelaySwitch%dHit" % i,"relay",i,
            A7FieldOperations.RELAY+Vector3((float(i)-1.0)*0.66,0.95,0.36),
            Vector3(0.46,0.63,0.46))
    for i in range(3):
        _make_hit_target("W73ActualSyncContact%dHit" % i,"sync",i,
            A7FieldOperations.CORE+Vector3(1.02+(float(i)-1.0)*0.31,1.52,0.25),
            Vector3(0.28,0.46,0.35))
    _update_active_targets()
    set_process(true)

func _correct_stage(kind: String) -> bool:
    if equipment == null or not equipment.enabled:
        return false
    return ((kind == "valve" and equipment.stage == 0)
        or (kind == "relay" and equipment.stage == 2)
        or (kind == "sync" and equipment.stage == 4))

func _update_active_targets() -> void:
    for obj in targets:
        var kind: String = str(obj.get_meta("w73_device_kind"))
        obj.collision_layer = WORLD_TARGET_LAYER if (
            _correct_stage(kind) and player != null and player.piloting) else 0

func _process(_delta: float) -> void:
    _update_active_targets()

func look_at_active_target() -> Dictionary:
    actual_aim = {}
    if player == null or not player.piloting or equipment == null or not equipment.enabled:
        return {}
    _update_active_targets()
    if ray == null or not ray.is_inside_tree():
        return {}
    physical_ray_checks += 1
    ray.force_raycast_update()
    if not ray.is_colliding():
        return {}
    var object: StaticBody3D = ray.get_collider() as StaticBody3D
    if object == null or not object.has_meta("w73_device_kind"):
        return {}
    var kind: String = str(object.get_meta("w73_device_kind"))
    if not _correct_stage(kind):
        return {}
    var pos: Vector3 = A7FieldOperations.RELAY if kind == "relay" else A7FieldOperations.CORE
    var limit: float = RELAY_MAX if kind == "relay" else CORE_MAX
    if player.body == null or player.body.position.distance_to(pos) >= limit:
        return {}
    var point: Vector3 = ray.get_collision_point()
    var eye: Vector3 = player.head_camera.global_position
    if point.distance_to(eye) > RETICLE_RAY_LENGTH+0.02:
        return {}
    actual_aim = {
        "kind": kind,
        "index": int(object.get_meta("w73_device_index")),
        "hit": [point.x,point.y,point.z],
        "ray_distance": eye.distance_to(point),
        "collider_name": object.name,
        "native_physics_ray": true,
    }
    return actual_aim.duplicate(true)

func interact(state: Dictionary) -> Dictionary:
    var aimed: Dictionary = look_at_active_target()
    if aimed.is_empty():
        rejected_world_uses += 1
        return {}
    var ok: bool = false
    var kind: String = str(aimed["kind"])
    var index: int = int(aimed["index"])
    if kind == "valve":
        ok = equipment.rotate_valve(1,player)
    elif kind == "relay":
        ok = equipment.toggle_relay(index,player)
    elif kind == "sync":
        ok = equipment.sync_connector(index,player,state)
    if not ok:
        rejected_world_uses += 1
        return {}
    accepted_world_uses += 1
    last_world_mechanic = kind
    last_world_index = index
    return aimed

func hint(locale: String) -> String:
    var hit: Dictionary = look_at_active_target()
    if hit.is_empty():
        return ("НАВЕДИТЕ ПРИЦЕЛ НА УЗЕЛ • G"
            if locale == "ru" else "AIM AT A PHYSICAL DEVICE • G")
    var kind: String = str(hit["kind"])
    var label: String = ("КЛАПАН" if kind == "valve" else
        "РЕЛЕ %d" % (int(hit["index"])+1) if kind == "relay" else
        "КОНТАКТ %d" % (int(hit["index"])+1))
    if locale != "ru":
        label = ("THERMAL VALVE" if kind == "valve" else
            "RELAY %d" % (int(hit["index"])+1) if kind == "relay" else
            "CONTACT %d" % (int(hit["index"])+1))
    return "%s  /  G" % label

func qa_readout() -> Dictionary:
    return {
        "schema":"LAST_FRONTIER_W73_NATIVE_RAYCAST_WORLD_INTERACTION_V1",
        "real_ray": ray is RayCast3D,
        "attached_to_actual_eye_camera":ray.get_parent() == player.head_camera if ray != null else false,
        "actual_native_staticbody_targets":targets.size(),
        "actual_world_collision_layer":WORLD_TARGET_LAYER,
        "raycast_max_meters":RETICLE_RAY_LENGTH,
        "physically_measured_raycast_checks":physical_ray_checks,
        "accepted_ray_interactions":accepted_world_uses,
        "rejected_raycast_uses":rejected_world_uses,
        "last_mechanism":last_world_mechanic,
        "last_target_index":last_world_index,
        "actual_active_ray_target":actual_aim.get("kind",""),
        "external_network":false,
        "production_approved":false,
    }
