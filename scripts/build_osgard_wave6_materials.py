#!/usr/bin/env python3
"""Reproducible authored PBR texture sheets for OSGARD Wave 6.

Uses a deterministic analytical height field, material-dependent wear and seeded
microtexture. Emits separate albedo, normal, roughness and metallic PNG maps.
Generated in GitHub CI before Godot editor import, no network or bought assets.
"""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image

MATERIALS = {
    "vector-zero": {
        "machined_steel": ((64, 83, 95), 0.85, 0.31, 53),
        "hazard_deck": ((72, 77, 75), 0.64, 0.49, 67),
        "ceramic_guard": ((168, 175, 178), 0.28, 0.37, 79),
    },
    "time-empire": {
        "civic_stone": ((126, 133, 126), 0.08, 0.72, 103),
        "titanium_facade": ((102, 124, 131), 0.82, 0.35, 107),
        "bronze_concourse": ((150, 111, 70), 0.71, 0.45, 113),
    },
}


def color_field(name: str, base, metal: float, rough: float, seed: int, n: int):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[:n, :n]
    xx = xx.astype(np.float32) / n
    yy = yy.astype(np.float32) / n

    # Layered brushed, cast, and rain-weathered relief at different scales.
    fine = rng.normal(0, 1, (n, n)).astype(np.float32)
    coarse = rng.normal(0, 1, (32, 32)).astype(np.float32)
    macro = np.asarray(Image.fromarray(coarse, mode="F").resize((n, n), Image.Resampling.BICUBIC))
    stroke = np.sin(yy * 2100 + np.sin(xx * 29) * 5) * 0.26
    relief = 0.22 * fine + 0.54 * macro + 0.09 * stroke

    if name == "hazard_deck":
        # A stamped anti-slip diamond pattern; normal map actually reflects it.
        ax = np.abs(np.mod(xx * 19 + yy * 19, 1) - 0.5)
        ay = np.abs(np.mod(xx * 19 - yy * 19, 1) - 0.5)
        relief += 0.90 * ((ax < 0.066) & (ay < 0.26)).astype(np.float32)
    elif name in ("civic_stone", "ceramic_guard"):
        # Large individually cast slabs with shallow recessed joints.
        seamx = (np.mod(xx * 4, 1) < 0.014)
        seamy = (np.mod(yy * 4, 1) < 0.014)
        relief -= 1.6 * (seamx | seamy).astype(np.float32)
    else:
        # Repeating broad alloy bands plus micro machining grooves.
        relief += 0.14 * np.sin(xx * 15.0 * np.pi)
        # Infrequent impact scratches across the same sheet.
        for _ in range(34):
            y0 = int(rng.integers(0, n))
            x0 = int(rng.integers(0, n))
            length = int(rng.integers(14, 110))
            for delta in range(length):
                tx = (x0 + delta) % n
                ty = (y0 + int(delta * 0.045)) % n
                relief[ty, tx] += 0.38
    wear = np.clip(0.25 * macro + 0.2 * np.sin(yy * 32 + xx * 11), -0.55, 0.55)
    illumination = np.clip(1 + relief * 0.065 + wear * 0.12, 0.70, 1.24)
    rgb = np.asarray(base, dtype=np.float32)[None, None, :] * illumination[:, :, None]
    rgb += fine[:, :, None] * np.array([2.0, 2.2, 2.3])[None, None, :]
    rgb = np.uint8(np.clip(rgb, 0, 255))

    # Godot StandardMaterial3D samples the green channel for roughness by default.
    rough_v = np.uint8(np.clip(255 * (rough + 0.10 * macro - relief * 0.065), 6, 251))
    metal_v = np.uint8(np.clip(255 * (metal - np.maximum(0, wear) * 0.095), 0, 255))

    grad_y, grad_x = np.gradient(relief)
    normal = np.stack((-grad_x * 3.3, -grad_y * 3.3, np.ones_like(relief)), axis=-1)
    normal /= np.maximum(np.linalg.norm(normal, axis=-1, keepdims=True), 1e-4)
    normal = np.uint8(np.clip((normal * 0.5 + 0.5) * 255, 0, 255))
    return rgb, rough_v, metal_v, normal


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True, choices=tuple(MATERIALS))
    ap.add_argument("--root", default="godot")
    ap.add_argument("--size", default=512, type=int)
    args = ap.parse_args()
    if args.size not in (256, 512, 1024):
        raise SystemExit("Texture size must be 256/512/1024")
    directory = Path(args.root) / args.project / "assets" / "wave6"
    directory.mkdir(parents=True, exist_ok=True)
    manifest = {"schema": "osgard.wave6.pbr.sheets.v1", "project": args.project, "size": args.size, "materials": {}}
    for name, (base, metal, rough, seed) in MATERIALS[args.project].items():
        albedo, roughmap, metalmap, normalmap = color_field(name, base, metal, rough, seed, args.size)
        folder = directory / name
        folder.mkdir(exist_ok=True)
        assets = {"albedo": albedo, "roughness": roughmap, "metallic": metalmap, "normal": normalmap}
        for kind, content in assets.items():
            Image.fromarray(content).save(folder / (kind + ".png"), optimize=True)
        manifest["materials"][name] = {"metallic": metal, "roughness": rough, "maps": [str(folder.relative_to(directory) / (k + ".png")) for k in assets]}
    (directory / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps({"status": "OK", "project": args.project, "textures": len(manifest["materials"]) * 4, "asset_root": str(directory)}))


if __name__ == "__main__":
    main()