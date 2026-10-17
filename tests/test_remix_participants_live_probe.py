"""Safety and actual isolated Core/guard execution of the participant live probe."""
import http.client
import importlib.util
import io
import json
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


probe_module = load('participant_live_probe_tests', 'scripts/remix-participants-live-smoke.py')
transport_fixture = load('participant_probe_memory_fixture', 'tests/test_core_inherit_live_probe.py')


class ParticipantProbeTest(unittest.TestCase):
    def test_write_flag_requires_pin_before_proxy_or_network(self):
        with patch.object(sys, 'argv', ['probe', '--exercise-participants']), \
                patch.object(probe_module.transport, 'runtime_proxy') as network:
            with self.assertRaises(probe_module.ProbeFailure):
                probe_module.main()
        network.assert_not_called()

    def test_readonly_default_makes_three_gets(self):
        calls = []
        def request(self, method, path, **kwargs):
            calls.append((method, path))
            return 'a' * 12 if path == '/' else dict(authPolicyVersion=1, provider='core', ownershipPolicy='confirmed-durable-binding')
        with patch.object(sys, 'argv', ['probe']), patch.object(probe_module.transport, 'runtime_proxy', return_value=None), \
                patch.object(probe_module.Probe, 'request', request), patch('sys.stdout', new_callable=io.StringIO):
            self.assertEqual(probe_module.main(), 0)
        self.assertEqual(calls, [('GET', '/'), ('GET', probe_module.V2 + 'capabilities'), ('GET', '/')])

    def test_disabled_admission_stops_before_creating_accounts(self):
        def request(self, method, path, **kwargs):
            return 'a' * 12 if path == '/' else dict(authPolicyVersion=1, provider='core', ownershipPolicy='confirmed-durable-binding',
                creationEnabled=True, participantPolicyVersion=1, participantAdmissionEnabled=False, maxParticipants=2)
        with patch.object(sys, 'argv', ['probe', '--exercise-participants', '--expected-release', 'a' * 12]), \
                patch.object(probe_module.transport, 'runtime_proxy', return_value=None), \
                patch.object(probe_module.Probe, 'request', request), patch.object(probe_module.Probe, 'account') as account, \
                patch('sys.stdout', new_callable=io.StringIO):
            self.assertEqual(probe_module.main(), 1)
        account.assert_not_called()

    def test_invalid_routes_never_dispatch_credentials(self):
        probe = probe_module.Probe()
        factory = unittest.mock.Mock()
        with patch.object(probe_module.base, 'http', types.SimpleNamespace(client=types.SimpleNamespace(HTTPSConnection=factory))):
            for path in ('https://another.test/', '//another.test/', '/api/core/auth/login', '/api/core/inherit/v1/worlds',
                         '/api/remix/v2/matches?token=value', '/api/remix/v2/invitations/inv_' + 'a' * 32 + '/../accept'):
                with self.subTest(path=path), self.assertRaises(probe_module.ProbeFailure):
                    probe.request('GET', path, token='private-token')
        factory.assert_not_called()

    def test_lost_post_is_not_retried_or_logged_with_credentials(self):
        probe = probe_module.Probe()
        connection = transport_fixture.FakeConnection(error=OSError('drop'))
        factory = unittest.mock.Mock(return_value=connection)
        with patch.object(probe_module.base, 'http', types.SimpleNamespace(client=types.SimpleNamespace(HTTPSConnection=factory))):
            with self.assertRaises(OSError):
                probe.request('POST', probe_module.V2 + 'matches', token='private-token', key='a' * 32, body={'private': 'payload'})
        self.assertEqual(factory.call_count, 1)
        self.assertEqual(len(connection.sent), 1)
        self.assertTrue(connection.closed)
        self.assertEqual(probe.report['requests'][0]['outcome'], 'uncertain')
        self.assertNotIn('private-token', json.dumps(probe.report))
        self.assertNotIn('payload', json.dumps(probe.report))

    def test_verified_identity_and_retained_token_precede_game_writes(self):
        username = 'qa_participant_owner_' + 'd' * 16
        actor = dict(id='a' * 32, username=username)
        for registered, verified in ((dict(actor, username='wrong-user'), actor), (actor, dict(actor, id='b' * 32)),
                                     (actor, dict(actor, username='wrong-user'))):
            probe = probe_module.Probe()
            with patch.object(probe_module.secrets, 'token_hex', return_value='d' * 16), \
                    patch.object(probe, 'request', side_effect=[{'user': registered, 'token': 'c' * 48}, {'user': verified}]):
                with self.assertRaises(probe_module.ProbeFailure):
                    probe.account('owner')
            self.assertEqual(probe.tokens, ['c' * 48])
            self.assertFalse(probe.report['authOutcomeUncertain'])

    def test_same_accounts_or_tokens_stop_before_challenge_write(self):
        for accounts in ((('a' * 48, '1' * 32), ('b' * 48, '1' * 32)), (('a' * 48, '1' * 32), ('a' * 48, '2' * 32))):
            probe = probe_module.Probe()
            with patch.object(probe, 'account', side_effect=accounts), patch.object(probe, 'request') as request:
                with self.assertRaises(probe_module.ProbeFailure):
                    probe.exercise()
            request.assert_not_called()

    def test_false_logout_and_unknown_auth_never_claim_cleanup_success(self):
        for response in ({'loggedOut': False}, {'loggedOut': 1}, {}):
            probe = probe_module.Probe()
            probe.tokens.append('fixture-token')
            probe.report['requests'].append({'status': 200})
            with patch.object(probe, 'request', return_value=response) as request:
                probe.cleanup()
                probe.cleanup()
            self.assertEqual(request.call_count, 1)
            self.assertFalse(probe.report['allQaSessionsLoggedOut'])
        probe = probe_module.Probe()
        probe.report['authOutcomeUncertain'] = True
        probe.cleanup()
        self.assertFalse(probe.report['allQaSessionsLoggedOut'])

    def test_acceptance_for_another_invitation_cannot_be_reported_as_our_join(self):
        probe = probe_module.Probe()
        owner_id, member_id = '1' * 32, '2' * 32
        invitation = dict(id='inv_' + 'a' * 32, matchId='match_qa', challengeId='ch_qa', recipientAccountId=member_id,
                          role='owner', status='pending')
        match = dict(id='match_qa', challengeId='ch_qa', playerId='player_owner', role='owner', accessMode='core-owned',
                     participantCount=1, maxParticipants=2, highestSubmittedSequence=0)
        calls = []
        def request(method, path, **kwargs):
            calls.append((method, path))
            if kwargs.get('expected') in (401, 403):
                return {'error': 'fixture-denied'}
            if path.endswith('/challenges'):
                return {'id': 'ch_qa'}
            if path == probe_module.V2 + 'matches':
                return match
            if path.endswith('/invitations'):
                return dict(operation='invite', operationKey=kwargs['key'], status='ready', invitation=invitation)
            if method == 'GET' and '/invitations/' in path:
                return dict(invitation, role='recipient', admissionAllowed=True)
            if path.endswith('/accept'):
                return dict(operation='accept', operationKey=kwargs['key'], status='ready',
                            invitation=dict(invitation, id='inv_' + 'b' * 32, role='recipient', status='accepted'),
                            match=dict(match, playerId='player_member', role='participant', participantCount=2))
            raise AssertionError('The mismatched acceptance must stop before any further request')
        with patch.object(probe, 'account', side_effect=[('owner-token', owner_id), ('member-token', member_id)]), \
                patch.object(probe, 'request', request):
            with self.assertRaisesRegex(probe_module.ProbeFailure, 'distinct second player'):
                probe.exercise()
        self.assertTrue(calls[-1][1].endswith('/accept'))
        self.assertNotIn('participantPlayerId', probe.report['match'])

    def test_exact_probe_exercise_on_real_isolated_core_and_participant_guard(self):
        fixture = load('participant_live_full_fixture', 'tests/test_remix_participants.py')
        fixture.ParticipantTests.setUpClass()
        self.addCleanup(fixture.ParticipantTests.tearDownClass)
        context = fixture.ParticipantTests('test_invitation_reference_is_not_a_capability_or_automatic_join')
        context.setUp()
        self.addCleanup(context.tearDown)
        class Connection:
            def __init__(self, host, *, timeout):
                if host != 'osgard.world':
                    raise AssertionError('Nonfixed QA origin')
                self.timeout, self.actual = timeout, None

            def request(self, method, path, body=None, headers=None):
                if path.startswith('/api/core/'):
                    port, routed = context.core_port, path
                else:
                    port, routed = context.port, path.removeprefix('/api/remix')
                    if method == 'GET' and routed.endswith('/state'):
                        for identifier in context.legacy.created:
                            if context.legacy.input_count == 2:
                                context.legacy.terminal(identifier)
                            else:
                                context.legacy.playing(identifier)
                self.actual = http.client.HTTPConnection('127.0.0.1', port, timeout=self.timeout)
                self.actual.request(method, routed, body, {**(headers or {}), 'Host': 'osgard.world'})

            def getresponse(self):
                return self.actual.getresponse()

            def close(self):
                if self.actual:
                    self.actual.close()

        probe = probe_module.Probe(exercise=True)
        with patch.object(probe_module.base, 'http', types.SimpleNamespace(client=types.SimpleNamespace(HTTPSConnection=Connection))):
            try:
                probe.exercise()
            finally:
                probe.cleanup()
        self.assertTrue(probe.report['allQaSessionsLoggedOut'])
        self.assertEqual(len(probe.tokens), 2)
        self.assertEqual(len(context.legacy.created), 1)
        self.assertEqual(context.legacy.input_count, 2)
        self.assertEqual(probe.report['result']['replayFrames'], 2)
        self.assertEqual(len(probe.report['result']['scores']), 2)
        self.assertEqual(len(probe.report['checks']), 12)
        self.assertLess(len(probe.report['requests']), 88)
        self.assertTrue(all(row['outcome'] == 'received' for row in probe.report['requests']))
        with context.core.store.connect() as db:
            for token in probe.tokens:
                self.assertIsNone(db.execute('SELECT 1 FROM sessions WHERE token_hash=?', (fixture.fixture.core_server.digest(token),)).fetchone())


if __name__ == '__main__':
    unittest.main()
