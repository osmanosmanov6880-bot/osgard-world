#!/usr/bin/env python3
"""Offline 8-profile Windows GPU benchmark review; refuses software/CI results."""
from __future__ import annotations
import argparse, json, re, sys
from json import JSONDecodeError
from pathlib import Path

def main():
 ap=argparse.ArgumentParser();ap.add_argument('report_dir',type=Path);ap.add_argument('--output',type=Path);args=ap.parse_args()
 rows=[]
 for game in ['vector','chronos']:
  for resolution,w,h in [('1080',1920,1080),('1440',2560,1440)]:
   for profile in ['ultra','balanced']:
    filename=f'{game}_{resolution}_{profile}.json'
    path=args.report_dir/filename
    status='MISSING';report={}
    if path.is_file():
     try:
      report=json.loads(path.read_text(encoding='utf-8-sig'))
      adapter=str(report.get('adapter','')).lower()
      physical=report.get('physical_gpu_validation_candidate') is True
      gpu_unsafe=bool(re.search(r'llvmpipe|swiftshader|softpipe|basic render|virtualbox|vmware|software|remote display',adapter))
      verified=(physical and not gpu_unsafe and report.get('is_software_renderer') is False and report.get('rendering_method')=='forward_plus' and report.get('os')=='Windows' and report.get('res_x')==w and report.get('res_y')==h and report.get('quality')==profile and float(report.get('measurement_seconds',0))>=24 and int(report.get('frames',0))>=120)
      if not verified:status='NOT_PHYSICAL_GPU_VERIFIED'
      else:status='PASS' if float(report.get('mean_fps',0))>=60 and float(report.get('p95_frame_ms',999))<=16.67 else 'BELOW_TARGET'
     except (ValueError, TypeError,KeyError,JSONDecodeError) as exc:status=f'BAD_REPORT:{exc}'
    rows.append({'file':filename,'status':status,'adapter':report.get('adapter',''),'fps':report.get('mean_fps'),'p95_ms':report.get('p95_frame_ms')})
    print(f'{filename:33} {status:27} {report.get("mean_fps","-")} FPS')
 overall='8_PROFILES_PASS' if all(x['status']=='PASS' for x in rows) else 'UNVERIFIED_OR_PERFORMANCE_LIMITED'
 result={'schema':'osgard.wave8.hardware.qa.v1','overall':overall,'profiles':rows,'claims':'Software CI and screenshots are never acceptable substitutes for tests on an actual GPU.'}
 out=args.output or args.report_dir/'OSGARD_WAVE8_GPU_QA.json'
 out.parent.mkdir(parents=True,exist_ok=True)
 out.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
 print('Summary:',overall,'=>',out)
 return 0 if overall=='8_PROFILES_PASS' else 2
if __name__=='__main__':
 from json import JSONDecodeError
 sys.exit(main())
