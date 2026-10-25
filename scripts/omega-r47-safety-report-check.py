#!/usr/bin/env python3
"""Fail closed on incomplete/fake R47 Godot simulation evidence."""
import json, math, pathlib, sys
p=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "godot/empire-omega/tests/r47-city-safety.json")
if not p.is_file():
    raise SystemExit("R47 FAIL: genuine native Godot report missing")
a=json.loads(p.read_text(encoding="utf-8"))
assert a["engine"]=="Godot 4.4.1"
assert a["predictive_cases"]==200 and a["real_collision_scenarios"]==1
assert a["seeds"]==[7,23,61,109,211] and a["failed"]==0 and a["passed"]>=615
assert a["full_crowd_simulation"] is False
assert a["device_fps_measured"] is False and a["production_agent_changes"] is False
for i,g in enumerate(a["groups"]):
    assert g["seed"]==a["seeds"][i] and len(g["cases"])==40
    assert g["false_alerts"]==g["missed_conflicts"]==0
    for j,c in enumerate(g["cases"]):
        assert c["kind"]==["incoming","retreating","adjacent","walking_crossing"][j%4]
        assert c["actual"] is c["expected"]
        assert 0<=c["closest_s"]<=2.4001
        assert 0<=c["wet_safe_mps"]<=c["dry_safe_mps"]+0.00011<=14.0002
        assert all(math.isfinite(c[key]) for key in ("closest_s","speed_mps","clearance_m","dry_safe_mps","wet_safe_mps"))
trial=a["physical_trial"]
assert trial["real_physics_frames"]==240 and trial["collision_shape"] is True
assert trial["collision_layer"]==8 and trial["nonfinite_frames"]==0
assert trial["travelled_m"]>3 and trial["final_z_m"]>-27 and trial["stopped_seconds"]>0.5
print("R47 PASS: 200 seeded analytic trajectory checks plus 240 genuine Godot traffic physics frames")
