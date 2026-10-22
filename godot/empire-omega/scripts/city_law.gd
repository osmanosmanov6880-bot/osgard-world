extends RefCounted
## v0.15: deterministic, non-violent driving-law simulation. Persistent state
## uses only JSON-safe scalars/arrays; cooldowns use elapsed gameplay seconds.
const MAX_HEAT := 3
const MAX_FINE := 200000
const OFFENCES := {"speeding":90,"collision":180,"reckless":140}
const OFFENCE_COOLDOWN := 18.0
const ESCAPE_SECONDS := 70.0

static func initial() -> Dictionary:
	return {"heat":0,"fine":0,"cooldown":0.0,"calm":0.0,"infractions":0,"stops":0,"escapes":0,"history":[]}

static func _amount(code: String, heat: int) -> int:
	return int(OFFENCES.get(code,0)) * (1 + maxi(0,heat-1))

static func register(state: Dictionary, code: String) -> bool:
	if not OFFENCES.has(code): return false
	var law: Dictionary = state.get("law",initial())
	if float(law.get("cooldown",0.0)) > 0.0: return false
	var heat: int = mini(MAX_HEAT,int(law["heat"])+1)
	var amount: int = _amount(code,heat)
	law["heat"] = heat
	law["fine"] = mini(MAX_FINE,int(law["fine"])+amount)
	law["cooldown"] = OFFENCE_COOLDOWN
	law["calm"] = 0.0
	law["infractions"] = mini(100000,int(law["infractions"])+1)
	var history: Array = law["history"]
	history.push_front({"turn":int(state["turn"]),"type":code,"fine":amount})
	if history.size()>24: history.resize(24)
	state["law"] = law
	return true

static func progress(state: Dictionary, seconds: float, patrol_nearby: bool) -> bool:
	# Cooling cannot be accelerated by a time-scale spike or a paused game.
	var delta: float = clampf(seconds,0.0,0.25)
	if delta<=0.0: return false
	var law: Dictionary = state.get("law",initial())
	law["cooldown"] = maxf(0.0,float(law["cooldown"])-delta)
	if int(law["heat"])<=0:
		law["calm"] = 0.0
		return false
	law["calm"] = 0.0 if patrol_nearby else float(law["calm"])+delta
	if float(law["calm"]) < ESCAPE_SECONDS: return false
	law["heat"] = maxi(0,int(law["heat"])-1)
	law["calm"] = 0.0
	law["escapes"] = mini(100000,int(law["escapes"])+1)
	# Escaping removes pursuit intensity, never the legal fine.
	return true

static func settle(state: Dictionary, detained: bool) -> bool:
	var law: Dictionary = state.get("law",initial())
	var amount: int = int(law.get("fine",0))
	if amount<=0: return false
	var wallet: int = int(state.get("wallet",0))
	if not detained and wallet<amount: return false
	var paid: int = mini(amount,wallet)
	state["wallet"] = wallet-paid
	state["treasury"] = int(state["treasury"])+paid
	if detained:
		var unpaid: int = amount-paid
		state["personal_debt"] = mini(20000000,int(state.get("personal_debt",0))+unpaid)
		state["reputation"] = maxi(0,int(state.get("reputation",35))-4*maxi(1,int(law["heat"])))
		law["stops"] = mini(100000,int(law["stops"])+1)
	law["heat"] = 0
	law["fine"] = 0
	law["cooldown"] = 0.0
	law["calm"] = 0.0
	state["law"] = law
	return true

static func _whole(value: Variant, lower: int, upper: int) -> bool:
	# Godot JSON.parse_string may decode integral JSON numbers as float.
	# Accept 2.0 but reject 2.5, NaN and booleans during save migration.
	if not (value is int or value is float): return false
	var number: float = float(value)
	return is_finite(number) and number>=float(lower) and number<=float(upper) and absf(number-roundf(number))<0.00001

static func valid(raw: Variant, turn: int) -> bool:
	if not (raw is Dictionary): return false
	var expected := ["heat","fine","cooldown","calm","infractions","stops","escapes","history"]
	for field in expected:
		if not raw.has(field): return false
	if not _whole(raw["heat"],0,MAX_HEAT) or not _whole(raw["fine"],0,MAX_FINE): return false
	var heat: int = int(raw["heat"])
	for field in ["infractions","stops","escapes"]:
		if not _whole(raw[field],0,100000): return false
	for field in ["cooldown","calm"]:
		if not (raw[field] is int or raw[field] is float): return false
		if not is_finite(float(raw[field])): return false
	if float(raw["cooldown"])<0.0 or float(raw["cooldown"])>OFFENCE_COOLDOWN: return false
	if float(raw["calm"])<0.0 or float(raw["calm"])>ESCAPE_SECONDS: return false
	if heat==0 and float(raw["calm"])>0.0: return false
	if not raw["history"] is Array or raw["history"].size()>24: return false
	for entry in raw["history"]:
		if not entry is Dictionary: return false
		if not OFFENCES.has(str(entry.get("type",""))): return false
		if not _whole(entry.get("turn",null),1,turn): return false
		if not _whole(entry.get("fine",null),1,1000): return false
	return true
