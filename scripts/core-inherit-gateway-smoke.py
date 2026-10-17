#!/usr/bin/env python3
"""Run the INHERIT acceptance through an isolated loopback Core/Nginx gateway.

The caller owns and removes both disposable databases. No production target or
credential file is accepted; this uses exactly the live probe's domain checks.
"""
import http.client
import importlib.util
from pathlib import Path
import sys
from urllib.parse import urlsplit


def main():
    if len(sys.argv) != 2:
        raise SystemExit('Supply one isolated loopback gateway URL')
    parsed = urlsplit(sys.argv[1])
    if not (parsed.scheme == 'http' and parsed.hostname == '127.0.0.1' and parsed.port
            and not parsed.path.strip('/') and not parsed.username and not parsed.query and not parsed.fragment):
        raise SystemExit('Only an isolated loopback HTTP gateway is permitted')
    spec = importlib.util.spec_from_file_location('_inherit_gateway_contract', Path(__file__).with_name('core-inherit-live-smoke.py'))
    contract = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(contract)

    class Connection(http.client.HTTPConnection):
        def request(self, method, path, body=None, headers=None, **kwargs):
            return super().request(method, path, body, {**(headers or {}), 'Host': 'osgard.world'}, **kwargs)

    def connect(host, *, timeout):
        assert host == 'osgard.world'
        return Connection('127.0.0.1', parsed.port, timeout=timeout)

    probe = contract.Probe(connect)
    try:
        contract.exercise(probe)
        probe.report['status'] = 'PASS'
    finally:
        probe.cleanup()
    if probe.report['status'] != 'PASS':
        raise SystemExit('INHERIT gateway acceptance did not complete with logged-out QA sessions')
    print(f"PASS INHERIT Core/Nginx: {len(probe.report['checks'])} domain checks, {len(probe.report['requests'])} real HTTP assertions; all QA sessions logged out")


if __name__ == '__main__':
    main()
