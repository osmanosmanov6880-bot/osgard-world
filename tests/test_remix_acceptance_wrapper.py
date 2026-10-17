"""Acceptance plumbing regressions; server gameplay has separate real HTTP tests."""
import contextlib
import functools
import gzip
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import threading
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


matrix = module('remix_local_acceptance_test', 'games-local-acceptance.py')
acceptance = module('remix_server_acceptance_test', 'remix-server-acceptance.py')


class HeadersTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix='osgard-remix-wrapper-')
        self.root = Path(self.scratch.name) / 'dist'
        (self.root / 'games/null-shift-godot').mkdir(parents=True)
        (self.root / 'index.html').write_text('<!doctype html><title>Exact SPA fallback</title>')
        self.header = self.root / '_headers'
        self.wasm = self.root / 'games/null-shift-godot/index.wasm'
        self.header.write_text('/games/null-shift-godot/*.wasm\n  Content-Encoding: gzip\n')
        self.wasm.write_bytes(gzip.compress(b'\x00asm\x01\x00\x00\x00'))

    def tearDown(self):
        self.scratch.cleanup()

    def test_exact_header_and_gzip_bytes_are_both_required(self):
        matrix.check_cloudflare_headers(self.root)
        for contents in ('/*\n  Content-Encoding: gzip\n', '/games/null-shift-godot/*.wasm\n  Content-Encoding: br\n', '/other\n  Content-Encoding: gzip\n'):
            with self.subTest(contents=contents):
                self.header.write_text(contents)
                with self.assertRaises(ValueError): matrix.check_cloudflare_headers(self.root)
        self.header.write_text('/games/null-shift-godot/*.wasm\n  Content-Encoding: gzip\n')
        self.wasm.write_bytes(b'\x00asm\x01\x00\x00\x00')
        with self.assertRaises(ValueError): matrix.check_cloudflare_headers(self.root)

    def test_header_read_is_bounded(self):
        self.header.write_bytes(b'x' * (256 * 1024 + 1))
        with self.assertRaises(ValueError): matrix.check_cloudflare_headers(self.root)

    def test_real_http_serves_packaged_bytes_and_only_exact_spa_routes(self):
        server = matrix.create_server(self.root, Path(self.scratch.name) / 'core.sqlite3', port=0, commerce_config=matrix.core_commerce.Config(enabled=False))
        server.RequestHandlerClass = functools.partial(matrix.matrix_handler(True), directory=str(self.root))
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        base = 'http://127.0.0.1:' + str(server.server_address[1])
        try:
            with urlopen(base + '/games/null-shift-godot/index.wasm?version=1', timeout=5) as response:
                self.assertEqual(response.headers['Content-Encoding'], 'gzip')
                self.assertEqual(response.read(), self.wasm.read_bytes())
            for route in ('/play', '/play/', '/games/time', '/games/time/'):
                with self.subTest(route=route), urlopen(base + route, timeout=5) as response:
                    self.assertEqual(response.read(), (self.root / 'index.html').read_bytes())
                    self.assertIsNone(response.headers.get('Content-Encoding'))
            for route in ('/missing.js', '/games/null-shift-godot/index.pck', '/games/time/missing.js'):
                with self.subTest(route=route), self.assertRaises(HTTPError) as caught:
                    urlopen(base + route, timeout=5)
                self.assertEqual(caught.exception.code, 404)
            (self.root / 'games/time').mkdir()
            (self.root / 'games/time/index.html').write_text('Existing route file')
            with urlopen(base + '/games/time/', timeout=5) as response:
                self.assertEqual(response.read(), b'Existing route file')
        finally:
            server.shutdown(); thread.join(5); server.server_close()


class FailClosedTests(unittest.TestCase):
    def test_cleanup_exception_after_pass_cannot_keep_success(self):
        for script, is_matrix in ((acceptance, False), (matrix, True)):
            with self.subTest(script=script.__name__), tempfile.TemporaryDirectory(prefix='osgard-remix-exit-') as temporary:
                root = Path(temporary) / 'dist'; root.mkdir(); (root / 'index.html').write_text('<title>fixture</title>')
                output = Path(temporary) / ('matrix' if is_matrix else 'result.json')
                passed = dict(schemaVersion=1, status='passed', passed=16, failed=0)
                actor = SimpleNamespace(token='UNIT-TEST-ONLY-NOT-A-SESSION', user={'id': 'fixture'})
                server = SimpleNamespace(server_address=('127.0.0.1', 4179), serve_forever=lambda: None, server_close=lambda: None)
                def fail_shutdown(): raise RuntimeError('Injected cleanup failure after successful checks')
                server.shutdown = fail_shutdown
                fake_thread = SimpleNamespace(start=lambda: None, join=lambda timeout: None)
                arguments = ['acceptance', '--dist', str(root), '--out', str(output)]
                with patch.object(sys, 'argv', arguments), patch.object(script, 'create_server', return_value=server), patch.object(script, 'exercise', return_value=(passed, actor, actor)), patch.object(script.threading, 'Thread', return_value=fake_thread), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                    if is_matrix:
                        with patch.object(script.subprocess, 'run', return_value=SimpleNamespace(returncode=0)):
                            code = script.main()
                    else: code = script.main()
                self.assertEqual(code, 1)
                report = json.loads((output / 'remix-server.json' if is_matrix else output).read_text())
                self.assertEqual(report['status'], 'failed'); self.assertGreaterEqual(report['failed'], 1)


if __name__ == '__main__':
    unittest.main()
