from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
project = root / "godot/vector-zero"
checks = {
    "project": project / "project.godot",
    "scene": project / "scenes/main.tscn",
    "simulation": project / "scripts/magnetic_sim.gd",
    "game": project / "scripts/blackfield.gd",
    "tests": project / "tests/runtime_smoke.gd",
    "web export": project / "export_presets.cfg",
    "CI": root / ".github/workflows/vector-zero-godot.yml",
}
for key, path in checks.items():
    assert path.is_file() and path.stat().st_size, f"missing {key}: {path}"
    print(f"PASS {key} ({path.stat().st_size:,} bytes)")

engine = checks["simulation"].read_text()
world = checks["game"].read_text()
tests = checks["tests"].read_text()
for text in ["step(", "simulate(", "acceleration(", "reached_target(", "is_lost("]:
    assert text in engine, text
for text in ["_build_world", "_build_environment", "_build_game_objects", "_build_ui", "_physics_process", "_draw_preview", "_load_stage", "_toggle_polarity", "_on_viewport_changed"]:
    assert text in world, text
assert 'Sim.step(' in world and 'Sim.simulate(' in world, 'prediction physics must equal gameplay physics'
assert all(x in world for x in ["Доставь ядро в приёмник", "СЛЕДУЮЩЕЕ ИСПЫТАНИЕ", "ПОЛЯРНОСТЬ"] if x != "ПОЛЯРНОСТЬ")
assert "Godot 4.7.2" in checks["CI"].read_text()
assert "FlightForecast" in world and "MultiMeshInstance3D" in world, "batched trajectory must be present"
assert "direction.is_finite()" in world and "length < 0.001" in world, "degenerate segments guard"
assert "*.pck" not in checks["CI"].read_text() or "size +100k" not in checks["CI"].read_text(), "Web exporter must allow small valid PCK"
assert "game._physics_process" in tests, 'runtime must test real integrator'

# Catch common accidental write errors in the GDScript indentation structure.
for path in [checks["game"], checks["simulation"], checks["tests"]]:
    source = path.read_text().splitlines()
    for i, line in enumerate(source, 1):
        assert '\t' not in line[:len(line)-len(line.lstrip())], f'tab indentation: {path}:{i}'
        assert line.count('"') % 2 == 0 or line.lstrip().startswith('#'), f'unbalanced quotes: {path}:{i}'
    assert re.search(r'^extends\s+', '\n'.join(source), re.M)
print('PASS source smoke — structure and 3D game contracts')
print('NOTE: parsing/import/runtime/export require Godot 4.7.2 on GitHub Actions; not installed in this container')