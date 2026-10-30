extends SceneTree
## R179: one TRUE source red stopline crossing, never proximity fines.
const PROOF=preload("res://scripts/city_reign_red_light_evidence.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R179 SOURCE STOPBAR EVIDENCE FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var first:=Vector3(-156,0.8,-165)
	var second:=Vector3(-156,0.8,-163)
	var valid: Dictionary=PROOF.crossing(first,second,PI,8.0,0.1,0.35)
	check(valid.get("violation",false)==true and valid.get("kind","")=="red_light" and
		PROOF.evidence_is_supported(valid),
		"real forward car crosses exactly 8m-before-center physical stopbar on Z red")
	check(PROOF.crossing(first,second,PI,8,12.1,12.35).is_empty(),
		"green Z signal NEVER creates fine even when physically crossing source bar")
	check(PROOF.crossing(first,second,PI,8,11.90,12.15).is_empty(),
		"signal switching inside sample is explicitly excluded, no false red fine")
	check(PROOF.crossing(first,second,PI,2.0,0.1,0.35).is_empty(),
		"parking/near-stopped vehicle cannot receive red signal ticket")
	check(PROOF.crossing(first,second,PI,-8.0,0.1,0.35).is_empty(),
		"vehicle reversing across line is not a forward violation")
	check(PROOF.crossing(second,first,PI,8.0,0.1,0.35).is_empty(),
		"backward movement with a forward heading is not falsely counted")
	check(PROOF.crossing(first,Vector3(-149,0.8,-163),PI,8,0.1,0.35).is_empty(),
		"out-of-lane sideslip cannot trigger red signal evidence")
	check(PROOF.crossing(first,Vector3(-156,0.8,-140),PI,8,0.1,0.35).is_empty(),
		"impossible 25m teleport across road is rejected")
	check(PROOF.crossing(first,second,PI,8,0.1,1.1).is_empty(),
		"unobserved long interval never asserts red crossing time")
	check(PROOF.crossing(first,second,PI,8,0.35,0.1).is_empty(),
		"backwards/jumped signal timer never charges an offence")
	check(PROOF.crossing(Vector3(NAN,0,0),second,PI,8,0.1,0.35).is_empty(),
		"non-finite world position cannot justify a red light fine")
	check(PROOF.crossing(first,second,NAN,8,0.1,0.35).is_empty(),
		"corrupt car yaw cannot claim a real forward lane crossing")
	check(PROOF.crossing(first,second,PI,8,NAN,0.35).is_empty(),
		"invalid time cannot lead to legal transaction")
	var xbefore:=Vector3(-165,0.8,-156)
	var xafter:=Vector3(-163,0.8,-156)
	check(PROOF.crossing(xbefore,xafter,-PI/2,8,10.7,10.92).is_empty(),
		"original AMBER X phase must never count as a red light violation")
	check(PROOF.crossing(xbefore,xafter,-PI/2,8,0.2,0.4).is_empty(),
		"source GREEN X phase must never count as red")
	check(PROOF.crossing(xbefore,xafter,-PI/2,8,12.1,12.4).get("violation",false),
		"real physical X crossing on source RED is detected symmetrically")
	check(PROOF.evidence_is_supported({}) and not PROOF.evidence_is_supported(
		{"violation":true,"kind":"red_light","distance_m":1000.0}),
		"no extra high-risk proof or PII can enter original law engine")
	print("CITY REIGN R179 REAL STOP LINE EVIDENCE: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
