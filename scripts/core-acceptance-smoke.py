"""Studio acceptance HTTP/SQLite checks plus 48 account, pilot and Core regressions."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime,timezone
import importlib.util
import json
import sys
import unittest
import uuid
spec=importlib.util.spec_from_file_location('account_base',Path(__file__).with_name('core-account-smoke.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
from core_backup import backup
from core_server import Store

class AcceptanceTests(base.AccountTests):
    def released(self,html=False):
        self.ready()
        if html:
            self.update({'allowedActions':['local_checks','build_preview']});self.update({'accepted':True})
            status,result=self.act('build_preview');self.assertEqual(status,200,result);self.p=result['project']
        status,result=self.act('release');self.assertEqual(status,200,result);self.p=result['project'];return result['result']
    def releases(self,token=None):return self.request('GET','projects/'+self.p['id']+'/releases',token=token or self.owner['token'])
    def packet(self,r,token=None):return self.request('GET','projects/'+self.p['id']+'/releases/'+r['id'],token=token or self.owner['token'])
    def review_body(self,r,passed=True):return dict(expectedVersion=self.p['version'],releaseId=r['id'],criteria=[dict(id='test',passed=passed,evidence='Checked a new example and recorded the observed result.')],note='Participant conclusion with reproducible steps and limitations.')
    def review(self,r,passed=True,token=None,key=None,body=None):return self.write('projects/'+self.p['id']+'/release-review',body or self.review_body(r,passed),token or self.other['token'],key)
    def test_release_packet_is_frozen_and_scoped(self):
        r=self.released(True);packet=self.packet(r)[1];oldtitle=packet['snapshot']['title'];html=packet['asset']['html'];self.assertTrue(packet['asset']['integrityMatches']);self.assertFalse(packet['limits']['externalURLVerified'])
        self.update({'title':'A changed title after release','acceptance':[dict(id='new',title='A different criterion',done=False)]})
        later=self.packet(r)[1];self.assertEqual(later['snapshot']['title'],oldtitle);self.assertEqual(later['snapshot']['acceptance'][0]['id'],'test');self.assertEqual(later['asset']['html'],html);self.assertEqual(later['sourceVersion'],r['sourceVersion']);self.assertEqual(self.packet(r,self.other['token'])[0],404)
    def test_release_author_and_viewer_cannot_accept(self):
        r=self.released();self.assertEqual(self.review(r,token=self.owner['token'])[0],403);self.add_member('viewer','viewer');self.assertEqual(self.packet(r,self.viewer['token'])[0],200);self.assertEqual(self.review(r,token=self.viewer['token'])[0],403);self.assertFalse(self.releases(self.viewer['token'])[1]['releases'][0]['canReview'])
    def test_release_review_evidence_and_criteria_are_required(self):
        r=self.released();self.add_member('other','editor');original=self.review_body(r)
        for entries in [[],[dict(id='other',passed=True,evidence='A sufficiently long evidence description.')],[dict(id='test',passed=1,evidence='A sufficiently long evidence description.')],[dict(id='test',passed=True,evidence='short')],[dict(id=[],passed=True,evidence='A sufficiently long evidence description.')]]:
            body=dict(original,criteria=entries);self.assertEqual(self.review(r,body=body)[0],400,entries)
        self.assertEqual(self.review(r,body=dict(original,note='short'))[0],400)
        self.assertEqual(self.packet(r)[1]['reviews'],[])
    def test_release_review_verdict_history_and_new_release(self):
        r=self.released();self.add_member('other','editor');status,result=self.review(r,False);self.assertEqual(status,200,result);self.p=result['project'];self.assertEqual(result['verdict'],'needs_changes')
        status,result=self.review(r);self.assertEqual(status,200,result);self.p=result['project'];self.assertEqual(result['verdict'],'accepted');packet=self.packet(r)[1];self.assertEqual([v['verdict'] for v in packet['reviews']],['accepted','needs_changes'])
        status,result=self.act('release');self.assertEqual(status,200,result);self.p=result['project'];new=result['result'];self.assertEqual(self.packet(new)[1]['reviews'],[]);self.assertEqual(len(self.packet(r)[1]['reviews']),2)
    def test_release_review_retry_and_access_revocation(self):
        r=self.released();self.add_member('other','editor');body=self.review_body(r);key=uuid.uuid4().hex;status,result=self.review(r,key=key,body=body);self.assertEqual(status,200,result);self.p=result['project']
        status,replay=self.review(r,key=key,body=body);self.assertEqual(status,200,replay);self.assertTrue(replay['replayed']);self.assertEqual(len(self.packet(r)[1]['reviews']),1)
        self.assertEqual(self.review(r,key=key,body=dict(body,note='Changed content with the same operation key.'))[0],409)
        self.add_member('other','remove');self.assertEqual(self.review(r,key=key,body=body)[0],404);self.assertEqual(self.packet(r,self.other['token'])[0],404)
    def test_release_review_version_race_allows_one_commit(self):
        r=self.released();self.add_member('other','editor');body=self.review_body(r)
        with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:self.review(r,body=body),range(2)))
        self.assertEqual(sorted(v[0] for v in results),[200,409]);self.assertEqual(len(self.packet(r)[1]['reviews']),1)
    def test_release_integrity_mismatch_blocks_acceptance(self):
        r=self.released(True);self.add_member('other','editor')
        with self.server.store.transaction() as db:db.execute('UPDATE assets SET content=? WHERE project_id=?',('tampered HTML',self.p['id']))
        self.assertFalse(self.packet(r)[1]['asset']['integrityMatches']);self.assertEqual(self.review(r)[0],409);self.assertEqual(self.packet(r)[1]['reviews'],[])
        status,result=self.review(r,False);self.assertEqual(status,200,result);self.assertEqual(result['verdict'],'needs_changes')
    def test_release_reviews_export_restore_and_consent(self):
        r=self.released();before=self.p['version'];self.add_member('other','editor');status,result=self.review(r);self.assertEqual(status,200,result);self.p=result['project']
        copied=Path(self.tmp.name)/('acceptance-'+uuid.uuid4().hex+'.sqlite3');backup(self.db,copied);restored=Store(copied);self.assertEqual(len(restored.get('projects/'+self.p['id']+'/releases/'+r['id'],self.owner['user']['id'])['reviews']),1)
        export=self.request('GET','projects/'+self.p['id']+'/export',token=self.owner['token'])[1];self.assertEqual(len(export['releaseReviews']),1);self.assertNotIn(self.owner['token'],json.dumps(export))
        status,result=self.write('projects/'+self.p['id']+'/restore',dict(expectedVersion=self.p['version'],version=before));self.assertEqual(status,200,result);self.p=result['project'];self.assertEqual(len(self.packet(r)[1]['reviews']),1)
        self.update({'consents':dict(learning=True,studio=False,business=False)});self.assertEqual(self.packet(r)[0],400);self.assertEqual(self.review(r)[0],400)
    def test_release_legacy_and_missing_snapshot_fail_explicitly(self):
        r=self.released()
        with self.server.store.transaction() as db:
            row=db.execute('SELECT data FROM projects WHERE id=?',(self.p['id'],)).fetchone();data=json.loads(row['data']);del data['releases'][-1]['sourceVersion'];db.execute('UPDATE projects SET data=? WHERE id=?',(json.dumps(data),self.p['id']))
        self.assertIsNone(self.releases()[1]['releases'][0]['sourceVersion']);self.assertEqual(self.packet(r)[0],409)
    def test_release_owner_can_review_editor_release(self):
        self.ready();self.add_member('other','editor');body=dict(expectedVersion=self.p['version'],kind='release',payload={});status,result=self.write('projects/'+self.p['id']+'/actions',body,self.other['token']);self.assertEqual(status,200,result);self.p=result['project'];r=result['result']
        self.assertTrue(self.releases()[1]['releases'][0]['canReview']);self.assertEqual(self.review(r,token=self.other['token'])[0],403);self.assertEqual(self.review(r,token=self.owner['token'])[0],200)

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(AcceptanceTests))
    report=dict(scope='HTTP/SQLite release acceptance tests plus 48 Core/Learning/Pilot/Account regressions; not browser QA, certification or external URL verification',status='passed' if result.wasSuccessful() else 'failed',testsRun=result.testsRun,failures=len(result.failures),errors=len(result.errors),generatedAt=datetime.now(timezone.utc).isoformat(),paymentsTested=False,externalMessagesSent=False)
    (Path(__file__).resolve().parents[1]/'docs/STUDIO-ACCEPTANCE-TESTS.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');sys.exit(0 if result.wasSuccessful() else 1)
