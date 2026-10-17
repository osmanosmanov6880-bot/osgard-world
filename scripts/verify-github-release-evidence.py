#!/usr/bin/env python3
"""Verify GitHub Actions release evidence against live GitHub API, no publishing."""
import argparse
import json
import re
import sys
from urllib.request import Request, build_opener, HTTPRedirectHandler
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse

RUN_PATTERN = re.compile(r"^/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/actions/runs/([1-9][0-9]*)/?$")
REQUIRED = ("code_ci", "frontend_ci", "archive", "backup_restore", "smoke")
GITHUB_HOST = "github.com"
API_HOST = "api.github.com"
class RejectAPIRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("GitHub API redirect refused")
def safe_api_opener(request, timeout=10):
    return build_opener(RejectAPIRedirects()).open(request, timeout=timeout)

def parse_run_url(value, expected_repo):
    if not isinstance(value, str):
        raise ValueError("missing run URL")
    p = urlparse(value)
    if p.scheme != "https" or p.hostname != GITHUB_HOST or p.port not in (None, 443) or p.username or p.password or p.query or p.fragment:
        raise ValueError("run URL must be canonical github.com HTTPS URL")
    match = RUN_PATTERN.fullmatch(p.path)
    if not match:
        raise ValueError("run URL must point to a GitHub Actions run")
    owner, name, run_id = match.groups()
    if f"{owner}/{name}".lower() != expected_repo.lower():
        raise ValueError("run URL references a different repository")
    return int(run_id)

def fetch_run(repository, run_id, opener=safe_api_opener):
    request = Request(f"https://api.github.com/repos/{repository}/actions/runs/{run_id}",
        headers={"Accept":"application/vnd.github+json", "User-Agent":"osgard-release-verifier"})
    # Explicitly request a GitHub API URL; no arbitrary user-supplied hosts.
    with opener(request, timeout=10) as response:
        data = response.read(128 * 1024 + 1)
    if len(data) > 128 * 1024:
        raise ValueError("GitHub API response too large")
    obj = json.loads(data)
    if not isinstance(obj, dict):
        raise ValueError("invalid GitHub API result")
    return obj

def verify(evidence, repository, workflow_names, opener=safe_api_opener):
    errors = []
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository or ""):
        raise ValueError("invalid repository")
    sha = evidence.get("commit_sha")
    if not isinstance(sha, str) or not re.fullmatch(r"(?:[a-fA-F0-9]{40}|[a-fA-F0-9]{64})", sha):
        raise ValueError("invalid release commit_sha")
    entries = evidence.get("checks")
    if not isinstance(entries, dict):
        raise ValueError("missing checks")
    for key in REQUIRED:
        entry = entries.get(key)
        if not isinstance(entry, dict):
            errors.append(f"{key}: missing evidence")
            continue
        try:
            run_id = parse_run_url(entry.get("evidence_url"), repository)
            run = fetch_run(repository, run_id, opener)
            got_repo = run.get("repository", {}).get("full_name")
            if str(got_repo).lower() != repository.lower():
                raise ValueError("GitHub API repository mismatch")
            if run.get("id") != run_id:
                raise ValueError("GitHub API run id mismatch")
            if run.get("head_sha", "").lower() != sha.lower():
                raise ValueError("run belongs to another commit")
            if run.get("status") != "completed" or run.get("conclusion") != "success":
                raise ValueError("run is not completed successfully")
            if run.get("name") != workflow_names[key]:
                raise ValueError("wrong workflow")
            if entry.get("status") != "passed":
                raise ValueError("local evidence status is not passed")
        except (ValueError, KeyError, TypeError, HTTPError, URLError, TimeoutError, json.JSONDecodeError) as exc:
            errors.append(f"{key}: {exc}")
    return {"status":"verified" if not errors else "blocked", "problems":errors,
            "checked_repository": repository, "checked_commit":sha,
            "publication_performed":False}

def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("evidence")
    p.add_argument("--repository", required=True)
    p.add_argument("--workflows", required=True, help="JSON file mapping five check keys to exact workflow names")
    args = p.parse_args(argv)
    try:
        evidence = json.loads(open(args.evidence, encoding="utf-8").read())
        names = json.loads(open(args.workflows, encoding="utf-8").read())
        if set(REQUIRED) != set(names) or not all(isinstance(v,str) and v for v in names.values()):
            raise ValueError("workflow mapping must contain exact five workflow names")
        result = verify(evidence, args.repository, names)
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print(f"BLOCK RELEASE: {error}", file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "verified" else 2

if __name__ == "__main__":
    raise SystemExit(main())
