#!/usr/bin/env python3
"""OSGARD Wave 5: authored modular environment GLB assets + tileable wear-aware PBR.

Deterministic geometry and surface maps; no copyrighted or stock content. Generates
independent PC / browser LODs. Runs ahead of Godot import in CI, not at runtime.
"""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import numpy as np
import trimesh
from PIL import Image
from build_osgard_wave4_assets import Asset, box, cylinder, lathe, ring, tube, translate, TAU

ROOT = Path(__file__).resolve().parents[1]


def oriented_box(size, pos, angle=0.0):
    m=box(*size)
    if angle:
        m.apply_transform(trimesh.transformations.rotation_matrix(angle,(0,1,0)))
    m.apply_translation(pos)
    return m


def hardware_loop(asset, radius, y, size, count, mat='graphite', segments=14):
    for i in range(count):
        a=TAU*i/count
        asset.add(mat,cylinder(size,size*2,y,radius*math.cos(a),radius*math.sin(a),seg=segments))


def add_window(asset, w, h, d, x,y,z, tint='darkglass'):
    asset.add(tint,box(w,h,d,x,y,z))
    asset.add('titanium',box(w+0.12,0.075,d+0.04,x,y+h*0.5,z))
    asset.add('graphite',box(w+0.12,0.075,d+0.04,x,y-h*0.5,z))


def coolant(lod):
    seg=54 if lod else 22
    a=Asset()
    a.add('graphite',box(3.0,0.28,1.9,0,0.14,0))
    a.add('titanium',box(2.8,0.12,1.72,0,.34,0))
    for x in [-.76,.76]:
        a.add('graphite',translate(lathe([(.10,.45),(.56,.45),(.64,.65),(.61,.95),(.61,3.28),(.64,3.4),(.52,3.65),(.10,3.65)],seg),x,0,0))
        for y in [.72,1.50,2.2,3.13]:
            a.add('titanium',translate(ring(.65,.065,y,seg),x,0,0))
        for s in [-1,1]:
            a.add('copper',box(.15,3.0,.14,x+s*.68,1.95,0))
        a.add('cyan',box(.36,.58,.09,x,2.1,.64))
        hardware_loop(a,.54,3.55,.065,14,'gold',10)
    for z in [-.85,.85]:
        a.add('ceramic',box(2.7,.14,.14,0,.47,z))
    for i in range(4):
        x=-1.12+float(i%2)*2.24; z=-.73+float(i//2)*1.46
        a.add('titanium',box(.13,3.6,.13,x,1.9,z))
        a.add('gold',cylinder(.17,.10,3.7,x,z,seg=12))
    # An original CNC turbine wheel and shrouded fan assembly
    a.add('graphite',translate(ring(.48,.12,2.62,seg),0,0,.96))
    for i in range(12 if lod else 6):
        ang=TAU*i/(12 if lod else 6)
        a.add('titanium',oriented_box((.10,.07,.40),(.37*math.cos(ang),2.62,.96+.37*math.sin(ang)),ang))
    return a


def vault(lod):
    a=Asset();seg=56 if lod else 24
    a.add('graphite',box(5.6,7.2,.76,0,3.6,0))
    a.add('titanium',box(5.2,6.86,.22,0,3.6,.42))
    a.add('ceramic',box(4.65,6.3,.12,0,3.6,.58))
    for x in [-2.42,-1.3,0,1.3,2.42]:
        a.add('graphite',box(.14,6.75,.28,x,3.6,.64))
    for y in [1.0,1.8,3.6,5.4,6.2]:
        a.add('titanium',box(5.3,.12,.28,0,y,.68))
    for x in [-2.65,2.65]:
        a.add('gold',box(.12,6.9,.22,x,3.6,.78))
    for y in [1.7,3.6,5.5]:
        a.add('graphite',translate(ring(.37,.11,y,seg,vertical=True),0,0,.86))
        a.add('copper',cylinder(.13,.18,0,0,0,12))
    for i in range(9):
        y=.85+.64*i
        add_window(a,.54,.28,.045,-1.76,y,.79,'cyan' if i%3==0 else 'darkglass')
    return a


def gantry(lod):
    a=Asset();seg=40 if lod else 20
    a.add('graphite',box(16.0,.64,1.25,0,.12,0))
    a.add('titanium',box(15.7,.22,1.40,0,.58,0))
    for x in np.linspace(-7.2,7.2,11 if lod else 7):
        for z in [-.65,.65]:
            a.add('graphite',box(.16,1.3,.15,float(x),-.18,z))
    for x in np.linspace(-6.9,6.9,8 if lod else 5):
        a.add('copper',box(.17,.18,1.10,float(x),.80,0))
        a.add('gold',box(.09,.08,.84,float(x),.93,0))
    for x in [-6.2,6.2]:
        a.add('titanium',translate(ring(.68,.12,-.35,seg),x,0,0))
        a.add('ceramic',cylinder(.28,.24,-.35,x,0,seg))
    # Multilayer maintenance bridge guardrail strips
    a.add('titanium',box(16.0,.08,.09,0,1.25,.68))
    a.add('titanium',box(16.0,.08,.09,0,1.25,-.68))
    return a


def arcology(lod):
    a=Asset();seg=64 if lod else 26
    h=15.8
    a.add('graphite',lathe([(2.3,0),(2.85,.2),(2.75,.8),(2.5,1.2),(2.38,4), (2.15,8),(1.94,11),(1.62,14.8),(.15,15.8)],seg))
    for j in range(15 if lod else 8):
        y=1.0+(float(j)+.5)*.85
        r=2.5-.06*j
        a.add('titanium',ring(r,.066,y,seg))
        if j%2==0:
            a.add('gold',ring(r+.08,.032,y+.15,seg))
    for i in range(16 if lod else 8):
        theta=TAU*i/(16 if lod else 8)
        r=2.4
        x,z=r*math.cos(theta),r*math.sin(theta)
        a.add('darkglass',oriented_box((.28,11,.11),(x,7,z),-theta))
        for k in range(9 if lod else 5):
            y=3+1.0*k
            a.add('cyan',box(.10,.12,.10,x,y,z))
    for y in [3.5,8.0,11.0]:
        a.add('ceramic',lathe([(2.0,y-.14),(2.85,y-.14),(3.1,y), (2.83,y+.14),(2.0,y+.14)],seg))
        hardware_loop(a,2.92,y,.045,24 if lod else 12,'gold',8)
    a.add('titanium',lathe([(.12,15.3),(.5,15.3),(.36,16.1),(.09,16.5)],seg))
    return a


def terminal(lod):
    a=Asset();seg=36 if lod else 18
    a.add('graphite',box(12.5,.55,4,0,.28,0))
    a.add('titanium',box(12.6,.12,4.2,0,.61,0))
    for x in [-5.25,-2.5,0,2.5,5.25]:
        for z in [-1.5,1.5]:
            a.add('titanium',box(.18,3.9,.2,x,2.4,z))
            a.add('gold',box(.27,.12,.30,x,4.29,z))
    # A stepped segmented arched canopy rather than floating rings.
    for j in range(12 if lod else 6):
        y=4.2+0.55*math.sin(math.pi*j/(12 if lod else 6))
        x=-5.3+(10.6*j/(11 if lod else 5))
        a.add('ceramic',box(1.02,.18,4.3,x,y,0))
        a.add('darkglass',box(.94,.04,3.75,x,y+.13,0))
    a.add('graphite',box(10.7,.08,.35,0,4.65,1.8))
    a.add('graphite',box(10.7,.08,.35,0,4.65,-1.8))
    for x in [-5.7,5.7]:
        a.add('copper',box(.22,.65,4.0,x,.95,0))
    for i in range(12):
        x=-5+i*.9
        a.add('cyan',box(.28,.04,.30,x,.68,-1.53))
    return a


def solar(lod):
    a=Asset();seg=32 if lod else 16
    a.add('graphite',box(6.4,.24,4.9,0,.12,0))
    for x in [-2.6,0,2.6]:
        a.add('titanium',box(.14,1.75,.15,x,1.0,0))
    for j in range(3):
        x=-2.45+j*2.45
        a.add('darkglass',oriented_box((2.03,.11,2.8),(x,2.15,-.34),-.21))
        a.add('cyan',box(1.87,.045,.14,x,2.21,1.0))
    for i in range(8):
        x=-2.8+(i%4)*1.85
        z=-1.85+(i//4)*3.7
        a.add('titanium',cylinder(.10,.3,.53,x,z,seg=seg))
    a.add('gold',translate(ring(.65,.10,.55,seg),0,0,1.3))
    return a


def generate_surface(project:str, folder:Path):
    """Three packed, tiled PBR atlases: realistic grime, edge wear and stamped steel."""
    n=768
    rng=np.random.default_rng(2123 if project=='vector-zero' else 3439)
    xx,yy=np.meshgrid(np.arange(n),np.arange(n))
    grid=np.minimum(np.mod(xx,192),192-np.mod(xx,192))
    grid=np.minimum(grid,np.minimum(np.mod(yy,192),192-np.mod(yy,192)))
    chamfer=np.clip((12-grid)/12,0,1)
    scratches=(np.sin(xx*.51+np.sin(yy*.031)*2.3)>.985).astype(float)
    dirt=np.clip(rng.normal(0,.85,(n,n)) + .7*np.sin(xx*.037+yy*.026)+.4*np.sin(yy*.12),-2.4,2.4)
    oil=np.clip(np.cos(xx*.008-yy*.019)*np.sin(yy*.013+xx*.027),-.8,.8)
    rivets=((np.mod(xx,192)-18)**2+(np.mod(yy,192)-18)**2)<19
    if project=='vector-zero':
        base=np.array([97,120,137],dtype=float)
    else:
        base=np.array([137,143,136],dtype=float)
    shaded=(base.reshape(1,1,3) + dirt[:,:,None]*8 - chamfer[:,:,None]*19 + scratches[:,:,None]*25 - oil[:,:,None]*8)
    shaded=np.clip(shaded+rivets[:,:,None]*22,0,255).astype(np.uint8)
    normal=np.dstack([np.gradient(chamfer+scratches*.30)[1]*-.14,
                      np.gradient(chamfer+scratches*.30)[0]*-.14,
                      np.ones((n,n))])
    normal/=np.linalg.norm(normal,axis=2,keepdims=True)
    normal=np.uint8(np.clip(normal*.5*255+127,0,255))
    # White == maximum roughness; roughness is separate greyscale R texture.
    rough=np.uint8(np.clip(142+dirt*12+chamfer*32+oil*13-scratches*22,25,250))
    folder.mkdir(parents=True,exist_ok=True)
    Image.fromarray(shaded,'RGB').save(folder/'panel_albedo.png',optimize=True)
    Image.fromarray(normal,'RGB').save(folder/'panel_normal.png',optimize=True)
    Image.fromarray(rough,'L').save(folder/'panel_roughness.png',optimize=True)
    return [str(folder/x) for x in ('panel_albedo.png','panel_normal.png','panel_roughness.png')]


def build(project:str):
    options={'vector-zero':{'coolant_skid':coolant,'containment_vault':vault,'service_gantry':gantry},
             'time-empire':{'arcology_cluster':arcology,'transit_concourse':terminal,'solar_substation':solar}}
    assert project in options
    base=ROOT/'godot'/project/'assets'/'wave5'
    catalog=[]
    for name,fn in options[project].items():
        for lod in ('ultra','web'):
            model=fn(1 if lod=='ultra' else 0)
            fname=base/f'{name}_{lod}.glb'
            row=model.export(fname,384 if lod=='ultra' else 256)
            assert row['faces']>=500 and row['bytes']>10000, row
            catalog.append({'name':name,'lod':lod,'path':str(fname.relative_to(ROOT)),**{x:row[x] for x in ('faces','mesh_count','bytes')}})
    generate_surface(project,base/'surfaces')
    index={'project':project,'assets':catalog,'source':'Original OSGARD Wave 5 generated geometry. GPU measurements are separate.'}
    (base/'manifest.json').write_text(json.dumps(index,indent=2),encoding='utf8')
    print(json.dumps(index,indent=2))
    return index


if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--project',required=True,choices=['vector-zero','time-empire'])
    ns=ap.parse_args();build(ns.project)