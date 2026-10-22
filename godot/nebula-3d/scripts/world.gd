extends Node3D
## NEBULA ASCENSION 3D: experimental standalone Godot 4 vertical slice.
## Built from procedural geometry; it does not share browser v4 save data.

const ShipScript = preload("res://scripts/ship.gd")
const DroneScript = preload("res://scripts/drone.gd")
const RadarScript = preload("res://scripts/radar.gd")
const SAVE_PATH = "user://nebula_3d_save.json"
const SECTOR_COLORS = [Color(0.10,0.68,0.97), Color(0.64,0.35,1.0), Color(0.98,0.73,0.40), Color(1.0,0.46,0.34), Color(0.87,0.27,0.88), Color(0.24,0.92,0.88)]
const SECTOR_NAMES = ["ПОРТ АВРОРА","НЕОНОВЫЙ КВАРТАЛ","ЦИТАДЕЛЬ","ЧЁРНЫЙ РЫНОК","РАЗЛОМ","НЕКСУС"]
const SECTOR_POSITIONS = [Vector3(0,0,0),Vector3(610,0,-330),Vector3(1070,0,330),Vector3(-500,0,670),Vector3(480,0,940),Vector3(1250,0,-730)]
const MISSIONS = [
    {"title":"ПЕРВЫЙ ПОЛЁТ","hint":"Доберись до светящегося навигационного маяка","position":Vector3(210,18,-270),"type":"reach","reward":350},
    {"title":"НЕОНОВЫЙ КВАРТАЛ","hint":"Посети новый сектор и найди торговый маршрут","position":Vector3(610,20,-330),"type":"reach","reward":450},
    {"title":"СИГНАЛ ПЕРЕХВАТА","hint":"Очисти сектор от трёх пиратских дронов","position":Vector3(1070,19,330),"type":"combat","reward":900},
    {"title":"ВОЗВРАЩЕНИЕ В ПОРТ","hint":"Доставь разведданные обратно в Аврору","position":Vector3(0,16,0),"type":"reach","reward":600},
    {"title":"РАЗЛОМ","hint":"Открой нестабильный навигационный портал","position":Vector3(480,23,940),"type":"reach","reward":1300},
    {"title":"НЕКСУС","hint":"Сразись с элитной эскадрильей","position":Vector3(1250,26,-730),"type":"combat","reward":2100}
]

var rng := RandomNumberGenerator.new()
var ship
var chase_camera: Camera3D
var camera_distance: float = 24.0
var drones: Array[Node3D] = []
var mission_index: int = 0
var credits: int = 950
var xp: int = 0
var mission_enemies: int = 0
var mission_started: bool = false
var shot_flash: float = 0.0
var hud_mission: Label
var hud_status: Label
var hud_controls: Label
var hud_notice: Label
var notice_timer: float = 0.0
var mission_beacon: Node3D
var world_timer: float = 0.0
var radar: Control
var world_pulse: float = 0.0
var lens_mode: int = 0
var last_notice: String = ""
var world_events: int = 0

func _ready() -> void:
    rng.seed = 20261022
    _setup_environment()
    _build_city()
    _spawn_player()
    _spawn_civilians_and_pirates()
    _make_hud()
    _load_progress()
    _start_mission()
    _show_notice("НЕБУЛА 3D · СИСТЕМА АКТИВНА")

func _setup_environment() -> void:
    var node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.014,0.026,0.071)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.21,0.36,0.66)
    env.ambient_light_energy = 0.68
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    node.environment = env
    add_child(node)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0,-34.0,0.0)
    sun.light_color = Color(0.67,0.84,1.0)
    sun.light_energy = 1.45
    add_child(sun)
    var deck := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(4100,4100)
    deck.mesh = plane
    deck.material_override = _mat(Color(0.016,0.05,0.09),0.08)
    deck.position.y = -2.0
    add_child(deck)

func _mat(col: Color, glow: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = col
    mat.metallic = 0.62
    mat.roughness = 0.31
    if glow > 0.01:
        mat.emission_enabled = true
        mat.emission = col
        mat.emission_energy_multiplier = glow
    return mat

func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = pos
    parent.add_child(instance)
    return instance

func _build_city() -> void:
    # MultiMesh keeps hundreds of individual high-rise structures inexpensive.
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.use_colors = true
    var tower := BoxMesh.new()
    tower.size = Vector3.ONE
    multimesh.mesh = tower
    multimesh.instance_count = 360
    var tower_material := StandardMaterial3D.new()
    tower_material.vertex_color_use_as_albedo = true
    tower_material.metallic = 0.78
    tower_material.roughness = 0.30
    var inst := MultiMeshInstance3D.new()
    inst.name = "CityTowers_MultiMesh"
    inst.multimesh = multimesh
    inst.material_override = tower_material
    add_child(inst)
    var skylights := MultiMesh.new()
    skylights.transform_format = MultiMesh.TRANSFORM_3D
    skylights.use_colors = true
    var luminaire := BoxMesh.new()
    luminaire.size = Vector3.ONE
    skylights.mesh = luminaire
    skylights.instance_count = 360
    var glow_layer := MultiMeshInstance3D.new()
    glow_layer.name = "SkylineNeonCrowns"
    glow_layer.multimesh = skylights
    var glow_material := _mat(Color.WHITE, 2.0)
    glow_material.vertex_color_use_as_albedo = true
    glow_layer.material_override = glow_material
    add_child(glow_layer)
    for i in range(360):
        var sector: int = i % SECTOR_POSITIONS.size()
        var center: Vector3 = SECTOR_POSITIONS[sector]
        var radius: float = rng.randf_range(130.0,320.0)
        var bearing: float = rng.randf_range(0.0,TAU)
        var w: float = rng.randf_range(12.0,29.0)
        var height: float = rng.randf_range(25.0,170.0)
        var depth: float = rng.randf_range(12.0,29.0)
        var pos := center + Vector3(cos(bearing)*radius,height*0.5,sin(bearing)*radius)
        multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(w,height,depth)),pos))
        var col: Color = SECTOR_COLORS[sector].darkened(rng.randf_range(0.42,0.70))
        multimesh.set_instance_color(i,col)
        skylights.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(w+2.0,2.6,depth+2.0)), pos + Vector3(0,height*0.5+1.6,0)))
        skylights.set_instance_color(i,SECTOR_COLORS[sector].lightened(0.14))
        var solid := StaticBody3D.new()
        solid.name = "TowerCollision_%03d" % i
        solid.position = pos
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(w,height,depth)
        collision.shape = shape
        solid.add_child(collision)
        add_child(solid)
    for i in SECTOR_POSITIONS.size():
        var base: Vector3 = SECTOR_POSITIONS[i]
        _build_sector(base,SECTOR_COLORS[i],SECTOR_NAMES[i],i)
    _build_starfield()

func _build_sector(center: Vector3, tint: Color, name: String, index: int) -> void:
    var group := Node3D.new()
    group.name = name
    group.position = center
    add_child(group)
    _box(Vector3(0,3,0),Vector3(95,6,95),_mat(Color(0.07,0.15,0.25),0.1),group)
    for k in 12:
        var ang: float = TAU*float(k)/12.0
        var px: float = cos(ang)*105.0
        var pz: float = sin(ang)*105.0
        _box(Vector3(px,32,pz),Vector3(9,62,9),_mat(tint.darkened(0.44),0.18),group)
        _box(Vector3(px,65,pz),Vector3(12,4,12),_mat(tint,1.5),group)
    for h in 4:
        var ring := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 68.0 + h*9.0
        torus.outer_radius = 70.0 + h*9.0
        ring.mesh = torus
        ring.material_override = _mat(tint,1.7)
        ring.position.y = 11.0+h*13.0
        group.add_child(ring)
    var text := Label3D.new()
    text.text = name
    text.font_size = 58
    text.pixel_size = 0.12
    text.modulate = tint.lightened(0.35)
    text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    text.position = Vector3(0,90,0)
    group.add_child(text)
    var light := OmniLight3D.new()
    light.light_color = tint
    light.light_energy = 3.0
    light.omni_range = 115.0
    light.position.y = 44.0
    group.add_child(light)
    if index==0:
        _box(Vector3(0,9,0),Vector3(115,2,115),_mat(Color(0.26,0.75,1.0),1.2),group)

func _build_starfield() -> void:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    var unit := SphereMesh.new()
    unit.radius = 0.45
    unit.height = 0.9
    mm.mesh = unit
    mm.instance_count = 430
    var node := MultiMeshInstance3D.new()
    node.name = "DistantStars"
    node.multimesh = mm
    node.material_override = _mat(Color(0.55,0.80,1.0),2.0)
    add_child(node)
    for i in 430:
        var v := Vector3(rng.randf_range(-1850,1850),rng.randf_range(185,620),rng.randf_range(-1850,1850))
        mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,v))

func _spawn_player() -> void:
    ship = ShipScript.new()
    ship.name = "PlayerShip"
    ship.global_position = Vector3(0,19,78)
    add_child(ship)
    ship.fired.connect(_on_ship_fire)
    chase_camera = Camera3D.new()
    chase_camera.current = true
    chase_camera.fov = 72.0
    add_child(chase_camera)
    chase_camera.global_position = ship.global_position+Vector3(0,9,25)

func _spawn_civilians_and_pirates() -> void:
    for i in 22:
        var drone = DroneScript.new()
        drone.hostile = i%4==0
        drone.speed = 21.0 if drone.hostile else 11.0
        drone.target = ship
        var sec: Vector3 = SECTOR_POSITIONS[i%SECTOR_POSITIONS.size()]
        drone.position = sec+Vector3(rng.randf_range(-140,140),rng.randf_range(13,60),rng.randf_range(-140,140))
        drone.destroyed.connect(_on_drone_destroyed)
        drone.fired.connect(_on_drone_fire)
        add_child(drone)
        drones.append(drone)

func _make_hud() -> void:
    var ui := CanvasLayer.new()
    ui.layer = 5
    add_child(ui)
    var surface := Control.new()
    surface.set_anchors_preset(Control.PRESET_FULL_RECT)
    surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(surface)
    var block := PanelContainer.new()
    block.set_anchors_preset(Control.PRESET_TOP_LEFT)
    block.offset_left = 22
    block.offset_top = 22
    block.offset_right = 480
    block.offset_bottom = 167
    var frame := StyleBoxFlat.new()
    frame.bg_color = Color(0.025,0.085,0.16,0.91)
    frame.border_color = Color(0.55,0.8,0.95,0.65)
    frame.set_border_width_all(1)
    frame.set_corner_radius_all(12)
    frame.content_margin_left = 17
    frame.content_margin_right = 17
    frame.content_margin_top = 14
    frame.content_margin_bottom = 12
    block.add_theme_stylebox_override("panel",frame)
    surface.add_child(block)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation",9)
    block.add_child(stack)
    hud_mission = Label.new()
    hud_mission.add_theme_font_size_override("font_size",25)
    hud_mission.add_theme_color_override("font_color",Color(1.0,0.88,0.62))
    stack.add_child(hud_mission)
    hud_status = Label.new()
    hud_status.add_theme_font_size_override("font_size",15)
    hud_status.add_theme_color_override("font_color",Color(0.86,0.95,1.0))
    stack.add_child(hud_status)
    hud_controls = Label.new()
    hud_controls.text = "WASD — полёт    Q / E — высота    Shift — форсаж    Space — огонь    F5 — сохранить"
    hud_controls.add_theme_font_size_override("font_size",16)
    hud_controls.add_theme_color_override("font_color",Color(0.81,0.91,1.0))
    hud_controls.position = Vector2(22,640)
    surface.add_child(hud_controls)
    radar = RadarScript.new()
    radar.name = "WaypointRadar"
    radar.position = Vector2(20, 430)
    surface.add_child(radar)
    hud_notice = Label.new()
    hud_notice.add_theme_font_size_override("font_size",30)
    hud_notice.add_theme_color_override("font_color",Color(1.0,0.83,0.47))
    hud_notice.position = Vector2(510,55)
    surface.add_child(hud_notice)

func _process(delta: float) -> void:
    if not is_instance_valid(ship): return
    world_timer += delta
    world_pulse += delta
    if world_pulse > 92.0 and mission_index > 0 and ship.global_position.distance_to(SECTOR_POSITIONS[0]) > 270.0:
        world_pulse = 0.0
        _spawn_pirate_ambush()
    notice_timer = maxf(0.0, notice_timer-delta)
    if notice_timer <= 0.0: hud_notice.text = ""
    var basis: Basis = ship.global_transform.basis
    var ideal: Vector3 = ship.global_position + basis.z*camera_distance + Vector3(0,10.0,0)
    chase_camera.global_position = chase_camera.global_position.lerp(ideal,minf(1.0,delta*3.3))
    chase_camera.look_at(ship.global_position + Vector3(0,2.0,0),Vector3.UP)
    _mission_tick(delta)
    if ship.hull <= 0.0:
        ship.global_position = Vector3(0,20,75)
        ship.velocity = Vector3.ZERO
        ship.shield = 100.0
        ship.hull = 100.0
        credits = maxi(0,credits-220)
        _show_notice("КОРАБЛЬ ВОССТАНОВЛЕН · -220 CR")
    elif ship.global_position.distance_to(Vector3(0,19,78))<70:
        ship.shield = minf(100.0,ship.shield+12.0*delta)
        ship.hull = minf(100.0,ship.hull+4.0*delta)
    _update_hud()
    if is_instance_valid(radar):
        radar.player_position = ship.global_position
        radar.player_forward = -ship.global_transform.basis.z
        radar.has_objective = mission_index < MISSIONS.size()
        if radar.has_objective: radar.objective = MISSIONS[mission_index]["position"]
        radar.targets.clear()
        for n in drones:
            if is_instance_valid(n) and n.hostile and n.global_position.distance_to(ship.global_position) < 460.0:
                radar.targets.append(n.global_position)
        radar.queue_redraw()
    if world_timer>=25.0:
        world_timer=0.0
        _save_progress()

func _mission_tick(_dt: float) -> void:
    if mission_index>=MISSIONS.size():return
    var mission: Dictionary = MISSIONS[mission_index]
    var target: Vector3 = mission["position"]
    if mission["type"]=="reach" and ship.global_position.distance_to(target)<47.0:
        _complete_mission()
    elif mission["type"]=="combat" and mission_started and mission_enemies<=0:
        _complete_mission()

func _start_mission() -> void:
    mission_started = false
    mission_enemies = 0
    if is_instance_valid(mission_beacon):mission_beacon.queue_free()
    if mission_index>=MISSIONS.size():
        _show_notice("СЮЖЕТ ЗАВЕРШЁН · СВОБОДНЫЙ ПОЛЁТ")
        return
    var data: Dictionary = MISSIONS[mission_index]
    var beacon := Node3D.new()
    beacon.name = "MissionBeacon"
    beacon.position = data["position"]
    var sphere := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius=4.8
    mesh.height=9.6
    sphere.mesh=mesh
    sphere.material_override=_mat(Color(1.0,0.72,0.28),3.0)
    beacon.add_child(sphere)
    var lamp := OmniLight3D.new()
    lamp.omni_range=55.0
    lamp.light_energy=3.0
    lamp.light_color=Color(1.0,0.74,0.32)
    beacon.add_child(lamp)
    add_child(beacon)
    mission_beacon=beacon
    if data["type"]=="combat":
        mission_started=true
        mission_enemies=3 if mission_index==2 else 5
        for i in mission_enemies:
            var drone = DroneScript.new()
            drone.hostile=true
            drone.health=17.0 if mission_index==5 else 9.0
            drone.target=ship
            drone.position=data["position"]+Vector3(float(i-2)*14.0,3.0,float(i%2)*17.0)
            drone.destroyed.connect(_on_mission_drone_destroyed)
            drone.fired.connect(_on_drone_fire)
            add_child(drone)
            drones.append(drone)

func _complete_mission() -> void:
    var data: Dictionary = MISSIONS[mission_index]
    credits+=int(data["reward"])
    xp+=150+mission_index*65
    mission_index+=1
    _show_notice("МИССИЯ ВЫПОЛНЕНА · +"+str(data["reward"])+" CR")
    _save_progress()
    _start_mission()

func _on_drone_destroyed(drone: Node3D) -> void:
    drones.erase(drone)
    credits+=45

func _on_mission_drone_destroyed(drone: Node3D) -> void:
    mission_enemies=maxi(0,mission_enemies-1)
    _on_drone_destroyed(drone)

func _on_drone_fire(from: Vector3, to: Vector3) -> void:
    if not is_instance_valid(ship):return
    _laser_effect_colored(from,to,Color(1.0,0.26,0.39))
    if from.distance_to(ship.global_position)<250.0 and ship.global_position.distance_to(to)<7.0:
        ship.take_damage(8.0)

func _spawn_pirate_ambush() -> void:
    var nearby := 0
    for n in drones:
        if is_instance_valid(n) and n.hostile: nearby += 1
    if nearby >= 14:return
    for i in 3:
        var raider = DroneScript.new()
        raider.hostile = true
        raider.health = 10.0
        raider.speed = 26.0
        raider.target = ship
        raider.position = ship.global_position + Vector3(float(i-1)*42.0, 3.0, -115.0)
        raider.destroyed.connect(_on_drone_destroyed)
        raider.fired.connect(_on_drone_fire)
        add_child(raider)
        drones.append(raider)
    world_events += 1
    _show_notice("СОБЫТИЕ В МИРЕ · ПИРАТСКАЯ ЭСКАДРИЛЬЯ")

func _on_ship_fire(origin: Vector3, direction: Vector3) -> void:
    var endpoint: Vector3 = origin+direction*180.0
    var best_distance: float = 180.0
    var best
    for candidate in drones:
        if not is_instance_valid(candidate): continue
        var offset: Vector3 = candidate.global_position-origin
        var along: float = offset.dot(direction)
        if along<0.0 or along>best_distance: continue
        if offset.cross(direction).length()<=5.2:
            best_distance=along
            best=candidate
    if is_instance_valid(best):
        endpoint=best.global_position
        best.call("hit",2.0+float(ship.weapon_rank))
    _laser_effect(origin,endpoint)

func _laser_effect(a: Vector3,b: Vector3) -> void:
    _laser_effect_colored(a,b,Color(0.25,0.95,1.0))

func _laser_effect_colored(a: Vector3,b: Vector3,tint: Color) -> void:
    var distance: float = a.distance_to(b)
    if distance<0.01:return
    var shaft:=MeshInstance3D.new()
    var tube:=CylinderMesh.new()
    tube.top_radius=0.15
    tube.bottom_radius=0.15
    tube.height=distance
    shaft.mesh=tube
    shaft.material_override=_mat(tint,3.8)
    add_child(shaft)
    shaft.global_position=(a+b)*0.5
    shaft.look_at(b,Vector3.UP)
    shaft.rotate_object_local(Vector3.RIGHT,PI*0.5)
    get_tree().create_timer(0.12).timeout.connect(func()->void:
        if is_instance_valid(shaft):shaft.queue_free()
    )

func _show_notice(message: String) -> void:
    if not is_instance_valid(hud_notice):return
    hud_notice.text=message
    last_notice = message
    notice_timer=3.3

func _update_hud() -> void:
    if not is_instance_valid(hud_status):return
    if mission_index>=MISSIONS.size():
        hud_mission.text="НЕБУЛА · СВОБОДНЫЙ МИР"
        hud_status.text="Сюжет завершён. Исследуй шесть районов.\nКредиты: %d   XP: %d   Щит: %d%%   Корпус: %d%%" % [credits,xp,roundi(ship.shield),roundi(ship.hull)]
    else:
        var m: Dictionary=MISSIONS[mission_index]
        var d: int=roundi(ship.global_position.distance_to(m["position"]))
        hud_mission.text="%02d · %s" % [mission_index+1,m["title"]]
        hud_status.text="%s · %d м\nКредиты: %d   XP: %d   Щит: %d%%   Корпус: %d%%   Форсаж: %d%%" % [m["hint"],d,credits,xp,roundi(ship.shield),roundi(ship.hull),roundi(ship.boost)]

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode==KEY_F5:
            _save_progress()
            _show_notice("ИГРА СОХРАНЕНА")
        elif event.keycode==KEY_F2:
            lens_mode=(lens_mode+1)%3
            camera_distance=[16.0,24.0,33.0][lens_mode]
            _show_notice("КАМЕРА · " + str(lens_mode+1) + "/3")
        elif event.keycode==KEY_1 or event.keycode==KEY_2 or event.keycode==KEY_3:
            _upgrade_docked(event.keycode-KEY_1)
        elif event.keycode==KEY_F1:
            _show_notice("WASD ПОЛЁТ · Q/E ВЫСОТА · SHIFT ФОРСАЖ · SPACE ОГОНЬ")

func _upgrade_docked(slot: int) -> void:
    if ship.global_position.distance_to(SECTOR_POSITIONS[0])>115.0:
        _show_notice("УЛУЧШЕНИЯ ТОЛЬКО В ПОРТУ АВРОРА")
        return
    var price: int = 600 + (ship.engine_rank if slot == 0 else ship.weapon_rank if slot == 1 else 0)*500
    if credits<price:
        _show_notice("НЕДОСТАТОЧНО КРЕДИТОВ · %d CR" % price)
        return
    if slot == 2:
        if ship.hull >= 99.0 and ship.shield >= 99.0:return
        ship.hull=100.0
        ship.shield=100.0
    elif slot==0:
        if ship.engine_rank>=4:return
        ship.engine_rank+=1
    else:
        if ship.weapon_rank>=4:return
        ship.weapon_rank+=1
    credits-=price
    _save_progress()
    _show_notice("АНГАР · УЛУЧШЕНИЕ УСТАНОВЛЕНО")

func _safe_float(value: Variant, fallback: float) -> float:
    if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
        return fallback
    var number: float = float(value)
    return number if is_finite(number) else fallback

func _save_progress() -> void:
    var file:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if file==null:return
    file.store_string(JSON.stringify({"version":1,"credits":credits,"xp":xp,"mission":mission_index,"player_x":ship.global_position.x,"player_y":ship.global_position.y,"player_z":ship.global_position.z,"engine_rank":ship.engine_rank,"weapon_rank":ship.weapon_rank}))
    file.close()

func _load_progress() -> void:
    if not FileAccess.file_exists(SAVE_PATH):return
    var file:=FileAccess.open(SAVE_PATH,FileAccess.READ)
    if file==null:return
    var raw=JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(raw)!=TYPE_DICTIONARY or raw.get("version",0)!=1:return
    mission_index=clampi(int(_safe_float(raw.get("mission",0),0.0)),0,MISSIONS.size())
    credits=clampi(int(_safe_float(raw.get("credits",950),950.0)),0,99999999)
    xp=clampi(int(_safe_float(raw.get("xp",0),0.0)),0,99999999)
    ship.engine_rank=clampi(int(_safe_float(raw.get("engine_rank",0),0.0)),0,4)
    ship.weapon_rank=clampi(int(_safe_float(raw.get("weapon_rank",0),0.0)),0,4)
    ship.global_position=Vector3(clampf(_safe_float(raw.get("player_x",0),0.0),-1700,1700),clampf(_safe_float(raw.get("player_y",19),19.0),4,160),clampf(_safe_float(raw.get("player_z",78),78.0),-1700,1700))

# Godot 4.7 source contract: procedural skyline, mission radar, enemy weapons, harbor upgrades.
