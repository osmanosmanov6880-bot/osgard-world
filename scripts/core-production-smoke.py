#!/usr/bin/env python3
"""Check the production Core gateway, persistence and proxy policy without Docker or publishing."""
from pathlib import Path
from tempfile import TemporaryDirectory
from threading import Thread
from urllib.error import HTTPError
from urllib.request import Request, urlopen
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'server'))
import core_server

compose = (ROOT / 'docker-compose.production.yml').read_text()
dockerfile = (ROOT / 'server/Dockerfile').read_text()
nginx = (ROOT / 'nginx.conf').read_text()
docs = (ROOT / 'docs/CORE-PRODUCTION.md').read_text()
backup = (ROOT / 'scripts/backup-core-production.sh').read_text()

def block(text, start, end):
    assert start in text, f'missing section {start}'
    value = text.split(start, 1)[1]
    return value.split(end, 1)[0] if end in value else value

service_match = re.search(r'(?ms)^  core-api:\n(.*?)(?=^  remix-api:|\Z)', compose)
web_match = re.search(r'(?ms)^  osgard-world:\n(.*?)(?=^  core-api:)', compose)
assert service_match and web_match
service, web = service_match[1], web_match[1]
dockerignore = (ROOT / '.dockerignore').read_text()
assert 'dockerfile: server/Dockerfile' in service
assert 'expose:\n      - "4173"' in service and 'ports:' not in service
assert 'osgard-core-data:/var/lib/osgard-core' in service
assert 'read_only: true' in service and 'no-new-privileges:true' in service and 'cap_drop:' in service
assert 'mem_limit: 768m' in service and 'cpus: "1.0"' in service
assert 'condition: service_healthy' in web and 'core-api:' in web
assert 'osgard-core-data:' in compose
assert '!server/**' in dockerignore and '!dist/**' in dockerignore and '.env' not in dockerignore
assert 'USER 10001:10001' in dockerfile and 'HEALTHCHECK' in dockerfile
assert '--public-origin' in service and 'OSGARD_CORE_PUBLIC_ORIGIN' in service
assert 'location ^~ /api/core/ {' in nginx
core_proxy = block(nginx, '  location ^~ /api/core/ {', '\n  location / {')
for token in ('proxy_pass http://$osgard_core_api_host:4173;', 'proxy_set_header Host $host;', 'proxy_set_header X-Real-IP $remote_addr;', 'client_max_body_size 256k;', 'Cache-Control "no-store"'):
    assert token in core_proxy, f'Core proxy missing {token}'
assert 'osgard_core_api' in nginx and 'limit_req_status 429;' in core_proxy
backup_module = (ROOT / 'server/core_backup.py').read_text()
assert 'from core_backup import backup' in backup and 'server/core_backup.py publish' in backup
assert 'src.backup(dst,' in backup_module and 'PRAGMA integrity_check' in backup_module
assert 'PRAGMA foreign_key_check' in backup_module and '?mode=ro' in backup_module
assert '--sha256 "$remote_sha"' in backup and 'sha256sum -c' in backup and 'chmod 600' in backup
assert 'named Docker volume is persistence, not a backup' in docs

with TemporaryDirectory() as directory:
    root = Path(directory) / 'static'
    root.mkdir()
    (root / 'index.html').write_text('<title>temporary Core route fixture</title>')
    server = core_server.create_server(root, Path(directory) / 'db' / 'core.sqlite3', port=0, public_origin='https://osgard.world')
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f'http://127.0.0.1:{server.server_address[1]}/api/core/health'
    try:
        healthy = Request(base, headers={'Host': 'osgard.world', 'Origin': 'https://osgard.world'})
        with urlopen(healthy, timeout=3) as response:
            payload = response.read().decode()
            assert response.status == 200 and '"status":"ok"' in payload
            assert '"payments":false' in payload and '"ai":false' in payload
        for headers in (
            {'Host': 'attacker.example', 'Origin': 'https://osgard.world'},
            {'Host': 'osgard.world', 'Origin': 'https://attacker.example'},
        ):
            try:
                urlopen(Request(base, headers=headers), timeout=3)
                raise AssertionError('untrusted host/origin was accepted')
            except HTTPError as error:
                assert error.code == 403
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=3)

print('PASS Core production gateway: private API, persistent volume, constrained container, origin policy, health, bounded requests and verified online backup command')
