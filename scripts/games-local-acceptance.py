#!/usr/bin/env python3
"""Run the game matrix on a disposable Core + authoritative REMIX server."""
import argparse
import functools
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'server'))
import core_commerce
from core_server import Handler, create_server
from remix_acceptance import exercise


def check_cloudflare_headers(dist):
    header_file = dist / '_headers'
    if not header_file.is_file() or header_file.stat().st_size > 256 * 1024:
        raise ValueError('A bounded dist/_headers file is required for packaged WASM.')
    current, encoding = None, None
    for line in header_file.read_text(encoding='utf-8').splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        if not line[0].isspace():
            current = line.strip()
        elif current == '/games/null-shift-godot/*.wasm' and ':' in line:
            name, value = line.strip().split(':', 1)
            if name.lower() == 'content-encoding':
                encoding = value.strip().lower()
    if encoding != 'gzip':
        raise ValueError('The exact Godot WASM header rule must declare Content-Encoding: gzip.')
    with (dist / 'games/null-shift-godot/index.wasm').open('rb') as stream:
        if stream.read(2) != b'\x1f\x8b':
            raise ValueError('Packaged Godot WASM does not have gzip magic.')


def matrix_handler(packaged):
    class MatrixHandler(Handler):
        def send_head(self):
            path = urlsplit(self.path).path
            if path in ('/games/time', '/games/time/', '/play', '/play/') and not Path(self.translate_path(self.path)).exists():
                self.path = '/index.html'
            return super().send_head()

        def end_headers(self):
            if packaged and urlsplit(self.path).path == '/games/null-shift-godot/index.wasm':
                self.send_header('Content-Encoding', 'gzip')
            super().end_headers()
    return MatrixHandler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dist', type=Path, default=ROOT / 'dist')
    parser.add_argument('--out', type=Path, default=ROOT / 'test-results/games-browser')
    parser.add_argument('--only')
    parser.add_argument('--devices')
    parser.add_argument('--timeout', type=int, default=75000)
    parser.add_argument('--cloudflare-headers', action='store_true')
    args = parser.parse_args()
    dist = args.dist.resolve()
    args.out.mkdir(parents=True, exist_ok=True)
    report = dict(schemaVersion=1, status='failed', passed=0, failed=1)
    code = 1
    try:
        if not (dist / 'index.html').is_file():
            raise ValueError('Build the static frontend before browser acceptance.')
        if args.cloudflare_headers:
            check_cloudflare_headers(dist)
        with tempfile.TemporaryDirectory(prefix='osgard-games-local-') as temporary:
            server = create_server(dist, Path(temporary) / 'core.sqlite3', port=0, commerce_config=core_commerce.Config(enabled=False), enable_remix=True)
            server.RequestHandlerClass = functools.partial(matrix_handler(args.cloudflare_headers), directory=str(dist))
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                base = 'http://127.0.0.1:' + str(server.server_address[1])
                report, creator, challenger = exercise(base)
                environment = dict(os.environ, OSGARD_REMIX_ACCEPTANCE_TOKEN=creator.token, OSGARD_REMIX_ACCEPTANCE_ACTOR=creator.user['id'], OSGARD_REMIX_PEER_TOKEN=challenger.token, OSGARD_REMIX_PEER_ACTOR=challenger.user['id'])
                command = ['node', str(ROOT / 'scripts/games-browser-acceptance.mjs'), '--base-url', base, '--allow-api-mutations', '--out', str(args.out.resolve()), '--timeout', str(args.timeout)]
                if args.only:
                    command.extend(['--only', args.only])
                if args.devices:
                    command.extend(['--devices', args.devices])
                print(f"REMIX real HTTP acceptance: {report['passed']} passed; starting the browser matrix on its isolated server.", flush=True)
                code = subprocess.run(command, cwd=ROOT, env=environment, check=False).returncode
                report['browserExitCode'] = code
                report['servingProfile'] = 'cloudflare-packaged-wasm' if args.cloudflare_headers else 'uncompressed-static'
            finally:
                server.shutdown()
                thread.join(5)
                server.server_close()
    except Exception as error:
        code = 1
        report['status'], report['failed'], report['error'] = 'failed', 1, str(error)
        print('Local game acceptance failed: ' + str(error), file=sys.stderr)
    (args.out / 'remix-server.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    return code


if __name__ == '__main__':
    raise SystemExit(main())
