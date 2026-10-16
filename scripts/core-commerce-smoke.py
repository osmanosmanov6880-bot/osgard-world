#!/usr/bin/env python3
"""Real local HTTP/SQLite; injected provider only. No Stripe network or live payment test."""
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from datetime import datetime, timezone
from http.client import HTTPConnection
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch
import copy
import hashlib
import hmac
import json
import os
import sys
import threading
import time
import unittest
import uuid

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'server'))
from core_server import Store,create_server
from core_commerce import Config,API_VERSION,RETRY_WINDOW,StripeProvider


class FakeProvider:
    """In-memory deterministic provider boundary; never sends a request."""
    def __init__(self):
        self.sessions={};self.intents={};self.charges={};self.refunds={};self.keys={};self.refund_keys={}
        self.checkout_creates=0;self.refund_creates=0;self.lose_checkout=False;self.lose_refund=False;self.lock=threading.Lock()
    def create_checkout(self,params,key):
        with self.lock:
            if key not in self.keys:
                self.checkout_creates+=1;sid='cs_test_'+uuid.uuid4().hex
                item=dict(id=sid,livemode=False,mode='payment',metadata=copy.deepcopy(params['metadata']),client_reference_id=params['client_reference_id'],amount_total=params['line_items'][0]['price_data']['unit_amount'],currency=params['line_items'][0]['price_data']['currency'],payment_status='unpaid',status='open',payment_intent=None,url='https://checkout.stripe.com/c/pay/'+sid)
                self.keys[key]=sid;self.sessions[sid]=item
                if self.lose_checkout:self.lose_checkout=False;raise TimeoutError('synthetic lost result')
            return copy.deepcopy(self.sessions[self.keys[key]])
    def retrieve_session(self,value):return copy.deepcopy(self.sessions[value])
    def retrieve_intent(self,value):return copy.deepcopy(self.intents[value])
    def retrieve_charge(self,value):return copy.deepcopy(self.charges[value])
    def refunds_for_charge(self,value):return copy.deepcopy([r for r in self.refunds.values() if r['charge']==value])
    def settle(self,order_id):
        session=next(v for v in self.sessions.values() if v['client_reference_id']==order_id)
        pi='pi_'+uuid.uuid4().hex;ch='ch_'+uuid.uuid4().hex
        self.intents[pi]=dict(id=pi,livemode=False,metadata=copy.deepcopy(session['metadata']),amount=session['amount_total'],amount_received=session['amount_total'],currency=session['currency'],status='succeeded',latest_charge=ch)
        self.charges[ch]=dict(id=ch,livemode=False,amount=session['amount_total'],currency=session['currency'],payment_intent=pi,paid=True,captured=True)
        session.update(payment_status='paid',status='complete',payment_intent=pi)
        return copy.deepcopy(session)
    def create_refund(self,params,key):
        with self.lock:
            if key not in self.refund_keys:
                self.refund_creates+=1;rid='re_'+uuid.uuid4().hex;intent=self.intents[params['payment_intent']]
                self.refunds[rid]=dict(id=rid,object='refund',payment_intent=intent['id'],charge=intent['latest_charge'],amount=params['amount'],currency=intent['currency'],status='succeeded',metadata=copy.deepcopy(params.get('metadata',{})))
                self.refund_keys[key]=rid
                if self.lose_refund:self.lose_refund=False;raise TimeoutError('synthetic lost refund result')
            return copy.deepcopy(self.refunds[self.refund_keys[key]])


class CommerceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp=TemporaryDirectory();public=Path(cls.temp.name)/'public';public.mkdir();(public/'index.html').write_text('<title>test</title>')
        cls.database=Path(cls.temp.name)/'private/core.sqlite3';cls.server=create_server(public,cls.database,port=0,commerce_config=Config())
        cls.port=cls.server.server_address[1];cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True);cls.thread.start()
        cls.people={}
        for name in ('merchant','buyer','reviewer','stranger'):
            status,value=cls.request('POST','auth/register',dict(username='commerce-'+name,password='Temporary integration fixture password 2026'))
            assert status==200,value
            cls.people[name]=value
    @classmethod
    def tearDownClass(cls):cls.server.shutdown();cls.server.server_close();cls.thread.join(3);cls.temp.cleanup()
    @classmethod
    def request(cls,method,route,body=None,token=None,key=None,raw=None,signature=None):
        c=HTTPConnection('127.0.0.1',cls.port,timeout=10);headers={'Content-Type':'application/json'}
        if token:headers['Authorization']='Bearer '+token
        if key:headers['Idempotency-Key']=key
        if signature:headers['Stripe-Signature']=signature
        c.request(method,'/api/core/'+route,raw if raw is not None else json.dumps(body) if body is not None else None,headers)
        r=c.getresponse();value=r.status,json.loads(r.read());c.close();return value
    def setUp(self):
        self.provider=FakeProvider();self.config=Config(True,self.people['merchant']['user']['id'],'acct_fixture',False,'https://osgard.example','not-a-real-key','whsec_local_test_fixture_only')
        self.server.store.commerce.config=self.config;self.server.store.commerce._adapter=self.provider
        status,value=self.write('projects',dict(title='Purchased result',goal='Create a useful static project with a verified final file.'))
        self.assertEqual(status,200,value);self.project=value['project']
    def token(self,person='merchant'):return self.people[person]['token']
    def write(self,route,body,person='merchant',key=None):return self.request('POST',route,body,self.token(person),key or uuid.uuid4().hex)
    def route(self,suffix=''):return 'projects/'+self.project['id']+suffix
    def update(self,changes):
        status,value=self.write(self.route(),dict(expectedVersion=self.project['version'],changes=changes));self.assertEqual(status,200,value);self.project=value['project']
    def action(self,kind,payload=None):
        status,value=self.write(self.route('/actions'),dict(expectedVersion=self.project['version'],kind=kind,payload=payload or {}));self.assertEqual(status,200,value);self.project=value['project'];return value
    def prepare(self):
        self.update(dict(currency='USD',budgetMinor=20000,consents=dict(learning=True,studio=True,business=True),allowedActions=['local_checks','build_preview','prepare_offer'],acceptance=[dict(id='criterion',title='The file explains the agreed result.',done=True)],offer=dict(title='Reviewed HTML result',customer='A known buyer',scope='One reviewed static HTML file; no hosting or subscription.',amountMinor=1000)))
        self.update({'accepted':True});self.action('build_preview')
        status,value=self.write(self.route('/members'),dict(expectedVersion=self.project['version'],username='commerce-reviewer',role='editor'));self.assertEqual(status,200,value);self.project=value['project']
        release=self.action('release')['result']
        status,value=self.write(self.route('/release-review'),dict(expectedVersion=self.project['version'],releaseId=release['id'],criteria=[dict(id='criterion',passed=True,evidence='Opened the HTML and checked its goal against the accepted result.')],note='The participant reviewed the saved file, its goal and its limitations.'),'reviewer');self.assertEqual(status,200,value);self.project=value['project']
        draft=self.action('create_order')['result'];self.draft_id=draft['id'];self.release_id=release['id']
        self.preparation=dict(expectedVersion=self.project['version'],draftOrderId=draft['id'],releaseId=release['id'],buyerUsername='commerce-buyer',confirmedAmountMinor=1000,confirmedCurrency='USD',sharingAcknowledged=True)
        status,value=self.write(self.route('/commerce'),self.preparation);self.assertEqual(status,200,value);self.order=value['order'];return value
    def checkout(self,key=None):
        return self.write('commerce/orders/'+self.order['id']+'/checkout',{},'buyer',key)
    def event(self,kind,obj,event_id=None,changes=None):
        value=dict(id=event_id or 'evt_'+uuid.uuid4().hex,object='event',type=kind,api_version=API_VERSION,livemode=False,data={'object':obj})
        if changes:value.update(changes)
        return value
    def post_event(self,event,offset=0,raw=None):
        raw=raw or json.dumps(event,separators=(',',':')).encode();stamp=str(int(time.time())+offset)
        signature=hmac.new(self.config.webhook_secret.encode(),stamp.encode()+b'.'+raw,hashlib.sha256).hexdigest()
        return self.request('POST','commerce/webhook',raw=raw,signature='t='+stamp+',v1='+signature)
    def purchase(self):
        status,value=self.request('GET','commerce/purchases',token=self.token('buyer'));self.assertEqual(status,200,value)
        return next(item for item in value['orders'] if item['id']==self.order['id'])
    def file(self,person='buyer'):return self.request('GET','commerce/purchases/'+self.order['id']+'/file',token=self.token(person))
    def pay(self):
        self.prepare();self.assertEqual(self.checkout()[0],200);session=self.provider.settle(self.order['id'])
        status,value=self.post_event(self.event('checkout.session.completed',session));self.assertEqual(status,200,value);return session
    def refund(self,target,key=None):return self.write('commerce/orders/'+self.order['id']+'/refund',{'targetRefundMinor':target},key=key)

    def test_default_disabled_and_safe_configuration(self):
        self.server.store.commerce.config=Config()
        status,value=self.request('GET','commerce/config',token=self.token());self.assertEqual(status,200);self.assertFalse(value['enabled']);self.assertNotIn('key',json.dumps(value))
        self.assertEqual(self.post_event(self.event('checkout.session.completed',{'id':'cs_test_disabled'}))[0],503)
        self.assertEqual(self.provider.checkout_creates,0)
        with patch.dict(os.environ,{},clear=True):self.assertFalse(Config.from_env().enabled)

    def test_prepare_binds_price_buyer_and_reviewed_file(self):
        self.prepare();self.assertEqual(self.order['amountMinor'],1000);self.assertEqual(self.order['buyer'],'commerce-buyer')
        self.assertEqual(self.file()[0],403);self.assertEqual(self.file('stranger')[0],404)
        status,value=self.write(self.route('/commerce'),dict(self.preparation,confirmedAmountMinor=999));self.assertEqual(status,400)
        status,value=self.write(self.route('/commerce'),self.preparation,'reviewer');self.assertEqual(status,403)
        self.assertEqual(self.request('GET',self.route(),token=self.token('buyer'))[0],404)

    def test_return_url_and_unpaid_webhook_never_grant_access(self):
        self.prepare();self.assertEqual(self.checkout()[0],200);session=next(iter(self.provider.sessions.values()))
        status,value=self.post_event(self.event('checkout.session.completed',session));self.assertEqual(status,200,value)
        self.assertFalse(self.purchase()['accessGranted']);self.assertEqual(self.file()[0],403)
        self.assertEqual(self.request('GET','commerce/purchases?checkout=returned',token=self.token('buyer'))[0],200)
        self.assertEqual(self.file()[0],403)

    def test_paid_webhook_grants_only_frozen_file(self):
        self.pay();status,file=self.file();self.assertEqual(status,200,file);self.assertEqual(set(file),{'orderId','title','html','sha256'})
        self.assertNotIn('snapshot',json.dumps(file));self.assertEqual(hashlib.sha256(file['html'].encode()).hexdigest(),file['sha256'])
        self.update({'title':'A changed later project'});self.action('build_preview')
        self.assertEqual(self.file()[1],file);self.assertEqual(self.request('GET',self.route('/export'),token=self.token('buyer'))[0],404)

    def test_async_success_after_unpaid_completion(self):
        self.prepare();self.checkout();session=next(iter(self.provider.sessions.values()))
        self.assertEqual(self.post_event(self.event('checkout.session.completed',session))[0],200);self.assertFalse(self.purchase()['accessGranted'])
        session=self.provider.settle(self.order['id']);self.assertEqual(self.post_event(self.event('checkout.session.async_payment_succeeded',session))[0],200)
        self.assertTrue(self.purchase()['accessGranted'])

    def test_raw_signature_timestamp_account_and_mode(self):
        self.prepare();self.checkout();session=self.provider.settle(self.order['id']);event=self.event('checkout.session.completed',session)
        raw=json.dumps(event).encode();stamp=str(int(time.time()));sig=hmac.new(self.config.webhook_secret.encode(),stamp.encode()+b'.'+raw,hashlib.sha256).hexdigest()
        self.assertEqual(self.request('POST','commerce/webhook',raw=raw+b' ',signature='t='+stamp+',v1='+sig)[0],400)
        self.assertEqual(self.post_event(event,offset=-400)[0],400)
        self.assertEqual(self.post_event(event,offset=400)[0],400)
        self.assertEqual(self.post_event(dict(event,livemode=True))[0],403)
        self.assertEqual(self.post_event(dict(event,account='acct_wrong'))[0],403)
        self.assertFalse(self.purchase()['accessGranted']);self.assertEqual(self.post_event(event)[0],200)

    def test_provider_amount_currency_and_metadata_must_match(self):
        self.prepare();self.checkout();session=self.provider.settle(self.order['id']);stored=self.provider.sessions[session['id']]
        for field,wrong in [('amount_total',999),('currency','eur'),('livemode',True),('metadata',dict(stored['metadata'],osgard_buyer_id='wrong'))]:
            original=stored[field];stored[field]=wrong
            self.assertEqual(self.post_event(self.event('checkout.session.completed',session))[0],409,field)
            self.assertFalse(self.purchase()['accessGranted']);stored[field]=original

    def test_webhook_replay_and_payload_conflict(self):
        self.prepare();self.checkout();session=self.provider.settle(self.order['id']);event=self.event('checkout.session.completed',session)
        self.assertEqual(self.post_event(event)[0],200);self.assertTrue(self.post_event(event)[1]['replayed'])
        self.assertEqual(self.post_event(dict(event,created=123))[0],409)
        with self.server.store.connect() as db:self.assertEqual(db.execute('SELECT COUNT(*) FROM commerce_entitlements WHERE order_id=?',(self.order['id'],)).fetchone()[0],1)

    def test_lost_checkout_result_retries_same_key_after_restart(self):
        self.prepare();self.provider.lose_checkout=True;key=uuid.uuid4().hex
        self.assertEqual(self.checkout(key)[0],503)
        self.server.store=Store(self.database,self.config,self.provider)
        status,value=self.checkout(key);self.assertEqual(status,200,value);self.assertEqual(self.provider.checkout_creates,1)
        self.assertEqual(self.checkout()[1]['url'],value['url']);self.assertEqual(self.provider.checkout_creates,1)
        self.assertEqual(self.write('commerce/orders/'+self.order['id']+'/checkout',{'different':True},'buyer',key)[0],409)

    def test_old_unknown_checkout_is_never_recreated(self):
        self.prepare();self.provider.lose_checkout=True;self.assertEqual(self.checkout()[0],503)
        with self.server.store.transaction() as db:db.execute('UPDATE commerce_checkout_ops SET started_at=? WHERE order_id=?',(time.time()-RETRY_WINDOW-5,self.order['id']))
        status,value=self.checkout();self.assertEqual((status,value['error']),(409,'reconciliation_required'));self.assertEqual(self.provider.checkout_creates,1)

    def test_concurrent_checkout_creates_one_provider_session(self):
        self.prepare()
        with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:self.checkout(),range(2)))
        self.assertTrue(any(result[0]==200 for result in results),results);self.assertTrue(all(result[0] in (200,409) for result in results),results)
        self.assertEqual(self.provider.checkout_creates,1)

    def test_partial_full_refund_and_late_paid_event(self):
        session=self.pay();self.assertEqual(self.refund(300)[0],200)
        self.assertEqual(self.purchase()['refundedMinor'],0)
        refund=next(iter(self.provider.refunds.values()));self.assertEqual(self.post_event(self.event('refund.updated',refund))[0],200)
        self.assertEqual(self.purchase()['refundedMinor'],300);self.assertTrue(self.purchase()['accessGranted'])
        self.assertEqual(self.refund(1000)[0],200);latest=list(self.provider.refunds.values())[-1]
        self.assertEqual(latest['amount'],700);self.assertEqual(self.post_event(self.event('charge.refunded',self.provider.charges[latest['charge']]))[0],200)
        self.assertEqual(self.purchase()['refundedMinor'],1000);self.assertFalse(self.purchase()['accessGranted']);self.assertEqual(self.file()[0],403)
        self.assertEqual(self.post_event(self.event('checkout.session.completed',session))[0],200);self.assertFalse(self.purchase()['accessGranted'])

    def test_full_refund_before_paid_webhook_never_grants_access(self):
        self.prepare();self.checkout();session=self.provider.settle(self.order['id']);intent=self.provider.intents[session['payment_intent']]
        refund=self.provider.create_refund(dict(payment_intent=intent['id'],amount=1000),uuid.uuid4().hex)
        self.assertEqual(self.post_event(self.event('charge.refunded',self.provider.charges[refund['charge']]))[0],200)
        self.assertFalse(self.purchase()['checkoutConfirmed']);self.assertEqual(self.file()[0],403)
        self.assertEqual(self.post_event(self.event('checkout.session.completed',session))[0],200);self.assertFalse(self.purchase()['accessGranted'])

    def test_lost_refund_result_does_not_duplicate_money_action(self):
        self.pay();self.provider.lose_refund=True;key=uuid.uuid4().hex
        self.assertEqual(self.refund(400,key)[0],503);self.assertEqual(self.refund(400,key)[0],200);self.assertEqual(self.provider.refund_creates,1)
        self.assertEqual(self.refund(500)[0],409)
        refund=next(iter(self.provider.refunds.values()));self.post_event(self.event('refund.updated',refund));self.assertEqual(self.purchase()['refundedMinor'],400)

    def test_pending_and_failed_refunds_are_not_counted(self):
        self.pay();self.refund(300);refund=next(iter(self.provider.refunds.values()));refund['status']='pending'
        self.post_event(self.event('refund.created',refund));self.assertEqual(self.purchase()['refundedMinor'],0);self.assertTrue(self.purchase()['accessGranted'])
        refund['status']='failed';self.assertEqual(self.post_event(self.event('refund.failed',refund))[0],200)
        self.assertEqual(self.purchase()['refundState'],'failed');self.assertEqual(self.refund(300)[0],409)

    def test_external_refund_must_reconcile_before_new_refund(self):
        session=self.pay();refund=self.provider.create_refund(dict(payment_intent=session['payment_intent'],amount=200),uuid.uuid4().hex)
        status,value=self.refund(500);self.assertEqual((status,value['error']),(409,'refund_reconciliation'));self.assertEqual(self.provider.refund_creates,1)
        self.post_event(self.event('refund.updated',refund));self.assertEqual(self.refund(500)[0],200)
        self.assertEqual(list(self.provider.refunds.values())[-1]['amount'],300)

    def test_refund_and_download_authorization(self):
        self.pay()
        self.assertEqual(self.write('commerce/orders/'+self.order['id']+'/refund',{'targetRefundMinor':100},'buyer')[0],404)
        self.assertEqual(self.write('commerce/orders/'+self.order['id']+'/checkout',{},'stranger')[0],404)
        self.assertEqual(self.file('merchant')[0],404);self.assertEqual(self.file('stranger')[0],404)
        self.assertEqual(self.refund(1001)[0],400)

    def test_bound_draft_cannot_be_cancelled_as_if_stripe_were_cancelled(self):
        self.prepare();status,value=self.write(self.route('/actions'),dict(expectedVersion=self.project['version'],kind='cancel_order',payload={'orderId':self.draft_id}))
        self.assertEqual((status,value['error']),(409,'commerce_order_bound'))

    def test_tampered_paid_envelope_blocks_download(self):
        self.pay()
        with self.server.store.transaction() as db:
            row=db.execute('SELECT envelope FROM commerce_orders WHERE id=?',(self.order['id'],)).fetchone();data=json.loads(row['envelope']);data['html']='changed bytes'
            db.execute('UPDATE commerce_orders SET envelope=? WHERE id=?',(json.dumps(data),self.order['id']))
        self.assertEqual(self.file()[0],409)

    def test_disabling_new_payments_preserves_existing_paid_access(self):
        self.pay();self.server.store.commerce.config=replace(self.config,enabled=False)
        self.assertEqual(self.file()[0],200);self.assertTrue(self.purchase()['accessGranted'])

    def test_late_checkout_response_does_not_reopen_expired_order(self):
        self.prepare();original=self.provider.create_checkout
        def delayed(params,key):
            result=original(params,key)
            self.assertEqual(self.post_event(self.event('checkout.session.expired',result))[0],200)
            self.assertEqual(self.purchase()['status'],'expired')
            return result
        self.provider.create_checkout=delayed
        status,result=self.checkout();self.assertEqual(status,200,result)
        self.assertTrue(result['closed']);self.assertIsNone(result['url']);self.assertEqual(self.purchase()['status'],'expired')
        self.assertEqual(self.checkout()[0],409);self.assertEqual(self.provider.checkout_creates,1)

    def test_webhook_before_lost_checkout_response_has_explicit_pending_state(self):
        self.prepare();self.provider.lose_checkout=True;self.assertEqual(self.checkout()[0],503)
        session=next(iter(self.provider.sessions.values()))
        self.assertEqual(self.post_event(self.event('checkout.session.completed',session))[0],200)
        status,result=self.checkout();self.assertEqual(status,200,result)
        self.assertTrue(result['pending']);self.assertIsNone(result['url']);self.assertEqual(result['status'],'payment_processing')
        self.assertEqual(self.provider.checkout_creates,1);self.assertFalse(self.purchase()['accessGranted'])

    def test_late_unpaid_event_does_not_reopen_failed_order(self):
        self.prepare();self.checkout();session=next(iter(self.provider.sessions.values()))
        self.assertEqual(self.post_event(self.event('checkout.session.async_payment_failed',session))[0],200)
        self.assertEqual(self.post_event(self.event('checkout.session.completed',session))[0],200)
        self.assertEqual(self.purchase()['status'],'failed');self.assertEqual(self.checkout()[0],409)

    def test_failed_refund_before_create_response_is_bound_by_metadata(self):
        self.pay();original=self.provider.create_refund
        def delayed(params,key):
            result=original(params,key);self.provider.refunds[result['id']]['status']='failed';result['status']='failed'
            self.assertEqual(self.post_event(self.event('refund.failed',result))[0],200)
            self.assertEqual(self.purchase()['refundState'],'failed')
            return result
        self.provider.create_refund=delayed
        status,result=self.refund(400);self.assertEqual(status,200,result);self.assertTrue(result['failed'])
        self.assertEqual(self.refund(400)[0],409);self.assertEqual(self.provider.refund_creates,1)
        self.assertEqual(self.purchase()['refundedMinor'],0);self.assertTrue(self.purchase()['accessGranted'])

    def test_failed_refund_with_lost_create_response_still_requires_reconciliation(self):
        self.pay();original=self.provider.create_refund
        def lost(params,key):
            result=original(params,key);self.provider.refunds[result['id']]['status']='failed';result['status']='failed'
            self.assertEqual(self.post_event(self.event('refund.failed',result))[0],200)
            raise TimeoutError('synthetic lost response after failed webhook')
        self.provider.create_refund=lost
        self.assertEqual(self.refund(400)[0],503);self.assertEqual(self.purchase()['refundState'],'failed')
        self.assertEqual(self.refund(400)[0],409);self.assertEqual(self.provider.refund_creates,1)


if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(CommerceTests))
    report=dict(status='passed' if result.wasSuccessful() else 'failed',testsRun=result.testsRun,failures=len(result.failures),errors=len(result.errors),generatedAt=datetime.now(timezone.utc).isoformat(),scope='Local HTTP/SQLite with injected FakeProvider; signature, isolation, idempotency, failed/partial/full refunds, immutable access and recovery',stripeNetworkCalled=False,realPaymentsTested=False,productionActivation=False)
    (ROOT/'docs/CORE-COMMERCE-TESTS.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');sys.exit(0 if result.wasSuccessful() else 1)
