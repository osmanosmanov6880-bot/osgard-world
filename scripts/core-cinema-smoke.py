"""Real HTTP/SQLite OSA Cinema V61 collaboration tests, including pre-existing Core regressions."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from tempfile import TemporaryDirectory
import importlib.util
import json
import sys
import unittest
import uuid

base_spec=importlib.util.spec_from_file_location('core_base',Path(__file__).with_name('core-api-smoke.py'))
base=importlib.util.module_from_spec(base_spec);base_spec.loader.exec_module(base)
from core_server import Store
from core_backup import backup

class CinemaTests(base.CoreTests):
    def workspace(self,film='zero-window',token=None):
        status,result=self.write('cinema/spaces',{'filmId':film,'title':'OSA production pilot'},token)
        self.assertEqual(status,200,result)
        return result['workspaceId']

    def view(self,id,token=None):
        return self.request('GET','cinema/spaces/'+id,token=token or self.owner['token'])

    def edit(self,id,version,kind,token=None,key=None,**params):
        return self.write('cinema/spaces/'+id,
            {'expectedVersion':version,'kind':kind,**params},token,key)

    def test_scoped_workspaces_and_no_public_release(self):
        self.assertEqual(self.request('GET','cinema/spaces')[0],401)
        wid=self.workspace()
        status,r=self.view(wid);self.assertEqual(status,200,r)
        self.assertEqual(r['space']['filmId'],'zero-window')
        self.assertEqual(r['space']['role'],'owner')
        self.assertEqual(r['space']['publicFilmReleaseAuthorized'],False)
        self.assertEqual(r['space']['publicVideoUrl'],None)
        self.assertEqual(r['tasks'],[])
        self.assertEqual(r['audit'][0]['kind'],'space_created')
        self.assertEqual(r['limits']['noFilmPremiere'],True)
        listed=self.request('GET','cinema/spaces',token=self.owner['token'])[1]
        self.assertIn(wid,{x['id'] for x in listed['spaces']})
        self.assertNotIn(wid,{x['id'] for x in self.request('GET','cinema/spaces',token=self.other['token'])[1]['spaces']})
        self.assertEqual(self.view(wid,self.other['token'])[0],404)
        self.assertEqual(self.edit(wid,1,'task.create',self.other['token'],sceneId='S01',category='script',title='Try to steal')[0],404)
        self.assertEqual(self.request('GET','cinema/spaces',token=self.owner['token'],origin='https://evil.invalid')[0],403)
        self.assertEqual(self.workspace('threshold')!=wid,True)
        self.assertEqual(self.write('cinema/spaces',{'filmId':'zero-window','title':'Duplicate'})[0],409)

    def test_task_creation_update_validation_and_audit(self):
        wid=self.workspace()
        status,r=self.edit(wid,1,'task.create',sceneId='S03',category='camera',
                           title='Record camera blocking',owner='Camera lead',
                           dueDate='2026-11-10',notes='Plan only: no shooting evidence.')
        self.assertEqual(status,200,r)
        self.assertEqual(r['version'],2)
        self.assertIsNone(r['publicVideoUrl'])
        v=self.view(wid)[1]
        self.assertEqual(len(v['tasks']),1)
        t=v['tasks'][0]
        self.assertEqual(t['sceneId'],'S03')
        self.assertEqual(t['status'],'planned')
        self.assertEqual(t['notes'],'Plan only: no shooting evidence.')
        self.assertEqual(self.edit(wid,2,'task.update',taskId=t['id'],status='ready_for_review')[0],200)
        self.assertEqual(self.view(wid)[1]['tasks'][0]['status'],'ready_for_review')
        self.assertEqual(self.view(wid)[1]['space']['publicFilmReleaseAuthorized'],False)
        self.assertEqual(self.edit(wid,3,'task.delete',taskId=t['id'])[0],200)
        self.assertEqual(self.view(wid)[1]['tasks'],[])
        kinds=[event['kind'] for event in self.view(wid)[1]['audit']]
        self.assertEqual(kinds[:3],['task.delete','task.update','task.create'])
        self.assertNotIn('Plan only: no shooting evidence.',json.dumps(self.view(wid)[1]['audit']))

    def test_owner_only_member_management_and_viewer_read_only(self):
        wid=self.workspace()
        self.assertEqual(self.edit(wid,1,'member.set',username='viewer',role='viewer')[0],200)
        v=self.view(wid,self.viewer['token'])
        self.assertEqual(v[0],200,v)
        self.assertEqual(v[1]['space']['role'],'viewer')
        self.assertEqual(self.edit(wid,2,'task.create',self.viewer['token'],
                       sceneId='S01',category='script',title='Viewer should not edit')[0],403)
        self.assertEqual(self.edit(wid,2,'member.set',self.viewer['token'],username='other',role='editor')[0],403)
        self.assertEqual(self.edit(wid,2,'member.set',username='other',role='editor')[0],200)
        self.assertEqual(self.edit(wid,3,'task.create',self.other['token'],
                sceneId='S02',category='camera',title='Editor can plan tasks')[0],200)
        task=self.view(wid)[1]['tasks'][0]
        self.assertEqual(task['title'],'Editor can plan tasks')
        self.assertEqual(self.edit(wid,4,'member.set',self.other['token'],username='viewer',role='editor')[0],403)
        self.assertEqual(self.edit(wid,4,'member.remove',username='other')[0],200)
        self.assertEqual(self.view(wid,self.other['token'])[0],404)
        self.assertEqual(self.edit(wid,5,'task.delete',self.other['token'],taskId=task['id'])[0],404)
        self.assertEqual(self.edit(wid,5,'member.remove',username='owner')[0],400)
        self.assertEqual(self.edit(wid,5,'space.rename',self.viewer['token'],title='Viewer rename')[0],403)

    def test_member_removal_invalidates_previous_idempotent_editor_operation(self):
        wid=self.workspace()
        self.assertEqual(self.edit(wid,1,'member.set',username='other',role='editor')[0],200)
        key=uuid.uuid4().hex
        body={'expectedVersion':2,'kind':'task.create','sceneId':'S05','category':'sound','title':'Sound mapping'}
        route='cinema/spaces/'+wid
        s,r=self.write(route,body,self.other['token'],key);self.assertEqual(s,200,r)
        tid=r['detail']['taskId']
        again=self.write(route,body,self.other['token'],key)
        self.assertEqual(again[0],200,again);self.assertEqual(again[1]['detail']['taskId'],tid)
        self.assertTrue(again[1]['replayed'])
        self.assertEqual(self.edit(wid,3,'member.remove',username='other')[0],200)
        self.assertEqual(self.write(route,body,self.other['token'],key)[0],404)
        self.assertEqual(len(self.view(wid)[1]['tasks']),1)

    def test_two_concurrent_writes_conflict_by_version(self):
        wid=self.workspace()
        def write(n):
            return self.edit(wid,1,'task.create',sceneId='S07',category='location',
                             title='Location check '+str(n))
        with ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(write,[1,2]))
        self.assertCountEqual([r[0] for r in results],[200,409],results)
        self.assertEqual(len(self.view(wid)[1]['tasks']),1)
        self.assertEqual(self.view(wid)[1]['space']['version'],2)

    def test_reject_unsupported_scenes_statuses_video_controls_and_dates(self):
        wid=self.workspace()
        body=dict(sceneId='S01',category='script',title='Basic scene planning')
        for patch in [
            {'sceneId':'S14'},{'sceneId':'../admin'},{'sceneId':'PREVIZ'},
            {'status':'filmed'},{'status':'published'},{'category':'distribution'},
            {'dueDate':'2026-02-31'},{'dueDate':'2026-01-01T00:00:00Z'},
            {'notes':'X'*601},{'owner':'X'*81},{'title':' '},
            {'releaseAuthorized':True},{'publicVideoUrl':'https://test.invalid/video.mp4'},
            {'rightsIndependentlyVerified':True},{'publish':True}]:
            s,_=self.edit(wid,1,'task.create',**{**body,**patch})
            self.assertEqual(s,400,patch)
        self.assertEqual(self.write('cinema/spaces',{'filmId':'zero-window','title':'Extra','releaseAuthorized':True})[0],400)
        self.assertEqual(self.edit(wid,1,'publish')[0],400)
        self.assertEqual(self.view(wid)[1]['tasks'],[])
        self.assertEqual(self.workspace('threshold')!=wid,True)
        second=self.request('GET','cinema/spaces',token=self.owner['token'])[1]['spaces']
        tid=next(x['id'] for x in second if x['filmId']=='threshold')
        self.assertEqual(self.edit(tid,1,'task.create',sceneId='S01',category='script',title='Invalid shot')[0],400)
        self.assertEqual(self.edit(tid,1,'task.create',sceneId='PREVIZ',category='post',title='Previz pipeline')[0],200)

    def test_no_cross_workspace_task_modification(self):
        w1=self.workspace()
        w2=self.workspace('threshold')
        self.assertEqual(self.edit(w1,1,'task.create',sceneId='S01',category='script',title='One film only')[0],200)
        tid=self.view(w1)[1]['tasks'][0]['id']
        self.assertEqual(self.edit(w2,1,'task.delete',taskId=tid)[0],404)
        self.assertEqual(self.edit(w2,1,'task.update',taskId=tid,status='ready_for_review')[0],404)
        self.assertEqual(len(self.view(w1)[1]['tasks']),1)
        self.assertEqual(self.view(w2)[1]['tasks'],[])

    def test_exit_revokes_access_and_no_viewer_impersonation(self):
        wid=self.workspace()
        self.assertEqual(self.edit(wid,1,'member.set',username='viewer',role='viewer')[0],200)
        self.assertEqual(self.edit(wid,2,'leave',self.viewer['token'])[0],200)
        self.assertEqual(self.view(wid,self.viewer['token'])[0],404)
        self.assertEqual(self.edit(wid,3,'leave')[0],400)
        self.assertEqual(self.edit(wid,3,'member.set',username='owner',role='editor')[0],400)

    def test_sqlite_persists_space_after_restart_and_backup(self):
        wid=self.workspace()
        self.assertEqual(self.edit(wid,1,'task.create',sceneId='S01',category='camera',title='Persist test')[0],200)
        fresh=Store(self.db)
        s=fresh.get('cinema/spaces/'+wid,self.owner['user']['id'])
        self.assertEqual(s['tasks'][0]['title'],'Persist test')
        with TemporaryDirectory() as tmp:
            copy=Path(tmp)/'cinema.sqlite3'
            digest=backup(self.db,copy)
            self.assertEqual(len(digest),64)
            reopened=Store(copy)
            self.assertEqual(reopened.get('cinema/spaces/'+wid,self.owner['user']['id'])['tasks'][0]['title'],'Persist test')

    def test_revoke_session_and_original_media_no_go(self):
        evidence=json.loads((Path(__file__).resolve().parents[1]/'docs/OSA_CINEMA_V53_CONCEPT_EVIDENCE_20261028.json').read_text())
        self.assertEqual(evidence['actorSceneProduction']['scenesFilmed'],0)
        self.assertFalse(evidence['publicReleaseAuthorized'])
        wid=self.workspace()
        new_session=self.request('POST','auth/login',{'username':'owner','password':'long password for pilot 2026'})[1]
        self.assertEqual(self.request('GET','cinema/spaces/'+wid,token=new_session['token'])[0],200)
        self.assertEqual(self.request('POST','auth/logout',{},new_session['token'])[0],200)
        self.assertEqual(self.request('GET','cinema/spaces/'+wid,token=new_session['token'])[0],401)
        self.assertNotIn('password_hash',json.dumps(self.view(wid)[1]))
        self.assertNotIn(self.owner['token'],json.dumps(self.view(wid)[1]))

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(CinemaTests))
    sys.exit(0 if result.wasSuccessful() else 1)
