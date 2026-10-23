extends Node3D
const GuidedMissileR16Script = preload("res://scripts/guided_missile_r16.gd")
## R15 player-owned fleet gameplay. Credit purchases only; premium purchases
## are never fulfilled from browser state. Allies assist in real combat.
signal missile_hit(target: Node3D)
signal ally_fired(origin: Vector3, endpoint: Vector3)
var active_ship: String = "ship_scout"
var active_weapon: String = "weapon_basic"
var missiles: int = 0
var helpers: Array[Node3D] = []
var player_ship: Node3D
var targets: Array[Node3D] = []
var cooldown: float = 0.0
var ally_timer: float = 0.0
var missile_damage: float = 14.0
var cosmetic_skin: String = ""
var helper_ids: Array[String] = []
const MISSILE_POOL_SIZE: int = 8
var missile_pool: Array[Node3D] = []
var missile_impacts: int = 0
var helper_rebuilds: int = 0

func _ready() -> void:
    for i in MISSILE_POOL_SIZE:
        var rocket: Node3D = GuidedMissileR16Script.new()
        rocket.name = "R16_GuidedMissile_%02d" % i
        add_child(rocket)
        rocket.connect("impacted", Callable(self, "_on_missile_impact"))
        missile_pool.append(rocket)

func _on_missile_impact(victim: Node3D) -> void:
    missile_impacts += 1
    missile_hit.emit(victim)

func set_loadout(ship_id: String, weapon_id: String, rockets: int,
                 wingmen: Array[String]) -> void:
    active_ship = ship_id
    active_weapon = weapon_id
    missiles = maxi(0, rockets)
    var same_formation: bool = helper_ids == wingmen and helpers.size() == mini(wingmen.size(), 2)
    if same_formation:
        _apply_ship_stats()
        return
    helper_ids = wingmen.duplicate()
    helper_rebuilds += 1
    for node in helpers:
        if is_instance_valid(node): node.queue_free()
    helpers.clear()
    for i in mini(wingmen.size(), 2):
        var model := Node3D.new()
        model.name = "R15_Companion_%d" % i
        add_child(model)
        if is_instance_valid(player_ship):
            model.global_position = player_ship.global_position + player_ship.global_basis.x * (-8.0 if i == 0 else 8.0)
        var hull := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = Vector3(2.7, 0.6, 3.8)
        hull.mesh = box
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.22, 0.58, 0.65) if wingmen[i] == "wingman_escort" else Color(0.74, 0.47, 0.20)
        mat.metallic = 0.77
        mat.roughness = 0.34
        hull.material_override = mat
        model.add_child(hull)
        var wing := MeshInstance3D.new()
        var wingmesh := BoxMesh.new()
        wingmesh.size = Vector3(4.8, 0.16, 1.0)
        wing.mesh = wingmesh
        wing.material_override = mat
        model.add_child(wing)
        helpers.append(model)
    if is_instance_valid(player_ship):
        _apply_ship_stats()

func _apply_ship_stats() -> void:
    if not is_instance_valid(player_ship):return
    player_ship.turn_speed = 2.4 if active_ship == "ship_interceptor" else 1.5 if active_ship == "ship_guardian" else 1.9

func _process(delta: float) -> void:
    if not is_instance_valid(player_ship):return
    ally_timer += delta
    cooldown = maxf(0.0, cooldown - delta)
    for i in helpers.size():
        var ally: Node3D = helpers[i]
        if not is_instance_valid(ally):continue
        var side: float = -1.0 if i == 0 else 1.0
        var target_pos: Vector3 = player_ship.global_position + player_ship.global_basis.x * (side * 8.0) + player_ship.global_basis.z * 5.0 + Vector3.UP * (1.0 + sin(ally_timer * 2.0 + float(i)))
        ally.global_position = ally.global_position.lerp(target_pos, minf(1.0, delta * 3.2))
        ally.global_basis = player_ship.global_basis
    if ally_timer >= 1.15 and not helpers.is_empty():
        ally_timer = 0.0
        var opponent: Node3D = _nearest_hostile(160.0)
        if is_instance_valid(opponent) and opponent.has_method("hit"):
            for wingman in helpers:
                if is_instance_valid(wingman):
                    ally_fired.emit(wingman.global_position, opponent.global_position)
            opponent.hit(3.5 + float(helpers.size()) * 2.0)

func _nearest_hostile(distance: float) -> Node3D:
    var selected: Node3D
    var best: float = distance * distance
    if not is_instance_valid(player_ship):return selected
    for drone in targets:
        if not is_instance_valid(drone) or not bool(drone.hostile):continue
        var d: float = drone.global_position.distance_squared_to(player_ship.global_position)
        if d < best:
            best = d
            selected = drone
    return selected

func launch_missile() -> bool:
    if missiles <= 0 or cooldown > 0.0 or not is_instance_valid(player_ship):
        return false
    var enemy: Node3D = _nearest_hostile(245.0)
    if not is_instance_valid(enemy):
        return false
    var ready_rocket: Node3D
    for rocket in missile_pool:
        if not bool(rocket.get("armed")):
            ready_rocket = rocket
            break
    if not is_instance_valid(ready_rocket):
        return false
    var forward: Vector3 = -player_ship.global_basis.z
    if not bool(ready_rocket.call("activate", player_ship.global_position + forward * 3.4,
                                  forward, enemy, missile_damage)):
        return false
    missiles -= 1
    cooldown = 1.1
    return true

func weapon_damage() -> float:
    return 10.5 if active_weapon == "weapon_plasma" else 7.2 if active_weapon == "weapon_pulse" else 4.0

func ship_hull_cap() -> float:
    return 160.0 if active_ship == "ship_guardian" else 100.0

func ship_shield_cap() -> float:
    return 140.0 if active_ship == "ship_guardian" else 100.0
