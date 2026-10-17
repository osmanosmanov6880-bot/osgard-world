"""End-to-end offline release bundle tests: real ZIPs, manifest and two validators."""
import importlib.util
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("bundle",ROOT/"scripts/release-bundle.py")
bundle=importlib.util.module_from_spec(spec)
spec.loader.exec_module(bundle)

class BundleTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        d=Path(self.tmp.name)
        self.dist=d/"dist";self.dist.mkdir()
        self.zip=d/"release.zip"
        self.manifest=d/"manifest.json"
        for rel in bundle.REQUIRED_ROUTES:
            p=self.dist/rel;p.parent.mkdir(parents=True,exist_ok=True)
            p.write_text("<!doctype html><title>OSGARD</title>",encoding="utf-8")
        (self.dist/"assets").mkdir(exist_ok=True)
        (self.dist/"assets"/"app.js").write_text("console.log(1)")
    def make(self):
        return bundle.build(self.dist,"a"*40,self.zip,self.manifest)
    def test_end_to_end(self):
        self.assertEqual(self.make()["status"],"built_and_verified")
        self.assertEqual(bundle.verify(self.zip,self.manifest)["status"],"verified_for_staging")
    def test_deterministic_zip(self):
        first=self.make()["zip_sha256"]
        self.zip.unlink();self.manifest.unlink()
        second=self.make()["zip_sha256"]
        self.assertEqual(first,second)
    def test_missing_game_catalog(self):
        (self.dist/"play/index.html").unlink()
        with self.assertRaisesRegex(ValueError,"required routes"):
            self.make()
        self.assertFalse(self.zip.exists())
    def test_existing_file_not_overwritten(self):
        self.zip.write_bytes(b"do not touch")
        with self.assertRaisesRegex(ValueError,"already exist"):
            self.make()
        self.assertEqual(self.zip.read_bytes(),b"do not touch")
    def test_manifest_outside_build_root(self):
        with self.assertRaisesRegex(ValueError,"outside"):
            bundle.build(self.dist,"a"*40,self.zip,self.dist/"manifest.json")
    def test_empty_asset_rejected(self):
        (self.dist/"assets"/"empty.js").touch()
        with self.assertRaisesRegex(ValueError,"empty or oversized"):
            self.make()
    def test_symlink_rejected(self):
        (self.dist/"link").symlink_to(self.dist/"index.html")
        with self.assertRaisesRegex(ValueError,"symlink"):
            self.make()
    def test_bad_commit(self):
        with self.assertRaisesRegex(ValueError,"invalid Git"):
            bundle.build(self.dist,"invalid",self.zip,self.manifest)
    def test_modified_zip_blocked(self):
        self.make()
        with zipfile.ZipFile(self.zip,"a") as z:
            z.writestr("malicious.html",b"bad")
        with self.assertRaisesRegex(ValueError,"unexpected"):
            bundle.verify(self.zip,self.manifest)
    def test_tampered_manifest_blocked(self):
        self.make()
        data=json.loads(self.manifest.read_text())
        data["files"][0]["sha256"]="0"*64
        self.manifest.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError,"hash mismatch"):
            bundle.verify(self.zip,self.manifest)
    def test_missing_zip_blocked(self):
        self.make();self.zip.unlink()
        with self.assertRaisesRegex(ValueError,"regular file"):
            bundle.verify(self.zip,self.manifest)
    def test_missing_manifest_blocked(self):
        self.make();self.manifest.unlink()
        with self.assertRaisesRegex(ValueError,"regular file"):
            bundle.verify(self.zip,self.manifest)
    def test_no_publication_flag(self):
        self.assertIs(self.make()["publication_performed"],False)
        self.assertIs(bundle.verify(self.zip,self.manifest)["publication_performed"],False)

if __name__=="__main__":unittest.main()
