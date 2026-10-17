#!/usr/bin/env python3
"""Run the INHERIT acceptance through an isolated loopback Core/Nginx gateway.

The caller owns and removes both disposable databases. No production target or
credential file is accepted; this uses exactly the live probe's domain checks.
"""
import http.client
import importlib.util
from pathlib import Path
import sys
import time
from urllib.parse import urlsplit


def connection_factory(port, *, clock=time.monotonic, sleep=time.sleep,
                       connection_type=http.client.HTTPConnection):
    # Core's production Nginx policy is 5 requests/second with a burst of 20.
    # Pace this sequential CI probe below that rate, including its logout calls.
    # Probe.request already encloses request() in its per-request/overall budget.
    next_start = None

    class Connection(connection_type):
        def request(self, method, path, body=None, headers=None, **kwargs):
            nonlocal next_start
            started = clock()
            deadline = started + self.timeout
            if next_start is not None and started < next_start:
                if next_start >= deadline:
                    raise TimeoutError('Gateway pacing exceeds the remaining request budget')
                sleep(next_start - started)
            stamp = clock()
            if stamp >= deadline or (next_start is not None and stamp < next_start):
                raise TimeoutError('Gateway pacing did not complete within the request budget')
            next_start = stamp + 0.25
            return super().request(method, path, body, {**(headers or {}), 'Host': 'osgard.world'}, **kwargs)

    def connect(host, *, timeout):
        if host != 'osgard.world':
            raise ValueError('Only the fixed Core host is permitted')
        return Connection('127.0.0.1', port, timeout=timeout)

    return connect


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

    probe = contract.Probe(connection_factory(parsed.port))
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
