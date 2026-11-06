extends RefCounted
## NEBULA R59: credit-earned original 3D liveries, PER OWNED HULL.
## No premium entitlements, external currency, billing or bypassed ownership.
const SHIP_IDS: Array[String] = ["ship_scout", "ship_interceptor", "ship_guardian"]
const STYLE_IDS: Array[String] = ["factory", "cobalt", "ember", "obsidian"]
const COSTS: Dictionary = {
    "factory": 0, "cobalt": 680, "ember": 1080, "obsidian": 1650}
const TITLES: Dictionary = {
    "factory":"ЗАВОДСКОЙ ТИТАН",
    "cobalt":"ПОЛЯРНЫЙ КОБАЛЬТ",
    "ember":"ПЛАМЯ РАЗЛОМА",
    "obsidian":"ЧЁРНЫЙ МОНОЛИТ"}
const DETAILS: Dictionary = {
    "factory":"Серебристый титановый корпус Авроры",
    "cobalt":"Холодный синий металл и бирюзовые световые рейки",
    "ember":"Графитовые панели и янтарные контурные вставки",
    "obsidian":"Глубокий чёрный металл и золотые рёбра корпуса"}

static func valid_ship(ship_id: String) -> bool:
    return SHIP_IDS.has(ship_id)

static func valid_style(style: String) -> bool:
    return STYLE_IDS.has(style)

static func price(style: String) -> int:
    return int(COSTS[style]) if valid_style(style) else -1

static func default_owned() -> Dictionary:
    return {
        "ship_scout": ["factory"],
        "ship_interceptor": ["factory"],
        "ship_guardian": ["factory"]}

static func default_equipped() -> Dictionary:
    return {"ship_scout":"factory", "ship_interceptor":"factory",
        "ship_guardian":"factory"}

static func safe_owned(raw: Variant) -> Dictionary:
    var result: Dictionary = default_owned()
    if typeof(raw) != TYPE_DICTIONARY:
        return result
    for ship_id in SHIP_IDS:
        var incoming: Variant = raw.get(ship_id, [])
        if typeof(incoming) != TYPE_ARRAY:
            continue
        var normalized: Array[String] = ["factory"]
        for raw_style in incoming:
            if typeof(raw_style) != TYPE_STRING:
                continue
            var style: String = str(raw_style)
            if valid_style(style) and not normalized.has(style):
                normalized.append(style)
        result[ship_id] = normalized
    return result

static func owns(owned: Dictionary, ship_id: String, style: String) -> bool:
    if not valid_ship(ship_id) or not valid_style(style):
        return false
    var entries: Variant = owned.get(ship_id, [])
    return typeof(entries) == TYPE_ARRAY and entries.has(style)

static func safe_equipped(raw: Variant, owned: Dictionary) -> Dictionary:
    var result: Dictionary = default_equipped()
    if typeof(raw) != TYPE_DICTIONARY:
        return result
    for ship_id in SHIP_IDS:
        var value: Variant = raw.get(ship_id, "factory")
        if typeof(value) != TYPE_STRING:
            continue
        var candidate: String = str(value)
        if owns(owned, ship_id, candidate):
            result[ship_id] = candidate
    return result

static func palette(style: String) -> Dictionary:
    match style:
        "cobalt":
            return {"body":Color(0.12,0.30,0.49),
                "armor":Color(0.028,0.105,0.16),
                "dark":Color(0.008,0.029,0.075),
                "accent":Color(0.23,0.92,0.96),
                "glass":Color(0.07,0.27,0.35),
                "roughness":0.25}
        "ember":
            return {"body":Color(0.29,0.31,0.34),
                "armor":Color(0.095,0.060,0.056),
                "dark":Color(0.036,0.02,0.025),
                "accent":Color(1.0,0.39,0.15),
                "glass":Color(0.25,0.095,0.045),
                "roughness":0.34}
        "obsidian":
            return {"body":Color(0.054,0.068,0.085),
                "armor":Color(0.019,0.028,0.045),
                "dark":Color(0.006,0.012,0.025),
                "accent":Color(0.96,0.71,0.24),
                "glass":Color(0.13,0.095,0.045),
                "roughness":0.20}
        _:
            return {"body":Color(0.40,0.47,0.52),
                "armor":Color(0.070,0.12,0.18),
                "dark":Color(0.015,0.038,0.065),
                "accent":Color(0.20,0.75,0.93),
                "glass":Color(0.046,0.18,0.27),
                "roughness":0.28}

static func catalog() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for style in STYLE_IDS:
        result.append({
            "id":style, "title":str(TITLES[style]),
            "description":str(DETAILS[style]),
            "credits":price(style),
            "palette":palette(style)})
    return result
