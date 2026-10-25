"""EMPIRE Omega R75: fail closed on forged PNG bytes and reused evidence.

Every test image below is synthetically generated for contract QA and MUST
NOT be used as field evidence of a real human playthrough.
"""
import hashlib
import importlib.util
import struct
import tempfile
import unittest
import zlib
from pathlib import Path

module_file = Path(__file__).with_name("omega_r73_field_qa.py")
spec = importlib.util.spec_from_file_location("r73", module_file)
r73 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r73)


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return (struct.pack(">I", len(payload)) + kind + payload +
            struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF))


def synthetic_decodable_png(index: int) -> bytes:
    width, height = 320, 240
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    # 4 bytes/pixel, one PNG filter byte per row, all rows decoded by zlib.
    row = b"\x00" + bytes([index & 255, 65, 120, 255]) * width
    pixels = row * height
    return (r73.PNG_SIGNATURE + png_chunk(b"IHDR", ihdr) +
            png_chunk(b"IDAT", zlib.compress(pixels)) +
            png_chunk(b"IEND", b""))


class FieldEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.manifest = {
            "engine": "Godot 4.4.1",
            "source_path": "godot/empire-omega",
            "artifact_kind": "native-Godot-HTML5-export",
            "source_commit": "a" * 40,
        }
        self.missions = [
            {"id": "drive" if i % 2 else "trade", "reward": 100 + i}
            for i in range(40)
        ]
        self.report = r73.make_template(self.manifest, self.missions)

    def put(self, filename, payload):
        (self.path / filename).write_bytes(payload)
        return hashlib.sha256(payload).hexdigest()

    def complete(self):
        self.report.update(
            tester="QA synthetic sample - NOT a player",
            platform="desktop",
            human_operated=True,  # Deliberately shows flag alone cannot certify play.
            captured_utc="2026-10-25T15:00:00Z",
            recording_duration_s=240,
            recording_sha256=self.put("campaign.webm", b"\x1a\x45\xdf\xa3" + b"x" * 2200),
        )
        for i, entry in enumerate(self.report["missions"]):
            entry.update(
                result="passed", start_s=1 + i * 5, finish_s=3 + i * 5,
                screen_sha256=self.put(entry["screen_file"], synthetic_decodable_png(i)),
            )
        for i, entry in enumerate(self.report["save_reload_checkpoints"]):
            entry.update(
                save_reload_verified=True, stage_after_reload=entry["stage"],
                screen_sha256=self.put(entry["screen_file"], synthetic_decodable_png(i + 40)),
            )

    def verify(self):
        return r73.verify_campaign(self.report, self.manifest, self.missions, self.path)

    def test_empty_template_is_hold(self):
        with self.assertRaises(r73.EvidenceError):
            self.verify()

    def test_exact_forty_and_checkpoints_never_automatic_production_go(self):
        self.complete()
        result = self.verify()
        self.assertEqual(result["mission_records_checked"], 40)
        self.assertEqual(result["decodable_png_images_checked"], 43)
        self.assertEqual(result["status"], "EVIDENCE_READY_FOR_INDEPENDENT_REVIEW")
        self.assertFalse(result["production_go"])
        self.assertFalse(result["screenshots_semantically_verified"])

    def test_modified_video_rejected(self):
        self.complete()
        (self.path / "campaign.webm").write_bytes(b"\x1a\x45\xdf\xa3" + b"tampered" * 300)
        with self.assertRaisesRegex(r73.EvidenceError, "SHA-256 mismatch"):
            self.verify()

    def test_wrong_source_rejected(self):
        self.complete()
        self.report["source_commit"] = "b" * 40
        with self.assertRaisesRegex(r73.EvidenceError, "another game commit"):
            self.verify()

    def test_mission_skip_rejected(self):
        self.complete()
        self.report["missions"][10]["stage"] = 13
        with self.assertRaisesRegex(r73.EvidenceError, "stage sequence"):
            self.verify()

    def test_reused_name_rejected(self):
        self.complete()
        self.report["missions"][1]["screen_file"] = self.report["missions"][0]["screen_file"]
        with self.assertRaisesRegex(r73.EvidenceError, "reused screenshot filename"):
            self.verify()

    def test_identical_pixel_bytes_under_different_names_rejected(self):
        self.complete()
        first = self.report["missions"][0]
        second = self.report["missions"][1]
        second["screen_sha256"] = self.put(second["screen_file"],
                                           (self.path / first["screen_file"]).read_bytes())
        with self.assertRaisesRegex(r73.EvidenceError, "reused screenshot pixel file"):
            self.verify()

    def test_checkpoint_reuse_rejected(self):
        self.complete()
        first = self.report["missions"][0]
        checkpoint = self.report["save_reload_checkpoints"][0]
        checkpoint["screen_sha256"] = self.put(checkpoint["screen_file"],
                                                (self.path / first["screen_file"]).read_bytes())
        with self.assertRaisesRegex(r73.EvidenceError, "reused screenshot image"):
            self.verify()

    def test_overlapping_timestamps_rejected(self):
        self.complete()
        self.report["missions"][2]["start_s"] = 2
        with self.assertRaisesRegex(r73.EvidenceError, "recording timeline"):
            self.verify()

    def test_save_regression_rejected(self):
        self.complete()
        self.report["save_reload_checkpoints"][0]["stage_after_reload"] = 5
        with self.assertRaisesRegex(r73.EvidenceError, "save/reload proof"):
            self.verify()

    def test_human_flag_must_be_true(self):
        self.complete()
        self.report["human_operated"] = False
        with self.assertRaisesRegex(r73.EvidenceError, "unattested human"):
            self.verify()

    def test_malformed_png_crc_rejected_even_with_matching_file_hash(self):
        self.complete()
        item = self.report["missions"][0]
        original = (self.path / item["screen_file"]).read_bytes()
        tampered = bytearray(original)
        tampered[-14] ^= 1
        item["screen_sha256"] = self.put(item["screen_file"], tampered)
        with self.assertRaises(r73.EvidenceError):
            self.verify()

    def test_signature_only_png_rejected_even_with_matching_file_hash(self):
        self.complete()
        item = self.report["missions"][0]
        fake = r73.PNG_SIGNATURE + b"x" * 300
        item["screen_sha256"] = self.put(item["screen_file"], fake)
        with self.assertRaises(r73.EvidenceError):
            self.verify()

    def test_missing_iend_rejected_even_with_matching_file_hash(self):
        self.complete()
        item = self.report["missions"][0]
        png = (self.path / item["screen_file"]).read_bytes()
        item["screen_sha256"] = self.put(item["screen_file"], png[:-12])
        with self.assertRaisesRegex(r73.EvidenceError, "missing image chunks"):
            self.verify()

    def test_trailing_png_garbage_rejected_even_with_matching_file_hash(self):
        self.complete()
        item = self.report["missions"][0]
        png = (self.path / item["screen_file"]).read_bytes()
        item["screen_sha256"] = self.put(item["screen_file"], png + b"extra")
        with self.assertRaisesRegex(r73.EvidenceError, "trailing bytes"):
            self.verify()


if __name__ == "__main__":
    unittest.main(verbosity=2)
