import importlib.util
import tempfile
import unittest
from pathlib import Path

SOURCE = Path(__file__).parent / "osa-cinema-v17-av-qc.py"
spec = importlib.util.spec_from_file_location("osa_cinema_v17_av_qc", SOURCE)
qc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qc)


class TestRealMediaTimelineQc(unittest.TestCase):
    def test_real_manifest_contains_four_video_and_six_audio_sources(self):
        a = qc.asset_specs()
        self.assertEqual(len(a), 10)
        self.assertEqual(sum(kind == "video" for kind, _ in a), 4)
        self.assertEqual(sum(kind == "narration" for kind, _ in a), 6)
        self.assertEqual(len(set(x["id"] for _, x in a)), 10)

    def test_ebu_r128_loudness_and_silence_are_parsed(self):
        log = """[silencedetect] silence_start: 21.836417
[silencedetect] silence_end: 23.046440 | silence_duration: 1.210023
[Parsed_ebur128_0] Summary:
  Integrated loudness:
    I:         -16.9 LUFS
  Loudness range:
    LRA:         2.2 LU
  True peak:
    Peak:       -0.7 dBFS
"""
        out = qc.parse_audio(log)
        self.assertEqual(out["integratedLufs"], -16.9)
        self.assertEqual(out["loudnessRangeLu"], 2.2)
        self.assertEqual(out["truePeakDbtp"], -0.7)
        self.assertEqual(out["silences"], [{"start": 21.836, "duration": 1.21}])

    def test_video_black_and_freeze_intervals_are_factual_markers(self):
        log = """[freeze] lavfi.freezedetect.freeze_start: 0
[freeze] lavfi.freezedetect.freeze_duration: 3
[freeze] lavfi.freezedetect.freeze_end: 3
[black] black_start:23.833333 black_end:24.291667 black_duration:0.458333
"""
        out = qc.parse_video(log)
        self.assertEqual(out["blackIntervals"], [{"start": 23.833, "duration": 0.458}])
        self.assertEqual(out["freezeIntervals"], [{"start": 0.0, "duration": 3.0}])

    def test_missing_files_fail_closed_without_releasing_media(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            report = qc.evaluate(root, root, max_workers=2)
        self.assertEqual(report["summary"]["mediaTotal"], 10)
        self.assertEqual(report["summary"]["integrityVerified"], 0)
        self.assertEqual(report["summary"]["scanSucceeded"], 0)
        self.assertEqual(report["summary"]["publicationAuthorized"], 0)
        self.assertFalse(report["releaseAuthorization"])
        self.assertTrue(all("original_missing_or_unsafe_symlink" in row["reviewFlags"] for row in report["assets"]))
        self.assertTrue(all(row["publicationAuthorized"] is False for row in report["assets"]))

    def test_incorrect_file_bytes_are_not_scanned(self):
        kind, ref = qc.asset_specs()[0]
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / ref["file"]).write_bytes(b"not an MP4")
            report = qc.inspect_one((kind, ref), root, root)
        self.assertFalse(report["integrityVerified"])
        self.assertIn("source_integrity_mismatch", report["reviewFlags"])
        self.assertFalse(report["scanSucceeded"])
        self.assertFalse(report["publicationAuthorized"])


if __name__ == "__main__":
    unittest.main()
