"""OSA CINEMA V62: real SQLite+HTTP two-person metadata reviews and original Core regressions."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from tempfile import TemporaryDirectory
import importlib.util
import json
import sys
import uuid
import unittest

spec=importlib.util.spec_from_file_location('cinema_v61',Path(__file__).with_name('core-cinema-smoke.py'))
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
from core_server import Store
from core_backup import backup

class EvidenceTests(base.CinemaTests):
    def evidence(self,wid,version,kind,token=None,key=None,**params):
        return self.write('cinema/spaces/'+wid+'/evidence',
             {'kind':kind,'expectedVersion':version,**params},token,key)

    def read_evidence(self,wid,token=None):
        return self.request('GET','cinema/spaces/'+wid+'/evidence',token=token or self.owner['token'])

    def create_evidence(self,wid,version=1,token=None,**fields):
        payload=dict(sceneId='S01',category='script',title='Screenplay draft reference',
                     description='Owner provided metadata only; no file was uploaded.',
                     sourceUrl='https://example.org/script-final',declaredSha256='')
        payload.update(fields)
        status,result=self.evidence(wid,version,'evidence.create',token,**payload)
        self.assertEqual(status,200,result)
        return result['evidenceId']

    def test_private_namespace_and_empty_ledger_are_truthful(self):
        wid=self.workspace()
        self.assertEqual(self.request('GET','cinema/spaces/'+wid+'/evidence')[0],401)
        self.assertEqual(self.read_evidence(wid,self.other['token'])[0],404)
        status,result=self.read_evidence(wid)
        self.assertEqual(status,200,result)
        self.assertEqual(result['evidence'],[])
        self.assertIsNone(result['publicVideoUrl'])
        self.assertFalse(result['rightsIndependentlyVerified'])
        self.assertFalse(result['releaseAuthorized'])
        self.assertFalse(result['verificationLimits']['checksumCalculatedFromFiles'])
        self.assertTrue(result['verificationLimits']['independentProfessionalAudit'] is False)

    def test_two_person_review_preserves_author_and_no_fake_clearance(self):
        wid=self.workspace()
        item_id=self.create_evidence(wid)
        state=self.read_evidence(wid)[1]['evidence'][0]
        self.assertEqual(state['state'],'draft')
        self.assertFalse(state['checksumVerifiedByServer'])
        self.assertEqual(state['author'],'owner')
        self.assertEqual(self.evidence(wid,2,'evidence.request_review',evidenceId=item_id,expectedItemVersion=1)[0],200)
        self.assertEqual(self.evidence(wid,3,'evidence.review',
                        evidenceId=item_id,expectedItemVersion=2,verdict='internally_reviewed',
                        note='Self-review is not allowed even for the owner.')[0],403)
        self.assertEqual(self.edit(wid,3,'member.set',username='other',role='editor')[0],200)
        status,result=self.evidence(wid,4,'evidence.review',self.other['token'],
                 evidenceId=item_id,expectedItemVersion=2,
                 verdict='internally_reviewed',
                 note='This metadata entry has been read for internal planning; no file was checked.')
        self.assertEqual(status,200,result)
        self.assertEqual(result['state'],'internally_reviewed')
        self.assertFalse(result['releaseAuthorized'])
        ledger=self.read_evidence(wid)[1]
        self.assertEqual(ledger['evidence'][0]['state'],'internally_reviewed')
        self.assertEqual(ledger['evidence'][0]['reviews'][0]['reviewer'],'other')
        self.assertEqual(ledger['evidence'][0]['reviews'][0]['itemVersion'],2)
        self.assertFalse(ledger['evidence'][0]['externalRightsVerified'])
        self.assertNotIn('publicVideoUrl',ledger['evidence'][0])
        self.assertFalse(self.view(wid)[1]['space']['publicFilmReleaseAuthorized'])
        self.assertEqual(self.evidence(wid,5,'evidence.review',self.other['token'],
                         evidenceId=item_id,expectedItemVersion=3,verdict='internally_reviewed',
                         note='Duplicate review should be blocked.')[0],409)

    def test_needs_changes_update_resubmit_second_independent_review(self):
        wid=self.workspace()
        item=self.create_evidence(wid,sourceUrl='',declaredSha256='a'*64)
        self.assertEqual(self.evidence(wid,2,'evidence.request_review',evidenceId=item,expectedItemVersion=1)[0],200)
        self.assertEqual(self.edit(wid,3,'member.set',username='other',role='editor')[0],200)
        self.assertEqual(self.evidence(wid,4,'evidence.review',self.other['token'],
            evidenceId=item,expectedItemVersion=2,verdict='needs_changes',
            note='Please attach a usable source pointer before next review.')[0],200)
        self.assertEqual(self.evidence(wid,5,'evidence.update',evidenceId=item,expectedItemVersion=3,
            sceneId='S02',category='shotlist',title='Second shotlist version',
            description='User-declared checksum only',sourceUrl='https://example.org/shotlist',
            declaredSha256='b'*64)[0],200)
        self.assertEqual(self.read_evidence(wid)[1]['evidence'][0]['state'],'draft')
        self.assertEqual(self.evidence(wid,6,'evidence.request_review',evidenceId=item,expectedItemVersion=4)[0],200)
        self.assertEqual(self.evidence(wid,7,'evidence.review',self.other['token'],
            evidenceId=item,expectedItemVersion=5,verdict='internally_reviewed',
            note='Reviewed pointer format only, not rights or media authenticity.')[0],200)
        history=self.read_evidence(wid)[1]['evidence'][0]['reviews']
        self.assertEqual([r['verdict'] for r in history],['internally_reviewed','needs_changes'])
        self.assertFalse(self.read_evidence(wid)[1]['verificationLimits']['legalRightsClearance'])

    def test_unauthorized_editors_and_viewers_stay_restricted(self):
        wid=self.workspace()
        self.assertEqual(self.edit(wid,1,'member.set',username='viewer',role='viewer')[0],200)
        self.assertEqual(self.evidence(wid,2,'evidence.create',self.viewer['token'],
           sceneId='S01',category='script',title='Forbidden member entry')[0],403)
        self.assertEqual(self.edit(wid,2,'member.set',username='other',role='editor')[0],200)
        status,result=self.evidence(wid,3,'evidence.create',self.other['token'],
            sceneId='S02',category='safety',title='Safety requirements draft',
            description='Plan review later',sourceUrl='https://example.org/safety')
        self.assertEqual(status,200,result)
        item=result['evidenceId']
        self.assertEqual(self.evidence(wid,4,'evidence.request_review',self.other['token'],
                         evidenceId=item,expectedItemVersion=1)[0],200)
        # The owner is allowed to review the editor's metadata; still not an independent legal audit.
        self.assertEqual(self.evidence(wid,5,'evidence.review',
                         evidenceId=item,expectedItemVersion=2,verdict='internally_reviewed',
                         note='Owner reviewed the metadata entry, not actual rights.')[0],200)
        self.assertEqual(self.evidence(wid,6,'evidence.update',self.viewer['token'],
                         evidenceId=item,expectedItemVersion=3,sceneId='S02',category='rights',
                         title='Viewer intrusion')[0],403)
        self.assertEqual(self.read_evidence(wid,self.viewer['token'])[0],200)
        self.assertEqual(self.read_evidence(wid,self.other['token'])[0],200)
        self.assertEqual(self.edit(wid,6,'member.remove',username='other')[0],200)
        self.assertEqual(self.read_evidence(wid,self.other['token'])[0],404)

    def test_invalid_external_links_and_fake_verified_fields_fail_closed(self):
        wid=self.workspace()
        base_payload=dict(sceneId='S01',category='rights',title='Contract metadata draft',
                          description='No original contract stored')
        attempts=[
          {'sourceUrl':'http://example.org/rights'}, {'sourceUrl':'https://admin:pass@example.org'},
          {'sourceUrl':'https://localhost/a'}, {'sourceUrl':'https://127.0.0.1/a'},
          {'sourceUrl':'https://10.0.0.1/a'}, {'sourceUrl':'https://example.org/f#access-token'},
          {'sourceUrl':'javascript:alert(1)'}, {'sourceUrl':'https://evil.test/path'},
          {'declaredSha256':'not-a-checksum'}, {'declaredSha256':'Z'*64},
          {'sceneId':'S14'}, {'sceneId':'../escape'}, {'category':'public_rights_approved'},
          {'title':' '}, {'description':'\u0001bad'}, {'releaseAuthorized':True},
          {'externalRightsVerified':True}, {'publicVideoUrl':'https://cdn.example.org/video.mp4'},
          {'liveActionFilmed':True}, {'fileUpload':'secret-pdf-data'}
        ]
        for patch in attempts:
            status,result=self.evidence(wid,1,'evidence.create',**dict(base_payload,**patch))
            self.assertEqual(status,400,(patch,result))
        self.assertEqual(self.read_evidence(wid)[1]['evidence'],[])
        self.assertEqual(self.view(wid)[1]['space']['version'],1)
        self.assertEqual(self.evidence(wid,1,'evidence.create',**dict(base_payload,sourceUrl=''))[0],200)
        item=self.read_evidence(wid)[1]['evidence'][0]
        self.assertEqual(self.evidence(wid,2,'evidence.request_review',
             evidenceId=item['id'],expectedItemVersion=1)[0],400)

    def test_item_versions_and_duplicate_idempotent_replay(self):
        wid=self.workspace()
        key=uuid.uuid4().hex
        payload=dict(kind='evidence.create',expectedVersion=1,sceneId='S04',
                     category='master',title='Declared master metadata',
                     description='No file stored',sourceUrl='https://example.org/master',
                     declaredSha256='c'*64)
        path='cinema/spaces/'+wid+'/evidence'
        a=self.write(path,payload,key=key)
        b=self.write(path,payload,key=key)
        self.assertEqual(a[0],200,a);self.assertEqual(b[0],200,b)
        self.assertTrue(b[1]['replayed'])
        self.assertEqual(b[1]['evidenceId'],a[1]['evidenceId'])
        self.assertEqual(len(self.read_evidence(wid)[1]['evidence']),1)
        self.assertEqual(self.evidence(wid,1,'evidence.request_review',
            evidenceId=a[1]['evidenceId'],expectedItemVersion=1)[0],409)
        self.assertEqual(self.evidence(wid,2,'evidence.request_review',
            evidenceId=a[1]['evidenceId'],expectedItemVersion=999)[0],409)
        p=dict(payload,title='Different file under same key')
        self.assertEqual(self.write(path,p,key=key)[0],409)

    def test_concurrent_review_conflict_and_revocation_replay(self):
        wid=self.workspace()
        item=self.create_evidence(wid)
        self.assertEqual(self.evidence(wid,2,'evidence.request_review',evidenceId=item,expectedItemVersion=1)[0],200)
        self.assertEqual(self.edit(wid,3,'member.set',username='other',role='editor')[0],200)
        self.assertEqual(self.edit(wid,4,'member.set',username='viewer',role='editor')[0],200)
        def review(tok):
            return self.evidence(wid,5,'evidence.review',tok,
              evidenceId=item,expectedItemVersion=2,verdict='internally_reviewed',
              note='Metadata reviewed internally; external provenance is unverified.')
        with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(review,[self.other['token'],self.viewer['token']]))
        self.assertCountEqual([x[0] for x in results],[200,409],results)
        self.assertEqual(len(self.read_evidence(wid)[1]['evidence'][0]['reviews']),1)
        key=uuid.uuid4().hex
        # Verify an editor's new record gets replay-blocked after their membership is revoked.
        body=dict(kind='evidence.create',expectedVersion=6,sceneId='S05',category='post',
                 title='Planning only',sourceUrl='https://example.org/post')
        path='cinema/spaces/'+wid+'/evidence'
        status,res=self.write(path,body,self.other['token'],key)
        self.assertEqual(status,200,res)
        self.assertEqual(self.edit(wid,7,'member.remove',username='other')[0],200)
        self.assertEqual(self.write(path,body,self.other['token'],key)[0],404)

    def test_cross_space_and_cross_account_isolation(self):
        first=self.workspace()
        second=self.workspace('threshold')
        eid=self.create_evidence(first)
        self.assertEqual(self.read_evidence(first,self.other['token'])[0],404)
        self.assertEqual(self.evidence(second,1,'evidence.update',
              evidenceId=eid,expectedItemVersion=1,sceneId='PREVIZ',category='post',
              title='Cross-project edit')[0],404)
        self.assertEqual(self.evidence(second,1,'evidence.create',
              sceneId='S01',category='post',title='Invalid Threshold scene')[0],400)
        self.assertEqual(self.evidence(second,1,'evidence.create',
              sceneId='PREVIZ',category='post',title='Threshold metadata draft')[0],200)
        self.assertEqual(len(self.read_evidence(first)[1]['evidence']),1)
        self.assertEqual(len(self.read_evidence(second)[1]['evidence']),1)

    def test_evidence_sqlite_backup_restore_and_original_no_go(self):
        wid=self.workspace()
        eid=self.create_evidence(wid,declaredSha256='d'*64)
        self.assertFalse(self.read_evidence(wid)[1]['evidence'][0]['checksumVerifiedByServer'])
        fresh=Store(self.db)
        persisted=fresh.get('cinema/spaces/'+wid+'/evidence',self.owner['user']['id'])
        self.assertEqual(persisted['evidence'][0]['id'],eid)
        with TemporaryDirectory() as tmp:
            copied=Path(tmp)/'evidence-backup.sqlite3'
            h=backup(self.db,copied);self.assertEqual(len(h),64)
            restored=Store(copied)
            self.assertEqual(restored.get('cinema/spaces/'+wid+'/evidence',self.owner['user']['id'])['evidence'][0]['id'],eid)
        proof=json.loads((Path(__file__).resolve().parents[1]/'docs/OSA_CINEMA_V53_CONCEPT_EVIDENCE_20261028.json').read_text())
        self.assertFalse(proof['publicReleaseAuthorized'])
        self.assertEqual(proof['actorSceneProduction']['scenesFilmed'],0)
        self.assertFalse(self.view(wid)[1]['space']['publicFilmReleaseAuthorized'])

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(EvidenceTests))
    sys.exit(0 if result.wasSuccessful() else 1)
