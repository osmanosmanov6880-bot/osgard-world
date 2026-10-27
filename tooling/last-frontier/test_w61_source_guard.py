#!/usr/bin/env python3
"""Synthetic adversarial tests only. No real device or brand certification."""
import unittest
import w61_source_guard as g

class BrandScopeNegativeTests(unittest.TestCase):
    def test_allows_only_brand_paths(self):
        self.assertEqual(g.validate_paths(g.MANDATORY), sorted(g.MANDATORY))
    def test_rejects_mission_code(self):
        with self.assertRaisesRegex(ValueError, "Unauthorized"):
            g.validate_paths(set(g.MANDATORY) | {"w33-godot-native/scripts/OSGARDCore.gd"})
    def test_rejects_public_deployment_change(self):
        with self.assertRaisesRegex(ValueError, "Unauthorized"):
            g.validate_paths(set(g.MANDATORY) | {".github/workflows/deploy-production.yml"})
    def test_rejects_missing_brand_native_test(self):
        with self.assertRaisesRegex(ValueError, "Incomplete"):
            g.validate_paths(set(g.MANDATORY) - {"w33-godot-native/tests/test_w61_brand_and_phase_hud.gd"})
    def test_rejects_arbitrary_other_docs(self):
        with self.assertRaisesRegex(ValueError, "Unauthorized"):
            g.validate_paths(set(g.MANDATORY) | {"docs/unreviewed-changes.md"})
    def test_method_extract_deterministic(self):
        p="extends Control\nfunc alpha() -> void:\n    pass\n\nfunc beta() -> void:\n    pass\n"
        self.assertEqual(list(g.methods(p)), ["alpha", "beta"])
    def test_rejects_changed_mission_control_method(self):
        a="func _refresh() -> void:\n    pass\n\nfunc _engine_clicked() -> void:\n    pass\n"
        b=a.replace("func _engine_clicked() -> void:\n    pass", "func _engine_clicked() -> void:\n    print('changed')")
        with self.assertRaisesRegex(ValueError, "unrelated gameplay method"):
            g.validate_main_methods(a,b)
    def test_rejects_removed_gameplay_method(self):
        a="func _refresh() -> void:\n    pass\n"
        b=a+"\nfunc new_backdoor() -> void:\n    pass\n"
        with self.assertRaisesRegex(ValueError, "added/removed"):
            g.validate_main_methods(a,b)
    def test_rejects_missing_localization_entries(self):
        with self.assertRaisesRegex(ValueError, "localized brand"):
            g.validate_localization('const RU = {}','const RU = {}')
    def test_rejects_modified_original_text(self):
        original='BASE\n'
        entries=[
          '    "brand_desktop":"ПОСЛЕДНИЙ РУБЕЖ   /   ПРОТОКОЛ А7",\n',
          '    "brand_mobile":"ПОСЛЕДНИЙ РУБЕЖ",\n',
          '    "stage_facility":"ОБЪЕКТ A7  //  ДИАГНОСТИКА",\n',
          '    "stage_narrow":"A7  /  НАБЛЮДЕНИЕ",\n',
          '    "brand_desktop":"LAST FRONTIER   /   A7 PROTOCOL",\n',
          '    "brand_mobile":"LAST FRONTIER",\n',
          '    "stage_facility":"A7 FACILITY  //  LIVE DIAGNOSTICS",\n',
          '    "stage_narrow":"A7  /  OBSERVATION",\n'
        ]
        self.assertEqual(g.validate_localization(original,original+''.join(entries)),8)
        with self.assertRaisesRegex(ValueError, "original gameplay instruction"):
            g.validate_localization(original,original+'MODIFIED\n'+''.join(entries))

if __name__ == '__main__':
    unittest.main()
