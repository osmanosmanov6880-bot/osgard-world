#!/usr/bin/env python3
"""Program Commerce HTTP/SQLite integration; FakeProvider only, no Stripe network."""
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch
import copy
import importlib.util
import json
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('commerce_fixtures', ROOT/'scripts/core-commerce-smoke.py')
base = importlib.util.module_from_spec(spec); spec.loader.exec_module(base)
from core_server import Store
from core_commerce import Config
import core_learning
import core_programs


class ProgramCommerceTests(unittest.TestCase):
    setUpClass = classmethod(base.CommerceTests.setUpClass.__func__)
    tearDownClass = classmethod(base.CommerceTests.tearDownClass.__func__)
    request = classmethod(base.CommerceTests.request.__func__)
    setUp = base.CommerceTests.setUp
    token = base.CommerceTests.token
    write = base.CommerceTests.write
    route = base.CommerceTests.route
    update = base.CommerceTests.update
    action = base.CommerceTests.action
    checkout = base.CommerceTests.checkout
    event = base.CommerceTests.event
    post_event = base.CommerceTests.post_event
    purchase = base.CommerceTests.purchase
    file = base.CommerceTests.file
    pay = base.CommerceTests.pay
    refund = base.CommerceTests.refund

    def prepare(self, buyer='commerce-buyer'):
        self.update(dict(currency='USD', budgetMinor=20000, consents=dict(learning=False, studio=False, business=True),
                         allowedActions=['local_checks', 'prepare_offer'], offer=dict(title='Program test offer', customer=buyer,
                         scope='Synthetic integration amount only; no human mentor.', amountMinor=1000)))
        self.update({'accepted': True})
        draft = self.action('create_order')['result']
        self.program = self.request('GET', 'learning/programs', token=self.token())[1]['program']
        self.preparation = dict(expectedVersion=self.project['version'], draftOrderId=draft['id'], kind='learning_program',
                                buyerUsername=buyer, confirmedAmountMinor=1000, confirmedCurrency='USD', sharingAcknowledged=True,
                                programId=self.program['programId'], programVersion=self.program['version'], policyVersion=self.program['policyVersion'])
        status, value = self.write(self.route('/commerce'), self.preparation)
        self.assertEqual(status, 200, value); self.order = value['order']; return value

    def enrollment_route(self, suffix=''):
        return 'learning/enrollments/' + self.order['id'] + suffix

    def read(self, person='buyer', suffix=''):
        return self.request('GET', self.enrollment_route(suffix), token=self.token(person))

    def activate(self, key=None, person='buyer'):
        return self.write(self.enrollment_route(), dict(action='activate', learningConsent=True,
                          goal='Create a useful practical result and document its verification.'), person, key)

    def mutation(self, action, **payload):
        current = self.read()[1]
        return self.write(self.enrollment_route(), dict(action=action, expectedVersion=current['version'], **payload), 'buyer')

    def activity(self, index=0, correct=True):
        lesson = self.read()[1]['curriculum']['lessons'][index]
        answer = lesson['ru']['check']['correctIndex']
        return self.mutation('activity', slug=lesson['slug'], locale='ru', answer=answer if correct else (answer+1)%len(lesson['ru']['check']['options']),
                             practice='Private learner contribution: concrete exercise with evidence and limitations.')

    def refund_event(self, target):
        status, value = self.refund(target); self.assertEqual(status, 200, value)
        refund = list(self.provider.refunds.values())[-1]
        status, value = self.post_event(self.event('refund.updated', refund)); self.assertEqual(status, 200, value)

    def test_disabled_program_and_free_curriculum_unchanged(self):
        self.prepare(); free = copy.deepcopy(core_learning.CURRICULUM)
        self.server.store.commerce.config = replace(self.config, enabled=False)
        self.assertEqual(self.checkout()[0], 503)
        status, catalog = self.request('GET', 'learning/programs', token=self.token('buyer'))
        self.assertEqual(status, 200); self.assertFalse(catalog['configuration']['enabled'])
        self.assertFalse(catalog['program']['mentorIncluded']); self.assertEqual(catalog['program']['freeModule'], '/learning/program')
        self.assertEqual(self.request('GET', 'curriculum', token=self.token('buyer'))[1], free)
        self.assertEqual(self.provider.checkout_creates, 0)

    def test_server_version_price_and_kind_binding(self):
        self.prepare(); self.assertEqual(self.order['kind'], 'learning_program')
        for changes in ({'programVersion':'0'*64}, {'policyVersion':'unsupported'}, {'programId':'unrelated'}, {'confirmedAmountMinor':999}):
            self.assertIn(self.write(self.route('/commerce'), dict(self.preparation, **changes))[0], (400,409))
        self.assertEqual(self.file()[0], 409)
        self.assertEqual(self.read('stranger')[0], 404)
        self.assertEqual(self.activate(person='stranger')[0], 404)
        self.assertEqual(self.request('GET', self.route(), token=self.token('buyer'))[0], 404)

    def test_unpaid_pending_return_url_and_free_progress_do_not_grant(self):
        self.prepare(); self.checkout(); session = next(iter(self.provider.sessions.values()))
        self.assertEqual(self.activate()[0], 403)
        self.assertEqual(self.post_event(self.event('checkout.session.completed', session))[0], 200)
        self.assertEqual(self.read()[1]['status'], 'payment_required')
        self.assertNotIn('curriculum', self.read()[1])
        self.assertEqual(self.request('GET', 'commerce/purchases?checkout=returned', token=self.token('buyer'))[0], 200)
        self.assertEqual(self.activate()[0], 403)
        self.assertEqual(self.write('projects', dict(title='Free learner project', goal='A free project continues without any program payment.'), 'buyer')[0], 200)

    def test_paid_activation_requires_consent_and_is_private(self):
        self.pay()
        self.assertEqual(self.write(self.enrollment_route(), dict(action='activate', goal='A sufficiently long goal.'), 'buyer')[0], 400)
        status, value = self.activate(); self.assertEqual(status, 200, value)
        student_project = value['projectId']
        self.assertEqual(self.read()[1]['status'], 'active')
        self.assertEqual(self.read('merchant')[0], 404)
        self.assertEqual(self.request('GET', 'projects/'+student_project, token=self.token('merchant'))[0], 404)
        self.assertEqual(self.request('GET', 'projects/'+student_project, token=self.token('stranger'))[0], 404)
        self.assertFalse(self.read()[1]['program']['mentorIncluded'])
        self.assertEqual(self.activity()[0], 200)
        free = self.request('GET', 'projects/'+student_project+'/learning', token=self.token('buyer'))[1]
        self.assertEqual(free['activities'], []); self.assertEqual(free['completed'], [])

    def test_lost_activation_response_restart_and_concurrency_create_one_project(self):
        self.pay(); key = uuid.uuid4().hex
        first = self.activate(key); self.assertEqual(first[0], 200)
        self.server.store = Store(self.database, self.config, self.provider)
        second = self.activate(key); self.assertEqual(second[0], 200); self.assertTrue(second[1]['replayed'])
        self.assertEqual(second[1]['projectId'], first[1]['projectId'])
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda _: self.activate(), range(4)))
        self.assertTrue(all(status==200 and value['projectId']==first[1]['projectId'] for status,value in results))
        with self.server.store.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM program_enrollments WHERE order_id=?', (self.order['id'],)).fetchone()[0], 1)

    def test_purchased_curriculum_pinned_across_updates(self):
        self.pay(); self.activate(); old = self.read()[1]
        modified = copy.deepcopy(core_learning.CURRICULUM)
        modified['lessons'][0]['ru']['check']['correctIndex'] = (modified['lessons'][0]['ru']['check']['correctIndex']+1)%3
        modified['lessons'][0]['ru']['example'] = 'A later program edition should not replace a purchased edition.'
        with patch.object(core_learning, 'CURRICULUM', modified):
            self.assertNotEqual(core_programs.current_program()['version'], old['program']['version'])
            self.assertEqual(self.read()[1]['curriculum'], old['curriculum'])
            self.assertEqual(self.activity()[1]['feedback']['passed'], True)
            self.assertEqual(self.write(self.route('/commerce'), self.preparation)[0], 409)

    def test_attempt_and_submission_versions_and_frozen_result(self):
        self.pay(); self.activate()
        self.assertEqual(self.mutation('submit')[0], 409)
        self.assertFalse(self.activity(correct=False)[1]['feedback']['passed'])
        self.assertEqual(self.read()[1]['completed'], [])
        old_version = self.read()[1]['version']
        for index in range(8):self.assertEqual(self.activity(index)[0], 200)
        self.assertEqual(self.write(self.enrollment_route(), dict(action='save_work', expectedVersion=old_version, work={}), 'buyer')[0], 409)
        work = {key:'A concrete original result and evidence on a different task.' for key in core_programs.WORK_FIELDS}
        self.assertEqual(self.mutation('save_work', work=work)[0], 200)
        self.assertEqual(self.mutation('submit')[0], 200)
        frozen = self.read()[1]['practice']['submissions'][0]
        self.assertFalse(frozen['snapshot']['mentorAssigned'])
        self.assertEqual(frozen['snapshot']['verification'], 'learner_submission_not_independent_assessment')
        self.mutation('save_work', work={key:'Changed current work does not modify the prior submission.' for key in core_programs.WORK_FIELDS})
        self.assertEqual(self.read()[1]['practice']['submissions'][0], frozen)

    def test_refund_revokes_paid_routes_and_retry_but_preserves_owned_export(self):
        session = self.pay(); activation_key = uuid.uuid4().hex; self.activate(activation_key); self.activity()
        before = self.read(suffix='/export')[1]
        self.refund_event(300); self.assertEqual(self.read()[1]['status'], 'active')
        self.refund_event(1000)
        self.assertEqual(self.read()[1]['status'], 'refunded'); self.assertNotIn('curriculum', self.read()[1])
        self.assertEqual(self.activate(activation_key)[0], 403)
        self.assertEqual(self.write(self.enrollment_route(), dict(action='save_work', expectedVersion=before['version'], work={}), 'buyer')[0], 403)
        self.assertEqual(self.post_event(self.event('checkout.session.async_payment_succeeded', session))[0], 200)
        self.assertEqual(self.read()[1]['status'], 'refunded')
        self.assertEqual(self.read(suffix='/export')[1], before)
        self.assertEqual(self.read('stranger', '/export')[0], 404)
        status, exported = self.request('GET', 'projects/'+before['projectId']+'/export', token=self.token('buyer'))
        self.assertEqual(status, 200, exported); self.assertEqual(exported['programWork']['activities'], before['activities'])

    def test_consent_revocation_and_team_access_do_not_bypass_program(self):
        self.pay(); key=uuid.uuid4().hex; self.activate(key); self.activity()
        private = self.read(suffix='/export')[1]; project = private['project']; pid = project['id']
        status, changed = self.write('projects/'+pid+'/members', dict(expectedVersion=project['version'], username='commerce-reviewer', role='editor'), 'buyer')
        self.assertEqual(status, 200, changed)
        self.assertEqual(self.read('reviewer')[0], 404); self.assertEqual(self.read('reviewer','/export')[0], 404)
        changes = dict(consents=dict(learning=False, studio=False, business=False))
        self.assertEqual(self.write('projects/'+pid, dict(expectedVersion=changed['project']['version'], changes=changes), 'buyer')[0], 200)
        self.assertEqual(self.read()[1]['status'], 'consent_required'); self.assertNotIn('curriculum', self.read()[1])
        self.assertEqual(self.activate(key)[0], 403)
        self.assertEqual(self.read(suffix='/export')[0], 200)

    def test_pending_refund_does_not_revoke_confirmed_program_access(self):
        self.pay(); self.activate(); self.activity()
        self.assertEqual(self.refund(1000)[0], 200)
        refund = list(self.provider.refunds.values())[-1]
        refund['status'] = 'pending'
        self.assertEqual(self.post_event(self.event('refund.updated', refund))[0], 200)
        self.assertEqual(self.read()[1]['status'], 'active')
        refund['status'] = 'succeeded'
        self.assertEqual(self.post_event(self.event('refund.updated', refund))[0], 200)
        self.assertEqual(self.read()[1]['status'], 'refunded')

    def test_full_refund_before_activation_and_late_paid_never_enroll(self):
        session = self.pay(); self.refund_event(1000)
        self.assertEqual(self.post_event(self.event('checkout.session.async_payment_succeeded', session))[0], 200)
        self.assertEqual(self.activate()[0], 403)
        self.assertFalse(self.read()[1]['exportAvailable'])
        with self.server.store.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM program_enrollments WHERE order_id=?', (self.order['id'],)).fetchone()[0], 0)

    def test_pause_identity_and_corruption_fail_closed(self):
        self.pay(); self.activate(); self.activity()
        self.server.store.commerce.config = replace(self.config, enabled=False)
        self.assertEqual(self.read()[1]['status'], 'active')
        self.server.store.commerce.config = replace(self.config, enabled=False, account_id='acct_unrelated')
        self.assertEqual(self.read()[0], 409); self.assertEqual(self.read(suffix='/export')[0], 200)
        self.server.store.commerce.config = self.config
        with self.server.store.transaction() as db:
            original = db.execute('SELECT envelope FROM commerce_orders WHERE id=?', (self.order['id'],)).fetchone()['envelope']
            db.execute("UPDATE commerce_orders SET envelope=envelope||' ' WHERE id=?", (self.order['id'],))
        try:
            self.assertEqual(self.read()[0], 409); self.assertEqual(self.read(suffix='/export')[0], 200)
        finally:
            with self.server.store.transaction() as db:
                db.execute('UPDATE commerce_orders SET envelope=? WHERE id=?', (original,self.order['id']))

    def test_lost_checkout_and_webhook_replay_share_one_entitlement(self):
        self.prepare(); self.provider.lose_checkout = True; key = uuid.uuid4().hex
        self.assertEqual(self.checkout(key)[0], 503)
        self.server.store = Store(self.database, self.config, self.provider)
        self.assertEqual(self.checkout(key)[0], 200); self.assertEqual(self.provider.checkout_creates, 1)
        session = self.provider.settle(self.order['id']); event = self.event('checkout.session.completed', session)
        self.assertEqual(self.post_event(event)[0], 200); self.assertTrue(self.post_event(event)[1]['replayed'])
        self.assertEqual(self.activate()[0], 200)
        with self.server.store.connect() as db:
            self.assertEqual(db.execute('SELECT COUNT(*) FROM commerce_entitlements WHERE order_id=?', (self.order['id'],)).fetchone()[0], 1)

    def test_html_orders_remain_downloads_not_programs(self):
        base.CommerceTests.prepare(self); self.checkout(); session = self.provider.settle(self.order['id'])
        self.assertEqual(self.post_event(self.event('checkout.session.completed', session))[0], 200)
        self.assertEqual(self.file()[0], 200); self.assertEqual(self.purchase()['kind'], 'html_release')
        self.assertEqual(self.read()[0], 409); self.assertEqual(self.activate()[0], 409)


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(ProgramCommerceTests))
    print(json.dumps(dict(scope='local HTTP/SQLite with FakeProvider', testsRun=result.testsRun, failures=len(result.failures),
                         errors=len(result.errors), liveStripeTest=False, realRevenueVerified=False)))
    sys.exit(not result.wasSuccessful())
