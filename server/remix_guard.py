#!/usr/bin/env python3
"""REMIX phase guard and durable terminal snapshots for the existing HTTP API.

This is original proxy code, not the legacy game implementation. Cooperating
ACL-aware processes share one local SQLite volume and its admission locks. The
guard serializes match requests, blocks input outside a verified playing phase,
and never changes a persisted terminal result. Optional v2 ownership verifies a
live Core session on every protected request; anonymous legacy matches remain
anonymous. Protected creation and addressed second-participant admission each
require an explicit enable flag. Existing rights remain enforced with either
flag disabled. Simulation,
active-match recovery, and complete replay verification remain unavailable here.
The read-before-write gate cannot make the legacy simulator's phase expiry
atomic. The durable guarantee starts at the first observed terminal phase.
"""

from __future__ import annotations

import argparse
from contextlib import closing, contextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import errno
import fcntl
import hashlib
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
from pathlib import Path
import re
import secrets
import socket
import sqlite3
import stat
import threading
import time
from urllib.parse import parse_qs, urlsplit


VERSION = 1
AUTH_POLICY_VERSION = 1
OWNED_SCHEMA_VERSION = 2
PARTICIPANT_SCHEMA_VERSION = 3
PARTICIPANT_POLICY_VERSION = 1
INVITATION_TTL_SECONDS = 120
MAX_WORKERS = 32
MAX_BODY = 256 * 1024
MAX_RESPONSE = 1024 * 1024
MAX_SAFE_INTEGER = 2 ** 53 - 1
ID = r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}"
MATCH_ROUTE = re.compile(r"^/v1/matches/(?P<id>" + ID + r")/(?P<action>state|result|input)$")
OWNED_MATCH_ROUTE = re.compile(r"^/v2/matches/(?P<id>" + ID + r")(?:/(?P<action>state|result|input))?$")
ATTEMPT_ROUTE = re.compile(r"^/v2/creation-attempts/(?P<key>[A-Za-z0-9_-]{16,100})$")
INVITATION_CREATE_ROUTE = re.compile(r"^/v2/matches/(?P<id>" + ID + r")/invitations$")
INVITATION_ROUTE = re.compile(r"^/v2/invitations/(?P<id>inv_[0-9a-f]{32})(?:/(?P<action>accept|revoke))?$")
ADMISSION_ATTEMPT_ROUTE = re.compile(r"^/v2/admission-attempts/(?P<key>[A-Za-z0-9_-]{16,100})$")
PHASES = {"WAITING", "COUNTDOWN", "PLAYING", "RUNNING", "RESULTS"}
HOP_HEADERS = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
               "te", "trailer", "transfer-encoding", "upgrade", "host", "content-length"}


def field_header(headers, name):
    values = [value for key, value in headers.items() if key.lower() == name.lower()]
    if len(values) > 1:
        raise GuardError("request_headers", "Duplicate authorization or operation header.", 400)
    return values[0] if values else ""


def request_object(body):
    try:
        value = decode_json(body)
    except GuardError as error:
        raise GuardError("invalid_request", "Send one valid JSON object.", 400) from error
    if not isinstance(value, dict):
        raise GuardError("invalid_request", "Send one valid JSON object.", 400)
    return value


class VolumeLocks:
    """Separate open-file descriptions: flock coordinates threads and processes.

    Lock order is admission SH/EX -> local match stripe -> file match stripe ->
    SQLite. No client value is used as a filename. A dead process releases its
    lease. An unknown orphan is never adopted or presented as protected.
    """
    def __init__(self, directory):
        self.directory = Path(directory)

    @contextmanager
    def lease(self, name, exclusive, deadline):
        expiry = min(deadline, time.monotonic() + 2)
        directory = os.open(self.directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
        fd = None
        try:
            fd = os.open(name, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600, dir_fd=directory)
            info = os.fstat(fd)
            current = os.stat(name, dir_fd=directory, follow_symlinks=False)
            if (not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_uid != os.geteuid()
                    or info.st_mode & 0o077 or (info.st_dev, info.st_ino) != (current.st_dev, current.st_ino)):
                raise OSError("Unsafe REMIX lock file")
            mode = fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH
            while True:
                if time.monotonic() >= expiry:
                    raise GuardError("match_busy", "Match admission is busy. Retry this read later.")
                try:
                    fcntl.flock(fd, mode | fcntl.LOCK_NB)
                    break
                except OSError as error:
                    if error.errno not in (errno.EAGAIN, errno.EACCES):
                        raise
                    time.sleep(min(0.01, max(0, expiry - time.monotonic())))
            yield
        finally:
            if fd is not None:
                os.close(fd)
            os.close(directory)

    def admission(self, exclusive, deadline):
        return self.lease("remix-admission.lock", exclusive, deadline)

    def match(self, match_id, deadline):
        stripe = hashlib.sha256(match_id.encode()).digest()[0]
        return self.lease(f"remix-match-{stripe:02x}.lock", True, deadline)


class GuardError(Exception):
    def __init__(self, code, message, status=503):
        super().__init__(message)
        self.code, self.message, self.status = code, message, status


def require(condition, message):
    if not condition:
        raise GuardError("upstream_contract", message)


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)


def json_pairs(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError("Duplicate JSON key")
        value[key] = item
    return value


def decode_json(raw):
    try:
        return json.loads(raw.decode("utf-8") if isinstance(raw, bytes) else raw,
                          object_pairs_hook=json_pairs)
    except (UnicodeError, ValueError, RecursionError) as error:
        raise GuardError("upstream_contract", "The match service returned invalid JSON.") from error


def terminal_identity(raw, field, match_id):
    """Recognize an unambiguous identity/phase before validating other fields.

    Object pairs remain distinct from arrays. Duplicate identity or phase keys
    are ambiguous; malformed/duplicate score fields cannot erase a clear
    terminal observation. The strict decoder still rejects that response.
    """
    try:
        pairs = json.loads(raw.decode("utf-8"), object_pairs_hook=tuple)
    except (UnicodeError, ValueError, RecursionError):
        return False
    if not isinstance(pairs, tuple):
        return False
    identifiers = [value for key, value in pairs if key == field]
    phases = [value for key, value in pairs if key == "phase"]
    return identifiers == [match_id] and phases == ["RESULTS"]


def natural(value):
    return type(value) is int and 0 <= value <= MAX_SAFE_INTEGER


def finite_number(value):
    try:
        return type(value) in (int, float) and math.isfinite(value)
    except OverflowError:
        return False


def validate_scores(value):
    require(isinstance(value, list) and len(value) <= 10000, "Invalid score roster.")
    seen = set()
    for score in value:
        require(isinstance(score, dict) and set(score) == {"playerId", "score"}, "Invalid score fields.")
        identifier = score["playerId"]
        require(isinstance(identifier, str) and re.fullmatch(ID, identifier), "Invalid player identifier.")
        require(identifier not in seen and finite_number(score["score"]), "Invalid or duplicate player score.")
        seen.add(identifier)
    return value


def validate_state(value, match_id):
    require(isinstance(value, dict) and set(value) == {"id", "phase", "players", "remainingMs", "replayFrames", "scores"},
            "Invalid match state fields.")
    require(value["id"] == match_id and value["phase"] in PHASES, "Match state identity or phase does not match.")
    require(natural(value["players"]) and natural(value["remainingMs"]) and natural(value["replayFrames"]),
            "Invalid match counters.")
    validate_scores(value["scores"])
    require(value["players"] == len(value["scores"]), "Match roster and player count disagree.")
    require(value["phase"] != "RESULTS" or value["remainingMs"] == 0, "Terminal match still has time remaining.")
    return value


def validate_result(value, match_id, state):
    require(isinstance(value, dict) and set(value) == {"matchId", "phase", "replayFrames", "scores"},
            "Invalid result fields.")
    require(value["matchId"] == match_id and value["phase"] == "RESULTS", "Result identity or phase does not match.")
    require(natural(value["replayFrames"]), "Invalid result frame count.")
    validate_scores(value["scores"])
    require(value["replayFrames"] == state["replayFrames"] and
            sorted((row["playerId"], row["score"]) for row in value["scores"]) ==
            sorted((row["playerId"], row["score"]) for row in state["scores"]),
            "Terminal state and result disagree; no result was exposed.")
    return value


class SnapshotStore:
    """Snapshots, membership, submission counters and durable intents; no sessions."""

    @staticmethod
    def validate_protected_schema(db, version=OWNED_SCHEMA_VERSION):
        # A schema-2 database has already crossed the protection boundary.
        # Recreating a lost ownership table as empty could classify protected
        # frozen results as anonymous. Refuse incomplete/restored fragments;
        # recovery requires the consistent database, not an empty ACL catalog.
        required = {
            "terminal_matches": [("match_id", 1), ("state_json", 0), ("result_json", 0), ("observed_at", 0), ("finalized_at", 0)],
            "guard_health": [("id", 1), ("sequence", 0)],
            "owned_matches": [("match_id", 1), ("owner_id", 0), ("player_id", 0), ("match_json", 0), ("highest_submitted_sequence", 0)],
            "owned_creation_attempts": [("owner_id", 1), ("operation_key", 2), ("request_hash", 0), ("status", 0),
                                        ("match_id", 0), ("upstream_status", 0), ("created_at", 0)],
            "anonymous_matches": [("match_id", 1)],
        }
        if version >= PARTICIPANT_SCHEMA_VERSION:
            required.update({
                "owned_participants": [("match_id", 1), ("account_id", 0), ("player_id", 0),
                                       ("highest_submitted_sequence", 0), ("invitation_id", 0), ("joined_at", 0)],
                "owned_invitations": [("invitation_id", 1), ("match_id", 0), ("owner_id", 0),
                                      ("recipient_id", 0), ("status", 0), ("created_at", 0), ("expires_at", 0)],
                "owned_admission_attempts": [("actor_id", 1), ("operation_key", 2), ("operation", 0),
                                             ("request_hash", 0), ("match_id", 0), ("invitation_id", 0),
                                             ("status", 0), ("error", 0), ("error_status", 0), ("created_at", 0)],
            })
        for name, columns in required.items():
            table = db.execute("SELECT type FROM sqlite_master WHERE name=?", (name,)).fetchone()
            actual = [(row["name"], row["pk"]) for row in db.execute(f'PRAGMA table_info("{name}")')]
            if table is None or table["type"] != "table" or actual != columns:
                raise ValueError("Protected REMIX storage schema is incomplete. Restore a consistent database before starting.")

    def __init__(self, path):
        self.request_context = threading.local()
        self.path = Path(path).absolute()
        if self.path.is_symlink():
            raise ValueError("The guard database cannot be a symlink.")
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        with self.connect() as db:
            version = db.execute("PRAGMA user_version").fetchone()[0]
            if version not in (0, VERSION, OWNED_SCHEMA_VERSION, PARTICIPANT_SCHEMA_VERSION):
                raise ValueError("Unsupported REMIX guard database version.")
            if db.execute("PRAGMA quick_check").fetchone()[0] != "ok":
                raise ValueError("REMIX guard database integrity check failed.")
            db.execute("PRAGMA journal_mode=WAL")
            db.execute("BEGIN IMMEDIATE")
            version = db.execute("PRAGMA user_version").fetchone()[0]
            if version >= OWNED_SCHEMA_VERSION:
                self.validate_protected_schema(db, version)
            db.execute("""CREATE TABLE IF NOT EXISTS terminal_matches(
                match_id TEXT PRIMARY KEY,
                state_json TEXT,
                result_json TEXT,
                observed_at TEXT NOT NULL,
                finalized_at TEXT,
                CHECK(result_json IS NULL OR (state_json IS NOT NULL AND finalized_at IS NOT NULL)))""")
            db.execute("CREATE TABLE IF NOT EXISTS guard_health(id INTEGER PRIMARY KEY CHECK(id=1), sequence INTEGER NOT NULL)")
            db.execute("INSERT OR IGNORE INTO guard_health VALUES(1,0)")
            db.execute("""CREATE TABLE IF NOT EXISTS owned_matches(
                match_id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, player_id TEXT NOT NULL,
                match_json TEXT NOT NULL, highest_submitted_sequence INTEGER NOT NULL DEFAULT 0
                CHECK(highest_submitted_sequence>=0))""")
            db.execute("CREATE INDEX IF NOT EXISTS owned_matches_owner ON owned_matches(owner_id,match_id)")
            db.execute("""CREATE TABLE IF NOT EXISTS owned_creation_attempts(
                owner_id TEXT NOT NULL, operation_key TEXT NOT NULL, request_hash TEXT NOT NULL,
                status TEXT NOT NULL CHECK(status IN ('dispatching','ready','rejected','uncertain')),
                match_id TEXT, upstream_status INTEGER, created_at TEXT NOT NULL,
                PRIMARY KEY(owner_id,operation_key))""")
            db.execute("CREATE TABLE IF NOT EXISTS anonymous_matches(match_id TEXT PRIMARY KEY)")
            # Keep the original owner's row and counter canonical. The match_id
            # primary key allows exactly one additional immutable participant.
            db.execute("""CREATE TABLE IF NOT EXISTS owned_participants(
                match_id TEXT PRIMARY KEY, account_id TEXT NOT NULL, player_id TEXT NOT NULL,
                highest_submitted_sequence INTEGER NOT NULL DEFAULT 0 CHECK(highest_submitted_sequence>=0),
                invitation_id TEXT NOT NULL UNIQUE, joined_at TEXT NOT NULL)""")
            db.execute("CREATE INDEX IF NOT EXISTS owned_participants_account ON owned_participants(account_id,match_id)")
            db.execute("""CREATE TABLE IF NOT EXISTS owned_invitations(
                invitation_id TEXT PRIMARY KEY, match_id TEXT NOT NULL, owner_id TEXT NOT NULL,
                recipient_id TEXT NOT NULL,
                status TEXT NOT NULL CHECK(status IN ('pending','accepted','revoked','expired','match_closed')),
                created_at TEXT NOT NULL, expires_at TEXT NOT NULL)""")
            db.execute("CREATE UNIQUE INDEX IF NOT EXISTS owned_invitation_pending ON owned_invitations(match_id) WHERE status='pending'")
            db.execute("""CREATE TABLE IF NOT EXISTS owned_admission_attempts(
                actor_id TEXT NOT NULL, operation_key TEXT NOT NULL,
                operation TEXT NOT NULL CHECK(operation IN ('invite','accept','revoke')),
                request_hash TEXT NOT NULL, match_id TEXT NOT NULL, invitation_id TEXT,
                status TEXT NOT NULL CHECK(status IN ('dispatching','ready','rejected')),
                error TEXT, error_status INTEGER, created_at TEXT NOT NULL,
                PRIMARY KEY(actor_id,operation_key))""")
            # Empty ACL tables remain rollback-compatible with the old guard.
            # The first protected reservation raises this to 2 atomically; a
            # subsequent ACL-aware start or disabled-creation rollback never lowers it.
            if db.execute("PRAGMA user_version").fetchone()[0] == 0:
                db.execute(f"PRAGMA user_version={VERSION}")
            if (db.execute("PRAGMA user_version").fetchone()[0] == VERSION and
                    (db.execute("SELECT 1 FROM owned_matches LIMIT 1").fetchone() is not None or
                     db.execute("SELECT 1 FROM owned_creation_attempts LIMIT 1").fetchone() is not None)):
                raise ValueError("Protected ownership data require REMIX storage schema 2.")
            if db.execute("PRAGMA user_version").fetchone()[0] < PARTICIPANT_SCHEMA_VERSION:
                if any(db.execute(f"SELECT 1 FROM {table} LIMIT 1").fetchone() is not None for table in
                       ("owned_participants", "owned_invitations", "owned_admission_attempts")):
                    raise ValueError("Participant admission data require REMIX storage schema 3.")
            db.commit()
        os.chmod(self.path, 0o600)

    @contextmanager
    def connect(self):
        # Existing requests use this same fixed path; no client value becomes a filename.
        remaining = min(2, getattr(self.request_context, "deadline", time.monotonic() + 2) - time.monotonic())
        if remaining <= 0:
            raise GuardError("storage_timeout", "The storage deadline expired. No further request was forwarded.")
        with closing(sqlite3.connect(self.path, timeout=remaining, isolation_level=None)) as db:
            db.row_factory = sqlite3.Row
            db.execute("PRAGMA synchronous=FULL")
            db.execute(f"PRAGMA busy_timeout={max(1, int(remaining * 1000))}")
            try:
                yield db
            finally:
                if db.in_transaction:
                    db.rollback()

    def probe(self):
        # A real committed write detects a full/read-only volume before an input
        # is forwarded. Merely opening a SELECT connection would not establish this.
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            db.execute("UPDATE guard_health SET sequence=(sequence+1)%1000000 WHERE id=1")
            require(db.execute("SELECT changes()").fetchone()[0] == 1, "Guard metadata is missing.")
            db.commit()

    def schema_version(self):
        with self.connect() as db:
            return db.execute("PRAGMA user_version").fetchone()[0]

    def owner(self, match_id):
        with self.connect() as db:
            row = db.execute("SELECT * FROM owned_matches WHERE match_id=?", (match_id,)).fetchone()
            if row is None:
                # Remaining protected references cannot turn a lost owner row
                # into an anonymously readable terminal snapshot.
                require(db.execute("""SELECT 1 FROM owned_participants WHERE match_id=?
                    UNION ALL SELECT 1 FROM owned_invitations WHERE match_id=?
                    UNION ALL SELECT 1 FROM owned_creation_attempts WHERE match_id=? AND status='ready' LIMIT 1""",
                                   (match_id, match_id, match_id)).fetchone() is None,
                        "The protected match ownership record is missing.")
                return None
            value = dict(row)
            require(isinstance(value["owner_id"], str) and re.fullmatch(ID, value["owner_id"])
                    and isinstance(value["player_id"], str) and re.fullmatch(ID, value["player_id"])
                    and natural(value["highest_submitted_sequence"]), "Invalid stored ownership record.")
            return value

    def register_anonymous(self, match_id):
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            require(db.execute("SELECT 1 FROM owned_matches WHERE match_id=?", (match_id,)).fetchone() is None,
                    "An owned match cannot become anonymous.")
            db.execute("INSERT OR IGNORE INTO anonymous_matches VALUES(?)", (match_id,))
            db.commit()

    def second_participant(self, owned):
        require(isinstance(owned, dict), "The protected ownership record is missing.")
        with self.connect() as db:
            row = db.execute("SELECT * FROM owned_participants WHERE match_id=?", (owned["match_id"],)).fetchone()
            if row is None:
                require(db.execute("SELECT 1 FROM owned_invitations WHERE match_id=? AND status='accepted' LIMIT 1",
                                   (owned["match_id"],)).fetchone() is None,
                        "The accepted participant record is missing.")
                return None
        value = dict(row)
        require(isinstance(value["account_id"], str) and re.fullmatch(ID, value["account_id"])
                and value["account_id"] != owned["owner_id"]
                and isinstance(value["player_id"], str) and re.fullmatch(ID, value["player_id"])
                and value["player_id"] != owned["player_id"] and natural(value["highest_submitted_sequence"]),
                "Invalid stored participant record.")
        invite = self.invitation(value["invitation_id"])
        require(invite is not None and invite["match_id"] == owned["match_id"]
                and invite["owner_id"] == owned["owner_id"] and invite["recipient_id"] == value["account_id"]
                and invite["status"] == "accepted", "The participant admission record is inconsistent.")
        return value

    def member(self, owned, actor):
        second = self.second_participant(owned)
        if actor == owned["owner_id"]:
            return {"account_id": actor, "player_id": owned["player_id"],
                    "highest_submitted_sequence": owned["highest_submitted_sequence"], "role": "owner"}
        if second is not None and actor == second["account_id"]:
            return dict(second, role="participant")
        return None

    def metadata(self, owned, actor=None):
        value = decode_json(owned["match_json"])
        require(isinstance(value, dict) and value.get("id") == owned["match_id"], "Invalid stored match metadata.")
        member = self.member(owned, actor or owned["owner_id"])
        require(member is not None, "The account is not a stored participant.")
        return dict(value, playerId=member["player_id"], highestSubmittedSequence=member["highest_submitted_sequence"],
                    accessMode="core-owned", role=member["role"],
                    participantCount=1 + int(self.second_participant(owned) is not None), maxParticipants=2)

    def list_owned(self, owner_id, after=""):
        with self.connect() as db:
            ids = [row[0] for row in db.execute("""SELECT match_id FROM owned_matches WHERE owner_id=? AND match_id>?
                UNION SELECT match_id FROM owned_participants WHERE account_id=? AND match_id>?
                ORDER BY match_id LIMIT 51""", (owner_id, after, owner_id, after))]
        return {"matches": [self.metadata(self.owner(identifier), owner_id) for identifier in ids[:50]],
                "nextCursor": ids[49] if len(ids) > 50 else None}

    def attempt(self, owner_id, key):
        with self.connect() as db:
            row = db.execute("SELECT * FROM owned_creation_attempts WHERE owner_id=? AND operation_key=?", (owner_id, key)).fetchone()
            return dict(row) if row is not None else None

    def reserve_creation(self, owner_id, key, request_hash):
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            require(db.execute("SELECT COUNT(*) FROM owned_creation_attempts WHERE owner_id=?", (owner_id,)).fetchone()[0] < 1000,
                    "The account creation-history limit has been reached.")
            self.raise_schema(db, OWNED_SCHEMA_VERSION)
            db.execute("INSERT INTO owned_creation_attempts VALUES(?,?,?,'dispatching',NULL,NULL,?)",
                       (owner_id, key, request_hash, datetime.now(timezone.utc).isoformat()))
            db.commit()

    def finish_creation(self, owner_id, key, status, upstream_status=None):
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            db.execute("UPDATE owned_creation_attempts SET status=?,upstream_status=? WHERE owner_id=? AND operation_key=? AND status='dispatching'",
                       (status, upstream_status, owner_id, key))
            db.commit()

    def bind_creation(self, owner_id, key, match, player_id):
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            require(db.execute("SELECT 1 FROM owned_creation_attempts WHERE owner_id=? AND operation_key=? AND status='dispatching'", (owner_id, key)).fetchone() is not None,
                    "The protected creation reservation is missing.")
            identifier = match["id"]
            require(db.execute("SELECT 1 FROM anonymous_matches WHERE match_id=? UNION ALL SELECT 1 FROM terminal_matches WHERE match_id=? LIMIT 1", (identifier, identifier)).fetchone() is None,
                    "An existing anonymous match cannot be claimed.")
            db.execute("INSERT INTO owned_matches VALUES(?,?,?,?,0)", (identifier, owner_id, player_id, canonical(match)))
            db.execute("UPDATE owned_creation_attempts SET status='ready',match_id=?,upstream_status=201 WHERE owner_id=? AND operation_key=?", (identifier, owner_id, key))
            db.commit()

    def submit_sequence(self, match_id, owner_id, sequence):
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT owner_id,highest_submitted_sequence FROM owned_matches WHERE match_id=?", (match_id,)).fetchone()
            require(row is not None, "The protected ownership record changed.")
            table, identity = "owned_matches", "owner_id"
            if row["owner_id"] != owner_id:
                table, identity = "owned_participants", "account_id"
                row = db.execute("SELECT account_id,highest_submitted_sequence FROM owned_participants WHERE match_id=? AND account_id=?",
                                 (match_id, owner_id)).fetchone()
                require(row is not None, "The protected participant record changed.")
            if sequence <= row["highest_submitted_sequence"]:
                raise GuardError("stale_input_sequence", "Use a sequence above the highest submitted sequence.", 409)
            db.execute(f"UPDATE {table} SET highest_submitted_sequence=? WHERE match_id=? AND {identity}=?", (sequence, match_id, owner_id))
            db.commit()

    @staticmethod
    def raise_schema(db, minimum):
        version = db.execute("PRAGMA user_version").fetchone()[0]
        require(version in (VERSION, OWNED_SCHEMA_VERSION, PARTICIPANT_SCHEMA_VERSION), "Unsupported storage version.")
        if version < minimum:
            db.execute(f"PRAGMA user_version={minimum}")

    def invitation(self, identifier):
        with self.connect() as db:
            row = db.execute("SELECT * FROM owned_invitations WHERE invitation_id=?", (identifier,)).fetchone()
        if row is None:
            return None
        value = dict(row)
        require(isinstance(value["invitation_id"], str) and re.fullmatch(r"inv_[0-9a-f]{32}", value["invitation_id"]) is not None
                and all(isinstance(value[key], str) and re.fullmatch(ID, value[key]) for key in ("match_id", "owner_id", "recipient_id"))
                and value["owner_id"] != value["recipient_id"]
                and value["status"] in ("pending", "accepted", "revoked", "expired", "match_closed"),
                "Invalid stored invitation.")
        try:
            created, expires = (datetime.fromisoformat(value[key]) for key in ("created_at", "expires_at"))
            require(created.utcoffset() == timedelta(0) and expires.utcoffset() == timedelta(0)
                    and expires > created, "Invalid invitation expiry.")
        except (TypeError, ValueError) as error:
            raise GuardError("upstream_contract", "Invalid stored invitation time.") from error
        return value

    def admission_attempt(self, actor, key):
        with self.connect() as db:
            row = db.execute("SELECT * FROM owned_admission_attempts WHERE actor_id=? AND operation_key=?", (actor, key)).fetchone()
        if row is None:
            return None
        value = dict(row)
        require(value["actor_id"] == actor and value["operation_key"] == key
                and isinstance(value["match_id"], str) and re.fullmatch(ID, value["match_id"])
                and isinstance(value["request_hash"], str) and re.fullmatch(r"[0-9a-f]{64}", value["request_hash"])
                and value["operation"] in ("invite", "accept", "revoke")
                and value["status"] in ("dispatching", "ready", "rejected")
                and (value["invitation_id"] is None or isinstance(value["invitation_id"], str)
                     and re.fullmatch(r"inv_[0-9a-f]{32}", value["invitation_id"])),
                "Invalid stored admission attempt.")
        return value

    def reserve_admission(self, actor, key, operation, request_hash, match_id, invitation_id):
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            require(db.execute("SELECT COUNT(*) FROM owned_admission_attempts WHERE actor_id=?", (actor,)).fetchone()[0] < 1000,
                    "The account admission-history limit has been reached.")
            self.raise_schema(db, PARTICIPANT_SCHEMA_VERSION)
            db.execute("INSERT INTO owned_admission_attempts VALUES(?,?,?,?,?,?,'dispatching',NULL,NULL,?)",
                       (actor, key, operation, request_hash, match_id, invitation_id, datetime.now(timezone.utc).isoformat()))
            db.commit()

    def reject_admission(self, actor, key, error, status, invitation_id=None):
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            db.execute("""UPDATE owned_admission_attempts SET status='rejected',error=?,error_status=?,
                invitation_id=COALESCE(?,invitation_id) WHERE actor_id=? AND operation_key=? AND status='dispatching'""",
                       (error, status, invitation_id, actor, key))
            db.commit()

    def expire_invitation(self, identifier, closed=False):
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            if closed:
                db.execute("UPDATE owned_invitations SET status='match_closed' WHERE invitation_id=? AND status='pending'", (identifier,))
            else:
                db.execute("UPDATE owned_invitations SET status='expired' WHERE invitation_id=? AND status='pending' AND expires_at<=?",
                           (identifier, datetime.now(timezone.utc).isoformat()))
            db.commit()

    def pending_invitation(self, match_id):
        with self.connect() as db:
            row = db.execute("SELECT invitation_id FROM owned_invitations WHERE match_id=? AND status='pending'", (match_id,)).fetchone()
        return self.invitation(row[0]) if row is not None else None

    def complete_admission(self, actor, key, operation, owned, invite=None, recipient=None):
        """Local effect and ready marker commit together; there is no engine POST."""
        now = datetime.now(timezone.utc)
        match_id = owned["match_id"]
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            attempt = db.execute("SELECT * FROM owned_admission_attempts WHERE actor_id=? AND operation_key=?", (actor, key)).fetchone()
            require(attempt is not None and attempt["status"] == "dispatching" and attempt["operation"] == operation
                    and attempt["match_id"] == match_id, "The admission reservation changed.")
            if operation in ("invite", "accept"):
                if db.execute("SELECT 1 FROM terminal_matches WHERE match_id=?", (match_id,)).fetchone() is not None:
                    raise GuardError("match_closed", "This match is already terminal; admission is closed.", 409)
                if db.execute("SELECT 1 FROM owned_participants WHERE match_id=?", (match_id,)).fetchone() is not None:
                    raise GuardError("match_full", "The immutable second participant slot is already occupied.", 409)
            if operation == "invite":
                require(actor == owned["owner_id"] and recipient != actor, "Invalid invitation owner or recipient.")
                db.execute("UPDATE owned_invitations SET status='expired' WHERE match_id=? AND status='pending' AND expires_at<=?", (match_id, now.isoformat()))
                if db.execute("SELECT 1 FROM owned_invitations WHERE match_id=? AND status='pending'", (match_id,)).fetchone() is not None:
                    raise GuardError("invitation_pending", "This match already has an outstanding invitation.", 409)
                identifier = "inv_" + secrets.token_hex(16)
                db.execute("INSERT INTO owned_invitations VALUES(?,?,?,?,'pending',?,?)",
                           (identifier, match_id, actor, recipient, now.isoformat(), (now + timedelta(seconds=INVITATION_TTL_SECONDS)).isoformat()))
            else:
                identifier = invite["invitation_id"]
                current = db.execute("SELECT * FROM owned_invitations WHERE invitation_id=?", (identifier,)).fetchone()
                require(current is not None and current["match_id"] == match_id and current["owner_id"] == owned["owner_id"],
                        "The addressed invitation changed.")
                if operation == "revoke" and current["status"] == "revoked":
                    pass  # A new explicit revoke has no additional effect.
                elif current["status"] != "pending":
                    raise GuardError("invitation_" + current["status"], "This invitation cannot admit or change a participant.", 409)
                elif current["expires_at"] <= now.isoformat():
                    raise GuardError("invitation_expired", "This invitation has expired.", 409)
                elif operation == "accept":
                    require(actor == current["recipient_id"], "The verified account is not the addressed recipient.")
                    player = "corep_" + secrets.token_hex(16)
                    require(player != owned["player_id"], "Assigned player identifiers must differ.")
                    db.execute("INSERT INTO owned_participants VALUES(?,?,?,0,?,?)", (match_id, actor, player, identifier, now.isoformat()))
                    db.execute("UPDATE owned_invitations SET status='accepted' WHERE invitation_id=?", (identifier,))
                else:
                    require(actor == owned["owner_id"], "Only the owner may revoke a pending invitation.")
                    db.execute("UPDATE owned_invitations SET status='revoked' WHERE invitation_id=?", (identifier,))
            db.execute("""UPDATE owned_admission_attempts SET status='ready',invitation_id=?,error=NULL,error_status=NULL
                WHERE actor_id=? AND operation_key=? AND status='dispatching'""", (identifier, actor, key))
            require(db.execute("SELECT changes()").fetchone()[0] == 1, "The admission outcome was not committed.")
            db.commit()

    def _decode(self, row):
        if row is None:
            return None
        state = validate_state(decode_json(row["state_json"]), row["match_id"]) if row["state_json"] is not None else None
        require(state is None or state["phase"] == "RESULTS", "Stored terminal marker has an invalid phase.")
        result = validate_result(decode_json(row["result_json"]), row["match_id"], state) if row["result_json"] is not None else None
        return {"state": state, "result": result}

    def load(self, match_id):
        with self.connect() as db:
            return self._decode(db.execute("SELECT * FROM terminal_matches WHERE match_id=?", (match_id,)).fetchone())

    def mark_terminal(self, match_id, state=None):
        if state is not None:
            validate_state(state, match_id)
            require(state["phase"] == "RESULTS", "Cannot mark a running match terminal.")
        encoded = canonical(state) if state is not None else None
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            db.execute("INSERT OR IGNORE INTO terminal_matches(match_id,state_json,observed_at) VALUES(?,?,?)",
                       (match_id, encoded, datetime.now(timezone.utc).isoformat()))
            # A minimal terminal marker may precede a valid state. Once a valid
            # terminal state is recorded, it is never replaced by an upstream revision.
            if encoded is not None:
                db.execute("UPDATE terminal_matches SET state_json=? WHERE match_id=? AND state_json IS NULL", (encoded, match_id))
            row = db.execute("SELECT * FROM terminal_matches WHERE match_id=?", (match_id,)).fetchone()
            value = self._decode(row)
            db.commit()
            return value

    def finalize(self, match_id, state, result):
        validate_state(state, match_id)
        require(state["phase"] == "RESULTS", "Cannot freeze a running match.")
        validate_result(result, match_id, state)
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT * FROM terminal_matches WHERE match_id=?", (match_id,)).fetchone()
            require(row is not None, "Terminal marker must be committed before finalization.")
            existing = self._decode(row)
            if existing["result"] is not None:
                db.commit()
                return existing
            require(existing["state"] is None or canonical(existing["state"]) == canonical(state),
                    "The first observed terminal state cannot be replaced.")
            db.execute("UPDATE terminal_matches SET state_json=?,result_json=?,finalized_at=? WHERE match_id=?",
                       (canonical(state), canonical(result), datetime.now(timezone.utc).isoformat(), match_id))
            db.commit()
        return {"state": state, "result": result}


@dataclass(frozen=True)
class Reply:
    status: int
    headers: tuple
    body: bytes

    @classmethod
    def json(cls, status, value):
        return cls(status, (("Content-Type", "application/json; charset=utf-8"),), canonical(value).encode())

    def object(self):
        content_type = next((value for name, value in self.headers if name.lower() == "content-type"), "")
        require(content_type.split(";", 1)[0].strip().lower() == "application/json", "The match service did not return JSON.")
        return decode_json(self.body)


class Upstream:
    def __init__(self, base, timeout=3, trusted_host=None):
        parsed = urlsplit(base)
        if (parsed.scheme not in ("http", "https") or not parsed.hostname or parsed.username is not None
                or parsed.password is not None or parsed.path not in ("", "/") or parsed.query or parsed.fragment):
            raise ValueError("The upstream must be one fixed HTTP(S) origin without credentials or a path.")
        self.host, self.port, self.scheme = parsed.hostname, parsed.port, parsed.scheme
        self.timeout = timeout
        if trusted_host is not None and not re.fullmatch(r"[A-Za-z0-9.-]+(?::[0-9]{1,5})?", trusted_host):
            raise ValueError("The trusted Core Host must be a fixed hostname with an optional port.")
        self.trusted_host = trusted_host

    def request(self, method, target, body, headers, deadline):
        now = time.monotonic()
        request_deadline = min(deadline, now + self.timeout)
        remaining = request_deadline - now
        if remaining <= 0:
            raise GuardError("upstream_timeout", "The match service deadline expired.")
        connection_class = http.client.HTTPSConnection if self.scheme == "https" else http.client.HTTPConnection
        connection = connection_class(self.host, self.port, timeout=min(self.timeout, remaining))
        forwarded = {name: value for name, value in headers.items() if name.lower() not in HOP_HEADERS | {"accept-encoding"}}
        forwarded["Accept-Encoding"] = "identity"
        forwarded["Connection"] = "close"
        if self.trusted_host is not None:
            forwarded["Host"] = self.trusted_host
        # A fresh direct connection does not consult HTTP_PROXY, follow redirects,
        # or retry a POST. Its host can never be selected through a request target.
        response = None
        channel = None
        expired = threading.Event()

        def interrupt():
            # Socket inactivity timeouts alone do not bound a slow stream of
            # response headers. shutdown also interrupts the HTTPResponse file
            # reader after HTTPConnection releases a Connection: close socket.
            expired.set()
            active = channel if channel is not None else connection.sock
            if active is not None:
                try:
                    active.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass

        expiry = threading.Timer(remaining, interrupt)
        expiry.daemon = True
        expiry.start()
        try:
            # Resolution happens only for the configured fixed origin. The
            # system resolver itself is not cancellable by socket shutdown;
            # if it returns late, no POST may first be sent after expiry.
            connection.connect()
            channel = connection.sock
            if expired.is_set() or time.monotonic() >= request_deadline:
                raise TimeoutError("deadline")
            connection.request(method, target, body=body, headers=forwarded)
            if time.monotonic() >= request_deadline:
                raise TimeoutError("deadline")
            response = connection.getresponse()
            if time.monotonic() >= request_deadline:
                raise TimeoutError("deadline")
            chunks, length = [], 0
            while not response.isclosed() and response.length != 0:
                remaining = request_deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError("deadline")
                if channel is not None:
                    channel.settimeout(min(self.timeout, remaining))
                chunk = response.read1(min(65536, MAX_RESPONSE + 1 - length))
                if not chunk:
                    break
                chunks.append(chunk)
                length += len(chunk)
                if length > MAX_RESPONSE:
                    raise GuardError("upstream_response_limit", "The match service response is too large.")
            # Watchdog shutdown can look like ordinary EOF for an HTTP response
            # without Content-Length. Never treat that truncated body as success.
            if expired.is_set() or time.monotonic() >= request_deadline:
                raise TimeoutError("deadline")
            if response.length not in (None, 0):
                raise http.client.IncompleteRead(b"")
            return Reply(response.status, tuple(response.getheaders()), b"".join(chunks))
        except (OSError, http.client.HTTPException, TimeoutError) as error:
            code = "upstream_write_uncertain" if method not in ("GET", "HEAD", "OPTIONS") else "upstream_unavailable"
            message = ("The service did not confirm this write. It was not retried." if code == "upstream_write_uncertain"
                       else "The match service is unavailable. Retry this read later.")
            raise GuardError(code, message) from error
        finally:
            expiry.cancel()
            # A worker cannot start its next upstream call until its watchdog
            # has exited. 32 workers + 32 timers fit the container's 96 PID cap.
            expiry.join()
            if response is not None:
                response.close()
            connection.close()


class CoreVerifier:
    def __init__(self, base="http://core-api:4173", trusted_host="osgard.world", timeout=3):
        self.upstream = Upstream(base, timeout, trusted_host)

    def actor(self, headers, deadline):
        authorization = field_header(headers, "Authorization")
        if not isinstance(authorization, str) or not re.fullmatch(r"Bearer [A-Za-z0-9_-]{40,100}", authorization):
            raise GuardError("authentication_required", "Sign in to your Core account for this match.", 401)
        try:
            reply = self.upstream.request("GET", "/api/core/auth/me", None,
                                          {"Authorization": authorization, "Accept": "application/json"}, deadline)
            if reply.status == 401:
                raise GuardError("authentication_required", "Your Core session expired or was revoked. Sign in again.", 401)
            require(reply.status == 200, "Core authentication is unavailable.")
            value = reply.object()
            require(isinstance(value, dict) and set(value) == {"user"} and isinstance(value["user"], dict),
                    "Invalid Core identity response.")
            user = value["user"]
            require(set(user) == {"id", "username"} and isinstance(user["id"], str)
                    and re.fullmatch(ID, user["id"]) and isinstance(user["username"], str)
                    and re.fullmatch(r"[a-z0-9_.-]{3,64}", user["username"]), "Invalid Core identity response.")
            return user["id"]
        except GuardError as error:
            if error.status == 401:
                raise
            raise GuardError("authentication_unavailable", "Core could not verify this session. No protected input was forwarded.") from error


class Guard:
    def __init__(self, database, upstream="http://remix-api:8080", timeout=3, budget=10,
                 core_upstream="http://core-api:4173", core_host="osgard.world", enable_owned_creation=False,
                 enable_participant_admission=False):
        self.store = SnapshotStore(database)
        self.upstream = Upstream(upstream, timeout)
        self.core = CoreVerifier(core_upstream, core_host, timeout)
        self.enable_owned_creation = bool(enable_owned_creation)
        self.enable_participant_admission = bool(enable_participant_admission)
        self.files = VolumeLocks(self.store.path.parent)
        self.budget = budget
        self.locks = [threading.Lock() for _ in range(256)]

    def lock(self, match_id):
        return self.locks[hashlib.sha256(match_id.encode()).digest()[0]]

    @contextmanager
    def match_lease(self, match_id, deadline):
        lock = self.lock(match_id)
        if not lock.acquire(timeout=min(2, max(0, deadline - time.monotonic()))):
            raise GuardError("match_busy", "This match has a request in progress. Retry the read later.")
        try:
            with self.files.match(match_id, deadline):
                yield
        finally:
            lock.release()

    def _protected_roster(self, value, owned):
        if owned is None:
            return
        allowed = {owned["player_id"]}
        second = self.store.second_participant(owned)
        if second is not None:
            allowed.add(second["player_id"])
        require(all(row["playerId"] in allowed for row in value["scores"]),
                "The service returned a player outside this match's durable participant roster.")

    def _request(self, method, target, body, headers, deadline):
        # Legacy never receives a Core bearer, browser cookie or claimed identity header.
        safe = {name: value for name, value in headers.items()
                if name.lower() not in {"authorization", "cookie", "proxy-authorization", "x-user", "x-user-id"}}
        return self.upstream.request(method, target, body, safe, deadline)

    def _state(self, match_id, headers, deadline, owned=None):
        reply = self._request("GET", f"/v1/matches/{match_id}/state", None, headers, deadline)
        if reply.status != 200:
            return reply, None
        # An identity-bound terminal observation blocks future inputs even if
        # other state fields or the subsequent result response are malformed.
        if terminal_identity(reply.body, "id", match_id):
            self.store.mark_terminal(match_id)
        value = reply.object()
        state = validate_state(value, match_id)
        self._protected_roster(state, owned)
        if state["phase"] == "RESULTS":
            self.store.mark_terminal(match_id, state)
        return reply, state

    def _frozen(self, match_id, saved, headers, deadline, owned=None):
        if saved["result"] is not None:
            self._protected_roster(saved["state"], owned)
            self._protected_roster(saved["result"], owned)
            return saved
        state = saved["state"]
        if state is None:
            reply, state = self._state(match_id, headers, deadline, owned)
            if reply.status != 200 or state is None or state["phase"] != "RESULTS":
                raise GuardError("terminal_result_pending", "This match is terminal; its result is not safely available yet.")
        reply = self._request("GET", f"/v1/matches/{match_id}/result", None, headers, deadline)
        if reply.status != 200:
            raise GuardError("terminal_result_pending", "This match is terminal; retry fetching its result later.")
        result = validate_result(reply.object(), match_id, state)
        self._protected_roster(state, owned)
        self._protected_roster(result, owned)
        return self.store.finalize(match_id, state, result)

    def capabilities(self):
        return {"authPolicyVersion": AUTH_POLICY_VERSION, "creationEnabled": self.enable_owned_creation,
                "provider": "core", "ownershipPolicy": "confirmed-durable-binding",
                "legacyMatches": "anonymous", "activeMatchRecovery": False, "replayVerification": False,
                "participantPolicyVersion": PARTICIPANT_POLICY_VERSION,
                "participantAdmissionEnabled": self.enable_participant_admission, "maxParticipants": 2}

    def _invitation_dto(self, invitation, actor):
        require(isinstance(invitation, dict), "The addressed invitation record is missing.")
        if actor not in (invitation["owner_id"], invitation["recipient_id"]):
            raise GuardError("invitation_forbidden", "This invitation is addressed to another account.", 403)
        owned = self.store.owner(invitation["match_id"])
        require(owned is not None and owned["owner_id"] == invitation["owner_id"], "The invitation's owner binding is invalid.")
        metadata = self.store.metadata(owned)
        return {"id": invitation["invitation_id"], "matchId": invitation["match_id"],
                "challengeId": metadata["challengeId"], "recipientAccountId": invitation["recipient_id"],
                "status": invitation["status"], "createdAt": invitation["created_at"], "expiresAt": invitation["expires_at"],
                "role": "owner" if actor == invitation["owner_id"] else "recipient"}

    def _admission_reply(self, actor, key, attempt, posted=False):
        require(isinstance(attempt, dict) and attempt["actor_id"] == actor and attempt["operation_key"] == key
                and attempt["operation"] in ("invite", "accept", "revoke")
                and attempt["status"] in ("dispatching", "ready", "rejected"), "Invalid stored admission attempt.")
        if attempt["status"] == "dispatching":
            # The caller holds the same cross-process match lease as the writer.
            # Unlike engine creation, admission has only an atomic local effect:
            # an abandoned dispatching record proves that no admission committed.
            self.store.reject_admission(actor, key, "admission_interrupted", 409)
            attempt = self.store.admission_attempt(actor, key)
        value = {"operation": attempt["operation"], "operationKey": key, "status": attempt["status"]}
        if attempt["status"] == "rejected":
            require(isinstance(attempt["error"], str) and re.fullmatch(r"[a-z_]{1,80}", attempt["error"])
                    and type(attempt["error_status"]) is int and 400 <= attempt["error_status"] < 500,
                    "Invalid stored admission rejection.")
            value.update(error=attempt["error"], message="This admission operation did not commit. No POST was repeated.")
            if attempt["invitation_id"]:
                value["invitationId"] = attempt["invitation_id"]
            return Reply.json(attempt["error_status"] if posted else 200, value)
        invitation = self.store.invitation(attempt["invitation_id"])
        require(invitation is not None and invitation["match_id"] == attempt["match_id"], "The committed invitation is missing.")
        value["invitation"] = self._invitation_dto(invitation, actor)
        if attempt["operation"] == "accept":
            owned = self.store.owner(attempt["match_id"])
            second = self.store.second_participant(owned)
            require(second is not None and second["account_id"] == actor
                    and second["invitation_id"] == invitation["invitation_id"], "The committed participant is missing.")
            value["match"] = self.store.metadata(owned, actor)
        return Reply.json((200 if attempt["operation"] == "revoke" else 201) if posted else 200, value)

    def _admission_engine(self, owned, deadline):
        identifier = owned["match_id"]
        if self.store.load(identifier) is not None:
            return {"phase": "RESULTS", "remainingMs": 0}, False
        reply, state = self._state(identifier, {}, deadline, owned)
        if state is None:
            raise GuardError("match_unavailable" if reply.status == 404 else "upstream_unavailable",
                             "The legacy engine cannot confirm a joinable match.", 404 if reply.status == 404 else 503)
        allowed = state["phase"] in ("COUNTDOWN", "PLAYING", "RUNNING") and state["remainingMs"] > 0
        return {"phase": state["phase"], "remainingMs": state["remainingMs"]}, allowed

    def _read_invitation(self, identifier, headers, deadline):
        with self.files.admission(False, deadline):
            actor = self.core.actor(headers, deadline)
            invitation = self.store.invitation(identifier)
            if invitation is None:
                raise GuardError("invitation_not_found", "This invitation is not available.", 404)
            with self.match_lease(invitation["match_id"], deadline):
                invitation = self.store.invitation(identifier)
                self._invitation_dto(invitation, actor)  # Permission precedes phase or scores.
                self.store.expire_invitation(identifier)
                owned = self.store.owner(invitation["match_id"])
                engine, playable = self._admission_engine(owned, deadline)
                if not playable and engine["phase"] == "RESULTS":
                    self.store.expire_invitation(identifier, closed=True)
                invitation = self.store.invitation(identifier)
                value = self._invitation_dto(invitation, actor)
                value.update(engine=engine, admissionAllowed=(self.enable_participant_admission and playable
                             and actor == invitation["recipient_id"] and invitation["status"] == "pending"
                             and self.store.second_participant(owned) is None))
                return Reply.json(200, value)

    def _admission_operation(self, operation, identifier, body, headers, deadline):
        value = request_object(body)
        if operation == "invite":
            if (set(value) != {"recipientAccountId"} or not isinstance(value["recipientAccountId"], str)
                    or not re.fullmatch(ID, value["recipientAccountId"])):
                raise GuardError("invalid_request", "Supply only the intended recipient's Core account ID.", 400)
        elif value:
            raise GuardError("invalid_request", "This operation requires an empty JSON object.", 400)
        key = field_header(headers, "Idempotency-Key")
        if not re.fullmatch(r"[A-Za-z0-9_-]{16,100}", key):
            raise GuardError("operation_key", "Provide a valid Idempotency-Key for this admission operation.", 400)
        digest = hashlib.sha256(canonical({"operation": operation, "id": identifier, "body": value}).encode()).hexdigest()
        with self.files.admission(False, deadline):
            actor = self.core.actor(headers, deadline)
            invitation = None if operation == "invite" else self.store.invitation(identifier)
            if operation != "invite" and invitation is None:
                raise GuardError("invitation_not_found", "This invitation is not available.", 404)
            match_id = identifier if operation == "invite" else invitation["match_id"]
            with self.match_lease(match_id, deadline):
                owned = self.store.owner(match_id)
                if owned is None:
                    raise GuardError("owned_match_not_found", "Only an existing Core-owned match can admit a participant.", 404)
                if operation != "invite":
                    invitation = self.store.invitation(identifier)
                    self._invitation_dto(invitation, actor)
                required_actor = invitation["recipient_id"] if operation == "accept" else owned["owner_id"]
                if actor != required_actor:
                    raise GuardError("invitation_forbidden", "This account cannot perform the requested invitation operation.", 403)
                previous = self.store.admission_attempt(actor, key)
                if previous is not None:
                    if previous["request_hash"] != digest or previous["operation"] != operation or previous["match_id"] != match_id:
                        raise GuardError("operation_conflict", "This operation key belongs to another admission request.", 409)
                    return self._admission_reply(actor, key, previous, True)
                if operation != "revoke" and not self.enable_participant_admission:
                    raise GuardError("participant_admission_disabled", "New participant admission is not enabled in this release.", 403)
                self.store.reserve_admission(actor, key, operation, digest, match_id,
                                             None if invitation is None else invitation["invitation_id"])
                try:
                    if operation == "invite" and value["recipientAccountId"] == actor:
                        raise GuardError("recipient_is_owner", "The owner already has the first participant slot.", 400)
                    if invitation is not None:
                        self.store.expire_invitation(identifier)
                        invitation = self.store.invitation(identifier)
                    if operation in ("invite", "accept"):
                        engine, allowed = self._admission_engine(owned, deadline)
                        if not allowed:
                            if invitation is not None and engine["phase"] == "RESULTS":
                                self.store.expire_invitation(identifier, closed=True)
                            raise GuardError("match_closed", "The observed match phase cannot admit a new participant. The engine timer was not extended.", 409)
                    self.store.complete_admission(actor, key, operation, owned, invitation, value.get("recipientAccountId"))
                except GuardError as error:
                    if error.status < 500:
                        pending = self.store.pending_invitation(match_id) if error.code == "invitation_pending" else None
                        self.store.reject_admission(actor, key, error.code, error.status,
                                                    pending["invitation_id"] if pending else None)
                        return self._admission_reply(actor, key, self.store.admission_attempt(actor, key), True)
                    raise
                return self._admission_reply(actor, key, self.store.admission_attempt(actor, key), True)

    def _attempt_reply(self, owner_id, key, attempt, creation=False):
        if attempt["status"] == "ready":
            owned = self.store.owner(attempt["match_id"])
            require(owned is not None and owned["owner_id"] == owner_id, "Stored creation ownership is invalid.")
            value = self.store.metadata(owned)
            return Reply.json(201, value) if creation else Reply.json(200, {"status": "ready", "match": value})
        if attempt["status"] == "dispatching":
            # Every caller holds admission SH/EX, so a live creator cannot still
            # be dispatching under its exclusive lease. Commit crash recovery as
            # uncertain; no missing upstream ID can be adopted from this intent.
            self.store.finish_creation(owner_id, key, "uncertain")
        status = "uncertain" if attempt["status"] in ("dispatching", "uncertain") else "rejected"
        value = {"status": status, "operationKey": key}
        if creation:
            value.update(error="creation_" + status,
                         message="This creation was not retried. Check the existing attempt before starting another match.")
        return Reply.json(409 if creation else 200, value)

    def _owned_create(self, body, headers, deadline):
        if not self.enable_owned_creation:
            raise GuardError("owned_creation_disabled", "Account-owned creation is not enabled in this release.", 403)
        actor = self.core.actor(headers, deadline)
        value = request_object(body)
        if (set(value) != {"challengeId", "maxPlayers"} or not isinstance(value["challengeId"], str)
                or not re.fullmatch(ID, value["challengeId"]) or type(value["maxPlayers"]) is not int or value["maxPlayers"] != 2):
            raise GuardError("invalid_request", "Owned creation requires challengeId and maxPlayers: 2 only.", 400)
        key = field_header(headers, "Idempotency-Key")
        if not re.fullmatch(r"[A-Za-z0-9_-]{16,100}", key):
            raise GuardError("operation_key", "Provide an Idempotency-Key with 16 to 100 letters, digits, underscores or hyphens.", 400)
        encoded = canonical(value).encode()
        request_hash = hashlib.sha256(encoded).hexdigest()
        with self.files.admission(True, deadline):
            previous = self.store.attempt(actor, key)
            if previous is not None:
                if previous["request_hash"] != request_hash:
                    raise GuardError("operation_conflict", "This operation key belongs to a different creation request.", 409)
                return self._attempt_reply(actor, key, previous, True)
            self.store.reserve_creation(actor, key, request_hash)
            try:
                # Nothing linking this request to an account or player is sent
                # upstream before the confirmed binding. A crash may leave an
                # empty, unlinked orphan; it is never adopted or retried.
                reply = self._request("POST", "/v1/matches", encoded, {"Content-Type": "application/json"}, deadline)
                if reply.status != 201:
                    rejected = 400 <= reply.status < 500
                    self.store.finish_creation(actor, key, "rejected" if rejected else "uncertain", reply.status)
                    return self._attempt_reply(actor, key, self.store.attempt(actor, key), True)
                match = reply.object()
                require(isinstance(match, dict) and set(match) == {"id", "challengeId", "maxPlayers", "createdAt"}
                        and isinstance(match["id"], str) and re.fullmatch(ID, match["id"])
                        and match["challengeId"] == value["challengeId"]
                        and type(match["maxPlayers"]) is int and match["maxPlayers"] == 2
                        and isinstance(match["createdAt"], str) and 1 <= len(match["createdAt"]) <= 100,
                        "The service did not confirm the requested new match.")
                state_reply = self._request("GET", f"/v1/matches/{match['id']}/state", None, {}, deadline)
                require(state_reply.status == 200, "The new match state is unavailable.")
                state = validate_state(state_reply.object(), match["id"])
                require(state["players"] == 0 and state["replayFrames"] == 0 and state["scores"] == [],
                        "A nonempty or existing match cannot be registered as newly owned.")
                self.store.bind_creation(actor, key, match, "corep_" + secrets.token_hex(16))
                return Reply.json(201, self.store.metadata(self.store.owner(match["id"])))
            except (GuardError, sqlite3.Error, OSError) as error:
                try:
                    self.store.finish_creation(actor, key, "uncertain")
                except (GuardError, sqlite3.Error, OSError):
                    pass  # The durable dispatching intent also means uncertain after restart.
                raise GuardError("creation_uncertain", "The service did not confirm a durable owned match. This creation was not retried.") from error

    def _owned_input(self, body, owned):
        value = request_object(body)
        required = {"sequence", "moveX", "moveY", "jump"}
        if (not required <= set(value) or set(value) - required - {"playerId"}
                or not natural(value["sequence"]) or value["sequence"] == 0
                or not all(finite_number(value[key]) and abs(value[key]) <= 1 for key in ("moveX", "moveY"))
                or type(value["jump"]) is not bool):
            raise GuardError("invalid_input", "Provide a positive integer sequence, movement from -1 to 1 and a boolean jump.", 400)
        if "playerId" in value and value["playerId"] != owned["player_id"]:
            raise GuardError("player_forbidden", "This player does not belong to the authenticated match.", 403)
        value["playerId"] = owned["player_id"]
        return value

    def handle(self, method, target, body=b"", headers=None):
        headers = headers or {}
        deadline = time.monotonic() + self.budget
        self.store.request_context.deadline = deadline
        try:
            return self._handle(method, target, body, headers, deadline)
        except (sqlite3.Error, OSError) as error:
            return Reply.json(503, {"error": "storage_unavailable", "message": "Match result storage is unavailable. No input was forwarded without its storage check."})
        except GuardError as error:
            return Reply.json(error.status, {"error": error.code, "message": error.message})
        finally:
            del self.store.request_context.deadline

    def _handle(self, method, target, body, headers, deadline):
        parsed = urlsplit(target)
        path = parsed.path
        # Reject ambiguous encodings/segments rather than let an upstream router
        # normalize an unguarded spelling into the guarded input route.
        if (parsed.scheme or parsed.netloc or parsed.fragment or not path.startswith("/") or
                len(target) > 4096 or "%" in path or "\\" in path or "//" in path or
                any(part in (".", "..") for part in path.split("/")) or
                any(ord(char) < 32 or ord(char) > 126 for char in target)):
            raise GuardError("invalid_path", "Use a canonical API request path.", 400)
        path = path.rstrip("/") or "/"
        target = path + ("?" + parsed.query if parsed.query else "")
        if path == "/health" and method in ("GET", "HEAD"):
            self.store.probe()
            legacy = self._request("GET", "/health", None, headers, deadline)
            require(legacy.status == 200 and legacy.object().get("status") == "ok", "Legacy service health is not ready.")
            return Reply.json(200, {"status": "ok", "service": "osgard-remix-guard", "schemaVersion": self.store.schema_version(),
                                    "frozenResults": True, "storage": "ok", "upstream": "ok",
                                    "resultPolicy": "freeze-on-first-terminal-observation",
                                    "playerAuthentication": False, **self.capabilities()})
        if path == "/v2/capabilities" and method in ("GET", "HEAD"):
            return Reply.json(200, self.capabilities())
        if path == "/v2/matches":
            if method == "POST" and not parsed.query:
                return self._owned_create(body, headers, deadline)
            if method not in ("GET", "HEAD"):
                raise GuardError("method_not_allowed", "Use GET to list owned matches or POST to create one.", 405)
            try:
                query = parse_qs(parsed.query, keep_blank_values=True, strict_parsing=True, max_num_fields=2)
            except ValueError as error:
                raise GuardError("invalid_query", "Use only one optional after match identifier.", 400) from error
            if (set(query) - {"after"} or "after" in query and
                    (len(query["after"]) != 1 or not re.fullmatch(ID, query["after"][0]))):
                raise GuardError("invalid_query", "Use only one optional after match identifier.", 400)
            with self.files.admission(False, deadline):
                actor = self.core.actor(headers, deadline)
                return Reply.json(200, self.store.list_owned(actor, query.get("after", [""])[0]))
        attempt = ATTEMPT_ROUTE.fullmatch(path)
        if attempt is not None:
            if method not in ("GET", "HEAD"):
                raise GuardError("method_not_allowed", "Use GET to read an existing creation attempt.", 405)
            with self.files.admission(False, deadline):
                actor = self.core.actor(headers, deadline)
                saved = self.store.attempt(actor, attempt["key"])
                if saved is None:
                    raise GuardError("attempt_not_found", "This account has no such creation attempt.", 404)
                return self._attempt_reply(actor, attempt["key"], saved)
        admission = ADMISSION_ATTEMPT_ROUTE.fullmatch(path)
        if admission is not None:
            if method not in ("GET", "HEAD") or parsed.query:
                raise GuardError("method_not_allowed", "Use GET without a query to recover an admission attempt.", 405)
            with self.files.admission(False, deadline):
                actor = self.core.actor(headers, deadline)
                saved = self.store.admission_attempt(actor, admission["key"])
                if saved is None:
                    raise GuardError("attempt_not_found", "This account has no such admission attempt.", 404)
                require(isinstance(saved["match_id"], str) and re.fullmatch(ID, saved["match_id"]), "Invalid admission match identifier.")
                with self.match_lease(saved["match_id"], deadline):
                    saved = self.store.admission_attempt(actor, admission["key"])
                    return self._admission_reply(actor, admission["key"], saved)
        invite_create = INVITATION_CREATE_ROUTE.fullmatch(path)
        invite_route = INVITATION_ROUTE.fullmatch(path)
        if invite_create is not None or invite_route is not None:
            if parsed.query:
                raise GuardError("invalid_query", "Invitation operations do not accept query parameters.", 400)
            if invite_create is not None:
                if method != "POST":
                    raise GuardError("method_not_allowed", "Use POST to create an addressed invitation.", 405)
                return self._admission_operation("invite", invite_create["id"], body, headers, deadline)
            if invite_route["action"] is None:
                if method not in ("GET", "HEAD"):
                    raise GuardError("method_not_allowed", "Use GET to read an addressed invitation.", 405)
                return self._read_invitation(invite_route["id"], headers, deadline)
            if method != "POST":
                raise GuardError("method_not_allowed", "Use POST for an explicit invitation operation.", 405)
            return self._admission_operation(invite_route["action"], invite_route["id"], body, headers, deadline)
        owned_route = OWNED_MATCH_ROUTE.fullmatch(path)
        route = owned_route or MATCH_ROUTE.fullmatch(path)
        if route is None:
            if path.lower().startswith("/v2/") or path.lower().startswith("/v1/matches/"):
                raise GuardError("unknown_match_route", "This match route is not supported.", 404)
            if path.lower() == "/v1/matches":
                if path != "/v1/matches" or method != "POST":
                    raise GuardError("method_not_allowed", "Use POST to create a legacy match.", 405)
                with self.files.admission(False, deadline):
                    # Do not allow an unclassified client-supplied identity to
                    # reset a protected legacy object through the create route.
                    value = request_object(body)
                    if (set(value) != {"challengeId", "maxPlayers"}
                            or not isinstance(value["challengeId"], str) or not re.fullmatch(ID, value["challengeId"])
                            or not natural(value["maxPlayers"]) or value["maxPlayers"] == 0):
                        raise GuardError("invalid_request", "Legacy creation requires challengeId and maxPlayers only.", 400)
                    self.store.probe()
                    reply = self._request(method, target, body, headers, deadline)
                    if reply.status == 201:
                        match = reply.object()
                        require(isinstance(match, dict) and isinstance(match.get("id"), str) and re.fullmatch(ID, match["id"]),
                                "The service did not confirm a match identifier.")
                        self.store.register_anonymous(match["id"])
                    return reply
            return self._request(method, target, body, headers, deadline)
        if not ((method in ("GET", "HEAD") and route["action"] in (None, "state", "result")) or
                (method == "POST" and route["action"] == "input")):
            raise GuardError("method_not_allowed", "Use POST for input and GET or HEAD for state and result.", 405)
        match_id, action = route["id"], route["action"]
        # Classification must stay valid until forwarding/frozen reads finish.
        # The exclusive creation lease cannot release an ID before its owner
        # binding is durable, even when another guard process handles the alias.
        with self.files.admission(False, deadline):
            lock = self.lock(match_id)
            if not lock.acquire(timeout=min(2, max(0, deadline - time.monotonic()))):
                raise GuardError("match_busy", "This match has a request in progress. Retry the read later.")
            try:
                with self.files.match(match_id, deadline):
                    owned = self.store.owner(match_id)
                    member = None
                    if owned is not None or owned_route is not None:
                        actor = self.core.actor(headers, deadline)
                        if owned is None:
                            raise GuardError("owned_match_not_found", "This match is not registered as account-owned.", 404)
                        member = self.store.member(owned, actor)
                        if member is None:
                            raise GuardError("match_forbidden", "This match belongs to another account.", 403)
                    if action is None:
                        return Reply.json(200, self.store.metadata(owned, actor))
                    if owned is not None:
                        # Account credentials, cookies, referrers and operation
                        # keys are never part of a legacy match request.
                        headers = {"Content-Type": "application/json", "Accept": "application/json"}
                        if action == "input":
                            body = canonical(self._owned_input(body, member)).encode()
                    legacy_target = f"/v1/matches/{match_id}/{action}"
                    if owned is None and parsed.query:
                        legacy_target += "?" + parsed.query
                    return self._match_action(match_id, action, legacy_target, body, headers, deadline, owned, member)
            finally:
                lock.release()

    def _match_action(self, match_id, action, target, body, headers, deadline, owned, member=None):
        saved = self.store.load(match_id)
        if action == "input" and saved is not None:
            raise GuardError("match_finished", "This match has finished and cannot accept new input.", 409)
        if saved is not None:
            frozen = self._frozen(match_id, saved, headers, deadline, owned)
            return Reply.json(200, frozen[action])
        if action == "input":
            self.store.probe()
        state_reply, state = self._state(match_id, headers, deadline, owned)
        if state is None:
            return self._owned_error(state_reply, "state") if owned else state_reply
        if owned is None:
            self.store.register_anonymous(match_id)
        if state["phase"] == "RESULTS":
            if action == "input":
                raise GuardError("match_finished", "This match has finished and cannot accept new input.", 409)
            frozen = self._frozen(match_id, self.store.load(match_id), headers, deadline, owned)
            return Reply.json(200, frozen[action])
        if action == "state":
            return state_reply
        if action == "input":
            if state["phase"] not in ("PLAYING", "RUNNING") or state["remainingMs"] <= 0:
                raise GuardError("match_not_playing", "The service has not confirmed an active playing phase.", 409)
            if owned:
                value = request_object(body)
                # This is a submitted high-water mark, never an acceptance or
                # replay claim. An uncertain POST may have changed the engine.
                self.store.submit_sequence(match_id, member["account_id"], value["sequence"])
            reply = self._request("POST", target, body, headers, deadline)
            if owned:
                if reply.status != 200:
                    return self._owned_error(reply, action)
                ack = reply.object()
                require(isinstance(ack, dict) and set(ack) == {"playerId", "position", "velocityY", "onGround", "score", "lastSequence"}
                        and ack["playerId"] == member["player_id"] and natural(ack["lastSequence"])
                        and ack["lastSequence"] == value["sequence"] and type(ack["onGround"]) is bool
                        and isinstance(ack["position"], list) and len(ack["position"]) == 3
                        and all(finite_number(number) for number in ack["position"])
                        and finite_number(ack["velocityY"]) and finite_number(ack["score"]),
                        "The input acknowledgement did not match the submitted player and sequence; it was not retried.")
            return reply
        result_reply = self._request("GET", target, None, headers, deadline)
        if result_reply.status != 200:
            return self._owned_error(result_reply, action) if owned else result_reply
        # The phase may have changed during the two reads. Establish and
        # persist a matching terminal state before exposing the result.
        if terminal_identity(result_reply.body, "matchId", match_id):
            self.store.mark_terminal(match_id)
        result = result_reply.object()
        _, terminal = self._state(match_id, headers, deadline, owned)
        require(terminal is not None and terminal["phase"] == "RESULTS", "A result arrived before a matching terminal state.")
        validate_result(result, match_id, terminal)
        self._protected_roster(result, owned)
        frozen = self.store.finalize(match_id, terminal, result)
        return Reply.json(200, frozen["result"])

    @staticmethod
    def _owned_error(reply, action):
        # Legacy errors can be arbitrary plain text. Protected endpoints return
        # bounded, non-sensitive errors without reflecting that upstream body.
        if reply.status == 404:
            return Reply.json(404, {"error": "match_unavailable", "message": "The legacy engine cannot find this match. Its active simulation cannot be recovered here."})
        if action == "result" and reply.status == 409:
            return Reply.json(409, {"error": "match_not_finished", "message": "The service has not confirmed a terminal result."})
        if action == "input":
            return Reply.json(503 if reply.status >= 500 else 409,
                              {"error": "input_unconfirmed", "message": "The engine did not accept a confirmed input. Its submitted sequence is retained and the write was not retried."})
        return Reply.json(503, {"error": "upstream_unavailable", "message": "The match service could not return this match. Retry this read later."})


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "OSGARD-REMIX-Guard/1"
    sys_version = ""

    def setup(self):
        super().setup()
        self.connection.settimeout(5)

    def log_message(self, format, *args):
        # Do not persist request headers, credentials, query tokens, or bodies.
        pass

    def dispatch(self):
        try:
            if self.headers.get("Transfer-Encoding"):
                raise GuardError("body_encoding", "Chunked request bodies are not supported by this API guard.", 400)
            lengths = self.headers.get_all("Content-Length", [])
            if (len(lengths) > 1 or any(len(self.headers.get_all(name, [])) > 1 for name in ("Authorization", "Idempotency-Key"))
                    or sum(len(name) + len(value) for name, value in self.headers.items()) > 16384):
                raise GuardError("request_headers", "Request headers are invalid or too large.", 400)
            try:
                size = int(lengths[0]) if lengths else 0
            except ValueError as error:
                raise GuardError("body_length", "Invalid Content-Length.", 400) from error
            if not 0 <= size <= MAX_BODY:
                raise GuardError("body_limit", "Request body exceeds 256 KiB.", 413)
            body = self.rfile.read(size)
            if len(body) != size:
                raise GuardError("body_incomplete", "Request body is incomplete.", 400)
            # BaseHTTPRequestHandler normalizes a leading // before assigning
            # self.path. Validate the original request target so that spelling
            # cannot cross the guard as an unrelated route.
            target = self.requestline.split()[1]
            reply = self.server.guard.handle(self.command, target, body, dict(self.headers.items()))
        except (TimeoutError, OSError):
            reply = Reply.json(408, {"error": "request_timeout", "message": "The request body did not arrive in time."})
        except GuardError as error:
            reply = Reply.json(error.status, {"error": error.code, "message": error.message})
        except Exception:
            # Unexpected local failures must not result in an unguarded retry.
            reply = Reply.json(503, {"error": "guard_unavailable", "message": "The match guard could not complete this request."})
        self.send_response(reply.status)
        for name, value in reply.headers:
            if name.lower() not in HOP_HEADERS | {"server", "date", "cache-control"}:
                self.send_header(name, value)
        self.send_header("Content-Length", str(len(reply.body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        if self.command != "HEAD":
            try:
                self.wfile.write(reply.body)
            except (BrokenPipeError, ConnectionResetError):
                pass

    do_GET = do_HEAD = do_POST = do_OPTIONS = do_PUT = do_PATCH = do_DELETE = dispatch


class Server(ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = 64

    def __init__(self, address, guard):
        self.guard = guard
        self.slots = threading.BoundedSemaphore(MAX_WORKERS)
        super().__init__(address, Handler)

    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            try:
                request.sendall(b"HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\nContent-Length: 0\r\n\r\n")
            finally:
                self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self.slots.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.slots.release()

    def handle_error(self, request, client_address):
        pass


def create_server(database, upstream="http://remix-api:8080", host="127.0.0.1", port=8081, timeout=3, budget=10,
                  core_upstream="http://core-api:4173", core_host="osgard.world", enable_owned_creation=False,
                  enable_participant_admission=False):
    return Server((host, port), Guard(database, upstream, timeout, budget, core_upstream, core_host,
                                      enable_owned_creation, enable_participant_admission))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", type=Path, default=Path("/var/lib/remix-guard/terminal.sqlite3"))
    parser.add_argument("--upstream", default="http://remix-api:8080")
    parser.add_argument("--core-upstream", default="http://core-api:4173")
    parser.add_argument("--core-host", default="osgard.world")
    parser.add_argument("--enable-owned-creation", action="store_true",
                        help="Enable protected v2 creation only after an ACL-aware rollback release is verified.")
    parser.add_argument("--enable-participant-admission", action="store_true",
                        help="Enable addressed second participants only after a schema-3-aware rollback release is verified.")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8081)
    args = parser.parse_args()
    os.umask(0o077)
    server = create_server(args.database, args.upstream, args.host, args.port,
                           core_upstream=args.core_upstream, core_host=args.core_host,
                           enable_owned_creation=args.enable_owned_creation,
                           enable_participant_admission=args.enable_participant_admission)
    print(f"OSGARD REMIX guard ready on port {server.server_address[1]}; auth policy {AUTH_POLICY_VERSION}; "
          f"owned creation {args.enable_owned_creation}; participant policy {PARTICIPANT_POLICY_VERSION}; "
          f"participant admission {args.enable_participant_admission}.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
