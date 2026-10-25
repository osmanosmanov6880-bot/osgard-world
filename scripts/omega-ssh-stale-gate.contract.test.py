#!/usr/bin/env python3
"""Safety contracts for remote Omega promotion; real git-tree self-test is
run independently by the same CI. No SSH credentials are required."""
from pathlib import Path
import unittest

WORKFLOW = Path(".github/workflows/omega-web-direct-deploy.yml")

class DeployFreshnessContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.body = WORKFLOW.read_text(encoding="utf-8")

    def test_safeguard_precedes_network_and_secrets(self):
        doc = self.body
        self.assertIn('id: source_gate', doc)
        self.assertIn('git fetch --no-tags --depth=1 origin "$manifest_source"', doc)
        self.assertIn('python3 scripts/omega-build-freshness.py "$manifest_source" origin/master', doc)
        self.assertLess(doc.index('id: source_gate'), doc.index('name: Configure SSH'))
        self.assertLess(doc.index('id: source_gate'), doc.index('name: Upload verified Godot game'))

    def test_superseded_source_is_failed_not_successful_noop(self):
        gate = self.body.split('      - name: Reject superseded Godot source BEFORE any SSH or file upload',1)[1].split('      - name: Verify release-integrity failure conditions',1)[0]
        self.assertIn('ready=false', gate)
        self.assertIn('::error::SUPERSEDED', gate)
        self.assertRegex(gate, r'(?s)ready=false.*exit 3')
        self.assertNotIn('exit 0', gate)

    def test_sha_from_manifest_is_validated(self):
        self.assertIn('release.json"))["source_commit"]',self.body)
        self.assertIn('^'+'[0-9a-f]{40}'+'$',self.body)
        self.assertIn('::error::Invalid game release source SHA',self.body)

    def test_all_sensitive_steps_are_gated(self):
        for section in [
            'Verify release-integrity failure conditions',
            'Verify exact native Godot binary artifacts',
            'Configure SSH to existing OSGARD VPS',
            'Upload verified Godot game, activate with rollback'
        ]:
            pos=self.body.index('      - name: '+section)
            next_step=self.body.find('      - name:',pos+8)
            segment=self.body[pos:next_step if next_step!=-1 else None]
            self.assertIn("if: steps.source_gate.outputs.ready == 'true'",segment,section)

    def test_no_old_game_upload_after_source_advance(self):
        section=self.body.split('      - name: Upload verified Godot game, activate with rollback',1)[1]
        second_check='python3 scripts/omega-build-freshness.py'
        self.assertIn('id: publish',section)
        self.assertIn(second_check,section)
        self.assertLess(section.index(second_check),section.index('scp -i ~/.ssh/osgard_omega_deploy'))
        self.assertIn('deployed=false',section)
        self.assertIn('exit 3',section.split('scp -i ~/.ssh/osgard_omega_deploy')[0])
        self.assertNotIn('exit 0',section.split('scp -i ~/.ssh/osgard_omega_deploy')[0])
        self.assertIn('deployed=true',section)
        self.assertLess(section.index('bash \'$remote/deploy.sh\''),section.index('deployed=true'))

    def test_third_freshness_gate_after_scp_before_actual_activation(self):
        upload = self.body.split('      - name: Upload verified Godot game, activate with rollback', 1)[1]
        upload = upload.split('      - name: Verify exact live Godot source', 1)[0]
        stage = 'scp -i ~/.ssh/osgard_omega_deploy scripts/deploy-omega-native-remote.sh'
        last_scp = upload.index(stage)
        third = upload.index('if ! python3 scripts/omega-build-freshness.py', last_scp)
        activate = upload.index('"bash \\'$remote/deploy.sh\\' \\'$RUN_ID\\'"', last_scp)
        self.assertLess(last_scp, third)
        self.assertLess(third, activate)
        reject = upload[third:activate]
        self.assertIn('::error::SUPERSEDED after SCP', reject)
        self.assertIn('deployed=false', reject)
        self.assertIn('omega-native-remote-cleanup.sh', reject)
        self.assertIn('exit 3', reject)
        self.assertNotIn('exit 0', reject)

    def test_live_attestation_only_if_deployed(self):
        section=self.body.split('      - name: Verify exact live Godot source and downloaded SHA-256 for every file',1)[1]
        self.assertIn("if: steps.publish.outputs.deployed == 'true'",section)
        self.assertIn('omega-live-integrity.py',section)

    def test_server_rollback_lock_retained(self):
        script=Path("scripts/deploy-omega-native-remote.sh").read_text(encoding="utf-8")
        for required in ['flock -w 600','sha256sum -c SHA256SUMS.txt',
                         'previous=', 'mv "$previous" "$target"']:
            self.assertIn(required,script)

if __name__=="__main__":
    unittest.main(verbosity=2)
