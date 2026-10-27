#!/usr/bin/env python3
"""W62 synthetic source scope attacks only."""
import unittest
import w62_source_guard as s

class Contract(unittest.TestCase):
    def test_allows_review_files(self):
        self.assertEqual(s.verify_changes(s.MANDATORY), sorted(s.MANDATORY))
    def test_rejects_missing_negative_tests(self):
        with self.assertRaisesRegex(ValueError,"Incomplete"):
            s.verify_changes(s.MANDATORY - {"tooling/last-frontier/test_release_package.py"})
    def test_rejects_game_mission_edits(self):
        with self.assertRaisesRegex(ValueError,"Unreviewed"):
            s.verify_changes(s.MANDATORY | {"w33-godot-native/scripts/OSGARDCore.gd"})
    def test_rejects_unsafe_renames(self):
        with self.assertRaisesRegex(ValueError,"Unreviewed"):
            s.verify_changes(s.MANDATORY | {"w33-godot-native/project.godot"})
    def test_rejects_production_workflow(self):
        with self.assertRaisesRegex(ValueError,"Unreviewed"):
            s.verify_changes(s.MANDATORY | {".github/workflows/deploy-site.yml"})
if __name__=="__main__":unittest.main()
