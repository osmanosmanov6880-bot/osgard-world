#!/usr/bin/env python3
"""No network/no real charges: game shop webhook and entitlement security checks."""
import os,sys,time,json,hmac,hashlib,sqlite3,tempfile,contextlib,unittest
from unittest.mock import patch
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'server'))
from core_game_store import Shop,SCHEMA,ITEMS,catalog
from core_model import Fault
class FakeProvider:
 def __init__(self):self.sessions={};self.calls=0
 def create_checkout(self,params,key):
  self.calls+=1
  sid='cs_test_'+str(self.calls)
  item=params['line_items'][0]['price_data']
  self.sessions[sid]={'id':sid,'url':'https://checkout.stripe.test/session/'+sid,
                      'status':'open','payment_status':'unpaid','livemode':False,
                      'client_reference_id':params['client_reference_id'],
                      'metadata':params['metadata'],'currency':item['currency'],
                      'amount_total':item['unit_amount'],'payment_intent':'pi_test_123'}
  return self.sessions[sid]
 def retrieve_session(self,sid):return self.sessions[sid]
class FakeCommerce:
 def __init__(self):
  self.config=type('Config',(),dict(enabled=True,livemode=False,account_id='acct_test_123',webhook_secret='whsec_testing_secret_for_webhooks',
    public_origin='https://example.test'))()
  self.fake=FakeProvider()
 def enabled(self):pass
 def provider(self):return self.fake
class FakeStore:
 def __init__(self):
  self.temp=tempfile.TemporaryDirectory()
  self.path=os.path.join(self.temp.name,'db.sqlite')
  self.commerce=FakeCommerce()
  with self.connect() as db:db.executescript('CREATE TABLE users(id TEXT PRIMARY KEY); INSERT INTO users(id) VALUES ("buyer1");'+SCHEMA)
 @contextlib.contextmanager
 def connect(self):
  db=sqlite3.connect(self.path);db.row_factory=sqlite3.Row
  db.execute('PRAGMA foreign_keys=ON')
  try:yield db
  finally:db.close()
 @contextlib.contextmanager
 def transaction(self):
  with self.connect() as db:
   db.execute('BEGIN IMMEDIATE')
   try:yield db;db.commit()
   except BaseException:db.rollback();raise
class StoreTests(unittest.TestCase):
 def setUp(self):
  self.env=patch.dict(os.environ,{"OSGARD_GAME_SHOP_ENABLED":"1","OSGARD_GAME_SHOP_WEBHOOK_SECRET":"whsec_testing_secret_for_webhooks"},clear=False)
  self.env.start();self.store=FakeStore();self.shop=Shop(self.store)
 def tearDown(self):self.store.temp.cleanup();self.env.stop()
 def payload(self,id='evt_1',etype='checkout.session.completed',obj=None):
  obj=obj or {'id':'cs_test_1'}
  raw=json.dumps({'id':id,'type':etype,'livemode':False,'data':{'object':obj}}).encode()
  stamp=str(int(time.time()))
  sig=hmac.new(self.store.commerce.config.webhook_secret.encode(),stamp.encode()+b'.'+raw,hashlib.sha256).hexdigest()
  return raw,'t='+stamp+',v1='+sig
 def test_catalog_and_price_not_client_controlled(self):
  self.assertEqual(len(catalog()['items']),8)
  self.shop.checkout('buyer1',{'sku':'scout','amountMinor':1,'currency':'xyz'})
  self.assertEqual(self.store.commerce.fake.sessions['cs_test_1']['amount_total'],499)
 def test_webhook_only_grant_and_replay_and_refund(self):
  self.shop.checkout('buyer1',{'sku':'titan'})
  self.assertEqual(self.shop.owned('buyer1')['owned'],[])
  body,sig=self.payload()
  with self.assertRaises(Fault):self.shop.webhook(body,sig)
  self.assertEqual(self.shop.owned('buyer1')['owned'],[])
  session=self.store.commerce.fake.sessions['cs_test_1'];session['payment_status']='paid';session['status']='complete'
  bad,sbad=self.payload('evt_tampered')
  session['amount_total']=1
  with self.assertRaises(Fault):self.shop.webhook(bad,sbad)
  session['amount_total']=1499
  result=self.shop.webhook(body,sig)
  self.assertTrue(result['handled'])
  self.assertEqual(self.shop.owned('buyer1')['owned'],['titan'])
  self.assertTrue(self.shop.webhook(body,sig)['duplicate'])
  refund,sref=self.payload('evt_refund','charge.refunded',{'payment_intent':'pi_test_123'})
  self.shop.webhook(refund,sref)
  self.assertEqual(self.shop.owned('buyer1')['owned'],[])
 def test_signature_required(self):
  self.shop.checkout('buyer1',{'sku':'iris'})
  body,sig=self.payload()
  with self.assertRaises(Fault):self.shop.webhook(body,'t=1,v1=bad')
 def test_duplicate_clicks_share_session(self):
  a=self.shop.checkout('buyer1',{'sku':'phoenix'})
  b=self.shop.checkout('buyer1',{'sku':'phoenix'})
  self.assertEqual(a['checkoutUrl'],b['checkoutUrl'])
  self.assertEqual(self.store.commerce.fake.calls,1)
 def test_shop_is_disabled_without_separate_flag(self):
  os.environ.pop("OSGARD_GAME_SHOP_ENABLED")
  self.assertFalse(self.shop.status()["enabled"])
  with self.assertRaises(Fault):self.shop.checkout('buyer1',{'sku':'scout'})
 def test_live_requires_explicit_account_authorization(self):
  self.store.commerce.config.livemode=True
  self.assertFalse(self.shop.status()["realPaymentsEnabled"])
  with self.assertRaises(Fault):self.shop.checkout('buyer1',{'sku':'scout'})
  os.environ["OSGARD_GAME_SHOP_LIVE_APPROVED"]="1"
  os.environ["OSGARD_GAME_SHOP_EXPECTED_ACCOUNT_ID"]="acct_wrong"
  with self.assertRaises(Fault):self.shop.checkout('buyer1',{'sku':'scout'})
 def test_paid_session_prevents_duplicate_charge_before_webhook(self):
  self.shop.checkout('buyer1',{'sku':'plasma'})
  session=self.store.commerce.fake.sessions['cs_test_1'];session['status']='complete';session['payment_status']='paid'
  with self.assertRaises(Fault):self.shop.checkout('buyer1',{'sku':'plasma'})
  self.assertEqual(self.store.commerce.fake.calls,1)
 def test_revocation_before_confirmation_does_not_reissue(self):
  self.shop.checkout('buyer1',{'sku':'titan'})
  session=self.store.commerce.fake.sessions['cs_test_1'];session['payment_status']='paid';session['status']='complete'
  charge,sig=self.payload('evt_before_refund','charge.refunded',{'payment_intent':'pi_test_123'})
  self.shop.webhook(charge,sig)
  completed,signature=self.payload('evt_late_checkout')
  result=self.shop.webhook(completed,signature)
  self.assertTrue(result['revoked'])
  self.assertEqual(self.shop.owned('buyer1')['owned'],[])
 def test_distinct_game_webhook_secret_required(self):
  self.shop.checkout('buyer1',{'sku':'iris'})
  body,sig=self.payload()
  os.environ.pop('OSGARD_GAME_SHOP_WEBHOOK_SECRET')
  with self.assertRaises(Fault):self.shop.webhook(body,sig)
 def test_invalid_event_shape_rejected(self):
  self.shop.checkout('buyer1',{'sku':'iris'})
  raw=json.dumps({'id':'evt_malformed','type':'checkout.session.completed','livemode':False,'data':None}).encode()
  stamp=str(int(time.time()))
  sig=hmac.new(self.store.commerce.config.webhook_secret.encode(),stamp.encode()+b'.'+raw,hashlib.sha256).hexdigest()
  with self.assertRaises(Fault):self.shop.webhook(raw,'t='+stamp+',v1='+sig)
 def test_unknown_product_rejected(self):
  with self.assertRaises(Fault):self.shop.checkout('buyer1',{'sku':'free-money'})
if __name__=='__main__':unittest.main()
