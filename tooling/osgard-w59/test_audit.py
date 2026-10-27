#!/usr/bin/env python3
"""Synthetic safety regressions, not hardware results."""
import json,tempfile,unittest
from pathlib import Path
import audit as a

class FailClosed(unittest.TestCase):
    def setUp(self):
        self.t=tempfile.TemporaryDirectory();self.addCleanup(self.t.cleanup)
        self.root=Path(self.t.name)
    def test_missing_reports_hold(self):
        x=a.audit(self.root)
        self.assertEqual(x['status'],'HOLD')
        self.assertFalse(x['allow_master_merge'])
        self.assertEqual(len(x['missing']),6)
    def test_invalid_head(self):
        with self.assertRaisesRegex(a.EvidenceError,'40-character'):a.audit(self.root,'bad')
    def test_invalid_digest(self):
        with self.assertRaisesRegex(a.EvidenceError,'SHA256'):a.audit(self.root,candidate_digest='bad')
    def test_traversal(self):
        with self.assertRaisesRegex(a.EvidenceError,'Unsafe'):a.safe_file(self.root,'../bad/file')
    def test_absolute_path(self):
        with self.assertRaisesRegex(a.EvidenceError,'Unsafe'):a.safe_file(self.root,'/tmp/file')
    def test_symlink(self):
        (self.root/'link').symlink_to(self.root)
        with self.assertRaisesRegex(a.EvidenceError,'Symlink'):a.safe_file(self.root,'link/file')
    def test_utc(self):
        with self.assertRaisesRegex(a.EvidenceError,'UTC'):a.utc_time('2026-10-27T20:00:00+03:00')
    def test_bad_frames(self):
        p=self.root/'logs'/'frames.csv';p.parent.mkdir();p.write_text('fps\n60\n')
        with self.assertRaisesRegex(a.EvidenceError,'Frame CSV'):a.frame_stats(self.root,{'path':'logs/frames.csv','sha256':a.sha256(p)})
    def test_bad_thermal(self):
        p=self.root/'logs'/'thermal.csv';p.parent.mkdir();p.write_text('temp\n40\n')
        with self.assertRaisesRegex(a.EvidenceError,'Thermal CSV'):a.thermal_stats(self.root,{'path':'logs/thermal.csv','sha256':a.sha256(p)})
    def test_mismatched_candidate(self):
        m={'schema':'OSGARD_W59_EVIDENCE_MANIFEST_V1','source_sha':a.SOURCE_SHA,
           'candidate':{'path':'candidate/demo.zip','sha256':'a'*64},'reports':{}}
        (self.root/'manifest.json').write_text(json.dumps(m))
        with self.assertRaisesRegex(a.EvidenceError,'approved candidate'):a.audit(self.root)
    def test_stale_source(self):
        m={'schema':'OSGARD_W59_EVIDENCE_MANIFEST_V1','source_sha':'a'*40,
           'candidate':{'path':'candidate/demo.zip','sha256':a.CANDIDATE_SHA256},'reports':{}}
        (self.root/'manifest.json').write_text(json.dumps(m))
        with self.assertRaisesRegex(a.EvidenceError,'stale'):a.audit(self.root)
    def test_no_forged_device_go(self):
        report={'schema':'OSGARD_W59_DEVICE_SESSION_V1','platform':'ios','source_sha':a.SOURCE_SHA,
                'device_kind':'PHYSICAL_DEVICE_REPORTED_UNVERIFIED','production_approved':True}
        p=self.root/'reports'/'ios.json';p.parent.mkdir();p.write_text(json.dumps(report))
        with self.assertRaisesRegex(a.EvidenceError,'self-certification'):
            a.device(self.root,'ios',{'path':'reports/ios.json','sha256':a.sha256(p)},a.SOURCE_SHA)
    def test_emulator_rejected(self):
        report={'schema':'OSGARD_W59_DEVICE_SESSION_V1','platform':'android','source_sha':a.SOURCE_SHA,'device_kind':'EMULATOR'}
        p=self.root/'reports'/'android.json';p.parent.mkdir();p.write_text(json.dumps(report))
        with self.assertRaisesRegex(a.EvidenceError,'emulator'):
            a.device(self.root,'android',{'path':'reports/android.json','sha256':a.sha256(p)},a.SOURCE_SHA)
    def test_not_png(self):
        p=self.root/'img'/'ru.png';p.parent.mkdir();p.write_bytes(b'notpng')
        with self.assertRaisesRegex(a.EvidenceError,'not a PNG'):
            a.screenshot(self.root,{'path':'img/ru.png','sha256':a.sha256(p)})
if __name__=='__main__':unittest.main()
