#!/usr/bin/env python3
"""Complete local Core HTTP -> online backup -> offline restore -> fresh HTTP drill.

Creates only explicitly labelled local exercise data in an exclusively new
directory. It never discovers an existing database, accepts a remote API URL,
loads production credentials, or claims a production recovery/RTO/RPO result.
Only the JSON report is suitable for CI artifacts; the private work directory
contains SQLite password/session hashes and must not be published.
"""
from contextlib import closing, contextmanager
from http.client import HTTPConnection
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import secrets
import selectors
import signal
import sqlite3
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "server"))
from core_backup import (checked_path, copy_snapshot, create_backup_bundle, digest,
                         json_bytes, new_restore_directory, restore_backup,
                         check_sqlite, utc_now, write_private)


def check(condition, label):
    if not condition:
        raise ValueError("Core recovery check failed: " + label)


class LocalCore:
    """A fresh application process whose only listener is an ephemeral loopback port."""
    def __init__(self, web_root, database):
        self.root, self.database = web_root, database
        self.process = None
        self.port = None

    def __enter__(self):
        allowed = {"PATH", "LANG", "LC_ALL", "LC_CTYPE", "SYSTEMROOT", "WINDIR", "TMPDIR", "TEMP", "TMP", "LD_LIBRARY_PATH"}
        env = {key: value for key, value in os.environ.items() if key in allowed}
        env.update(OSGARD_COMMERCE_ENABLED="0", PYTHONDONTWRITEBYTECODE="1", PYTHONUNBUFFERED="1", PYTHONNOUSERSITE="1")
        self.process = subprocess.Popen(
            [sys.executable, str(ROOT / "server/core_server.py"), "--root", str(self.root),
             "--database", str(self.database), "--host", "127.0.0.1", "--port", "0"],
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, env=env, cwd=self.database.parent)
        deadline = time.monotonic() + 20
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(self.process.stdout, selectors.EVENT_READ)
                while time.monotonic() < deadline:
                    if self.process.poll() is not None:
                        # Startup has no accounts or credentials. Keep diagnostics
                        # bounded so a missing dependency/bind denial is actionable.
                        detail = self.process.stdout.read(3000).strip()
                        raise ValueError("Isolated Core process exited before announcing its loopback listener. " + detail)
                    if not selector.select(timeout=0.1):
                        continue
                    line = self.process.stdout.readline()
                    match = re.search(r"^OSGARD Core: http://127\.0\.0\.1:(\d+)/workspace", line)
                    if match:
                        self.port = int(match[1])
                        check(0 < self.port < 65536, "valid ephemeral port")
                        return self
            raise ValueError("Isolated Core startup timed out.")
        except BaseException:
            self.close()
            raise

    def close(self):
        if self.process is None:
            return
        if self.process.poll() is None:
            self.process.send_signal(signal.SIGINT)
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                try:
                    self.process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    self.process.kill()
                    self.process.wait(timeout=3)
        self.process.stdout.close()

    def __exit__(self, kind, error, traceback):
        self.close()
        if kind is None:
            check(self.process.returncode == 0, "application process exits cleanly")

    def request(self, method, route, body=None, *, token=None, key=None, expected=200):
        headers = {"Origin": f"http://127.0.0.1:{self.port}"}
        if token:
            headers["Authorization"] = "Bearer " + token
        if method == "POST":
            headers["Idempotency-Key"] = key or uuid.uuid4().hex
        raw = json.dumps(body).encode() if body is not None else None
        if raw is not None:
            headers["Content-Type"] = "application/json"
        connection = HTTPConnection("127.0.0.1", self.port, timeout=5)
        try:
            connection.request(method, "/api/core/" + route, raw, headers)
            response = connection.getresponse()
            content = response.read(4 * 1024 * 1024 + 1)
            check(len(content) <= 4 * 1024 * 1024, "bounded HTTP response")
            # Never include body/token/credentials in the error report.
            safe_route = re.sub(r"[a-f0-9]{32}", "{id}", route)
            check(response.status == expected, f"HTTP {method} {safe_route} returned {response.status}, expected {expected}")
            return json.loads(content)
        finally:
            connection.close()


@contextmanager
def wal_reader(database):
    """Keep committed HTTP writes in WAL without seeding or modifying SQL rows."""
    connection = sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)
    try:
        connection.execute("BEGIN")
        connection.execute("SELECT COUNT(*) FROM projects").fetchone()
        yield
    finally:
        connection.close()


def checkpoint_stopped_exercise_database(database):
    """Only called on this drill's own databases after their process has exited."""
    with closing(sqlite3.connect(database, timeout=3)) as connection:
        check(connection.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()[0] == 0, "stopped local database can checkpoint")
        check(connection.execute("PRAGMA journal_mode=DELETE").fetchone()[0] == "delete", "stopped local database is standalone")


def run_drill(work_dir):
    started = time.monotonic()
    report = {
        "schema_version": 1, "status": "running", "started_at": utc_now(),
        "scope": "Complete isolated local Core HTTP recovery exercise with newly-created local data",
        "production_backup_used": False, "production_modified": False,
        "production_restore_tested": False, "production_rto_rpo_measured": False,
        "external_requests_performed": False, "payments_enabled": False, "remix_enabled": False,
        "checks": [], "timings_ms": {},
    }
    work = None
    try:
        work = new_restore_directory(work_dir)
        root, private, snapshots = work / "public", work / "live", work / "snapshots"
        for path in (root, private, snapshots):
            path.mkdir(mode=0o700)
        (root / "index.html").write_text("<!doctype html><title>Local Core recovery exercise</title>\n")
        database, snapshot = private / "core.sqlite3", snapshots / "core.sqlite3"
        manifest = Path(str(snapshot) + ".manifest.json")
        credentials = {name: {"username": "drill_" + name + "_" + secrets.token_hex(4),
                              "password": secrets.token_urlsafe(32)} for name in ("owner", "viewer", "outsider")}
        with LocalCore(root, database) as live:
            source_pid = live.process.pid
            health = live.request("GET", "health")
            check(health["status"] == "ok" and health["schemaVersion"] == 1 and health["payments"] is False, "live Core health and disabled Commerce")
            with wal_reader(database):
                accounts = {name: live.request("POST", "auth/register", data) for name, data in credentials.items()}
                owner, viewer, outsider = (accounts[name] for name in ("owner", "viewer", "outsider"))
                created = live.request("POST", "projects", {"title": "Local recovery exercise", "goal": "Verify consistent backup and relational application state after restore."}, token=owner["token"])
                project = created["project"]
                route = "projects/" + project["id"]

                def update(changes):
                    nonlocal project
                    result = live.request("POST", route, {"expectedVersion": project["version"], "changes": changes}, token=owner["token"])
                    project = result["project"]

                update({"audience": "State included in the online snapshot", "budgetMinor": 20000,
                        "consents": {"learning": True, "studio": True, "business": True},
                        "allowedActions": ["local_checks", "build_preview"],
                        "acceptance": [{"id": "recover", "title": "Recover the saved project and its linked artifact", "done": True}]})
                update({"accepted": True})
                cost_key = uuid.uuid4().hex
                cost_body = {"expectedVersion": project["version"], "kind": "record_cost",
                             "payload": {"amountMinor": 1250, "category": "other", "note": "Self-reported exercise cost; no payment performed."}}
                project = live.request("POST", route + "/actions", cost_body, token=owner["token"], key=cost_key)["project"]
                project = live.request("POST", route + "/actions", {"expectedVersion": project["version"], "kind": "build_preview", "payload": {}}, token=owner["token"])["project"]
                project = live.request("POST", route + "/members", {"expectedVersion": project["version"], "username": credentials["viewer"]["username"], "role": "viewer"}, token=owner["token"])["project"]
                queued = live.request("POST", route + "/jobs", {"expectedVersion": project["version"]}, token=owner["token"])
                deadline = time.monotonic() + 10
                while True:
                    jobs = live.request("GET", route + "/jobs", token=owner["token"])["jobs"]
                    completed = next((job for job in jobs if job["id"] == queued["jobId"] and job["status"] == "completed"), None)
                    if completed:
                        break
                    check(time.monotonic() < deadline, "real local worker finishes queued operation")
                    time.sleep(0.05)
                before = live.request("GET", route + "/export", token=owner["token"])
                members_before = live.request("GET", route + "/members", token=owner["token"])
                check(len(before["assets"]) == 1 and len(before["jobs"]) == 1 and len(before["project"]["data"]["costs"]) == 1, "real linked records created over HTTP")
                check(Path(str(database) + "-wal").stat().st_size > 0, "live WAL contains committed application writes")
                with closing(sqlite3.connect(database.as_uri() + "?mode=ro&immutable=1", uri=True)) as main_only:
                    raw_count = main_only.execute("SELECT COUNT(*) FROM projects").fetchone()[0]
                check(raw_count == 0, "held reader makes raw main-file copy stale")
                try:
                    copy_snapshot(database, work / "must-not-copy-active.sqlite3")
                except ValueError as error:
                    check("sidecar" in str(error), "active WAL rejection is explicit")
                else:
                    raise ValueError("Active WAL main file was incorrectly admitted as an offline snapshot.")
                check(not (work / "must-not-copy-active.sqlite3").exists(), "rejected stale copy publishes no file")
                report["checks"].extend(["real_http_accounts_project_membership_asset_cost_and_queue",
                                         "active_wal_main_file_is_demonstrably_stale_and_rejected"])
                timer = time.monotonic()
                bundle = create_backup_bundle(database, snapshot)
                report["timings_ms"]["online_backup_and_metadata"] = round((time.monotonic() - timer) * 1000, 2)
                with closing(sqlite3.connect(snapshot.as_uri() + "?mode=ro&immutable=1", uri=True)) as saved:
                    check(saved.execute("SELECT COUNT(*) FROM projects").fetchone()[0] == 1, "online backup includes committed WAL data")
                    snapshot_counts = {table: saved.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
                                       for table in ("users", "projects")}
                    check(snapshot_counts == {"users": 3, "projects": 1}, "snapshot contains exactly the HTTP-created accounts and project")
            update({"audience": "Later live write deliberately outside the recovery point"})
            report["recovery_point"] = {"snapshot_project_revision": before["project"]["version"],
                                        "later_live_revision": project["version"], "later_change_excluded": True}
            report["checks"].append("online_backup_includes_wal_and_source_remains_writable")
        checkpoint_stopped_exercise_database(database)
        source_fingerprint = digest(database)
        timer = time.monotonic()
        restored = restore_backup(snapshot, manifest, work / "restored", expected_sha256=bundle["sha256"])
        report["timings_ms"]["offline_restore"] = round((time.monotonic() - timer) * 1000, 2)
        report["backup"] = {key: bundle[key] for key in ("sha256", "bytes", "manifest_sha256", "snapshot_method")}
        report["restored_sqlite"] = restored["sqlite"]
        timer = time.monotonic()
        with LocalCore(root, work / "restored/core.sqlite3") as recovered:
            check(recovered.process.pid != source_pid, "restored server is a fresh process")
            health = recovered.request("GET", "health")
            check(health["status"] == "ok" and health["payments"] is False and health["schemaVersion"] == 1, "restored Core health and disabled Commerce")
            restored_owner = recovered.request("GET", "auth/me", token=owner["token"])
            check(restored_owner["user"] == owner["user"], "hashed session and owner relation survives")
            login = recovered.request("POST", "auth/login", credentials["owner"])
            check(login["user"] == owner["user"], "restored password hash authenticates")
            after = recovered.request("GET", route + "/export", token=login["token"])
            for key in ("project", "snapshots", "revisions", "events", "assets", "jobs"):
                check(after[key] == before[key], "restored " + key + " matches the recovery point")
            check(recovered.request("GET", route + "/members", token=owner["token"]) == members_before, "membership/user join survives")
            check(recovered.request("GET", route, token=viewer["token"])["project"]["role"] == "viewer", "restored member read access")
            recovered.request("POST", route, {"expectedVersion": after["project"]["version"], "changes": {"audience": "must be denied"}}, token=viewer["token"], expected=403)
            recovered.request("GET", route, token=outsider["token"], expected=404)
            recovered.request("GET", route, expected=401)
            revisions = {item["version"] for item in after["snapshots"]}
            for asset in after["assets"]:
                result = recovered.request("GET", route + "/assets/" + asset["id"], token=viewer["token"])["asset"]
                check(result == asset and asset["sourceVersion"] in revisions, "asset HTTP content and source revision are linked")
                check(hashlib.sha256(result["html"].encode()).hexdigest() == result["sha256"], "restored artifact content hash")
            check(all(job["sourceVersion"] in revisions for job in after["jobs"]), "completed jobs reference restored revisions")
            replay = recovered.request("POST", route + "/actions", cost_body, token=owner["token"], key=cost_key)
            check(replay.get("replayed") is True, "persisted idempotency record replays")
            unchanged = recovered.request("GET", route, token=owner["token"])["project"]
            check(unchanged == before["project"] and unchanged["economics"]["confirmedRevenueMinor"] == 0, "replay does not duplicate cost or invent revenue")
            written = recovered.request("POST", route, {"expectedVersion": unchanged["version"], "changes": {"audience": "A new write in the isolated restored branch"}}, token=login["token"])["project"]
            check(written["version"] == unchanged["version"] + 1, "restored database accepts a real new mutation")
            report["checks"].extend(["fresh_restored_process_starts_without_production_credentials",
                                     "password_and_hashed_session_authentication_survive",
                                     "project_revisions_events_assets_jobs_and_costs_match_snapshot",
                                     "owner_viewer_outsider_and_anonymous_http_access_controls",
                                     "asset_hash_and_job_source_revision_relationships",
                                     "idempotent_retry_survives_without_duplicate_ledger_entry",
                                     "restored_database_accepts_new_http_write"])
        report["timings_ms"]["restored_process_and_http_verification"] = round((time.monotonic() - timer) * 1000, 2)
        check(digest(database) == source_fingerprint, "restored writes never change the stopped source database")
        check(digest(snapshot) == bundle["sha256"] and digest(manifest) == bundle["manifest_sha256"], "backup and metadata remain unchanged")
        checkpoint_stopped_exercise_database(work / "restored/core.sqlite3")
        final_check = check_sqlite(work / "restored/core.sqlite3", require_core=True)
        with closing(sqlite3.connect((work / "restored/core.sqlite3").as_uri() + "?mode=ro&immutable=1", uri=True)) as persisted:
            check(persisted.execute("SELECT version FROM projects WHERE id=?", (written["id"],)).fetchone()[0] == written["version"], "new restored write persists after server exit")
        report["checks"].append("final_sqlite_integrity_fk_and_source_snapshot_immutability")
        report["post_http_sqlite"] = {key: value for key, value in final_check.items() if key != "tables"}
        report["observed_records"] = {**snapshot_counts, "members": len(members_before["members"]),
                                       "revisions_at_snapshot": len(before["snapshots"]), "assets": len(before["assets"]),
                                       "completed_jobs": len(before["jobs"]), "cost_entries": len(before["project"]["data"]["costs"])}
        report["status"] = "passed"
    except Exception as error:
        report["status"] = "failed"
        report["error"] = str(error)[:1000]
    finally:
        report["completed_at"] = utc_now()
        report["timings_ms"]["total"] = round((time.monotonic() - started) * 1000, 2)
        if work is not None:
            write_private(work / "report.json", json_bytes(report))
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work-dir", required=True, type=Path, help="new private work directory; parent must exist")
    parser.add_argument("--report", type=Path, help="optional new JSON report path, safe to upload without SQLite files")
    args = parser.parse_args(argv)
    try:
        if args.report is not None:
            report_path = checked_path(args.report, missing=True)
            if os.path.lexists(report_path):
                raise ValueError("Report already exists; choose a new report path.")
            if not checked_path(report_path.parent).is_dir():
                raise ValueError("Report parent directory must already exist.")
        report = run_drill(args.work_dir)
        if args.report is not None:
            write_private(report_path, json_bytes(report))
    except (ValueError, OSError, sqlite3.Error, subprocess.SubprocessError) as error:
        print("LOCAL CORE RECOVERY FAILED: " + str(error), file=sys.stderr)
        return 2
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["status"] == "passed" else 2


if __name__ == "__main__":
    raise SystemExit(main())
