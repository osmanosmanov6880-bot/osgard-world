import importlib.util
import json
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('v49_finalize',Path(__file__).with_name('osa-cinema-v49-finalize.py'))
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)

class FinalizerTest(unittest.TestCase):
    def setUp(self):
        self.pin=json.loads(Path(__file__).parents[1].joinpath('docs/OSA_CINEMA_V48_LOCAL_MEDIA_CANDIDATE_20261027.json').read_text())
        self.http={'status':'PRODUCTION_HTTP_BYTES_VERIFIED_BROWSER_STILL_PENDING','baseUrl':f.PREFIX,'assetsVerified':8,
            'bytesVerified':f.EXPECTED_BYTES,'results':[{'path':x['path'],'url':f.PREFIX+x['path'],'bytesVerified':x['bytes'],'sha256Verified':x['sha256'],
             'httpFull':200,'httpRange':206,'httpUnsatisfiableRange':416} for x in self.pin['assets']]}
        self.browser={'schemaVersion':1,'project':'OSA CINEMA','status':'PUBLIC_BROWSER_PLAYBACK_PASS','baseUrl':f.PREFIX,
            'sourceSha':'0'*40,'checks':{k:True for k in f.CHECKS}}
    def test_full_proof_contract(self):
        self.assertEqual(f.check(self.http,self.browser,self.pin),'0'*40)
    def test_loopback_report_cannot_activate_publication(self):
        self.http['status']='LOOPBACK_INTEGRITY_ONLY_NOT_PUBLIC'
        with self.assertRaisesRegex(ValueError,'real HTTPS'):f.check(self.http,self.browser,self.pin)
    def test_browser_status_cannot_be_guessed(self):
        self.browser['status']='NOT_TESTED'
        with self.assertRaisesRegex(ValueError,'browser'):f.check(self.http,self.browser,self.pin)
    def test_missing_mobile_or_subtitles_denied(self):
        self.browser['checks']['mobilePlayback']=False
        with self.assertRaisesRegex(ValueError,'checks'):f.check(self.http,self.browser,self.pin)
    def test_wrong_movie_sha_denied(self):
        self.http['results'][0]['sha256Verified']='0'*64
        with self.assertRaisesRegex(ValueError,'GitHub pin'):f.check(self.http,self.browser,self.pin)
    def test_wrong_origin_denied(self):
        self.http['baseUrl']='https://example.com/osa-cinema/premiere/'
        with self.assertRaisesRegex(ValueError,'real HTTPS'):f.check(self.http,self.browser,self.pin)
    def test_duplicate_asset_denied(self):
        self.http['results'][1]=self.http['results'][0].copy()
        with self.assertRaisesRegex(ValueError,'duplicate'):f.check(self.http,self.browser,self.pin)

if __name__=='__main__':unittest.main(verbosity=2)
