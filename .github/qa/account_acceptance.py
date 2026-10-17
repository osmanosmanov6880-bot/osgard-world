#!/usr/bin/env python3
"""One reviewed GitHub push may run bounded QA on the fixed published origin.

This adapter leaves the frozen acceptance probes unchanged. It supplies direct,
verified HTTPS from the GitHub runner, paces requests below the Core gateway
limit, and publishes only the probes' credential-checked evidence.
"""
import hashlib
import http.client
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import ssl
import sys
import time
import types

ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = 'osmanosmanov6880-bot/osgard-world'
INTENT = 'ops/account-live-acceptance.json'
OUTPUT = 'account-live-evidence'
FROZEN_SHA256 = {
    'core-inherit-live-smoke.py': '49c69290fdc99a1c8c5e519bccd2b6b1b183c73382faa9749ec1df06146117ca',
    'remix-participants-live-smoke.py': '66bc4fc48d04c00b1a154ad62acaa730de714e07c876b792a309dc26e98c2ebd',
    'remix-owned-live-smoke.py': 'e816b676d3bf32280adb54f1efa59404c4ab0c557a71c86da6b434c5812bb79d',
    'with-remix-runtime-proxy.py': '080d52d5d7bf094aa6cfccab1441b5d209ea57aa25447a01960f792de7b18e2a',
}


class AcceptanceError(Exception):
    pass


def require(value, message):
    if not value:
        raise AcceptanceError(message)


def validate_context(env):
    require(env.get('GITHUB_ACTIONS') == 'true'
            and env.get('GITHUB_REPOSITORY') == REPOSITORY
            and env.get('GITHUB_EVENT_NAME') == 'push'
            and env.get('GITHUB_REF') == 'refs/heads/master'
            and env.get('GITHUB_RUN_ATTEMPT') == '1',
            'Live QA requires the first attempt of a reviewed master push')
    require(re.fullmatch(r'[a-f0-9]{40}', env.get('GITHUB_SHA', ''))
            and re.fullmatch(r'[1-9][0-9]*', env.get('GITHUB_RUN_ID', '')),
            'GitHub run provenance is incomplete')


def validate_intent(value):
    require(isinstance(value, dict) and set(value) == {'schemaVersion', 'mode', 'expectedRelease'},
            'Only the fixed acceptance intent fields are allowed')
    require(type(value['schemaVersion']) is int and value['schemaVersion'] == 1,
            'Unsupported acceptance intent schema')
    require(value['mode'] in ('foundation', 'participants'),
            'Only foundation or participants acceptance is allowed')
    require(isinstance(value['expectedRelease'], str)
            and re.fullmatch(r'[a-f0-9]{12}', value['expectedRelease']),
            'Acceptance requires one exact published release marker')
    return value


def verify_frozen_sources(root=ROOT):
    for name, expected in FROZEN_SHA256.items():
        path = root / 'scripts' / name
        require(path.is_file() and not path.is_symlink()
                and hashlib.sha256(path.read_bytes()).hexdigest() == expected,
                'A frozen acceptance source differs from its reviewed version')


def connection_factory(*, clock=time.monotonic, sleep=time.sleep,
                       connection_type=http.client.HTTPSConnection,
                       context_factory=ssl.create_default_context):
    context = context_factory()
    require(context.check_hostname and context.verify_mode == ssl.CERT_REQUIRED,
            'Verified TLS is required')
    next_start = None

    class Connection(connection_type):
        def request(self, method, path, body=None, headers=None, **kwargs):
            nonlocal next_start
            require(method in ('GET', 'POST') and isinstance(path, str)
                    and path.startswith('/') and not path.startswith('//')
                    and '\r' not in path and '\n' not in path,
                    'Only a relative fixed-origin QA route is allowed')
            started = clock()
            deadline = started + self.timeout
            if next_start is not None and started < next_start:
                require(next_start < deadline, 'Pacing exceeds the remaining request budget')
                sleep(next_start - started)
            stamp = clock()
            require(stamp < deadline and (next_start is None or stamp >= next_start),
                    'Pacing did not complete within the request budget')
            next_start = stamp + 0.25
            return super().request(method, path, body, headers or {}, **kwargs)

    def connect(host, *, timeout):
        require(host == 'osgard.world', 'Only osgard.world is permitted')
        require(type(timeout) in (float, int) and math.isfinite(timeout) and 0 < timeout <= 12,
                'A bounded QA request timeout is required')
        return Connection('osgard.world', 443, timeout=timeout, context=context)

    return connect


def load_probe(name, root=ROOT):
    require(name in ('core-inherit-live-smoke.py', 'remix-participants-live-smoke.py'),
            'Only the reviewed acceptance probes may run')
    spec = importlib.util.spec_from_file_location(
        '_account_acceptance_' + name.replace('-', '_').replace('.', '_'),
        root / 'scripts' / name)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def publish_report(path, expected_release, summary):
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 262144,
            'The probe did not produce bounded evidence')
    raw = path.read_bytes()
    report = json.loads(raw, parse_constant=lambda _: (_ for _ in ()).throw(AcceptanceError('Nonfinite report')))
    require(isinstance(report, dict) and report.get('origin') == 'https://osgard.world'
            and report.get('status') in ('PASS', 'FAIL')
            and isinstance(report.get('requests'), list)
            and isinstance(report.get('checks'), list),
            'The probe evidence contract is invalid')
    # A failure before release discovery is still useful evidence. Never run the
    # next probe unless the success contract, exact release and cleanup all pass.
    descriptor = dict(file=path.name, sha256=hashlib.sha256(raw).hexdigest(),
                      bytes=len(raw), status=report['status'],
                      requests=len(report['requests']), checks=len(report['checks']))
    summary['reports'].append(descriptor)
    print('ACCOUNT_ACCEPTANCE_REPORT_BEGIN ' + json.dumps(descriptor, sort_keys=True), flush=True)
    print(raw.decode('utf-8'), end='', flush=True)
    print('ACCOUNT_ACCEPTANCE_REPORT_END ' + path.name, flush=True)
    require(report.get('release') == expected_release or report['status'] == 'FAIL',
            'The evidence release differs from the reviewed intent')
    return report


def run_probe(name, flag, release, output, filename, connect, summary, *, loader=load_probe):
    probe = loader(name)

    def fixed_factory(configured):
        require(configured is None, 'The runner does not accept proxy or target configuration')
        return connect

    probe.transport = types.SimpleNamespace(runtime_proxy=lambda: None, connection_factory=fixed_factory)
    old_argv = sys.argv
    sys.argv = [name, '--expected-release', release, '--output', str(output / filename)]
    if flag:
        sys.argv.append(flag)
    try:
        result = probe.main()
    finally:
        sys.argv = old_argv
    report = publish_report(output / filename, release, summary)
    require(result == 0 and report['status'] == 'PASS'
            and report.get('release') == release
            and report.get('allQaSessionsLoggedOut') is True
            and report.get('authOutcomeUncertain') is False,
            'Acceptance failed; no probe or dispatched POST will be retried')
    return report


def run_plan(intent, output, summary, *, run=run_probe, connect=None):
    if connect is None:
        connect = connection_factory()
    release = intent['expectedRelease']
    if intent['mode'] == 'foundation':
        report = run('remix-participants-live-smoke.py', None, release, output,
                     'foundation-capabilities.json', connect, summary)
        caps = report.get('capabilities', {})
        require(report.get('mode') == 'read-only' and len(report['requests']) == 3
                and all(row.get('method') == 'GET' for row in report['requests'])
                and caps.get('authPolicyVersion') == 1
                and caps.get('provider') == 'core'
                and caps.get('ownershipPolicy') == 'confirmed-durable-binding'
                and caps.get('creationEnabled') is True
                and caps.get('participantPolicyVersion') == 1
                and caps.get('participantAdmissionEnabled') is False
                and caps.get('maxParticipants') == 2,
                'The published rollback foundation is not participant-aware with admission disabled')
        run('core-inherit-live-smoke.py', '--exercise-inherit', release, output,
            'inherit-live.json', connect, summary)
    else:
        run('remix-participants-live-smoke.py', '--exercise-participants', release, output,
            'participants-live.json', connect, summary)


def main():
    # Validate the immutable workflow context before filesystem or network work.
    validate_context(os.environ)
    require(len(sys.argv) == 1, 'The runner accepts no target or command arguments')
    intent_path = ROOT / INTENT
    require(intent_path.is_file() and not intent_path.is_symlink() and intent_path.stat().st_size <= 1024,
            'The reviewed acceptance intent is missing or oversized')
    intent = validate_intent(json.loads(intent_path.read_text(encoding='utf-8')))
    verify_frozen_sources()
    output = ROOT / OUTPUT
    require(not output.exists() and not output.is_symlink(), 'Refusing to overwrite acceptance evidence')
    output.mkdir()
    summary = dict(schemaVersion=1, origin='https://osgard.world', intent=intent,
                   sourceCommit=os.environ['GITHUB_SHA'], workflowRunId=os.environ['GITHUB_RUN_ID'],
                   workflowRunAttempt=1, status='running', reports=[])
    try:
        run_plan(intent, output, summary)
        summary['status'] = 'PASS'
    except Exception as error:
        summary['status'] = 'FAIL'
        summary['failure'] = str(error) if isinstance(error, AcceptanceError) else type(error).__name__
    finally:
        with (output / 'acceptance-summary.json').open('x', encoding='utf-8') as handle:
            json.dump(summary, handle, ensure_ascii=False, indent=2)
            handle.write('\n')
        print('ACCOUNT_ACCEPTANCE_SUMMARY ' + json.dumps(summary, sort_keys=True), flush=True)
    return 0 if summary['status'] == 'PASS' else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        print('FAIL account acceptance preflight: '
              + (str(error) if isinstance(error, AcceptanceError) else type(error).__name__), flush=True)
        sys.exit(2)
