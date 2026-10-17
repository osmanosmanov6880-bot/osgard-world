#!/usr/bin/env python3
"""Recover an active Core REMIX arena run using real isolated HTTP processes.

The drill creates its own accounts and databases under a new private directory.
It never reads production data or accepts a remote API origin. Only its JSON
report may be published; the work directory contains private account/session
data. This exercises the opt-in Core arena, not the separate legacy simulator.
"""
from contextlib import closing
from pathlib import Path
import argparse
import importlib.util
import json
import os
import secrets
import signal
import sqlite3
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "server"))
from core_backup import (checked_path, check_sqlite, copy_snapshot, create_backup_bundle,
                         digest, json_bytes, new_restore_directory, restore_backup,
                         utc_now, write_private)
from remix_acceptance import route_to_goal
from remix_service import RULESET, canonical, checksum, verify_replay

_spec = importlib.util.spec_from_file_location("osgard_core_recovery_helper", ROOT / "scripts/core-recovery-drill.py")
core_recovery = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(core_recovery)


def check(condition, label):
    if not condition:
        raise AssertionError(label)


class LocalArena(core_recovery.LocalCore):
    """Reuse the bounded Core launcher/HTTP client with only the arena enabled."""
    def __init__(self, web_root, database):
        super().__init__(web_root, database, enable_remix=True)
        self.requests = self.responses = 0
        self.crashed = False

    def request(self, *args, **kwargs):
        self.requests += 1
        response = super().request(*args, **kwargs)
        self.responses += 1
        return response

    def crash(self):
        check(self.process is not None and self.process.poll() is None, "live process before forced termination")
        self.process.kill()
        self.process.wait(timeout=5)
        check(self.process.returncode == -signal.SIGKILL, "actual forced application termination")
        self.crashed = True

    def __exit__(self, kind, error, traceback):
        if self.crashed:
            self.close()
            if kind is None:
                check(self.process.returncode == -signal.SIGKILL, "crashed process remains stopped")
        else:
            super().__exit__(kind, error, traceback)


def arena_request(server, token, route, body=None, *, key=None, expected=200):
    return server.request("GET" if body is None else "POST", "remix/v1/" + route,
                          body, token=token, key=key, expected=expected)


def normalized_ack(value):
    return {key: data for key, data in value.items() if key != "replayed"}


def prefix_rows(database, match_id):
    """Private comparison data, never included in a published report."""
    with closing(sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)) as db:
        db.row_factory = sqlite3.Row
        match = db.execute("SELECT * FROM remix_matches WHERE id=?", (match_id,)).fetchone()
        inputs = db.execute("SELECT * FROM remix_inputs WHERE match_id=? ORDER BY sequence", (match_id,)).fetchall()
        return {"match": dict(match), "inputs": [dict(row) for row in inputs]}


def game_rows(database):
    """Compare all arena rows around deliberately rejected corruption requests."""
    with closing(sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)) as db:
        db.row_factory = sqlite3.Row
        return {name: sorted(canonical(dict(row)) for row in db.execute('SELECT * FROM "' + name + '"'))
                for name in ("remix_challenges", "remix_matches", "remix_inputs", "remix_operations")}


def verify_health(server):
    health = server.request("GET", "health")
    capabilities = arena_request(server, None, "capabilities")
    check(health["status"] == "ok" and health["payments"] is False, "healthy isolated Core without payments")
    check(capabilities["ruleset"] == RULESET and capabilities["service"] == "osgard-remix-arena"
          and capabilities["resultAuthority"] == "server-input-journal" and capabilities["playersPerMatch"] == 1,
          "explicit single-actor Core arena contract")


def finish_proof(server, account, state):
    for dx, dy in route_to_goal(state["arena"], state["position"]):
        reply = arena_request(server, account["token"], "matches/" + state["id"] + "/input",
                              {"sequence": state["sequence"] + 1, "moveX": dx, "moveY": dy, "jump": False})
        state = reply["state"]
    result = arena_request(server, account["token"], "matches/" + state["id"] + "/result")
    replay = arena_request(server, account["token"], "matches/" + state["id"] + "/replay")
    verify_replay(replay)
    check(state["phase"] == "RESULTS" and result["won"] and result["purpose"] == "creator-proof"
          and result["replayHash"] == replay["hash"], "completed server-verified creator proof")
    return state, replay


def run_drill(work_dir):
    started = time.monotonic()
    report = {
        "schema_version": 1, "status": "running", "started_at": utc_now(), "ruleset": RULESET,
        "scope": "Isolated active Core REMIX arena recovery with real HTTP, process death and private synthetic data",
        "production_backup_used": False, "production_modified": False,
        "production_restore_tested": False, "production_rto_rpo_measured": False,
        "external_requests_performed": False, "payments_enabled": False,
        "remix_enabled": True, "legacy_active_match_recovery_tested": False,
        "checks": [], "timings_ms": {},
    }
    work, stage, processes = None, "prepare-isolated-directory", []
    try:
        work = new_restore_directory(work_dir)
        root, private, snapshots = work / "public", work / "live", work / "snapshots"
        for path in (root, private, snapshots):
            path.mkdir(mode=0o700)
        (root / "index.html").write_text("<!doctype html><title>Local REMIX recovery exercise</title>\n")
        database, snapshot = private / "core.sqlite3", snapshots / "core.sqlite3"
        manifest = Path(str(snapshot) + ".manifest.json")
        credentials = {name: {"username": "remix_drill_" + name + "_" + secrets.token_hex(4),
                              "password": secrets.token_urlsafe(32)} for name in ("creator", "challenger", "outsider")}
        stage = "create-http-proof-and-active-prefix"
        live = LocalArena(root, database)
        processes.append(live)
        with live:
            verify_health(live)
            with core_recovery.wal_reader(database):
                accounts = {name: live.request("POST", "auth/register", value) for name, value in credentials.items()}
                creator, challenger, outsider = (accounts[name] for name in ("creator", "challenger", "outsider"))
                challenge = arena_request(live, creator["token"], "challenges",
                                          {"title": "Isolated active recovery challenge", "seed": 42,
                                           "mode": "speed", "visibility": "public"})
                proof = arena_request(live, creator["token"], "matches", {"challengeId": challenge["id"], "maxPlayers": 1})
                proof, proof_replay = finish_proof(live, creator, proof)
                arena_request(live, creator["token"], "challenges/" + challenge["id"] + "/validate", {"matchId": proof["id"]})
                published = arena_request(live, creator["token"], "challenges/" + challenge["id"] + "/publish", {})
                check(published["status"] == "PUBLISHED", "creator proof permits publication")
                run = arena_request(live, challenger["token"], "matches", {"challengeId": challenge["id"], "maxPlayers": 1})
                run_route = "matches/" + run["id"]
                moves = [{"sequence": index + 1, "moveX": dx, "moveY": dy, "jump": False}
                         for index, (dx, dy) in enumerate(route_to_goal(run["arena"], run["position"]))]
                check(len(moves) > 6, "long enough route to preserve an active recovery point")
                keys = [uuid.uuid4().hex for _ in moves]
                prefix_length = 4
                for move, key in zip(moves[:prefix_length], keys):
                    prefix_ack = arena_request(live, challenger["token"], run_route + "/input", move, key=key)
                before = arena_request(live, challenger["token"], run_route + "/state")
                check(before == prefix_ack["state"] and before["phase"] == "PLAYING"
                      and before["sequence"] == prefix_length, "confirmed active prefix before backup")
                prefix = prefix_rows(database, run["id"])
                check(len(prefix["inputs"]) == prefix_length, "one durable row per accepted prefix input")
                check(Path(str(database) + "-wal").stat().st_size > 0, "active arena writes are in WAL")
                with closing(sqlite3.connect(database.as_uri() + "?mode=ro&immutable=1", uri=True)) as raw_main:
                    check(raw_main.execute("SELECT COUNT(*) FROM remix_matches").fetchone()[0] == 0,
                          "raw main database omits current arena matches")
                try:
                    copy_snapshot(database, work / "rejected-active-copy.sqlite3")
                except ValueError as error:
                    check("sidecar" in str(error), "active WAL is the reason the offline copy is rejected")
                    check(not (work / "rejected-active-copy.sqlite3").exists(), "WAL copy is rejected without publishing a file")
                else:
                    raise AssertionError("active main-file copy was accepted")
                report["checks"].extend(["real_http_creator_proof_publication_and_active_challenger",
                                         "active_wal_main_file_is_stale_and_offline_copy_is_rejected"])
                stage = "online-active-backup"
                timer = time.monotonic()
                bundle = create_backup_bundle(database, snapshot)
                report["timings_ms"]["online_backup"] = round((time.monotonic() - timer) * 1000, 2)
                check(prefix_rows(snapshot, run["id"]) == prefix, "online snapshot contains exact committed input prefix")
                with closing(sqlite3.connect(snapshot.as_uri() + "?mode=ro&immutable=1", uri=True)) as saved:
                    counts = {name: saved.execute('SELECT COUNT(*) FROM "' + name + '"').fetchone()[0]
                              for name in ("users", "remix_challenges", "remix_matches", "remix_inputs")}
                check(counts == {"users": 3, "remix_challenges": 1, "remix_matches": 2,
                                 "remix_inputs": proof["sequence"] + prefix_length}, "snapshot arena and account relations")
                later_ack = arena_request(live, challenger["token"], run_route + "/input",
                                          moves[prefix_length], key=keys[prefix_length])
                check(later_ack["state"]["sequence"] == prefix_length + 1, "later committed input lies after the recovery point")
                stage = "force-kill-active-source"
                live.crash()
            report["checks"].append("online_backup_preserves_active_prefix_before_later_input_and_sigkill")

        stage = "restart-source-and-record-deterministic-continuation"
        timer = time.monotonic()
        restarted = LocalArena(root, database)
        processes.append(restarted)
        with restarted:
            check(restarted.process.pid != live.process.pid, "source restart has a new process")
            verify_health(restarted)
            check(arena_request(restarted, challenger["token"], run_route + "/state") == later_ack["state"],
                  "SIGKILL restart recovers the last acknowledged move")
            duplicate = arena_request(restarted, challenger["token"], run_route + "/input",
                                      moves[prefix_length], key=keys[prefix_length])
            check(duplicate.get("replayed") is True and normalized_ack(duplicate) == normalized_ack(later_ack),
                  "SIGKILL restart preserves idempotent input response")
            continuation = [later_ack]
            for move, key in zip(moves[prefix_length + 1:], keys[prefix_length + 1:]):
                continuation.append(arena_request(restarted, challenger["token"], run_route + "/input", move, key=key))
            source_result = arena_request(restarted, challenger["token"], run_route + "/result")
            source_replay = arena_request(restarted, challenger["token"], run_route + "/replay")
            verify_replay(source_replay)
            check(source_result["won"] and source_replay["result"]["won"], "source reference continuation finishes")
        core_recovery.checkpoint_stopped_exercise_database(database)
        source_digest = digest(database)
        report["timings_ms"]["source_restart_and_continuation"] = round((time.monotonic() - timer) * 1000, 2)
        report["checks"].append("new_source_process_recovers_acknowledged_input_and_idempotent_retry")

        stage = "restore-bound-active-snapshot"
        timer = time.monotonic()
        restored = restore_backup(snapshot, manifest, work / "restored", expected_sha256=bundle["sha256"])
        restored_db = work / "restored/core.sqlite3"
        check(prefix_rows(restored_db, run["id"]) == prefix, "restored database equals the active snapshot prefix")
        report["backup"] = {key: bundle[key] for key in ("sha256", "bytes", "manifest_sha256", "snapshot_method")}
        report["restored_sqlite"] = restored["sqlite"]
        report["timings_ms"]["offline_restore"] = round((time.monotonic() - timer) * 1000, 2)
        stage = "restored-http-auth-ownership-and-continuation"
        recovered = LocalArena(root, restored_db)
        processes.append(recovered)
        with recovered:
            verify_health(recovered)
            for account in accounts.values():
                check(recovered.request("GET", "auth/me", token=account["token"])["user"] == account["user"],
                      "restored hashed session retains its own user")
            login = recovered.request("POST", "auth/login", credentials["challenger"])
            check(login["user"] == challenger["user"], "restored password authenticates the challenger")
            for token, expected in ((None, 401), (creator["token"], 404), (outsider["token"], 404)):
                arena_request(recovered, token, run_route + "/state", expected=expected)
                arena_request(recovered, token, run_route + "/input", moves[prefix_length], expected=expected)
            after = arena_request(recovered, login["token"], run_route + "/state")
            check(after == before and after["sequence"] < later_ack["state"]["sequence"], "later source input is excluded from restored state")
            check(arena_request(recovered, creator["token"], "challenges/" + challenge["id"]) == published,
                  "published challenge and creator relation survive")
            check(arena_request(recovered, creator["token"], "matches/" + proof["id"] + "/replay") == proof_replay,
                  "creator proof journal survives alongside active challenger")
            report["checks"].extend(["restored_password_and_all_session_relations_authenticate",
                                     "restored_owner_creator_outsider_and_anonymous_access_controls",
                                     "snapshot_prefix_excludes_later_source_input_and_preserves_published_proof"])
            for key in (keys[prefix_length - 1], uuid.uuid4().hex):
                retried = arena_request(recovered, login["token"], run_route + "/input", moves[prefix_length - 1], key=key)
                check(retried.get("replayed") is True and normalized_ack(retried) == normalized_ack(prefix_ack),
                      "restored operation/sequence retries return the original response")
            arena_request(recovered, login["token"], run_route + "/input", dict(moves[prefix_length - 1], jump=True),
                          key=keys[prefix_length - 1], expected=409)
            check(prefix_rows(restored_db, run["id"]) == prefix, "retries do not add an input or advance the prefix")
            report["checks"].append("restored_operation_and_sequence_idempotence_without_duplicate_input")
            for move, key, reference in zip(moves[prefix_length:], keys[prefix_length:], continuation):
                replayed = arena_request(recovered, login["token"], run_route + "/input", move, key=key)
                check(normalized_ack(replayed) == normalized_ack(reference), "each resumed step matches the source continuation")
            result = arena_request(recovered, login["token"], run_route + "/result")
            replay = arena_request(recovered, login["token"], run_route + "/replay")
            verify_replay(replay)
            check(result == source_result and replay == source_replay, "resumed result and full replay are exactly equal")
            scores = arena_request(recovered, creator["token"], "challenges/" + challenge["id"] + "/leaderboard")["scores"]
            check(len(scores) == 1 and scores[0]["playerId"] == challenger["user"]["id"]
                  and scores[0]["score"] == result["score"], "leaderboard verifies restored challenger and excludes creator proof")
            for suffix in ("result", "replay"):
                arena_request(recovered, outsider["token"], run_route + "/" + suffix, expected=404)
            finished = arena_request(recovered, login["token"], run_route + "/input",
                                     {"sequence": len(moves) + 1, "moveX": 1, "moveY": 0, "jump": False}, expected=409)
            check(finished["error"] == "match_finished", "completed restored run rejects a later new input")
            report["checks"].extend(["every_restored_step_matches_source_and_full_replay_resimulates",
                                     "restored_result_replay_leaderboard_and_terminal_input_boundaries"])

        core_recovery.checkpoint_stopped_exercise_database(restored_db)
        final_sqlite = check_sqlite(restored_db, require_core=True)
        report["post_http_sqlite"] = {key: value for key, value in final_sqlite.items() if key != "tables"}
        stage = "reject-corrupt-active-copy-without-writes"
        restore_backup(snapshot, manifest, work / "corrupted", expected_sha256=bundle["sha256"])
        corrupt_db = work / "corrupted/core.sqlite3"
        with closing(sqlite3.connect(corrupt_db)) as db:
            state = json.loads(prefix["match"]["state_json"])
            state["position"] = [11, 6]
            check(state != json.loads(prefix["match"]["state_json"]), "deliberately changed active state in isolated copy")
            db.execute("UPDATE remix_matches SET state_json=? WHERE id=?", (canonical(state), run["id"]))
            db.commit()
        corrupt_before = game_rows(corrupt_db)
        corrupted = LocalArena(root, corrupt_db)
        processes.append(corrupted)
        with corrupted:
            for route, body, key in ((run_route + "/state", None, None),
                                     (run_route + "/input", moves[prefix_length], uuid.uuid4().hex),
                                     (run_route + "/input", moves[prefix_length - 1], keys[prefix_length - 1])):
                rejected = arena_request(corrupted, challenger["token"], route, body, key=key, expected=503)
                check(rejected["error"] == "replay_integrity", "corrupt active prefix returns the integrity error")
            check(game_rows(corrupt_db) == corrupt_before, "rejected corrupt reads/new writes/cached retries leave all arena rows unchanged")
        report["checks"].append("corrupt_active_copy_rejects_reads_fresh_input_and_cached_retry_without_writes")
        check(digest(database) == source_digest, "restored/corrupt branches never change source data")
        check(digest(snapshot) == bundle["sha256"] and digest(manifest) == bundle["manifest_sha256"],
              "original backup and manifest remain unchanged")
        report["checks"].append("final_sqlite_fk_checks_and_source_snapshot_immutability")
        report["observed_records_at_snapshot"] = counts
        report["recovery_point"] = {"snapshot_sequence": prefix_length,
                                    "later_source_sequence": later_ack["state"]["sequence"], "later_input_excluded": True,
                                    "prefix_sha256": checksum(prefix)}
        report["continuation"] = {"resumed_inputs": len(continuation), "final_sequence": len(moves),
                                  "result_sha256": checksum(result), "replay_sha256": replay["hash"],
                                  "same_result_as_source": True, "same_replay_as_source": True}
        report["status"] = "passed"
    except Exception as error:
        # Error text from external dependencies or injected failures may contain
        # a private path or credential. Publish the fixed phase and type only.
        report["status"] = "failed"
        report["failure"] = {"stage": stage, "error_type": type(error).__name__}
    finally:
        report["processes"] = {"started": sum(p.process is not None for p in processes),
                               "forced_terminations": sum(p.crashed for p in processes)}
        report["http"] = {"requests": sum(p.requests for p in processes),
                          "verified_responses": sum(p.responses for p in processes), "loopback_only": True}
        report["completed_at"] = utc_now()
        report["timings_ms"]["total"] = round((time.monotonic() - started) * 1000, 2)
        if work is not None:
            write_private(work / "report.json", json_bytes(report))
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work-dir", required=True, type=Path, help="new private exercise directory; existing parent required")
    parser.add_argument("--report", type=Path, help="new JSON report path; publish only this file")
    args = parser.parse_args(argv)
    try:
        if args.report is not None:
            report_path = checked_path(args.report, missing=True)
            if os.path.lexists(report_path):
                raise ValueError("Report already exists.")
            if not checked_path(report_path.parent).is_dir():
                raise ValueError("Report parent must exist.")
        report = run_drill(args.work_dir)
        if args.report is not None:
            write_private(report_path, json_bytes(report))
    except (ValueError, OSError, sqlite3.Error, subprocess.SubprocessError) as error:
        print("LOCAL REMIX RECOVERY FAILED: " + type(error).__name__, file=sys.stderr)
        return 2
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["status"] == "passed" else 2


if __name__ == "__main__":
    raise SystemExit(main())
