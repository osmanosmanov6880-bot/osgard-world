#!/usr/bin/env python3
"""R138 static release policy and real Python guard tests. NO deployment."""
from __future__ import annotations
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parent.parent
guard = runpy.run_path(str(ROOT/"scripts/omega-r138-manual-release-guard.py"))
guard["self_test"]()
native=(ROOT/".github/workflows/omega-godot-web.yml").read_text(encoding="utf8")
ssh=(ROOT/".github/workflows/omega-web-direct-deploy.yml").read_text(encoding="utf8")
for path,src in (("native",native),("ssh",ssh)):
    assert "\non:\n" in src, path+" workflow lacks real trigger"
    triggers=src.split("\non:\n",1)[1].split("\npermissions:",1)[0]
    assert "workflow_dispatch:" in triggers, path
    assert "push:" not in triggers, path+" MUST NOT auto-release on master push"
    assert "workflow_run:" not in triggers, path+" MUST NOT auto-release after frontend job"
    assert "type: string" in triggers and "approved_source_sha:" in triggers
    assert "production_confirmation:" in triggers and "release_ticket:" in triggers
    assert "R138 HARD" in src
    assert src.index("R138 HARD") < src.index("setup-godot" if path=="native" else "Configure SSH")
    for name in ("ART_APPROVAL","GAMEPLAY_APPROVAL","PHYSICAL_APPROVAL","ROLLBACK_APPROVAL",
                 "ADMIN_SHA","ADMIN_TICKET","RELEASE_ENABLED","REQUESTED_SHA","REQUESTED_TICKET",
                 "PRODUCTION_CONFIRM","BRANCH_REF","EVENT_NAME"):
        assert name in src, (path,name)
    assert "scripts/omega-r138-manual-release-guard.py" in src, path

assert "gh workflow run deploy-frontend.yml" in native, "expected manual website activation after GO"
assert "git push origin HEAD:master" in native, "retain reviewed original runtime pin after manual GO"
assert native.index("R138 HARD") < native.index("git push origin HEAD:master")
assert ssh.index("R138 HARD") < ssh.index("Upload verified Godot game, activate with rollback")
assert "source_gate.outputs.ready == 'true'" in ssh
assert "omega-build-freshness.py" in ssh and native
assert "R138 HARD" in native and "R138 HARD" in ssh
# Guard must fail with empty/unconfigured repository variables, as deployed now.
fixture=guard["fixture"]()
for flag in ("enabled","approved_sha","admin_ticket","art","gameplay","physical","rollback"):
    fixture[flag]=""
assert not guard["verify"](fixture)["production_authorized"]
assert guard["verify"](fixture)["review_flags_count"]==0
print("EMPIRE R138 PASS: no silent source build or automatic SSH, both exact-SHA guarded manual paths; 21 strict refusal tests")
