"""Package the validated local redesign without publishing or Git operations."""
from pathlib import Path
import shutil
import zipfile

root=Path(__file__).resolve().parents[1]
delivery=root/'delivery'
for name,source in [('PAGES',root/'dist'),('BRAND-KIT',root/'public/brand'),('CORE',root/'server')]:
    shutil.rmtree(delivery/name,ignore_errors=True)
    shutil.copytree(source,delivery/name,ignore=shutil.ignore_patterns('__pycache__','*.sqlite3*'))
shutil.copy2(root/'docs/REDESIGN-BRIEF-LINE-BY-LINE.md',delivery/'BRIEF-CHECKLIST.md')
shutil.copy2(root/'docs/REDESIGN-BUILD-AUDIT.json',delivery/'BUILD-AUDIT.json')
shutil.copy2(root/'docs/REDESIGN-UX-ACCEPTANCE.md',delivery/'UX-CHECKS.md')
shutil.copy2(root/'docs/REDESIGN-PERFORMANCE.md',delivery/'PERFORMANCE.md')
shutil.copy2(root/'docs/CORE-PILOT.md',delivery/'CORE-PILOT.md')
shutil.copy2(root/'docs/ECOSYSTEM-PLAN-ACCEPTANCE.md',delivery/'ECOSYSTEM-PLAN-ACCEPTANCE.md')
shutil.copy2(root/'docs/CORE-TEST-REPORT.json',delivery/'CORE-CHECKS.json')
shutil.copy2(root/'docs/LEARNING-PILOT.md',delivery/'LEARNING-PILOT.md')
shutil.copy2(root/'docs/LEARNING-TEST-REPORT.json',delivery/'LEARNING-CHECKS.json')
shutil.copy2(root/'docs/PILOT-ORGANIZER.md',delivery/'PILOT-ORGANIZER.md')
shutil.copy2(root/'docs/PILOT-REPORT-TESTS.json',delivery/'PILOT-CHECKS.json')
shutil.copy2(root/'docs/ACCOUNT-ACCESS.md',delivery/'ACCOUNT-ACCESS.md')
shutil.copy2(root/'docs/ACCOUNT-TEST-REPORT.json',delivery/'ACCOUNT-CHECKS.json')
shutil.copy2(root/'docs/STUDIO-ACCEPTANCE.md',delivery/'STUDIO-ACCEPTANCE.md')
shutil.copy2(root/'docs/STUDIO-ACCEPTANCE-TESTS.json',delivery/'STUDIO-ACCEPTANCE-CHECKS.json')
shutil.copy2(root/'docs/DELIVERY-WORKFLOW.md',delivery/'DELIVERY-WORKFLOW.md')
shutil.copy2(root/'docs/DELIVERY-WORKFLOW-TESTS.json',delivery/'DELIVERY-WORKFLOW-CHECKS.json')
shutil.copy2(root/'docs/CORE-OVERVIEW.md',delivery/'CORE-OVERVIEW.md')
shutil.copy2(root/'docs/CORE-OVERVIEW-TESTS.json',delivery/'CORE-OVERVIEW-CHECKS.json')
shutil.copy2(root/'docs/FINAL-READINESS.md',delivery/'FINAL-READINESS.md')
if (root/'docs/LOCAL-RELEASE-CHECKS.json').exists():shutil.copy2(root/'docs/LOCAL-RELEASE-CHECKS.json',delivery/'LOCAL-RELEASE-CHECKS.json')
shutil.copy2(root/'docs/CLIENT-PORTAL.md',delivery/'CLIENT-PORTAL.md')
shutil.copy2(root/'docs/CLIENT-PORTAL-TESTS.json',delivery/'CLIENT-PORTAL-CHECKS.json')
shutil.copy2(root/'docs/TEAMS.md',delivery/'TEAMS.md')
shutil.copy2(root/'docs/TEAM-TESTS.json',delivery/'TEAM-CHECKS.json')
shutil.copy2(root/'docs/CORE-PRODUCTION.md',delivery/'CORE-PRODUCTION.md')
out=root.parent/'OSGARD-REDESIGN-THREE-BRANDS.zip'
exclude={'node_modules','.git','dist','delivery','__pycache__','core-data'}
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for path in root.rglob('*'):
        relative=path.relative_to(root)
        if not path.is_file() or any(part in exclude for part in relative.parts) or path.name.endswith('.tsbuildinfo') or path.name.startswith('.env') or '.sqlite3' in path.name:
            continue
        archive.write(path,'SOURCE/'+str(relative))
    for path in delivery.rglob('*'):
        if path.is_file() and '__pycache__' not in path.parts:
            archive.write(path,str(path.relative_to(delivery)))
with zipfile.ZipFile(out) as archive:
    assert archive.testzip() is None
    for required in ['START.py','START-WINDOWS.bat','README.md','BRIEF-CHECKLIST.md','BUILD-AUDIT.json','PAGES/intelligence/index.html','PAGES/play/index.html','PAGES/development/index.html','BRAND-KIT/portal-world.svg','SOURCE/src/WorldHome.tsx','START-CORE.py','START-CORE-WINDOWS.bat','CORE/core_server.py','CORE/core_model.py','CORE/core_backup.py','CORE-PILOT.md','ECOSYSTEM-PLAN-ACCEPTANCE.md','CORE-CHECKS.json','CORE/core_learning.py','CORE/curriculum.json','LEARNING-PILOT.md','LEARNING-CHECKS.json','CORE/core_pilot_reports.py','PILOT-ORGANIZER.md','PILOT-CHECKS.json','CORE/core_account.py','ACCOUNT-ACCESS.md','ACCOUNT-CHECKS.json','PAGES/account/index.html','CORE/core_acceptance.py','STUDIO-ACCEPTANCE.md','STUDIO-ACCEPTANCE-CHECKS.json','CORE/core_delivery.py','DELIVERY-WORKFLOW.md','DELIVERY-WORKFLOW-CHECKS.json','CORE/core_overview.py','CORE-OVERVIEW.md','CORE-OVERVIEW-CHECKS.json','FINAL-READINESS.md','QUICK-START-RU.md','PAGES/workspace/overview/index.html','CORE/core_client_portal.py','CLIENT-PORTAL.md','CLIENT-PORTAL-CHECKS.json','PAGES/deliveries/index.html','CORE/core_teams.py','TEAMS.md','TEAM-CHECKS.json','PAGES/teams/index.html','CORE-PRODUCTION.md']:
        assert required in archive.namelist(),required
upload=root.parent/'OSGARD-CLOUDFLARE-STATIC.zip'
with zipfile.ZipFile(upload,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for path in (root/'dist').rglob('*'):
        if path.is_file():
            archive.write(path,str(path.relative_to(root/'dist')))
with zipfile.ZipFile(upload) as archive:
    assert archive.testzip() is None
    assert 'index.html' in archive.namelist() and '404.html' in archive.namelist()
    assert not any(name.startswith('SOURCE/') for name in archive.namelist())
print('Validated archive:',out,'bytes:',out.stat().st_size)
print('Validated static upload:',upload,'bytes:',upload.stat().st_size)
