#!/usr/bin/env python3
"""Reject missing/mocked or unsafe R46 Godot A/B data; never authorizes live physics migration."""
import json, math, pathlib, sys
p=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "godot/empire-omega/tests/r46-physics-ab-metrics.json")
if not p.is_file():
    raise SystemExit(f"R46 FAIL: native Godot evidence not found: {p}")
obj=json.loads(p.read_text(encoding="utf-8"))
assert obj["engine"] == "Godot 4.4.1" and obj["physics_simulation"] is True
assert obj["migration_authorized"] is False and obj["physical_device_tested"] is False
assert obj["control_transfer_functions_equivalent"] is False
assert obj["trial_count"] == 3 and obj["failed"] == 0 and obj["passed"] >= 30
assert obj["ticks"] == {"settle":140,"drive":108,"turn":72,"brake":48}
trials=obj["trials"]
assert len(trials) == 3
for i,t in enumerate(trials):
    assert t["trial"]==i and t["seed"]==[17,61,17][i]
    assert math.isclose(t["surface_grip"],[1.0,0.65,1.0][i],abs_tol=1e-7)
    assert t["valid"] is True and t["fixed_tick_hz"] == 60
    assert t["spring_contacts_at_rest"]>=2
    for model in ["arcade","rigid"]:
        m=t[model]
        for name in ["drive_m","speed_after_drive_mps","turn_rad","speed_prebrake_mps","speed_postbrake_mps"]:
            assert isinstance(m[name],(int,float)) and math.isfinite(m[name]),(i,model,name)
        assert m["drive_m"]>0.75 and m["speed_after_drive_mps"]>0.25
        assert m["speed_postbrake_mps"] < m["speed_prebrake_mps"]+0.15
    assert t["rigid"]["supported_drive_frames"] > 108*0.55
assert 0 <= obj["rigid_dry_repeat_relative_error"]<0.20
assert math.isfinite(obj["rigid_vs_arcade_dry_drive_distance_relative_error"])
print(f"R46 PASS: {obj['trial_count']} real engine A/B trials, {obj['passed']} checks; live migration remains BLOCKED")
