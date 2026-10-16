"""Learning HTTP integration checks plus regression coverage from the existing Core suite."""
from pathlib import Path
from datetime import datetime,timezone
import importlib.util
import json
import sys
import unittest
import uuid
spec=importlib.util.spec_from_file_location('core_base',Path(__file__).with_name('core-api-smoke.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
from core_learning import CURRICULUM,RUBRIC

class LearningTests(base.CoreTests):
    def enable(self):self.update({'consents':{'learning':True,'studio':True,'business':False}})
    def learning(self,action,token=None,key=None,**payload):
        status,result=self.write('projects/'+self.p['id']+'/learning',dict(expectedVersion=self.p['version'],action=action,**payload),token,key)
        if status==200:self.p=result['project']
        return status,result
    def state(self,token=None):return self.request('GET','projects/'+self.p['id']+'/learning',token=token or self.owner['token'])
    def activity(self,correct=True,key=None):
        l=CURRICULUM['lessons'][0];answer=l['ru']['check']['correctIndex'];answer=answer if correct else (answer+1)%len(l['ru']['check']['options'])
        return self.learning('activity',key=key,slug=l['slug'],answer=answer,practice='A real exercise description with source checks and limitations.',locale='ru')
    def complete_program(self):
        self.enable()
        for lesson in CURRICULUM['lessons']:
            status,result=self.learning('activity',slug=lesson['slug'],answer=lesson['ru']['check']['correctIndex'],practice='Exercise result and source verification on a new example.',locale='ru');self.assertEqual(status,200,result)
        self.update({'audience':'Beginners completing a low-risk practical task','acceptance':[{'id':'quality','title':'Compare with a new example','done':True}],'sources':[{'id':str(i),'title':'Source '+str(i),'url':'https://example.com/source/'+str(i),'notes':'Primary source context','checkedAt':'','expiresAt':''} for i in range(3)],'artifact':{'url':'https://example.com/result','checksum':'','notes':'A reproducible example'},'practice':{'problem':'Verifying claims','before':'Baseline example and time','newTask':'A genuinely new input example','after':'Result with corrections included','evidence':'Comparison logs and source notes'}})
    def submit(self):
        status,result=self.learning('submit',summary='A final working instruction with reproducible steps, limitations and the new-task comparison.',evidence='Evidence: source links, comparison records and reproducible results.');self.assertEqual(status,200,result)
        return self.state()[1]['submissions'][0]
    def add_member(self,username,role):
        status,result=self.write('projects/'+self.p['id']+'/members',{'expectedVersion':self.p['version'],'username':username,'role':role});self.assertEqual(status,200,result);self.p=result['project']
    def scores(self,score=2):return [{'id':r['id'],'score':score,'evidence':'Specific evidence from the submitted new-task example.'} for r in RUBRIC]
    def session(self,**changes):
        fields=dict(title='Review of practical work',startsAt='2020-01-01T10:00:00Z',endsAt='2020-01-01T11:00:00Z',kind='review',facilitator='owner',meetingUrl='https://example.com/meeting',notes='Prepare examples before joining.');fields.update(changes)
        return self.learning('session',**fields)
    def test_activity_consent_wrong_answer_and_viewer(self):
        self.assertEqual(self.activity()[0],400);self.enable();status,result=self.activity(False);self.assertEqual(status,200,result);self.assertFalse(result['feedback']['passed']);self.assertEqual(self.state()[1]['completed'],[]);self.assertEqual(len(self.state()[1]['activities']),1)
        status,result=self.activity();self.assertEqual(status,200);self.assertTrue(result['feedback']['passed']);self.assertEqual(len(self.state()[1]['completed']),1)
        self.add_member('viewer','viewer');self.assertEqual(self.state(self.viewer['token'])[0],200)
        lesson=CURRICULUM['lessons'][0];self.assertEqual(self.learning('activity',self.viewer['token'],slug=lesson['slug'],answer=0,practice='A long enough exercise record.',locale='ru')[0],403)
        self.assertEqual(self.state(self.other['token'])[0],404)
    def test_second_session_continues_the_same_personal_progress(self):
        self.enable();self.assertEqual(self.activity()[0],200)
        status,login=self.request('POST','auth/login',{'username':'owner','password':'long password for pilot 2026'});self.assertEqual(status,200)
        status,state=self.state(login['token']);self.assertEqual(status,200);self.assertEqual(len(state['completed']),1);self.assertEqual(state['activities'][0]['actor'],'owner')

    def test_activity_idempotency_and_conflict(self):
        self.enable();key=uuid.uuid4().hex;v=self.p['version'];status,result=self.activity(key=key);self.assertEqual(status,200)
        l=CURRICULUM['lessons'][0];body=dict(expectedVersion=v,action='activity',slug=l['slug'],answer=l['ru']['check']['correctIndex'],practice='A real exercise description with source checks and limitations.',locale='ru')
        self.assertEqual(self.write('projects/'+self.p['id']+'/learning',body,key=key)[0],200);self.assertEqual(len(self.state()[1]['activities']),1)
        body['practice']='Different exercise evidence with the same operation key.';self.assertEqual(self.write('projects/'+self.p['id']+'/learning',body,key=key)[0],409)
        body['expectedVersion']=v;self.assertEqual(self.write('projects/'+self.p['id']+'/learning',body)[0],409)
    def test_manual_completion_does_not_replace_practice(self):
        self.enable();self.update({'lessonCompletions':[l['slug'] for l in CURRICULUM['lessons']]})
        self.assertEqual(self.state()[1]['completed'],[])
        self.assertEqual(self.learning('submit',summary='A sufficiently long final work description for the programme.',evidence='Evidence description sufficient in length.')[0],409)
    def test_progress_is_personal_and_curriculum_changes_invalidate_it(self):
        from core_learning import LESSONS
        self.enable();self.assertEqual(self.activity()[0],200);self.add_member('other','editor')
        self.assertEqual(self.state()[1]['completed'],[CURRICULUM['lessons'][0]['slug']]);self.assertEqual(self.state(self.other['token'])[1]['completed'],[])
        lesson=LESSONS[CURRICULUM['lessons'][0]['slug']];old=lesson['hash']
        try:
            lesson['hash']='changed-curriculum-version';self.assertEqual(self.state()[1]['completed'],[])
        finally:lesson['hash']=old
        self.update({'consents':{'learning':False,'studio':True,'business':False}});self.assertEqual(self.state()[0],400)
        status,export=self.request('GET','projects/'+self.p['id']+'/export',token=self.owner['token']);self.assertEqual(status,200);self.assertEqual(len(export['learning']['activities']),1)

    def test_invalid_activity_does_not_save(self):
        self.enable();slug=CURRICULUM['lessons'][0]['slug']
        for payload in [dict(slug='unknown',answer=0,practice='Enough practice text for a test.'),dict(slug=slug,answer=True,practice='Enough practice text for a test.'),dict(slug=slug,answer=999,practice='Enough practice text for a test.'),dict(slug=slug,answer=0,practice='short')]:
            self.assertEqual(self.learning('activity',**payload)[0],400)
        self.assertEqual(self.state()[1]['activities'],[])
    def test_submission_snapshot_and_export(self):
        self.complete_program();original=self.p['data']['goal'];source=self.p['version'];submitted=self.submit();self.assertEqual(submitted['sourceVersion'],source)
        self.update({'goal':'The latest project scope has changed after submission.'})
        status,result=self.request('GET','projects/'+self.p['id']+'/learning/submissions/'+submitted['id'],token=self.owner['token']);self.assertEqual(status,200);self.assertEqual(result['snapshot']['goal'],original)
        self.assertEqual(self.request('GET','projects/'+self.p['id']+'/learning/submissions/'+submitted['id'],token=self.other['token'])[0],404)
        status,export=self.request('GET','projects/'+self.p['id']+'/export',token=self.owner['token']);self.assertEqual(status,200);self.assertEqual(len(export['learning']['activities']),8);self.assertEqual(len(export['learning']['submissions']),1);self.assertNotIn(self.owner['token'],json.dumps(export))
    def test_review_self_denied_peer_feedback_retained(self):
        self.complete_program();submitted=self.submit();self.assertEqual(self.learning('review',submissionId=submitted['id'],scores=self.scores(),note='A concrete next step for the author.')[0],403)
        self.add_member('other','editor');status,result=self.learning('review',self.other['token'],submissionId=submitted['id'],scores=self.scores(1),note='Please demonstrate the claim on a genuinely new example.');self.assertEqual(status,200,result);reviews=self.state()[1]['reviews'];self.assertEqual(reviews[0]['verdict'],'needs_changes')
        status,result=self.write('projects/'+self.p['id']+'/restore',{'expectedVersion':self.p['version'],'version':1});self.assertEqual(status,200);self.p=result['project'];self.assertEqual(self.state()[0],400);status,export=self.request('GET','projects/'+self.p['id']+'/export',token=self.owner['token']);self.assertEqual(status,200);self.assertEqual(len(export['learning']['reviews']),1)
    def test_review_needs_all_evidence_and_editor_rights(self):
        self.complete_program();submitted=self.submit();self.add_member('other','editor');scores=self.scores();scores[0]['evidence']=''
        self.assertEqual(self.learning('review',self.other['token'],submissionId=submitted['id'],scores=scores,note='Please revise the practical work.')[0],400)
        self.assertEqual(self.learning('review',self.other['token'],submissionId=submitted['id'],scores=self.scores()[:-1],note='Please revise the practical work.')[0],400)
        self.add_member('other','viewer');self.assertEqual(self.learning('review',self.other['token'],submissionId=submitted['id'],scores=self.scores(),note='Please revise the practical work.')[0],403)
        self.assertEqual(self.state()[1]['reviews'],[])
    def test_schedule_owner_only_and_validations(self):
        self.enable();self.assertEqual(self.state()[1]['sessions'],[]);self.add_member('other','editor')
        self.assertEqual(self.learning('session',self.other['token'],title='Forbidden schedule edit')[0],403)
        for changes in [dict(endsAt='2019-01-01T10:00:00Z'),dict(endsAt='2020-01-03T10:00:00Z'),dict(meetingUrl='javascript:alert(1)'),dict(facilitator='missing'),dict(kind='unsupported')]:self.assertGreaterEqual(self.session(**changes)[0],400)
        self.assertEqual(self.state()[1]['sessions'],[]);status,result=self.session();self.assertEqual(status,200,result);self.assertEqual(len(self.state()[1]['sessions']),1)
    def test_attendance_is_self_reported_and_cancellation(self):
        self.enable();self.assertEqual(self.session()[0],200);sid=self.state()[1]['sessions'][0]['id'];self.assertEqual(self.learning('attendance',sessionId=sid,note='I completed a real practical example.')[0],200)
        self.assertEqual(self.learning('attendance',sessionId=sid,note='Updated note from the same participant.')[0],200);attendance=self.state()[1]['attendance'];self.assertEqual(len(attendance),1);self.assertEqual(attendance[0]['actor'],'owner')
        self.assertEqual(self.learning('session_status',sessionId=sid,status='cancelled')[0],200);self.assertEqual(self.learning('attendance',sessionId=sid,note='Cancelled session must reject an update.')[0],400)
        self.assertEqual(self.session(startsAt='2099-01-01T10:00:00Z',endsAt='2099-01-01T11:00:00Z')[0],200);future=next(s for s in self.state()[1]['sessions'] if s['startsAt'].startswith('2099'));self.assertEqual(self.learning('attendance',sessionId=future['id'],note='Future attendance must not be accepted.')[0],400)
    def test_pilot_config_and_removed_access(self):
        self.enable();status,result=self.learning('pilot_config',name='First learning pilot',audience='Beginning learners with one low-risk project.',hypothesis='Practice on a new task should improve verification quality.',notes='No real participants enrolled yet.',status='draft');self.assertEqual(status,200,result);self.assertEqual(self.state()[1]['pilot']['status'],'draft');self.assertEqual(len(self.state()[1]['participants']),1)
        self.add_member('other','editor');self.assertEqual(self.learning('pilot_config',self.other['token'],name='Unauthorized change',audience='Beginning learners.',hypothesis='Something useful for the learning project.',status='running')[0],403)
        self.add_member('other','remove');self.assertEqual(self.state(self.other['token'])[0],404)

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(LearningTests))
    report=dict(scope='Real temporary HTTP/SQLite integration coverage including the 16 existing Core regression tests; not browser QA or a real student pilot',status='passed' if result.wasSuccessful() else 'failed',testsRun=result.testsRun,failures=len(result.failures),errors=len(result.errors),generatedAt=datetime.now(timezone.utc).isoformat(),externalMessagesSent=False,paymentsTested=False)
    (Path(__file__).resolve().parents[1]/'docs/LEARNING-TEST-REPORT.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');sys.exit(0 if result.wasSuccessful() else 1)
