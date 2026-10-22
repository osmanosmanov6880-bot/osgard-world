from pathlib import Path
p=Path(__file__).resolve().parents[1]
paths={
 'project': 'godot/time-empire/project.godot',
 'scene':'godot/time-empire/scenes/main.tscn',
 'game':'godot/time-empire/scripts/chrono_city.gd',
 'native-tests':'godot/time-empire/tests/runtime_smoke.gd',
 'export':'godot/time-empire/export_presets.cfg',
 'ci':'.github/workflows/time-empire-godot.yml'
}
for key, rel in paths.items():
 f=p/rel
 assert f.is_file() and f.stat().st_size, (key,rel)
 print('PASS',key,rel,f.stat().st_size,'bytes')
game=(p/paths['game']).read_text()
for keyword in ['_populate_skyline', '_build_district', '_upgrade_core', '_calculate_rate', '_toggle_map', '_save_game', '_load_game', '_resize_ui', 'MultiMeshInstance3D', 'Построй первый хроногенератор']:
 assert keyword in game,keyword
assert 'include-hidden-files: true' in (p/paths['ci']).read_text()
print('PASS source smoke (Godot native compilation in GitHub CI)')