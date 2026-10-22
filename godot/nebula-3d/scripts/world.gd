extends Node3D
## NEBULA ASCENSION 3D: experimental standalone Godot 4 vertical slice.
## Built from procedural geometry; it does not share browser v4 save data.

const ShipScript = preload("res://scripts/ship.gd")
const DroneScript = preload("res://scripts/drone.gd")
const RadarScript = preload("res://scripts/radar.gd")
const PremiumArchitectureScript = preload("res://scripts/premium_architecture.gd")
const ArchitecturalDetailR4Script = preload("res://scripts/architectural_detail_r4.gd")
const CitySetDressingR5Script = preload("res://scripts/city_set_dressing_r5.gd")
const OrbitalDocksR6Script = preload("res://scripts/orbital_docks_r6.gd")
const SculpturalSkylineR6Script = preload("res://scripts/sculptural_skyline_r6.gd")
const CapitalFleetR7Script = preload("res://scripts/capital_fleet_r7.gd")
const OrbitalIndustryR9Script = preload("res://scripts/orbital_industry_r9.gd")
const AegisMegadockR10Script = preload("res://scripts/aegis_megadock_r10.gd")
const CityCladdingR10Script = preload("res://scripts/city_cladding_r10.gd")
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
var camera_distance: float = 16.0
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
var premium_architecture
var cinematic_shake: float = 0.0
var cinematic_velocity: Vector3 = Vector3.ZERO
var hud_flight: Label
var hud_objective: Label
var hud_panel: PanelContainer
var hud_canvas: CanvasLayer
var aegis_r10
var city_cladding_r10
var graphics_quality: int = 0

func _ready() -> void:
    rng.seed = 20261022
    _setup_environment()
    _build_city()
    _spawn_player()
    _spawn_civilians_and_pirates()
    _make_hud()
    _load_progress()
    _start_mission()
    _show_notice("NEBULA ASCENSION · CINEMATIC 3D")
    get_viewport().size_changed.connect(_fit_hud)
    _fit_hud()

func _setup_environment() -> void:
    var node := WorldEnvironment.new()
    var env := Environment.new()
    # A cinematic sky and softer physical light, without unsupported Web-only SSR effects.
    var sky := Sky.new()
    var atmosphere := ProceduralSkyMaterial.new()
    atmosphere.sky_top_color = Color(0.008,0.024,0.078)
    atmosphere.sky_horizon_color = Color(0.115,0.18,0.28)
    atmosphere.ground_bottom_color = Color(0.008,0.012,0.028)
    atmosphere.ground_horizon_color = Color(0.10,0.15,0.24)
    sky.sky_material = atmosphere
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.46
    env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.11,0.18,0.26)
    env.fog_density = 0.00044
    node.environment = env
    add_child(node)
    var sun := DirectionalLight3D.new()
    sun.name = "OrbitalSun"
    sun.rotation_degrees = Vector3(-34.0,-52.0,0.0)
    sun.light_color = Color(1.0,0.85,0.70)
    sun.light_energy = 1.82
    sun.shadow_enabled = true
    add_child(sun)
    var fill := DirectionalLight3D.new()
    fill.name = "DeepBlueFill"
    fill.rotation_degrees = Vector3(-18,128,0)
    fill.light_color = Color(0.22,0.48,1.0)
    fill.light_energy = 0.45
    add_child(fill)
    var deck := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(4100,4100)
    deck.mesh = plane
    deck.material_override = _mat(Color(0.023,0.040,0.075))
    deck.position.y = -5.0
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
    premium_architecture = PremiumArchitectureScript.new()
    premium_architecture.name = "PremiumArchitecture"
    add_child(premium_architecture)
    var tower_material: StandardMaterial3D = premium_architecture.make_facade_material()
    var tower_data: Array[Dictionary] = []
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
    var glow_material := _mat(Color.WHITE, 0.42)
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
        tower_data.append({"pos":pos,"w":w,"depth":depth,"h":height,"sector":sector})
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
    premium_architecture.build(tower_data,SECTOR_POSITIONS,SECTOR_COLORS)
    var architectural_detail_r4 := ArchitecturalDetailR4Script.new()
    architectural_detail_r4.name = "ArchitecturalDetailR4"
    add_child(architectural_detail_r4)
    architectural_detail_r4.build(tower_data, SECTOR_POSITIONS)
    var detail_r5 := CitySetDressingR5Script.new()
    detail_r5.name = "HighDetailCityR5"
    add_child(detail_r5)
    detail_r5.build(tower_data, SECTOR_POSITIONS)
    var docks_r6 := OrbitalDocksR6Script.new()
    docks_r6.name = "HeroMegadocksR6"
    add_child(docks_r6)
    docks_r6.build(SECTOR_POSITIONS, SECTOR_COLORS)
    var skyline_r6 := SculpturalSkylineR6Script.new()
    skyline_r6.name = "SculpturalSkylineR6"
    add_child(skyline_r6)
    skyline_r6.build(SECTOR_POSITIONS, SECTOR_COLORS)
    var fleet_r7 := CapitalFleetR7Script.new()
    fleet_r7.name = "CapitalFleetR7"
    add_child(fleet_r7)
    fleet_r7.build(SECTOR_POSITIONS)
    var industry_r9 := OrbitalIndustryR9Script.new()
    industry_r9.name = "OrbitalIndustryR9"
    add_child(industry_r9)
    industry_r9.build(SECTOR_POSITIONS)
    aegis_r10 = AegisMegadockR10Script.new()
    aegis_r10.name = "AegisMegadocksR10"
    add_child(aegis_r10)
    aegis_r10.build(SECTOR_POSITIONS)
    city_cladding_r10 = CityCladdingR10Script.new()
    city_cladding_r10.name = "R10_ArchitecturalCladding"
    add_child(city_cladding_r10)
    city_cladding_r10.build(tower_data, SECTOR_POSITIONS)
    _build_starfield()

func _build_sector(center: Vector3, tint: Color, name: String, index: int) -> void:
    # Landmark navigation tower; premium_architecture builds the actual dock.
    # R2's enormous emission toruses have been removed: they crossed the camera
    # and blew out the full frame on WebGL.
    var group := Node3D.new()
    group.name = name
    group.position = center + Vector3(91.0,0,-88.0)
    add_child(group)
    _box(Vector3(0,26,0),Vector3(12,52,12),_mat(Color(0.09,0.15,0.22)),group)
    _box(Vector3(0,55,0),Vector3(19,7,19),_mat(tint.darkened(0.28),0.40),group)
    _box(Vector3(0,74,0),Vector3(4,33,4),_mat(Color(0.12,0.23,0.34)),group)
    _box(Vector3(0,91,0),Vector3(8,2,8),_mat(tint,1.4),group)
    for side in [-1.0,1.0]:
        _box(Vector3(side*11,28,0),Vector3(1.2,42,4),_mat(tint.darkened(0.3),0.65),group)
    var text := Label3D.new()
    text.text = name
    text.font_size = 50
    text.pixel_size = 0.085
    text.modulate = tint.lightened(0.28)
    text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    text.position = Vector3(0,111,0)
    group.add_child(text)
    var light := OmniLight3D.new()
    light.light_color = tint
    light.light_energy = 1.15
    light.omni_range = 50.0
    light.position.y = 60.0
    group.add_child(light)

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
    chase_camera.fov = 63.0
    add_child(chase_camera)
    chase_camera.global_position = ship.global_position+Vector3(0,7,21)

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
    hud_canvas = ui
    var surface := Control.new()
    surface.set_anchors_preset(Control.PRESET_FULL_RECT)
    surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(surface)
    var block := PanelContainer.new()
    block.set_anchors_preset(Control.PRESET_TOP_LEFT)
    block.offset_left = 22
    block.offset_top = 22
    block.offset_right = 560
    block.offset_bottom = 168
    var frame := StyleBoxFlat.new()
    frame.bg_color = Color(0.018,0.038,0.074,0.87)
    frame.border_color = Color(0.67,0.77,0.92,0.38)
    frame.set_border_width_all(1)
    frame.set_corner_radius_all(12)
    frame.content_margin_left = 17
    frame.content_margin_right = 17
    frame.content_margin_top = 14
    frame.content_margin_bottom = 12
    block.add_theme_stylebox_override("panel",frame)
    surface.add_child(block)
    hud_panel = block
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation",9)
    block.add_child(stack)
    hud_mission = Label.new()
    hud_mission.add_theme_font_size_override("font_size",26)
    hud_mission.add_theme_color_override("font_color",Color(0.99,0.81,0.50))
    stack.add_child(hud_mission)
    hud_status = Label.new()
    hud_status.add_theme_font_size_override("font_size",15)
    hud_status.add_theme_color_override("font_color",Color(0.86,0.95,1.0))
    stack.add_child(hud_status)
    hud_controls = Label.new()
    hud_controls.text = "WASD — полёт    Q/E — высота    Shift — форсаж    Space — огонь    F3 — качество    F4 — HUD    F5 — сохранить"
    hud_controls.add_theme_font_size_override("font_size",15)
    hud_controls.add_theme_color_override("font_color",Color(0.81,0.91,1.0))
    hud_controls.anchor_top=1.0
    hud_controls.anchor_bottom=1.0
    hud_controls.offset_left=28.0
    hud_controls.offset_top=-49.0
    hud_controls.offset_right=1150.0
    hud_controls.offset_bottom=-17.0
    surface.add_child(hud_controls)
    radar = RadarScript.new()
    radar.name = "WaypointRadar"
    radar.anchor_top = 1.0
    radar.anchor_bottom = 1.0
    radar.offset_left = 16.0
    radar.offset_right = 236.0
    radar.offset_top = -282.0
    radar.offset_bottom = -62.0
    surface.add_child(radar)
    hud_flight = Label.new()
    hud_flight.text = "REMIX ARENA   /   NEBULA ASCENSION"
    hud_flight.add_theme_font_size_override("font_size",17)
    hud_flight.add_theme_color_override("font_color",Color(0.82,0.90,1.0))
    hud_flight.anchor_left=1.0
    hud_flight.anchor_right=1.0
    hud_flight.offset_left=-458.0
    hud_flight.offset_right=-23.0
    hud_flight.offset_top=27.0
    hud_flight.offset_bottom=57.0
    hud_flight.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    surface.add_child(hud_flight)
    hud_objective = Label.new()
    hud_objective.add_theme_font_size_override("font_size",19)
    hud_objective.add_theme_color_override("font_color",Color(0.99,0.82,0.49))
    hud_objective.anchor_left=1.0
    hud_objective.anchor_right=1.0
    hud_objective.offset_left=-450.0
    hud_objective.offset_right=-24.0
    hud_objective.offset_top=66.0
    hud_objective.offset_bottom=101.0
    hud_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    surface.add_child(hud_objective)
    hud_notice = Label.new()
    hud_notice.add_theme_font_size_override("font_size",30)
    hud_notice.add_theme_color_override("font_color",Color(1.0,0.83,0.47))
    hud_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
    hud_notice.offset_left=-250.0
    hud_notice.offset_top=160.0
    hud_notice.offset_right=250.0
    hud_notice.offset_bottom=210.0
    hud_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
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
    var speed: float = ship.velocity.length()
    var desired_distance: float = camera_distance + minf(6.0,speed*0.06)
    var desired_height: float = 5.5 + minf(3.0,speed*0.025)
    var ideal: Vector3 = ship.global_position + basis.z*desired_distance + Vector3(0,desired_height,0)
    chase_camera.global_position = chase_camera.global_position.lerp(ideal,minf(1.0,delta*4.0))
    chase_camera.look_at(ship.global_position - basis.z*12.0 + Vector3(0,2.0,0),Vector3.UP)
    chase_camera.fov = lerpf(chase_camera.fov,66.0 + minf(9.0,speed*0.12),minf(1.0,delta*1.4))
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
        hud_objective.text = "ИССЛЕДОВАНИЕ ШЕСТИ РАЙОНОВ"
        hud_mission.text="НЕБУЛА · СВОБОДНЫЙ МИР"
        hud_status.text="Сюжет завершён. Исследуй шесть районов.\nКредиты: %d   XP: %d   Щит: %d%%   Корпус: %d%%" % [credits,xp,roundi(ship.shield),roundi(ship.hull)]
    else:
        var m: Dictionary=MISSIONS[mission_index]
        var d: int=roundi(ship.global_position.distance_to(m["position"]))
        hud_mission.text="%02d · %s" % [mission_index+1,m["title"]]
        hud_objective.text="ЦЕЛЬ МИССИИ · %d М" % d
        hud_status.text="%s · %d м\nКредиты: %d   XP: %d   Щит: %d%%   Корпус: %d%%   Форсаж: %d%%" % [m["hint"],d,credits,xp,roundi(ship.shield),roundi(ship.hull),roundi(ship.boost)]

func _fit_hud() -> void:
    var width: float = get_viewport().get_visible_rect().size.x
    if width < 820.0:
        if is_instance_valid(hud_panel):
            hud_panel.offset_left=8.0
            hud_panel.offset_top=7.0
            hud_panel.offset_right=minf(460.0,width-8.0)
            hud_panel.offset_bottom=125.0
        if is_instance_valid(hud_mission):hud_mission.add_theme_font_size_override("font_size",19)
        if is_instance_valid(hud_status):hud_status.add_theme_font_size_override("font_size",12)
        if is_instance_valid(radar):
            radar.scale=Vector2(0.77,0.77)
            radar.offset_top=-228.0
        hud_controls.visible = false
        if is_instance_valid(hud_flight):hud_flight.visible = false
        if is_instance_valid(hud_objective):
            hud_objective.offset_left=-230.0
            hud_objective.add_theme_font_size_override("font_size",13)
    else:
        if is_instance_valid(hud_panel):
            hud_panel.offset_left=22.0
            hud_panel.offset_top=22.0
            hud_panel.offset_right=560.0
            hud_panel.offset_bottom=168.0
        if is_instance_valid(hud_mission):hud_mission.add_theme_font_size_override("font_size",26)
        if is_instance_valid(hud_status):hud_status.add_theme_font_size_override("font_size",15)
        if is_instance_valid(radar):
            radar.scale=Vector2.ONE
            radar.offset_top=-282.0
        hud_controls.visible = true
        if is_instance_valid(hud_flight):hud_flight.visible = true
        if is_instance_valid(hud_objective):
            hud_objective.offset_left=-450.0
            hud_objective.add_theme_font_size_override("font_size",19)

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode==KEY_F5:
            _save_progress()
            _show_notice("ИГРА СОХРАНЕНА")
        elif event.keycode==KEY_F2:
            lens_mode=(lens_mode+1)%3
            camera_distance=[14.5,23.0,33.0][lens_mode]
            _show_notice("КАМЕРА · " + str(lens_mode+1) + "/3")
        elif event.keycode==KEY_F3:
            _set_graphics_quality((graphics_quality+1)%3)
        elif event.keycode==KEY_F4:
            hud_canvas.visible = not hud_canvas.visible
        elif event.keycode==KEY_1 or event.keycode==KEY_2 or event.keycode==KEY_3:
            _upgrade_docked(event.keycode-KEY_1)
        elif event.keycode==KEY_F1:
            _show_notice("WASD ПОЛЁТ · Q/E ВЫСОТА · SHIFT ФОРСАЖ · SPACE ОГОНЬ")

func _set_graphics_quality(mode: int) -> void:
    graphics_quality = clampi(mode, 0, 2)
    if is_instance_valid(aegis_r10):
        aegis_r10.set_quality(graphics_quality)
    if is_instance_valid(city_cladding_r10):
        city_cladding_r10.set_quality(graphics_quality)
    _show_notice("ГРАФИКА · " + ["МАКСИМУМ", "ВЫСОКАЯ", "ОПТИМИЗАЦИЯ"][graphics_quality])

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
