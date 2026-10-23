#!/usr/bin/env python3
import argparse,json
from pathlib import Path
from PIL import Image

def main():
 p=argparse.ArgumentParser();p.add_argument('--project',required=True,choices=['vector-zero','time-empire']);p.add_argument('--root',default='');a=p.parse_args()
 root=Path(a.root) if a.root else Path('godot')/a.project/'assets'/'wave8'
 manifest=json.loads((root/'manifest.json').read_text())
 assert len(manifest['maps'])==3
 for item in manifest['maps']:
  folder=root/item['key']
  images=[Image.open(folder/(kind+'.png')) for kind in ['albedo','normal','roughness','metallic']]
  assert all(im.size==images[0].size for im in images)
  assert all(im.width>=256 for im in images)
  assert images[0].mode=='RGB' and images[1].mode=='RGB'
  assert all(im.mode=='L' for im in images[2:])
  print('PBR IMPORT QA:',a.project,item['key'],'resolution',images[0].size)
 print('WAVE8_PBR_PASS',a.project)
if __name__=='__main__':main()
