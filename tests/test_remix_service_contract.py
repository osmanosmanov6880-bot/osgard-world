"""Unit checks for contract validation, not a substitute for the real service run."""

import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location(
    "remix_service_contract", Path(__file__).parents[1] / "scripts/remix-service-contract-smoke.py")
contract = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(contract)

MATCH_ID = "match_20261017095147.729756227_4"
PLAYER_ID = "qa-remix-observed"


def response(body, status=200, content_type="application/json"):
    return {"status": status, "contentType": content_type, "body": body,
            "method": "GET", "path": "/v1/matches/own/result"}


def result(score=0.03333333333333333, frames=2):
    return {"matchId": MATCH_ID, "phase": "RESULTS", "replayFrames": frames,
            "scores": [{"playerId": PLAYER_ID, "score": score}]}


class RemixContractValidation(unittest.TestCase):
    def test_writes_are_opt_in(self):
        self.assertFalse(contract.parse_args([]).exercise)
        self.assertTrue(contract.parse_args(["--exercise"]).exercise)

    def test_url_rejects_credentials_or_query_and_preserves_api_prefix(self):
        self.assertEqual(contract.validate_base("https://osgard.world/api/remix/"), "https://osgard.world/api/remix")
        for base in ("/api/remix", "https://user:secret@example.test", "https://@example.test",
                     "https://example.test?token=secret", "https://example.test#fragment", "file:///tmp/api",
                     "https://example.test:invalid"):
            with self.subTest(base=base), self.assertRaises(contract.ContractFailure):
                contract.validate_base(base)

    def test_server_ids_allow_actual_timestamp_dots_but_not_path_traversal(self):
        self.assertEqual(contract.identifier(MATCH_ID, "match.id"), MATCH_ID)
        for bad in ("../another", "..", "/other", "x?token=y", "x%2fy", "x" * 129, ""):
            with self.subTest(value=bad), self.assertRaises(contract.ContractFailure):
                contract.identifier(bad, "match.id")

    def test_html_or_wrong_http_status_cannot_pass_as_a_server_result(self):
        for bad in (response("<html>SPA</html>", content_type="text/html"),
                    response(result(), status=409), response([], content_type="application/json")):
            with self.subTest(response=bad), self.assertRaises(contract.ContractFailure):
                contract.validate_result(bad, MATCH_ID)

    def test_result_accepts_observed_schema_without_inventing_replay_key(self):
        value = contract.validate_result(response(result()), MATCH_ID)
        self.assertEqual(value["replayFrames"], 2)
        self.assertNotIn("replayKey", value)

    def test_result_rejects_nonfinite_boolean_or_overflow_score(self):
        for value in (float("nan"), float("inf"), -float("inf"), True, "0.1", 10 ** 400):
            with self.subTest(score=str(value)[:30]), self.assertRaises(contract.ContractFailure):
                contract.validate_result(response(result(score=value)), MATCH_ID)

    def test_result_rejects_other_match_and_duplicate_player(self):
        with self.assertRaisesRegex(contract.ContractFailure, "different match"):
            contract.validate_result(response(result()), "other-match")
        duplicate = result()
        duplicate["scores"].append(copy.deepcopy(duplicate["scores"][0]))
        with self.assertRaisesRegex(contract.ContractFailure, "duplicate"):
            contract.validate_result(response(duplicate), MATCH_ID)

    def test_result_rejects_nonterminal_phase_or_invalid_frame_count(self):
        for field, value in (("phase", "PLAYING"), ("replayFrames", True), ("replayFrames", -1)):
            invalid = result()
            invalid[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(contract.ContractFailure):
                contract.validate_result(response(invalid), MATCH_ID)

    def test_terminal_immutability_detects_the_observed_late_input_bug(self):
        before = result()
        after = result(score=0.05, frames=3)
        with self.assertRaisesRegex(contract.ContractFailure, "Terminal result changed"):
            contract.require_immutable(before, after)
        contract.require_immutable(before, copy.deepcopy(before))

    def test_terminal_immutability_is_independent_of_roster_order(self):
        before = result()
        before["scores"].append({"playerId": "qa-second-player", "score": 0.1})
        after = copy.deepcopy(before)
        after["scores"].reverse()
        contract.require_immutable(before, after)

    def test_input_acknowledgement_rejects_wrong_player_sequence_and_world_shape(self):
        body = {"playerId": PLAYER_ID, "position": [0.08333333333333333, 0, 0],
                "velocityY": 0, "onGround": True, "score": 0.016666666666666666, "lastSequence": 1}
        contract.validate_input(response(body), PLAYER_ID, 1)
        for field, value in (("playerId", "another-player"), ("lastSequence", True), ("lastSequence", 2),
                             ("position", [0, 0]), ("velocityY", float("nan")), ("onGround", 1)):
            invalid = copy.deepcopy(body)
            invalid[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(contract.ContractFailure):
                contract.validate_input(response(invalid), PLAYER_ID, 1)

    def test_state_rejects_wrong_roster_and_nonzero_terminal_clock(self):
        body = {"id": MATCH_ID, "phase": "RESULTS", "players": 1, "remainingMs": 0,
                "replayFrames": 2, "scores": result()["scores"]}
        contract.validate_state(response(body), MATCH_ID)
        for field, value in (("remainingMs", 10), ("players", 0), ("players", True), ("phase", "UNKNOWN")):
            invalid = copy.deepcopy(body)
            invalid[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(contract.ContractFailure):
                contract.validate_state(response(invalid), MATCH_ID)

    def test_existing_report_is_not_overwritten_before_network(self):
        with tempfile.TemporaryDirectory() as root:
            output = Path(root) / "report.json"
            output.write_text("keep this evidence", encoding="utf-8")
            with self.assertRaisesRegex(contract.ContractFailure, "overwrite"):
                contract.Run("https://example.test/api/remix", False, output, 90)
            self.assertEqual(output.read_text(encoding="utf-8"), "keep this evidence")


if __name__ == "__main__":
    unittest.main()
