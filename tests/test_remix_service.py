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

    def active_fixture(self, challenge=None):
        if challenge is None:
            if not hasattr(type(self), 'prefix_challenge'):
                type(self).prefix_challenge = self.challenge(objects=[dict(id='goal', kind='goal', x=11, y=3)])
            challenge = self.prefix_challenge
        run = self.alice.request('matches', dict(challengeId=challenge['id']))
        key = secrets.token_hex(16)
        intent = dict(sequence=1, moveX=1, moveY=0, jump=False)
        response = self.alice.request('matches/' + run['id'] + '/input', intent, key=key)
        return response['state'], key, intent, response

    def persisted_run(self, identifier):
        with self.server.store.connect() as db:
            return (
                tuple(db.execute('SELECT * FROM remix_matches WHERE id=?', (identifier,)).fetchone()),
                [tuple(row) for row in db.execute('SELECT * FROM remix_inputs WHERE match_id=? ORDER BY sequence', (identifier,))],
                [tuple(row) for row in db.execute('SELECT * FROM remix_operations WHERE actor_id=? ORDER BY operation_key', (self.alice.user['id'],))],
            )

    def assert_prefix_rejected(self, run, key, intent):
        before = self.persisted_run(run['id'])
        path = 'matches/' + run['id']
        self.assertEqual(self.alice.request(path + '/state', expected=503)['error'], 'replay_integrity')
        for payload, operation_key in ((dict(intent, sequence=2), None), (intent, key), (intent, None)):
            value = self.alice.request(path + '/input', payload, key=operation_key, expected=503)
            self.assertEqual(value['error'], 'replay_integrity')
        self.assertEqual(self.persisted_run(run['id']), before, 'Rejected restoration/input must not change any durable row')

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

    def test_active_snapshot_corruption_blocks_reads_new_input_and_both_retry_paths(self):
        changes = {
            'position': lambda value: dict(value, position=[7, 3]),
            'sequence': lambda value: dict(value, sequence=0),
            'step-count': lambda value: dict(value, steps=8),
            'finished': lambda value: dict(value, finished=True),
            'extra-field': lambda value: dict(value, invented=True),
            'missing-field': lambda value: {key: item for key, item in value.items() if key != 'falls'},
            'integer-as-boolean': lambda value: dict(value, sequence=True),
            'integer-as-float': lambda value: dict(value, steps=1.0),
            'non-finite': lambda value: dict(value, timeMs=float('nan')),
        }
        for name, change in changes.items():
            with self.subTest(name=name):
                run, key, intent, _ = self.active_fixture()
                with self.server.store.transaction() as db:
                    row = db.execute('SELECT state_json FROM remix_matches WHERE id=?', (run['id'],)).fetchone()
                    db.execute('UPDATE remix_matches SET state_json=? WHERE id=?', (json.dumps(change(json.loads(row['state_json']))), run['id']))
                self.assert_prefix_rejected(run, key, intent)
        for raw in ('{broken', '[]', '{"sequence":1,"sequence":1}', '"' + 'x' * (remix.MAX_STORED_JSON + 1) + '"'):
            with self.subTest(raw_shape=raw[:32]):
                run, key, intent, _ = self.active_fixture()
                with self.server.store.transaction() as db:
                    db.execute('UPDATE remix_matches SET state_json=? WHERE id=?', (raw, run['id']))
                self.assert_prefix_rejected(run, key, intent)

    def test_active_journal_gaps_extra_rows_and_corrupted_acknowledgements_fail_closed(self):
        for corruption in ('missing', 'extra', 'column-sequence', 'input-sequence', 'input-direction', 'input-extra',
                           'checkpoint', 'checkpoint-hash', 'response-position', 'response-state', 'response-extra', 'response-json'):
            with self.subTest(corruption=corruption):
                run, key, intent, _ = self.active_fixture()
                with self.server.store.transaction() as db:
                    row = dict(db.execute('SELECT * FROM remix_inputs WHERE match_id=? AND sequence=1', (run['id'],)).fetchone())
                    if corruption == 'missing':
                        db.execute('DELETE FROM remix_inputs WHERE match_id=?', (run['id'],))
                    elif corruption == 'extra':
                        db.execute('INSERT INTO remix_inputs VALUES(?,?,?,?,?)', (run['id'], 2, row['input_json'], row['checkpoint_json'], row['response_json']))
                    elif corruption == 'column-sequence':
                        db.execute('UPDATE remix_inputs SET sequence=3 WHERE match_id=?', (run['id'],))
                    else:
                        field = 'input_json' if corruption.startswith('input') else 'checkpoint_json' if corruption.startswith('checkpoint') else 'response_json'
                        value = json.loads(row[field])
                        if corruption == 'input-sequence': value['sequence'] = 2
                        elif corruption == 'input-direction': value['moveX'] = -1
                        elif corruption == 'input-extra': value['extra'] = 'ignored by a permissive reader'
                        elif corruption == 'checkpoint': value['state']['position'] = [7, 3]
                        elif corruption == 'checkpoint-hash': value['hash'] = '0' * 64
                        elif corruption == 'response-position': value['position'] = [7, 3]
                        elif corruption == 'response-state': value['state']['sequence'] = 8
                        elif corruption == 'response-extra': value['extra'] = True
                        raw = '{broken' if corruption == 'response-json' else json.dumps(value)
                        db.execute(f'UPDATE remix_inputs SET {field}=? WHERE match_id=?', (raw, run['id']))
                self.assert_prefix_rejected(run, key, intent)

    def test_active_phase_result_and_arena_must_agree_with_durable_prefix(self):
        for corruption in ('phase-results', 'phase-unknown', 'purpose', 'premature-result', 'premature-hash', 'arena', 'seed'):
            with self.subTest(corruption=corruption):
                challenge = self.challenge(objects=[dict(id='goal', kind='goal', x=11, y=3)])
                run, key, intent, _ = self.active_fixture(challenge)
                with self.server.store.transaction() as db:
                    if corruption == 'phase-results': db.execute("UPDATE remix_matches SET phase='RESULTS' WHERE id=?", (run['id'],))
                    elif corruption == 'phase-unknown': db.execute("UPDATE remix_matches SET phase='WAITING' WHERE id=?", (run['id'],))
                    elif corruption == 'purpose': db.execute("UPDATE remix_matches SET purpose='invented' WHERE id=?", (run['id'],))
                    elif corruption == 'premature-result': db.execute("UPDATE remix_matches SET result_json='{}' WHERE id=?", (run['id'],))
                    elif corruption == 'premature-hash': db.execute('UPDATE remix_matches SET replay_hash=? WHERE id=?', ('0' * 64, run['id']))
                    elif corruption == 'seed': db.execute('UPDATE remix_challenges SET seed=43 WHERE id=?', (challenge['id'],))
                    else:
                        arena = json.loads(db.execute('SELECT arena_json FROM remix_challenges WHERE id=?', (challenge['id'],)).fetchone()[0])
                        arena['objects'][0]['y'] = 4
                        db.execute('UPDATE remix_challenges SET arena_json=? WHERE id=?', (json.dumps(arena), challenge['id']))
                self.assert_prefix_rejected(run, key, intent)

    def test_zero_input_prefix_is_verified_before_the_first_move(self):
        run = self.match()
        path = 'matches/' + run['id']
        self.assertEqual(self.alice.request(path + '/state'), run)
        with self.server.store.transaction() as db:
            state = remix.initial_state()
            state['position'] = [7, 3]
            db.execute('UPDATE remix_matches SET state_json=? WHERE id=?', (json.dumps(state), run['id']))
        before = self.persisted_run(run['id'])
        self.alice.request(path + '/state', expected=503)
        self.alice.request(path + '/input', dict(sequence=1, moveX=1, moveY=0), expected=503)
        self.assertEqual(self.persisted_run(run['id']), before)

    def test_input_idempotency_cache_cannot_return_an_unverified_response(self):
        for corruption in ('position', 'state', 'replayed-type', 'extra', 'malformed'):
            with self.subTest(corruption=corruption):
                run, key, intent, response = self.active_fixture()
                changed = copy.deepcopy(response)
                if corruption == 'position': changed['position'] = [7, 3]
                elif corruption == 'state': changed['state']['sequence'] = 8
                elif corruption == 'replayed-type': changed['replayed'] = 0
                elif corruption == 'extra': changed['invented'] = True
                raw = '{broken' if corruption == 'malformed' else json.dumps(changed)
                with self.server.store.transaction() as db:
                    db.execute('UPDATE remix_operations SET response_json=? WHERE actor_id=? AND operation_key=?', (raw, self.alice.user['id'], key))
                before = self.persisted_run(run['id'])
                self.assertEqual(self.alice.request('matches/' + run['id'] + '/state'), run)
                rejected = self.alice.request('matches/' + run['id'] + '/input', intent, key=key, expected=503)
                self.assertEqual(rejected['error'], 'replay_integrity')
                self.assertEqual(self.persisted_run(run['id']), before)

    def test_prior_input_retries_keep_the_original_acknowledgement_after_later_moves(self):
        run, key, intent, first = self.active_fixture()
        route = 'matches/' + run['id']
        latest = self.alice.request(route + '/input', dict(intent, sequence=2))['state']
        expected = dict(first, replayed=True)
        self.assertEqual(self.alice.request(route + '/input', intent, key=key), expected)
        duplicate_key = secrets.token_hex(16)
        self.assertEqual(self.alice.request(route + '/input', intent, key=duplicate_key), expected)
        self.assertEqual(self.alice.request(route + '/input', intent, key=duplicate_key), expected)
        self.assertEqual(self.alice.request(route + '/state'), latest)
        with self.server.store.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM remix_inputs WHERE match_id=?', (run['id'],)).fetchone()[0], 2)

    def test_active_prefix_and_retry_survive_core_restart(self):
        run, key, intent, accepted = self.active_fixture()
        before = self.persisted_run(run['id'])
        self.server.shutdown()
        self.thread.join(5)
        self.server.server_close()
        type(self).start_server()
        self.alice.base = self.bob.base = self.base
        self.assertEqual(self.alice.request('matches/' + run['id'] + '/state'), run)
        self.assertEqual(self.alice.request('matches/' + run['id'] + '/input', intent, key=key), dict(accepted, replayed=True))
        self.assertEqual(self.persisted_run(run['id']), before)
        next_move = self.alice.request('matches/' + run['id'] + '/input', dict(intent, sequence=2))
        self.assertEqual(next_move['position'], [2, 3])

    def test_terminal_state_and_cached_input_also_verify_the_final_result(self):
        challenge = self.challenge(objects=[dict(id='goal', kind='goal', x=1, y=3)])
        run, key, intent, _ = self.active_fixture(challenge)
        self.assertEqual(run['phase'], 'RESULTS')
        with self.server.store.transaction() as db:
            result = json.loads(db.execute('SELECT result_json FROM remix_matches WHERE id=?', (run['id'],)).fetchone()[0])
            result['score'] += 100
            db.execute('UPDATE remix_matches SET result_json=? WHERE id=?', (json.dumps(result), run['id']))
        self.assert_prefix_rejected(run, key, intent)

    def test_input_prefix_above_the_storage_bound_is_rejected_without_extension(self):
        run, key, intent, _ = self.active_fixture()
        with self.server.store.transaction() as db:
            row = db.execute('SELECT input_json,checkpoint_json,response_json FROM remix_inputs WHERE match_id=?', (run['id'],)).fetchone()
            db.executemany('INSERT INTO remix_inputs VALUES(?,?,?,?,?)', ((run['id'], sequence, *tuple(row)) for sequence in range(2, remix.MAX_INPUTS + 3)))
        self.assert_prefix_rejected(run, key, intent)

    def test_full_256_input_prefix_remains_valid_and_ends_at_the_original_limit(self):
        run = self.match()
        path = 'matches/' + run['id']
        for sequence in range(1, remix.MAX_INPUTS + 1):
            payload = dict(sequence=sequence, moveX=-1, moveY=0, jump=False)
            key = secrets.token_hex(16)
            accepted = self.alice.request(path + '/input', payload, key=key)
        state = self.alice.request(path + '/state')
        self.assertEqual((state['phase'], state['sequence'], state['position'], state['won']), ('RESULTS', 256, [0, 3], False))
        self.assertEqual(self.alice.request(path + '/input', payload, key=key), dict(accepted, replayed=True))
        result = self.alice.request(path + '/result')
        replay = self.alice.request(path + '/replay')
        self.assertEqual((result['outcome'], result['score'], result['replayHash']), ('input-limit', 0, replay['hash']))
        self.assertTrue(remix.verify_replay(replay))
        before = self.persisted_run(run['id'])
        self.alice.request(path + '/input', dict(payload, sequence=257), expected=400)
        self.assertEqual(self.persisted_run(run['id']), before)

    def test_owned_history_is_bounded_paginated_and_does_not_claim_verified_state(self):
        actor = register(self.base)
        challenge = actor.request('challenges', dict(title='History test', seed=42, objects=[dict(id='goal', kind='goal', x=1, y=3)]))
        runs = [actor.request('matches', dict(challengeId=challenge['id'])) for _ in range(53)]
        # Equal timestamps exercise the secondary stable identifier key.
        with self.server.store.transaction() as db:
            db.execute("UPDATE remix_matches SET created_at='2026-10-17T00:00:00+00:00' WHERE player_id=?", (actor.user['id'],))
        service, identifiers, cursor = self.server.store.remix, [], None
        first = service.list_matches(actor.user['id'], limit=20)
        self.assertEqual(len(first['matches']), 20)
        while True:
            page = service.list_matches(actor.user['id'], limit=20, cursor=cursor)
            for summary in page['matches']:
                self.assertEqual(set(summary), {'id', 'challengeId', 'title', 'phase', 'purpose', 'createdAt', 'stateVerified'})
                self.assertIs(summary['stateVerified'], False)
            identifiers.extend(row['id'] for row in page['matches'])
            cursor = page['nextCursor']
            if cursor is None:
                break
        self.assertEqual(identifiers, sorted((run['id'] for run in runs), reverse=True))
        self.assertEqual(len(service.list_matches(actor.user['id'], limit=50)['matches']), 50)
        unrelated = register(self.base)
        self.assertEqual(service.list_matches(unrelated.user['id'], limit=50)['matches'], [])
        cursor = first['nextCursor']
        actor.request('matches/' + cursor + '/input', dict(sequence=1, moveX=1, moveY=0))
        following = service.list_matches(actor.user['id'], limit=20, cursor=cursor)
        self.assertEqual([row['id'] for row in following['matches']], identifiers[20:40])
        self.assertEqual([row['id'] for row in service.list_matches(actor.user['id'], status='complete')['matches']], [cursor])
        corrupted = identifiers[0]
        with self.server.store.transaction() as db:
            db.execute("UPDATE remix_matches SET state_json='{}' WHERE id=?", (corrupted,))
        self.assertIs(service.list_matches(actor.user['id'])['matches'][0]['stateVerified'], False)
        self.assertEqual(actor.request('matches/' + corrupted + '/state', expected=503)['error'], 'replay_integrity')

    def test_history_rejects_foreign_cursor_and_invalid_bounds(self):
        service = self.server.store.remix
        own = self.match()
        for arguments in ({'status': 'all'}, {'limit': 0}, {'limit': 51}, {'limit': True}, {'limit': '20'}, {'cursor': ''}, {'cursor': '../id'}, {'cursor': 'f' * 32}):
            with self.subTest(arguments=arguments), self.assertRaises(Fault) as raised:
                service.list_matches(self.alice.user['id'], **arguments)
            self.assertEqual(raised.exception.status, 400)
        with self.assertRaises(Fault) as foreign:
            service.list_matches(self.bob.user['id'], cursor=own['id'])
        self.assertEqual((foreign.exception.status, foreign.exception.code), (400, 'invalid_cursor'))

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
