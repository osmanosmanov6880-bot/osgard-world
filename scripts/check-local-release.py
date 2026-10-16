#!/usr/bin/env python3
"""Reproduce the local release checks and ZIP packaging. No push, publish, credentials or payments."""
from pathlib import Path
from datetime import datetime,timezone
import json
import os
import shutil
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
REPORT=ROOT/'docs/LOCAL-RELEASE-CHECKS.json'
PYTHON=sys.executable
NPM=shutil.which('npm.cmd' if os.name=='nt' else 'npm')
NODE=shutil.which('node')
if not NPM or not NODE:raise SystemExit('Install Node.js and project dependencies first. The ready-to-run Core ZIP only needs Python; this script checks source code.')
checks=[
 ('Build and TypeScript',[NPM,'run','build']),
 ('Design models and server-rendered surfaces',[NPM,'run','qa:redesign']),
 ('Landing dependency graphs and budgets',[NPM,'run','qa:redesign-build']),
 ('Interface reliability contracts',[NPM,'run','qa:ux']),
 ('Guest backup and rollback',[NPM,'run','qa:backup']),
 ('Account client and safe return',[NODE,'scripts/account-client-smoke.mjs']),
 ('Learning client recovery and calendar',[NODE,'scripts/core-learning-client-smoke.mjs']),
 ('Pilot filters and report export',[NODE,'scripts/pilot-report-client-smoke.mjs']),
 ('Guest project collection',[NPM,'run','qa:osa-workspace']),
 ('Experiment measurements',[NPM,'run','qa:osa-experiments']),
 ('Media honesty and availability',[NPM,'run','qa:osa-media-availability']),
 ('Learning progress',[NPM,'run','qa:osa-progress']),
 ('Curriculum parity',[NODE,'scripts/build-core-curriculum.mjs','--check']),
 ('106 Core HTTP/SQLite regressions',[PYTHON,'scripts/core-teams-smoke.py']),
 ('Production Core gateway and backup contract',[PYTHON,'scripts/core-production-smoke.py']),
 ('Static release profile and hashes',[NPM,'run','qa:static-preview']),
 ('Deep routes and real 404 responses',[PYTHON,'scripts/redesign-http-smoke.py']),
 ('Built file integrity',[PYTHON,'delivery/VERIFY.py','dist']),
 ('Create local delivery archives',[PYTHON,'scripts/package-redesign.py']),
 ('Packaged file integrity',[PYTHON,'delivery/VERIFY.py']),
 ('Packaged server and end-to-end workflow',[PYTHON,'scripts/core-delivery-smoke.py']),
]
report=dict(profile='local-technical-pilot',status='running',startedAt=datetime.now(timezone.utc).isoformat(),checks=[],browserQA='not-performed',realDeviceQA='not-performed',fieldCoreWebVitals='not-collected',realStudentPilot='not-performed',payments='deferred-by-user',github='unchanged',published=False,fullStrategicPlanComplete=False)
def save():REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def run(name,command):
    started=time.perf_counter();print('CHECK:',name,flush=True)
    try:
        result=subprocess.run(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=240)
        passed=result.returncode==0
        report['checks'].append(dict(name=name,command=command,status='passed' if passed else 'failed',seconds=round(time.perf_counter()-started,2),exitCode=result.returncode))
        if not passed:print(result.stdout[-12000:],flush=True)
    except (OSError,subprocess.TimeoutExpired) as e:
        passed=False;report['checks'].append(dict(name=name,command=command,status='failed',seconds=round(time.perf_counter()-started,2),reason=type(e).__name__))
    save();return passed
save()
for name,command in checks:
    if not run(name,command):report['status']='failed';save();raise SystemExit('Local release failed; inspect docs/LOCAL-RELEASE-CHECKS.json. No publication was performed.')
report['status']='passed';report['completedAt']=datetime.now(timezone.utc).isoformat();report['serverTestReport']='TEAM-TESTS.json';save()
# Only reports changed after the packaged server test. Refresh those reports in the ZIP.
refresh=subprocess.run([PYTHON,'scripts/package-redesign.py'],cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=120)
if refresh.returncode:
    report['status']='failed';report['archiveReportRefresh']='failed';save();print(refresh.stdout[-3000:]);raise SystemExit(1)
print('LOCAL TECHNICAL RELEASE PASSED:',len(report['checks']),'checks. Browser/device/real-pilot acceptance remains open. No publication or payments.',flush=True)
