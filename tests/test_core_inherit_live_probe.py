"""The opt-in live probe has bounded, credential-safe, non-retrying transport."""
import importlib.util
import http.client
import io
import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('inherit_live_contract', ROOT / 'scripts/core-inherit-live-smoke.py')
probe_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe_module)


class Response:
    def __init__(self, status=200, value=None, raw=None, cache='no-store'):
        self.status, self.cache = status, cache
        self.raw = raw if raw is not None else json.dumps(value or {}).encode()

    def read(self, limit):
        return self.raw[:limit]

    def getheader(self, name, default=''):
        return {'Content-Type': 'application/json', 'Cache-Control': self.cache}.get(name, default)


class FakeConnection:
    def __init__(self, response=None, error=None):
        self.response, self.error = response or Response(), error
        self.sent, self.closed = [], False

    def request(self, method, path, body=None, headers=None):
        self.sent.append((method, path, body, headers))
        if self.error:
            raise self.error

    def getresponse(self):
        return self.response

    def close(self):
        self.closed = True


class LiveProbeTest(unittest.TestCase):
    def probe(self, response=None, error=None):
        connection = FakeConnection(response, error)
        calls = []
        def factory(host, *, timeout):
            calls.append((host, timeout))
            return connection
        return probe_module.Probe(factory), connection, calls

    def test_transport_never_retries_uncertain_post_or_records_credentials(self):
        probe, connection, calls = self.probe(error=OSError('synthetic drop'))
        token = 'private-fixture-token'
        with self.assertRaises(OSError):
            probe.request('POST', probe_module.API + 'worlds', token=token, key='operation-fixture', body={'title': 'private payload'})
        self.assertEqual(len(calls), 1)
        self.assertEqual(len(connection.sent), 1)
        self.assertTrue(connection.closed)
        self.assertEqual(probe.report['requests'][0]['outcome'], 'uncertain')
        evidence = json.dumps(probe.report)
        self.assertNotIn(token, evidence)
        self.assertNotIn('private payload', evidence)

    def test_credentials_cannot_reach_any_other_route(self):
        for route in ('/api/remix/v2/matches', '/api/core/auth/register', '/outside', '/api/core/inherit/v1/worlds?redirect=bad'):
            with self.subTest(route=route):
                probe, connection, calls = self.probe()
                with self.assertRaises(probe_module.ProbeFailure):
                    probe.request('GET', route, token='fixture')
                self.assertEqual(calls, [])
                self.assertEqual(connection.sent, [])

    def test_bad_json_cache_or_oversized_body_is_rejected_without_retry(self):
        for response in (Response(raw=b'bad-json'), Response(raw=b'{"number": NaN}'), Response(cache='public'),
                         Response(raw=b'x' * 1_048_577), Response(status=503)):
            probe, connection, calls = self.probe(response)
            with self.assertRaises((ValueError, probe_module.ProbeFailure)):
                probe.request('GET', probe_module.API + 'worlds')
            self.assertEqual(len(calls), 1)
            self.assertTrue(connection.closed)

    def test_request_and_deadline_limits_precede_dispatch(self):
        probe, connection, calls = self.probe()
        probe.report['requests'] = [{}] * 72
        with self.assertRaises(probe_module.ProbeFailure):
            probe.request('GET', probe_module.API + 'worlds')
        self.assertEqual(calls, [])
        probe.report['requests'] = []
        probe.deadline = 0
        with self.assertRaises(probe_module.ProbeFailure):
            probe.request('GET', probe_module.API + 'worlds')
        self.assertEqual(calls, [])

    def test_uncertain_logout_is_attempted_once_and_keeps_failed_cleanup_status(self):
        probe, connection, calls = self.probe(error=OSError('synthetic drop'))
        probe.tokens.append('fixture')
        probe.cleanup()
        probe.cleanup()
        self.assertEqual(len(calls), 1)
        self.assertFalse(probe.report['allQaSessionsLoggedOut'])
        self.assertEqual(probe.report['status'], 'FAIL')

    def test_unknown_registration_token_is_not_claimed_logged_out(self):
        probe, connection, calls = self.probe(Response(value={'token': 'invalid'}))
        with self.assertRaises(probe_module.ProbeFailure):
            probe.account('fixture')
        self.assertTrue(probe.report['authOutcomeUncertain'])
        probe.cleanup()
        self.assertFalse(probe.report['allQaSessionsLoggedOut'])

    def test_registered_qa_identity_must_match_username_and_verified_session(self):
        username = 'qa_inherit_fixture_' + 'd' * 16
        user = {'id': 'a' * 32, 'username': username}
        for registered, verified in ((dict(user, username='another-user'), user),
                                      (user, dict(user, id='b' * 32)),
                                      (user, dict(user, username='another-user'))):
            with self.subTest(registered=registered, verified=verified):
                probe, _, _ = self.probe()
                token = 'c' * 48
                with patch.object(probe_module.secrets, 'token_hex', return_value='d' * 16), \
                        patch.object(probe, 'request', side_effect=[{'token': token, 'user': registered}, {'user': verified}]) as request:
                    with self.assertRaises(probe_module.ProbeFailure):
                        probe.account('fixture')
                self.assertEqual(probe.tokens, [token])
                self.assertFalse(probe.report['authOutcomeUncertain'])
                self.assertTrue(all(call.args[1] in ('/api/core/auth/register', '/api/core/auth/me') for call in request.call_args_list))

    def test_same_qa_actor_or_session_stops_before_any_world_write(self):
        for accounts in ((('a' * 48, '1' * 32), ('b' * 48, '1' * 32)),
                         (('a' * 48, '1' * 32), ('a' * 48, '2' * 32))):
            probe, _, calls = self.probe()
            with patch.object(probe, 'account', side_effect=accounts):
                with self.assertRaises(probe_module.ProbeFailure):
                    probe_module.exercise(probe)
            self.assertEqual(calls, [])

    def test_false_or_missing_logout_confirmation_cannot_claim_cleanup_success(self):
        for response in (Response(value={'loggedOut': False}), Response(value={}), Response(value={'loggedOut': 1})):
            probe, _, calls = self.probe(response)
            probe.tokens.append('fixture')
            probe.cleanup()
            probe.cleanup()
            self.assertEqual(len(calls), 1)
            self.assertFalse(probe.report['allQaSessionsLoggedOut'])
            self.assertEqual(probe.report['status'], 'FAIL')
        for response in (Response(value={'loggedOut': True}), Response(status=401, value={'error': 'auth'})):
            probe, _, _ = self.probe(response)
            probe.tokens.append('fixture')
            probe.cleanup()
            self.assertTrue(probe.report['allQaSessionsLoggedOut'])

    def test_live_write_flag_requires_exact_release_before_proxy_or_network(self):
        with patch.object(sys, 'argv', ['probe', '--exercise-inherit']), patch.object(probe_module.transport, 'runtime_proxy') as network:
            with self.assertRaises(probe_module.ProbeFailure):
                probe_module.main()
            network.assert_not_called()

    def test_default_run_is_read_only(self):
        calls = []
        def request(self, method, path, **kwargs):
            calls.append((method, path))
            return 'a' * 12 if path == '/' else {'status': 'ok'}
        with patch.object(sys, 'argv', ['probe']), patch.object(probe_module.transport, 'runtime_proxy', return_value=None), \
                patch.object(probe_module.Probe, 'request', request), patch('sys.stdout', new_callable=io.StringIO):
            self.assertEqual(probe_module.main(), 0)
        self.assertEqual(calls, [('GET', '/'), ('GET', '/api/core/health'), ('GET', '/')])

    def test_complete_probe_against_real_isolated_core_http(self):
        sys.path.insert(0, str(ROOT / 'server'))
        from core_server import create_server
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            public = directory / 'public'
            public.mkdir()
            server = create_server(public, directory / 'private.sqlite3', port=0, public_origin='https://osgard.world')
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            class Connection(http.client.HTTPConnection):
                def request(self, method, path, body=None, headers=None):
                    return super().request(method, path, body, {**(headers or {}), 'Host': 'osgard.world'})
            def factory(host, *, timeout):
                self.assertEqual(host, 'osgard.world')
                return Connection(*server.server_address, timeout=timeout)
            probe = probe_module.Probe(factory)
            try:
                probe_module.exercise(probe)
                probe.report['status'] = 'PASS'
                probe.cleanup()
                self.assertTrue(probe.report['allQaSessionsLoggedOut'])
                self.assertEqual(len(probe.tokens), 2)
                self.assertEqual(len(probe.report['generations']), 2)
                self.assertGreaterEqual(len(probe.report['checks']), 12)
                with server.store.connect() as db:
                    self.assertEqual(db.execute('SELECT COUNT(*) FROM sessions').fetchone()[0], 0)
                    self.assertEqual(db.execute('SELECT COUNT(*) FROM inherit_worlds').fetchone()[0], 1)
                    self.assertEqual(db.execute('SELECT COUNT(*) FROM inherit_generations').fetchone()[0], 2)
            finally:
                probe.cleanup()
                server.shutdown()
                server.server_close()
                thread.join(timeout=3)


if __name__ == '__main__':
    unittest.main()
