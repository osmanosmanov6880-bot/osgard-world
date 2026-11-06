extends RefCounted
## NEBULA R58 - reputation, rank and elite replayable real-flight contracts.
## Unlocks are derived ONLY from bounded completed R57 contracts.
## No premium rights, real-money billing, daily clocks or shadow balances.
const PatrolContractsR57 = preload("res://scripts/patrol_contracts_r57.gd")
const MAX_TIER: int = 2
const RANK_THRESHOLDS: Array[int] = [0, 3, 9, 24]
const RANK_LABELS: Array[String] = [
    "НОВИЧОК", "ШТУРМАН", "АС", "ЛЕГЕНДА"]
const RISK_LABELS: Array[String] = [
    "СТАНДАРТ", "УСКОРЕННЫЙ", "ЭЛИТНЫЙ"]
const CREDIT_MULTIPLIERS: Array[float] = [1.0, 1.35, 1.75]
const XP_MULTIPLIERS: Array[float] = [1.0, 1.30, 1.65]
const TIME_MULTIPLIERS: Array[float] = [1.0, 0.85, 0.70]

static func total_completions(raw_counts: Variant) -> int:
    var counts: Dictionary = PatrolContractsR57.safe_finish_counts(raw_counts)
    var total: int = 0
    for route_id in PatrolContractsR57.CONTRACT_IDS:
        total += int(counts.get(route_id, 0))
    return total

static func rank(raw_counts: Variant) -> int:
    var earned: int = total_completions(raw_counts)
    var result: int = 0
    for i in range(RANK_THRESHOLDS.size()):
        if earned >= RANK_THRESHOLDS[i]:
            result = i
    return result

static func highest_unlocked_tier(raw_counts: Variant) -> int:
    # Avoid a reputation deadlock: standard contracts always remain playable.
    return mini(MAX_TIER, maxi(0, rank(raw_counts)))

static func unlocked(tier: int, raw_counts: Variant) -> bool:
    return tier >= 0 and tier <= highest_unlocked_tier(raw_counts)

static func valid_risk(raw_risk: Variant) -> bool:
    if typeof(raw_risk) != TYPE_INT and typeof(raw_risk) != TYPE_FLOAT:
        return false
    if not is_finite(float(raw_risk)):
        return false
    return float(raw_risk) == floorf(float(raw_risk)) and (
        int(raw_risk) >= 0 and int(raw_risk) <= MAX_TIER)

static func safe_selected_tier(raw_risk: Variant, counts: Variant) -> int:
    if not valid_risk(raw_risk):
        return 0
    var tier: int = int(raw_risk)
    return tier if unlocked(tier, counts) else 0

static func tier_label(tier: int) -> String:
    return RISK_LABELS[tier] if tier >= 0 and tier <= MAX_TIER else "НЕИЗВЕСТНО"

static func earned_credits(route_id: String, tier: int) -> int:
    if not PatrolContractsR57.valid_contract(route_id) or (
            tier < 0 or tier > MAX_TIER):
        return 0
    return roundi(PatrolContractsR57.reward_credits(route_id) *
        CREDIT_MULTIPLIERS[tier])

static func earned_xp(route_id: String, tier: int) -> int:
    if not PatrolContractsR57.valid_contract(route_id) or (
            tier < 0 or tier > MAX_TIER):
        return 0
    return roundi(PatrolContractsR57.reward_xp(route_id) *
        XP_MULTIPLIERS[tier])

static func available_seconds(route_id: String, tier: int) -> float:
    if not PatrolContractsR57.valid_contract(route_id) or (
            tier < 0 or tier > MAX_TIER):
        return 0.0
    var route: Dictionary = PatrolContractsR57.CATALOG[route_id]
    return float(route["limit_sec"]) * TIME_MULTIPLIERS[tier]

static func challenge_route(route_id: String,
        tier: int) -> Array[Vector3]:
    var result: Array[Vector3] = []
    if not PatrolContractsR57.valid_contract(route_id) or (
            tier < 0 or tier > MAX_TIER):
        return result
    var base: Array = PatrolContractsR57.CATALOG[route_id]["route"]
    for waypoint in base:
        result.append(waypoint as Vector3)
    # Higher tiers add actual return-leg navigation, not a decorative
    # medal. The 3D beacon must move and hold time still applies.
    if tier >= 1:
        result.append(base[base.size() - 2] as Vector3)
    if tier >= 2:
        result.append(base[base.size() - 3] as Vector3)
    return result

static func next_rank_threshold(raw_counts: Variant) -> int:
    var grade: int = rank(raw_counts)
    return RANK_THRESHOLDS[grade + 1] if (
        grade < RANK_THRESHOLDS.size() - 1) else 0

static func status(raw_counts: Variant) -> Dictionary:
    var grade: int = rank(raw_counts)
    var total: int = total_completions(raw_counts)
    var next_at: int = next_rank_threshold(raw_counts)
    return {
        "rank": grade, "title": RANK_LABELS[grade],
        "completed": total, "next_at": next_at,
        "remaining": maxi(0, next_at - total) if next_at > 0 else 0,
        "max_risk": highest_unlocked_tier(raw_counts)
    }

static func offer_catalog(raw_counts: Variant,
        selected_tier: int) -> Array[Dictionary]:
    var offers: Array[Dictionary] = []
    var tier: int = safe_selected_tier(selected_tier, raw_counts)
    for item in PatrolContractsR57.catalog():
        var entry: Dictionary = item.duplicate(true)
        var route_id: String = str(entry["id"])
        entry["credits"] = earned_credits(route_id, tier)
        entry["xp"] = earned_xp(route_id, tier)
        entry["duration_sec"] = available_seconds(route_id, tier)
        entry["checkpoints"] = challenge_route(route_id, tier).size()
        entry["risk_tier"] = tier
        offers.append(entry)
    return offers
