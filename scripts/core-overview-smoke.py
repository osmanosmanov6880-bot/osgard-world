"""Operational snapshot and runtime checks plus 72 Core regressions."""
from pathlib import Path
from datetime import datetime,timezone
import importlib.util
import json
import sqlite3
import statistics
import sys
import threading
import time
import unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('delivery_base',Path(__file__).with_name('core-delivery-workflow-smoke.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
from core_server import QueueWorker

class OverviewTests(base.DeliveryTests):
    baseline=None
    def ops_overview(self,token=None):return self.request('GET','overview',token=token or self.owner['token'])
    def item(self,report):return next(p for p in report['projects'] if p['id']==self.p['id'])
    def test_overview_access_and_revocation(self):
        self.assertEqual(self.request('GET','overview')[0],401);self.assertFalse(any(p['id']==self.p['id'] for p in self.ops_overview(self.other['token'])[1]['projects']))
        self.add_member('viewer','viewer');self.assertTrue(any(p['id']==self.p['id'] for p in self.ops_overview(self.viewer['token'])[1]['projects']));self.add_member('viewer','remove');self.assertFalse(any(p['id']==self.p['id'] for p in self.ops_overview(self.viewer['token'])[1]['projects']))
    def test_overview_empty_does_not_invent_runtime_health(self):
        account=self.account();status,r=self.ops_overview(account['token']);self.assertEqual(status,200);self.assertEqual(r['projects'],[]);self.assertEqual(r['currencies'],{});self.assertFalse(r['runtime']['workerRegistered']);self.assertIsNone(r['runtime']['workerAlive']);self.assertIsNone(r['runtime']['storageHealthy'])
    def test_overview_personal_learning_is_versioned(self):
        self.enable()
        self.update({'accepted':True});r=self.item(self.ops_overview()[1]);self.assertEqual(r['learning']['myCurrentPractices'],0);self.assertEqual(r['nextAction']['stage'],'campus')
        self.activity();self.assertEqual(self.item(self.ops_overview()[1])['learning']['myCurrentPractices'],1);self.add_member('other','editor');self.assertEqual(self.item(self.ops_overview(self.other['token'])[1])['learning']['myCurrentPractices'],0)
    def test_overview_currency_totals_are_separate_and_module_scoped(self):
        self.update({'currency':'EUR','budgetMinor':10000,'consents':dict(learning=False,studio=False,business=True)});self.update({'accepted':True});status,result=self.act('record_cost',dict(amountMinor=1200,category='other',note='User-entered expense fixture'));self.assertEqual(status,200);self.p=result['project']
        r=self.ops_overview()[1];item=self.item(r);self.assertEqual(item['economics']['currency'],'EUR');self.assertEqual(item['economics']['costMinor'],1200);self.assertGreaterEqual(r['currencies']['EUR']['costMinor'],1200);self.assertEqual(r['currencies']['EUR']['confirmedRevenueMinor'],0)
        self.update({'consents':dict(learning=False,studio=False,business=False)});r=self.item(self.ops_overview()[1]);self.assertIsNone(r['economics']);self.assertIsNone(r['learning']);self.assertIsNone(r['delivery']);self.assertEqual(r['jobs'],dict(queued=0,running=0,completed=0,failed=0))
    def test_overview_later_changes_are_not_covered_by_release_review(self):
        self.accepted_release();self.update({'consents':dict(learning=False,studio=True,business=True)});self.update({'accepted':True});item=self.item(self.ops_overview()[1]);self.assertTrue(item['latestRelease']['matchesCurrentArtifactAndScope']);self.assertEqual(item['nextAction']['stage'],'delivery')
        self.update({'title':'The result has changed after review'});self.update({'accepted':True});item=self.item(self.ops_overview()[1]);self.assertFalse(item['latestRelease']['matchesCurrentArtifactAndScope']);self.assertIn('unreleased_changes',item['issues']);self.assertEqual(item['nextAction']['stage'],'studio')
    def test_overview_viewer_receipt_and_private_support(self):
        hid,_=self.handoff();tid=self.ticket(hid);viewer=self.item(self.ops_overview(self.viewer['token'])[1]);self.assertEqual(viewer['nextAction']['stage'],'delivery');self.assertEqual(viewer['delivery']['pendingReceipts'],1);self.assertEqual(viewer['delivery']['openTickets'],1)
        self.add_member('other','viewer');other=self.item(self.ops_overview(self.other['token'])[1]);self.assertEqual(other['delivery']['openTickets'],0);self.assertEqual(other['delivery']['pendingReceipts'],0)
        raw=json.dumps(self.ops_overview()[1]);self.assertNotIn('expected and actual output',raw);self.assertNotIn(self.owner['token'],raw);self.assertNotIn('password_hash',raw);self.assertNotIn('code_hash',raw)
    def test_overview_queue_and_expired_sources_are_observations(self):
        self.ready();self.update({'sources':[dict(id='expired',title='Old source',url='https://example.com',notes='Private source body must not enter the overview',checkedAt='',expiresAt='2020-01-01T00:00:00Z')]});self.update({'accepted':True})
        status,result=self.write('projects/'+self.p['id']+'/jobs',dict(expectedVersion=self.p['version']));self.assertEqual(status,200,result);r=self.item(self.ops_overview()[1]);self.assertEqual(r['expiredSourceCount'],1);self.assertIn('expired_sources',r['issues']);self.assertEqual(r['jobs']['queued'],1);self.assertEqual(r['nextAction']['stage'],'memory');self.assertNotIn('Private source body',json.dumps(self.ops_overview()[1]))
    def test_overview_contract_is_the_first_editor_action(self):
        r=self.item(self.ops_overview()[1]);self.assertEqual(r['nextAction']['stage'],'contract');self.assertFalse(self.ops_overview()[1]['limits']['actualPilotConfirmed']);self.assertFalse(self.ops_overview()[1]['limits']['fieldCoreWebVitals'])
    def test_overview_registered_worker_reports_recovered_storage_error(self):
        worker=QueueWorker(self.server.store);failed=threading.Event();recovered=threading.Event();calls=[0]
        def cycle():
            calls[0]+=1
            if calls[0]==1:failed.set();raise sqlite3.OperationalError('synthetic storage outage, not disclosed')
            recovered.set();return False
        previous=self.server.worker;self.server.worker=worker
        try:
            with patch.object(worker,'run_one',side_effect=cycle):
                worker.start();self.assertTrue(failed.wait(2));self.assertTrue(recovered.wait(3));status,r=self.ops_overview();self.assertEqual(status,200);self.assertTrue(r['runtime']['workerAlive']);self.assertTrue(r['runtime']['storageHealthy']);self.assertEqual(r['runtime']['storageErrorsSinceStart'],1);self.assertIsNotNone(r['runtime']['lastCycleAt']);self.assertNotIn('synthetic storage outage',json.dumps(r));worker.stop();worker.join(3)
        finally:
            worker.stop();worker.join(3);self.server.worker=previous
    def test_overview_local_latency_baseline_is_not_field_performance(self):
        durations=[];count=0
        for _ in range(12):
            started=time.perf_counter();status,r=self.ops_overview();durations.append((time.perf_counter()-started)*1000);self.assertEqual(status,200);count=len(r['projects'])
        ordered=sorted(durations);OverviewTests.baseline=dict(scope='Loopback HTTP overview in temporary regression database, serial requests; not mobile, browser, production or user task speed',samples=len(durations),visibleProjects=count,p50Milliseconds=round(statistics.median(durations),2),p95Milliseconds=round(ordered[min(len(ordered)-1,int(len(ordered)*.95))],2))

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(OverviewTests))
    report=dict(scope='Operational overview and runtime HTTP checks plus 72 regressions; no browser QA or real pilot',status='passed' if result.wasSuccessful() else 'failed',testsRun=result.testsRun,failures=len(result.failures),errors=len(result.errors),generatedAt=datetime.now(timezone.utc).isoformat(),localBaseline=OverviewTests.baseline,externalMessagesSent=False,paymentsTested=False)
    (Path(__file__).resolve().parents[1]/'docs/CORE-OVERVIEW-TESTS.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');sys.exit(0 if result.wasSuccessful() else 1)
