extends Node3D
const GuidedMissileR16Script = preload("res://scripts/guided_missile_r16.gd")
## R46: one source of truth for actual flight turn rate and damage capacities.
## Numbers here are also displayed by the garage comparison UI.
const SHIP_PROFILES = {
    "ship_scout": {"turn_speed": 1.9, "hull": 100.0, "shield": 100.0},
    "ship_interceptor": {"turn_speed": 2.4, "hull": 100.0, "shield": 100.0},
    "ship_guardian": {"turn_speed": 1.5, "hull": 160.0, "shield": 140.0},
}

static func hull_profile(id: String) -> Dictionary:
    var key: String = id if SHIP_PROFILES.has(id) else "ship_scout"
    return (SHIP_PROFILES[key] as Dictionary).duplicate(true)

## R15 player-owned fleet gameplay. Credit purchases only; premium purchases
## are never fulfilled from browser state. Allies assist in real combat.
signal missile_hit(target: Node3D)
signal ally_fired(origin: Vector3, endpoint: Vector3)
## R49: only a real successful missile launch emits this gameplay event.
signal missile_launched
var active_ship: String = "ship_scout"
var active_weapon: String = "weapon_basic"
var missiles: int = 0
var helpers: Array[Node3D] = []
var player_ship: Node3D
var targets: Array[Node3D] = []
var cooldown: float = 0.0
var ally_timer: float = 0.0
## R47: the garage is a no-combat zone even when owned allies are equipped.
var combat_active: bool = false
var missile_damage: float = 14.0
var cosmetic_skin: String = ""
var helper_ids: Array[String] = []
const MISSILE_POOL_SIZE: int = 8
var missile_pool: Array[Node3D] = []
var missile_impacts: int = 0
var helper_rebuilds: int = 0
## R49: issued squad orders change real formation movement and weapon targeting.
const SQUAD_COMMANDS = ["follow", "attack", "defend"]
var command_mode: String = "follow"
var defend_anchor: Node3D
var command_changes: int = 0
var ally_hits_r49: int = 0
## R50: pilots can order an owned squad to focus a real hostile.
## An invalid, distant or already destroyed target cannot be locked.
const FOCUS_RANGE: float = 340.0
var focus_target: Node3D
var focus_changes: int = 0
var focus_shots: int = 0
## Reticle is a real world-space 3D object; laser hits must pass geometry.
var focus_marker: MeshInstance3D
var blocked_ally_shots: int = 0
var missile_focus_launches: int = 0

func _has_clear_laser_path(origin: Vector3, destination: Vector3) -> bool:
    if origin.distance_squared_to(destination) < 0.01:
        return false
    var query := PhysicsRayQueryParameters3D.create(origin, destination, 1)
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    # Enemies in this game have no physics collider. Ray hits are solid
    # buildings, ground and other actual world obstacles blocking a laser.
    return hit.is_empty()

func _refresh_focus_marker() -> void:
    if not is_instance_valid(focus_marker):
        return
    focus_marker.visible = combat_active and command_mode == "attack" and (
        _valid_focus(focus_target))
    if focus_marker.visible:
        focus_marker.global_position = focus_target.global_position + Vector3.UP * 4.5
        focus_marker.rotate_y(0.015)


func _valid_focus(candidate: Node3D) -> bool:
    return is_instance_valid(player_ship) and is_instance_valid(candidate) and (
        bool(candidate.hostile) and player_ship.global_position.distance_to(
            candidate.global_position) <= FOCUS_RANGE)

func clear_focus() -> void:
    focus_target = null

func select_next_focus() -> bool:
    if not is_instance_valid(player_ship) or not combat_active or helpers.is_empty():
        return false
    if targets.is_empty():
        clear_focus()
        return false
    var previous: int = targets.find(focus_target) if is_instance_valid(focus_target) else -1
    for turn in targets.size():
        var next_index: int = (previous + 1 + turn) % targets.size()
        var enemy: Node3D = targets[next_index]
        if _valid_focus(enemy):
            if enemy != focus_target:
                focus_changes += 1
            focus_target = enemy
            return true
    clear_focus()
    return false

func focus_status() -> String:
    if not _valid_focus(focus_target):
        return "НЕТ ЦЕЛИ"
    var distance: int = roundi(player_ship.global_position.distance_to(
        focus_target.global_position))
    return "ЦЕЛЬ %d М" % distance

func set_command(mode: String) -> bool:
    if not SQUAD_COMMANDS.has(mode):
        return false
    if command_mode != mode:
        command_mode = mode
        command_changes += 1
    return true

func _defend_center() -> Vector3:
    if not is_instance_valid(player_ship):
        return Vector3.ZERO
    # Never abandon the pilot to defend a target on the opposite side of town.
    if is_instance_valid(defend_anchor) and player_ship.global_position.distance_to(
            defend_anchor.global_position) <= 330.0:
        return defend_anchor.global_position
    return player_ship.global_position

func _command_enemy() -> Node3D:
    if not is_instance_valid(player_ship):
        return null
    if command_mode == "attack":
        if _valid_focus(focus_target):
            return focus_target
        return _nearest_hostile_from(player_ship.global_position, 240.0)
    if command_mode == "defend":
        # Drones striking the real vulnerable convoy take priority.
        if is_instance_valid(defend_anchor):
            var danger: Node3D = null
            var closest: float = 145.0 * 145.0
            for enemy in targets:
                if not is_instance_valid(enemy) or not bool(enemy.hostile):
                    continue
                if enemy.target != defend_anchor:
                    continue
                var gap: float = enemy.global_position.distance_squared_to(
                    _defend_center())
                if gap < closest:
                    closest = gap
                    danger = enemy
            if is_instance_valid(danger):
                return danger
        return _nearest_hostile_from(_defend_center(), 145.0)
    return _nearest_hostile_from(player_ship.global_position, 90.0)


func _ready() -> void:
    focus_marker = MeshInstance3D.new()
    focus_marker.name = "R50_ActualEnemyFocusReticle"
    var ring := TorusMesh.new()
    ring.inner_radius = 4.5
    ring.outer_radius = 5.0
    ring.rings = 28
    ring.ring_segments = 8
    focus_marker.mesh = ring
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.67, 0.22)
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.46, 0.14)
    mat.emission_energy_multiplier = 2.0
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    focus_marker.material_override = mat
    focus_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    focus_marker.visible = false
    add_child(focus_marker)
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
    clear_focus()
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
    player_ship.turn_speed = float(hull_profile(active_ship)["turn_speed"])
    # Keep visible in-flight geometry synchronized with real owned/equipped hull.
    if player_ship.has_method("set_hull_variant"):
        player_ship.set_hull_variant(active_ship)

func _process(delta: float) -> void:
    if not is_instance_valid(player_ship):return
    var dt: float = clampf(delta, 0.0, 0.25)
    ally_timer += dt
    cooldown = maxf(0.0, cooldown - dt)
    if not _valid_focus(focus_target):
        clear_focus()
    var opponent: Node3D = _command_enemy() if combat_active else null
    _refresh_focus_marker()
    for i in helpers.size():
        var ally: Node3D = helpers[i]
        if not is_instance_valid(ally):continue
        var side: float = -1.0 if i == 0 else 1.0
        var target_pos: Vector3 = player_ship.global_position + (
            player_ship.global_basis.x * (side * 8.0)) + (
            player_ship.global_basis.z * 5.0) + Vector3.UP * (
            1.0 + sin(ally_timer * 2.0 + float(i)))
        if command_mode == "defend":
            target_pos = _defend_center() + (
                player_ship.global_basis.x * (side * 15.0)) + Vector3.UP * 5.0
        elif command_mode == "attack" and is_instance_valid(opponent):
            target_pos = opponent.global_position + (
                player_ship.global_basis.x * (side * 11.0)) + Vector3.UP * 6.0
        # Bounded real movement, never teleport a companion across a district.
        ally.global_position = ally.global_position.move_toward(target_pos,
            dt * (92.0 if command_mode == "attack" else 65.0))
        if is_instance_valid(opponent) and command_mode == "attack" and (
                opponent.global_position.distance_squared_to(ally.global_position) > 1.0):
            ally.look_at(opponent.global_position, Vector3.UP)
        else:
            ally.global_basis = player_ship.global_basis
    if not combat_active:
        ally_timer = 0.0
        return
    if ally_timer >= 1.15 and not helpers.is_empty():
        ally_timer = 0.0
        if is_instance_valid(opponent) and opponent.has_method("hit"):
            for wingman in helpers:
                # Individual craft must physically reach weapons range.
                if is_instance_valid(wingman) and wingman.global_position.distance_to(
                        opponent.global_position) <= 170.0:
                    if not _has_clear_laser_path(wingman.global_position,
                            opponent.global_position):
                        blocked_ally_shots += 1
                        continue
                    ally_fired.emit(wingman.global_position, opponent.global_position)
                    opponent.hit(5.5 if command_mode == "attack" else 4.3)
                    ally_hits_r49 += 1
                    if opponent == focus_target:
                        focus_shots += 1

func _nearest_hostile_from(origin: Vector3, distance: float) -> Node3D:
    var selected: Node3D
    var best: float = distance * distance
    for drone in targets:
        if not is_instance_valid(drone) or not bool(drone.hostile):
            continue
        var gap: float = drone.global_position.distance_squared_to(origin)
        if gap < best:
            best = gap
            selected = drone
    return selected

func _nearest_hostile(distance: float) -> Node3D:
    if not is_instance_valid(player_ship):
        return null
    return _nearest_hostile_from(player_ship.global_position, distance)

func launch_missile() -> bool:
    if missiles <= 0 or cooldown > 0.0 or not is_instance_valid(player_ship):
        return false
    # The pilot's actual squad target gets first missile priority, but only
    # inside physical missile lock range; retain legacy nearest-enemy fallback.
    var locked: bool = _valid_focus(focus_target) and (
        player_ship.global_position.distance_to(focus_target.global_position) <= 245.0)
    var enemy: Node3D = focus_target if locked else _nearest_hostile(245.0)
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
    if locked:
        missile_focus_launches += 1
    cooldown = 1.1
    missile_launched.emit()
    return true

func weapon_damage() -> float:
    return 10.5 if active_weapon == "weapon_plasma" else 7.2 if active_weapon == "weapon_pulse" else 4.0

func ship_hull_cap() -> float:
    return float(hull_profile(active_ship)["hull"])

func ship_shield_cap() -> float:
    return float(hull_profile(active_ship)["shield"])
