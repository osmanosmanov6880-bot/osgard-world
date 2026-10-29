"""OSA CINEMA V64 — real owner aggregate quotas, integrity and backup rehearsal."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
import hashlib
import importlib.util
import os
import sys
import unittest

spec=importlib.util.spec_from_file_location('cinema_v63',Path(__file__).with_name('core-cinema-v63-vault-smoke.py'))
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
from core_server import Store
import core_cinema_ops

ops_spec=importlib.util.spec_from_file_location('cinema_backup_v64',Path(__file__).with_name('osa-cinema-v64-recovery-drill.py'))
recovery=importlib.util.module_from_spec(ops_spec);ops_spec.loader.exec_module(recovery)

class OpsTests(base.VaultTests):
    def integrity(self,wid,token=None):
        return self.request('GET','cinema/spaces/'+wid+'/vault/integrity',
                            token=token or self.owner['token'])

    def test_real_owner_sha256_audit_and_no_public_release(self):
        wid=self.workspace()
        status,_,uploaded=self.upload_raw(wid,1)
        self.assertEqual(status,200,uploaded)
        status,report=self.integrity(wid)
        self.assertEqual(status,200,report)
        self.assertEqual(report['status'],'PASS')
        self.assertEqual(report['filesChecked'],1)
        self.assertEqual(report['filesFailed'],0)
        self.assertEqual(report['assets'][0]['expectedSha256'],hashlib.sha256(base.PDF).hexdigest())
        self.assertEqual(report['assets'][0]['computedSha256'],hashlib.sha256(base.PDF).hexdigest())
        self.assertTrue(report['assets'][0]['match'])
        self.assertFalse(report['productionReady'])
        self.assertFalse(report['encryptionAtRest'])
        self.assertFalse(report['serverAntivirus'])
        self.assertFalse(report['professionalCustodyVerification'])
        self.assertFalse(report['publicFilmReleaseAuthorized'])
        self.assertIsNone(report['publicVideoUrl'])

    def test_owner_only_integrity_and_no_other_accounts(self):
        wid=self.workspace()
        self.assertEqual(self.integrity(wid,self.other['token'])[0],404)
        self.assertEqual(self.integrity(wid,self.viewer['token'])[0],404)
        self.assertEqual(self.edit(wid,1,'member.set',username='other',role='editor')[0],200)
        self.assertEqual(self.edit(wid,2,'member.set',username='viewer',role='viewer')[0],200)
        self.assertEqual(self.integrity(wid,self.other['token'])[0],403)
        self.assertEqual(self.integrity(wid,self.viewer['token'])[0],403)
        self.assertEqual(self.integrity(wid)[0],200)
        self.assertEqual(self.request('GET','cinema/spaces/'+wid+'/vault/integrity')[0],401)

    def test_real_corruption_detected_without_leaking_or_delivering_bytes(self):
        wid=self.workspace()
        status,_,uploaded=self.upload_raw(wid,1)
        self.assertEqual(status,200,uploaded)
        with self.server.store.transaction() as db:
            db.execute('UPDATE cinema_vault_assets SET actual_sha256=? WHERE id=?',
                       ('0'*64,uploaded['assetId']))
        status,report=self.integrity(wid)
        self.assertEqual(status,200,report)
        self.assertEqual(report['status'],'FAIL')
        self.assertEqual(report['filesFailed'],1)
        self.assertFalse(report['storedByteIntegrity'])
        self.assertFalse(report['assets'][0]['match'])
        status,_,failed=self.download_raw(wid,uploaded['assetId'])
        self.assertEqual(status,503,failed)
        self.assertNotEqual(failed,base.PDF)
        self.assertEqual(failed['error'],'integrity')

    def test_owner_quota_applies_to_all_spaces_and_editors(self):
        wid1=self.workspace()
        wid2=self.workspace('threshold')
        with patch.object(core_cinema_ops,'MAX_OWNER_BYTES',len(base.PDF)+8):
            self.assertEqual(self.upload_raw(wid1,1)[0],200)
            self.assertEqual(self.upload_raw(wid2,1)[0],409)
            self.assertEqual(self.edit(wid2,1,'member.set',username='other',role='editor')[0],200)
            self.assertEqual(self.upload_raw(wid2,2,token=self.other['token'])[0],409)
            report=self.listing(wid1)[1]
            self.assertEqual(report['ownerUsedBytes'],len(base.PDF))
            self.assertEqual(report['ownerRemainingBytes'],8)
            self.assertTrue(report['ownerQuotaEnforced'])
            self.assertEqual(report['limits']['maxOwnerBytes'],len(base.PDF)+8)
            editor=self.listing(wid2,self.other['token'])[1]
            self.assertIsNone(editor['ownerUsedBytes'])
            self.assertIsNone(editor['ownerRemainingBytes'])
        self.assertEqual(self.listing(wid2)[1]['assets'],[])

    def test_concurrent_cross_space_upload_respects_owner_quota(self):
        first=self.workspace()
        second=self.workspace('threshold')
        with patch.object(core_cinema_ops,'MAX_OWNER_BYTES',len(base.PDF)+1):
            def put(space_id):return self.upload_raw(space_id,1)
            with ThreadPoolExecutor(max_workers=2) as pool:
                out=list(pool.map(put,[first,second]))
        self.assertEqual(sorted(r[0] for r in out),[200,409],out)
        self.assertEqual(self.listing(first)[1]['usedBytes']+
                         self.listing(second)[1]['usedBytes'],len(base.PDF))

    def test_account_storage_overview_scoped_to_real_owner(self):
        wid=self.workspace()
        self.assertEqual(self.upload_raw(wid,1)[0],200)
        status,owner=self.request('GET','cinema/storage/overview',token=self.owner['token'])
        self.assertEqual(status,200,owner)
        self.assertEqual(owner['usedBytes'],len(base.PDF))
        self.assertEqual(owner['assets'],1)
        self.assertEqual(owner['spacesWithFiles'],1)
        self.assertFalse(owner['productionReady'])
        self.assertFalse(owner['releaseAuthorized'])
        status,other=self.request('GET','cinema/storage/overview',token=self.other['token'])
        self.assertEqual(status,200,other)
        self.assertEqual(other['usedBytes'],0)
        self.assertEqual(other['assets'],0)
        self.assertNotEqual(owner['ownerId'],other['ownerId'])
        self.assertEqual(self.request('GET','cinema/storage/overview')[0],401)

    def test_private_verified_restore_and_no_overwrite_or_public_root(self):
        wid=self.workspace()
        status,_,uploaded=self.upload_raw(wid,1)
        self.assertEqual(status,200,uploaded)
        with TemporaryDirectory() as tmp:
            target=Path(tmp)/'recovered.sqlite3'
            report=recovery.rehearse(self.db,target,self.root)
            self.assertTrue(report['passes'],report)
            self.assertTrue(report['checksumMatched'])
            self.assertEqual(report['sqliteIntegrity'],'ok')
            self.assertEqual(report['foreignKeyFailures'],0)
            self.assertEqual(report['assetsChecked'],1)
            self.assertEqual(report['assetFailures'],0)
            self.assertFalse(report['restoredIntoLiveProduction'])
            self.assertFalse(report['encryptedBackup'])
            self.assertFalse(report['publicFilmReleaseAuthorized'])
            self.assertEqual(target.stat().st_mode & 0o777,0o600)
            try:recovery.rehearse(self.db,target,self.root)
            except ValueError:pass
            else:self.fail('An existing backup must never be overwritten')
            try:recovery.safe_location(self.db,self.root/'public-backup.sqlite3',self.root)
            except ValueError:pass
            else:self.fail('A public-root database backup must always be rejected')
            restored=Store(target)
            asset=restored.get('cinema/spaces/'+wid+'/vault',self.owner['user']['id'])
            self.assertEqual(asset['assets'][0]['actualSha256'],uploaded['actualSha256'])

    def test_restored_snapshot_detects_corrupt_bytes_without_mutating_live(self):
        wid=self.workspace()
        status,_,uploaded=self.upload_raw(wid,1)
        self.assertEqual(status,200,uploaded)
        with self.server.store.transaction() as db:
            db.execute('UPDATE cinema_vault_assets SET actual_sha256=? WHERE id=?',
                       ('f'*64,uploaded['assetId']))
        with TemporaryDirectory() as tmp:
            target=Path(tmp)/'bad-backup.sqlite3'
            report=recovery.rehearse(self.db,target,self.root)
            self.assertFalse(report['passes'])
            self.assertTrue(report['checksumMatched']) # snapshot consistent, asset not
            self.assertEqual(report['assetFailures'],1)
            self.assertEqual(report['sqliteIntegrity'],'ok')
        self.assertEqual(self.integrity(wid)[1]['status'],'FAIL')

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(OpsTests))
    sys.exit(0 if result.wasSuccessful() else 1)
