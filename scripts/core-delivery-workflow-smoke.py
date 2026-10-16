"""Delivery/support/provenance HTTP checks plus 58 existing regressions."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime,timezone
import importlib.util
import json
import sys
import unittest
import uuid
spec=importlib.util.spec_from_file_location('acceptance_base',Path(__file__).with_name('core-acceptance-smoke.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
from core_server import Store
from core_backup import backup

class DeliveryTests(base.AcceptanceTests):
    def accepted_release(self,html=False):
        r=self.released(html);self.add_member('other','editor');status,result=self.review(r);self.assertEqual(status,200,result);self.p=result['project'];return r
    def delivery(self,action,token=None,key=None,**fields):
        status,result=self.write('projects/'+self.p['id']+'/delivery',dict(expectedVersion=self.p['version'],action=action,**fields),token,key)
        if status==200:self.p=result['project']
        return status,result
    def dashboard(self,token=None):return self.request('GET','projects/'+self.p['id']+'/delivery',token=token or self.owner['token'])
    def handoff(self,r=None):
        r=r or self.accepted_release();self.add_member('viewer','viewer');status,result=self.delivery('handoff',releaseId=r['id'],recipient='viewer',note='Open this immutable version, check the instructions and report problems.');self.assertEqual(status,200,result);return result['handoffId'],r
    def ticket(self,hid,token=None):
        status,result=self.delivery('ticket',token or self.viewer['token'],handoffId=hid,title='Problem opening the result',body='Steps: open the delivered result, compare the expected and actual output.');self.assertEqual(status,200,result);return result['ticketId']
    def conversation(self,tid,token=None):return self.request('GET','projects/'+self.p['id']+'/delivery/tickets/'+tid,token=token or self.owner['token'])
    def test_delivery_requires_business_and_positive_latest_review(self):
        self.assertEqual(self.dashboard()[0],400);r=self.released();self.add_member('viewer','viewer');self.assertEqual(self.delivery('handoff',releaseId=r['id'],recipient='viewer',note='Detailed instructions for the recipient account.')[0],409)
        self.add_member('other','editor');status,result=self.review(r);self.assertEqual(status,200);self.p=result['project'];self.assertEqual(self.delivery('handoff',releaseId=r['id'],recipient='viewer',note='Detailed instructions for the recipient account.')[0],200)
    def test_delivery_existing_members_only_and_no_access_grants(self):
        r=self.accepted_release();self.assertEqual(self.delivery('handoff',releaseId=r['id'],recipient='viewer',note='Detailed instructions for the recipient account.')[0],404)
        self.assertEqual(self.delivery('handoff',releaseId=r['id'],recipient='owner',note='Detailed instructions for the recipient account.')[0],400)
        self.add_member('viewer','viewer');self.assertEqual(self.delivery('handoff',self.viewer['token'],releaseId=r['id'],recipient='other',note='Detailed instructions for the recipient account.')[0],403)
        self.assertEqual(self.request('GET','projects/'+self.p['id'],token=self.viewer['token'])[1]['project']['role'],'viewer')
    def test_delivery_recipient_acknowledges_once_with_safe_retry(self):
        hid,r=self.handoff();self.assertEqual(self.delivery('acknowledge',handoffId=hid)[0],403)
        key=uuid.uuid4().hex;body=dict(expectedVersion=self.p['version'],action='acknowledge',handoffId=hid)
        status,result=self.write('projects/'+self.p['id']+'/delivery',body,self.viewer['token'],key);self.assertEqual(status,200,result);self.p=result['project'];self.assertEqual(result['project']['role'],'viewer')
        self.assertTrue(self.write('projects/'+self.p['id']+'/delivery',body,self.viewer['token'],key)[1]['replayed']);self.assertEqual(self.delivery('acknowledge',self.viewer['token'],handoffId=hid)[0],409)
        self.assertEqual(self.dashboard(self.viewer['token'])[1]['handoffs'][0]['status'],'acknowledged');self.assertEqual(self.write('projects/'+self.p['id'],dict(expectedVersion=self.p['version'],changes={'title':'Viewer cannot edit'}),self.viewer['token'])[0],403)
        self.add_member('viewer','remove');self.assertEqual(self.write('projects/'+self.p['id']+'/delivery',body,self.viewer['token'],key)[0],404)
    def test_delivery_duplicate_and_conflicting_requests_do_not_duplicate(self):
        hid,r=self.handoff();self.assertEqual(self.delivery('handoff',releaseId=r['id'],recipient='viewer',note='The same release must not create a second active handoff.')[0],409)
        body=dict(expectedVersion=self.p['version'],action='acknowledge',handoffId=hid)
        with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:self.write('projects/'+self.p['id']+'/delivery',body,self.viewer['token']),range(2)))
        self.assertEqual(sorted(v[0] for v in results),[200,409]);self.assertEqual(len(self.dashboard()[1]['handoffs']),1)
    def test_delivery_withdrawal_preserves_history_and_tickets(self):
        hid,r=self.handoff();tid=self.ticket(hid);self.assertEqual(self.delivery('withdraw',self.viewer['token'],handoffId=hid)[0],403);self.assertEqual(self.delivery('withdraw',handoffId=hid)[0],200)
        self.assertEqual(self.delivery('acknowledge',self.viewer['token'],handoffId=hid)[0],409);self.assertEqual(self.delivery('ticket',self.viewer['token'],handoffId=hid,title='Another request',body='A new ticket against a withdrawn handoff should fail.')[0],409)
        self.assertEqual(self.conversation(tid,self.viewer['token'])[0],200);self.assertEqual(self.delivery('reply',self.viewer['token'],ticketId=tid,body='Existing support remains available after handoff withdrawal.')[0],200)
        self.assertEqual(self.delivery('handoff',releaseId=r['id'],recipient='viewer',note='A replacement handoff with the same immutable release.')[0],200);self.assertEqual(len(self.dashboard()[1]['handoffs']),2)
    def test_delivery_revocation_blocks_recipient_and_shows_warning(self):
        hid,r=self.handoff();tid=self.ticket(hid);self.add_member('viewer','remove');self.assertEqual(self.dashboard(self.viewer['token'])[0],404);self.assertEqual(self.conversation(tid,self.viewer['token'])[0],404);self.assertEqual(self.delivery('acknowledge',self.viewer['token'],handoffId=hid)[0],404);self.assertFalse(self.dashboard()[1]['handoffs'][0]['recipientHasAccess'])
    def test_support_other_viewer_cannot_read_or_reply_to_ticket(self):
        hid,r=self.handoff();tid=self.ticket(hid)
        # Change the original reviewer to a viewer; their former editor role must not retain support access.
        self.add_member('other','viewer');self.assertEqual(self.dashboard(self.other['token'])[1]['tickets'],[]);self.assertEqual(self.dashboard(self.other['token'])[1]['handoffs'],[]);self.assertEqual(self.conversation(tid,self.other['token'])[0],404);self.assertEqual(self.delivery('reply',self.other['token'],ticketId=tid,body='An unrelated viewer must not post to this request.')[0],404)
        self.assertEqual(self.delivery('ticket',self.other['token'],handoffId=hid,title='Unrelated request',body='An unrelated viewer must not create this ticket.')[0],404)
    def test_support_lifecycle_records_messages_and_transitions(self):
        hid,_=self.handoff();tid=self.ticket(hid)
        self.assertEqual(self.delivery('ticket_status',self.viewer['token'],ticketId=tid,status='resolved',note='A viewer cannot claim the issue was resolved.')[0],403)
        self.assertEqual(self.delivery('ticket_status',ticketId=tid,status='active',note='Reproducing the reported problem now.')[0],200)
        self.assertEqual(self.delivery('reply',ticketId=tid,body='Please compare the exact release version and the expected output.')[0],200)
        self.assertEqual(self.delivery('ticket_status',ticketId=tid,status='resolved',note='Provided a reproducible workaround for this release.')[0],200)
        self.assertEqual(self.delivery('ticket_status',self.viewer['token'],ticketId=tid,status='closed',note='The workaround has solved my reported problem.')[0],200)
        self.assertEqual(self.delivery('reply',self.viewer['token'],ticketId=tid,body='Closed tickets require reopening first.')[0],409)
        self.assertEqual(self.delivery('ticket_status',self.viewer['token'],ticketId=tid,status='open',note='The same issue recurred on another input.')[0],200)
        t=self.conversation(tid)[1]['ticket'];self.assertEqual(len(t['messages']),2);self.assertEqual([v['toStatus'] for v in t['transitions']],['active','resolved','closed','open'])
    def test_support_invalid_fields_roll_back_atomically(self):
        hid,_=self.handoff();before=self.p['version']
        self.assertEqual(self.delivery('ticket',self.viewer['token'],handoffId=hid,title='short',body='bad')[0],400);self.assertEqual(self.dashboard()[1]['tickets'],[]);self.assertEqual(self.dashboard()[1]['projectVersion'],before)
        tid=self.ticket(hid);self.assertEqual(self.delivery('ticket_status',ticketId=tid,status='closed',note='An invalid transition from the open state.')[0],409);self.assertEqual(self.delivery('reply',ticketId=tid,body='short')[0],400);self.assertEqual(self.conversation(tid)[1]['ticket']['messageCount'],1)
        for action,field in [('acknowledge','handoffId'),('ticket','handoffId'),('reply','ticketId')]:
            self.assertEqual(self.delivery(action,**{field:{'invalid':'identifier'}})[0],400)
    def test_delivery_new_negative_review_is_visible_without_rewriting_receipt(self):
        hid,r=self.handoff();old=self.dashboard()[1]['handoffs'][0];status,result=self.review(r,False);self.assertEqual(status,200);self.p=result['project'];new=self.dashboard()[1]['handoffs'][0]
        self.assertEqual(old['reviewId'],new['reviewId']);self.assertEqual(new['latestReviewVerdict'],'needs_changes');self.assertFalse(new['reviewStillLatest']);self.assertEqual(self.delivery('acknowledge',self.viewer['token'],handoffId=hid)[0],200)
    def test_delivery_export_backup_and_restore_keep_scoped_history(self):
        hid,r=self.handoff();tid=self.ticket(hid);v=self.p['version'];self.delivery('reply',ticketId=tid,body='Support message stored in the server database.')
        export=self.request('GET','projects/'+self.p['id']+'/export',token=self.owner['token'])[1];self.assertEqual(len(export['delivery']['tickets'][0]['messages']),2);self.assertNotIn(self.owner['token'],json.dumps(export))
        copied=Path(self.tmp.name)/('delivery-'+uuid.uuid4().hex+'.sqlite3');backup(self.db,copied);restored=Store(copied);self.assertEqual(len(restored.get('projects/'+self.p['id']+'/delivery/tickets/'+tid,self.viewer['user']['id'])['ticket']['messages']),2)
        status,result=self.write('projects/'+self.p['id']+'/restore',dict(expectedVersion=self.p['version'],version=v));self.assertEqual(status,200);self.p=result['project'];self.assertEqual(self.conversation(tid)[1]['ticket']['messageCount'],2)
    def test_process_provenance_is_actual_and_private(self):
        r=self.accepted_release();status,result=self.write('templates',dict(projectId=self.p['id'],title='A process from participant-reviewed work'));self.assertEqual(status,200,result);template=result['template'];self.assertEqual(template['status'],'participant_reviewed_source');self.assertEqual(template['provenance']['releaseId'],r['id']);self.assertEqual(template['provenance']['reviewer'],'other')
        status,new=self.write('projects',dict(title='A new goal from a process',goal='Apply the same process to a new independent task.',templateId=template['id']));self.assertEqual(status,200,new);d=new['project']['data'];self.assertTrue(all(not x['done'] for x in d['acceptance']+d['tasks']));self.assertEqual(d['releases'],[]);self.assertFalse(d['accepted']);self.assertEqual(d['costs'],[])
        self.assertEqual(self.write('projects',dict(title='Foreign copy blocked',goal='Attempt to use another account process.',templateId=template['id']),self.other['token'])[0],404)
    def test_process_without_review_has_no_false_provenance(self):
        self.released();status,result=self.write('templates',dict(projectId=self.p['id'],title='Internal draft process'));self.assertEqual(status,200);self.assertEqual(result['template']['status'],'internal_review_only');self.assertIsNone(result['template']['provenance'])
    def test_delivery_integrity_and_disabled_consent(self):
        r=self.accepted_release(True);self.add_member('viewer','viewer')
        with self.server.store.transaction() as db:db.execute('UPDATE assets SET content=? WHERE project_id=?',('unexpected content',self.p['id']))
        self.assertEqual(self.delivery('handoff',releaseId=r['id'],recipient='viewer',note='A damaged file should block a new delivery.')[0],409)
        self.update({'consents':dict(learning=True,studio=True,business=False)});self.assertEqual(self.dashboard()[0],400);self.assertEqual(self.delivery('handoff',releaseId=r['id'],recipient='viewer',note='A disabled module cannot receive the project context.')[0],400)

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(DeliveryTests))
    report=dict(scope='Real HTTP/SQLite delivery, support and process provenance tests plus 58 regressions; no browser QA, payments or external delivery',status='passed' if result.wasSuccessful() else 'failed',testsRun=result.testsRun,failures=len(result.failures),errors=len(result.errors),generatedAt=datetime.now(timezone.utc).isoformat(),externalMessagesSent=False,paymentsTested=False)
    (Path(__file__).resolve().parents[1]/'docs/DELIVERY-WORKFLOW-TESTS.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');sys.exit(0 if result.wasSuccessful() else 1)
