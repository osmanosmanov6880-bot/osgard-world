#!/usr/bin/env python3
"""R77: verify that a human may rerun unchanged exact public Godot web checks
on master without granting manual dispatch to PR branches or auto-GO.
"""
from pathlib import Path

WF=Path(".github/workflows/omega-r50-release-evidence-qa.yml")


def allowed(event: str, ref: str = "", deploy_result: str = "", deploy_branch: str = "") -> bool:
    # Equivalent event truth table to the GitHub Actions job-level expression.
    return ((event == "workflow_run" and deploy_result == "success" and deploy_branch == "master")
            or (event == "workflow_dispatch" and ref == "refs/heads/master")
            or (event == "push" and ref == "refs/heads/master"))


def run():
    source=WF.read_text(encoding="utf-8")
    assert "  workflow_dispatch:" in source
    assert "  push:" in source
    assert "    branches: [master]" in source
    assert "- '.github/workflows/omega-r50-release-evidence-qa.yml'" in source
    prefix,tail=source.split("  real-post-ssh-game-acceptance:",1)
    expression=tail.split("    runs-on:",1)[0]
    assert "github.event_name == 'workflow_run'" in expression
    assert "github.event.workflow_run.conclusion == 'success'" in expression
    assert "github.event.workflow_run.head_branch == 'master'" in expression
    assert "github.event_name == 'workflow_dispatch'" in expression
    assert "github.ref == 'refs/heads/master'" in expression
    assert "github.event_name == 'push'" in expression
    assert expression.count("github.ref == 'refs/heads/master'") == 2
    assert "||" in expression and "&&" in expression
    assert "github.event_name == 'pull_request'" not in expression
    assert "scripts/omega-r77-dispatch-contract.py" in prefix
    assert "--retries=0 --reporter=json" in tail
    assert "omega-live-integrity.py" in tail
    assert "omega-r50-release-gate.py" in tail
    assert "assert obj['status']=='HOLD'" in tail
    assert "missing-two-physical-hardware-reports" in tail
    assert "actions/upload-artifact@v4" in tail
    assert not allowed("pull_request",ref="refs/heads/master")
    assert not allowed("workflow_dispatch",ref="refs/heads/untrusted")
    assert not allowed("push",ref="refs/heads/untrusted")
    assert not allowed("push",ref="refs/pull/45/merge")
    assert not allowed("workflow_run",deploy_result="failure",deploy_branch="master")
    assert not allowed("workflow_run",deploy_result="success",deploy_branch="feature")
    assert allowed("workflow_run",deploy_result="success",deploy_branch="master")
    assert allowed("workflow_dispatch",ref="refs/heads/master")
    assert allowed("push",ref="refs/heads/master")
    print("PASS R77/R78 master-only manual and one-time promotion push Godot WebGL; no automatic Production GO")


if __name__ == "__main__":
    run()
