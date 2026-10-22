#!/usr/bin/env python3
"""Validate real GLB geometry, PBR maps and desktop/Web LOD budgets."""
import argparse, struct, json
from pathlib import Path
import trimesh

BASE=Path(__file__).resolve().parents[1]
GROUPS={'vector-zero':('blackfield_magnet','blackfield_receiver'),
        'time-empire':('chronos_reactor','civic_spire')}

def glb_json(blob):
    assert blob[:4]==b'glTF', 'not binary glTF 2.0'
    n,t=struct.unpack_from('<II',blob,12)
    return json.loads(blob[20:20+n])

def validate(project):
    for name in GROUPS[project]:
        counts={}
        for suffix in ('ultra','web'):
            path=BASE/'godot'/project/'assets'/'wave4'/f'{name}_{suffix}.glb'
            blob=path.read_bytes(); meta=glb_json(blob)
            scene=trimesh.load(path,force='scene')
            tris=sum(len(m.faces) for m in scene.geometry.values())
            assert meta['asset']['version']=='2.0',meta['asset']
            assert len(meta['materials']) >= 4, f'{name}: insufficient separate physical surfaces'
            for m in meta['materials']:
                pbr=m.get('pbrMetallicRoughness',{})
                assert 'baseColorTexture' in pbr, 'missing albedo texture'
                assert 'metallicRoughnessTexture' in pbr, 'missing ORM texture'
                assert 'normalTexture' in m, 'missing normal map'
            assert tris > (17000 if suffix=='web' and 'receiver' not in name else 6000),f'Insufficient {suffix} geometry: {tris}'
            assert scene.is_empty is False
            counts[suffix]=tris
            print(f'PASS {project}/{name} {suffix}: {tris:,} triangles, {len(meta["materials"])} mapped PBR surfaces, {len(blob):,} bytes')
        assert counts['ultra'] > counts['web'] * 3.1, f'LOD differentiation insufficient for {name}'
        print(f'PASS LOD reduction: {name} {100*(1-counts["web"]/counts["ultra"]):.0f}% fewer Web triangles')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--project',choices=tuple(GROUPS),required=True)
    validate(parser.parse_args().project)