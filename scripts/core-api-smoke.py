"""Integration checks against a temporary real HTTP/SQLite Core server (not browser QA)."""
from pathlib import Path
from tempfile import TemporaryDirectory
from http.client import HTTPConnection
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
import sys
import threading
import unittest
import uuid
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from core_server import create_server,Store,QueueWorker
from core_backup import backup

class CoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp=TemporaryDirectory();cls.root=Path(cls.tmp.name)/'public';cls.root.mkdir();(cls.root/'index.html').write_text('OSGARD')
        cls.db=Path(cls.tmp.name)/'private/core.sqlite3';cls.server=create_server(cls.root,cls.db,port=0);cls.port=cls.server.server_address[1]
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True);cls.thread.start()
        cls.owner=cls.request('POST','auth/register',{'username':'owner','password':'long password for pilot 2026'})[1]
        cls.other=cls.request('POST','auth/register',{'username':'other','password':'another long password 2026'})[1]
        cls.viewer=cls.request('POST','auth/register',{'username':'viewer','password':'viewer long password 2026'})[1]
    @classmethod
    def tearDownClass(cls):cls.server.shutdown();cls.server.server_close();cls.tmp.cleanup()
    @classmethod
    def request(cls,method,route,body=None,token=None,key=None,origin=None):
        c=HTTPConnection('127.0.0.1',cls.port,timeout=10);headers={}
        if token:headers['Authorization']='Bearer '+token
        if key:headers['Idempotency-Key']=key
        if origin:headers['Origin']=origin
        raw=json.dumps(body) if body is not None else None
        if raw:headers['Content-Type']='application/json'
        c.request(method,'/api/core/'+route,raw,headers);r=c.getresponse();status=r.status;result=json.loads(r.read());c.close();return status,result
    def setUp(self):
        status,r=self.write('projects',{'title':'Useful project','goal':'Create a useful service with measurable acceptance.'});self.assertEqual(status,200);self.p=r['project']
    def write(self,route,body,token=None,key=None):return self.request('POST',route,body,token or self.owner['token'],key or uuid.uuid4().hex)
    def update(self,changes):
        status,r=self.write('projects/'+self.p['id'],{'expectedVersion':self.p['version'],'changes':changes});self.assertEqual(status,200,r);self.p=r['project'];return r
    def act(self,kind,payload=None,key=None):return self.write('projects/'+self.p['id']+'/actions',{'expectedVersion':self.p['version'],'kind':kind,'payload':payload or {}},key=key)
    def ready(self):
        self.update({'budgetMinor':20000,'consents':{'learning':True,'studio':True,'business':True},'allowedActions':['local_checks','prepare_offer'],'acceptance':[{'id':'test','title':'Verify the result against a new task','done':True}],'artifact':{'url':'https://example.com/product','notes':'Manual evidence','checksum':''}})
        self.update({'accepted':True})
    def test_auth_and_origin(self):
        self.assertEqual(self.request('GET','projects')[0],401)
        self.assertEqual(self.request('GET','projects',token=self.owner['token'],origin='https://evil.example')[0],403)
        status,login=self.request('POST','auth/login',{'username':'owner','password':'long password for pilot 2026'});self.assertEqual(status,200)
        self.assertEqual(self.request('GET','projects/'+self.p['id'],token=login['token'])[1]['project']['id'],self.p['id'])
        self.assertEqual(self.request('POST','auth/logout',{},login['token'])[0],200)
        self.assertEqual(self.request('GET','projects',token=login['token'])[0],401)
    def test_project_isolation(self):
        self.assertEqual(self.request('GET','projects/'+self.p['id'],token=self.other['token'])[0],404)
        self.assertEqual(self.write('projects/'+self.p['id'],{'expectedVersion':1,'changes':{'title':'Intrusion'}},self.other['token'])[0],404)
    def test_version_conflict(self):
        old=self.p['version'];self.update({'audience':'One pilot team'})
        self.assertEqual(self.write('projects/'+self.p['id'],{'expectedVersion':old,'changes':{'title':'Stale overwrite'}})[0],409)
    def test_duplicate_concurrent_cost_and_budget(self):
        self.ready();key=uuid.uuid4().hex
        with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:self.act('record_cost',{'amountMinor':5000,'category':'compute','note':'Measured cost'},key),range(2)))
        self.assertTrue(all(r[0]==200 for r in results),results)
        r=self.request('GET','projects/'+self.p['id'],token=self.owner['token'])[1];self.p=r['project'];self.assertEqual(len(self.p['data']['costs']),1);self.assertEqual(self.p['economics']['contributionMinor'],-5000)
        self.assertEqual(self.act('record_cost',{'amountMinor':16000,'category':'compute','note':'Too much'})[0],409)
        self.assertEqual(self.act('record_cost',{'amountMinor':1,'category':'compute','note':'Different payload'},key)[0],409)
    def test_contract_invalidated(self):
        self.ready();self.assertTrue(self.p['data']['accepted']);self.update({'goal':'Change the outcome and acceptance scope'});self.assertFalse(self.p['data']['accepted'])
        self.assertEqual(self.act('record_cost',{'amountMinor':100,'category':'compute','note':'Not accepted'})[0],400)
    def test_release_requires_checks(self):
        self.assertEqual(self.act('release')[0],409);self.ready();s,r=self.act('simulate');self.assertEqual(s,200);self.assertTrue(all(c['passed'] for c in r['result']['checks']));self.p=r['project']
        s,r=self.act('release');self.assertEqual(s,200);self.assertEqual(r['result']['status'],'internal_review');self.p=r['project']
        self.update({'sources':[{'id':'expired','title':'Expired source','url':'https://example.com','notes':'','checkedAt':'2020-01-01T00:00:00Z','expiresAt':'2020-01-02T00:00:00Z'}]})
        self.assertEqual(self.act('release')[0],409)
    def test_no_fake_payment_or_publication(self):
        self.ready();self.update({'offer':{'title':'Pilot programme','customer':'Customer','scope':'Eight lessons and a project','amountMinor':7900}})
        s,r=self.act('create_order');self.assertEqual(s,200);self.p=r['project'];self.assertEqual(r['result']['status'],'draft');self.assertEqual(self.p['economics']['confirmedRevenueMinor'],0)
        self.assertEqual(self.act('mark_paid')[0],422);self.assertEqual(self.act('publish')[0],422)
    def test_restore_retains_financial_records(self):
        self.ready();s,r=self.act('record_cost',{'amountMinor':1000,'category':'mentors','note':'One review'});self.assertEqual(s,200);self.p=r['project']
        s,r=self.write('projects/'+self.p['id']+'/restore',{'expectedVersion':self.p['version'],'version':1});self.assertEqual(s,200);self.assertEqual(len(r['project']['data']['costs']),1);self.assertFalse(r['project']['data']['accepted']);self.assertEqual(r['project']['version'],self.p['version']+1)
    def test_roles_and_revocation(self):
        route='projects/'+self.p['id']+'/members'
        s,r=self.write(route,{'expectedVersion':self.p['version'],'username':'viewer','role':'viewer'});self.assertEqual(s,200);self.p=r['project']
        self.assertEqual(self.request('GET','projects/'+self.p['id'],token=self.viewer['token'])[0],200)
        self.assertEqual(self.write('projects/'+self.p['id'],{'expectedVersion':self.p['version'],'changes':{'title':'Denied'}},self.viewer['token'])[0],403)
        s,r=self.write(route,{'expectedVersion':self.p['version'],'username':'viewer','role':'editor'});self.assertEqual(s,200);self.p=r['project']
        retrykey=uuid.uuid4().hex;body={'expectedVersion':self.p['version'],'changes':{'title':'Editor update'}}
        s,r=self.write('projects/'+self.p['id'],body,self.viewer['token'],retrykey);self.assertEqual(s,200);self.p=r['project']
        s,r=self.write(route,{'expectedVersion':self.p['version'],'username':'viewer','role':'remove'});self.assertEqual(s,200)
        self.assertEqual(self.write('projects/'+self.p['id'],body,self.viewer['token'],retrykey)[0],404)
    def test_export_restart_and_no_secrets(self):
        self.update({'lessonCompletions':['verify-an-ai-answer'],'audience':'Pilot team'})
        status,r=self.request('GET','projects/'+self.p['id']+'/export',token=self.owner['token']);self.assertEqual(status,200);self.assertEqual(len(r['snapshots']),2)
        raw=json.dumps(r);self.assertNotIn('password_hash',raw);self.assertNotIn(self.owner['token'],raw)
        restarted=Store(self.db);self.assertEqual(restarted.get('projects/'+self.p['id'],self.owner['user']['id'])['project']['data']['audience'],'Pilot team')
    def test_validation_and_injection(self):
        for changes in [{'budgetMinor':-1},{'budgetMinor':True},{'costs':[]},{'lessonCompletions':['not-a-lesson']},{'artifact':{'url':'javascript:alert(1)','notes':'','checksum':''}}]:
            status,_=self.write('projects/'+self.p['id'],{'expectedVersion':self.p['version'],'changes':changes});self.assertEqual(status,400)
        status,_=self.request('GET',"projects/%27%20OR%201=1--",token=self.other['token']);self.assertEqual(status,404)
    def test_product_artifact_is_escaped_owned_and_exported(self):
        self.ready();self.update({'title':'<script>alert(1)</script>','allowedActions':['local_checks','build_preview']});self.update({'accepted':True})
        status,r=self.act('build_preview');self.assertEqual(status,200,r);self.p=r['project'];aid=self.p['data']['artifact']['assetId'];self.assertTrue(aid)
        status,r=self.request('GET','projects/'+self.p['id']+'/assets/'+aid,token=self.owner['token']);self.assertEqual(status,200);self.assertIn('&lt;script&gt;',r['asset']['html']);self.assertNotIn('<script>',r['asset']['html'])
        self.assertEqual(self.request('GET','projects/'+self.p['id']+'/assets/'+aid,token=self.other['token'])[0],404)
        status,r=self.request('GET','projects/'+self.p['id']+'/export',token=self.owner['token']);self.assertEqual(status,200);self.assertEqual(r['assets'][0]['id'],aid)
        status,r=self.act('release');self.assertEqual(status,200,r);self.assertEqual(r['result']['assetId'],aid)

    def test_measurement_uses_correction_and_human_help(self):
        status,r=self.act('record_measurement',{'task':'Comparable task A','beforeSeconds':120,'afterSeconds':20,'correctionSeconds':20,'manualSeconds':20,'success':False,'evidence':'A failed acceptance check'})
        self.assertEqual(status,200);self.p=r['project'];self.assertEqual(self.p['metrics']['speedRatio'],2);self.assertEqual(self.p['metrics']['successRate'],0)
        status,r=self.act('record_measurement',{'task':'Comparable task B','beforeSeconds':120,'afterSeconds':40,'correctionSeconds':0,'manualSeconds':0,'success':True,'evidence':'A new task'})
        self.assertEqual(status,200);self.p=r['project'];self.assertEqual(self.p['metrics']['sampleSize'],2);self.assertEqual(self.p['metrics']['successRate'],.5);self.assertEqual(self.p['metrics']['speedRatio'],2.4)
        status,r=self.write('projects/'+self.p['id']+'/restore',{'expectedVersion':self.p['version'],'version':1});self.assertEqual(status,200);self.assertEqual(r['project']['metrics']['sampleSize'],2)
    def test_consistent_backup_and_restore(self):
        self.update({'audience':'State survives a backup'})
        target=Path(self.tmp.name)/('backup-'+uuid.uuid4().hex+'.sqlite3');checksum=backup(self.db,target);self.assertEqual(len(checksum),64)
        restored=Store(target);self.assertEqual(restored.get('projects/'+self.p['id'],self.owner['user']['id'])['project']['data']['audience'],'State survives a backup')
        with self.assertRaises(ValueError):backup(self.db,target)
        self.assertEqual(self.request('GET','projects/'+self.p['id']+'/export',token=self.other['token'])[0],404)

    def test_durable_queue_recovers_and_uses_snapshot(self):
        self.ready();source=self.p['version'];operation=uuid.uuid4().hex;route='projects/'+self.p['id']+'/jobs';body={'expectedVersion':source}
        status,r=self.write(route,body,key=operation);self.assertEqual(status,200);job=r['jobId']
        status,replay=self.write(route,body,key=operation);self.assertEqual(status,200);self.assertEqual(job,replay['jobId'])
        self.update({'audience':'A changed audience after queuing'})
        with self.server.store.transaction() as db:db.execute("UPDATE jobs SET status='running' WHERE id=?",(job,))
        worker=QueueWorker(self.server.store);self.assertTrue(worker.run_one());self.assertFalse(worker.run_one())
        status,result=self.request('GET',route,token=self.owner['token']);self.assertEqual(status,200);self.assertEqual(result['jobs'][0]['status'],'completed');self.assertEqual(result['jobs'][0]['sourceVersion'],source);self.assertTrue(all(c['passed'] for c in result['jobs'][0]['result']['checks']))
        self.assertEqual(self.request('GET',route,token=self.other['token'])[0],404)

    def test_templates_remove_customer_and_finances(self):
        self.ready();s,r=self.act('release');self.assertEqual(s,200);self.p=r['project']
        self.update({'offer':{'title':'Sensitive offer','customer':'Private name','scope':'Confidential scope','amountMinor':10000},'tasks':[{'id':'unreviewed','title':'Unreviewed changed process','done':False}]})
        s,r=self.write('templates',{'projectId':self.p['id'],'title':'Reusable process'});self.assertEqual(s,200);tid=r['template']['id'];self.assertNotIn('Private name',json.dumps(r));self.assertNotIn('Unreviewed changed process',json.dumps(r));self.assertNotIn('costs',r['template']['data'])
        s,r=self.write('projects',{'title':'From template','goal':'Another measurable project outcome','templateId':tid});self.assertEqual(s,200);self.assertEqual(len(r['project']['data']['acceptance']),1);self.assertFalse(r['project']['data']['accepted']);self.assertFalse(r['project']['data']['consents']['business'])
        self.assertEqual(self.write('projects',{'title':'Steal template','goal':'Another measurable project outcome','templateId':tid},self.other['token'])[0],404)

if __name__=='__main__':
    from datetime import datetime,timezone
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(CoreTests))
    report={'scope':'Real temporary HTTP/SQLite integration checks, not browser or production validation','status':'passed' if result.wasSuccessful() else 'failed','testsRun':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),'generatedAt':datetime.now(timezone.utc).isoformat(),'paymentsTested':False,'externalServicesTested':False,'checks':['session and origin','project isolation','optimistic version conflict','concurrent idempotent costs','budget limits','contract invalidation','release gates and expired sources','disabled payment and publication actions','restore preserving ledger','roles and revocation','export without credentials','restart persistence','input validation','immutable template release snapshot','durable queue recovery','consistent SQLite backup','artifact escaping and access','measurements including correction and human time']}
    (Path(__file__).resolve().parents[1]/'docs/CORE-TEST-REPORT.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    sys.exit(0 if result.wasSuccessful() else 1)
