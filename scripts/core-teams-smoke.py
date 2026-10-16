"""Team inheritance checks plus 94 project, learning, delivery and account regressions."""
from pathlib import Path
from datetime import datetime,timezone
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
import sys
import unittest
import uuid
spec=importlib.util.spec_from_file_location('portal_base',Path(__file__).with_name('core-client-portal-smoke.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
from core_server import Store
from core_backup import backup

class TeamTests(base.PortalTests):
    def setUp(self):
        if self._testMethodName.startswith('test_team_'):
            with self.server.rate_lock:self.server.rate_limits.clear()
            self.owner=self.account()
        super().setUp()
    def new_team(self,token=None):
        status,r=self.write('teams',dict(name='A controlled team space'),token);self.assertEqual(status,200,r);self.tid=r['teamId'];return self.tid
    def team_state(self,token=None):return self.request('GET','teams/'+self.tid,token=token or self.owner['token'])
    def team_action(self,kind,token=None,key=None,**fields):
        version=self.team_state(token)[1]['team']['version'];return self.write('teams/'+self.tid,dict(expectedVersion=version,action=kind,**fields),token,key)
    def team_member(self,name,role):
        status,r=self.team_action('member',username=name,role=role);self.assertEqual(status,200,r)
    def attach(self,token=None,ack=True):
        status,r=self.team_action('attach',token,projectId=self.p['id'],projectVersion=self.p['version'],sharingAcknowledged=ack)
        if status==200:self.p=self.request('GET','projects/'+self.p['id'],token=self.owner['token'])[1]['project']
        return status,r
    def test_team_create_is_private_and_owner_is_immutable(self):
        self.new_team();self.assertEqual(self.team_state(self.other['token'])[0],404);self.assertEqual(self.team_action('member',username=self.owner['user']['username'],role='viewer')[0],400);self.assertEqual(self.team_action('leave')[0],400)
    def test_team_requires_project_owner_and_explicit_sharing(self):
        self.new_team();self.assertEqual(self.attach(ack=False)[0],400);self.team_member('other','admin');self.add_member('other','editor');self.assertEqual(self.attach(self.other['token'])[0],403);self.assertEqual(self.attach()[0],200)
    def test_team_inherited_editor_and_viewer_use_current_project_acl(self):
        self.new_team();self.team_member('other','editor');self.team_member('viewer','viewer');self.assertEqual(self.attach()[0],200)
        p=self.request('GET','projects/'+self.p['id'],token=self.other['token'])[1]['project'];self.assertEqual(p['role'],'editor');self.assertEqual(self.request('GET','projects/'+self.p['id'],token=self.viewer['token'])[1]['project']['role'],'viewer')
        self.assertEqual(self.write('projects/'+self.p['id'],dict(expectedVersion=self.p['version'],changes={'title':'Denied viewer change'}),self.viewer['token'])[0],403)
        status,r=self.write('projects/'+self.p['id'],dict(expectedVersion=self.p['version'],changes={'title':'A team editor change'}),self.other['token']);self.assertEqual(status,200,r);self.p=r['project']
    def test_team_direct_and_inherited_roles_combine_without_duplicates(self):
        self.new_team();self.add_member('other','viewer');self.team_member('other','editor');self.attach();self.assertEqual(self.request('GET','projects/'+self.p['id'],token=self.other['token'])[1]['project']['role'],'editor')
        self.team_member('other','remove');self.assertEqual(self.request('GET','projects/'+self.p['id'],token=self.other['token'])[1]['project']['role'],'viewer');members=self.request('GET','projects/'+self.p['id']+'/members',token=self.owner['token'])[1]['members'];self.assertEqual(sum(m['username']=='other' for m in members),1)
    def test_team_revoke_blocks_stale_writes_and_idempotent_replay(self):
        self.new_team();self.team_member('other','editor');self.attach();body=dict(expectedVersion=self.p['version'],changes={'title':'A team-authenticated edit'});key=uuid.uuid4().hex;status,r=self.write('projects/'+self.p['id'],body,self.other['token'],key);self.assertEqual(status,200);self.p=r['project'];self.team_member('other','remove');self.assertEqual(self.write('projects/'+self.p['id'],body,self.other['token'],key)[0],404);self.assertEqual(self.request('GET','projects/'+self.p['id']+'/export',token=self.other['token'])[0],404)
    def test_team_admin_cannot_elevate_admin_or_take_project_ownership(self):
        self.new_team();self.team_member('other','admin');self.team_member('viewer','viewer');self.assertEqual(self.team_action('member',self.other['token'],username='viewer',role='admin')[0],403);self.assertEqual(self.team_action('member',self.other['token'],username='viewer',role='editor')[0],200);self.attach();self.assertEqual(self.request('GET','projects/'+self.p['id'],token=self.other['token'])[1]['project']['role'],'editor');self.assertEqual(self.write('projects/'+self.p['id']+'/members',dict(expectedVersion=self.p['version'],username='viewer',role='remove'),self.other['token'])[0],403)
    def test_team_owner_can_detach_after_leaving_team(self):
        self.new_team(self.other['token']);version=self.team_state(self.other['token'])[1]['team']['version'];name=self.owner['user']['username'];self.assertEqual(self.write('teams/'+self.tid,dict(expectedVersion=version,action='member',username=name,role='admin'),self.other['token'])[0],200);self.attach();self.assertEqual(self.team_action('leave')[0],200);self.assertEqual(self.team_state()[0],404)
        context=self.request('GET','projects/'+self.p['id']+'/team',token=self.owner['token'])[1];self.assertTrue(context['canDetach']);status,r=self.write('projects/'+self.p['id']+'/team',dict(expectedVersion=self.p['version']));self.assertEqual(status,200,r);self.p=r['project'];self.assertEqual(self.request('GET','projects/'+self.p['id'],token=self.other['token'])[0],404)
    def test_team_detach_preserves_direct_access_and_project_data(self):
        self.new_team();self.team_member('other','editor');self.team_member('viewer','viewer');self.add_member('viewer','viewer');self.attach();before=self.p['data'];self.assertEqual(self.team_action('detach',projectId=self.p['id'],projectVersion=self.p['version'])[0],200);self.assertEqual(self.request('GET','projects/'+self.p['id'],token=self.other['token'])[0],404);self.assertEqual(self.request('GET','projects/'+self.p['id'],token=self.viewer['token'])[1]['project']['data'],before)
    def test_team_concurrent_version_changes_have_one_commit(self):
        self.new_team();version=self.team_state()[1]['team']['version'];body=dict(expectedVersion=version,action='rename',name='A new stable team name')
        with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:self.write('teams/'+self.tid,body),range(2)))
        self.assertEqual(sorted(v[0] for v in results),[200,409])
    def test_team_learning_and_organizer_use_effective_participants(self):
        self.complete_program();submitted=self.submit();self.new_team();self.team_member('other','editor');self.attach();state=self.state()[1];self.assertEqual(sum(p['username']=='other' for p in state['participants']),1);self.assertEqual(self.assign(submitted['id'])[0],200);self.assertTrue(self.report()[1]['queue'][0]['assignment']['hasAccess']);self.team_member('other','viewer');self.assertFalse(self.report()[1]['queue'][0]['assignment']['hasAccess']);self.assertTrue(any(p['projectId']==self.p['id'] for p in self.overview(self.other['token'])[1]['projects']))
    def test_team_isolated_delivery_stays_private_to_project_writers(self):
        did,recipient,_,_=self.shared();self.new_team();self.team_member('viewer','viewer');self.attach();self.assertEqual(self.client_packet(did,self.viewer['token'])[0],403);self.team_member('viewer','editor');self.assertEqual(self.client_packet(did,self.viewer['token'])[0],200);self.team_member('viewer','remove');self.assertEqual(self.client_packet(did,self.viewer['token'])[0],404);self.assertEqual(self.client_packet(did,recipient['token'])[0],200)
    def test_team_backup_and_owner_deduplication(self):
        self.new_team();self.team_member('other','editor');self.enable();self.attach();people=self.state()[1]['participants'];self.assertEqual(sum(p['id']==self.owner['user']['id'] for p in people),1);copied=Path(self.tmp.name)/('team-'+uuid.uuid4().hex+'.sqlite3');backup(self.db,copied);restored=Store(copied);self.assertEqual(restored.get('projects/'+self.p['id'],self.other['user']['id'])['project']['role'],'editor')

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(TeamTests));report=dict(scope='Team ACL HTTP/SQLite tests plus 94 previous regressions; not SSO, billing or browser QA',status='passed' if result.wasSuccessful() else 'failed',testsRun=result.testsRun,failures=len(result.failures),errors=len(result.errors),generatedAt=datetime.now(timezone.utc).isoformat(),paymentsTested=False,externalMessagesSent=False)
    (Path(__file__).resolve().parents[1]/'docs/TEAM-TESTS.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');sys.exit(0 if result.wasSuccessful() else 1)
