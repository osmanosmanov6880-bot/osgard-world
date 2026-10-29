extends SceneTree
## R171 safe original source-driven live episode guidance unit acceptance.
const COACH=preload("res://scripts/city_reign_episode_live_coach.gd")
const CARGO=preload("res://scripts/cargo_logistics.gd")
var locations: Dictionary={}
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R171 LIVE GUIDANCE FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func advice(s: Dictionary,offer: Dictionary,at: Vector3,car: Vector3,
		driving: bool=false,speed: float=0.0,fuel: float=100.0,
		health: float=100.0,menu: bool=false,language: String="en") -> Dictionary:
	return COACH.recommend(s,offer,locations,language,
		at,car,driving,speed,fuel,health,menu,500)
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var contracts: Node=root.get_node_or_null("ContractManager")
	check(sim!=null and contracts!=null,"original GameState & contracts are real runtime autoloads")
	if sim==null or contracts==null:
		quit(2)
		return
	locations=contracts.POSITIONS
	var original: Dictionary=sim.data.duplicate(true)
	sim.data=sim.new_game()
	var state: Dictionary=sim.data
	var offer: Dictionary=contracts.current_offer()
	var car: Vector3=Vector3(-120.0,1.3,-104.0)
	var market: Vector3=Vector3(130.0,1.3,-130.0)
	var pickup: Vector3=contracts.POSITIONS[str(offer["pickup"])]
	var dropoff: Vector3=contracts.POSITIONS[str(offer["dropoff"])]
	check(advice(state,offer,Vector3(-155,1.3,-104),car)["mode"]=="walk_car",
		"player must physically approach the original saved first vehicle")
	check(advice(state,offer,Vector3(-117,1.3,-104),car)["mode"]=="enter_car",
		"within actual 8m entering distance show original E action")
	check(COACH.horizontal_distance(Vector3(0,0,0),Vector3(3,100,4))==5.0,
		"native guidance uses true horizontal world metres not camera pixels")
	state["mission"]=1
	check(advice(state,offer,car,car,true,9.0)["mode"]=="drive_market",
		"true 260m market delivery gives real 3D driving destination")
	check(advice(state,offer,market,market,true)["mode"]=="deliver_market",
		"original F market interaction only when really close to correct location")
	check(advice(state,offer,car,car,true,8.0,7.0)["mode"]=="fuel",
		"car state under 10 percent triggers real terminal refuel advice")
	check(advice(state,offer,car,car,true,8.0,60.0,19.0)["mode"]=="repair",
		"real damaged car must be repaired before a long trip")
	state["mission"]=2
	state["wallet"]=0
	check(advice(state,offer,market,market,true)["mode"]=="funds",
		"buy business suggestion does not fabricate a purchase without funds")
	state["wallet"]=600
	check(advice(state,offer,market,market,true)["mode"]=="buy_market",
		"R171 shows real B only when affordable and within 29m")
	check(advice(state,offer,car,car,true)["mode"]=="drive_buy",
		"R171 uses actual market location when company too far")
	state["businesses"]["market_stall"]=true
	check(advice(state,offer,market,market,true)["mode"]=="owned",
		"already-owned property is not falsely advertised as a repeatable purchase")
	state["businesses"]["market_stall"]=false
	state["mission"]=3
	check(advice(state,offer,car,car)["mode"]=="open_city",
		"outside existing cabinet suggests genuine TAB action")
	check(advice(state,offer,car,car,false,0.0,100.0,100.0,true)["mode"]=="city_turn",
		"open cabinet suggests original N to advance genuine economic tick")
	state["incident"]="blackout"
	check(advice(state,offer,car,car)["mode"]=="incident",
		"active city incident blocks N, so R171 never misleads player")
	state["incident"]=""
	state["mission"]=4
	check(advice(state,offer,car,car)["mode"]=="to_cargo",
		"genuine first cargo pickup is selected from authoritative live offer")
	check(advice(state,offer,pickup,pickup,true)["mode"]=="collect_cargo",
		"cargo F shown at actual pickup with nearby original vehicle")
	check(advice(state,offer,pickup,car)["mode"]=="bring_car",
		"pedestrian at depot cannot accept a cargo when their car is far away")
	state["mission"]=5
	check(advice(state,offer,pickup,pickup,true)["mode"]=="to_cargo" or
		advice(state,offer,pickup,pickup,true)["mode"]=="recover_cargo",
		"missing original load stays a real recovery trip, never completion")
	var active: Dictionary=CARGO.begin(offer,200.0,0.0,100.0,"compact",1)
	state["active_contract"]=active
	check(advice(state,offer,dropoff,dropoff,true)["mode"]=="travel_more",
		"physically arriving without driven mileage may not complete freight")
	active["cargo_progress"]["meters"]=200.0
	check(advice(state,offer,car,car,true)["mode"]=="drive_dropoff",
		"recorded genuine mileage still requires the actual delivery location")
	check(advice(state,offer,dropoff,dropoff,true,4.0)["mode"]=="stop_car",
		"real courier unload requires speed at most 1.5m/s")
	check(advice(state,offer,dropoff,dropoff,true,0.0)["mode"]=="unload_cargo",
		"only full mileage, parked original car and actual dropoff suggest F")
	state["vehicle_selected"]="utility"
	check(advice(state,offer,dropoff,dropoff,true)["mode"]=="assigned_car",
		"original freight must use the very car assigned at acceptance")
	state["vehicle_selected"]="compact"
	state["mission"]=4
	check(advice(state,offer,car,car,true)["mode"]=="existing_cargo",
		"existing older delivery must finish before taking a second contract")
	state["driving_trial"]={"id":"forum_loop"}
	check(advice(state,offer,car,car)["mode"]=="trial",
		"active genuine driving trial takes priority over first-episode prompts")
	state["driving_trial"]={}
	state["service_active"]={"id":"original_public_service"}
	check(advice(state,offer,car,car)["mode"]=="priority",
		"real public service takes priority")
	state["service_active"]={}
	state["mission"]=0
	check(advice(state,offer,Vector3(NAN,0,0),car)["mode"]=="invalid",
		"NaN location safely fails closed")
	check(advice(state,offer,car,car,false,NAN)["mode"]=="invalid",
		"NaN physics telemetry never claims real interaction")
	state["mission"]=6
	for lang in ["ru","en","zh"]:
		var finished: Dictionary=advice(state,offer,car,car,false,0.0,100.0,100.0,false,lang)
		check(finished["mode"]=="done" and
			not str(finished["text"]).is_empty(),"fully localized original 6/6 completion "+lang)
	state["mission"]=0
	var frozen: Dictionary=state.duplicate(true)
	for i in range(120):
		advice(state,offer,car,car,i%2==0,float(i%10),80.0,100.0,false,
			["ru","en","zh"][i%3])
	check(state==frozen and sim.data==state,
		"120 actual advice samples have ZERO effects on original mission, wallet or save")
	sim.data=original
	print("CITY REIGN R171 LIVE GUIDANCE: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
