#!/usr/bin/env python3
"""Original modular glTF 2.0 PBR engineering meshes for OSGARD Godot.
Generates deterministic cinematic-quality authored 3D assets with an explicit
native / Web mesh density and real embedded basecolor, metal/rough, normal maps.
No protected third-party assets or photographs are used.
"""
from __future__ import annotations
import argparse
import json
import math
from collections import defaultdict
from pathlib import Path

import numpy as np
import trimesh
from PIL import Image
from trimesh.visual import TextureVisuals
from trimesh.visual.material import PBRMaterial

TAU = math.tau
ROOT = Path(__file__).resolve().parents[1]
RNG = np.random.default_rng(730241)

PALETTE = {
    "titanium": dict(rgb=(153, 178, 189), metallic=.91, roughness=.27),
    "graphite": dict(rgb=(73, 92, 107), metallic=.79, roughness=.41),
    "copper": dict(rgb=(203, 134, 77), metallic=.95, roughness=.25),
    "ceramic": dict(rgb=(206, 213, 209), metallic=.18, roughness=.32),
    "gold": dict(rgb=(216, 170, 83), metallic=.89, roughness=.28),
    "cyan": dict(rgb=(76, 219, 244), metallic=.31, roughness=.19, emissive=(0.12, .62, .90)),
    "violet": dict(rgb=(154, 109, 229), metallic=.30, roughness=.19, emissive=(0.46, .18, .85)),
    "darkglass": dict(rgb=(75, 132, 145), metallic=.22, roughness=.13),
    "sandstone": dict(rgb=(177, 184, 173), metallic=.28, roughness=.45),
}


def make_pbr(name: str, size: int) -> PBRMaterial:
    cfg=PALETTE[name]
    base=np.array(cfg['rgb'], dtype=float)[None, None, :]
    noise=RNG.normal(0, 5.0, (size,size,1))
    col=(np.sin(np.linspace(0,26*np.pi,size))[:,None,None]*3.6)
    stripe=(np.sin(np.linspace(0,85*np.pi,size))[None,:,None]*1.4)
    x=np.broadcast_to(np.arange(size)[None,:,None],(size,size,1))
    wear=(np.sin(x*.18 + np.arange(size)[:,None,None]*.011)>0.999) * 8
    color=np.clip(base+noise+col+stripe+wear,0,255).astype(np.uint8)
    color=np.repeat(color,1,axis=2)
    rgb=Image.fromarray(color,'RGB')
    # Channel G=roughness, B=metalness as required by glTF.
    rm=np.zeros((size,size,3),np.uint8)
    rm[:,:,1]=np.clip(cfg['roughness']*255 + RNG.normal(0,9,(size,size)),10,240)
    rm[:,:,2]=int(cfg['metallic']*255)
    roughmetal=Image.fromarray(rm,'RGB')
    h=RNG.normal(0,1.2,(size,size)).astype(np.float32)
    h+=(np.sin(np.linspace(0,45*np.pi,size))[:,None]*1.3)
    dy,dx=np.gradient(h)
    nx=-dx*.12;ny=-dy*.12
    norm=np.stack((nx,ny,np.ones_like(nx)),axis=2)
    norm/=np.linalg.norm(norm,axis=2,keepdims=True)
    norm=np.uint8(np.clip((norm*.5+.5)*255,0,255))
    normal=Image.fromarray(norm,'RGB')
    return PBRMaterial(name=name,baseColorFactor=[255,255,255,255],
        metallicFactor=1.0,roughnessFactor=1.0,
        baseColorTexture=rgb,metallicRoughnessTexture=roughmetal,
        normalTexture=normal, emissiveFactor=list(cfg.get('emissive',(0.,0.,0.))),doubleSided=False)


def translate(mesh: trimesh.Trimesh,x=0,y=0,z=0):
    mesh.apply_translation((x,y,z));return mesh


def ring(major:float, minor:float,y:float, seg:int, tube:int|None=None,vertical=False):
    shape=trimesh.creation.torus(major,minor,major_sections=seg,
        minor_sections=tube or max(8,seg//3))
    if not vertical:
        shape.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[1,0,0]))
    return translate(shape,0,y,0)


def cylinder(r:float,h:float,y:float=0,x:float=0,z:float=0,seg:int=48):
    return translate(trimesh.creation.cylinder(radius=r,height=h,sections=seg),x,y,z)


def box(xsize,ysize,zsize,x=0,y=0,z=0):
    return translate(trimesh.creation.box(extents=(xsize,ysize,zsize)),x,y,z)


def lathe(profile, segments:int):
    """Create a CNC-contour / body of revolution around Y with UV-compatible indexing."""
    positions=[];faces=[]
    for rad,y in profile:
        for i in range(segments):
            a=TAU*i/segments
            positions.append((rad*math.cos(a),y,rad*math.sin(a)))
    for j in range(len(profile)-1):
        for i in range(segments):
            v=j*segments+i;vn=j*segments+(i+1)%segments
            a=v;b=vn;c=vn+segments;d=v+segments
            faces.append((a,c,b));faces.append((a,d,c))
    return trimesh.Trimesh(vertices=np.asarray(positions),faces=np.asarray(faces),process=False)


def helix(radius:float,start_y:float,end_y:float,loops:float,width:float,segments:int=550,sides:int=10,phase=0):
    path=[]
    for j in range(segments+1):
        u=j/segments; a=phase+TAU*loops*u
        path.append([radius*math.cos(a),start_y+(end_y-start_y)*u,radius*math.sin(a)])
    return tube(np.asarray(path),width,sides)


def tube(path:np.ndarray,radius:float,sides:int=12):
    positions=[];faces=[]
    for j,p in enumerate(path):
        direction=(path[min(j+1,len(path)-1)]-path[max(j-1,0)]).astype(float)
        direction/=max(np.linalg.norm(direction),1e-9)
        seed=np.array([0.,1.,0.]) if abs(direction[1])<0.9 else np.array([1.,0.,0.])
        right=np.cross(direction,seed);right/=max(np.linalg.norm(right),1e-9)
        up=np.cross(direction,right)
        for k in range(sides):
            a=k*TAU/sides
            v=p+radius*(right*math.cos(a)+up*math.sin(a))
            positions.append(v)
        if j:
            for k in range(sides):
                n=(k+1)%sides
                a=(j-1)*sides+k;b=(j-1)*sides+n
                c=j*sides+n;d=j*sides+k
                faces.extend([(a,b,c),(a,c,d)])
    return trimesh.Trimesh(vertices=np.asarray(positions),faces=np.asarray(faces),process=False)


def curved_spire(height:float, radius:float, twist:float,segments:int,steps:int=50):
    # Author-built silhouette, unlike repeating BoxMesh stock geometry.
    outline=np.array([[1.0,0],[0.85,0.44],[0.52,0.87],[-0.08,1],[-0.63,.83],[-.96,.35],[-.85,-.45],[-.41,-.9],[.37,-.98],[.91,-.51]],dtype=float)
    vertices=[];faces=[]
    for j in range(steps+1):
        t=j/steps
        scale=radius*(1.0-0.42*t)*(1+0.045*math.sin(t*TAU*4))
        ang=twist*t
        rot=np.array([[math.cos(ang),-math.sin(ang)],[math.sin(ang),math.cos(ang)]])
        for p in outline:
            x,z=rot@p*scale
            vertices.append((x,height*t,z))
        if j:
            n=len(outline)
            for k in range(n):
                a=(j-1)*n+k;b=(j-1)*n+(k+1)%n;c=j*n+(k+1)%n;d=j*n+k
                faces.extend([(a,c,b),(a,d,c)])
    return trimesh.Trimesh(vertices=np.asarray(vertices),faces=np.asarray(faces),process=False)


class Asset:
    def __init__(self):
        self.geom=defaultdict(list)
    def add(self,material:str, mesh:trimesh.Trimesh):
        if mesh is None or len(mesh.faces)==0:return
        self.geom[material].append(mesh)
    def export(self,path:Path,texture:int):
        scene=trimesh.Scene()
        total_faces=0
        for name,meshes in self.geom.items():
            combined=trimesh.util.concatenate(meshes)
            positions=np.asarray(combined.vertices)
            uv=np.stack((np.mod(positions[:,0]*0.33+positions[:,2]*0.08,1.0),
                         np.mod(positions[:,1]*0.23+positions[:,2]*0.12,1.0)),axis=1)
            combined.visual=TextureVisuals(uv=uv,material=make_pbr(name,texture))
            scene.add_geometry(combined,geom_name=f"Wave4_{name}",node_name=f"{name}_hardware")
            total_faces+=len(combined.faces)
        path.parent.mkdir(parents=True,exist_ok=True)
        blob=scene.export(file_type='glb')
        path.write_bytes(blob)
        return {"path":str(path),"faces":total_faces,"mesh_count":len(self.geom),"bytes":len(blob),"density":"PC ULTRA" if 'ultra' in path.name else "WEB LOD"}


def magnet(lod:int):
    a=Asset();seg=72 if lod==1 else 36
    a.add('graphite',lathe([(0.82,-2.2),(1.12,-2.2),(1.33,-2.03),(1.2,-1.9),
        (1.07,-1.6),(1.07,1.6),(1.2,1.9),(1.33,2.03),(1.12,2.2),(.82,2.2)],seg))
    for y in [-2.08, -1.60,0.0,1.60,2.08]:
        a.add('titanium',ring(1.5,.12,y,seg))
    for y in np.linspace(-1.66,1.66,13 if lod else 9):
        a.add('copper',ring(1.30,.071,float(y),seg))
    for phase in [0,math.pi/2]:
        a.add('copper',helix(1.45,-1.8,1.8,6.7,.065,650 if lod else 250,12 if lod else 7,phase))
    for i in range(12):
        ang=i*TAU/12
        radial=np.array([math.cos(ang),0,math.sin(ang)])
        strut=box(.17,3.9,.23)
        strut.apply_transform(trimesh.transformations.rotation_matrix(-ang,[0,1,0]));strut.apply_translation(radial*1.83)
        a.add('titanium',strut)
        for y in [-1.84,1.84]:
            a.add('gold',cylinder(.11,.22,y,float(radial[0]*1.8),float(radial[2]*1.8),14 if lod else 10))
        if i%2==0:
            a.add('cyan',box(.09,2.8,.09,radial[0]*1.95,0,radial[2]*1.95))
    for y in [-2.28,2.28]:
        a.add('graphite',lathe([(1.38,y-.17),(1.93,y-.17),(2.03,y-.06),
           (2.03,y+.09),(1.91,y+.17),(1.38,y+.17)],seg))
    for i in range(28 if lod else 16):
        angle=i*TAU/(28 if lod else 16)
        for y in [-2.22,2.22]:
            a.add('ceramic',cylinder(.062,.10,y,1.76*math.cos(angle),1.76*math.sin(angle),12 if lod else 8))
    return a


def receiver(lod):
    a=Asset();seg=80 if lod else 40
    for r,t in [(1.55,.20),(1.16,.11),(.83,.08)]:
        a.add('titanium',ring(r,t,0.0,seg,vertical=True))
    for i in range(12):
        ang=i*TAU/12
        v=math.cos(ang);w=math.sin(ang)
        # Iris mechanical spokes and movable capture petals.
        blade=box(.16,.27,.8,v*1.26,w*.12,w*1.26)
        blade.apply_transform(trimesh.transformations.rotation_matrix(ang,[0,1,0]))
        a.add('graphite',blade)
        a.add('copper',box(.09,.31,.1,v*1.22,0,w*1.22))
        a.add('cyan',cylinder(.07,.23,0,v*1.7,w*1.7,seg=12))
    for r in [1.85,2.05]:
        a.add('graphite',ring(r,.04,-.18,seg,vertical=True))
    a.add('darkglass',trimesh.creation.icosphere(subdivisions=3 if lod else 2,radius=.46))
    a.add('cyan',ring(.55,.08,0,seg,vertical=True))
    return a


def reactor(lod):
    a=Asset();seg=84 if lod else 42
    a.add('graphite',lathe([(2.8,0),(3.65,0),(3.85,.28),(3.7,.66),
       (2.45,.90),(2.20,1.85),(2.05,3.80),(1.75,5.35),
       (1.65,7.35),(1.83,7.65),(2.25,8.05),(2.10,8.25)],seg))
    for y,r in [(0.3,3.70),(.9,2.50),(1.6,2.4),(2.3,2.20),(4.0,2.05),(5.5,1.78),(7.1,1.69),(8.15,2.20)]:
        a.add('gold',ring(r,.10,y,seg))
    for i in range(16 if lod else 10):
        ang=i*TAU/(16 if lod else 10)
        radial=np.array([math.cos(ang),0.,math.sin(ang)])
        for h in [1.65,3.65,5.65]:
            a.add('titanium',box(.13,1.6,.25,radial[0]*2.35,h,radial[2]*2.35))
        a.add('copper',cylinder(.15,6.6,4.2,2.65*radial[0],2.65*radial[2],seg=14 if lod else 9))
    for phase in [0,math.pi]:
        a.add('cyan',helix(1.97,2.0,7.9,5.5,.07,600 if lod else 250,10 if lod else 6,phase))
    a.add('gold',ring(2.88,.18,8.2,seg))
    for y in [1.2,3.4,5.6]:
        a.add('ceramic',ring(2.47,.08,y,seg))
    return a


def civic_tower(lod):
    a=Asset();seg=64 if lod else 32
    a.add('graphite',lathe([(0,0),(3.4,0),(3.6,.25),(3.4,.9),(2.68,1.3),(2.6,2.1)],seg))
    a.add('titanium',curved_spire(19.8,2.5,.65,seg,steps=90 if lod else 45))
    for y in np.arange(2.0,19.8,.67 if lod else 1.1):
        a.add('ceramic',ring(2.50*(1-.42*y/19.8),.08,float(y),seg))
    for idx in range(10):
        theta=TAU*idx/10
        a.add('copper',helix(2.56,1.5,18.5,0.30,.075,110 if lod else 75,8 if lod else 6,theta))
    for y,r in [(1.2,2.9),(6.6,2.30),(13.8,1.72),(19.4,1.30)]:
        a.add('gold',ring(r,.16,y,seg))
    a.add('cyan',trimesh.creation.icosphere(subdivisions=3 if lod else 2,radius=.62).apply_translation([0.,21.2,0.]))
    for idx in range(10):
        th=TAU*idx/10
        a.add('cyan',box(.11,15.0,.09,2.34*math.cos(th),10.0,2.34*math.sin(th)))
    return a


def create(project: str = "both"):
    artifacts=[]
    targets=[('vector-zero','blackfield_magnet',magnet),('vector-zero','blackfield_receiver',receiver),
        ('time-empire','chronos_reactor',reactor),('time-empire','civic_spire',civic_tower)]
    for target_project,name,fn in targets:
        if project not in ("both", target_project):
            continue
        for lod in (1,0):
            obj=fn(lod)
            p=ROOT/'godot'/target_project/'assets'/'wave4'/(name+('_ultra' if lod else '_web')+'.glb')
            result=obj.export(p,512 if lod else 256)
            artifacts.append(result)
            print(json.dumps(result))
    (ROOT/'art_source').mkdir(parents=True, exist_ok=True)
    output=ROOT/'art_source'/('asset_manifest_'+project+'.json')
    output.write_text(json.dumps(artifacts,indent=2),encoding='utf-8')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--project',choices=('both','vector-zero','time-empire'),default='both')
    create(parser.parse_args().project)