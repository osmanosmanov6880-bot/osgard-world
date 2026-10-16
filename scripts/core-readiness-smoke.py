#!/usr/bin/env python3
"""Regression checks for version-bound Studio evidence against a real HTTP/SQLite API."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from http.client import HTTPConnection
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib
import json
import sys
import threading
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'server'))
from core_server import create_server, QueueWorker


class ReadinessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = TemporaryDirectory()
        root = Path(cls.temp.name) / 'public'
        root.mkdir()
        (root / 'index.html').write_text('<title>Core test fixture</title>')
        cls.server = create_server(root, Path(cls.temp.name) / 'private' / 'core.sqlite3', port=0)
        cls.port = cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.owner = cls.request('POST', 'auth/register', {'username': 'readiness-owner', 'password': 'Test-only long password 2026'})[1]
        cls.other = cls.request('POST', 'auth/register', {'username': 'readiness-other', 'password': 'Test-only second password 2026'})[1]

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=3)
        cls.temp.cleanup()

    @classmethod
    def request(cls, method, route, body=None, token=None, key=None):
        connection = HTTPConnection('127.0.0.1', cls.port, timeout=10)
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        if body is not None and '/auth/' not in '/' + route:
            headers['Idempotency-Key'] = key or uuid.uuid4().hex
        connection.request(method, '/api/core/' + route, json.dumps(body) if body is not None else None, headers)
        response = connection.getresponse()
        result = response.status, json.loads(response.read())
        connection.close()
        return result

    def setUp(self):
        status, result = self.request('POST', 'projects', {'title': 'Release evidence', 'goal': 'Create a project with a measurable and verifiable result.'}, self.owner['token'])
        self.assertEqual(status, 200, result)
        self.project = result['project']

    def route(self, suffix=''):
        return 'projects/' + self.project['id'] + suffix

    def update(self, changes):
        status, result = self.request('POST', self.route(), {'expectedVersion': self.project['version'], 'changes': changes}, self.owner['token'])
        self.assertEqual(status, 200, result)
        self.project = result['project']
        return result

    def act(self, kind, payload=None):
        status, result = self.request('POST', self.route('/actions'), {'expectedVersion': self.project['version'], 'kind': kind, 'payload': payload or {}}, self.owner['token'])
        if status == 200:
            self.project = result['project']
        return status, result

    def ready(self, local=True):
        self.update({'budgetMinor': 10000, 'consents': {'learning': True, 'studio': True, 'business': True},
                     'allowedActions': ['local_checks', 'prepare_offer', 'build_preview'],
                     'acceptance': [{'id': 'criterion', 'title': 'The generated file explains the agreed goal.', 'done': True}],
                     'artifact': {'url': '' if local else 'https://example.com/unverified', 'checksum': '', 'notes': 'Manual pilot evidence.'}})
        self.update({'accepted': True})
        if local:
            status, result = self.act('build_preview')
            self.assertEqual(status, 200, result)
        return self.project

    def report(self):
        status, result = self.request('GET', self.route('/readiness'), token=self.owner['token'])
        self.assertEqual(status, 200, result)
        return result

    def release(self):
        status, result = self.act('release')
        self.assertEqual(status, 200, result)
        return result['result']

    def test_readiness_requires_auth_access_and_consent(self):
        self.assertEqual(self.request('GET', self.route('/readiness'))[0], 401)
        self.assertEqual(self.request('GET', self.route('/readiness'), token=self.other['token'])[0], 404)
        self.assertEqual(self.request('GET', self.route('/readiness'), token=self.owner['token'])[0], 400)
        self.ready()
        self.update({'consents': {'learning': True, 'studio': False, 'business': True}})
        self.assertEqual(self.request('GET', self.route('/readiness'), token=self.owner['token'])[0], 400)

    def test_fresh_html_produces_verifiable_release_evidence(self):
        self.ready()
        report = self.report()
        self.assertTrue(report['canCreateInternalRelease'])
        self.assertTrue(report['artifact']['integrityMatches'])
        self.assertTrue(report['artifact']['inputsMatch'])
        self.assertEqual(report['artifact']['actualSha256'], self.project['data']['artifact']['checksum'])
        self.assertEqual(report['sourceVersion'], self.project['version'])
        encoded = json.dumps(self.project['data'], ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False)
        self.assertEqual(report['snapshotSha256'], hashlib.sha256(encoded.encode()).hexdigest())
        release = self.release()
        self.assertEqual(release['evidence']['snapshotSha256'], report['snapshotSha256'])
        self.assertEqual(release['evidence']['sourceVersion'], report['sourceVersion'])
        self.assertFalse(release['evidence']['externalVerification'])
        self.assertNotIn(self.owner['token'], json.dumps(report))

    def test_changed_goal_requires_rebuild_after_new_contract(self):
        self.ready()
        self.update({'goal': 'The updated goal now asks for a completely different useful result.'})
        self.assertFalse(self.project['data']['accepted'])
        self.update({'accepted': True})
        self.assertIn('asset_inputs', self.report()['blockers'])
        status, result = self.act('release')
        self.assertEqual((status, result['error']), (409, 'artifact_stale'))
        self.assertEqual(len(self.project['data']['releases']), 0)
        self.assertEqual(self.act('build_preview')[0], 200)
        self.assertTrue(self.report()['canCreateInternalRelease'])
        self.release()

    def test_each_rendered_field_invalidates_old_preview(self):
        self.ready()
        changes = [
            {'title': 'A different product title'},
            {'audience': 'A new pilot audience'},
            {'tasks': [{'id': 'different-task', 'title': 'A changed implementation step', 'done': False}]},
            {'acceptance': [{'id': 'criterion', 'title': 'A different acceptance requirement', 'done': True}]},
        ]
        for fields in changes:
            with self.subTest(fields=list(fields)):
                self.update(fields)
                self.update({'accepted': True})
                self.assertFalse(self.report()['artifact']['inputsMatch'])
                self.assertEqual(self.act('release')[1]['error'], 'artifact_stale')
                self.assertEqual(self.act('build_preview')[0], 200)
                self.assertTrue(self.report()['artifact']['inputsMatch'])

    def test_task_tick_and_notes_do_not_require_a_new_file(self):
        self.ready()
        checksum = self.project['data']['artifact']['checksum']
        status, result = self.act('complete_task', {'taskId': self.project['data']['tasks'][0]['id']})
        self.assertEqual(status, 200, result)
        self.update({'artifact': dict(self.project['data']['artifact'], notes='Added reproducible manual checking instructions.')})
        self.assertEqual(self.project['data']['artifact']['checksum'], checksum)
        self.assertTrue(self.report()['artifact']['inputsMatch'])
        self.release()

    def test_missing_asset_cannot_be_released(self):
        self.ready()
        with self.server.store.transaction() as db:
            db.execute('DELETE FROM assets WHERE id=?', (self.project['data']['artifact']['assetId'],))
        report = self.report()
        self.assertFalse(report['canCreateInternalRelease'])
        self.assertIn('asset_exists', report['blockers'])
        status, result = self.act('release')
        self.assertEqual((status, result['error']), (409, 'artifact_missing'))

    def test_corrupt_asset_cannot_be_released(self):
        self.ready()
        with self.server.store.transaction() as db:
            db.execute('UPDATE assets SET content=? WHERE id=?', ('Changed file contents', self.project['data']['artifact']['assetId']))
        report = self.report()
        self.assertFalse(report['artifact']['integrityMatches'])
        self.assertIn('asset_integrity', report['blockers'])
        status, result = self.act('release')
        self.assertEqual((status, result['error']), (409, 'integrity_mismatch'))

    def test_missing_build_revision_cannot_be_released(self):
        self.ready()
        report = self.report()
        with self.server.store.transaction() as db:
            db.execute('DELETE FROM revisions WHERE project_id=? AND version=?', (self.project['id'], report['artifact']['sourceVersion']))
        self.assertIn('asset_source', self.report()['blockers'])
        status, result = self.act('release')
        self.assertEqual((status, result['error']), (409, 'artifact_source_missing'))

    def test_external_url_remains_explicitly_unverified(self):
        self.ready(local=False)
        report = self.report()
        self.assertTrue(report['canCreateInternalRelease'])
        self.assertEqual(report['artifact']['kind'], 'external_url')
        self.assertIsNone(report['artifact']['integrityMatches'])
        self.assertFalse(report['externalVerification'])
        self.assertFalse(report['limits']['publicDeploymentVerified'])
        self.assertFalse(report['limits']['paymentsVerified'])
        self.assertTrue(any('Внешняя ссылка' in warning for warning in report['warnings']))
        self.release()

    def test_version_conflict_prevents_stale_contract_overwrite_and_release(self):
        self.ready()
        old_version = self.project['version']
        old_report = self.report()
        self.update({'goal': 'A revised goal cannot be accepted by a stale browser tab.'})
        for body in [
            {'expectedVersion': old_version, 'changes': {'accepted': True}},
            {'expectedVersion': old_version, 'kind': 'release', 'payload': {}},
        ]:
            suffix = '/actions' if 'kind' in body else ''
            status, result = self.request('POST', self.route(suffix), body, self.owner['token'])
            self.assertEqual((status, result['error']), (409, 'version_conflict'))
        self.assertFalse(self.project['data']['accepted'])
        self.assertNotEqual(old_report['snapshotSha256'], self.report()['snapshotSha256'])

    def test_retry_and_concurrent_requests_do_not_duplicate_release(self):
        self.ready()
        body = {'expectedVersion': self.project['version'], 'kind': 'release', 'payload': {}}
        key = uuid.uuid4().hex
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: self.request('POST', self.route('/actions'), body, self.owner['token'], key), range(2)))
        self.assertTrue(all(status == 200 for status, _ in results), results)
        self.assertEqual(results[0][1]['result']['id'], results[1][1]['result']['id'])
        _, current = self.request('GET', self.route(), token=self.owner['token'])
        self.assertEqual(len(current['project']['data']['releases']), 1)

    def test_old_release_remains_frozen_after_rebuild(self):
        self.ready()
        old = self.release()
        old_route = self.route('/releases/' + old['id'])
        status, packet = self.request('GET', old_route, token=self.owner['token'])
        self.assertEqual(status, 200, packet)
        self.assertTrue(packet['asset']['inputsMatchSnapshot'])
        self.update({'title': 'A later edition of the product'})
        self.assertEqual(self.act('build_preview')[0], 200)
        self.release()
        _, later = self.request('GET', old_route, token=self.owner['token'])
        self.assertEqual(packet['snapshot'], later['snapshot'])
        self.assertEqual(packet['asset'], later['asset'])
        self.assertEqual(packet['release']['evidence'], later['release']['evidence'])

    def test_background_check_is_bound_to_queued_version(self):
        self.ready()
        expected = self.report()
        status, queued = self.request('POST', self.route('/jobs'), {'expectedVersion': self.project['version']}, self.owner['token'])
        self.assertEqual(status, 200, queued)
        self.update({'title': 'Changed after queueing the check'})
        worker = QueueWorker(self.server.store)
        self.assertTrue(worker.run_one())
        status, result = self.request('GET', self.route('/jobs'), token=self.owner['token'])
        self.assertEqual(status, 200, result)
        job = next(item for item in result['jobs'] if item['id'] == queued['jobId'])
        self.assertEqual(job['status'], 'completed')
        self.assertEqual(job['result']['sourceVersion'], expected['sourceVersion'])
        self.assertEqual(job['result']['snapshotSha256'], expected['snapshotSha256'])
        self.assertTrue(job['result']['artifact']['inputsMatch'])
        self.assertFalse(self.report()['artifact']['inputsMatch'])

    def test_synchronous_check_uses_real_file_integrity(self):
        self.ready()
        with self.server.store.transaction() as db:
            db.execute('UPDATE assets SET content=? WHERE id=?', ('corruption after build', self.project['data']['artifact']['assetId']))
        status, result = self.act('simulate')
        self.assertEqual(status, 200, result)
        self.assertFalse(result['result']['canCreateInternalRelease'])
        self.assertIn('asset_integrity', result['result']['blockers'])

    def test_overview_guides_user_to_rebuild_a_stale_file(self):
        self.ready()
        self.update({'title': 'A changed title without a replacement HTML file'})
        status, result = self.request('GET', 'overview', token=self.owner['token'])
        self.assertEqual(status, 200, result)
        project = next(item for item in result['projects'] if item['id'] == self.project['id'])
        self.assertIn('artifact_rebuild', project['issues'])
        self.assertEqual(project['nextAction']['stage'], 'studio')
        self.assertIn('Пересобрать', project['nextAction']['label'])
        self.assertLess(project['checks']['passed'], project['checks']['total'])

    def test_export_includes_current_snapshot_evidence(self):
        self.ready()
        expected = self.report()
        status, result = self.request('GET', self.route('/export'), token=self.owner['token'])
        self.assertEqual(status, 200, result)
        self.assertEqual(result['releaseReadiness']['sourceVersion'], expected['sourceVersion'])
        self.assertEqual(result['releaseReadiness']['snapshotSha256'], expected['snapshotSha256'])
        self.assertEqual(result['format'], 'osgard-core-project-v1')

    def test_frozen_packet_reveals_stale_legacy_build(self):
        self.ready()
        # Reproduce a release accepted by older code: the file source and the
        # released scope differ. Data is inserted only into this temporary DB.
        self.update({'title': 'Changed title previously allowed by the old release code'})
        with self.server.store.transaction() as db:
            row = self.server.store.access(db, self.project['id'], self.owner['user']['id'])
            from core_model import action
            data, release = action(json.loads(row['data']), 'release', {})
            release['sourceVersion'] = row['version']
            self.project = self.server.store.save(db, row, self.owner['user']['id'], data, 'legacy_test_release', {})
        status, packet = self.request('GET', self.route('/releases/' + release['id']), token=self.owner['token'])
        self.assertEqual(status, 200, packet)
        self.assertTrue(packet['asset']['integrityMatches'])
        self.assertFalse(packet['asset']['inputsMatchSnapshot'])
        status, result = self.request('POST', self.route('/members'), {'expectedVersion': self.project['version'], 'username': 'readiness-other', 'role': 'editor'}, self.owner['token'])
        self.assertEqual(status, 200, result)
        self.project = result['project']
        body = {'expectedVersion': self.project['version'], 'releaseId': release['id'], 'criteria': [{'id': 'criterion', 'passed': True, 'evidence': 'A detailed review should not waive a stale generated artifact.'}], 'note': 'This check must reject a locally stale build even with human approval.'}
        status, result = self.request('POST', self.route('/release-review'), body, self.other['token'])
        self.assertEqual((status, result['error']), (409, 'artifact_stale'))
        # Also emulate an old positive review: new handoffs must still examine
        # the frozen release's own inputs instead of trusting that verdict.
        with self.server.store.transaction() as db:
            db.execute('INSERT INTO release_reviews VALUES(?,?,?,?,?,?,?,?,?)',
                       (uuid.uuid4().hex, self.project['id'], release['id'], release['sourceVersion'],
                        self.other['user']['id'], 'accepted', json.dumps(body['criteria']), body['note'],
                        datetime.now(timezone.utc).isoformat()))
        for suffix, extra in [
            ('/delivery', {'action': 'handoff', 'note': 'This stale legacy release must not be handed to another participant.'}),
            ('/client-deliveries', {'sharingAcknowledged': True, 'title': 'A legacy package', 'description': 'The old accepted release must still pass the source consistency gate.', 'instructions': 'Read the provided material and record your observations.'}),
        ]:
            outgoing = dict(expectedVersion=self.project['version'], releaseId=release['id'], recipient='readiness-other', **extra)
            status, result = self.request('POST', self.route(suffix), outgoing, self.owner['token'])
            self.assertEqual((status, result['error']), (409, 'artifact_stale'))


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(ReadinessTests))
    report = {
        'status': 'passed' if result.wasSuccessful() else 'failed',
        'testsRun': result.testsRun,
        'failures': len(result.failures),
        'errors': len(result.errors),
        'generatedAt': datetime.now(timezone.utc).isoformat(),
        'scope': 'Real local HTTP/SQLite release evidence, stale builds, file integrity, exact versions, retry and immutable historical releases',
        'externalPublicationTested': False,
        'paymentsTested': False,
        'actualPilotConfirmed': False,
    }
    (ROOT / 'docs' / 'CORE-READINESS-TESTS.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    sys.exit(0 if result.wasSuccessful() else 1)
