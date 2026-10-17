import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("manifest",ROOT/"scripts/release-artifact-manifest.py")
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
class ArtifactManifestTest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)/"dist"
        self.root.mkdir()
        (self.root/"index.html").write_text("<h1>OK</h1>")
        (self.root/"assets").mkdir()
        (self.root/"assets"/"app.js").write_text("console.log(1)")
    def test_reproducible(self):
        a=mod.inspect(self.root,"a"*40)
        b=mod.inspect(self.root,"a"*40)
        self.assertEqual(mod.canonical(a),mod.canonical(b))
        self.assertEqual(mod.verify(self.root,a)["status"],"verified")
    def test_change_detected(self):
        a=mod.inspect(self.root,"a"*40)
        (self.root/"assets"/"app.js").write_text("console.log(2)")
        with self.assertRaisesRegex(ValueError,"manifest mismatch"):
            mod.verify(self.root,a)
    def test_addition_detected(self):
        a=mod.inspect(self.root,"a"*40)
        (self.root/"assets"/"new.js").write_text("new")
        with self.assertRaisesRegex(ValueError,"manifest mismatch"):
            mod.verify(self.root,a)
    def test_removal_detected(self):
        a=mod.inspect(self.root,"a"*40)
        (self.root/"assets"/"app.js").unlink()
        with self.assertRaisesRegex(ValueError,"manifest mismatch"):
            mod.verify(self.root,a)
    def test_bad_commit(self):
        with self.assertRaisesRegex(ValueError,"invalid Git"):
            mod.inspect(self.root,"bad")
    def test_secret_path(self):
        (self.root/".env.production").write_text("secret")
        with self.assertRaisesRegex(ValueError,"secret-related"):
            mod.inspect(self.root,"a"*40)
    def test_symlink_path(self):
        (self.root/"alias").symlink_to(self.root/"index.html")
        with self.assertRaisesRegex(ValueError,"symlink"):
            mod.inspect(self.root,"a"*40)
    def test_missing_entrypoint(self):
        (self.root/"index.html").unlink()
        with self.assertRaisesRegex(ValueError,"missing root"):
            mod.inspect(self.root,"a"*40)
    def test_manifest_tamper(self):
        a=mod.inspect(self.root,"a"*40)
        a["files"][0]["sha256"]="0"*64
        with self.assertRaisesRegex(ValueError,"manifest mismatch"):
            mod.verify(self.root,a)
    def test_canonical_json_parses(self):
        a=mod.inspect(self.root,"a"*40)
        self.assertEqual(json.loads(mod.canonical(a)),a)
if __name__=="__main__":unittest.main()
