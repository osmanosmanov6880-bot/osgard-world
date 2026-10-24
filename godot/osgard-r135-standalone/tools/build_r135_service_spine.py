#!/usr/bin/env python3
"""OSGARD R135: deterministic modular service spine and true glTF PBR maps.

No visual mesh pretends to be connected hardware. Geometry is authored in meters,
material families are batched, and both LODs preserve the same footprint.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image
import trimesh
from trimesh.visual.material import PBRMaterial

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / 'models' / 'r135'
TEXTURES = ROOT / 'textures' / 'r135'
SEED = 13520261023
# Albedo (sRGB 8 bit), metal factor, roughness and brushing strength.
SURFACES = {
 'galvanized_steel': ((94, 118, 129), .83, .44, .40),
 'brushed_aluminium': ((170, 188, 195), .91, .27, .83),
 'epoxy_floor': ((71, 83, 89), .07, .69, .16),
 'warm_copper': ((174, 107, 70), .91, .38, .38),
 'dielectric_gasket': ((26, 34, 41), .01, .85, .04),
 'frosted_glass': ((125, 174, 190), .02, .24, .08),
 'polymer_jacket': ((39, 69, 93), .02, .62, .14),
 'optical_fiber': ((41, 154, 201), .0, .24, .10),
 'warning_enamel': ((229, 134, 65), .10, .37, .11),
 'ceramic_insulation': ((199, 202, 190), .01, .72, .20),
 'service_paint': ((37, 51, 63), .33, .55, .35),
 'emission_bar': ((91, 208, 237), .0, .21, .04),
}

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def maps() -> dict:
    TEXTURES.mkdir(parents=True, exist_ok=True)
    n = 1024
    xx, yy = np.meshgrid(np.arange(n, dtype=np.float32) / n,
                         np.arange(n, dtype=np.float32) / n)
    result = {}
    for index, (name, (tint, metallic, roughness, brush)) in enumerate(SURFACES.items()):
        rng = np.random.default_rng(SEED + index)
        # Periodic surface fields: material grain, shallow dents, low-frequency wear.
        field = (.42*brush*np.sin(2*np.pi*(72*xx+4*yy))
                 + .25*np.sin(2*np.pi*(7*xx-5*yy))
                 + .19*np.cos(2*np.pi*(3*xx+2*yy))
                 + .10*np.sin(2*np.pi*(42*yy-19*xx)))
        field += rng.normal(0.0, .045, (n, n)).astype(np.float32)
        seam = (np.cos(2*np.pi*16*xx)**24) * .15
        dirt = np.maximum(0.0, .45 + .32*np.cos(2*np.pi*(2*xx+3*yy)) - .36*np.sin(2*np.pi*(yy-xx)))
        if name == 'epoxy_floor':
            field += .4*np.maximum(0,np.sin(2*np.pi*20*xx)*np.sin(2*np.pi*20*yy))
        if name == 'warm_copper':
            dirt *= 1.5
        if name in ('frosted_glass','emission_bar','optical_fiber'):
            dirt *= .1
        value = np.clip(.98 + .09*field - .095*dirt + seam*.25, .66, 1.20)
        rgb = np.uint8(np.clip(np.array(tint)[None,None,:]*value[:,:,None],0,255))
        # Longitudinal process scratches, not arbitrary white noise.
        albedo = TEXTURES / f'{name}_albedo.png'
        Image.fromarray(rgb).save(albedo,compress_level=1)
        dy, dx = np.gradient(field)
        nx, ny = -dx*1.04, -dy*1.04
        inv = 1/np.sqrt(1+nx*nx+ny*ny)
        normal = np.uint8(np.clip(np.stack([nx*inv,ny*inv,inv],-1)*127.5+127.5,0,255))
        norm_path = TEXTURES/f'{name}_normal.png'
        Image.fromarray(normal).save(norm_path,compress_level=1)
        orm = np.empty((n,n,3),np.uint8)
        orm[:,:,0] = np.uint8(np.clip(245 - np.maximum(field,0)*8 - dirt*20,0,255))
        orm[:,:,1] = np.uint8(np.clip((roughness+.044*field+.17*dirt)*255,0,255))
        orm[:,:,2] = np.uint8(np.clip((metallic-.20*dirt)*255,0,255))
        orm_path = TEXTURES/f'{name}_orm.png'
        Image.fromarray(orm).save(orm_path,compress_level=1)
        result[name] = {'albedo':digest(albedo),'normal':digest(norm_path),'orm':digest(orm_path)}
    return result


class Builder:
    def __init__(self, hero: bool):
        self.hero=hero
        self.geo=defaultdict(list)
        self.parts=Counter()

    def add(self, mesh, mat, category):
        assert mat in SURFACES and mesh.faces.shape[0] > 0
        assert np.isfinite(mesh.vertices).all()
        self.geo[mat].append(mesh)
        self.parts[category]+=1

    def box(self, xyz, dims, mat, category, bevel=0):
        if bevel:
            s=np.array(dims,dtype=float)/2
            b=min(bevel,min(s)*.5)
            vertices=[]
            for axis in range(3):
                plane=[a for a in range(3) if a!=axis]
                for sign in (-1,1):
                    for u in (-1,1):
                        for v in (-1,1):
                            p=np.zeros(3)
                            p[axis]=sign*s[axis]
                            p[plane[0]]=u*(s[plane[0]]-b)
                            p[plane[1]]=v*(s[plane[1]]-b)
                            vertices.append(p)
            mesh=trimesh.convex.convex_hull(vertices)
        else:
            mesh=trimesh.creation.box(extents=dims)
        mesh.apply_translation(xyz)
        self.add(mesh,mat,category)

    def rod(self,a,b,radius,mat,category,segments=None):
        a=np.asarray(a,dtype=float)
        b=np.asarray(b,dtype=float)
        direction=b-a
        d=float(np.linalg.norm(direction))
        if d<1.e-5:return
        mesh=trimesh.creation.cylinder(radius=radius,height=d,
              sections=segments or (18 if self.hero else 9))
        mesh.apply_transform(trimesh.geometry.align_vectors([0,0,1],direction/d))
        mesh.apply_translation((a+b)/2)
        self.add(mesh,mat,category)

    def hose(self,coords,r,mat,name):
        for a,b in zip(coords,coords[1:]):
            self.rod(a,b,r,mat,name)

    def fastener(self,x,y,z,axis='z'):
        if axis=='y':self.rod((x,y-.009,z),(x,y+.009,z),.013,'brushed_aluminium','captive_bolt',8)
        else:self.rod((x,y,z-.009),(x,y,z+.009),.013,'brushed_aluminium','captive_bolt',8)

    def mesh_scene(self):
        scene=trimesh.Scene()
        stats={}
        for mat, sources in self.geo.items():
            vnum=sum(len(g.vertices) for g in sources)
            fnum=sum(len(g.faces) for g in sources)
            vertices=np.empty((vnum,3),np.float32)
            normals=np.empty((vnum,3),np.float32)
            uv=np.empty((vnum,2),np.float32)
            faces=np.empty((fnum,3),np.int64)
            i=j=0
            for geo in sources:
                nv,nf=len(geo.vertices),len(geo.faces)
                vertices[i:i+nv]=geo.vertices
                normals[i:i+nv]=geo.vertex_normals
                faces[j:j+nf]=geo.faces+i
                # Physical-world UV projection chosen per surface normal.
                # Textures tile in object space, reducing stretching on long ducts.
                xyz=geo.vertices
                dominant=np.argmax(np.abs(geo.vertex_normals),axis=1)
                uv_chunk=np.zeros((nv,2),np.float32)
                for axis,a,b in ((0,2,1),(1,0,2),(2,0,1)):
                    mask=dominant==axis
                    uv_chunk[mask,0]=xyz[mask,a]*1.1
                    uv_chunk[mask,1]=xyz[mask,b]*1.1
                uv[i:i+nv]=uv_chunk
                i+=nv;j+=nf
            combined=trimesh.Trimesh(vertices=vertices,faces=faces,vertex_normals=normals,process=False)
            alpha=105 if mat=='frosted_glass' else 255
            pbr=PBRMaterial(
                name='R135_'+mat,
                baseColorFactor=[255,255,255,alpha],
                metallicFactor=1.0,roughnessFactor=1.0,
                alphaMode='BLEND' if mat=='frosted_glass' else 'OPAQUE',
                doubleSided=mat=='frosted_glass',
                baseColorTexture=Image.open(TEXTURES/f'{mat}_albedo.png'),
                normalTexture=Image.open(TEXTURES/f'{mat}_normal.png'),
                metallicRoughnessTexture=Image.open(TEXTURES/f'{mat}_orm.png'),
                occlusionTexture=Image.open(TEXTURES/f'{mat}_orm.png'),
                emissiveFactor=[.17,.52,.72] if mat=='emission_bar' else [0,0,0],
            )
            combined.visual=trimesh.visual.TextureVisuals(uv=uv,material=pbr)
            scene.add_geometry(combined,node_name='R135_BATCH_'+mat,geom_name='R135_'+mat)
            stats[mat]={'triangles':fnum,'batched_primitives':len(sources)}
        return scene,stats


def geometry(hero):
    b=Builder(hero)
    step=1 if hero else 3
    # Dedicated rear service corridor (z>4.8) fits behind R134 utility spine.
    # Floor ribs and drain grooves are physical, not flat texture artifacts.
    for i in range(12):
        x=-5.4+i*.98
        b.box((x,.014,5.22),(.955,.082,2.12),'epoxy_floor','maintenance_deck',.012)
        b.box((x,-.009,4.23),(.91,.035,.07),'brushed_aluminium','deck_end_cap')
        for j in range(0,10,step):
            z=4.40+j*.182
            b.box((x,.065,z),(.82,.006,.009),'galvanized_steel','anti_slip_groove')
        for side in (-1,1):
            b.fastener(x+side*.44,.06,4.34,'y')
            b.fastener(x+side*.44,.06,6.05,'y')
    # Overhead structural truss, clamped cable rack and two separate ducts.
    for z in (4.71,5.92):
        b.box((0,4.23,z),(11.6,.14,.20),'galvanized_steel','ceiling_truss',.020)
        for i in range(0,25,step):
            x=-5.57+i*.46
            b.box((x,4.14,z),(.17,.19,.37),'brushed_aluminium','truss_bracket',.012)
            b.fastener(x-.053,4.05,z,'y')
            b.fastener(x+.053,4.05,z,'y')
        b.box((0,4.04,z),(10.8,.055,.09),'emission_bar','recessed_light',.010)
    for z in (5.05,5.71):
        b.box((0,3.64,z),(11.16,.38,.38),'service_paint','ventilation_duct',.023)
        for i in range(0,37,step):
            x=-5.37+i*.30
            b.box((x,3.64,z+.202),(.012,.31,.016),'galvanized_steel','duct_standing_seam')
            b.fastener(x,3.50,z+.222)
        # Mesh louvers and cowl lips are real thickness.
        for i in range(0,68,step):
            x=-5.13+i*.15
            b.box((x,3.40,z-.07),(.087,.025,.19),'brushed_aluminium','supply_louver')
    # Service switchgear cabinets with recessed sockets, handles and resilient gaskets.
    for module in range(8):
        x=-4.80+module*1.38
        b.box((x,1.17,6.18),(1.16,2.28,.46),'service_paint','switchgear_cabinet',.038)
        b.box((x,1.17,5.938),(1.04,2.07,.014),'dielectric_gasket','cabinet_seal')
        b.box((x,1.17,5.924),(.99,1.96,.018),'galvanized_steel','access_door',.018)
        b.box((x+.38,1.18,5.87),(.055,.23,.064),'brushed_aluminium','door_pull',.009)
        b.box((x,.65,5.89),(.76,.08,.018),'warning_enamel','cabinet_warning_strip')
        for row in range(4):
            for col in range(0,6,step):
                px=x-.35+col*.14;py=1.45+row*.12
                b.box((px,py,5.906),(.092,.052,.013),'polymer_jacket','connector_block')
                b.rod((px,py,5.903),(px,py,5.878),.013,'warm_copper','contact_pin',8)
        for dx in (-.46,.46):
            for y in (.19,2.12):b.fastener(x+dx,y,5.91)
    # Physically distinct pump and liquid cooling manifold with no false sensors.
    for line, y in enumerate((.72,1.19,1.66)):
        for t in range(11):
            x=-5.27+t*1.04
            radius=.046 if line!=1 else .078
            b.rod((x-.58,y,5.12),(x+.58,y,5.12),radius,
                  'warm_copper' if line!=2 else 'ceramic_insulation','manifold_pipe')
            for offset in (-.35,.35):
                b.rod((x+offset,y-.085,5.12),(x+offset,y+.085,5.12),radius*1.23,
                      'galvanized_steel','pipe_collar',12)
    for idx in range(5):
        x=-4.4+idx*2.10
        b.box((x,.47,5.13),(.72,.32,.65),'galvanized_steel','pump_motor_mount',.025)
        b.rod((x,.60,4.92),(x,.60,5.39),.245,'service_paint','centrifugal_pump_body',30 if hero else 12)
        b.rod((x,.60,4.895),(x,.60,4.875),.19,'brushed_aluminium','pump_end_bearing',22 if hero else 12)
        for fin in range(0,22,step):
            b.box((x-.24+fin*.023,.69,5.18),(.009,.17,.43),'brushed_aluminium','pump_heat_sink_fin')
        for s in (-1,1):
            b.box((x+s*.27,.39,5.13),(.10,.15,.51),'dielectric_gasket','vibration_mount')
    # Cold aisle screening, subtle translucent partitions and machined mullions.
    for bay in range(10):
        x=-5.45+bay*1.11
        b.box((x,2.18,4.14),(1.08,2.1,.016),'frosted_glass','cold_containment_screen')
        b.box((x-.53,2.18,4.14),(.032,2.3,.075),'brushed_aluminium','glass_mullion',.009)
        b.box((x,3.34,4.14),(1.07,.06,.105),'dielectric_gasket','top_glazing_seal')
        if bay%2==0:b.box((x,1.36,4.11),(.83,.020,.012),'warning_enamel','glazing_safety_marker')
    # Upper fiber/conductor spine: cables follow separated continuous guides.
    for bundle in range(8):
        x=-5.0+bundle*1.4
        for strand in range(0,7,step):
            y=3.08+strand*.034
            z=5.48 + math.sin(bundle*.6+strand*.21)*.08
            b.hose([(x,y,z),(x+.24,y+.07,z+.13),(x+.56,y+.04,z+.04),
                    (x+.94,y+.045,z)],.011 if strand%2 else .017,
                   'optical_fiber' if strand%2 else 'polymer_jacket','fiber_patch_lead')
        b.box((x+.34,3.19,5.52),(.57,.09,.28),'service_paint','cable_tie_plate',.012)
    # High value geometry kept only in HERO: internal fin stacks and bolted inspection strips.
    if hero:
        for rail in range(4):
            z=4.69+rail*.39
            b.box((0,2.91,z),(11.3,.048,.082),'galvanized_steel','overhead_fiber_ladder')
            for i in range(68):
                x=-5.48+i*.162
                b.box((x,2.96,z),(.044,.062,.28),'brushed_aluminium','cable_tray_rung',.006)
        for i in range(30):
            x=-5.0+i*.345
            b.fastener(x,3.44,5.06,'y')
            b.fastener(x,3.44,5.77,'y')
    return b


def export_lod(hero:bool):
    b=geometry(hero)
    scene,stats=b.mesh_scene()
    MODELS.mkdir(parents=True,exist_ok=True)
    level='hero' if hero else 'eco'
    path=MODELS/f'service_spine_{level}.glb'
    path.write_bytes(scene.export(file_type='glb'))
    manifest={
     'schema':'OSGARD_R135_SERVICE_SPINE_V1','lod':level,'asset':str(path.relative_to(ROOT)),
     'sha256':digest(path),'triangles':sum(s['triangles'] for s in stats.values()),
     'material_batches':stats,'batched_mesh_count':len(stats),
     'component_count':sum(b.parts.values()),'semantic_parts':dict(sorted(b.parts.items())),
     'simulation_only':True,'real_hardware_connected':False,
    }
    path.with_suffix('.manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    return manifest


def main(argv=None):
    ap=argparse.ArgumentParser()
    ap.add_argument('--level',choices=('eco','hero','both'),default='both')
    ap.add_argument('--skip-textures',action='store_true')
    args=ap.parse_args(argv)
    if not args.skip_textures:maps()
    if args.level in ('both','eco'):print(json.dumps(export_lod(False)))
    if args.level in ('both','hero'):print(json.dumps(export_lod(True)))

if __name__=='__main__':main()
