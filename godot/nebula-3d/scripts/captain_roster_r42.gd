extends RefCounted
## NEBULA R42: three free, selectable commanders with real balanced gameplay effects.
## Data is deterministic, and does not touch the Stripe entitlement service.

const CAPTAINS: Dictionary = {
    "ada": {
        "name": "АДА ВЕЙЛ",
        "role": "ТАКТИК",
        "effect": "−10% входящего урона",
        "description": "Крепкая оборона для сложных боевых вылетов.",
        "damage_multiplier": 0.90,
        "thrust_multiplier": 1.0,
        "credit_bonus": 0.0,
    },
    "kai": {
        "name": "КАЙ РЕН",
        "role": "АСС",
        "effect": "+8% ускорения",
        "description": "Быстрее набирает скорость, сохраняя ограничения максимальной скорости.",
        "damage_multiplier": 1.0,
        "thrust_multiplier": 1.08,
        "credit_bonus": 0.0,
    },
    "leya": {
        "name": "ЛЕЯ НОКС",
        "role": "ИНЖЕНЕР",
        "effect": "+12% кредитов за миссию",
        "description": "Премия только за успешное выполнение цели; без платежей.",
        "damage_multiplier": 1.0,
        "thrust_multiplier": 1.0,
        "credit_bonus": 0.12,
    },
}

static func valid_id(id: String) -> bool:
    return CAPTAINS.has(id)

static func info(id: String) -> Dictionary:
    var selected: String = id if valid_id(id) else "ada"
    return (CAPTAINS[selected] as Dictionary).duplicate(true)

static func reward(base: int, id: String) -> int:
    var captain: Dictionary = info(id)
    return maxi(0, base + roundi(float(maxi(base, 0)) * float(captain["credit_bonus"])))
