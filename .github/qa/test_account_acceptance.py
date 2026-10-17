#!/usr/bin/env python3
"""Offline safety checks for the one-time published acceptance adapter."""
import hashlib
import importlib.util
import json
from pathlib import Path
import ssl
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('account_acceptance', Path(__file__).with_name('account_acceptance.py'))
QA = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(QA)
RELEASE = '48879eb3c94e'


def intent(mode='foundation'):
    return dict(schemaVersion=1, mode=mode, expectedRelease=RELEASE)


def environment():
    return dict(GITHUB_ACTIONS='true', GITHUB_REPOSITORY=QA.REPOSITORY,
                GITHUB_EVENT_NAME='push', GITHUB_REF='refs/heads/master',
                GITHUB_RUN_ATTEMPT='1', GITHUB_SHA='a' * 40, GITHUB_RUN_ID='123')


def evidence(**overrides):
    return dict(dict(schemaVersion=1, origin='https://osgard.world', release=RELEASE,
                     status='PASS', mode='read-only', allQaSessionsLoggedOut=True,
                     authOutcomeUncertain=False, checks=['one'],
                     requests=[dict(method='GET', status=200)] * 3,
                     capabilities=dict(authPolicyVersion=1, provider='core',
                                       ownershipPolicy='confirmed-durable-binding',
                                       creationEnabled=True, participantPolicyVersion=1,
                                       participantAdmissionEnabled=False, maxParticipants=2)),
                **overrides)


class Clock:
    def __init__(self):
        self.now = 0
        self.waits = []

    def __call__(self):
        return self.now

    def sleep(self, amount):
        self.waits.append(amount)
        self.now += amount


class FakeConnection:
    created = []
    sent = []

    def __init__(self, host, port, *, timeout, context):
        self.host, self.port, self.timeout, self.context = host, port, timeout, context
        self.created.append(self)

    def request(self, method, path, body=None, headers=None, **kwargs):
        self.sent.append((method, path, body, headers))
        return 'sent'


class AcceptanceTests(unittest.TestCase):
    def setUp(self):
        FakeConnection.created = []
        FakeConnection.sent = []

    def factory(self, clock=None, sleep=None):
        clock = clock or Clock()
        return QA.connection_factory(clock=clock, sleep=sleep or clock.sleep,
                                     connection_type=FakeConnection), clock

    def test_exact_master_first_attempt_context(self):
        QA.validate_context(environment())
        for key, bad in [('GITHUB_ACTIONS', ''), ('GITHUB_REPOSITORY', 'other/repo'),
                         ('GITHUB_EVENT_NAME', 'pull_request'), ('GITHUB_REF', 'refs/heads/qa'),
                         ('GITHUB_RUN_ATTEMPT', '2'), ('GITHUB_SHA', 'abcd'),
                         ('GITHUB_RUN_ID', '0')]:
            with self.subTest(key=key), self.assertRaises(QA.AcceptanceError):
                QA.validate_context(dict(environment(), **{key: bad}))

    def test_intent_rejects_target_commands_unknown_mode_and_malformed_release(self):
        for mode in ('foundation', 'participants'):
            self.assertEqual(QA.validate_intent(intent(mode)), intent(mode))
        bad_values = [None, dict(intent(), target='https://other.invalid'),
                      dict(intent(), command='arbitrary'), dict(intent(), mode='owned'),
                      dict(intent(), schemaVersion=True), dict(intent(), expectedRelease=''),
                      dict(intent(), expectedRelease='A' * 12),
                      dict(intent(), expectedRelease=123)]
        for value in bad_values:
            with self.subTest(value=value), self.assertRaises(QA.AcceptanceError):
                QA.validate_intent(value)

    def test_invalid_context_stops_before_reading_or_loading_probe(self):
        with patch.dict(QA.os.environ, {}, clear=True), patch.object(QA, 'verify_frozen_sources') as verify, \
             patch.object(QA, 'run_plan') as run:
            with self.assertRaises(QA.AcceptanceError):
                QA.main()
            verify.assert_not_called()
            run.assert_not_called()

    def test_frozen_source_digest_and_symlink_gate(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'scripts').mkdir()
            source = root / 'scripts' / 'frozen.py'
            source.write_bytes(b'known source\n')
            with patch.object(QA, 'FROZEN_SHA256', {'frozen.py': hashlib.sha256(source.read_bytes()).hexdigest()}):
                QA.verify_frozen_sources(root)
                source.write_bytes(b'changed source\n')
                with self.assertRaises(QA.AcceptanceError):
                    QA.verify_frozen_sources(root)
                source.unlink()
                target = root / 'target.py'
                target.write_bytes(b'known source\n')
                source.symlink_to(target)
                with self.assertRaises(QA.AcceptanceError):
                    QA.verify_frozen_sources(root)

    def test_loader_rejects_arbitrary_probe_before_import(self):
        with self.assertRaises(QA.AcceptanceError):
            QA.load_probe('../../other.py')

    def test_direct_transport_uses_only_fixed_host_port_and_verified_tls(self):
        connect, _ = self.factory()
        connection = connect('osgard.world', timeout=12)
        self.assertEqual((connection.host, connection.port), ('osgard.world', 443))
        self.assertTrue(connection.context.check_hostname)
        self.assertEqual(connection.context.verify_mode, ssl.CERT_REQUIRED)
        for host in ('http://osgard.world', 'osgard.world:443', '127.0.0.1', 'other.invalid'):
            with self.assertRaises(QA.AcceptanceError):
                connect(host, timeout=12)
        for timeout in (0, -1, 13, True, float('nan'), float('inf')):
            with self.assertRaises(QA.AcceptanceError):
                connect('osgard.world', timeout=timeout)
        self.assertEqual(len(FakeConnection.created), 1)

    def test_unverified_tls_context_is_rejected(self):
        with self.assertRaises(QA.AcceptanceError):
            QA.connection_factory(context_factory=lambda: types.SimpleNamespace(check_hostname=False, verify_mode=ssl.CERT_NONE))

    def test_pacing_is_shared_across_connections_including_cleanup(self):
        connect, clock = self.factory()
        self.assertEqual(connect('osgard.world', timeout=12).request('GET', '/'), 'sent')
        connect('osgard.world', timeout=12).request('POST', '/api/core/auth/register', b'body', {})
        connect('osgard.world', timeout=5).request('POST', '/api/core/auth/logout', b'{}', {})
        self.assertEqual(clock.waits, [0.25, 0.25])
        self.assertEqual(len(FakeConnection.sent), 3)

    def test_pacing_cannot_dispatch_when_remaining_timeout_is_too_short(self):
        connect, _ = self.factory()
        connect('osgard.world', timeout=12).request('GET', '/')
        with self.assertRaises(QA.AcceptanceError):
            connect('osgard.world', timeout=0.2).request('POST', '/api/core/auth/register')
        self.assertEqual(len(FakeConnection.sent), 1)

    def test_early_sleep_does_not_dispatch_or_retry(self):
        connect, _ = self.factory(sleep=lambda _: None)
        connect('osgard.world', timeout=12).request('GET', '/')
        with self.assertRaises(QA.AcceptanceError):
            connect('osgard.world', timeout=12).request('POST', '/api/core/auth/register')
        self.assertEqual(len(FakeConnection.sent), 1)

    def test_absolute_or_injected_routes_are_rejected_before_dispatch(self):
        connect, _ = self.factory()
        for method, path in [('DELETE', '/'), ('GET', '//other.invalid/'),
                             ('GET', 'https://other.invalid/'), ('GET', '/\r\nHeader: value')]:
            with self.assertRaises(QA.AcceptanceError):
                connect('osgard.world', timeout=12).request(method, path)
        self.assertEqual(FakeConnection.sent, [])

    def test_foundation_checks_readonly_caps_then_inherit(self):
        calls = []
        def run(*args):
            calls.append(args)
            return evidence()
        QA.run_plan(intent(), Path('/unused'), {'reports': []}, run=run, connect=object())
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0][:3], ('remix-participants-live-smoke.py', None, RELEASE))
        self.assertEqual(calls[1][:3], ('core-inherit-live-smoke.py', '--exercise-inherit', RELEASE))

    def test_incorrect_foundation_caps_stop_before_any_inherit_write(self):
        changes = [dict(participantAdmissionEnabled=True), dict(participantPolicyVersion=None),
                   dict(creationEnabled=False), dict(maxParticipants=3),
                   dict(provider='other'), dict(ownershipPolicy='other')]
        for change in changes:
            calls = []
            def run(*args):
                calls.append(args)
                return evidence(capabilities=dict(evidence()['capabilities'], **change))
            with self.subTest(change=change), self.assertRaises(QA.AcceptanceError):
                QA.run_plan(intent(), Path('/unused'), {'reports': []}, run=run, connect=object())
            self.assertEqual(len(calls), 1)

    def test_foundation_preflight_must_be_three_gets(self):
        for report in (evidence(mode='write'), evidence(requests=[dict(method='POST')] * 3),
                       evidence(requests=[dict(method='GET')])):
            calls = []
            def run(*args):
                calls.append(args)
                return report
            with self.assertRaises(QA.AcceptanceError):
                QA.run_plan(intent(), Path('/unused'), {'reports': []}, run=run, connect=object())
            self.assertEqual(len(calls), 1)

    def test_participants_only_invokes_the_reviewed_two_account_probe_once(self):
        calls = []
        QA.run_plan(intent('participants'), Path('/unused'), {'reports': []},
                    run=lambda *args: calls.append(args), connect=object())
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][:3], ('remix-participants-live-smoke.py', '--exercise-participants', RELEASE))

    def test_probe_arguments_transport_and_argv_restoration(self):
        old_argv = sys.argv
        summary = {'reports': []}
        connect = object()
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder)
            module = types.SimpleNamespace()
            def main():
                self.assertEqual(sys.argv[1:], ['--expected-release', RELEASE, '--output',
                                              str(output / 'inherit-live.json'), '--exercise-inherit'])
                self.assertIsNone(module.transport.runtime_proxy())
                self.assertIs(module.transport.connection_factory(None), connect)
                with self.assertRaises(QA.AcceptanceError):
                    module.transport.connection_factory('unexpected configuration')
                (output / 'inherit-live.json').write_text(json.dumps(evidence()), encoding='utf-8')
                return 0
            module.main = main
            with patch('builtins.print'):
                report = QA.run_probe('core-inherit-live-smoke.py', '--exercise-inherit', RELEASE,
                                      output, 'inherit-live.json', connect, summary, loader=lambda _: module)
            self.assertEqual(report['status'], 'PASS')
            self.assertIs(sys.argv, old_argv)
            self.assertEqual(len(summary['reports']), 1)
            raw = (output / 'inherit-live.json').read_bytes()
            self.assertEqual(summary['reports'][0]['sha256'], hashlib.sha256(raw).hexdigest())

    def test_failed_probe_or_cleanup_is_preserved_and_never_retried(self):
        for change in (dict(status='FAIL'), dict(allQaSessionsLoggedOut=False),
                       dict(authOutcomeUncertain=True), dict(release='b' * 12)):
            calls = []
            with tempfile.TemporaryDirectory() as folder:
                output = Path(folder)
                def main():
                    calls.append('once')
                    (output / 'probe.json').write_text(json.dumps(evidence(**change)), encoding='utf-8')
                    return 0
                with patch('builtins.print'), self.assertRaises(QA.AcceptanceError):
                    QA.run_probe('core-inherit-live-smoke.py', '--exercise-inherit', RELEASE,
                                 output, 'probe.json', object(), {'reports': []},
                                 loader=lambda _: types.SimpleNamespace(main=main))
                self.assertEqual(calls, ['once'])
                self.assertTrue((output / 'probe.json').is_file())

    def test_probe_exception_restores_argv_and_does_not_retry(self):
        old_argv = sys.argv
        calls = []
        def main():
            calls.append('once')
            raise TimeoutError()
        with self.assertRaises(TimeoutError):
            QA.run_probe('core-inherit-live-smoke.py', '--exercise-inherit', RELEASE,
                         Path('/unused'), 'probe.json', object(), {'reports': []},
                         loader=lambda _: types.SimpleNamespace(main=main))
        self.assertIs(sys.argv, old_argv)
        self.assertEqual(calls, ['once'])


    def test_checked_out_probes_match_the_reviewed_frozen_versions(self):
        QA.verify_frozen_sources()

    def test_real_readonly_probes_use_injected_transport_and_send_only_three_gets(self):
        for name in ('core-inherit-live-smoke.py', 'remix-participants-live-smoke.py'):
            requests = []
            class Response:
                status = 200
                def __init__(self, path):
                    self.path = path
                def getheader(self, header, default=''):
                    return ('text/html' if self.path == '/' else 'application/json') if header == 'Content-Type' else 'no-store'
                def read(self, limit):
                    if self.path == '/':
                        return ('<script src="/brand/osa-transition.js?v=' + RELEASE + '"></script>').encode()
                    if self.path == '/api/core/health':
                        return b'{"status":"ok"}'
                    return json.dumps(evidence()['capabilities']).encode()
            class Connection:
                def request(self, method, path, body=None, headers=None):
                    self.path = path
                    requests.append((method, path))
                def getresponse(self):
                    return Response(self.path)
                def close(self):
                    pass
            def connect(host, *, timeout):
                self.assertEqual(host, 'osgard.world')
                self.assertGreater(timeout, 0)
                self.assertLessEqual(timeout, 12)
                return Connection()
            with self.subTest(name=name), tempfile.TemporaryDirectory() as folder, patch('builtins.print'):
                summary = {'reports': []}
                report = QA.run_probe(name, None, RELEASE, Path(folder), 'readonly.json',
                                      connect, summary)
                self.assertEqual(report['status'], 'PASS')
                self.assertEqual(len(requests), 3)
                self.assertTrue(all(method == 'GET' for method, path in requests))
                self.assertEqual(len(summary['reports']), 1)


if __name__ == '__main__':
    unittest.main()
