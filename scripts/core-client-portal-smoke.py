"""Isolated recipient API tests plus 82 Core regressions. No external delivery or payments."""
from pathlib import Path
from datetime import datetime,timezone
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
import sys
import unittest
import uuid
spec=importlib.util.spec_from_file_location('overview_base',Path(__file__).with_name('core-overview-smoke.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
from core_backup import backup
from core_server import Store

class PortalTests(base.OverviewTests):
    def shared(self,html=False):
        r=self.accepted_release(html);a=self.account();body=dict(expectedVersion=self.p['version'],releaseId=r['id'],recipient=a['username'],title='Recipient-facing result',description='Only the intended description goes to the recipient.',instructions='Open the supplied file and ask for help in this delivery.',sharingAcknowledged=True)
        status,result=self.write('projects/'+self.p['id']+'/client-deliveries',body);self.assertEqual(status,200,result);self.p=result['project'];return result['deliveryId'],a,r,body
    def client_packet(self,did,token=None):return self.request('GET','deliveries/'+did,token=token or self.owner['token'])
    def client_action(self,did,token=None,key=None,body=None,**fields):
        token=token or self.owner['token'];version=self.client_packet(did,token)[1]['delivery']['version'];return self.write('deliveries/'+did,body or dict(expectedVersion=version,**fields),token,key)
    def test_client_recipient_has_no_project_membership_or_internal_endpoints(self):
        did,a,_,_=self.shared();p=self.client_packet(did,a['token'])[1]['delivery'];self.assertEqual(p['role'],'recipient');self.assertEqual(self.item(self.ops_overview()[1])['clientDeliveryCounts']['active'],1);self.assertFalse(p['limits']['projectAccess']);self.assertEqual(self.request('GET','projects/'+self.p['id'],token=a['token'])[0],404);self.assertEqual(self.request('GET','projects/'+self.p['id']+'/export',token=a['token'])[0],404);self.assertFalse(any(v['id']==self.p['id'] for v in self.request('GET','projects',token=a['token'])[1]['projects']));self.assertFalse(any(v['id']==self.p['id'] for v in self.ops_overview(a['token'])[1]['projects']))
        self.assertEqual(self.request('GET','projects/'+self.p['id']+'/client-deliveries',token=a['token'])[0],404)
    def test_client_packet_is_redacted_and_source_changes_do_not_rewrite_it(self):
        self.update({'decisions':[dict(id=uuid.uuid4().hex,text='SECRET-INTERNAL-DECISION',at='2026-01-01T00:00:00Z')]})
        did,a,_,_=self.shared();before=self.client_packet(did,a['token'])[1];raw=json.dumps(before);self.assertNotIn('SECRET-INTERNAL-DECISION',raw);self.assertNotIn(self.p['id'],raw);self.assertNotIn('budgetMinor',raw);self.assertNotIn('sources',raw);self.assertNotIn(self.owner['token'],raw)
        self.update({'title':'CHANGED-PRIVATE-TITLE'});self.assertEqual(before['delivery']['materials'],self.client_packet(did,a['token'])[1]['delivery']['materials'])
    def test_client_explicit_sharing_and_positive_review_required(self):
        r=self.released();a=self.account();body=dict(expectedVersion=self.p['version'],releaseId=r['id'],recipient=a['username'],title='Shared result',description='A recipient-facing description with no private context.',instructions='Open the material and record any questions in this thread.',sharingAcknowledged=False)
        self.assertEqual(self.write('projects/'+self.p['id']+'/client-deliveries',body)[0],400);body['sharingAcknowledged']=True;self.assertEqual(self.write('projects/'+self.p['id']+'/client-deliveries',body)[0],409)
        self.add_member('viewer','viewer');body['expectedVersion']=self.p['version'];self.assertEqual(self.write('projects/'+self.p['id']+'/client-deliveries',body,self.viewer['token'])[0],403)
    def test_client_unrelated_account_and_project_viewer_are_denied(self):
        did,a,_,_=self.shared();foreign=self.account();self.assertEqual(self.client_packet(did,foreign['token'])[0],404);self.add_member('viewer','viewer');self.assertEqual(self.client_packet(did,self.viewer['token'])[0],403);self.assertEqual(self.request('GET','deliveries',token=foreign['token'])[1]['deliveries'],[])
    def test_client_receipt_retry_and_revoke_recheck(self):
        did,a,_,_=self.shared();body=dict(expectedVersion=1,action='acknowledge');key=uuid.uuid4().hex
        self.assertEqual(self.write('deliveries/'+did,body,a['token'],key)[0],200);self.assertTrue(self.write('deliveries/'+did,body,a['token'],key)[1]['replayed']);self.assertEqual(self.client_action(did,a['token'],action='revoke',body=None)[0],403)
        version=self.client_packet(did)[1]['delivery']['version'];self.assertEqual(self.write('deliveries/'+did,dict(expectedVersion=version,action='revoke',body='Access withdrawn at the sender request.'))[0],200)
        self.assertEqual(self.client_packet(did,a['token'])[0],404);self.assertEqual(self.write('deliveries/'+did,body,a['token'],key)[0],404);self.assertEqual(self.request('GET','deliveries',token=a['token'])[1]['deliveries'],[]);self.assertEqual(self.client_packet(did)[1]['delivery']['status'],'revoked')
    def test_client_concurrent_receipt_has_one_commit(self):
        did,a,_,_=self.shared();body=dict(expectedVersion=1,action='acknowledge')
        with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:self.write('deliveries/'+did,body,a['token']),range(2)))
        self.assertEqual(sorted(v[0] for v in results),[200,409]);self.assertEqual(len(self.client_packet(did,a['token'])[1]['delivery']['history']),1)
    def test_client_support_lifecycle_without_project_access(self):
        did,a,_,_=self.shared()
        def action(token,kind,**fields):
            p=self.client_packet(did,token)[1]['delivery'];return self.write('deliveries/'+did,dict(expectedVersion=p['version'],action=kind,**fields),token)
        self.assertEqual(action(a['token'],'message',body='The supplied result has an issue on this example.')[0],200);self.assertEqual(action(a['token'],'support_status',status='resolved',body='Recipient cannot declare the team solution.')[0],403);self.assertEqual(action(self.owner['token'],'support_status',status='active',body='Reproducing the received example now.')[0],200);self.assertEqual(action(self.owner['token'],'message',body='Here are the steps to resolve the reported problem.')[0],200);self.assertEqual(action(self.owner['token'],'support_status',status='resolved',body='A reproducible workaround is now available.')[0],200);self.assertEqual(action(a['token'],'support_status',status='closed',body='The provided workaround resolves my example.')[0],200);self.assertEqual(action(a['token'],'message',body='Closed support must be reopened first.')[0],409);self.assertEqual(action(a['token'],'support_status',status='open',body='The issue recurred with a different input.')[0],200);self.assertEqual(self.client_packet(did,a['token'])[1]['delivery']['supportStatus'],'open')
    def test_client_copied_html_integrity_and_private_snapshot_separation(self):
        did,a,_,_=self.shared(True);p=self.client_packet(did,a['token'])[1]['delivery'];self.assertTrue(p['materials']['integrityMatches']);html=p['materials']['html']
        with self.server.store.transaction() as db:db.execute('UPDATE assets SET content=? WHERE project_id=?',('changed after delivery',self.p['id']))
        after=self.client_packet(did,a['token'])[1]['delivery'];self.assertEqual(after['materials']['html'],html);self.assertTrue(after['materials']['integrityMatches']);self.assertNotIn('snapshot',after)
    def test_client_staff_revocation_and_business_consent(self):
        did,a,_,_=self.shared();self.assertEqual(self.client_packet(did,self.other['token'])[0],200);self.add_member('other','remove');self.assertEqual(self.client_packet(did,self.other['token'])[0],404);self.update({'consents':dict(learning=True,studio=True,business=False)});self.assertEqual(self.client_packet(did,a['token'])[0],404);self.assertEqual(self.request('GET','deliveries',token=a['token'])[1]['deliveries'],[])
    def test_client_export_backup_restore_preserve_packet_and_messages(self):
        did,a,_,_=self.shared();self.assertEqual(self.write('deliveries/'+did,dict(expectedVersion=1,action='message',body='This record must survive the database backup.'),a['token'])[0],200)
        export=self.request('GET','projects/'+self.p['id']+'/export',token=self.owner['token'])[1];self.assertEqual(export['clientDeliveries'][0]['id'],did);self.assertEqual(len(export['clientDeliveries'][0]['history']),1)
        copied=Path(self.tmp.name)/('client-'+uuid.uuid4().hex+'.sqlite3');backup(self.db,copied);restored=Store(copied);self.assertEqual(len(restored.get('deliveries/'+did,a['user']['id'])['delivery']['history']),1)
        self.add_member('viewer','viewer');self.assertEqual(self.request('GET','projects/'+self.p['id']+'/export',token=self.viewer['token'])[1]['clientDeliveries'],[])
    def test_client_duplicate_sharing_and_validation_are_atomic(self):
        did,a,r,body=self.shared();body['expectedVersion']=self.p['version'];self.assertEqual(self.write('projects/'+self.p['id']+'/client-deliveries',body)[0],409);self.assertEqual(self.write('deliveries/'+did,dict(expectedVersion=1,action='message',body='bad'),a['token'])[0],400);self.assertEqual(self.client_packet(did,a['token'])[1]['delivery']['version'],1)
    def test_client_owner_can_export_revoked_delivery_addressed_to_owner(self):
        r=self.accepted_release();body=dict(expectedVersion=self.p['version'],releaseId=r['id'],recipient='owner',title='Delivery to owner',description='Explicitly selected material for the project owner.',instructions='The owner receives this envelope as a recipient.',sharingAcknowledged=True)
        status,result=self.write('projects/'+self.p['id']+'/client-deliveries',body,self.other['token']);self.assertEqual(status,200,result);self.p=result['project'];did=result['deliveryId'];self.assertEqual(self.write('deliveries/'+did,dict(expectedVersion=1,action='revoke',body='Withdrawing this envelope while retaining the project history.'),self.other['token'])[0],200);self.assertEqual(self.request('GET','projects/'+self.p['id']+'/export',token=self.owner['token'])[0],200)

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(PortalTests))
    report=dict(scope='Isolated recipient HTTP/SQLite tests plus 82 regressions; not browser QA, payments or external delivery',status='passed' if result.wasSuccessful() else 'failed',testsRun=result.testsRun,failures=len(result.failures),errors=len(result.errors),generatedAt=datetime.now(timezone.utc).isoformat(),externalMessagesSent=False,paymentsTested=False,localBaseline=base.OverviewTests.baseline)
    (Path(__file__).resolve().parents[1]/'docs/CLIENT-PORTAL-TESTS.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');sys.exit(0 if result.wasSuccessful() else 1)
