"""Offline quality gate for R135 rebuilt GLB and texture assets."""
from pathlib import Path
import hashlib
import json
import struct
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_GLB = {
    "eco": "c6bbc41c53e596d5048371e639a662cd2a75d58a02f75c9df93ffced7685533b",
    "hero": "8ef33e28534c7c41d4adaceee4e479e38da92287a99bbd5fd53b9fc9318c0078",
}

def test_reproduced_models_are_bit_exact():
    for level, expected in EXPECTED_GLB.items():
        path = ROOT / "models/r135" / f"service_spine_{level}.glb"
        blob = path.read_bytes()
        assert blob[:4] == b"glTF"
        assert hashlib.sha256(blob).hexdigest() == expected
        info = json.loads(path.with_suffix(".manifest.json").read_text())
        assert info["sha256"] == expected
        assert info["batched_mesh_count"] == 12
        assert info["simulation_only"] is True
        assert info["real_hardware_connected"] is False
        length = struct.unpack_from("<I", blob, 12)[0]
        gltf = json.loads(blob[20:20 + length])
        assert len(gltf["meshes"]) == 12
        assert len(gltf["materials"]) == 12
        assert len(gltf["images"]) >= 36

def test_all_36_pbr_maps_present():
    textures = sorted((ROOT / "textures/r135").glob("*.png"))
    assert len(textures) == 36
    surfaces = {x.stem.rsplit("_", 1)[0] for x in textures}
    assert len(surfaces) == 12
    for surface in surfaces:
        for suffix in ("albedo", "normal", "orm"):
            path = ROOT / "textures/r135" / f"{surface}_{suffix}.png"
            assert path.is_file()
            with Image.open(path) as im:
                assert im.size == (1024, 1024)
                assert im.mode == "RGB"
