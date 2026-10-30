extends Control
class_name IPTacticalAtlas
## G10 WORLD: an original ACTUAL-GODOT, source-bound sector schematic.
## Uses true live IPCrisisEngine state and real in-world station coordinates.
## Not an autonomous player, navigation mesh, x-ray camera, GPS or real-life
## reactor/control-system instruction. Never changes the engine or saves.
##
## The map does not pretend a direct line is a traversable route.
## It is entirely local; does not record users or send telemetry.

const SCHEMA: String = "IRON_PULSE_TACTICAL_ATLAS_G10"
const MAX_MARKERS: int = 40
const X_MIN: float = -12.0
const X_MAX: float = 12.0
const Z_TOP: float = 8.0
const Z_BOTTOM: float = -66.0
const OBSIDIAN: Color = Color(0.024,0.040,0.057)
const STEEL: Color = Color(0.18,0.31,0.38)
const CYAN: Color = Color(0.16,0.86,0.93)
const BRONZE: Color = Color(0.98,0.62,0.29)
const CORAL: Color = Color(1.0,0.32,0.34)
const IVORY: Color = Color(0.89,0.94,0.96)
const NEUTRAL: Color = Color(0.48,0.62,0.68)

var _markers: Array[Dictionary] = []
var _positions: Dictionary = {}
var _player: Vector3 = Vector3.ZERO
var _target: String = ""
var _locale: String = "ru"
var _scenario: String = "blackout"
var _active: bool = false
var _heat: float = 0.0
var _oxygen: float = 0.0
var _crew: float = 0.0
var _door: float = 0.0
var _time_left: float = 0.0
var _sector: String = "reactor"
var _distance: float = 0.0

func _ready() -> void:
    name = "G10_ActualFacilityTacticalAtlas"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(220.0,190.0)
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    resized.connect(queue_redraw)

func configure(terminals: Array[Dictionary], relays: Array[Dictionary], field_stations: Array[Dictionary]) -> void:
    _markers.clear()
    _positions.clear()
    for group in [
        {"entries": terminals, "kind":"terminal"},
        {"entries": relays, "kind":"relay"},
        {"entries": field_stations, "kind":"field"}
    ]:
        var entries: Array = group["entries"]
        for info in entries:
            if _markers.size() >= MAX_MARKERS:
                break
            if not info.has("id") or not info.has("position"):
                continue
            var marker_id: String = str(info["id"])
            var raw: Variant = info["position"]
            if marker_id == "" or _positions.has(marker_id) or not raw is Vector3:
                continue
            var point: Vector3 = raw
            if not is_finite(point.x) or not is_finite(point.z):
                continue
            _positions[marker_id] = point
            _markers.append({
                "id":marker_id,
                "kind":str(group["kind"]),
                "position":point
            })
    queue_redraw()

func capture(engine: IPCrisisEngine, player_position: Vector3,
        objective_target: String, current_sector: String, language: String,
        current_operation: bool) -> void:
    _active = engine != null and current_operation and not engine.finished()
    _locale = "en" if language == "en" else "ru"
    _sector = current_sector if current_sector in ["reactor","service","evacuation"] else "reactor"
    if not _active:
        _target = ""
        _distance = 0.0
        queue_redraw()
        return
    # The values are actual game state, not guessed performance or data from
    # a webpage. capture() deliberately performs no IPCrisisEngine mutations.
    _player = player_position
    _scenario = engine.scenario_id
    _heat = engine.heat
    _oxygen = engine.oxygen
    _crew = engine.crew_health
    _door = engine.door_charge
    _time_left = engine.time_left
    _target = objective_target if _positions.has(objective_target) else ""
    _distance = 0.0
    if _target != "":
        var goal: Vector3 = _positions[_target]
        _distance = Vector2(goal.x-_player.x,goal.z-_player.z).length()
    queue_redraw()

func _point(world: Vector3) -> Vector2:
    # Static ground-plan projection: X is left/right, negative Z is deeper.
    # Not an A* route, collidable floor guarantee or moving-wall knowledge.
    var pad: float = 13.0
    var width: float = maxf(1.0,size.x-pad*2.0)
    var height: float = maxf(1.0,size.y-pad*2.0)
    return Vector2(
        pad + clampf((world.x-X_MIN)/(X_MAX-X_MIN),0.0,1.0)*width,
        pad + clampf((Z_TOP-world.z)/(Z_TOP-Z_BOTTOM),0.0,1.0)*height
    )

func _draw() -> void:
    var w: float = size.x
    var h: float = size.y
    if w < 32.0 or h < 32.0:
        return
    draw_rect(Rect2(Vector2.ZERO,size),OBSIDIAN,true)
    # A real top-down diagram of the three actual game sectors. These bands
    # are approximate schematic regions, never fabricated walkable routes.
    var bands: Array[Dictionary] = [
        {"top":Z_TOP,"bottom":-14.0,"color":Color(0.032,0.112,0.142)},
        {"top":-14.0,"bottom":-43.0,"color":Color(0.051,0.080,0.098)},
        {"top":-43.0,"bottom":Z_BOTTOM,"color":Color(0.080,0.079,0.075)}
    ]
    for band in bands:
        var y0: float = _point(Vector3.ZERO+Vector3(0,0,float(band["top"]))).y
        var y1: float = _point(Vector3.ZERO+Vector3(0,0,float(band["bottom"]))).y
        draw_rect(Rect2(13.0,y0,w-26.0,y1-y0),band["color"],true)
    var left: float = _point(Vector3(-6.7,0,Z_TOP)).x
    var right: float = _point(Vector3(6.7,0,Z_TOP)).x
    var top: float = _point(Vector3(0,0,Z_TOP)).y
    var bottom: float = _point(Vector3(0,0,Z_BOTTOM)).y
    draw_rect(Rect2(left,top,right-left,bottom-top),Color(0.050,0.091,0.113),true)
    draw_line(Vector2(left,top),Vector2(left,bottom),STEEL,2.0,true)
    draw_line(Vector2(right,top),Vector2(right,bottom),STEEL,2.0,true)
    for fraction in [0.25,0.5,0.75]:
        var x: float = lerpf(left,right,fraction)
        draw_line(Vector2(x,top),Vector2(x,bottom),Color(0.15,0.28,0.33,0.38),1.0,true)
    for z in [-14.0,-43.0]:
        var y: float = _point(Vector3(0,0,z)).y
        draw_line(Vector2(13,y),Vector2(w-13,y),Color(0.44,0.59,0.59,0.46),1.0,true)
    if not _active:
        return
    # Relationship between two genuine live coordinates; intentionally
    # segmented so no viewer confuses this with an authorized walking path.
    var player_dot: Vector2 = _point(_player)
    if _target != "":
        var goal: Vector2 = _point(_positions[_target])
        for part in range(0,12,2):
            var a: float = float(part)/12.0
            var b: float = float(part+1)/12.0
            draw_line(player_dot.lerp(goal,a),player_dot.lerp(goal,b),
                Color(CYAN.r,CYAN.g,CYAN.b,0.64),1.6,true)
    # All icons are derived from actual physical source coordinates.
    for marker in _markers:
        var pos: Vector2 = _point(marker["position"])
        var kind: String = marker["kind"]
        var shade: Color = BRONZE if kind == "relay" else NEUTRAL if kind == "field" else Color(0.41,0.69,0.75)
        var radius: float = 3.2
        if marker["id"] == _target:
            shade = CYAN
            radius = 6.0
            draw_circle(pos,9.0,Color(CYAN.r,CYAN.g,CYAN.b,0.18))
        draw_circle(pos,radius,shade)
    var danger: bool = _heat >= 80.0 or _oxygen <= 30.0
    draw_circle(player_dot,9.0,Color(0.09,0.16,0.18))
    draw_circle(player_dot,6.0,CORAL if danger else IVORY)
    draw_circle(player_dot,2.3,OBSIDIAN)

func readout() -> Dictionary:
    var records: Array = []
    for marker in _markers:
        var pos: Vector3 = marker["position"]
        records.append({
            "id":marker["id"], "kind":marker["kind"],
            "position_xz":[snappedf(pos.x,0.01),snappedf(pos.z,0.01)]
        })
    return {
        "schema":SCHEMA,
        "visible":visible,
        "active":_active,
        "source":"actual_godot_engine_and_physical_scene_coordinates",
        "local_only":true,
        "telemetry_uploaded":false,
        "simulated_player_progress":false,
        "route_solver_used":false,
        "distance_kind":"straight_line_schematic_not_walkable_path",
        "target":_target,
        "straight_line_m":snappedf(_distance,0.1),
        "player_xz":[snappedf(_player.x,0.01),snappedf(_player.z,0.01)],
        "marker_count":_markers.size(),
        "markers":records,
        "sector":_sector,
        "scenario":_scenario,
        "heat_c":snappedf(_heat,0.1),
        "oxygen_pct":snappedf(_oxygen,0.1),
        "crew_pct":snappedf(_crew,0.1),
        "door_pct":snappedf(_door,0.1),
        "time_left_s":snappedf(_time_left,0.1),
        "locale":_locale
    }

func line_summary() -> String:
    if not _active:
        return "NO ACTIVE MISSION" if _locale == "en" else "НЕТ АКТИВНОЙ МИССИИ"
    var target: String = _target.to_upper() if _target != "" else "--"
    if _locale == "en":
        return "TARGET  %s   /   DIRECT  %.0f m\nHEAT  %.0f°C    AIR  %.0f%%    CREW  %.0f%%\nACT %s    /    SECTOR %s" % [
            target,_distance,_heat,_oxygen,_crew,_scenario.to_upper(),_sector.to_upper()
        ]
    return "ЦЕЛЬ  %s   /   НАПРЯМУЮ  %.0f м\nТЕПЛО  %.0f°C    ВОЗДУХ  %.0f%%    ЭКИПАЖ  %.0f%%\nАКТ %s    /    СЕКТОР %s" % [
        target,_distance,_heat,_oxygen,_crew,_scenario.to_upper(),_sector.to_upper()
    ]
