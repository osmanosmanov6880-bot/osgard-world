"""NEBULA Stripe contract tests. Fake provider; NEVER makes real charges."""
import hashlib
import hmac
import http.client
import json
import pathlib
import sys
import tempfile
import threading
import time
import unittest
import uuid
from unittest.mock import patch

ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"server"))
from core_server import Store,create_server
from core_model import Fault
from nebula_payments import Payments,Config,CATALOG,API_VERSION


class FakeStripe:
    def __init__(self):
        self.sessions={}
        self.intents={}
        self.charges={}
        self.calls=0

    def create_checkout(self,params,key):
        self.calls+=1
        rid=params["client_reference_id"]
        sid="cs_fake_"+rid
        intent_id="pi_fake_"+rid
        charge_id="ch_fake_"+rid
        amount=params["line_items"][0]["price_data"]["unit_amount"]
        meta=params["metadata"].copy()
        self.sessions[sid]={
            "id":sid,"livemode":False,"status":"open","payment_status":"unpaid",
            "mode":"payment","client_reference_id":rid,"metadata":meta,
            "currency":"gbp","amount_total":amount,"payment_intent":intent_id,
            "url":"https://checkout.stripe.com/c/pay/test_"+rid}
        self.intents[intent_id]={
            "id":intent_id,"livemode":False,"status":"succeeded",
            "currency":"gbp","amount_received":amount,"metadata":meta,
            "latest_charge":charge_id}
        self.charges[charge_id]={
            "id":charge_id,"payment_intent":intent_id,"livemode":False,
            "paid":True,"captured":True,"currency":"gbp",
            "amount":amount,"amount_refunded":0,"disputed":False}
        return self.sessions[sid]

    def retrieve_session(self,sid):return self.sessions[sid]
    def retrieve_intent(self,iid):return self.intents[iid]
    def retrieve_charge(self,cid):return self.charges[cid]


class NebulaPaymentsTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root=pathlib.Path(self.temp.name)
        self.root.joinpath("web").mkdir()
        self.root.joinpath("web","index.html").write_text("test")
        self.fake=FakeStripe()
        self.config=Config(True,"acct_MAGA_TEST",False,
                           "https://osgard.world","rk_test_fakefakefakefake",
                           "whsec_nebula_test_secret")
        self.db=self.root/"db.sqlite3"
        self.store=Store(self.db,nebula_config=self.config,nebula_provider=self.fake)
        self.pay=self.store.nebula
        self.actor=self.store.auth("register",{"username":"testpilot","password":"long-secret-password-2026"})
        self.user=self.actor["user"]["id"]
        self.seq=0

    def key(self):
        return "req_"+uuid.uuid4().hex

    def checkout(self,sku="ship_interceptor"):
        return self.pay.checkout(self.user,sku,self.key())

    def event(self,sid,event_type="checkout.session.completed",paid=True,
              webhook_id=None,malformed=False):
        self.seq+=1
        self.fake.sessions[sid]["payment_status"]="paid" if paid else "unpaid"
        self.fake.sessions[sid]["status"]="complete" if paid else "open"
        event={"id":webhook_id or "evt_nebula_"+str(self.seq),
               "object":"event","api_version":API_VERSION,
               "livemode":False,"account":self.config.account_id,
               "type":event_type,"data":{"object":{"id":sid}}}
        raw=json.dumps(event).encode()
        stamp=int(time.time())
        digest=hmac.new(self.config.webhook_secret.encode(),
                        f"{stamp}.".encode()+raw,hashlib.sha256).hexdigest()
        header=f"t={stamp},v1="+("0"*64 if malformed else digest)
        return self.pay.webhook(raw,header)

    def test_disabled_by_default(self):
        with patch.dict("os.environ",{"OSGARD_NEBULA_PAYMENTS_ENABLED":"0"}):
            self.assertFalse(Config.from_env().enabled)
        other=Payments(self.store,Config())
        with self.assertRaises(Fault):
            other.checkout(self.user,"ship_interceptor",self.key())
        self.assertTrue(len(other.catalog()["items"]) >= 6)

    def test_server_prices_and_idempotent_checkout(self):
        key=self.key()
        first=self.pay.checkout(self.user,"ship_interceptor",key)
        again=self.pay.checkout(self.user,"ship_interceptor",key)
        self.assertEqual(first["orderId"],again["orderId"])
        self.assertEqual(self.fake.calls,1)
        self.assertEqual(self.fake.sessions[next(iter(self.fake.sessions))]["amount_total"],
                         CATALOG["ship_interceptor"][2])
        self.assertEqual(self.pay.inventory(self.user)["items"],{})
        with self.assertRaises(Fault):
            self.pay.checkout(self.user,"ship_guardian",key)
        with self.assertRaises(Fault):
            self.pay.checkout(self.user,"ship_interceptor",self.key())

    def test_unpaid_completed_and_invalid_signature_never_grant(self):
        result=self.checkout()
        sid="cs_fake_"+result["orderId"]
        with self.assertRaises(Fault):
            self.event(sid,malformed=True)
        self.assertEqual(self.pay.inventory(self.user)["items"],{})
        self.event(sid,paid=False)
        self.assertEqual(self.pay.inventory(self.user)["items"],{})
        self.event(sid,paid=True)
        self.assertEqual(self.pay.inventory(self.user)["items"]["ship_interceptor"],1)
        self.assertEqual(self.pay.inventory(self.user)["orders"][0]["state"],"paid")

    def test_paid_webhook_replay_and_duplicate_event_grant_once(self):
        result=self.checkout("weapon_plasma")
        sid="cs_fake_"+result["orderId"]
        self.event(sid,paid=True,webhook_id="evt_same_100")
        same=self.event(sid,paid=True,webhook_id="evt_same_100")
        self.assertTrue(same["replayed"])
        self.event(sid,paid=True,webhook_id="evt_another_event")
        self.assertEqual(self.pay.inventory(self.user)["items"]["weapon_plasma"],1)
        with self.assertRaises(Fault):
            self.pay.checkout(self.user,"weapon_plasma",self.key())

    def test_refunds_and_disputes_revoke_rights(self):
        order=self.checkout("ship_guardian")
        sid="cs_fake_"+order["orderId"]
        self.event(sid)
        charge=self.fake.charges["ch_fake_"+order["orderId"]]
        charge["amount_refunded"]=CATALOG["ship_guardian"][2]
        self.seq+=1
        evt={"id":"evt_refund_"+str(self.seq),"object":"event",
             "api_version":API_VERSION,"livemode":False,
             "account":self.config.account_id,"type":"charge.refunded",
             "data":{"object":{"id":charge["id"]}}}
        raw=json.dumps(evt).encode()
        t=int(time.time())
        digest=hmac.new(self.config.webhook_secret.encode(),
                        f"{t}.".encode()+raw,hashlib.sha256).hexdigest()
        self.pay.webhook(raw,f"t={t},v1={digest}")
        self.assertNotIn("ship_guardian",self.pay.inventory(self.user)["items"])
        self.event(sid,paid=True)
        self.assertNotIn("ship_guardian",self.pay.inventory(self.user)["items"])

    def test_paid_missiles_consumed_once_per_key(self):
        order=self.checkout("missiles_6")
        sid="cs_fake_"+order["orderId"]
        self.event(sid)
        self.assertEqual(self.pay.inventory(self.user)["items"]["missiles_6"],6)
        key=self.key()
        one=self.pay.consume_missile(self.user,key)
        two=self.pay.consume_missile(self.user,key)
        self.assertFalse(one["replayed"])
        self.assertTrue(two["replayed"])
        self.assertEqual(self.pay.inventory(self.user)["items"]["missiles_6"],5)
        for _ in range(5):
            self.pay.consume_missile(self.user,self.key())
        with self.assertRaises(Fault):
            self.pay.consume_missile(self.user,self.key())

    def test_payment_amount_tampering_rejected(self):
        result=self.checkout()
        sid="cs_fake_"+result["orderId"]
        self.fake.sessions[sid]["amount_total"]=1
        with self.assertRaises(Fault):
            self.event(sid)
        self.assertEqual(self.pay.inventory(self.user)["items"],{})

    def test_http_routes_enforce_auth_and_allow_no_public_fulfillment(self):
        server=create_server(self.root/"web",self.db,port=0,
                             nebula_config=self.config,nebula_provider=self.fake)
        thread=threading.Thread(target=server.serve_forever,daemon=True)
        thread.start()
        self.addCleanup(lambda: (server.shutdown(),server.server_close(),thread.join(timeout=2)))
        port=server.server_address[1]
        conn=http.client.HTTPConnection("127.0.0.1",port,timeout=5)
        conn.request("GET","/api/core/nebula/catalog",
                     headers={"Host":f"127.0.0.1:{port}"})
        response=conn.getresponse()
        self.assertEqual(response.status,200)
        self.assertTrue(json.loads(response.read())["enabled"])
        conn.request("GET","/api/core/nebula/inventory",
                     headers={"Host":f"127.0.0.1:{port}"})
        response=conn.getresponse()
        self.assertEqual(response.status,401)
        response.read()
        conn.request("GET","/api/core/nebula/inventory",headers={
            "Host":f"127.0.0.1:{port}","Authorization":"Bearer "+self.actor["token"]})
        response=conn.getresponse()
        self.assertEqual(response.status,200)
        self.assertEqual(json.loads(response.read())["items"],{})
        conn.close()


if __name__ == "__main__":
    unittest.main()
