"""Account-access integration checks plus 38 Core/Learning/Pilot regressions."""
from pathlib import Path
from datetime import datetime,timezone
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
import importlib.util
import json
import sys
import time
import unittest
import uuid
spec=importlib.util.spec_from_file_location('pilot_base',Path(__file__).with_name('core-pilot-reports-smoke.py'));base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
import core_account
import core_server

class AccountTests(base.PilotTests):
    def setUp(self):
        with self.server.rate_lock:self.server.rate_limits.clear()
        super().setUp()
    def account(self):
        username='account-'+uuid.uuid4().hex[:16];password='separate account password 2026'
        status,result=self.request('POST','auth/register',{'username':username,'password':password});self.assertEqual(status,200,result);return dict(**result,password=password,username=username)
    def login(self,a,password=None):return self.request('POST','auth/login',{'username':a['username'],'password':password or a['password']})
    def secure(self,a,token=None):return self.request('GET','auth/security',token=token or a['token'])
    def prepare(self,a):
        status,result=self.request('POST','auth/recovery/prepare',{'currentPassword':a['password']},a['token']);self.assertEqual(status,200,result);return result
    def activate(self,a,prepared,token=None):return self.request('POST','auth/recovery/activate',{'batchId':prepared['batchId'],'confirmation':prepared['confirmation']},token or a['token'])
    def test_account_session_list_revocation_and_foreign_scope(self):
        a=self.account();status,second=self.login(a);self.assertEqual(status,200);status,security=self.secure(a);self.assertEqual(status,200);self.assertEqual(len(security['sessions']),2);self.assertTrue(any(v['current'] for v in security['sessions']));self.assertNotIn(a['token'],json.dumps(security))
        other_session=next(v for v in security['sessions'] if not v['current']);self.assertEqual(self.request('POST','auth/sessions/revoke',{'sessionId':other_session['id']},a['token'])[0],200)
        self.assertEqual(self.request('GET','auth/me',token=second['token'])[0],401);self.assertEqual(self.secure(a)[0],200)
        b=self.account();foreign=self.secure(b)[1]['sessions'][0]['id'];self.assertEqual(self.request('POST','auth/sessions/revoke',{'sessionId':foreign},a['token'])[0],200);self.assertEqual(self.secure(b)[0],200)
    def test_account_password_change_keeps_current_and_revokes_others(self):
        a=self.account();second=self.login(a)[1];new='changed account password 2026'
        self.assertEqual(self.request('POST','auth/password',{'currentPassword':'incorrect current password','newPassword':new},a['token'])[0],403)
        status,result=self.request('POST','auth/password',{'currentPassword':a['password'],'newPassword':new},a['token']);self.assertEqual(status,200,result);self.assertTrue(result['currentSessionKept']);self.assertEqual(self.secure(a)[0],200);self.assertEqual(self.request('GET','auth/me',token=second['token'])[0],401);self.assertEqual(self.login(a)[0],401);self.assertEqual(self.login(a,new)[0],200)
    def test_account_prepared_codes_are_inactive_and_never_stored_plaintext(self):
        a=self.account();p=self.prepare(a);self.assertEqual(len(p['codes']),8);self.assertEqual(self.secure(a)[1]['recoveryRemaining'],0)
        self.assertEqual(self.request('POST','auth/recover',{'username':a['username'],'code':p['codes'][0],'newPassword':'new account recovered password'},None)[0],401)
        with self.server.store.connect() as db:raw=json.dumps([dict(v) for v in db.execute('SELECT * FROM recovery_pending WHERE user_id=?',(a['user']['id'],))])
        self.assertNotIn(p['codes'][0],raw);self.assertNotIn(p['codes'][0].replace('-',''),raw);self.assertNotIn(p['confirmation'],raw);self.assertEqual(self.secure(a)[0],200)
    def test_account_code_activation_is_bound_idempotent_and_expiring(self):
        a=self.account();p=self.prepare(a);second=self.login(a)[1]
        self.assertEqual(self.activate(a,p,second['token'])[0],409);self.assertEqual(self.activate(a,p)[0],200);status,replay=self.activate(a,p);self.assertEqual(status,200);self.assertTrue(replay['replayed']);self.assertEqual(self.secure(a)[1]['recoveryRemaining'],8)
        next_batch=self.prepare(a)
        with self.server.store.transaction() as db:db.execute('UPDATE recovery_pending SET expires_at=? WHERE user_id=?',(time.time()-1,a['user']['id']))
        self.assertEqual(self.activate(a,next_batch)[0],409);self.assertEqual(self.secure(a)[1]['recoveryBatch']['id'],p['batchId']);self.assertEqual(self.secure(a)[1]['recoveryRemaining'],8)
    def test_account_recovery_is_single_use_concurrent_and_preserves_projects(self):
        a=self.account();p=self.prepare(a);self.activate(a,p);status,project=self.write('projects',{'title':'Preserved private project','goal':'Keep work after recovering an account password.'},a['token']);self.assertEqual(status,200)
        passwords=['first recovered password 2026','second recovered password 2026']
        def recover(password):return self.request('POST','auth/recover',{'username':a['username'],'code':p['codes'][0],'newPassword':password})
        with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(recover,passwords))
        self.assertEqual(sorted(r[0] for r in results),[200,401]);winner=passwords[next(i for i,r in enumerate(results) if r[0]==200)]
        self.assertEqual(self.secure(a)[0],401);self.assertEqual(self.login(a)[0],401);status,new=self.login(a,winner);self.assertEqual(status,200)
        self.assertEqual(self.request('GET','projects/'+project['project']['id'],token=new['token'])[0],200);self.assertEqual(self.secure(a,new['token'])[1]['recoveryRemaining'],0)
        self.assertEqual(self.request('POST','auth/recover',{'username':a['username'],'code':p['codes'][1],'newPassword':'another recovery password 2026'})[0],401)
    def test_account_rotating_codes_and_revoke_others(self):
        a=self.account();old=self.prepare(a);self.activate(a,old);new=self.prepare(a);self.assertEqual(self.secure(a)[1]['recoveryBatch']['id'],old['batchId']);self.activate(a,new)
        self.assertEqual(self.request('POST','auth/recover',{'username':a['username'],'code':old['codes'][0],'newPassword':'another recovery password 2026'})[0],401)
        second=self.login(a)[1];self.assertEqual(self.request('POST','auth/sessions/revoke-others',{},a['token'])[0],200);self.assertEqual(self.request('GET','auth/me',token=second['token'])[0],401);self.assertEqual(self.secure(a)[1]['recoveryRemaining'],8)
        current=self.secure(a)[1]['sessions'][0]['id'];self.assertTrue(self.request('POST','auth/sessions/revoke',{'sessionId':current},a['token'])[1]['current']);self.assertEqual(self.secure(a)[0],401)
    def test_account_security_log_has_no_passwords_or_codes_and_legacy_sessions_work(self):
        a=self.account();p=self.prepare(a);self.activate(a,p);status,security=self.secure(a);self.assertEqual(status,200);raw=json.dumps(security);self.assertNotIn(a['password'],raw);self.assertNotIn(p['confirmation'],raw)
        for code in p['codes']:self.assertNotIn(code,raw)
        with self.server.store.transaction() as db:db.execute('DELETE FROM session_details WHERE token_hash=?',(core_server.digest(a['token']),))
        self.assertIsNone(self.secure(a)[1]['sessions'][0]['createdAt'])
    def test_account_login_cannot_issue_session_after_concurrent_password_change(self):
        a=self.account();original=core_server.password_hash
        def interrupted(password,salt):
            result=original(password,salt)
            with self.server.store.transaction() as db:db.execute("UPDATE users SET password_hash='changed-by-another-request' WHERE id=?",(a['user']['id'],))
            return result
        with patch('core_server.password_hash',side_effect=interrupted):
            self.assertEqual(self.login(a)[0],409)
        with self.server.store.connect() as db:self.assertEqual(db.execute('SELECT COUNT(*) FROM sessions WHERE user_id=?',(a['user']['id'],)).fetchone()[0],1)
    def test_account_password_recheck_rejects_stale_authorization(self):
        a=self.account();original=core_account.checked_user
        def interrupted(store,user,password):
            result=original(store,user,password)
            with store.transaction() as db:db.execute("UPDATE users SET password_hash='changed-by-another-request' WHERE id=?",(user,))
            return result
        with patch('core_account.checked_user',side_effect=interrupted):self.assertEqual(self.request('POST','auth/password',{'currentPassword':a['password'],'newPassword':'different password after concurrent change'},a['token'])[0],409)
    def test_account_recovery_is_throttled_and_cross_origin_blocked(self):
        self.assertEqual(self.request('POST','auth/recover',{'username':'unknown','code':'a'*32,'newPassword':'a sufficiently long new password'},origin='https://evil.example')[0],403)
        with self.server.rate_lock:self.server.rate_limits.clear()
        for _ in range(20):self.assertEqual(self.request('POST','auth/recover',{'username':'unknown','code':'bad','newPassword':'a sufficiently long new password'})[0],401)
        self.assertEqual(self.request('POST','auth/recover',{'username':'unknown','code':'bad','newPassword':'a sufficiently long new password'})[0],429)

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(AccountTests))
    report=dict(scope='HTTP/SQLite account access tests plus all 38 Core/Learning/Pilot regressions; not a security audit or browser QA',status='passed' if result.wasSuccessful() else 'failed',testsRun=result.testsRun,failures=len(result.failures),errors=len(result.errors),generatedAt=datetime.now(timezone.utc).isoformat(),externalMessagesSent=False,paymentsTested=False)
    (Path(__file__).resolve().parents[1]/'docs/ACCOUNT-TEST-REPORT.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');sys.exit(0 if result.wasSuccessful() else 1)
