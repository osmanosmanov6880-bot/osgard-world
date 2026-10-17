import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
def load(name,path):
    s=importlib.util.spec_from_file_location(name,ROOT/path)
    m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
manifest=load("osgard_manifest","scripts/release-artifact-manifest.py")
gate=load("osgard_zip_binding","scripts/verify-zip-manifest.py")

class ZipManifestBindingTest(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        base=Path(self.tmp.name);self.root=base/"dist";self.root.mkdir()
        (self.root/"index.html").write_bytes(b"<title>OSGARD</title>")
        (self.root/"asset.js").write_bytes(b"console.log(1)")
        self.zip=base/"release.zip"
        self.record=manifest.inspect(self.root,"a"*40)
    def pack(self,extra=None,omit=None,mutate=None):
        with zipfile.ZipFile(self.zip,"w",compression=zipfile.ZIP_DEFLATED) as z:
            for path in sorted(self.root.iterdir()):
                if path.name!=omit:
                    z.writestr(path.name, mutate if path.name=="asset.js" and mutate is not None else path.read_bytes())
            if extra:
                z.writestr(*extra)
    def test_exact_copy(self):
        self.pack()
        self.assertEqual(gate.verify(self.zip,self.record)["status"],"verified")
    def test_repack_compression_independent(self):
        self.pack()
        first=gate.verify(self.zip,self.record)
        with zipfile.ZipFile(self.zip,"w",compression=zipfile.ZIP_STORED) as z:
            for p in self.root.iterdir():z.writestr(p.name,p.read_bytes())
        second=gate.verify(self.zip,self.record)
        self.assertEqual(first["manifest_sha256"],second["manifest_sha256"])
    def test_modified_file(self):
        self.pack(mutate=b"console.log(2)")
        with self.assertRaisesRegex(ValueError,"hash mismatch"):
            gate.verify(self.zip,self.record)
    def test_omission(self):
        self.pack(omit="asset.js")
        with self.assertRaisesRegex(ValueError,"missing"):
            gate.verify(self.zip,self.record)
    def test_unexpected_file(self):
        self.pack(extra=("hidden.txt",b"x"))
        with self.assertRaisesRegex(ValueError,"unexpected"):
            gate.verify(self.zip,self.record)
    def test_duplicate_member(self):
        self.pack(extra=("index.html",b"<title>OSGARD</title>"))
        with self.assertRaisesRegex(ValueError,"duplicate"):
            gate.verify(self.zip,self.record)
    def test_path_escape(self):
        self.pack(extra=("../bad.txt",b"x"))
        with self.assertRaisesRegex(ValueError,"unsafe"):
            gate.verify(self.zip,self.record)
    def test_false_manifest_digest(self):
        self.pack();self.record["files"][0]["sha256"]="0"*64
        with self.assertRaisesRegex(ValueError,"hash mismatch"):
            gate.verify(self.zip,self.record)
    def test_wrong_size(self):
        self.pack();self.record["files"][0]["size"]=999
        with self.assertRaisesRegex(ValueError,"size differs"):
            gate.verify(self.zip,self.record)
    def test_no_manifest_entrypoint(self):
        self.pack();self.record["files"]=[r for r in self.record["files"] if r["path"]!="index.html"]
        self.record["file_count"]=len(self.record["files"])
        with self.assertRaisesRegex(ValueError,"entrypoint"):
            gate.verify(self.zip,self.record)
if __name__=="__main__":unittest.main()
