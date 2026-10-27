#!/usr/bin/env python3
"""R134 host ONLY restored, source-locked ORIGINAL R87 bytes on localhost.

No production URL is contacted, no public side effect. Strict game origins.
"""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import mimetypes

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/octet-stream", ".pck")


class OriginalGameHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--port", default=4887, type=int)
    args = parser.parse_args()
    runner = os.environ.get("RUNNER_TEMP")
    if not runner or not args.root.resolve().is_relative_to(Path(runner).resolve()):
        parser.error("R134 original R87 service may only run under CI RUNNER_TEMP")
    if args.root.is_symlink() or not (args.root / "release.json").is_file():
        parser.error("R134 restored R87 source release.json not available")
    if args.port < 1024 or args.port > 65535:
        parser.error("Port outside safe unprivileged range")
    handler = partial(OriginalGameHandler, directory=str(args.root.resolve()))
    with ThreadingHTTPServer(("127.0.0.1", args.port), handler) as http:
        print("R134 ORIGINAL R87 restored stage on localhost %d (NOT live VPS)" % args.port,
              flush=True)
        http.serve_forever()


if __name__ == "__main__":
    main()
