#!/usr/bin/env python3
"""Exercise REMIX through real local HTTP, Core auth and disposable SQLite."""
import argparse
import json
from pathlib import Path
import sys
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'server'))
import core_commerce
from core_server import create_server
from remix_acceptance import exercise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dist', type=Path, default=ROOT / 'dist')
    parser.add_argument('--out', type=Path, default=ROOT / 'test-results/remix-server.json')
    args = parser.parse_args()
    server = thread = None
    report = dict(schemaVersion=1, status='failed', passed=0, failed=1)
    try:
        if not (args.dist / 'index.html').is_file():
            raise ValueError('Build the static frontend before running HTTP acceptance.')
        with tempfile.TemporaryDirectory(prefix='osgard-remix-http-') as temporary:
            server = create_server(args.dist, Path(temporary) / 'core.sqlite3', port=0, commerce_config=core_commerce.Config(enabled=False), enable_remix=True)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                report, _, _ = exercise('http://127.0.0.1:' + str(server.server_address[1]))
            finally:
                server.shutdown()
                thread.join(5)
                server.server_close()
    except Exception as error:
        report['status'], report['failed'], report['error'] = 'failed', max(1, report.get('failed', 0)), str(error)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f"REMIX real HTTP acceptance: {report['status']} ({report['passed']} passed, {report['failed']} failed)")
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
