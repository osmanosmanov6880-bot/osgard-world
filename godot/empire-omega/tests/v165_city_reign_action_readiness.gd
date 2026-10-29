extends SceneTree
## R172 pure action logic: actual proximity, original cargo constraints,
## three languages, real save non-mutation and no invented mission rewards.
const COACH=preload("res://scripts/city_reign_action_readiness.gd")
const CARGO=preload("res://scripts/cargo_logistics.gd")
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R172 ACTION FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var contracts: Node=root.get_node_or_null("ContractManager")
	check(sim!=null and contracts!=null,"original autoloads available")
	if sim==null or contracts==null:
		quit(2)
		return
	var saved: Dictionary=sim.data.duplicate(true)
	sim.data=sim.new_game()
	var state: Dictionary=sim.data
	var offer: Dictionary=contracts.current_offer()
	var loc: Dictionary=contracts.POSITIONS
	var origin: Vector3=Vector3(-100,1,-100)
	var near_car: Vector3=Vector3(-106,1,-100)
	var far_car: Vector3=Vector3(100,1,100)
	var initial: Dictionary=state.duplicate(true)
	var view: Dictionary=COACH.project(state,offer,loc,origin,far_car,false,0,false,"ru")
	check(view["phase"]=="vehicle_walk" and not view["ready"],"cannot enter distant car")
	view=COACH.project(state,offer,loc,origin,near_car,false,0,false,"ru")
	check(view["phase"]=="vehicle_enter" and view["ready"],"true E distance <8m")
	for language in ["ru","en","zh"]:
		view=COACH.project(state,offer,loc,origin,near_car,false,0,false,language)
		check(not str(view["title"]).is_empty() and view["key"]=="E","genuine enter action localized "+language)
	state["mission"]=1
	view=COACH.project(state,offer,loc,origin,near_car,false,0,false,"en")
	check(view["phase"]=="market_drive" and not view["ready"],"must physically travel to market")
	view=COACH.project(state,offer,loc,loc["market"]+Vector3(4,0,0),near_car,false,0,false,"en")
	check(view["phase"]=="market_deliver" and view["ready"],"F only at real market")
	state["mission"]=2
	view=COACH.project(state,offer,loc,loc["market"],near_car,false,0,false,"zh")
	check(view["phase"]=="business_buy" and view["key"]=="B","touch and keyboard B correspond to real business action")
	state["mission"]=3
	view=COACH.project(state,offer,loc,origin,near_car,false,0,false,"en")
	check(view["phase"]=="government_open" and view["key"]=="Tab","Tab actual city command")
	view=COACH.project(state,offer,loc,origin,near_car,false,0,true,"en")
	check(view["phase"]=="government_turn" and view["key"]=="N","N only advertised inside cabinet")
	state["mission"]=4
	var pickup: Vector3=loc[str(offer["pickup"])]
	view=COACH.project(state,offer,loc,pickup,far_car,false,0,false,"en")
	check(view["phase"]=="car_to_pickup" and not view["ready"],"no fake cargo acceptance if car far away")
	view=COACH.project(state,offer,loc,pickup, pickup+Vector3(1,0,0),false,0,false,"en")
	check(view["phase"]=="pickup_ready" and view["ready"],"true F cargo acceptance with actual car in range")
	var drop: Vector3=loc[str(offer["dropoff"])]
	var required: float=CARGO.route_distance(pickup,drop)
	var active: Dictionary=CARGO.begin(offer,required,0,100,str(state["vehicle_selected"]),int(state["turn"]))
	state["active_contract"]=active
	view=COACH.project(state,offer,loc,drop,drop,true,0,false,"en")
	check(view["phase"]=="freight_distance" and not view["ready"],"active cargo cannot be fabricated as delivered before mileage")
	active["cargo_progress"]["meters"]=required
	view=COACH.project(state,offer,loc,drop,drop,true,4.0,false,"en")
	check(view["phase"]=="freight_stop" and not view["ready"],"cannot unload at driving speed")
	view=COACH.project(state,offer,loc,drop,drop,true,0,false,"ru")
	check(view["phase"]=="finish_prior" and view["ready"],"old contract must finish before mission 5 pickup")
	state["mission"]=5
	view=COACH.project(state,offer,loc,drop,drop,true,0,false,"en")
	check(view["phase"]=="freight_unload" and view["ready"],"real freight ready with same selected vehicle")
	view=COACH.project(state,offer,loc,drop,drop,false,0,false,"en")
	check(view["phase"]=="freight_car" and not view["ready"],"modern freight requires the assigned vehicle")
	state["active_contract"]={}
	view=COACH.project(state,offer,loc,origin,near_car,false,0,false,"en")
	check(not view["ready"] and view["phase"]=="car_to_pickup","interrupted freight recovers without phantom delivery")
	state["driving_trial"]={"id":"forum_loop"}
	view=COACH.project(state,offer,loc,origin,near_car,false,0,false,"en")
	check(not view["active"],"real driving trial overrides six-chapter coaching")
	state["driving_trial"]={}
	view=COACH.project(state,offer,loc,Vector3(NAN,0,0),near_car,false,0,false,"en")
	check(not view["active"],"nonfinite player coordinates fail closed")
	view=COACH.project(state,{}, {},origin,near_car,false,0,false,"en")
	check(not view["active"],"missing current offer cannot invent a GPS location")
	state["mission"]=6
	view=COACH.project(state,offer,loc,origin,near_car,false,0,false,"ru")
	check(not view["active"] and view["phase"]=="complete","chapter progression stops at original six")
	check(initial["wallet"]==state["wallet"] and initial["treasury"]==state["treasury"],
		"read-only coach never mints money or mutates treasury")
	sim.data=saved
	print("CITY REIGN R172 REAL ACTIONS: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
