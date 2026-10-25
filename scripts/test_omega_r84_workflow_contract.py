#!/usr/bin/env python3
"""R84 negative CI contracts. No original game or private QA media is mocked."""
import unittest
from omega_r84_workflow_contract import validate, WORKFLOW


class RealG0WorkflowContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = WORKFLOW.read_text(encoding="utf-8")

    def check_replacement_fails(self, needle: str, replacement: str):
        self.assertIn(needle, self.source, "contract fixture drift")
        with self.assertRaisesRegex(ValueError, "unsafe G0 release workflow"):
            validate(self.source.replace(needle, replacement, 1))

    def test_actual_workflow_is_fail_closed(self):
        validate(self.source)

    def test_unreviewed_pull_request_cannot_claim_live_production(self):
        self.check_replacement_fails(
            "github.ref == 'refs/heads/master'",
            "github.ref == 'refs/heads/feature'")

    def test_unpinned_source_rejected(self):
        self.check_replacement_fails(
            'omega-build-freshness.py "$source_sha" HEAD',
            'echo "$source_sha"')

    def test_unverified_manifest_flags_rejected(self):
        self.check_replacement_fails("strict_bytes=True", "strict_bytes=False")

    def test_partial_public_hash_evidence_rejected(self):
        self.check_replacement_fails(
            "assert d['status']=='PASS' and d['verified_files']==7",
            "assert d['status']=='PASS'")

    def test_software_renderer_is_actual_mesa(self):
        self.check_replacement_fails(
            "OMEGA_CI_GL_BACKEND: mesa", "OMEGA_CI_GL_BACKEND: swiftshader")

    def test_recovered_flaky_retries_rejected(self):
        self.check_replacement_fails(
            "--retries=0 --reporter=json", "--retries=2 --reporter=json")

    def test_synthetic_browser_json_rejected(self):
        self.check_replacement_fails(
            "--r50-browser omega-r84-evidence/playwright.json",
            "--r50-browser synthetic-fixture.json")

    def test_false_go_claim_rejected(self):
        self.check_replacement_fails(
            "v['production_go'] is False", "v['production_go'] is True")

    def test_false_aaa_claim_rejected(self):
        self.check_replacement_fails(
            "v['aaa_quality_certified'] is False",
            "v['aaa_quality_certified'] is True")

    def test_missing_physical_device_gate_rejected(self):
        self.check_replacement_fails(
            "'physical_ios_original_telemetry'", "'some_fake_gate'")

    def test_private_deploy_key_cannot_enter_read_only_qa(self):
        with self.assertRaisesRegex(ValueError, "deploy credentials"):
            validate(self.source + "\n      - run: echo secrets.DEPLOY_KEY\n")

    def test_no_public_artifact_is_not_acceptable(self):
        self.check_replacement_fails(
            "actions/upload-artifact@v4", "actions/checkout@v4")

    def test_changed_original_r83_reporter_forces_fresh_real_public_g0(self):
        self.check_replacement_fails(
            "      - 'scripts/omega_r83_release_gate.py'",
            "      - 'scripts/not-relevant-docs.py'")

    def test_unrestricted_push_rejected(self):
        self.check_replacement_fails(
            "  push:\n    branches: [master]",
            "  push:\n    branches: ['**']")

    def test_full_field_release_without_evidence_stays_hold(self):
        self.check_replacement_fails(
            "v['status']=='HOLD'",
            "v['status']=='READY_FOR_INDEPENDENT_HUMAN_SIGNOFF'")


if __name__ == "__main__":
    unittest.main(verbosity=2)
