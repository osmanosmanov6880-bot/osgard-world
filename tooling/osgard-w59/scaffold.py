#!/usr/bin/env python3
"""Creates empty evidence templates, never hardware observations."""
import argparse,json
from pathlib import Path
from audit import SOURCE_SHA,CANDIDATE_SHA256,PLATFORMS,COMMON,EXTRA
p=argparse.ArgumentParser()
p.add_argument('--evidence-dir',type=Path,required=True)
root=p.parse_args().evidence_dir
if root.exists() and any(root.iterdir()):p.error('Refuse to overwrite evidence')
root.mkdir(parents=True,exist_ok=True)
m={'schema':'OSGARD_W59_EVIDENCE_MANIFEST_V1','source_sha':SOURCE_SHA,'candidate':
{'path':'candidate/OSGARD_W58_verified.zip','sha256':CANDIDATE_SHA256},'reports':{}}
(root/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
for platform in PLATFORMS:
    (root/'candidate').mkdir(exist_ok=True)
    (root/'reports').mkdir(exist_ok=True)
    (root/'devices'/platform).mkdir(parents=True,exist_ok=True)
    r={'schema':'OSGARD_W59_DEVICE_SESSION_V1','platform':platform,'source_sha':SOURCE_SHA,
       'device_kind':'PHYSICAL_DEVICE_REPORTED_UNVERIFIED',
       'device':{'model':'','os':'','gpu':''},'started_utc':'','ended_utc':'',
       'manual_checks':{k:'NOT_TESTED' for k in COMMON+EXTRA[platform]},
       'modes':{mode:{'path':f'devices/{platform}/{mode}.csv','sha256':''} for mode in ('hero','eco')},
       'thermal':{'path':f'devices/{platform}/thermal.csv','sha256':''},
       'screenshots':{lang:{'path':f'devices/{platform}/{lang}.png','sha256':''} for lang in ('ru','en')}}
    (root/'reports'/f'{platform}.json').write_text(json.dumps(r,indent=2)+'\n')
(root/'INCOMPLETE.txt').write_text('BLANK TEMPLATES ONLY. No physical devices tested. HOLD.\n')
print('Blank templates only; hardware reports missing; production HOLD.')
