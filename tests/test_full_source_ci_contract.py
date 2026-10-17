"""Guard CI coverage of real product changes (not script-only)."""
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class BuildTriggerTests(unittest.TestCase):
 def test_full_source_acceptance_has_unfiltered_pull_request_trigger(self):
  text=(ROOT/".github/workflows/full-source-release-acceptance.yml").read_text()
  section=text.split("  pull_request:",1)[1].split("  workflow_dispatch:",1)[0]
  self.assertNotIn("paths:",section)
  self.assertNotIn("paths-ignore:",section)
 def test_full_source_acceptance_still_builds_and_validates_all_games(self):
  text=(ROOT/".github/workflows/full-source-release-acceptance.yml").read_text()
  for cmd in ("npm ci","npm run build","npm run qa:zion-local","scripts/staging-release-acceptance.py"):
   with self.subTest(cmd=cmd):self.assertIn(cmd,text)
if __name__=="__main__":unittest.main()
