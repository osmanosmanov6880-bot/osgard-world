extends SceneTree
## R165 native Godot 4.4.1 deterministic response tests.
## These sample an arcade brake-input model and never claim certified ABS.
const APEX = preload("res://scripts/city_reign_brake_response.gd")
const DYNAMICS = preload("res://scripts/driving_dynamics.gd")
var passed: int = 0
var failed: int = 0
func check(ok: bool,name: String) -> void:
    if ok:
        passed+=1
    else:
        failed+=1
        push_error("CITY REIGN R165 APEX MODEL FAIL: "+name)
func _initialize() -> void:
    call_deferred("_run")

static func trial(grip: float,hz: int) -> Dictionary:
    var dt: float = 1.0/float(hz)
    var speed: float = 20.0
    var traveled: float = 0.0
    var response: float = 0.0
    var peak: float = 0.0
    for i in range(hz*7):
        if speed<=0.001:
            break
        response=APEX.step(response,APEX.request(-1.0,speed,false),dt)
        var effective: float = APEX.effective_throttle(-1.0,speed,response)
        speed=DYNAMICS.speed_step(speed,effective,grip,1.0,29.0,9.0,
            9.5,10.5,2.4,false,dt)
        traveled += maxf(0.0,speed)*dt
        peak=maxf(peak,response)
    return {"distance_m":traveled,"pressure_max":peak,"speed_end":speed}

func _run() -> void:
    check(APEX.request(-1,18,false)==1.0,
        "opposing physical pedal requests full brake")
    check(APEX.request(1,-9,false)==1.0,
        "forward pedal actively brakes a reversing vehicle")
    check(APEX.request(1,18,false)==0.0,
        "positive torque never requests accidental braking")
    check(APEX.request(-1,0,false)==0.0,
        "manual reverse engagement from true standstill remains unchanged")
    check(APEX.request(0,0,true)==1.0,
        "existing handbrake still has unconditional authority")
    check(APEX.request(NAN,18,false)==0,
        "invalid input fails closed without propagating NaN")
    var pressure: float=0
    for i in range(12):
        pressure=APEX.step(pressure,1.0,1.0/60.0)
        check(pressure>=0.0 and pressure<=1.0,
            "real-time brake actuation is bounded at frame "+str(i))
    check(pressure>0.90 and pressure<1.0,
        "brake response reaches full request smoothly rather than instantly")
    var former: float=pressure
    for i in range(15):
        pressure=APEX.step(pressure,0.0,1.0/60.0)
    check(pressure<former*0.20,
        "real pedal release visibly unwinds previous brake response")
    check(APEX.step(NAN,1.0,-0.1)==0.0 and APEX.step(0.2,NAN,0.1)<0.2,
        "non-finite and negative dt inputs never contaminate physics")
    check(APEX.step(0.0,1.0,999.0)<=1.0,
        "background-tab time jump is bounded to one max substep")
    var effort: float = APEX.effective_throttle(-1.0,15.0,0.25)
    check(effort< -0.23 and effort> -0.27,
        "full panic brake builds actual hydraulic-style arcade envelope")
    check(APEX.effective_throttle(-1.0,0.0,0.0)==-1.0,
        "driver can always reverse after actual stop")
    check(APEX.effective_throttle(0.65,15.0,0.9)==0.65,
        "existing accelerator authority unaffected by stale brake response")
    check(APEX.power_factor(0,29)==1.0 and APEX.power_factor(28,29)<0.85,
        "source curve trims high-speed engine effort, not low-speed launch")
    check(APEX.power_factor(999,29)>=0.81,
        "motor response is never clamped below documented bounded torque")
    var raw: float = DYNAMICS.yaw_rate(18,0.9,0.95,false)
    var dry: float = APEX.corner_yaw(raw,18,1.0,1.0,false)
    var wet: float = APEX.corner_yaw(raw,18,0.55,1.0,false)
    check(raw>0.0 and dry>0.0 and dry<raw,
        "hard braking reduces lateral turn budget in the original motion model")
    check(wet<dry and wet>0.0,
        "wetter tyre grip reserves more combined brake/corner capacity")
    check(APEX.corner_yaw(raw,18,0.55,1.0,true)==raw,
        "intentional handbrake drift bypasses the steering reserve")
    check(APEX.corner_yaw(raw,18,1.0,0.0,false)==raw,
        "original straight-drive steering remains unchanged when not braking")
    check(APEX.corner_yaw(raw,0.0,1.0,1.0,false)==raw,
        "parking manoeuvres retain low-speed turning")
    var dry30: Dictionary=trial(1.0,30)
    var dry60: Dictionary=trial(1.0,60)
    var dry120: Dictionary=trial(1.0,120)
    var rainy60: Dictionary=trial(0.55,60)
    check(float(dry60["distance_m"])>8.0 and float(dry60["distance_m"])<70.0,
        "full brake from actual 20m/s travels positive finite physical road")
    check(float(rainy60["distance_m"])>float(dry60["distance_m"])*1.25,
        "wet road genuinely increases modelled braking distance")
    check(absf(float(dry30["distance_m"])-float(dry60["distance_m"]))<2.0,
        "same dry input at 30/60Hz has deterministic calibrated distance")
    check(absf(float(dry120["distance_m"])-float(dry60["distance_m"]))<2.0,
        "same dry input at 60/120Hz has deterministic calibrated distance")
    check(float(dry60["speed_end"])<0.5 and float(rainy60["speed_end"])<0.5,
        "dry and wet runs reach nearly full stop within simulation window")
    check(float(dry60["pressure_max"])>0.95,
        "model reaches maximum pedal brake effort during real physical stopping")
    check(APEX.safety_bound(0.5,25.0,1.1) and not APEX.safety_bound(NAN,25,1),
        "telemetry safety gates reject invalid speed/brake values")
    print("CITY REIGN R165 APEX RESPONSE: %d PASS %d FAIL" % [passed,failed])
    quit(0 if failed==0 else 1)
