#!/usr/bin/env python3
"""CI-only mutable REMIX fixture for Docker/Nginx guard integration.

Run with a read-only checkout mounted into an isolated test container:
  python scripts/remix-guard-fixture.py --host 0.0.0.0 --port 8080

The production RemixGuard.Dockerfile does not copy this script or the tests.
Control routes must only be called on the isolated fixture, never production.
"""

import argparse
from http.server import ThreadingHTTPServer
from pathlib import Path
import sys
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tests"))
from test_remix_guard import Legacy, LegacyHandler, MATCH, PLAYER


class FixtureHandler(LegacyHandler):
    def answer(self, status, value, content_type="application/json"):
        # Match the observed create DTO in the isolated gateway fixture.
        if self.path == "/v1/matches" and status == 201 and isinstance(value, dict):
            value = dict(value, createdAt="2026-10-17T00:00:00Z")
        return super().answer(status, value, content_type)

    def do_GET(self):
        if urlsplit(self.path).path == "/__fixture/echo":
            return self.answer(200, {"path": self.path})
        if urlsplit(self.path).path == "/__fixture/ownership-evidence":
            with self.server.legacy.lock:
                calls = self.server.legacy.calls
                return self.answer(200, {
                    "creates": sum(method == "POST" and path == "/v1/matches" for method, path, _, _ in calls),
                    "inputs": sum(method == "POST" and path.endswith("/input") for method, path, _, _ in calls),
                    "credentialHeaders": sum(any(key.lower() in ("authorization", "cookie") for key in headers) for _, _, _, headers in calls),
                })
        return super().do_GET()

    def do_POST(self):
        legacy = self.server.legacy
        path = urlsplit(self.path).path
        if path.startswith("/__fixture/"):
            if self.headers.get("Transfer-Encoding"):
                return self.answer(400, {"error": "unsupported fixture body"})
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 <= size <= 1024:
                return self.answer(400, {"error": "fixture body limit"})
            self.rfile.read(size)
            with legacy.lock:
                if path == "/__fixture/countdown":
                    legacy.state.update(phase="COUNTDOWN", remainingMs=2500)
                elif path == "/__fixture/playing":
                    legacy.state.update(phase="PLAYING", remainingMs=30000)
                elif path == "/__fixture/terminal":
                    legacy.terminal()
                elif path == "/__fixture/owned-terminal":
                    # Preserve the random authenticated player's existing score.
                    legacy.state.update(phase="RESULTS", remainingMs=0)
                else:
                    return self.answer(404, {"error": "unknown fixture control"})
                return self.answer(200, legacy.state)
        return super().do_POST()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), FixtureHandler)
    server.daemon_threads = True
    server.legacy = Legacy()
    print(f"CI fixture ready: match={MATCH} player={PLAYER} port={server.server_address[1]}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
