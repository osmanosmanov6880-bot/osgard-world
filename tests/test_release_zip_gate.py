import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("zip_gate", ROOT / "scripts/verify-release-zip.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

class ZipGateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.archive = Path(self.temp.name) / "release.zip"

    def write(self, entries):
        with zipfile.ZipFile(self.archive, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for name, data in entries:
                zf.writestr(name, data)

    def test_valid(self):
        self.write([("index.html", b"<html>hello</html>"), ("assets/main.js", b"ok")])
        report = gate.validate(self.archive)
        self.assertEqual(report["files"], 2)
        self.assertTrue(report["no_publish_performed"])

    def test_missing_entrypoint(self):
        self.write([("assets/file.js", b"ok")])
        with self.assertRaisesRegex(ValueError, "missing root-level"):
            gate.validate(self.archive)

    def test_parent_traversal(self):
        self.write([("index.html", b"ok"), ("../oops.txt", b"ok")])
        with self.assertRaisesRegex(ValueError, "unsafe archive path"):
            gate.validate(self.archive)

    def test_windows_traversal(self):
        self.write([("index.html", b"ok"), ("..\\oops.txt", b"ok")])
        with self.assertRaisesRegex(ValueError, "unsafe archive filename"):
            gate.validate(self.archive)

    def test_secret(self):
        self.write([("index.html", b"ok"), ("assets/.env.production", b"secret")])
        with self.assertRaisesRegex(ValueError, "secret-looking"):
            gate.validate(self.archive)

    def test_case_collision(self):
        self.write([("index.html", b"ok"), ("A/file.txt", b"1"), ("a/FILE.txt", b"2")])
        with self.assertRaisesRegex(ValueError, "case-colliding"):
            gate.validate(self.archive)

    def test_file_limit(self):
        self.write([("index.html", b"ok"), ("a.txt", b"ok")])
        with self.assertRaisesRegex(ValueError, "too many files"):
            gate.validate(self.archive, max_files=1)

    def test_expanded_size_limit(self):
        self.write([("index.html", b"12345")])
        with self.assertRaisesRegex(ValueError, "oversized"):
            gate.validate(self.archive, max_file=3)

    def test_total_size_limit(self):
        self.write([("index.html", b"123"), ("x", b"123")])
        with self.assertRaisesRegex(ValueError, "total uncompressed"):
            gate.validate(self.archive, max_total=5)

    def test_bad_zip(self):
        self.archive.write_bytes(b"not a ZIP")
        with self.assertRaises(zipfile.BadZipFile):
            gate.validate(self.archive)

    def test_zero_length(self):
        self.write([("index.html", b"")])
        with self.assertRaisesRegex(ValueError, "empty or oversized"):
            gate.validate(self.archive)

    def test_symlink_source(self):
        self.write([("index.html", b"ok")])
        link = Path(self.temp.name) / "link.zip"
        link.symlink_to(self.archive)
        with self.assertRaisesRegex(ValueError, "symlink"):
            gate.validate(link)

if __name__ == "__main__":
    unittest.main()
