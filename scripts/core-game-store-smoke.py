#!/usr/bin/env python3
"""Real HTTP and SQLite, fake Stripe provider. NEVER makes a live charge."""
from http.client import HTTPConnection
from pathlib import Path
from tempfile import TemporaryDirectory
import copy
import hashlib
import hmac
import json
import sys
import threading
import time
import unittest
import uuid

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'server'))
from core_server import create_server
from core_game_store import Config, CATALOG, GameStore
from core_commerce import API_VERSION

class FakeStripe:
    def __init__(self):
        self.calls=0
        self.keys={}
        self.sessions={}
        self.intents={}
        self.charges={}
        self.lose=False

    def create_checkout(self,params,key):
        if key not in self.keys:
            self.calls+=1
            sid='cs_test_'+uuid.uuid4().hex
            price=params['line_items'][0]['price_data']
            record=dict(id=sid,livemode=False,mode='payment',
                metadata=copy.deepcopy(params['metadata']),
                client_reference_id=params['client_reference_id'],
                amount_total=price['unit_amount'],currency=price['currency'],
                payment_status='unpaid',status='open',payment_intent=None,
                url='https://checkout.stripe.com/c/pay/'+sid)
            self.sessions[sid]=record;self.keys[key]=sid
            if self.lose:
                self.lose=False
                raise TimeoutError('lost response')
        return copy.deepcopy(self.sessions[self.keys[key]])

    def retrieve_session(self,sid):return copy.deepcopy(self.sessions[sid])
    def retrieve_intent(self,pi):return copy.deepcopy(self.intents[pi])
    def retrieve_charge(self,ch):return copy.deepcopy(self.charges[ch])

    def settle(self,order_id):
        record=next(x for x in self.sessions.values()
                    if x['client_reference_id']==order_id)
        pi='pi_'+uuid.uuid4().hex
        ch='ch_'+uuid.uuid4().hex
        self.intents[pi]=dict(
            id=pi,livemode=False,metadata=copy.deepcopy(record['metadata']),
            amount_received=record['amount_total'],
            status='succeeded',currency=record['currency'],latest_charge=ch)
        self.charges[ch]=dict(
            id=ch,livemode=False,payment_intent=pi,
            amount=record['amount_total'],currency=record['currency'],
            paid=True,amount_refunded=0)
        record.update(status='complete',payment_status='paid',payment_intent=pi)
        return copy.deepcopy(record)

    def refund(self,session,fraction=1):
        ch=self.intents[session['payment_intent']]['latest_charge']
        charge=self.charges[ch]
        charge['amount_refunded']=int(charge['amount']*fraction)
        return dict(id=ch,object='charge')

class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp=TemporaryDirectory()
        root=Path(cls.temp.name)/'public'
        root.mkdir()
        (root/'index.html').write_text('<title>test</title>')
        cls.provider=FakeStripe()
        cls.config=Config(True,'acct_game_test',False,'https://osgard.example',
                          'sk_test_fixture_local_only','whsec_game_fixture_secret')
        cls.http=create_server(root,Path(cls.temp.name)/'private/core.db',
            port=0,game_config=cls.config,game_provider=cls.provider)
        cls.port=cls.http.server_address[1]
        cls.thread=threading.Thread(target=cls.http.serve_forever,daemon=True)
        cls.thread.start()
        cls.users={}
        for name in ('buyer','stranger','friend'):
            status,body=cls.request('POST','auth/register',dict(
                username='z40-'+name,password='Long local fixture password 2026'))
            assert status==200,body
            cls.users[name]=body

    @classmethod
    def tearDownClass(cls):
        cls.http.shutdown();cls.http.server_close()
        cls.thread.join(3);cls.temp.cleanup()

    @classmethod
    def request(cls,method,route,body=None,person=None,raw=None,signature=None):
        c=HTTPConnection('127.0.0.1',cls.port,timeout=12)
        headers={'Content-Type':'application/json'}
        if person:
            headers['Authorization']='Bearer '+cls.users[person]['token']
        if signature:headers['Stripe-Signature']=signature
        data=raw if raw is not None else json.dumps(body) if body is not None else None
        c.request(method,'/api/core/'+route,data,headers)
        response=c.getresponse()
        value=response.status,json.loads(response.read())
        c.close()
        return value

    @classmethod
    def event(cls,kind,obj,changes=None):
        result=dict(id='evt_'+uuid.uuid4().hex,object='event',type=kind,
            api_version=API_VERSION,livemode=False,data=dict(object=obj))
        if changes:result.update(changes)
        return result

    @classmethod
    def webhook(cls,event,signature_override=None):
        data=json.dumps(event,sort_keys=True,separators=(',',':')).encode()
        stamp=str(int(time.time()))
        sig=hmac.new(cls.config.webhook_secret.encode(),
            stamp.encode()+b'.'+data,hashlib.sha256).hexdigest()
        return cls.request('POST','game/webhook',raw=data,
            signature=signature_override or 't='+stamp+',v1='+sig)

    @classmethod
    def get_owned(cls,user='buyer'):
        code,data=cls.request('GET','game/inventory',person=user)
        assert code==200,data
        return set(data['owned'])

    @classmethod
    def buy(cls,sku,person='buyer'):
        return cls.request('POST','game/checkout',dict(sku=sku),person=person)

    def test_01_catalog_public_and_server_only_prices(self):
        code,view=self.request('GET','game/store')
        self.assertEqual(code,200,view)
        self.assertTrue(view['enabled']);self.assertEqual(view['mode'],'test')
        self.assertEqual(len(view['products']),len(CATALOG))
        self.assertFalse(any('secret' in str(k).lower()
          for k in view))
        self.assertEqual(view['products'][0]['amountMinor'],
                         CATALOG[view['products'][0]['sku']]['amountMinor'])
        self.assertEqual(self.request('GET','game/inventory')[0],401)
        self.assertEqual(self.buy('car_onyx',person=None)[0],401)

    def test_02_price_and_sku_tampering_rejected(self):
        self.assertEqual(self.request('POST','game/checkout',dict(
            sku='car_onyx',amountMinor=1,currency='EUR'),person='buyer')[0],400)
        self.assertEqual(self.buy('car_unknown')[0],400)
        self.assertEqual(self.buy('__proto__')[0],400)

    def test_03_deduplicated_checkout_unpaid_never_grants(self):
        before=self.provider.calls
        code,item=self.buy('car_onyx')
        self.assertEqual(code,200,item)
        code,repeat=self.buy('car_onyx')
        self.assertEqual(code,200,repeat)
        self.assertTrue(repeat['reused'])
        self.assertEqual(item['url'],repeat['url'])
        self.assertEqual(self.provider.calls,before+1)
        self.assertNotIn('car_onyx',self.get_owned())
        session=next(x for x in self.provider.sessions.values()
                     if x['client_reference_id']==item['orderId'])
        code,result=self.webhook(self.event('checkout.session.completed',session))
        self.assertEqual(code,200,result)
        self.assertNotIn('car_onyx',self.get_owned())
        self.assertEqual(self.request('GET',
            'game/inventory?checkout=returned',person='buyer')[0],200)
        self.assertNotIn('car_onyx',self.get_owned())
        self.assertEqual(self.get_owned('stranger'),set())

    def test_04_stripe_paid_replay_and_refund_revocation(self):
        code,item=self.buy('suit_copper')
        self.assertEqual(code,200,item)
        session=self.provider.settle(item['orderId'])
        event=self.event('checkout.session.completed',session)
        self.assertEqual(self.webhook(event)[0],200)
        self.assertIn('suit_copper',self.get_owned())
        self.assertNotIn('suit_copper',self.get_owned('stranger'))
        code,result=self.webhook(event)
        self.assertEqual(code,200,result)
        self.assertTrue(result['replayed'])
        self.assertTrue(self.buy('suit_copper')[1]['alreadyOwned'])
        refund=self.provider.refund(session)
        code,result=self.webhook(self.event('charge.refunded',refund))
        self.assertEqual(code,200,result)
        self.assertNotIn('suit_copper',self.get_owned())

    def test_05_bundle_grants_cosmetics_without_gameplay_items(self):
        code,item=self.buy('founder_pack',person='friend')
        self.assertEqual(code,200,item)
        paid=self.provider.settle(item['orderId'])
        self.assertEqual(self.webhook(
          self.event('checkout.session.completed',paid))[0],200)
        own=self.get_owned('friend')
        self.assertEqual(own,
            {'founder_pack','car_onyx','car_aurora',
             'suit_copper','city_afterglow'})
        self.assertNotIn('founder_pack',self.get_owned('stranger'))
        self.provider.refund(paid)
        ch=self.provider.intents[paid['payment_intent']]['latest_charge']
        self.assertEqual(self.webhook(
            self.event('charge.refunded',dict(id=ch)))[0],200)
        self.assertNotIn('founder_pack',self.get_owned('friend'))
        self.assertNotIn('car_aurora',self.get_owned('friend'))

    def test_06_forged_signature_and_metadata_never_unlock(self):
        code,item=self.buy('city_afterglow',person='stranger')
        self.assertEqual(code,200,item)
        session=self.provider.settle(item['orderId'])
        event=self.event('checkout.session.completed',session)
        self.assertIn(self.webhook(event,signature_override='t=1,v1='+'0'*64)[0],
                      (400,403))
        self.assertNotIn('city_afterglow',self.get_owned('stranger'))
        sid=session['id']
        self.provider.sessions[sid]['metadata']['zion_sku']='car_onyx'
        self.assertEqual(self.webhook(event)[0],409)
        self.assertNotIn('city_afterglow',self.get_owned('stranger'))
        self.provider.sessions[sid]['metadata']['zion_sku']='city_afterglow'
        self.assertEqual(self.webhook(event)[0],200)
        self.assertIn('city_afterglow',self.get_owned('stranger'))

    def test_07_disabled_blocks_payment_but_preserves_inventory(self):
        game=self.http.store.game_store
        old=game.config
        try:
            game.config=Config(False,old.account_id,old.livemode,old.public_origin)
            self.assertEqual(self.request('GET','game/store')[1]['enabled'],False)
            self.assertEqual(self.buy('car_aurora')[0],503)
            self.assertEqual(self.request('GET','game/inventory',person='buyer')[0],200)
        finally:game.config=old

    def test_08_lost_result_safe_idempotency_key(self):
        self.provider.lose=True
        before=self.provider.calls
        self.assertEqual(self.buy('car_aurora')[0],503)
        self.assertEqual(self.provider.calls,before+1)
        code,result=self.buy('car_aurora')
        self.assertEqual(code,200,result)
        self.assertEqual(self.provider.calls,before+1)
        self.assertNotIn('car_aurora',self.get_owned())

if __name__=='__main__':
    unittest.main(verbosity=2)
