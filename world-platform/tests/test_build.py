#!/usr/bin/env python3
"""W76 red-team tests. Synthetic bytes are ONLY test fixtures, never real game assets."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from build import (
    WorldBuildError, GAME_SOURCE_SHA, SCHEMA, ROOT, file_sha256,
    make_manifest, generate
)

TEST_SHA = "a" * 40
FAKE_FILES = {
    "index.wasm":b"\0asm\1\0\0\0"+b"UNIT_TEST_NOT_AN_ENGINE"*9,
    "index.pck":b"GDPC"+b"TEST_FIXTURE_ONLY"*9,
    "index.html":b"<html><title>UNIT TEST ONLY</title></html>",
    "index.js":b"console.log('synthetic packaging fixture, never ship');",
    "index.png":b"not an actual image. packaging unit test",
    "index.icon.png":b"unit test png bytes placeholder",
    "index.apple-touch-icon.png":b"unit test apple icon bytes",
    "index.audio.worklet.js":b"// unit test audio helper",
    "index.audio.position.worklet.js":b"// unit test position worklet",
}


def fixture_game(folder, changes=None, extra=None):
    folder.mkdir(parents=True,exist_ok=True)
    entries=[]
    for filename,raw in FAKE_FILES.items():
        if changes and filename in changes:
            raw=changes[filename]
        (folder/filename).write_bytes(raw)
        entries.append({"name":filename,"bytes":len(raw),
                        "sha256":hashlib.sha256(raw).hexdigest()})
    data={
        "schema":"OSGARD_W33_GODOT_WEB_BYTES_V1",
        "source_commit":TEST_SHA,
        "godot_release":"4.4.1","files":entries
    }
    if extra:data.update(extra)
    (folder/"evidence.json").write_text(json.dumps(data))
    return data


class OriginalGodotPackaging(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.root=Path(self.temp.name)
        self.game=self.root/"game"
        fixture_game(self.game)

    def tearDown(self):
        self.temp.cleanup()

    def test_01_source_bound_manifest_requires_exact_game_sha(self):
        m=make_manifest(self.game,TEST_SHA)
        self.assertEqual(m["schema"],SCHEMA)
        self.assertEqual(m["sourceSha"],GAME_SOURCE_SHA)
        self.assertEqual(m["platformSourceSha"],TEST_SHA)
        self.assertEqual(m["releaseStatus"],"PRODUCTION_HOLD")
        self.assertFalse(m["commercialReleaseApproved"] if "commercialReleaseApproved" in m else m["productionApproved"])
        self.assertEqual(len(m["gameFiles"]),9)

    def test_02_fake_export_provenance_rejected(self):
        with self.assertRaisesRegex(WorldBuildError,"exact W76 source SHA"):
            make_manifest(self.game,"b"*40)
        with self.assertRaisesRegex(WorldBuildError,"Exact platform Git"):
            make_manifest(self.game,"unversioned")

    def test_03_bad_wasm_header_rejected_even_with_consistent_sha(self):
        fixture_game(self.game,{"index.wasm":b"FAKE_BINARY"+b"A"*19})
        with self.assertRaisesRegex(WorldBuildError,"genuine WebAssembly"):
            make_manifest(self.game,TEST_SHA)

    def test_04_bad_godot_pck_header_rejected_even_with_consistent_sha(self):
        fixture_game(self.game,{"index.pck":b"AAAAUNITTEST_ONLY"})
        with self.assertRaisesRegex(WorldBuildError,"authentic Godot PCK"):
            make_manifest(self.game,TEST_SHA)

    def test_05_byte_mutation_detected_by_original_export_checksum(self):
        (self.game/"index.wasm").write_bytes(b"\0asmCORRUPTED")
        with self.assertRaisesRegex(WorldBuildError,"size mismatch"):
            make_manifest(self.game,TEST_SHA)

    def test_06_same_size_binary_tampering_fails_sha256(self):
        path=self.game/"index.pck"
        path.write_bytes(b"FAKE"+path.read_bytes()[4:])
        with self.assertRaisesRegex(WorldBuildError,"SHA256 differs"):
            make_manifest(self.game,TEST_SHA)

    def test_07_traversal_in_original_godot_export_rejected(self):
        data=fixture_game(self.game)
        data["files"][0]["name"]="../private.txt"
        (self.game/"evidence.json").write_text(json.dumps(data))
        with self.assertRaisesRegex(WorldBuildError,"untrusted game path"):
            make_manifest(self.game,TEST_SHA)

    def test_08_duplicate_original_file_rejected(self):
        data=fixture_game(self.game)
        data["files"].append(data["files"][0])
        (self.game/"evidence.json").write_text(json.dumps(data))
        with self.assertRaisesRegex(WorldBuildError,"Duplicate original"):
            make_manifest(self.game,TEST_SHA)

    def test_09_bogus_html_page_cannot_substitute_missing_wasm(self):
        (self.game/"index.wasm").unlink()
        with self.assertRaisesRegex(WorldBuildError,"absent"):
            make_manifest(self.game,TEST_SHA)

    def test_10_real_offline_package_from_verified_fixture_is_complete_and_reproducible(self):
        # This test only demonstrates zip mechanics with explicit fake data;
        # production CI *must* run the same packager on actual Godot 4.4.1 WASM.
        one=self.root/"build-one"
        two=self.root/"build-two"
        zip_one=self.root/"test-one.zip"
        zip_two=self.root/"test-two.zip"
        a=generate(self.game,one,TEST_SHA,zip_one)
        b=generate(self.game,two,TEST_SHA,zip_two)
        self.assertTrue(a["realWebAssembly"])
        self.assertEqual(a["archiveSha256"],b["archiveSha256"])
        self.assertEqual(file_sha256(zip_one),file_sha256(zip_two))
        self.assertTrue((one/"index.html").is_file())
        self.assertTrue((one/"game"/"index.wasm").is_file())
        self.assertTrue((one/"release-manifest.json").is_file())
        self.assertTrue((one/"START_WINDOWS.bat").is_file())
        m=json.loads((one/"release-manifest.json").read_text())
        self.assertFalse(m["productionApproved"])
        self.assertEqual(m["sourceSha"],GAME_SOURCE_SHA)

    def test_11_never_replace_an_existing_output_directory(self):
        out=self.root/"exists";out.mkdir()
        (out/"do_not_delete").write_text("safe")
        with self.assertRaisesRegex(WorldBuildError,"new path"):
            generate(self.game,out,TEST_SHA,None)
        self.assertEqual((out/"do_not_delete").read_text(),"safe")

    def test_12_wasm_is_required_even_if_engine_js_exists(self):
        data=fixture_game(self.game)
        data["files"]=[x for x in data["files"] if x["name"]!="index.wasm"]
        (self.game/"evidence.json").write_text(json.dumps(data))
        with self.assertRaisesRegex(WorldBuildError,"Genuine playable WebAssembly"):
            make_manifest(self.game,TEST_SHA)

    def test_13_source_bundle_has_real_html_css_javascript_and_service_worker(self):
        for file in ("index.html","styles.css","app.mjs","core.mjs","sw.js"):
            content=(ROOT/file).read_text(encoding="utf-8")
            self.assertGreater(len(content),100)
        self.assertIn("WORLD OPERATIONS",(ROOT/"index.html").read_text())
        self.assertIn("CACHE_GAME",(ROOT/"sw.js").read_text())
        self.assertIn("G direct physics-ray interaction",(ROOT/"README.txt").read_text())

    def test_14_no_global_network_dependency_in_launcher(self):
        self.assertIn("--bind 127.0.0.1",(ROOT/"START_WINDOWS.bat").read_text())
        self.assertIn("--bind 127.0.0.1",(ROOT/"START_LINUX_MAC.sh").read_text())
        sw=(ROOT/"sw.js").read_text()
        self.assertIn("crypto.subtle.digest",sw)
        self.assertIn('event.data?.type!=="CACHE_GAME"',sw)
        self.assertIn("await caches.delete(GAME)",sw)
        self.assertIn('file.path',sw)


if __name__=="__main__":
    unittest.main(verbosity=2)
