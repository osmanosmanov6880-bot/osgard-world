#!/usr/bin/env python3
"""Strict reproducible PBR validation; no artwork-only placeholder files."""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True, choices=("vector-zero", "time-empire"))
    ap.add_argument("--root", default="godot")
    args = ap.parse_args()
    directory = Path(args.root) / args.project / "assets" / "wave6"
    data = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
    assert data["schema"] == "osgard.wave6.pbr.sheets.v1"
    assert len(data["materials"]) == 3
    for material, config in data["materials"].items():
        assert len(config["maps"]) == 4
        for rel in config["maps"]:
            source = directory / rel
            assert source.exists(), source
            assert source.stat().st_size > 1000, source
            im = Image.open(source)
            assert im.size == (data["size"], data["size"]), source
            a = np.asarray(im).astype(np.float32)
            assert a.std() > 0.1, f"flat placeholder: {source}"
        n = np.asarray(Image.open(directory / material / "normal.png"), dtype=np.float32) / 127.5 - 1.0
        lengths = np.linalg.norm(n, axis=2)
        assert np.mean(abs(lengths - 1)) < 0.015, material
        assert float(np.mean(n[:, :, 2])) > 0.55, material
    print("WAVE6_PBR_VALIDATED", args.project, len(data["materials"]) * 4)


if __name__ == "__main__":
    main()