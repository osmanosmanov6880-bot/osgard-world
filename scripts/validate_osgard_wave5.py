#!/usr/bin/env python3
"""Static import-independent verification before the full Godot 4.7.2 CI gate."""
import argparse, json
from pathlib import Path
import trimesh
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
NAMES={"vector-zero":("coolant_skid","containment_vault","service_gantry"),
       "time-empire":("arcology_cluster","transit_concourse","solar_substation")}

def validate(game):
    folder=ROOT/'godot'/game/'assets'/'wave5'
    data=json.loads((folder/'manifest.json').read_text())
    assert data['project']==game
    for name in NAMES[game]:
        counts={}
        for lod in ('ultra','web'):
            path=folder/f'{name}_{lod}.glb'
            assert path.exists() and path.stat().st_size>15000
            scene=trimesh.load(path,force='scene')
            faces=sum(len(g.faces) for g in scene.geometry.values())
            assert faces>=500, (name,lod,faces)
            counts[lod]=faces
            assert len(scene.geometry)>=3, (name,lod)
            assert all(g.vertices.shape[0] and not g.is_empty for g in scene.geometry.values())
        assert counts['ultra']>=counts['web'],(name,counts)
        print('PASS',name,counts)
    for name in ('panel_albedo','panel_normal','panel_roughness'):
        p=folder/'surfaces'/f'{name}.png'
        im=Image.open(p)
        assert im.width>=512 and im.height>=512
        im.verify()
    return True

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--project',choices=NAMES,required=True)
    args=a.parse_args()
    validate(args.project)
    print('WAVE5 ASSETS PASS',args.project)