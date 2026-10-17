import importlib.util
import json
import tempfile
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
    def setUp(self):
        binding=patch.object(m,"verify_dist_manifest",return_value={
            "status":"verified","commit_sha":"a"*40,"manifest_sha256":"b"*64})
        self.binding=binding.start()
        self.addCleanup(binding.stop)
    def fixture(self,config="passed",bundle="verified_for_staging",games="verified"):
        modules=[Fake({"status":config}),Fake({"status":bundle,"zip_sha256":"a"*64,"manifest_sha256":"b"*64}),
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
    def test_incomplete_world_count_blocks(self):
        with patch.object(m,"module",side_effect=[
            Fake({"status":"passed"}),
            Fake({"status":"verified_for_staging","zip_sha256":"a"*64,"manifest_sha256":"b"*64}),
            Fake({"status":"verified","zion_worlds":10,"legacy_entrypoints":8})
        ]):
            result=m.evaluate("dist","a","m")
        self.assertEqual(result["status"],"blocked")
        self.assertIn("game_entrypoint_count",result["failed"])
    def test_malformed_zip_digest_blocks(self):
        with patch.object(m,"module",side_effect=[
            Fake({"status":"passed"}),
            Fake({"status":"verified_for_staging","zip_sha256":"invalid","manifest_sha256":"b"*64}),
            Fake({"status":"verified","zion_worlds":11,"legacy_entrypoints":8})
        ]):
            result=m.evaluate("dist","a","m")
        self.assertIn("zip_sha256",result["failed"])
    def test_games_failure_blocks(self):
        with self.fixture(games="blocked"): result=m.evaluate("dist","a","m")
        self.assertEqual(result["status"],"blocked")
        self.assertIn("game_routes",result["failed"])
    def test_changed_manifest_between_checks_blocks(self):
        self.binding.return_value["manifest_sha256"]="c"*64
        with self.fixture():
            result=m.evaluate("dist","a","m")
        self.assertEqual(result["status"],"blocked")
        self.assertIn("manifest_binding",result["failed"])
class ArtifactBindingIntegrationTests(unittest.TestCase):
    """Exercise actual directories, ZIPs and manifests instead of mocked gates."""
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work=Path(self.temp.name)
        self.dist=self.work/"dist"
        self.dist.mkdir()
        self.archive=self.work/"release.zip"
        self.manifest=self.work/"manifest.json"
        self.bundle=m.module("real_bundle","release-bundle.py")
        self.headers="/*\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: strict-origin-when-cross-origin\n"
        files={route:b"<html lang='ru'><head><title>OSGARD</title></head><body></body></html>"
               for route in self.bundle.REQUIRED_ROUTES}
        worlds=[]
        routes=[f"games/{slug}/index.html" for slug in
                ("afterimage-run","empire-orbit","inherit","null-shift","remix","swarm","time-empire","vector-zero")]
        for number in range(20,31):
            route=f"/games/zion-9/queue/ZION-{number:03d}/index.html"
            worlds.append({"id":f"zion-{number:03d}","route":route})
            routes.append(route.lstrip("/"))
        for route in routes:
            files[route]=b"<html lang='ru'><head><title>Game</title></head><body><script src='local.js'></script></body></html>"
            files[str(Path(route).with_name("local.js"))]=b"console.log('fixture');"
        files["games/zion-9/worlds.json"]=json.dumps({"games":worlds}).encode()
        files.update({"_headers":self.headers.encode(),"_redirects":b"/old /index.html 301\n",
                      "robots.txt":b"User-agent: *\nAllow: /\n"})
        for name,content in files.items():
            path=self.dist/name
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(content)
    def build(self):
        self.bundle.build(self.dist,"a"*40,self.archive,self.manifest)
    def evaluate(self,dist=None):
        return m.evaluate(dist or self.dist,self.archive,self.manifest)
    def test_real_matching_directory_and_archive_are_accepted(self):
        self.build()
        result=self.evaluate()
        self.assertEqual(result["status"],"ready_for_staging_review")
        self.assertEqual(result["checks"]["dist_manifest"],"verified")
        self.assertEqual(result["commit_sha"],"a"*40)
        self.assertEqual(result["game_entrypoints_checked"],19)
        self.assertFalse(result["production_modified"])
        self.assertFalse(result["staging_deployed"])
    def test_unrelated_clean_directory_cannot_mask_unsafe_archive(self):
        (self.dist/"_headers").write_text("/*\n  X-Unrelated: value\n")
        self.build()
        clean=self.work/"unrelated-dist"
        clean.mkdir()
        for name in ("_headers","_redirects","robots.txt"):
            (clean/name).write_bytes((self.dist/name).read_bytes())
        (clean/"_headers").write_text(self.headers)
        with self.assertRaises(ValueError):
            self.evaluate(clean)
    def test_modified_directory_cannot_reuse_previous_manifest(self):
        self.build()
        (self.dist/"index.html").write_text("<html>changed after packaging</html>")
        with self.assertRaisesRegex(ValueError,"manifest mismatch"):
            self.evaluate()
    def test_extra_directory_file_is_not_silently_accepted(self):
        self.build()
        (self.dist/"unarchived.txt").write_text("not included in release")
        with self.assertRaisesRegex(ValueError,"manifest mismatch"):
            self.evaluate()
    def test_unsafe_config_in_matching_archive_remains_blocked(self):
        (self.dist/"_headers").write_text("/*\n  X-Unrelated: value\n")
        self.build()
        result=self.evaluate()
        self.assertEqual(result["status"],"blocked")
        self.assertIn("security_config",result["failed"])
    def test_tab_indented_global_headers_are_valid(self):
        (self.dist/"_headers").write_text(self.headers.replace("  ","\t"))
        self.build()
        self.assertEqual(self.evaluate()["status"],"ready_for_staging_review")
    def test_malformed_commit_cannot_enter_staging_review(self):
        self.build()
        record=json.loads(self.manifest.read_text())
        record["commit_sha"]="not-a-commit"
        self.manifest.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError,"commit"):
            self.evaluate()

if __name__=="__main__":unittest.main()
