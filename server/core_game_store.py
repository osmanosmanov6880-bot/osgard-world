"""OSGARD digital items: signed Stripe webhook is the only entitlement authority."""
import time
from core_model import require, uid
from core_commerce import verify_webhook

ITEMS={
 "scout":("Корабль «Разведчик»",499,"ship","fleet"),
 "titan":("Корабль «Титан»",1499,"ship","fleet"),
 "plasma":("Плазменная пушка",699,"weapon","fleet"),
 "phoenix":("Ракета «Феникс»",399,"rocket","fleet"),
 "iris":("Помощник IRIS",599,"helper","fleet"),
 "chrono_founder":("CHRONOS — набор основателя",999,"cosmetic","time-empire"),
 "chrono_neon":("CHRONOS — неоновый город",499,"cosmetic","time-empire"),
 "copper_core":("BLACKFIELD — медное ядро",399,"cosmetic","vector-zero")
}
SCHEMA="""
CREATE TABLE IF NOT EXISTS game_shop_orders(
 id TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES users(id),sku TEXT NOT NULL,
 amount_minor INTEGER NOT NULL,currency TEXT NOT NULL,
 session_id TEXT UNIQUE,payment_intent TEXT UNIQUE,state TEXT NOT NULL,
 created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS game_shop_entitlements(
 user_id TEXT NOT NULL REFERENCES users(id),sku TEXT NOT NULL,
 order_id TEXT NOT NULL REFERENCES game_shop_orders(id),revoked_at INTEGER,
 PRIMARY KEY(user_id,sku));
CREATE TABLE IF NOT EXISTS game_shop_webhook_events(id TEXT PRIMARY KEY);
CREATE INDEX IF NOT EXISTS game_shop_orders_user ON game_shop_orders(user_id);
"""

def catalog():
 return {"currency":"EUR","items":[dict(sku=k,name=v[0],amountMinor=v[1],kind=v[2],game=v[3])
                                for k,v in ITEMS.items()]}

class Shop:
 def __init__(self,store):self.store=store
 def status(self):
  c=self.store.commerce.config
  return dict(enabled=c.enabled,mode="live" if c.livemode else "test",realPaymentsEnabled=bool(c.enabled and c.livemode))
 def owned(self,user):
  with self.store.connect() as db:
   return {"owned":[row["sku"] for row in db.execute("SELECT sku FROM game_shop_entitlements WHERE user_id=? AND revoked_at IS NULL",(user,))]}
 def checkout(self,user,payload):
  self.store.commerce.enabled()
  sku=payload.get("sku")
  require(type(sku) is str and sku in ITEMS,"Неизвестный товар.","invalid_sku",400)
  with self.store.transaction() as db:
   require(not db.execute("SELECT 1 FROM game_shop_entitlements WHERE user_id=? AND sku=? AND revoked_at IS NULL",(user,sku)).fetchone(),
           "Этот предмет уже приобретён.","already_owned",409)
   existing=db.execute("SELECT * FROM game_shop_orders WHERE user_id=? AND sku=? AND state='pending' AND session_id IS NOT NULL ORDER BY created_at DESC LIMIT 1",(user,sku)).fetchone()
  if existing:
   session=self.store.commerce.provider().retrieve_session(existing["session_id"])
   if session.get("status")=="open" and session.get("url"):
    return {"checkoutUrl":session["url"],"status":"pending"}
  order_id=uid()
  name,amount,*_=ITEMS[sku]
  with self.store.transaction() as db:
   db.execute("INSERT INTO game_shop_orders(id,user_id,sku,amount_minor,currency,state,created_at) VALUES(?,?,?,?,?,?,?)",
              (order_id,user,sku,amount,"eur","pending",int(time.time())))
  params={"mode":"payment","client_reference_id":user,
          "line_items":[{"price_data":{"currency":"eur","unit_amount":amount,
                         "product_data":{"name":name}},"quantity":1}],
          "metadata":{"osgard_game_order":order_id,"osgard_game_sku":sku},
          "success_url":self.store.commerce.config.public_origin+"/games/store/?payment=return",
          "cancel_url":self.store.commerce.config.public_origin+"/games/store/?payment=cancel"}
  session=self.store.commerce.provider().create_checkout(params,"osgard-game-"+order_id)
  require(session.get("id") and session.get("url"),"Платёжная страница недоступна.","stripe_unavailable",503)
  with self.store.transaction() as db:
   db.execute("UPDATE game_shop_orders SET session_id=? WHERE id=?",(session["id"],order_id))
  return {"checkoutUrl":session["url"],"status":"pending"}
 def webhook(self,raw,signature):
  self.store.commerce.enabled()
  event=verify_webhook(raw,signature,self.store.commerce.config.webhook_secret)
  eid=event.get("id");etype=event.get("type")
  require(type(eid) is str and len(eid)<=255,"Неверное событие.","event_invalid",400)
  if etype not in ("checkout.session.completed","checkout.session.async_payment_succeeded","charge.refunded","charge.dispute.created"):
   return {"received":True,"handled":False}
  obj=event.get("data",{}).get("object",{})
  require(isinstance(obj,dict),"Неверное событие.","event_invalid",400)
  if etype.startswith("checkout.session"):
   sid=obj.get("id")
   require(type(sid) is str and sid.startswith("cs_"),"Некорректный Checkout.","session_invalid",400)
   session=self.store.commerce.provider().retrieve_session(sid)
   require(session.get("id")==sid and session.get("payment_status")=="paid","Платёж не подтверждён.","unpaid",409)
   with self.store.transaction() as db:
    if db.execute("SELECT 1 FROM game_shop_webhook_events WHERE id=?",(eid,)).fetchone():return {"received":True,"duplicate":True}
    order=db.execute("SELECT * FROM game_shop_orders WHERE session_id=?",(sid,)).fetchone()
    require(order is not None,"Заказ не найден.","order_missing",404)
    meta=session.get("metadata") or {}
    require(meta.get("osgard_game_order")==order["id"] and meta.get("osgard_game_sku")==order["sku"] and session.get("client_reference_id")==order["user_id"],
            "Покупатель или товар не совпадают.","order_mismatch",409)
    require(session.get("currency")=="eur" and session.get("amount_total")==order["amount_minor"],
            "Неверная сумма оплаты.","amount_mismatch",409)
    require(session.get("livemode")==self.store.commerce.config.livemode,"Режим оплаты не совпадает.","mode_mismatch",409)
    intent=session.get("payment_intent")
    if isinstance(intent,dict):intent=intent.get("id")
    require(type(intent) is str and intent.startswith("pi_"),"Нет PaymentIntent.","intent_missing",409)
    db.execute("UPDATE game_shop_orders SET state='paid',payment_intent=? WHERE id=?",(intent,order["id"]))
    db.execute("""INSERT INTO game_shop_entitlements(user_id,sku,order_id,revoked_at)
                  VALUES(?,?,?,NULL)
                  ON CONFLICT(user_id,sku) DO UPDATE SET order_id=excluded.order_id,revoked_at=NULL""",
               (order["user_id"],order["sku"],order["id"]))
    db.execute("INSERT INTO game_shop_webhook_events VALUES(?)",(eid,))
  else:
   intent=obj.get("payment_intent")
   if isinstance(intent,dict):intent=intent.get("id")
   with self.store.transaction() as db:
    if db.execute("SELECT 1 FROM game_shop_webhook_events WHERE id=?",(eid,)).fetchone():return {"received":True,"duplicate":True}
    if intent:
     order=db.execute("SELECT id FROM game_shop_orders WHERE payment_intent=?",(intent,)).fetchone()
     if order:
      db.execute("UPDATE game_shop_orders SET state='revoked' WHERE id=?",(order["id"],))
      db.execute("UPDATE game_shop_entitlements SET revoked_at=? WHERE order_id=?",(int(time.time()),order["id"]))
    db.execute("INSERT INTO game_shop_webhook_events VALUES(?)",(eid,))
  return {"received":True,"handled":True}
