import copy
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import secrets
import sys
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'server'))
import core_commerce
from core_server import create_server
from core_model import Fault
import remix_service as remix
from remix_acceptance import Actor, complete, exercise, register


class SimulationTests(unittest.TestCase):
    def test_seeded_level_is_stable_walkable_and_changes_with_seed(self):
        self.assertEqual(remix.arena(42), remix.arena(42))
        self.assertNotEqual(remix.arena(42), remix.arena(43))
        for seed in (1, 42, 20261017, 2147483647):
            self.assertTrue(remix.reachable(remix.arena(seed)['objects']))

    def test_hazard_reset_and_jump_are_computed_from_geometry(self):
        level = remix.arena(1, [dict(id='hazard', kind='hazard', x=1, y=3), dict(id='goal', kind='goal', x=2, y=3)])
        state = remix.advance(level, remix.initial_state(), dict(sequence=1, moveX=1, moveY=0, jump=False))
        self.assertEqual((state['position'], state['falls'], state['timeMs']), ([0, 3], 1, 1600))
        state = remix.advance(level, state, dict(sequence=2, moveX=1, moveY=0, jump=True))
        self.assertTrue(state['finished'] and state['won'])
        self.assertEqual(state['timeMs'], 1800)

    def test_jump_cannot_cross_platform(self):
        level = remix.arena(1, [dict(id='wall', kind='platform', x=1, y=3), dict(id='goal', kind='goal', x=3, y=3)])
        state = remix.advance(level, remix.initial_state(), dict(sequence=1, moveX=1, moveY=0, jump=True))
        self.assertEqual((state['position'], state['blocked']), ([0, 3], 1))

    def test_step_limit_finishes_with_zero_score(self):
        level, state = remix.arena(1), remix.initial_state()
        for sequence in range(1, remix.MAX_INPUTS + 1):
            state = remix.advance(level, state, dict(sequence=sequence, moveX=-1, moveY=0, jump=False))
        self.assertEqual(remix.result_values(state)['score'], 0)
        self.assertTrue(state['finished'])
        with self.assertRaises(Fault):
            remix.advance(level, state, dict(sequence=257, moveX=1, moveY=0, jump=False))

    def test_invalid_arena_objects_fail_before_play(self):
        examples = [[], [dict(id='goal', kind='goal', x=True, y=3)], [dict(id='goal', kind='goal', x=0, y=3)], [dict(id='goal', kind='goal', x=12, y=3)], [dict(id='goal', kind='goal', x=2.5, y=3)], [dict(id='goal', kind='goal', x=2, y=3), dict(id='wall', kind='platform', x=2, y=3)]]
        for objects in examples:
            with self.subTest(objects=objects), self.assertRaises(Fault):
                remix.arena(1, objects)


class HttpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory(prefix='osgard-remix-tests-')
        cls.root = Path(cls.scratch.name) / 'public'
        cls.root.mkdir()
        (cls.root / 'index.html').write_text('<!doctype html><title>Isolated acceptance</title>')
        cls.database = Path(cls.scratch.name) / 'remix.sqlite3'
        cls.start_server()
        cls.alice, cls.bob = register(cls.base), register(cls.base)

    @classmethod
    def start_server(cls):
        cls.server = create_server(cls.root, cls.database, port=0, commerce_config=core_commerce.Config(enabled=False), enable_remix=True)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = 'http://127.0.0.1:' + str(cls.server.server_address[1])

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.thread.join(5)
        cls.server.server_close()
        cls.scratch.cleanup()

    def challenge(self, **changes):
        return self.alice.request('challenges', dict(dict(title='Owned challenge', seed=42, visibility='public'), **changes))

    def match(self):
        return self.alice.request('matches', dict(challengeId=self.challenge()['id'], maxPlayers=1))

    def test_complete_two_actor_http_contract(self):
        report, _, _ = exercise(self.base, self.alice, self.bob)
        self.assertEqual((report['status'], report['failed']), ('passed', 0))
        self.assertGreaterEqual(report['passed'], 16)

    def test_service_is_opt_in_and_core_default_still_works(self):
        with tempfile.TemporaryDirectory(prefix='osgard-remix-disabled-') as temporary:
            server = create_server(self.root, Path(temporary) / 'core.sqlite3', port=0, commerce_config=core_commerce.Config(enabled=False))
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                actor = Actor('http://127.0.0.1:' + str(server.server_address[1]))
                self.assertEqual(actor.request('capabilities', expected=404)['error'], 'remix_disabled')
                self.assertEqual(actor.request('/api/core/health')['status'], 'ok')
                with server.store.connect() as db:
                    self.assertIsNone(db.execute("SELECT name FROM sqlite_master WHERE name='remix_challenges'").fetchone())
            finally:
                server.shutdown()
                thread.join(5)
                server.server_close()

    def test_arena_namespace_never_claims_legacy_match_routes(self):
        self.assertEqual(Actor(self.base).request('/api/core/remix/v1/capabilities')['ruleset'], remix.RULESET)
        with self.server.store.connect() as db:
            before = db.execute('SELECT COUNT(*) FROM remix_challenges').fetchone()[0]
        for actor in (Actor(self.base), self.alice):
            with self.subTest(authenticated=bool(actor.token)):
                self.assertEqual(actor.request('/api/remix/v1/capabilities', expected=404)['error'], 'not_found')
                self.assertEqual(actor.request('/api/remix/v1/challenges', dict(title='Reserved legacy route', seed=42), expected=404)['error'], 'not_found')
        with self.server.store.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM remix_challenges').fetchone()[0], before)

    def test_failed_mutations_leave_no_sqlite_rows(self):
        with self.server.store.connect() as db:
            before = db.execute('SELECT COUNT(*) FROM remix_challenges').fetchone()[0]
        for changes in ({'seed': True}, {'seed': 0}, {'seed': 1.5}, {'score': 999}, {'objects': []}, {'creatorId': self.bob.user['id']}):
            self.alice.request('challenges', dict(dict(title='Invalid challenge', seed=42), **changes), expected=403 if 'creatorId' in changes else 400)
        with self.server.store.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM remix_challenges').fetchone()[0], before)

    def test_invalid_identifiers_are_validation_errors(self):
        for identifier in (None, [], {}, 42, '../challenge'):
            self.alice.request('matches', dict(challengeId=identifier), expected=400)

    def test_sequence_validation_never_advances_state(self):
        run = self.match()
        for changes in ({'sequence': True}, {'sequence': 0}, {'sequence': 257}, {'moveX': 2}, {'moveX': float('inf')}, {'moveY': 1}, {'jump': 1}, {'position': [11, 3]}):
            if changes.get('moveX') == float('inf'):
                continue  # Non-finite raw JSON is covered by the shared Core body gate.
            self.alice.request('matches/' + run['id'] + '/input', dict(dict(sequence=1, moveX=1, moveY=0, jump=False), **changes), expected=400)
        self.assertEqual(self.alice.request('matches/' + run['id'] + '/state')['sequence'], 0)

    def test_concurrent_duplicate_input_is_committed_once(self):
        run, key = self.match(), secrets.token_hex(16)
        payload = dict(sequence=1, moveX=1, moveY=0, jump=False)
        with ThreadPoolExecutor(max_workers=2) as pool:
            values = list(pool.map(lambda _: self.alice.request('matches/' + run['id'] + '/input', payload, key=key), range(2)))
        self.assertEqual([value['state']['sequence'] for value in values], [1, 1])
        self.assertEqual(sum(bool(value['replayed']) for value in values), 1)
        with self.server.store.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM remix_inputs WHERE match_id=?', (run['id'],)).fetchone()[0], 1)

    def test_same_key_with_reordered_json_is_a_retry(self):
        key = secrets.token_hex(16)
        first = self.alice.request('challenges', dict(title='Stable request', seed=73), key=key)
        repeated = self.alice.request('challenges', dict(seed=73, title='Stable request'), key=key)
        self.assertEqual(first['id'], repeated['id'])
        self.assertTrue(repeated['replayed'])

    def test_operation_keys_are_scoped_to_real_actor(self):
        key, body = secrets.token_hex(16), dict(title='Independent actor', seed=71)
        alice = self.alice.request('challenges', body, key=key)
        bob = self.bob.request('challenges', body, key=key)
        self.assertNotEqual(alice['id'], bob['id'])
        self.assertEqual(bob['creatorId'], self.bob.user['id'])

    def test_origin_guard_rejects_even_authenticated_writes(self):
        self.alice.request('challenges', dict(title='Foreign origin', seed=42), headers={'Origin': 'https://example.invalid'}, expected=403)

    def test_single_actor_capability_does_not_claim_live_multiplayer(self):
        self.assertEqual(Actor(self.base).request('capabilities')['playersPerMatch'], 1)
        self.alice.request('matches', dict(challengeId=self.challenge()['id'], maxPlayers=2), expected=409)

    def test_private_published_challenge_stays_owner_only(self):
        challenge = self.challenge(visibility='private')
        run = self.alice.request('matches', dict(challengeId=challenge['id']))
        complete(self.alice, run)
        self.alice.request('challenges/' + challenge['id'] + '/validate', dict(matchId=run['id']))
        self.alice.request('challenges/' + challenge['id'] + '/publish', {})
        self.bob.request('challenges/' + challenge['id'], expected=404)

    def test_own_proof_for_other_challenge_is_rejected(self):
        run, other = self.match(), self.challenge()
        complete(self.alice, run)
        self.alice.request('challenges/' + other['id'] + '/validate', dict(matchId=run['id']), expected=409)

    def test_publish_rejects_a_corrupted_cross_challenge_proof_link(self):
        proofs = []
        for title in ('First proof', 'Second proof'):
            challenge = self.challenge(title=title, objects=[dict(id='goal', kind='goal', x=1, y=3)])
            run = self.alice.request('matches', dict(challengeId=challenge['id']))
            complete(self.alice, run)
            self.alice.request('challenges/' + challenge['id'] + '/validate', dict(matchId=run['id']))
            proofs.append((challenge, run))
        target = proofs[1][0]
        # Both journals are valid and owned by the same actor. SQLite integrity
        # alone does not prove that the saved proof belongs to this challenge.
        with self.server.store.transaction() as db:
            db.execute('UPDATE remix_challenges SET proof_match_id=? WHERE id=?', (proofs[0][1]['id'], target['id']))
            self.assertEqual(db.execute('PRAGMA foreign_key_check').fetchall(), [])
        response = self.alice.request('challenges/' + target['id'] + '/publish', {}, expected=409)
        self.assertEqual(response['error'], 'proof_required')
        self.assertEqual(self.alice.request('challenges/' + target['id'])['status'], 'VALIDATED')

    def test_replay_resimulation_rejects_changed_inputs_even_with_new_hash(self):
        _, replay = complete(self.alice, self.match())
        forged = copy.deepcopy(replay)
        forged['inputs'][0]['moveX'] = -1
        forged['hash'] = remix.checksum({key: value for key, value in forged.items() if key != 'hash'})
        with self.assertRaises(Fault):
            remix.verify_replay(forged)

    def test_database_replay_corruption_is_not_served_as_verified(self):
        run = self.match()
        complete(self.alice, run)
        with self.server.store.transaction() as db:
            entry = db.execute('SELECT checkpoint_json FROM remix_inputs WHERE match_id=? AND sequence=1', (run['id'],)).fetchone()
            changed = json.loads(entry['checkpoint_json'])
            changed['state']['position'] = [11, 3]
            db.execute('UPDATE remix_inputs SET checkpoint_json=? WHERE match_id=? AND sequence=1', (json.dumps(changed), run['id']))
        self.assertEqual(self.alice.request('matches/' + run['id'] + '/replay', expected=503)['error'], 'replay_integrity')

    def test_result_payload_and_final_state_corruption_are_not_served(self):
        for field in ('playerId', 'scores', 'ruleset', 'final-state'):
            with self.subTest(field=field):
                run = self.match()
                complete(self.alice, run)
                with self.server.store.transaction() as db:
                    row = db.execute('SELECT result_json,state_json FROM remix_matches WHERE id=?', (run['id'],)).fetchone()
                    result, state = json.loads(row['result_json']), json.loads(row['state_json'])
                    if field == 'final-state':
                        state['position'] = [0, 0]
                    elif field == 'scores':
                        result['scores'][0]['score'] = 999999
                    else:
                        result[field] = 'changed-stored-value'
                    db.execute('UPDATE remix_matches SET result_json=?,state_json=? WHERE id=?', (json.dumps(result), json.dumps(state), run['id']))
                self.assertEqual(self.alice.request('matches/' + run['id'] + '/result', expected=503)['error'], 'replay_integrity')

    def test_leaderboard_selects_best_run_and_verifies_its_journal(self):
        challenge = self.challenge(objects=[dict(id='goal', kind='goal', x=2, y=3)])
        proof = self.alice.request('matches', dict(challengeId=challenge['id']))
        complete(self.alice, proof)
        self.alice.request('challenges/' + challenge['id'] + '/validate', dict(matchId=proof['id']))
        self.alice.request('challenges/' + challenge['id'] + '/publish', {})
        slow = self.bob.request('matches', dict(challengeId=challenge['id']))
        blocked = self.bob.request('matches/' + slow['id'] + '/input', dict(sequence=1, moveX=-1, moveY=0))
        slow_result, _ = complete(self.bob, blocked['state'])
        fast = self.bob.request('matches', dict(challengeId=challenge['id']))
        fast_result, _ = complete(self.bob, fast)
        board = self.alice.request('challenges/' + challenge['id'] + '/leaderboard')
        self.assertEqual(len(board['scores']), 1)
        self.assertEqual(board['scores'][0]['matchId'], fast['id'])
        self.assertLess(fast_result['timeMs'], slow_result['timeMs'])
        with self.server.store.transaction() as db:
            row = db.execute('SELECT result_json FROM remix_matches WHERE id=?', (fast['id'],)).fetchone()
            result = json.loads(row['result_json'])
            result['scores'][0]['score'] = 999999
            db.execute('UPDATE remix_matches SET result_json=? WHERE id=?', (json.dumps(result), fast['id']))
        self.assertEqual(self.alice.request('challenges/' + challenge['id'] + '/leaderboard', expected=503)['error'], 'replay_integrity')

    def test_restart_preserves_auth_result_replay_and_publication(self):
        challenge = self.challenge()
        run = self.alice.request('matches', dict(challengeId=challenge['id']))
        result, replay = complete(self.alice, run)
        self.alice.request('challenges/' + challenge['id'] + '/validate', dict(matchId=run['id']))
        self.alice.request('challenges/' + challenge['id'] + '/publish', {})
        self.server.shutdown()
        self.thread.join(5)
        self.server.server_close()
        type(self).start_server()
        self.alice.base = self.base
        self.bob.base = self.base
        self.assertEqual(self.alice.request('matches/' + run['id'] + '/replay'), replay)
        self.assertEqual(self.alice.request('matches/' + run['id'] + '/result'), result)
        self.assertEqual(self.bob.request('challenges/' + challenge['id'])['status'], 'PUBLISHED')

    def test_revoked_session_cannot_mutate_remix(self):
        actor = register(self.base)
        actor.request('/api/core/auth/logout', {})
        actor.request('challenges', dict(title='Revoked session', seed=42), expected=401)


if __name__ == '__main__':
    unittest.main()
