"""Real HTTP history/query isolation, keyset pagination and read-only behavior."""
from contextlib import closing
from http.client import HTTPConnection
from pathlib import Path
import hashlib
import importlib.util
import json
import secrets
import sqlite3
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("remix_history_recovery_helpers", ROOT / "scripts/remix-recovery-drill.py")
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)


class RemixHistoryHttpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="osgard-remix-history-http-")
        cls.addClassCleanup(temporary.cleanup)
        cls.work = Path(temporary.name)
        public = cls.work / "public"
        public.mkdir()
        (public / "index.html").write_text("<!doctype html><title>Isolated history API test</title>\n")
        cls.database = cls.work / "core.sqlite3"
        cls.server = helpers.LocalArena(public, cls.database)
        cls.server.__enter__()
        cls.addClassCleanup(cls.server.__exit__, None, None, None)
        cls.accounts, cls.runs = {}, {}
        for name, count, complete_count in (("owner", 25, 2), ("other", 3, 1)):
            account = cls.server.request("POST", "auth/register", {
                "username": "history_" + name + "_" + secrets.token_hex(4),
                "password": secrets.token_urlsafe(32),
            })
            cls.accounts[name] = account
            challenge = helpers.arena_request(cls.server, account["token"], "challenges", {
                "title": "Private history fixture", "seed": 42,
                "objects": [{"id": "goal", "kind": "goal", "x": 1, "y": 3}],
            })
            runs = [helpers.arena_request(cls.server, account["token"], "matches", {
                "challengeId": challenge["id"], "maxPlayers": 1,
            }) for _ in range(count)]
            for run in runs[:complete_count]:
                helpers.arena_request(cls.server, account["token"], "matches/" + run["id"] + "/input", {
                    "sequence": 1, "moveX": 1, "moveY": 0, "jump": False,
                })
            cls.runs[name] = {"active": [run["id"] for run in runs[complete_count:]],
                              "complete": [run["id"] for run in runs[:complete_count]]}

    def database_rows_hash(self):
        # Return only a digest: an assertion failure must not dump password or
        # session rows. The worker has no queued jobs in this isolated fixture.
        with closing(sqlite3.connect(self.database.as_uri() + "?mode=ro", uri=True)) as db:
            db.execute("BEGIN")
            tables = [row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")]
            rows = {table: sorted(json.dumps(row, separators=(",", ":"), ensure_ascii=False)
                                  for row in db.execute('SELECT * FROM "' + table.replace('"', '""') + '"'))
                    for table in tables}
        return hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(",", ":")).encode()).hexdigest()

    def setUp(self):
        self.before = self.database_rows_hash()

    def tearDown(self):
        self.assertEqual(self.database_rows_hash(), self.before, "History GETs must not mutate any Core or arena table")

    def history(self, name="owner", query="", expected=200):
        account = self.accounts[name] if name is not None else None
        return helpers.arena_request(self.server, account["token"] if account else None,
                                     "matches" + ("?" + query if query else ""), expected=expected)

    def ordered_ids(self, name, status):
        # Independently order the captured fixture IDs using their real creation
        # timestamps; no server response supplies this expected membership/order.
        allowed = set(self.runs[name][status])
        with closing(sqlite3.connect(self.database.as_uri() + "?mode=ro", uri=True)) as db:
            rows = [(created, identifier) for identifier, created in db.execute("SELECT id,created_at FROM remix_matches")
                    if identifier in allowed]
        return [identifier for _, identifier in sorted(rows, reverse=True)]

    def test_anonymous_is_rejected_and_default_page_has_twenty_owned_active_runs(self):
        denied = self.history(None, expected=401)
        self.assertEqual(denied["error"], "unauthorized")
        first = self.history()
        self.assertEqual(first["schemaVersion"], 1)
        self.assertEqual(len(first["matches"]), 20)
        self.assertEqual([row["id"] for row in first["matches"]], self.ordered_ids("owner", "active")[:20])
        self.assertEqual(first["nextCursor"], first["matches"][-1]["id"])
        for row in first["matches"]:
            self.assertEqual(set(row), {"id", "challengeId", "title", "phase", "purpose", "createdAt", "stateVerified"})
            self.assertEqual(row["phase"], "PLAYING")
            self.assertIs(row["stateVerified"], False)
        other = self.history("other")
        self.assertEqual([row["id"] for row in other["matches"]], self.ordered_ids("other", "active"))
        self.assertIsNone(other["nextCursor"])
        self.assertTrue(set(row["id"] for row in first["matches"]).isdisjoint(row["id"] for row in other["matches"]))

    def test_real_keyset_pages_are_bounded_stable_and_actor_isolated(self):
        for status in ("active", "complete"):
            for name in ("owner", "other"):
                with self.subTest(name=name, status=status):
                    identifiers, cursor, pages = [], None, 0
                    while True:
                        page = self.history(name, "status=" + status + "&limit=7" + ("&cursor=" + cursor if cursor else ""))
                        self.assertLessEqual(len(page["matches"]), 7)
                        identifiers.extend(row["id"] for row in page["matches"])
                        cursor = page["nextCursor"]
                        pages += 1
                        self.assertLess(pages, 10, "Bounded fixture pagination must terminate")
                        if cursor is None:
                            break
                    self.assertEqual(identifiers, self.ordered_ids(name, status))
                    self.assertEqual(len(set(identifiers)), len(identifiers))
        largest = self.history(query="limit=50")
        self.assertEqual(len(largest["matches"]), 23)
        self.assertIsNone(largest["nextCursor"])

    def test_cursor_is_owner_bound_even_when_its_phase_differs(self):
        foreign = self.runs["other"]["active"][0]
        denied = self.history(query="cursor=" + foreign, expected=400)
        missing = self.history(query="cursor=" + "f" * 32, expected=400)
        self.assertEqual(denied["error"], "invalid_cursor")
        self.assertEqual(denied, missing, "Foreign and nonexistent cursors must not expose different metadata")
        # A cursor remains an owned history position if it has completed since
        # an earlier active page was read. The actual filters still apply.
        own_completed = self.runs["owner"]["complete"][0]
        page = self.history(query="status=active&cursor=" + own_completed)
        self.assertTrue(all(row["phase"] == "PLAYING" for row in page["matches"]))
        self.assertTrue({row["id"] for row in page["matches"]} <= set(self.runs["owner"]["active"]))

    def test_unknown_duplicate_blank_malformed_and_oversized_query_fields_return_400(self):
        invalid = [
            "status=all", "status=", "limit=", "limit=0", "limit=51", "limit=100",
            "limit=01", "limit=1.0", "limit=NaN", "limit=+1", "limit=%FF", "limit=%00",
            "cursor=", "cursor=../id", "unknown=x", "status",
            "status=active&status=active", "limit=1&limit=2", "limit=1&%6cimit=2",
            "status=active&&limit=1", "status=active&limit=1&cursor=x&extra=1", "x" * 257,
        ]
        for query in invalid:
            with self.subTest(query=query[:80]):
                value = self.history(query=query, expected=400)
                self.assertIn(value["error"], ("history_query", "validation", "invalid_cursor"))
                self.assertNotIn("matches", value)

    def test_invalid_or_legacy_routes_do_not_dispatch_to_history_or_legacy_services(self):
        routes = [
            "/api/remix/v1/matches?limit=20", "/api/remix/v2/matches?limit=20",
            "/api/core/remix/v2/matches?limit=20", "/api/core/remix/v1/matches/?limit=20",
            "/api/core/remix/v1/matches/not-a-match?limit=20",
        ]
        for route in routes:
            with self.subTest(route=route):
                # Use a literal HTTP target here: the shared client always
                # prepends /api/core/ and cannot express a legacy namespace.
                connection = HTTPConnection("127.0.0.1", self.server.port, timeout=5)
                try:
                    connection.request("GET", route, headers={"Authorization": "Bearer " + self.accounts["owner"]["token"]})
                    response = connection.getresponse()
                    content = response.read(65537)
                    self.assertLessEqual(len(content), 65536)
                    self.assertEqual(response.status, 404)
                    value = json.loads(content)
                    self.assertEqual(value["error"], "not_found")
                    self.assertNotIn("matches", value)
                finally:
                    connection.close()


if __name__ == "__main__":
    unittest.main()
