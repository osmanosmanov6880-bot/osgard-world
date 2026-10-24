#!/usr/bin/env python3
"""Release safety contracts for exact Omega game SSH publication."""
import pathlib
import unittest

WORKFLOW = pathlib.Path(".github/workflows/omega-web-direct-deploy.yml")
BUDGET = pathlib.Path("scripts/omega-native-space-budget.py")
FREE = pathlib.Path("scripts/omega-native-remote-free-space.sh")
CLEAN = pathlib.Path("scripts/omega-native-remote-cleanup.sh")


class ProductionCapacityContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = WORKFLOW.read_text(encoding="utf-8")

    def test_source_tree_checked_before_capacity_and_scp(self):
        body = self.workflow
        start = body.index("      - name: Upload verified Godot game, activate with rollback")
        end = body.index("      - name: Verify exact live Godot source", start)
        step = body[start:end]
        self.assertLess(step.index('python3 scripts/omega-build-freshness.py'), step.index('python3 scripts/omega-native-space-budget.py'))
        self.assertLess(step.index('omega-native-remote-free-space.sh'), step.index('mkdir -p'))
        self.assertLess(step.index('omega-native-remote-free-space.sh'), step.index('scp -i'))
        self.assertIn('deployed=false', step)
        self.assertIn('deployed=true', step)

    def test_safe_remote_capacity_budget(self):
        body = FREE.read_text(encoding="utf-8")
        self.assertIn('df -Pk /tmp', body)
        self.assertIn('"$available_bytes" -lt "$minimum_bytes"', body)
        self.assertIn('exit 4', body)
        self.assertNotIn('rm -rf', body)
        self.assertNotIn('docker', body.lower())

    def test_cleanup_after_full_public_attestation_only(self):
        body = self.workflow
        proof = body.index('python3 scripts/omega-live-integrity.py')
        cleanup = body.index('      - name: Remove only this release transport staging')
        self.assertLess(proof, cleanup)
        post = body[cleanup:]
        self.assertIn("if: steps.publish.outputs.deployed == 'true'", post)
        self.assertIn('omega-native-remote-cleanup.sh', post)
        self.assertIn('github.run_id', post)

    def test_cleanup_cannot_prune_live_game_or_backups(self):
        body = CLEAN.read_text(encoding="utf-8")
        self.assertIn('root="/tmp/osgard-omega-native-${run_id}"', body)
        self.assertIn('if [ -L "$root" ]', body)
        self.assertIn('rm -rf -- "$root"', body)
        for forbidden in ('docker system prune', '/usr/share/nginx', 'osgard-gh-release', 'docker volume', 'omega-backup'):
            self.assertNotIn(forbidden, body.lower())

    def test_native_release_still_fail_closed(self):
        body = self.workflow
        for expected in (
            "if: steps.source_gate.outputs.ready == 'true'",
            "if: steps.publish.outputs.deployed == 'true'",
            'python3 scripts/omega-build-freshness.py',
            'sha256sum -c SHA256SUMS.txt',
            '--base https://osgard.world/games/omega-3d-preview'
        ):
            self.assertIn(expected, body)
        self.assertTrue(BUDGET.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
