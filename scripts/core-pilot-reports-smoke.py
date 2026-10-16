"""Pilot reporting integration scenarios plus all 28 Core/Learning regressions."""
from pathlib import Path
from datetime import datetime,timezone
import importlib.util
import json
import sys
import unittest
import uuid
spec=importlib.util.spec_from_file_location('learning_base',Path(__file__).with_name('core-learning-smoke.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)

class PilotTests(base.LearningTests):
    def report(self,token=None):return self.request('GET','projects/'+self.p['id']+'/learning/report',token=token or self.owner['token'])
    def overview(self,token=None):return self.request('GET','learning/overview',token=token or self.owner['token'])
    def assign(self,sid,reviewer='other',deadline='2020-01-01T12:00:00Z',token=None,key=None):return self.learning('assign_review',token,key,submissionId=sid,reviewer=reviewer,deadline=deadline,note='Check evidence from the new example.')
    def test_empty_report_has_no_manufactured_results(self):
        self.enable();status,report=self.report();self.assertEqual(status,200,report);self.assertEqual(report['counts']['accountsWithAccess'],1);self.assertEqual(report['counts']['practiceAttempts'],0);self.assertEqual(report['counts']['submissions'],0);self.assertIsNone(report['measurements']['speedRatio']);self.assertFalse(report['limits']['skillIndependentlyVerified']);self.assertFalse(report['limits']['realPilotConfirmed']);self.assertGreater(len(report['warnings']),0)
    def test_overview_isolates_projects_and_learning_consent(self):
        status,foreign=self.write('projects',{'title':'Private project of other account','goal':'This project must never appear in the owner overview.'},self.other['token']);self.assertEqual(status,200);foreign=foreign['project']
        self.assertEqual(self.write('projects/'+foreign['id'],{'expectedVersion':1,'changes':{'consents':{'learning':True,'studio':False,'business':False}}},self.other['token'])[0],200)
        self.enable();status,overview=self.overview();self.assertEqual(status,200);ids={p['projectId'] for p in overview['projects']};self.assertIn(self.p['id'],ids);self.assertNotIn(foreign['id'],ids)
        self.assertEqual(self.request('GET','projects/'+foreign['id']+'/learning/report',token=self.owner['token'])[0],404)
        self.update({'consents':{'learning':False,'studio':True,'business':False}});self.assertEqual(self.report()[0],400);self.assertNotIn(self.p['id'],{p['projectId'] for p in self.overview()[1]['projects']})
    def test_assignment_requires_owner_and_non_author_writer(self):
        self.complete_program();submitted=self.submit();self.assertEqual(self.assign(submitted['id'],reviewer='owner')[0],403);self.add_member('viewer','viewer');self.assertEqual(self.assign(submitted['id'],reviewer='viewer')[0],403)
        self.add_member('other','editor');self.assertEqual(self.assign(submitted['id'],token=self.other['token'])[0],403);self.assertEqual(self.assign(submitted['id'])[0],200)
        state=self.state()[1];self.assertEqual(state['assignments'][0]['reviewer'],'other');self.assertEqual(state['assignments'][0]['status'],'open')
    def test_assignment_idempotency_and_stale_version(self):
        self.complete_program();submitted=self.submit();self.add_member('other','editor');version=self.p['version'];key=uuid.uuid4().hex
        status,result=self.assign(submitted['id'],key=key);self.assertEqual(status,200);result_version=self.p['version']
        body=dict(expectedVersion=version,action='assign_review',submissionId=submitted['id'],reviewer='other',deadline='2020-01-01T12:00:00Z',note='Check evidence from the new example.')
        route='projects/'+self.p['id']+'/learning';status,result=self.write(route,body,key=key);self.assertEqual(status,200);self.assertTrue(result['replayed']);self.assertEqual(result['project']['version'],result_version);self.assertEqual(len(self.state()[1]['assignments']),1)
        body['note']='Changed payload using the same key.';self.assertEqual(self.write(route,body,key=key)[0],409);self.assertEqual(self.write(route,body)[0],409)
    def test_assignment_closes_only_after_valid_assigned_review(self):
        self.complete_program();submitted=self.submit();self.add_member('other','editor');self.add_member('viewer','editor');self.assertEqual(self.assign(submitted['id'])[0],200)
        mine=self.overview(self.other['token'])[1]['myAssignments'];item=next(v for v in mine if v['submissionId']==submitted['id']);self.assertTrue(item['assignment']['overdue'])
        self.assertEqual(self.learning('review',self.viewer['token'],submissionId=submitted['id'],scores=self.scores(),note='A different unassigned reviewer must be denied.')[0],403)
        self.assertEqual(self.learning('review',self.other['token'],submissionId=submitted['id'],scores=self.scores(),note='short')[0],400);self.assertEqual(self.state()[1]['assignments'][0]['status'],'open')
        status,result=self.learning('review',self.other['token'],submissionId=submitted['id'],scores=self.scores(),note='The new example supports all five criteria.');self.assertEqual(status,200,result);self.assertEqual(self.state()[1]['assignments'][0]['status'],'done');self.assertNotIn(submitted['id'],{v['submissionId'] for v in self.overview(self.other['token'])[1]['myAssignments']})
        report=self.report()[1];self.assertEqual(report['counts']['latestReviewedByParticipant'],1);self.assertEqual(report['counts']['pendingLatestReviews'],0);self.assertFalse(report['limits']['skillIndependentlyVerified'])
    def test_removed_reviewer_is_flagged_and_cannot_read(self):
        self.complete_program();submitted=self.submit();self.add_member('other','editor');self.assign(submitted['id']);self.add_member('other','remove')
        report=self.report()[1];self.assertFalse(report['queue'][0]['assignment']['hasAccess']);self.assertTrue(any('права редактирования' in v for v in report['warnings']));self.assertEqual(self.report(self.other['token'])[0],404)
        self.assertNotIn(self.p['id'],{p['projectId'] for p in self.overview(self.other['token'])[1]['projects']})
    def test_only_latest_submission_per_author_changes_headline_counts(self):
        self.complete_program();old=self.submit();self.add_member('other','editor');self.assertEqual(self.learning('review',self.other['token'],submissionId=old['id'],scores=self.scores(1),note='Please make the suggested changes on a new example.')[0],200)
        latest=self.submit();self.assertNotEqual(old['id'],latest['id']);report=self.report()[1];self.assertEqual(report['counts']['submissions'],2);self.assertEqual(report['counts']['latestSubmittedAuthors'],1);self.assertEqual(report['counts']['latestNeedChanges'],0);self.assertEqual(report['counts']['pendingLatestReviews'],1)
        self.assertFalse(next(v for v in report['queue'] if v['submissionId']==old['id'])['isLatest']);self.assertTrue(next(v for v in report['queue'] if v['submissionId']==latest['id'])['isLatest'])
        self.assertEqual(self.assign(old['id'])[0],200);tasks=self.overview(self.other['token'])[1]['myAssignments'];self.assertTrue(any(v['submissionId']==old['id'] and not v['isLatest'] for v in tasks))
    def test_latest_review_is_deterministic_at_equal_timestamps(self):
        self.complete_program();submitted=self.submit();self.add_member('other','editor')
        for score in (2,1):self.assertEqual(self.learning('review',self.other['token'],submissionId=submitted['id'],scores=self.scores(score),note='Specific review based on the submitted version.')[0],200)
        with self.server.store.transaction() as db:db.execute("UPDATE reviews SET created_at='2026-01-01T00:00:00+00:00' WHERE project_id=?",(self.p['id'],))
        report=self.report()[1];self.assertEqual(report['queue'][0]['latestScore'],5);self.assertEqual(report['counts']['latestNeedChanges'],1);self.assertEqual(self.state()[1]['reviews'][0]['verdict'],'needs_changes')
    def test_report_measurements_include_corrections_and_do_not_score_skill(self):
        self.enable()
        for success in (False,True):
            status,result=self.act('record_measurement',{'task':'Comparable pilot task','beforeSeconds':120,'afterSeconds':20,'correctionSeconds':20,'manualSeconds':20,'success':success,'evidence':'User-entered comparison including all corrections.'});self.assertEqual(status,200);self.p=result['project']
        report=self.report()[1];self.assertEqual(report['measurements']['sampleSize'],2);self.assertEqual(report['measurements']['speedRatio'],2);self.assertEqual(report['measurements']['successRate'],.5);self.assertFalse(report['limits']['skillIndependentlyVerified']);self.assertEqual(report['counts']['latestReviewedByParticipant'],0)
    def test_report_denominators_and_withdrawal_preserve_history(self):
        self.complete_program();submitted=self.submit();self.add_member('other','editor');lesson=base.CURRICULUM['lessons'][0]
        self.assertEqual(self.learning('activity',self.other['token'],slug=lesson['slug'],answer=lesson['ru']['check']['correctIndex'],practice='Another account practice record with evidence.',locale='ru')[0],200)
        report=self.report()[1];self.assertEqual(report['counts']['accountsWithPractice'],2);self.assertEqual(report['counts']['accountsWithEightCurrentPractices'],1)
        self.assign(submitted['id']);self.assertEqual(self.learning('withdraw_review',submissionId=submitted['id'])[0],200);self.assertEqual(self.state()[1]['assignments'][0]['status'],'withdrawn');self.assertEqual(self.report()[1]['counts']['submissions'],1)
        self.add_member('other','remove');report=self.report()[1];self.assertEqual(report['counts']['accountsWithPractice'],1);self.assertEqual(report['counts']['practiceAttempts'],9)
        status,export=self.request('GET','projects/'+self.p['id']+'/export',token=self.owner['token']);self.assertEqual(status,200);self.assertEqual(export['learning']['assignments'][0]['status'],'withdrawn')

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(PilotTests))
    report=dict(scope='Real HTTP/SQLite pilot-report and assignment tests including all 28 Core/Learning regressions; not browser or real-student validation',status='passed' if result.wasSuccessful() else 'failed',testsRun=result.testsRun,failures=len(result.failures),errors=len(result.errors),generatedAt=datetime.now(timezone.utc).isoformat(),externalMessagesSent=False,paymentsTested=False)
    (Path(__file__).resolve().parents[1]/'docs/PILOT-REPORT-TESTS.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');sys.exit(0 if result.wasSuccessful() else 1)
