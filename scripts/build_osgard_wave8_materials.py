#!/usr/bin/env python3
"""OSGARD Wave 8 original reproducible PBR atlas; runs before Godot import.
No downloaded third-party assets. Smooth macro-scale wear, low-noise normals.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SPECS = {
 'vector-zero': {
   'machined_nickel': {'base':(104,129,139),'metal':232,'rough':88,'stripe':(143,157,164)},
   'oxide_copper': {'base':(145,85,52),'metal':220,'rough':112,'stripe':(197,125,75)},
   'powder_graphite': {'base':(40,59,70),'metal':155,'rough':150,'stripe':(72,86,96)},
 },
 'time-empire': {
   'architectural_titanium': {'base':(101,132,145),'metal':216,'rough':92,'stripe':(159,181,184)},
   'sea_wall_concrete': {'base':(114,123,119),'metal':12,'rough':216,'stripe':(152,154,141)},
   'patinated_bronze': {'base':(113,95,74),'metal':191,'rough':129,'stripe':(161,136,95)},
 }
}

def write_material(root:Path,key:str,cfg:dict, n:int,seed:int)->dict:
    rng=np.random.default_rng(seed)
    dir=root/key;dir.mkdir(parents=True,exist_ok=True)
    y,x=np.mgrid[0:n,0:n].astype('float32')
    # Coherent large-scale surface variation, not high-frequency television noise.
    coarse=rng.normal(0,1,(24,24)).astype('float32')
    coarse_im=Image.fromarray(np.uint8(np.clip((coarse+2.8)*37,0,255)),'L').resize((n,n),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(n/85))
    macro=(np.asarray(coarse_im,dtype=np.float32)-125.0)/34.0
    # Directional shallow brushed finish with sparse human-scale scoring.
    brushed=(np.sin(y*0.23)+0.35*np.sin(y*0.77+x*0.009))*0.55
    fine=rng.normal(0,0.48,(n,n)).astype('float32')
    wear=macro*1.45+brushed*0.85+fine*0.21
    base=np.array(cfg['base'],dtype=np.float32)
    tex=np.stack([np.clip(base[k]+wear*(1.6 if k==1 else 1.3),0,255) for k in range(3)],axis=-1).astype('uint8')
    albedo=Image.fromarray(tex,'RGB');draw=ImageDraw.Draw(albedo,'RGBA')
    # Wide panel joints and manufactured fastener seats are intentional details.
    step=max(n//4,1)
    for j in range(step,n,step):
        draw.line([(j,0),(j,n)],fill=(8,17,20,38),width=max(2,n//350))
        draw.line([(0,j),(n,j)],fill=(11,14,17,26),width=max(2,n//420))
        draw.line([(j+4,0),(j+4,n)],fill=(*cfg['stripe'],19),width=1)
    for cy in range(step//2,n,step):
        for cx in range(step//2,n,step):
            draw.ellipse((cx-3,cy-3,cx+3,cy+3), fill=(25,28,27,71))
            draw.ellipse((cx-1,cy-1,cx+1,cy+1), fill=(*cfg['stripe'],80))
    albedo.save(dir/'albedo.png',optimize=True)
    # Physically subtle normal perturbations. Neutral blue = flat normal.
    macro_smooth=Image.fromarray(np.uint8(np.clip(macro*11+128,0,255)),'L').filter(ImageFilter.GaussianBlur(2.5))
    relief=np.asarray(macro_smooth,dtype=np.float32)/255.0*0.07 + brushed*0.007
    dy,dx=np.gradient(relief); nx=-dx*1.5;ny=-dy*1.5;nz=np.ones_like(nx)
    nm=np.stack([nx,ny,nz],axis=-1);nm/=np.linalg.norm(nm,axis=-1,keepdims=True)
    normal=np.clip((nm*0.5+0.5)*255,0,255).astype('uint8')
    Image.fromarray(normal,'RGB').save(dir/'normal.png',optimize=True)
    rough=np.uint8(np.clip(cfg['rough'] + macro*3.5 + brushed*2.2, 26,250));Image.fromarray(rough,'L').save(dir/'roughness.png',optimize=True)
    metal=np.uint8(np.clip(cfg['metal'] + macro*2.5, 0,255));Image.fromarray(metal,'L').save(dir/'metallic.png',optimize=True)
    return {'key':key,'resolution':[n,n],'files':{t:(dir/(t+'.png')).stat().st_size for t in ('albedo','normal','roughness','metallic')},'source':'procedural_original'}

def main():
    a=argparse.ArgumentParser();a.add_argument('--project',required=True,choices=list(SPECS));a.add_argument('--size',type=int,default=640);a.add_argument('--root',default='');args=a.parse_args()
    if args.size<128 or args.size>2048:raise SystemExit('size out of range')
    folder=Path(args.root) if args.root else Path('godot')/args.project/'assets'/'wave8'
    records=[]
    for i,(key,cfg) in enumerate(SPECS[args.project].items()):records.append(write_material(folder,key,cfg,args.size,20261023+i*103))
    (folder/'manifest.json').write_text(json.dumps({'version':8,'project':args.project,'maps':records},indent=2),encoding='utf-8')
    print('WAVE8_PBR_CREATED',args.project,len(records),sum(sum(v['files'].values()) for v in records))
if __name__=='__main__':main()
