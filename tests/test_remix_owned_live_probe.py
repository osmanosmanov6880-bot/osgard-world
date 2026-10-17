"""Offline regression tests for the opt-in public REMIX verification CLI.

The stateful fixture applies a request before optionally losing its response, so
reported cleanup is checked against sessions that actually remain in the fixture.
All HTTP and socket connection paths are blocked or replaced; no server is run.
POSIX alarm tests use real signals and bounded blocking stand-ins, not live HTTP.
"""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import signal
import socket
import tempfile
import time
import types
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "remix_owned_live_probe", Path(__file__).resolve().parents[1] / "scripts/remix-owned-live-smoke.py")
mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)


class Fixture:
    """Small stateful protocol peer; faults happen after its mutation commits."""

    def __init__(self, fault=None):
        self.now = 0.0
        self.fault = fault
        self.fault_used = False
        self.calls = []
        self.users = {}
        self.sessions = {}
        self.issued = []
        self.secret_values = []
        self.match = None
        self.created_at = None
        self.playing_at = None
        self.frames = 0
        self.sequence = 0
        self.active_input_posts = 0
        self.logout_counts = {}
        self.closed_connections = 0
    def sleep(self, value): self.now += value
    def status(self):
        if self.now - self.created_at < 2.6: return 'COUNTDOWN'
        if self.playing_at is None: self.playing_at = self.now
        return 'PLAYING' if self.now - self.playing_at < 30 else 'RESULTS'
    def new_session(self, user):
        token = 'T' * 41 + str(len(self.issued) + 1).zfill(2)
        self.issued.append(token)
        self.secret_values.append(token)
        self.sessions[token] = user
        return token
    def dispatch(self, method, target, body, headers):
        self.now += .02
        payload = json.loads(body) if body is not None else None
        token = headers.get('Authorization', '').removeprefix('Bearer ')
        self.calls.append((method, target, token))
        if target == '/': return 200, b'<script src="/brand/osa-transition.js?v=123456789abc"></script>', 'text/html'
        if target.endswith('/capabilities'):
            return 200, {'authPolicyVersion':1,'provider':'core','ownershipPolicy':'confirmed-durable-binding','creationEnabled':True,'legacyMatches':'anonymous','activeMatchRecovery':False,'replayVerification':False}, 'application/json'
        if target in ('/api/core/auth/register', '/api/core/auth/login'):
            self.secret_values.extend([payload['username'], payload['password']])
            if target.endswith('/register'):
                user = {'id':'qa_user_' + str(len(self.users) + 1), 'username':payload['username']}
                self.users[payload['username']] = user
            user = self.users[payload['username']]
            session = self.new_session(user)
            return 200, {'token':session,'user':user,'expiresInSeconds':28800}, 'application/json'
        if target == '/api/core/auth/logout':
            self.logout_counts[token] = self.logout_counts.get(token, 0) + 1
            self.sessions.pop(token, None)
            return 200, {'loggedOut':True}, 'application/json'
        if target == '/api/core/auth/me':
            return (200, {'user':self.sessions[token]}, 'application/json') if token in self.sessions else (401, {'error':'unauthorized'}, 'application/json')
        if target == '/api/remix/v1/challenges':
            assert payload['visibility'] == 'private'
            return 201, dict(payload, id='ch_qa_fixture'), 'application/json'
        if target == '/api/remix/v2/matches' and method == 'POST':
            assert set(payload) == {'challengeId', 'maxPlayers'} and payload['maxPlayers'] == 2
            self.owner = self.sessions[token]['id']
            self.created_at = self.now
            self.match = dict(payload, id='match_qa_fixture', createdAt='2026-10-17T00:00:00Z', playerId='corep_' + 'f'*32, highestSubmittedSequence=0, accessMode='core-owned')
            return 201, dict(self.match), 'application/json'
        if target.startswith('/api/remix/v2/creation-attempts/'):
            return 200, {'status':'ready','match':dict(self.match)}, 'application/json'
        if target == '/api/remix/v2/matches':
            rows = [dict(self.match)] if self.sessions[token]['id'] == self.owner else []
            return 200, {'matches':rows,'nextCursor':None}, 'application/json'
        if target.startswith(('/api/remix/v1/matches/', '/api/remix/v2/matches/')):
            if token not in self.sessions: return 401, {'error':'authentication_required'}, 'application/json'
            if self.sessions[token]['id'] != self.owner: return 403, {'error':'match_forbidden'}, 'application/json'
            if target.endswith('/state'):
                phase = self.status()
                return 200, {'id':self.match['id'],'phase':phase,'players':int(self.frames>0),'remainingMs':0 if phase=='RESULTS' else 1000,'replayFrames':self.frames,'scores':[] if self.frames==0 else [{'playerId':self.match['playerId'],'score':.1}]}, 'application/json'
            if target.endswith('/result'):
                return 200, {'matchId':self.match['id'],'phase':'RESULTS','replayFrames':self.frames,'scores':[{'playerId':self.match['playerId'],'score':.1}]}, 'application/json'
            if target.endswith('/input'):
                if self.status() == 'RESULTS' or payload['sequence'] <= self.sequence: return 409, {'error':'match_finished'}, 'application/json'
                self.sequence = payload['sequence']; self.frames += 1; self.active_input_posts += 1
                self.match['highestSubmittedSequence'] = self.sequence
                return 200, {'playerId':self.match['playerId'],'lastSequence':self.sequence,'position':[.1,0,0],'velocityY':0,'onGround':True,'score':.1}, 'application/json'
            return 200, dict(self.match), 'application/json'
        raise AssertionError('Unexpected fixture route')
    def connection(self, host, timeout):
        fixture = self
        assert host == 'osgard.world'
        class Connection:
            def request(self, method, target, body=None, headers=None):
                self.target = target
                status, payload, content_type = fixture.dispatch(method, target, body, headers)
                self.reply = types.SimpleNamespace(status=status, read=lambda size: payload if isinstance(payload, bytes) else json.dumps(payload).encode(), getheader=lambda name, default='': content_type if name.lower()=='content-type' else 'no-store' if name.lower()=='cache-control' else default)
            def getresponse(self):
                if not fixture.fault_used and ((fixture.fault == 'lost-register' and self.target.endswith('/auth/register')) or (fixture.fault == 'lost-logout' and self.target.endswith('/auth/logout'))):
                    fixture.fault_used = True
                    raise TimeoutError('synthetic transport text must not be retained')
                if not fixture.fault_used and fixture.fault == 'slow-body' and self.target == '/api/remix/v2/capabilities':
                    fixture.fault_used = True
                    original = self.reply.read
                    def delayed(size):
                        fixture.now += 101
                        return original(size)
                    self.reply.read = delayed
                return self.reply
            def close(self): fixture.closed_connections += 1
        return Connection()


class CheckedFixture(Fixture):
    """Observe journaling at the transport boundary, then inject lost replies."""

    def dispatch(self, method, target, body, headers):
        entry = self.probe.report['requests'][-1]
        assert (entry['method'], entry['path'], entry['outcome']) == (method, target, 'pending')
        assert len(self.probe.report['requests']) == len(self.calls) + 1
        if target in ('/api/core/auth/register', '/api/core/auth/login'):
            assert self.probe.report['authOutcomeUncertain'] is True
        return super().dispatch(method, target, body, headers)
    def connection(self, host, timeout):
        connection = super().connection(host, timeout)
        original_request, original_response = connection.request, connection.getresponse
        def request(method, target, body=None, headers=None):
            connection.method = method
            return original_request(method, target, body, headers)
        def response():
            value = original_response()
            target = connection.target
            eligible = ((self.fault == 'lost-login' and target.endswith('/auth/login'))
                or (self.fault == 'lost-create' and target == '/api/remix/v2/matches' and connection.method == 'POST')
                or (self.fault == 'lost-owner-input' and target.endswith('/input') and self.active_input_posts == 1)
                or (self.fault == 'lost-final-logout' and target.endswith('/auth/logout') and len(self.issued) == 4 and self.calls[-1][2] == self.issued[-1])
                or (self.fault in ('auth-secret-error', 'auth-invalid-json', 'auth-no-store', 'auth-missing-token', 'auth-invalid-token', 'auth-clock-expiry') and target.endswith('/auth/register'))
                or (self.fault == 'invalid-login-user' and target.endswith('/auth/login')))
            if eligible and not self.fault_used:
                self.fault_used = True
                if self.fault.startswith('lost-'):
                    raise TimeoutError('Private diagnostic ' + self.secret_values[-1])
                raw = json.dumps({'password':self.secret_values[1], 'token':self.issued[0], 'username':self.secret_values[0]}).encode()
                if self.fault == 'auth-secret-error':
                    value.status = 500; value.read = lambda size: raw
                elif self.fault == 'auth-invalid-json': value.read = lambda size: b'{' + raw
                elif self.fault == 'auth-no-store':
                    getheader = value.getheader
                    value.getheader = lambda name, default='': '' if name == 'Cache-Control' else getheader(name, default)
                elif self.fault in ('auth-missing-token', 'auth-invalid-token', 'invalid-login-user'):
                    payload = json.loads(value.read(1_048_577))
                    if self.fault == 'auth-missing-token': payload.pop('token')
                    elif self.fault == 'auth-invalid-token': payload['token'] = 'invalid'
                    else: payload['user'] = []
                    value.read = lambda size: json.dumps(payload).encode()
                else:
                    read = value.read
                    def late_read(size): self.now += 101; return read(size)
                    value.read = late_read
            return value
        connection.request, connection.getresponse = request, response
        return connection


@unittest.skipUnless(hasattr(signal, 'setitimer') and hasattr(signal, 'SIGALRM'),
                     'The live verification CLI requires POSIX interval timers')
class LiveProbeTests(unittest.TestCase):
    def setUp(self):
        # A failing alarm regression must not leave a timer for a later test.
        # Temporarily isolate any timer owned by the test runner itself.
        previous_handler = signal.getsignal(signal.SIGALRM)
        previous_timer = signal.setitimer(signal.ITIMER_REAL, 0)
        started = time.monotonic()

        def restore_alarm():
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, previous_handler)
            if previous_timer[0]:
                remaining = max(.000001, previous_timer[0] - (time.monotonic() - started))
                signal.setitimer(signal.ITIMER_REAL, remaining, previous_timer[1])

        self.addCleanup(restore_alarm)
        for target, name in ((mod.http.client, 'HTTPSConnection'), (socket, 'create_connection'),
                             (socket.socket, 'connect'), (socket.socket, 'connect_ex')):
            blocker = patch.object(target, name, side_effect=AssertionError('Real network is forbidden'))
            blocker.start()
            self.addCleanup(blocker.stop)

    def run_fixture(self, scenario='healthy', exercise=True):
        fixture = CheckedFixture(scenario)
        original_probe = mod.Probe
        class RecordedProbe(original_probe):
            def __init__(self, *args):
                super().__init__(*args)
                fixture.probe = self
        with tempfile.TemporaryDirectory(prefix='owned-live-fixed-') as directory:
            output = Path(directory) / 'evidence.json'
            argv = ['probe', '--expected-release', '123456789abc', '--output', str(output)]
            if exercise:
                argv.append('--exercise-owned')
            stdout = io.StringIO()
            with contextlib.ExitStack() as stack:
                stack.enter_context(patch.object(mod, 'Probe', RecordedProbe))
                stack.enter_context(patch.object(mod.http.client, 'HTTPSConnection', fixture.connection))
                stack.enter_context(patch.object(mod.time, 'monotonic', lambda: fixture.now))
                stack.enter_context(patch.object(mod.time, 'sleep', fixture.sleep))
                stack.enter_context(patch.object(mod.sys, 'argv', argv))
                stack.enter_context(contextlib.redirect_stdout(stdout))
                exit_code = mod.main()
            raw = output.read_text(encoding='utf-8')
            report = json.loads(raw)
        self.assertEqual(len(report['requests']), len(fixture.calls))
        self.assertEqual(len(fixture.calls), fixture.closed_connections)
        self.assertTrue(all(row['outcome'] in ('received', 'failed', 'uncertain') for row in report['requests']))
        self.assertFalse(any(secret in raw or secret in stdout.getvalue() for secret in fixture.secret_values))
        self.assertFalse(any(user['id'] in raw or user['id'] in stdout.getvalue()
                             for user in fixture.users.values()))
        self.assertNotIn('Private diagnostic', raw)
        self.assertTrue(all(count == 1 for count in fixture.logout_counts.values()))
        self.assertLessEqual(len(fixture.users), 2)
        self.assertLessEqual(sum(m == 'POST' and p == '/api/remix/v1/challenges'
                                 for m, p, token in fixture.calls), 1)
        self.assertLessEqual(sum(m == 'POST' and p == '/api/remix/v2/matches' for m, p, token in fixture.calls), 1)
        self.assertLessEqual(fixture.active_input_posts, 1)
        self.assertEqual(signal.getitimer(signal.ITIMER_REAL), (0.0, 0.0))
        return fixture, report, exit_code
    def assert_unknown_auth(self, scenario):
        fixture, report, exit_code = self.run_fixture(scenario)
        self.assertEqual((exit_code, report['status']), (1, 'FAIL'))
        self.assertTrue(report['authOutcomeUncertain'])
        self.assertFalse(report['allQaSessionsLoggedOut'])
        self.assertEqual(len(fixture.sessions), 1)
        return fixture, report
    def test_default_performs_only_three_gets(self):
        fixture, report, exit_code = self.run_fixture('readonly', False)
        self.assertEqual((exit_code, report['status'], len(report['checks'])), (0, 'PASS', 2))
        self.assertEqual([m for m, p, t in fixture.calls], ['GET', 'GET', 'GET'])
        self.assertEqual((len(fixture.users), len(fixture.sessions)), (0, 0))
    def test_success_is_bounded_and_sanitized(self):
        fixture, report, exit_code = self.run_fixture()
        self.assertEqual((exit_code, report['status'], len(report['checks'])), (0, 'PASS', 13))
        # Polling frequency may change; the record/write bounds must not.
        self.assertLessEqual(len(fixture.calls), 88)
        self.assertEqual((len(fixture.users), len(fixture.issued), len(fixture.sessions)), (2, 4, 0))
        self.assertEqual(sum(m == 'POST' and p == '/api/remix/v1/challenges' for m, p, t in fixture.calls), 1)
        self.assertTrue(report['allQaSessionsLoggedOut'])
        self.assertFalse(report['authOutcomeUncertain'])
        self.assertIn('Creation attempt resolves by GET without repeating POST', report['checks'])
    def test_lost_registration_is_journaled_and_cleanup_uncertain(self):
        fixture, report = self.assert_unknown_auth('lost-register')
        self.assertEqual(report['requests'][-1]['outcome'], 'uncertain')
        self.assertEqual(len(report['requests']), 3)
    def test_lost_login_does_not_claim_all_sessions_closed(self): self.assert_unknown_auth('lost-login')
    def test_secret_auth_error_body_is_not_retained(self): self.assert_unknown_auth('auth-secret-error')
    def test_invalid_auth_json_is_uncertain(self): self.assert_unknown_auth('auth-invalid-json')
    def test_missing_auth_cache_policy_is_uncertain(self): self.assert_unknown_auth('auth-no-store')
    def test_missing_auth_token_is_uncertain(self): self.assert_unknown_auth('auth-missing-token')
    def test_invalid_auth_token_is_uncertain(self): self.assert_unknown_auth('auth-invalid-token')
    def test_auth_clock_expiry_is_uncertain(self):
        fixture, report = self.assert_unknown_auth('auth-clock-expiry')
        self.assertEqual(report['requests'][-1]['outcome'], 'uncertain')
    def test_invalid_identity_still_logs_out_saved_token(self):
        fixture, report, exit_code = self.run_fixture('invalid-login-user')
        self.assertEqual((exit_code, len(fixture.sessions)), (1, 0))
        self.assertTrue(report['allQaSessionsLoggedOut'])
        self.assertFalse(report['authOutcomeUncertain'])
    def test_lost_logout_is_never_repeated_and_is_unconfirmed(self):
        fixture, report, exit_code = self.run_fixture('lost-logout')
        self.assertEqual((exit_code, report['cleanupFailureCount']), (1, 1))
        self.assertFalse(report['allQaSessionsLoggedOut'])
        self.assertFalse(report['authOutcomeUncertain'])
        self.assertEqual(len(fixture.logout_counts), 1)
        self.assertEqual(report['requests'][-1]['outcome'], 'uncertain')
    def test_final_logout_failure_overrides_pass(self):
        fixture, report, exit_code = self.run_fixture('lost-final-logout')
        self.assertEqual(len(report['checks']), 13)
        self.assertEqual((exit_code, report['status'], report['cleanupFailureCount']), (1, 'FAIL', 1))
        self.assertFalse(report['allQaSessionsLoggedOut'])
    def test_lost_match_creation_is_sent_once(self):
        fixture, report, exit_code = self.run_fixture('lost-create')
        self.assertEqual(exit_code, 1)
        attempts = [r for r in report['requests'] if r['method'] == 'POST' and r['path'] == '/api/remix/v2/matches']
        self.assertEqual([r['outcome'] for r in attempts], ['uncertain'])
        self.assertTrue(report['allQaSessionsLoggedOut'])
        self.assertEqual(fixture.active_input_posts, 0)
    def test_lost_accepted_input_is_sent_once(self):
        fixture, report, exit_code = self.run_fixture('lost-owner-input')
        self.assertEqual((exit_code, fixture.active_input_posts), (1, 1))
        self.assertTrue(report['allQaSessionsLoggedOut'])
        attempts = [r for r in report['requests'] if r['method'] == 'POST' and r['path'].startswith('/api/remix/v2/') and r['path'].endswith('/input')]
        self.assertEqual([r['outcome'] for r in attempts], ['uncertain'])
    def test_completed_response_after_monotonic_deadline_fails(self):
        fixture, report, exit_code = self.run_fixture('slow-body', False)
        self.assertEqual((exit_code, report['status']), (1, 'FAIL'))
        self.assertEqual(report['requests'][-1]['outcome'], 'failed')
        self.assertEqual(report['checks'], [])
    def assert_alarm_interrupts(self, stage):
        probe = mod.Probe(False, '')
        probe.deadline = time.monotonic() + .04
        original_handler = signal.getsignal(signal.SIGALRM)
        class Connection:
            closed = False
            def request(self, *args, **kwargs):
                if stage == 'send': time.sleep(1)
            def getresponse(self):
                if stage == 'headers': time.sleep(1)
                def read(size):
                    if stage == 'body': time.sleep(1)
                    return b'{"fixture":true}'
                return types.SimpleNamespace(status=200, read=read, getheader=lambda name, default='': 'application/json' if name == 'Content-Type' else 'no-store')
            def close(self):
                self.closed = True
                if stage == 'close': time.sleep(1)
        connection = Connection()
        def factory(*args, **kwargs):
            if stage == 'connect': time.sleep(1)
            return connection
        def parse(*args, **kwargs): time.sleep(1); return {}
        started = time.monotonic()
        with contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(mod.http.client, 'HTTPSConnection', factory))
            if stage == 'json': stack.enter_context(patch.object(mod.json, 'loads', parse))
            with self.assertRaisesRegex(mod.ProbeFailure, 'whole-request'):
                probe.request('GET', '/api/remix/v2/capabilities')
        self.assertLess(time.monotonic() - started, .6)
        self.assertEqual(probe.report['requests'][0]['outcome'], 'failed')
        self.assertEqual(signal.getitimer(signal.ITIMER_REAL), (0.0, 0.0))
        self.assertIs(signal.getsignal(signal.SIGALRM), original_handler)
        if stage != 'connect': self.assertTrue(connection.closed)
    def test_alarm_interrupts_connection_construction(self): self.assert_alarm_interrupts('connect')
    def test_alarm_interrupts_send(self): self.assert_alarm_interrupts('send')
    def test_alarm_interrupts_headers(self): self.assert_alarm_interrupts('headers')
    def test_alarm_interrupts_body(self): self.assert_alarm_interrupts('body')
    def test_alarm_interrupts_json_parse(self): self.assert_alarm_interrupts('json')
    def test_alarm_interrupts_close(self): self.assert_alarm_interrupts('close')
    def test_prior_handler_and_timer_are_restored_without_time_extension(self):
        previous_handler = signal.getsignal(signal.SIGALRM)
        previous_timer = signal.getitimer(signal.ITIMER_REAL)
        fired = []
        def caller_handler(signum, frame): fired.append(True)
        try:
            signal.signal(signal.SIGALRM, caller_handler)
            signal.setitimer(signal.ITIMER_REAL, .5, .4)
            with mod.request_timeout(.1): time.sleep(.025)
            remaining, interval = signal.getitimer(signal.ITIMER_REAL)
            self.assertIs(signal.getsignal(signal.SIGALRM), caller_handler)
            self.assertGreater(remaining, .35)
            self.assertLess(remaining, .49)
            self.assertEqual(interval, .4)
            self.assertEqual(fired, [])
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, previous_handler)
            if previous_timer[0]: signal.setitimer(signal.ITIMER_REAL, *previous_timer)

if __name__ == '__main__': unittest.main(verbosity=2)
