"""Start the packaged CLI with a throwaway DB and exercise its actual queue worker."""
from pathlib import Path
from tempfile import TemporaryDirectory
from http.client import HTTPConnection
import json
import re
import subprocess
import sys
import time
import uuid
root=Path(__file__).resolve().parents[1]
with TemporaryDirectory() as tmp:
    process=subprocess.Popen([sys.executable,str(root/'delivery/START-CORE.py'),'--port','0','--database',str(Path(tmp)/'core.sqlite3')],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    try:
        line=process.stdout.readline();match=re.search(r'127\.0\.0\.1:(\d+)',line)
        assert match,'Packaged Core launcher failed: '+line
        port=int(match.group(1))
        def request(method,path,body=None,token=None):
            connection=HTTPConnection('127.0.0.1',port,timeout=10);headers={}
            if body is not None:headers.update({'Content-Type':'application/json','Idempotency-Key':uuid.uuid4().hex})
            if token:headers['Authorization']='Bearer '+token
            connection.request(method,path,json.dumps(body) if body is not None else None,headers);response=connection.getresponse();status=response.status;raw=response.read();connection.close();assert status==200,(status,raw[:300]);return raw
        page=request('GET','/workspace/');assert b'canonical' in page and b'OSGARD' in page
        account=json.loads(request('POST','/api/core/auth/register',{'username':'delivery-check','password':'temporary test password only'}));token=account['token']
        security=json.loads(request('GET','/api/core/auth/security',token=token));assert len(security['sessions'])==1 and security['sessions'][0]['current'];assert security['recoveryRemaining']==0
        assert b'canonical' in request('GET','/account/')
        project=json.loads(request('POST','/api/core/projects',{'title':'Delivery check','goal':'Verify the bundled server and background worker'},token))['project']
        pid=project['id'];project=json.loads(request('POST','/api/core/projects/'+pid,{'expectedVersion':1,'changes':{'consents':{'learning':True,'studio':True,'business':False}}},token))['project']
        queued=json.loads(request('POST','/api/core/projects/'+pid+'/jobs',{'expectedVersion':project['version']},token));assert queued['jobId']
        for _ in range(40):
            jobs=json.loads(request('GET','/api/core/projects/'+pid+'/jobs',token=token))['jobs']
            if jobs and jobs[0]['status']=='completed':break
            time.sleep(.05)
        else:raise AssertionError('Bundled queue worker did not complete the check')
        assert jobs[0]['result']['externalVerification'] is False
        curriculum=json.loads(request('GET','/api/core/curriculum',token=token));lesson=curriculum['lessons'][0]
        result=json.loads(request('POST','/api/core/projects/'+pid+'/learning',{'expectedVersion':project['version'],'action':'activity','slug':lesson['slug'],'answer':lesson['ru']['check']['correctIndex'],'locale':'ru','practice':'A practical result saved through the bundled lesson API.'},token));assert result['feedback']['passed']
        learning=json.loads(request('GET','/api/core/projects/'+pid+'/learning',token=token));assert learning['completed']==[lesson['slug']]
        campus=request('GET','/learning/campus/');assert b'canonical' in campus
        overview=json.loads(request('GET','/api/core/learning/overview',token=token));assert any(p['projectId']==pid for p in overview['projects'])
        report=json.loads(request('GET','/api/core/projects/'+pid+'/learning/report',token=token));assert report['counts']['practiceAttempts']==1;assert report['limits']['skillIndependentlyVerified'] is False
        organizer=request('GET','/learning/organizer/');assert b'canonical' in organizer
        project=result['project']
        changes={'acceptance':[{'id':'delivery','title':'Show the release snapshot','done':True}],'artifact':{'url':'https://example.com/manual-result','checksum':'','notes':'Manual fixture, no network verification'}}
        project=json.loads(request('POST','/api/core/projects/'+pid,{'expectedVersion':project['version'],'changes':changes},token))['project']
        project=json.loads(request('POST','/api/core/projects/'+pid,{'expectedVersion':project['version'],'changes':{'accepted':True}},token))['project']
        release_result=json.loads(request('POST','/api/core/projects/'+pid+'/actions',{'expectedVersion':project['version'],'kind':'release','payload':{}},token));project=release_result['project'];rid=release_result['result']['id']
        reviewer=json.loads(request('POST','/api/core/auth/register',{'username':'delivery-reviewer','password':'temporary reviewer password only'}))
        project=json.loads(request('POST','/api/core/projects/'+pid+'/members',{'expectedVersion':project['version'],'username':'delivery-reviewer','role':'editor'},token))['project']
        reviewed=json.loads(request('POST','/api/core/projects/'+pid+'/release-review',{'expectedVersion':project['version'],'releaseId':rid,'criteria':[{'id':'delivery','passed':True,'evidence':'Checked the immutable release snapshot in the packaged server.'}],'note':'Manual participant acceptance fixture, not certification.'},reviewer['token']));assert reviewed['verdict']=='accepted'
        packet=json.loads(request('GET','/api/core/projects/'+pid+'/releases/'+rid,token=token));assert len(packet['reviews'])==1 and packet['limits']['externalURLVerified'] is False
        project=reviewed['project']
        project=json.loads(request('POST','/api/core/projects/'+pid,{'expectedVersion':project['version'],'changes':{'consents':{'learning':True,'studio':True,'business':True}}},token))['project']
        recipient=json.loads(request('POST','/api/core/auth/register',{'username':'delivery-recipient','password':'temporary recipient password only'}))
        project=json.loads(request('POST','/api/core/projects/'+pid+'/members',{'expectedVersion':project['version'],'username':'delivery-recipient','role':'viewer'},token))['project']
        sent=json.loads(request('POST','/api/core/projects/'+pid+'/delivery',{'expectedVersion':project['version'],'action':'handoff','releaseId':rid,'recipient':'delivery-recipient','note':'Read the immutable materials and confirm receipt of this release.'},token));project=sent['project'];hid=sent['handoffId']
        acknowledged=json.loads(request('POST','/api/core/projects/'+pid+'/delivery',{'expectedVersion':project['version'],'action':'acknowledge','handoffId':hid},recipient['token']));project=acknowledged['project'];assert project['role']=='viewer'
        ticket=json.loads(request('POST','/api/core/projects/'+pid+'/delivery',{'expectedVersion':project['version'],'action':'ticket','handoffId':hid,'title':'Delivery fixture request','body':'Check the reproduction steps for the received immutable release.'},recipient['token']));assert ticket['ticketId']
        workflow=json.loads(request('GET','/api/core/projects/'+pid+'/delivery',token=recipient['token']));assert len(workflow['tickets'])==1 and workflow['limits']['payments'] is False
        overview=json.loads(request('GET','/api/core/overview',token=recipient['token']));assert overview['runtime']['workerRegistered'] and overview['runtime']['workerAlive'];item=next(p for p in overview['projects'] if p['id']==pid);assert item['role']=='viewer' and item['nextAction']['stage']=='delivery';assert b'canonical' in request('GET','/workspace/overview/')
        project=json.loads(request('GET','/api/core/projects/'+pid,token=token))['project']
        isolated=json.loads(request('POST','/api/core/projects/'+pid+'/client-deliveries',{'expectedVersion':project['version'],'releaseId':rid,'recipient':'delivery-recipient','title':'Isolated fixture result','description':'Only explicitly selected materials are shared in this envelope.','instructions':'Open the supplied material and ask for help in its own thread.','sharingAcknowledged':True},token));did=isolated['deliveryId']
        packet=json.loads(request('GET','/api/core/deliveries/'+did,token=recipient['token']))['delivery'];assert 'snapshot' not in packet and 'projectId' not in packet
        acknowledged=json.loads(request('POST','/api/core/deliveries/'+did,{'expectedVersion':1,'action':'acknowledge'},recipient['token']));assert acknowledged['status']=='acknowledged' and 'project' not in acknowledged
        assert b'canonical' in request('GET','/deliveries/')
        team=json.loads(request('POST','/api/core/teams',{'name':'Packaged team fixture'},token));tid=team['teamId']
        team_state=json.loads(request('GET','/api/core/teams/'+tid,token=token))
        request('POST','/api/core/teams/'+tid,{'expectedVersion':team_state['team']['version'],'action':'member','username':'delivery-reviewer','role':'editor'},token)
        project=json.loads(request('GET','/api/core/projects/'+pid,token=token))['project'];team_state=json.loads(request('GET','/api/core/teams/'+tid,token=token))
        request('POST','/api/core/teams/'+tid,{'expectedVersion':team_state['team']['version'],'action':'attach','projectId':pid,'projectVersion':project['version'],'sharingAcknowledged':True},token)
        attached=json.loads(request('GET','/api/core/teams/'+tid,token=reviewer['token']));assert any(p['id']==pid for p in attached['projects']);assert b'canonical' in request('GET','/teams/')
        print('CORE DELIVERY PASS: packaged launcher, workspace HTML, account access, own sessions, project, durable job, live worker, curriculum, personal lesson practice, campus, organizer honest report counters versioned Studio acceptance, recipient acknowledgement scoped support a live operational snapshot an isolated recipient envelope and explicit team project sharing')
    finally:
        process.terminate()
        try:process.wait(timeout=5)
        except subprocess.TimeoutExpired:process.kill();process.wait(timeout=5)
