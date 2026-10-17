"""Real Core SQLite/HTTP contracts for private, recoverable INHERIT lineages."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import http.client
import importlib.util
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'server'))
import core_inherit
from core_backup import backup
from core_model import Fault
from core_server import Store, create_server, digest

verifier_spec = importlib.util.spec_from_file_location('inherit_backup_verifier', ROOT / 'scripts/verify-core-backup.py')
verifier = importlib.util.module_from_spec(verifier_spec)
verifier_spec.loader.exec_module(verifier)


class InheritFixture:
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.store = Store(self.base / 'core.sqlite3')
        self.people = {name: uuid.uuid4().hex for name in ('first', 'next', 'other')}
        with self.store.transaction() as db:
            for name, actor in self.people.items():
                db.execute('INSERT INTO users VALUES(?,?,?,?,?)',
                           (actor, 'inherit-test-' + name, '00', 'unusable-test-fixture', '2026-01-01T00:00:00Z'))

    def write(self, route, payload, who='first', key=None, store=None):
        return (store or self.store).mutate(core_inherit.PREFIX + route, self.people[who], payload, key or uuid.uuid4().hex)

    def read(self, route, who='first', store=None):
        return (store or self.store).get(core_inherit.PREFIX + route, self.people[who])

    def create(self, source='template', objects=None):
        return self.write('worlds', dict(title='Private QA lineage', template=core_inherit.TEMPLATE,
                                         source=source, objects=objects or []))['world']

    def append(self, world, who='first', key=None, store=None, x=30):
        return self.write('worlds/' + world['id'] + '/generations',
                          dict(expectedRevision=world['revision'], expectedGeneration=world['currentGeneration'],
                               message='One verified trace', delta=[dict(type='tree', x=x, y=45)]), who, key, store)

    def offer(self, world, who='first', target='next', key=None):
        return self.write('worlds/' + world['id'] + '/handoffs',
                          dict(expectedRevision=world['revision'], targetUserId=self.people[target],
                               sharingAcknowledged=True), who, key)

    def accept(self, invitation, who='next', key=None):
        return self.write('handoffs/' + invitation['id'] + '/accept',
                          dict(expectedRevision=invitation['expectedRevision']), who, key)

    def fault(self, status, fn, *args, **kwargs):
        with self.assertRaises(Fault) as raised:
            fn(*args, **kwargs)
        self.assertEqual(raised.exception.status, status)
        return raised.exception


class InheritTest(InheritFixture, unittest.TestCase):
    def test_invitation_operation_recovery_also_requires_retained_world_membership(self):
        world = self.append(self.create())['world']
        key = uuid.uuid4().hex
        offered = self.offer(world, key=key)
        self.assertEqual(self.read('operations/' + key)['result'], offered)
        with self.store.transaction() as db:
            db.execute('DELETE FROM inherit_members WHERE world_id=? AND user_id=?', (world['id'], self.people['first']))
        # A still-addressed invitation is not authority to recover a full world.
        self.read('handoffs/' + offered['invitation']['id'])
        self.fault(404, self.read, 'worlds/' + world['id'])
        self.fault(404, self.read, 'operations/' + key)
        self.fault(404, self.offer, world, key=key)

    def test_full_two_custodian_loop_and_return_notification(self):
        baseline = self.create()
        self.assertEqual((baseline['currentGeneration'], baseline['revision'], baseline['sourceVerified']), (1, 1, True))
        first = self.append(baseline)['world']
        offered = self.offer(first)
        self.assertFalse(offered['world']['canEdit'])
        invitation = offered['invitation']
        self.fault(404, self.read, 'worlds/' + first['id'], 'next')
        self.assertEqual(self.read('handoffs/' + invitation['id'], 'next')['invitation']['to']['id'], self.people['next'])
        next_world = self.accept(invitation)['world']
        self.assertTrue(next_world['canEdit'])
        self.assertEqual(next_world['custodian']['id'], self.people['next'])
        old = self.read('worlds/' + first['id'])['world']
        self.assertEqual((old['role'], old['canEdit']), ('reader', False))
        self.fault(403, self.append, old)
        advanced = self.append(next_world, 'next', x=60)
        returned = self.read('worlds/' + first['id'])['world']
        self.assertEqual(returned['currentGeneration'], 3)
        self.assertEqual(len(returned['objects']), 2)
        self.assertEqual([g['author']['id'] for g in returned['generations']], [self.people['first'], self.people['next']])
        notifications = self.read('notifications')['notifications']
        notice = next(n for n in notifications if n['kind'] == 'generation_created')
        self.assertEqual((notice['generation'], notice['actor']['id']), (2, self.people['next']))
        self.write('notifications/' + str(notice['id']) + '/read', {})
        self.assertIsNotNone(self.read('notifications')['notifications'][0]['readAt'])
        self.assertEqual(self.read('worlds/' + first['id'] + '/generations/1')['generation']['objects'], baseline['objects'] + [dict(type='tree', x=30, y=45)])
        self.assertEqual(advanced['generation']['parentHash'], first['snapshotHash'])
        # A previous custodian can be explicitly invited back after the next person's change.
        offered_back = self.offer(advanced['world'], who='next', target='first')
        self.assertEqual(self.accept(offered_back['invitation'], 'first')['world']['role'], 'custodian')

    def test_local_copy_has_no_fabricated_generation_or_author(self):
        world = self.create('local-copy', [dict(type='stone', x=5, y=95)])
        self.assertFalse(world['sourceVerified'])
        self.assertEqual((world['currentGeneration'], world['generations']), (1, []))
        published = self.append(world)['world']
        self.assertEqual(len(published['objects']), 2)
        self.assertEqual(len(published['generations']), 1)
        self.assertEqual(published['generations'][0]['author']['id'], self.people['first'])

    def test_private_acl_covers_world_history_operation_handoff_and_inbox(self):
        key = uuid.uuid4().hex
        made = self.write('worlds', dict(title='Private', template=core_inherit.TEMPLATE, source='template', objects=[]), key=key)
        world = self.append(made['world'])['world']
        invitation = self.offer(world)['invitation']
        for route in ('worlds/' + world['id'], 'worlds/' + world['id'] + '/generations/1',
                      'operations/' + key, 'handoffs/' + invitation['id']):
            self.fault(404, self.read, route, 'other')
        self.assertEqual(self.read('worlds', 'other'), {'worlds': []})
        self.assertEqual(self.read('notifications', 'other')['notifications'], [])
        self.fault(404, self.accept, invitation, 'other')
        self.fault(403, self.accept, invitation, 'first')

    def test_lost_create_and_append_response_recover_without_reexecution(self):
        create_key = uuid.uuid4().hex
        made = self.write('worlds', dict(title='Recovery', template=core_inherit.TEMPLATE, source='template', objects=[]), key=create_key)
        recovered = self.read('operations/' + create_key)
        self.assertEqual(recovered['result'], made)
        append_key = uuid.uuid4().hex
        saved = self.append(made['world'], key=append_key)
        self.assertEqual(self.read('operations/' + append_key)['result'], saved)
        replay = self.append(made['world'], key=append_key)
        self.assertTrue(replay.pop('replayed'))
        self.assertEqual(replay, saved)
        self.assertEqual(len(self.read('worlds/' + made['world']['id'])['world']['generations']), 1)
        self.fault(409, self.append, made['world'], key=append_key, x=33)

    def test_replayed_committed_generation_remains_readable_after_handoff(self):
        world = self.create()
        key = uuid.uuid4().hex
        saved = self.append(world, key=key)
        invitation = self.offer(saved['world'])['invitation']
        self.accept(invitation)
        self.assertEqual(self.read('operations/' + key)['result'], saved)
        self.assertTrue(self.append(world, key=key)['replayed'])
        self.fault(403, self.append, world)

    def test_conflicting_tabs_only_append_once(self):
        world = self.create()
        barrier = threading.Barrier(2)
        def concurrent(x):
            barrier.wait()
            try:
                return self.append(world, x=x)['world']['currentGeneration']
            except Fault as error:
                return error.status
        with ThreadPoolExecutor(max_workers=2) as pool:
            outcomes = list(pool.map(concurrent, (20, 40)))
        self.assertEqual(sorted(outcomes), [2, 409])
        current = self.read('worlds/' + world['id'])['world']
        self.assertEqual((len(current['objects']), len(current['generations'])), (1, 1))

    def test_accept_cancel_race_has_one_atomic_winner(self):
        invitation = self.offer(self.append(self.create())['world'])['invitation']
        barrier = threading.Barrier(2)
        def race(action):
            barrier.wait()
            try:
                result = self.write('handoffs/' + invitation['id'] + '/' + action,
                                    dict(expectedRevision=invitation['expectedRevision']), 'next' if action == 'accept' else 'first')
                return result['invitation']['status']
            except Fault as error:
                return error.status
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(race, ('accept', 'cancel')))
        self.assertIn(409, results)
        current = self.read('worlds/' + invitation['worldId'])['world']
        if 'accepted' in results:
            self.assertEqual(current['custodian']['id'], self.people['next'])
            self.assertEqual(self.read('worlds/' + current['id'], 'next')['world']['role'], 'custodian')
        else:
            self.assertIn('cancelled', results)
            self.assertEqual(current['custodian']['id'], self.people['first'])
            self.fault(404, self.read, 'worlds/' + current['id'], 'next')

    def test_decline_does_not_disclose_private_objects(self):
        offered = self.offer(self.append(self.create())['world'])
        invite = offered['invitation']
        result = self.write('handoffs/' + invite['id'] + '/decline', dict(expectedRevision=invite['expectedRevision']), 'next')
        self.assertNotIn('world', result)
        self.assertEqual(result['invitation']['status'], 'declined')
        self.fault(404, self.read, 'worlds/' + invite['worldId'], 'next')
        self.assertTrue(self.read('worlds/' + invite['worldId'])['world']['canEdit'])

    def test_expiry_unfreezes_world_without_read_side_effects(self):
        offered = self.offer(self.append(self.create())['world'])
        invite = offered['invitation']
        with self.store.transaction() as db:
            db.execute('UPDATE inherit_handoffs SET expires_at=? WHERE id=?', (time.time() - 1, invite['id']))
        world = self.read('worlds/' + invite['worldId'])['world']
        self.assertTrue(world['canEdit'])
        self.assertEqual(self.read('handoffs/' + invite['id'], 'next')['invitation']['status'], 'expired')
        self.fault(409, self.accept, invite)
        self.assertEqual(self.append(world)['world']['currentGeneration'], 3)
        with self.store.connect() as db:
            self.assertEqual(db.execute('SELECT status FROM inherit_handoffs WHERE id=?', (invite['id'],)).fetchone()[0], 'expired')

    def test_handoff_requires_own_generation_and_explicit_sharing(self):
        world = self.create()
        self.fault(409, self.offer, world)
        world = self.append(world)['world']
        self.fault(400, self.write, 'worlds/' + world['id'] + '/handoffs',
                   dict(expectedRevision=world['revision'], targetUserId=self.people['next'], sharingAcknowledged=False))
        offered = self.offer(world)
        self.fault(409, self.append, offered['world'])
        next_world = self.accept(offered['invitation'])['world']
        self.fault(409, self.offer, next_world, who='next', target='first')

    def test_generation_snapshot_and_hash_are_immutable(self):
        world = self.append(self.create())['world']
        original = self.read('worlds/' + world['id'] + '/generations/1')['generation']
        for sql in ('UPDATE inherit_generations SET message="changed"', 'DELETE FROM inherit_generations'):
            with self.assertRaises(sqlite3.IntegrityError), self.store.transaction() as db:
                db.execute(sql)
        self.assertEqual(self.read('worlds/' + world['id'] + '/generations/1')['generation'], original)
        expected_hash = core_inherit.checksum(dict(worldId=world['id'], number=1,
            authorId=self.people['first'], message=original['message'], delta=original['delta'],
            objects=original['objects'], parentHash=original['parentHash'], createdAt=original['createdAt']))
        self.assertEqual(original['snapshotHash'], expected_hash)

    def test_notification_failure_rolls_back_generation_snapshot_and_operation(self):
        first = self.append(self.create())['world']
        accepted = self.accept(self.offer(first)['invitation'])['world']
        key = uuid.uuid4().hex
        with patch.object(core_inherit, 'notify', side_effect=sqlite3.OperationalError('synthetic failure')):
            with self.assertRaises(sqlite3.OperationalError):
                self.append(accepted, 'next', key=key)
        current = self.read('worlds/' + first['id'])['world']
        self.assertEqual((current['currentGeneration'], current['revision'], current['objects']),
                         (accepted['currentGeneration'], accepted['revision'], accepted['objects']))
        self.fault(404, self.read, 'operations/' + key, 'next')

    def test_operation_insert_failure_rolls_back_created_world(self):
        with self.store.transaction() as db:
            db.execute("CREATE TRIGGER reject_core_operation BEFORE INSERT ON operations BEGIN SELECT RAISE(ABORT,'synthetic failure'); END")
        with self.assertRaises(sqlite3.IntegrityError):
            self.create()
        self.assertEqual(self.read('worlds')['worlds'], [])
        with self.store.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM inherit_operations').fetchone()[0], 0)

    def test_validation_rejects_spoofed_authors_bad_coordinates_and_oversize_delta(self):
        world = self.create()
        body = dict(expectedRevision=1, expectedGeneration=1, message='Valid trace', delta=[dict(type='tree', x=20, y=40)])
        for change in ({'author': 'pretend'}, {'expectedRevision': True}, {'expectedGeneration': False},
                       {'delta': [dict(type='tree', x=True, y=40)]}, {'delta': [dict(type='tree', x=float('nan'), y=40)]},
                       {'delta': [dict(type='tree', x=101, y=40)]}, {'delta': [dict(type='unknown', x=20, y=40)]},
                       {'delta': body['delta'] * 101}, {'delta': []}):
            with self.subTest(change=repr(change)):
                # Core's fingerprint rejects NaN before dispatch, which is also a non-mutating validation failure.
                try:
                    self.write('worlds/' + world['id'] + '/generations', body | change)
                except Fault as error:
                    self.assertIn(error.status, (400, 409))
                except ValueError:
                    pass
                else:
                    self.fail('invalid input was accepted')
        self.assertEqual(self.read('worlds/' + world['id'])['world']['currentGeneration'], 1)

    def test_object_limit_and_baseline_provenance_are_enforced(self):
        self.fault(400, self.create, 'template', [dict(type='tree', x=20, y=40)])
        world = self.create('local-copy', [dict(type='tree', x=20, y=40)] * 1024)
        self.fault(409, self.append, world)
        self.assertEqual(len(self.read('worlds/' + world['id'])['world']['objects']), 1024)

    def test_same_key_across_different_actors_is_isolated(self):
        key = uuid.uuid4().hex
        payload = dict(title='Same key, separate users', template=core_inherit.TEMPLATE, source='template', objects=[])
        a = self.write('worlds', payload, key=key)
        b = self.write('worlds', payload, who='next', key=key)
        self.assertNotEqual(a['world']['id'], b['world']['id'])
        self.assertEqual(self.read('operations/' + key, 'next')['result'], b)

    def test_restart_and_real_backup_restore_preserve_lineage_members_and_recovery(self):
        append_key = uuid.uuid4().hex
        baseline = self.create()
        first = self.append(baseline, key=append_key)['world']
        invitation = self.offer(first)['invitation']
        accept_key = uuid.uuid4().hex
        accepted = self.accept(invitation, key=accept_key)
        second = self.append(accepted['world'], 'next')['world']
        target = self.base / 'restored.sqlite3'
        digest_before = backup(self.store.path, target)
        self.assertEqual(hashlib.sha256(target.read_bytes()).hexdigest(), digest_before)
        self.assertTrue(verifier.drill(target, digest_before)['core_schema_checked'])
        restored = Store(target)
        self.assertEqual(self.read('worlds/' + first['id'], 'next', restored)['world'], second)
        self.assertEqual(self.read('operations/' + accept_key, 'next', restored)['result'], accepted)
        self.assertEqual(len(self.read('worlds/' + first['id'], 'first', restored)['world']['generations']), 2)
        self.assertTrue(self.read('notifications', 'first', restored)['unreadCount'] > 0)
        self.assertEqual(self.append(baseline, key=append_key, store=restored)['world']['currentGeneration'], 2)

    def test_existing_schema_missing_acl_or_immutability_trigger_fails_startup(self):
        self.create()
        with self.store.connect() as db:
            db.execute('DROP TABLE inherit_members')
        self.fault(503, Store, self.store.path)
        with self.store.connect() as db:
            self.assertIsNone(db.execute("SELECT name FROM sqlite_master WHERE name='inherit_members'").fetchone())

    def test_missing_operation_record_is_not_reconstructed_from_cached_success(self):
        key = uuid.uuid4().hex
        payload = dict(title='Recovery record', template=core_inherit.TEMPLATE, source='template', objects=[])
        self.write('worlds', payload, key=key)
        with self.store.transaction() as db:
            db.execute('DELETE FROM inherit_operations WHERE user_id=? AND key=?', (self.people['first'], key))
        self.fault(503, self.write, 'worlds', payload, key=key)

    def test_missing_immutability_trigger_is_not_silently_recreated(self):
        self.create()
        with self.store.connect() as db:
            db.execute('DROP TRIGGER inherit_generation_no_delete')
        self.fault(503, Store, self.store.path)

    def test_backup_verifier_rejects_lost_inherit_acl_and_history_guard(self):
        self.create()
        for sql in ('DROP TABLE inherit_members', 'DROP TRIGGER inherit_generation_no_update'):
            with self.subTest(sql=sql):
                target = self.base / (uuid.uuid4().hex + '.sqlite3')
                backup(self.store.path, target)
                with sqlite3.connect(target) as db:
                    db.execute(sql)
                with self.assertRaises(ValueError):
                    verifier.drill(target)


class InheritHttpTest(InheritFixture, unittest.TestCase):
    def setUp(self):
        super().setUp()
        public = self.base / 'public'
        public.mkdir()
        (public / 'index.html').write_text('<title>Isolated API fixture</title>')
        self.server = create_server(public, self.store.path, port=0)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop)
        self.tokens = {name: 'fixture_' + uuid.uuid4().hex + uuid.uuid4().hex for name in self.people}
        with self.store.transaction() as db:
            for name, token in self.tokens.items():
                db.execute('INSERT INTO sessions VALUES(?,?,?)', (digest(token), self.people[name], time.time() + 300))

    def stop(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=3)

    def request(self, method, path, who='first', body=None, key=None, headers=None):
        connection = http.client.HTTPConnection(*self.server.server_address, timeout=3)
        self.addCleanup(connection.close)
        request_headers = {'Authorization': 'Bearer ' + self.tokens[who]} if who else {}
        if body is not None:
            request_headers['Content-Type'] = 'application/json'
        if key:
            request_headers['Idempotency-Key'] = key
        request_headers.update(headers or {})
        connection.request(method, '/api/core/' + path, json.dumps(body) if body is not None else None, request_headers)
        response = connection.getresponse()
        status, data, cache = response.status, json.loads(response.read()), response.getheader('Cache-Control')
        connection.close()
        return status, data, cache

    def test_real_http_bearer_scope_logout_and_recovery(self):
        self.assertEqual(self.request('GET', 'inherit/v1/capabilities', None)[0], 401)
        key = uuid.uuid4().hex
        status, result, cache = self.request('POST', 'inherit/v1/worlds', body=dict(
            title='HTTP private fixture', template=core_inherit.TEMPLATE, source='template', objects=[]), key=key)
        self.assertEqual((status, cache), (200, 'no-store'))
        world_id = result['world']['id']
        self.assertEqual(self.request('GET', 'inherit/v1/worlds/' + world_id, 'next')[0], 404)
        self.assertEqual(self.request('GET', 'inherit/v1/operations/' + key)[1]['result'], result)
        self.assertEqual(self.request('GET', 'inherit/v1/operations/' + key, 'next')[0], 404)
        self.assertEqual(self.request('GET', 'inherit/v1/worlds/' + world_id, headers={'Origin': 'https://untrusted.example'})[0], 403)
        self.assertEqual(self.request('POST', 'auth/logout', body={})[0], 200)
        self.assertEqual(self.request('GET', 'inherit/v1/operations/' + key)[0], 401)
        self.assertEqual(self.request('GET', 'inherit/v1/worlds/' + world_id)[0], 401)


if __name__ == '__main__':
    unittest.main()
