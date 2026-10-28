#!/usr/bin/env python3
"""IRON PULSE local preview host.

Runs the exact-source portal and its offline Godot WebGL without uploading
files or personal data. COOP/COEP headers are required by some Godot WebGL
export configurations using SharedArrayBuffer. Do not expose to the internet.
"""
from __future__ import annotations
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

class SafeGameHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

def main() -> None:
    parser = argparse.ArgumentParser(description="Serve IRON PULSE software preview on loopback only")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent)
    options = parser.parse_args()
    if not 1024 <= options.port <= 65535:
        parser.error("Port must be within 1024..65535")
    directory = options.root.resolve(strict=True)
    if not directory.is_dir():
        parser.error("Root must be an existing directory")
    handler = partial(SafeGameHandler, directory=str(directory))
    with ThreadingHTTPServer(("127.0.0.1", options.port), handler) as server:
        print(f"IRON PULSE / local preview: http://127.0.0.1:{options.port}/", flush=True)
        server.serve_forever()

if __name__ == "__main__":
    main()
