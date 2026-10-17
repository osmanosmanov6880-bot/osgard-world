#!/usr/bin/env python3
"""REMIX phase guard and durable terminal snapshots for the existing HTTP API.

This is original proxy code, not the legacy game implementation. One process
must own a database. It serializes requests for the same match, blocks input
outside a verified playing phase, and never changes a persisted terminal result.
Active matches, player identity, simulation, and complete replays remain upstream.
The read-before-write gate cannot make the legacy simulator's phase expiry
atomic. The durable guarantee starts at the first observed terminal phase.
"""

from __future__ import annotations

import argparse
from contextlib import closing, contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
from pathlib import Path
import re
import socket
import sqlite3
import threading
import time
from urllib.parse import urlsplit


VERSION = 1
MAX_WORKERS = 32
MAX_BODY = 256 * 1024
MAX_RESPONSE = 1024 * 1024
MAX_SAFE_INTEGER = 2 ** 53 - 1
ID = r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}"
MATCH_ROUTE = re.compile(r"^/v1/matches/(?P<id>" + ID + r")/(?P<action>state|result|input)$")
PHASES = {"WAITING", "COUNTDOWN", "PLAYING", "RUNNING", "RESULTS"}
HOP_HEADERS = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
               "te", "trailer", "transfer-encoding", "upgrade", "host", "content-length"}


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
    """Only server state/result DTOs and operational timestamps are persisted."""

    def __init__(self, path):
        self.path = Path(path).absolute()
        if self.path.is_symlink():
            raise ValueError("The guard database cannot be a symlink.")
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        with self.connect() as db:
            version = db.execute("PRAGMA user_version").fetchone()[0]
            if version not in (0, VERSION):
                raise ValueError("Unsupported REMIX guard database version.")
            if db.execute("PRAGMA quick_check").fetchone()[0] != "ok":
                raise ValueError("REMIX guard database integrity check failed.")
            db.execute("PRAGMA journal_mode=WAL")
            db.execute("BEGIN IMMEDIATE")
            db.execute("""CREATE TABLE IF NOT EXISTS terminal_matches(
                match_id TEXT PRIMARY KEY,
                state_json TEXT,
                result_json TEXT,
                observed_at TEXT NOT NULL,
                finalized_at TEXT,
                CHECK(result_json IS NULL OR (state_json IS NOT NULL AND finalized_at IS NOT NULL)))""")
            db.execute("CREATE TABLE IF NOT EXISTS guard_health(id INTEGER PRIMARY KEY CHECK(id=1), sequence INTEGER NOT NULL)")
            db.execute("INSERT OR IGNORE INTO guard_health VALUES(1,0)")
            db.execute(f"PRAGMA user_version={VERSION}")
            db.commit()
        os.chmod(self.path, 0o600)

    @contextmanager
    def connect(self):
        # Existing requests use this same fixed path; no client value becomes a filename.
        with closing(sqlite3.connect(self.path, timeout=2, isolation_level=None)) as db:
            db.row_factory = sqlite3.Row
            db.execute("PRAGMA synchronous=FULL")
            db.execute("PRAGMA busy_timeout=2000")
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
    def __init__(self, base, timeout=3):
        parsed = urlsplit(base)
        if (parsed.scheme not in ("http", "https") or not parsed.hostname or parsed.username is not None
                or parsed.password is not None or parsed.path not in ("", "/") or parsed.query or parsed.fragment):
            raise ValueError("The upstream must be one fixed HTTP(S) origin without credentials or a path.")
        self.host, self.port, self.scheme = parsed.hostname, parsed.port, parsed.scheme
        self.timeout = timeout

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


class Guard:
    def __init__(self, database, upstream="http://remix-api:8080", timeout=3, budget=10):
        self.store = SnapshotStore(database)
        self.upstream = Upstream(upstream, timeout)
        self.budget = budget
        self.locks = [threading.Lock() for _ in range(256)]

    def lock(self, match_id):
        return self.locks[hashlib.sha256(match_id.encode()).digest()[0]]

    def _request(self, method, target, body, headers, deadline):
        return self.upstream.request(method, target, body, headers, deadline)

    def _state(self, match_id, headers, deadline):
        reply = self._request("GET", f"/v1/matches/{match_id}/state", None, headers, deadline)
        if reply.status != 200:
            return reply, None
        # An identity-bound terminal observation blocks future inputs even if
        # other state fields or the subsequent result response are malformed.
        if terminal_identity(reply.body, "id", match_id):
            self.store.mark_terminal(match_id)
        value = reply.object()
        state = validate_state(value, match_id)
        if state["phase"] == "RESULTS":
            self.store.mark_terminal(match_id, state)
        return reply, state

    def _frozen(self, match_id, saved, headers, deadline):
        if saved["result"] is not None:
            return saved
        state = saved["state"]
        if state is None:
            reply, state = self._state(match_id, headers, deadline)
            if reply.status != 200 or state is None or state["phase"] != "RESULTS":
                raise GuardError("terminal_result_pending", "This match is terminal; its result is not safely available yet.")
        reply = self._request("GET", f"/v1/matches/{match_id}/result", None, headers, deadline)
        if reply.status != 200:
            raise GuardError("terminal_result_pending", "This match is terminal; retry fetching its result later.")
        result = validate_result(reply.object(), match_id, state)
        return self.store.finalize(match_id, state, result)

    def handle(self, method, target, body=b"", headers=None):
        headers = headers or {}
        deadline = time.monotonic() + self.budget
        try:
            return self._handle(method, target, body, headers, deadline)
        except (sqlite3.Error, OSError) as error:
            return Reply.json(503, {"error": "storage_unavailable", "message": "Match result storage is unavailable. No input was forwarded without its storage check."})
        except GuardError as error:
            return Reply.json(error.status, {"error": error.code, "message": error.message})

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
            return Reply.json(200, {"status": "ok", "service": "osgard-remix-guard", "schemaVersion": VERSION,
                                    "frozenResults": True, "storage": "ok", "upstream": "ok",
                                    "resultPolicy": "freeze-on-first-terminal-observation",
                                    "activeMatchRecovery": False, "replayVerification": False, "playerAuthentication": False})
        route = MATCH_ROUTE.fullmatch(path)
        if route is None:
            if path.lower().startswith("/v1/matches/"):
                raise GuardError("unknown_match_route", "This match route is not supported.", 404)
            return self._request(method, target, body, headers, deadline)
        if not ((method in ("GET", "HEAD") and route["action"] in ("state", "result")) or
                (method == "POST" and route["action"] == "input")):
            raise GuardError("method_not_allowed", "Use POST for input and GET or HEAD for state and result.", 405)
        match_id, action = route["id"], route["action"]
        lock = self.lock(match_id)
        if not lock.acquire(timeout=min(2, max(0, deadline - time.monotonic()))):
            raise GuardError("match_busy", "This match has a request in progress. Retry the read later.")
        try:
            saved = self.store.load(match_id)
            if action == "input" and saved is not None:
                raise GuardError("match_finished", "This match has finished and cannot accept new input.", 409)
            if saved is not None:
                frozen = self._frozen(match_id, saved, headers, deadline)
                return Reply.json(200, frozen[action])
            if action == "input":
                self.store.probe()
            state_reply, state = self._state(match_id, headers, deadline)
            if state is None:
                return state_reply
            if state["phase"] == "RESULTS":
                if action == "input":
                    raise GuardError("match_finished", "This match has finished and cannot accept new input.", 409)
                frozen = self._frozen(match_id, self.store.load(match_id), headers, deadline)
                return Reply.json(200, frozen[action])
            if action == "state":
                return state_reply
            if action == "input":
                if state["phase"] not in ("PLAYING", "RUNNING") or state["remainingMs"] <= 0:
                    raise GuardError("match_not_playing", "The service has not confirmed an active playing phase.", 409)
                return self._request("POST", target, body, headers, deadline)
            result_reply = self._request("GET", target, None, headers, deadline)
            if result_reply.status != 200:
                return result_reply
            # The phase may have changed during the two reads. Establish and
            # persist a matching terminal state before exposing the result.
            if terminal_identity(result_reply.body, "matchId", match_id):
                self.store.mark_terminal(match_id)
            result = result_reply.object()
            _, terminal = self._state(match_id, headers, deadline)
            require(terminal is not None and terminal["phase"] == "RESULTS", "A result arrived before a matching terminal state.")
            validate_result(result, match_id, terminal)
            frozen = self.store.finalize(match_id, terminal, result)
            return Reply.json(200, frozen["result"])
        finally:
            lock.release()


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
            if len(lengths) > 1 or sum(len(name) + len(value) for name, value in self.headers.items()) > 16384:
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


def create_server(database, upstream="http://remix-api:8080", host="127.0.0.1", port=8081, timeout=3, budget=10):
    return Server((host, port), Guard(database, upstream, timeout, budget))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", type=Path, default=Path("/var/lib/remix-guard/terminal.sqlite3"))
    parser.add_argument("--upstream", default="http://remix-api:8080")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8081)
    args = parser.parse_args()
    os.umask(0o077)
    server = create_server(args.database, args.upstream, args.host, args.port)
    print(f"OSGARD REMIX guard ready on port {server.server_address[1]}; snapshot schema {VERSION}.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
