#!/usr/bin/env python3
"""Independent frozen-program checks: local HTTP/SQLite and injected FakeProvider only."""
from pathlib import Path
from unittest.mock import patch
import hashlib
import importlib.util
import json
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('frozen_program_tests', ROOT / 'scripts/core-program-commerce-smoke.py')
program = importlib.util.module_from_spec(spec)
spec.loader.exec_module(program)

PRIVATE = 'INDEPENDENT-PAID-PRIVATE-CONTRIBUTION: original practice, verification and transfer evidence.'
FREE = 'INDEPENDENT-FREE-PRACTICE: this contribution must not count as purchased practice.'
FILES = ('server/core_programs.py', 'server/core_commerce.py', 'server/core_server.py', 'scripts/core-program-commerce-smoke.py')


def frozen_hashes():
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in FILES}


class IndependentChecks(program.ProgramCommerceTests):
    def perform_recorded(self, action, **extra):
        current = self.read()[1]
        payload = dict(action=action, expectedVersion=current['version'], **extra)
        key = uuid.uuid4().hex
        status, result = self.write(self.enrollment_route(), payload, 'buyer', key)
        self.assertEqual(status, 200, result)
        return action, payload, key

    def complete_program_and_record_keys(self):
        self.pay()
        self.assertEqual(self.activate()[0], 200)
        records = []
        for lesson in self.read()[1]['curriculum']['lessons']:
            record = self.perform_recorded('activity', slug=lesson['slug'], locale='ru',
                                           answer=lesson['ru']['check']['correctIndex'], practice=PRIVATE)
            if not records:
                records.append(record)
        records.append(self.perform_recorded('save_work', work={field: PRIVATE for field in program.core_programs.WORK_FIELDS}))
        records.append(self.perform_recorded('submit'))
        before = self.read(suffix='/export')[1]
        for action, payload, key in records:
            status, response = self.write(self.enrollment_route(), payload, 'buyer', key)
            self.assertEqual(status, 200, (action, response))
            self.assertTrue(response.get('replayed'), action)
        self.assertEqual(self.read(suffix='/export')[1], before)
        return records, before

    def assert_closed_replays(self, records, error):
        for action, payload, key in records:
            for requested_key in (key, uuid.uuid4().hex):
                status, response = self.write(self.enrollment_route(), payload, 'buyer', requested_key)
                self.assertEqual((status, response.get('error')), (403, error), (action, response))
                self.assertNotIn('replayed', response)

    def test_independent_cached_actions_after_consent_revocation(self):
        records, before = self.complete_program_and_record_keys()
        project = before['project']
        status, response = self.write('projects/' + project['id'],
            dict(expectedVersion=project['version'], changes=dict(consents=dict(learning=False, studio=False, business=False))), 'buyer')
        self.assertEqual(status, 200, response)
        current = self.read()[1]
        self.assertEqual(current['status'], 'consent_required')
        self.assertNotIn('curriculum', current)
        self.assertNotIn('practice', current)
        self.assert_closed_replays(records, 'learning_consent_required')
        status, after = self.read(suffix='/export')
        self.assertEqual(status, 200, after)
        self.assertEqual({k: v for k, v in after.items() if k != 'project'},
                         {k: v for k, v in before.items() if k != 'project'})
        self.assertFalse(after['project']['data']['consents']['learning'])

    def test_independent_cached_actions_after_full_refund(self):
        records, before = self.complete_program_and_record_keys()
        self.refund_event(1000)
        current = self.read()[1]
        self.assertEqual(current['status'], 'refunded')
        self.assertNotIn('curriculum', current)
        self.assertNotIn('practice', current)
        self.assert_closed_replays(records, 'payment_required')
        self.assertEqual(self.read(suffix='/export'), (200, before))

    def test_independent_editor_export_excludes_paid_contributions(self):
        records, before = self.complete_program_and_record_keys()
        project = before['project']
        status, response = self.write('projects/' + project['id'] + '/members',
            dict(expectedVersion=project['version'], username='commerce-reviewer', role='editor'), 'buyer')
        self.assertEqual(status, 200, response)
        for suffix in ('', '/export'):
            status, exported = self.request('GET', 'projects/' + project['id'] + suffix, token=self.token('reviewer'))
            self.assertEqual(status, 200, exported)
            self.assertEqual(exported['project']['role'], 'editor')
            self.assertNotIn('programWork', exported)
            self.assertNotIn(PRIVATE, json.dumps(exported))
        self.assertEqual(self.read('reviewer')[0], 404)
        self.assertEqual(self.read('reviewer', '/export')[0], 404)
        action, payload, key = records[0]
        self.assertEqual(self.write(self.enrollment_route(), payload, 'reviewer', key)[0], 404)
        status, owned = self.request('GET', 'projects/' + project['id'] + '/export', token=self.token('buyer'))
        self.assertEqual(status, 200, owned)
        self.assertEqual(owned['programWork']['activities'], before['activities'])
        self.assertIn(PRIVATE, json.dumps(owned))

    def test_independent_free_learning_cannot_replace_paid_progress(self):
        self.pay()
        self.assertEqual(self.activate()[0], 200)
        starting = self.read()[1]
        pid = starting['projectId']
        lessons = self.request('GET', 'curriculum', token=self.token('buyer'))[1]['lessons']
        for lesson in lessons:
            status, project = self.request('GET', 'projects/' + pid, token=self.token('buyer'))
            self.assertEqual(status, 200, project)
            status, response = self.write('projects/' + pid + '/learning', dict(action='activity',
                expectedVersion=project['project']['version'], slug=lesson['slug'], locale='ru',
                answer=lesson['ru']['check']['correctIndex'], practice=FREE), 'buyer')
            self.assertEqual(status, 200, response)
        status, free = self.request('GET', 'projects/' + pid + '/learning', token=self.token('buyer'))
        self.assertEqual(status, 200, free)
        self.assertEqual(len(free['completed']), len(lessons))
        paid = self.read()[1]
        self.assertEqual(paid['version'], starting['version'])
        self.assertEqual(paid['completed'], [])
        self.assertEqual(paid['practice']['activities'], [])
        status, response = self.mutation('submit')
        self.assertEqual((status, response.get('error')), (409, 'not_ready'))
        self.assertEqual(self.activity()[0], 200)
        self.assertEqual(len(self.read()[1]['completed']), 1)
        self.assertEqual(self.request('GET', 'projects/' + pid + '/learning', token=self.token('buyer'))[1]['completed'], free['completed'])


if __name__ == '__main__':
    before = frozen_hashes()
    names = [name for name in IndependentChecks.__dict__ if name.startswith('test_independent_')]
    suite = unittest.TestSuite(IndependentChecks(name) for name in names)
    with patch('core_commerce.StripeProvider', side_effect=AssertionError('Real payment provider forbidden in review')):
        result = unittest.TextTestRunner(verbosity=2).run(suite)
    unchanged = before == frozen_hashes()
    print(json.dumps(dict(scope='Independent local HTTP/SQLite checks; FakeProvider only', testsRun=result.testsRun,
        failures=len(result.failures), errors=len(result.errors), frozenFilesUnchanged=unchanged,
        repositoryChanges=False, realAccounts=False, realCharges=False, codeSha256=before)))
    sys.exit(not (result.wasSuccessful() and unchanged))
