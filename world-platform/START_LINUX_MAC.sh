#!/bin/sh
set -eu
cd "$(dirname "$0")"
echo "LAST FRONTIER WORLD / local original Godot game"
echo "Open http://127.0.0.1:8765/ in a modern browser"
echo "Review-only build; no public game server is started"
exec python3 -m http.server 8765 --bind 127.0.0.1
