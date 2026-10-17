import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("staging_acceptance",ROOT/"scripts/staging-release-acceptance.py")
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Fake:
    def __init__(self, result): self.result=result
    def audit(self,root): return self.result
    def verify(self,*args): return self.result
class AcceptanceTests(unittest.TestCase):
    def fixture(self,config="passed",bundle="verified_for_staging",games="verified"):
        modules=[Fake({"status":config}),Fake({"status":bundle,"zip_sha256":"a"*64}),
                 Fake({"status":games,"zion_worlds":11,"legacy_entrypoints":8})]
        return patch.object(m,"module",side_effect=modules)
    def test_all_success_is_review_not_deploy(self):
        with self.fixture(): result=m.evaluate("dist","archive.zip","manifest.json")
        self.assertEqual(result["status"],"ready_for_staging_review")
        self.assertFalse(result["staging_deployed"])
        self.assertFalse(result["production_modified"])
        self.assertEqual(result["game_entrypoints_checked"],19)
    def test_config_failure_blocks(self):
        with self.fixture(config="blocked"): result=m.evaluate("dist","a","m")
        self.assertEqual(result["status"],"blocked")
        self.assertEqual(result["failed"],["security_config"])
    def test_invalid_zip_blocks(self):
        with self.fixture(bundle="blocked"): result=m.evaluate("dist","a","m")
        self.assertEqual(result["status"],"blocked")
        self.assertIn("bundle",result["failed"])
    def test_games_failure_blocks(self):
        with self.fixture(games="blocked"): result=m.evaluate("dist","a","m")
        self.assertEqual(result["status"],"blocked")
        self.assertIn("game_routes",result["failed"])
if __name__=="__main__":unittest.main()
