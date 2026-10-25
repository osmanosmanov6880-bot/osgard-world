import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

SCRIPT=Path(__file__).parent/"osa-cinema-v17-build-private-guide-audio.py"
spec=importlib.util.spec_from_file_location("osa_v17_private_guide",SCRIPT)
app=importlib.util.module_from_spec(spec)
spec.loader.exec_module(app)


class TestPrivateActGuide(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest=json.loads(app.NARRATION.read_text("utf8"))

    def test_three_authentic_mp3_acts_fit_239_seconds_in_both_locales(self):
        by_language=app.source_sets(self.manifest)
        self.assertEqual(set(by_language),{"ru","en"})
        for locale,tracks in by_language.items():
            self.assertEqual([a["act"] for a in tracks],[1,2,3])
            self.assertTrue(all(a["publicationStatus"]=="blocked" for a in tracks))
            for i,entry in enumerate(tracks):
                self.assertLess(app.STARTS[i]+entry["durationSeconds"],app.FILM_SECONDS)
                if i<2:
                    self.assertLess(app.STARTS[i]+entry["durationSeconds"],app.STARTS[i+1])

    def test_missing_act_fails_closed(self):
        broken=json.loads(json.dumps(self.manifest))
        broken["assets"].pop()
        with self.assertRaises(ValueError):
            app.source_sets(broken)

    def test_guide_never_authorizes_release_or_modifies_picture(self):
        with tempfile.TemporaryDirectory() as work:
            by_language=app.source_sets(self.manifest)
            with self.assertRaises(ValueError):
                app.render_private_guide("ru",by_language["ru"],Path(work),Path(work))
        self.assertIn("PRIVATE",app.PRIVATE_STATUS)

    def test_act_timings_follow_actual_static_holds(self):
        self.assertEqual(app.STARTS,(5.0,79.0,157.0))
        ru=app.source_sets(self.manifest)["ru"]
        self.assertAlmostEqual(app.STARTS[2]+ru[2]["durationSeconds"],230.796,places=2)


if __name__=="__main__":
    unittest.main()
