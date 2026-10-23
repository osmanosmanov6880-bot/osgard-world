"""NEBULA one-time Stripe Checkout with authenticated, webhook-only fulfillment.

Deliberately OFF until an owner verifies the MAGA merchant account, charges
capability, live restricted API key and dedicated webhook signing secret.
Godot and the public browser never receive Stripe secrets or grant entitlements.
"""
from dataclasses import dataclass
from urllib.parse import urlsplit
import hashlib
import json
import os
import re
import sqlite3
import threading
import time

from core_model import Fault, require, uid, now
from core_commerce import StripeProvider, verify_webhook, secret, API_VERSION


class VerifiedNebulaStripeProvider(StripeProvider):
    """Fail closed when the configured merchant cannot receive live payouts."""
    def verify_account(self):
        with self.lock:
            if self.checked:
                return
            account = self.client.v1.accounts.retrieve_current()
            require(account["id"] == self.config.account_id,
                    "Stripe key belongs to a different merchant account.",
                    "nebula_merchant_mismatch",503)
            if self.config.livemode:
                require(account.get("charges_enabled") is True and
                        account.get("payouts_enabled") is True,
                        "Merchant cannot accept and receive live payments yet.",
                        "nebula_merchant_inactive",503)
            self.checked = True

# Authoritative GBP minor-unit price catalog. The browser never sends prices.
CATALOG = {
    "ship_interceptor": ("VORTEX INTERCEPTOR", "ship", 799, False, 1),
    "ship_guardian": ("AEGIS GUARDIAN", "ship", 1399, False, 1),
    "weapon_plasma": ("PLASMA LANCE", "weapon", 499, False, 1),
    "missiles_6": ("HOMING MISSILES ×6", "ammo", 249, True, 6),
    "wingman_escort": ("ESCORT DRONE", "ally", 599, False, 1),
    "wingman_ace": ("ACE WINGMAN", "ally", 1099, False, 1),
    "skin_obsidian": ("OBSIDIAN SKIN", "cosmetic", 399, False, 1),
    "skin_aurora": ("AURORA CHROME", "cosmetic", 499, False, 1),
    "hangar_visuals": ("FOUNDER HANGAR", "cosmetic", 899, False, 1),
}
CURRENCY = "gbp"
RETRY_WINDOW = 20 * 3600
LEASE = 90
SCHEMA = """
CREATE TABLE IF NOT EXISTS nebula_orders(
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id),
 sku TEXT NOT NULL, price_minor INTEGER NOT NULL CHECK(price_minor > 0),
 currency TEXT NOT NULL, account_id TEXT NOT NULL,
 livemode INTEGER NOT NULL, request_key TEXT NOT NULL,
 provider_key TEXT UNIQUE NOT NULL, params TEXT NOT NULL,
 state TEXT NOT NULL, session_id TEXT UNIQUE, checkout_url TEXT,
 payment_intent TEXT UNIQUE, charge_id TEXT,
 started_at REAL NOT NULL, lease_until REAL NOT NULL DEFAULT 0,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 UNIQUE(user_id,request_key));
CREATE TABLE IF NOT EXISTS nebula_entitlements(
 order_id TEXT PRIMARY KEY REFERENCES nebula_orders(id) ON DELETE CASCADE,
 user_id TEXT NOT NULL REFERENCES users(id),
 sku TEXT NOT NULL, quantity INTEGER NOT NULL CHECK(quantity > 0),
 remaining INTEGER NOT NULL CHECK(remaining >= 0),
 active INTEGER NOT NULL DEFAULT 1,
 granted_at TEXT NOT NULL, revoked_at TEXT);
CREATE TABLE IF NOT EXISTS nebula_webhook_events(
 event_id TEXT PRIMARY KEY, body_hash TEXT NOT NULL,
 event_type TEXT NOT NULL, order_id TEXT, processed_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS nebula_consumption_keys(
 user_id TEXT NOT NULL REFERENCES users(id), request_key TEXT NOT NULL,
 order_id TEXT NOT NULL REFERENCES nebula_orders(id), created_at TEXT NOT NULL,
 PRIMARY KEY(user_id,request_key));
CREATE INDEX IF NOT EXISTS nebula_orders_user ON nebula_orders(user_id,created_at);
CREATE INDEX IF NOT EXISTS nebula_entitlements_user ON nebula_entitlements(user_id,active);
"""


def _strict_id(value, pattern=r'[a-f0-9]{32}'):
    require(isinstance(value, str) and re.fullmatch(pattern, value) is not None,
            "Invalid identifier.", "nebula_id", 400)
    return value


def _encoded(obj):
    return json.dumps(obj, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":"), allow_nan=False)


@dataclass(frozen=True)
class Config:
    enabled: bool = False
    account_id: str = ""
    livemode: bool = False
    public_origin: str = ""
    api_key: str = ""
    webhook_secret: str = ""

    @classmethod
    def from_env(cls):
        if os.getenv("OSGARD_NEBULA_PAYMENTS_ENABLED", "0") != "1":
            return cls()
        account_id = os.getenv("OSGARD_NEBULA_STRIPE_ACCOUNT_ID", "")
        mode = os.getenv("OSGARD_NEBULA_STRIPE_LIVEMODE", "0") == "1"
        origin = os.getenv("OSGARD_NEBULA_PUBLIC_ORIGIN", "").rstrip("/")
        api_key = secret("OSGARD_NEBULA_STRIPE_KEY")
        whsec = secret("OSGARD_NEBULA_STRIPE_WEBHOOK_SECRET")
        _strict_id(account_id, r'acct_[A-Za-z0-9]+')
        parsed = urlsplit(origin)
        require(parsed.scheme == "https" and parsed.netloc and
                not parsed.path and not parsed.query and not parsed.fragment and
                not parsed.username and not parsed.password,
                "NEBULA requires an HTTPS merchant origin.", "nebula_config")
        key_prefix = "live" if mode else "test"
        require(re.fullmatch(r"(rk|sk)_" + key_prefix + r"_[A-Za-z0-9]{12,}", api_key) is not None,
                "NEBULA key mode differs from the requested Stripe mode.", "nebula_config")
        require(whsec.startswith("whsec_") and len(whsec) >= 16,
                "Missing NEBULA webhook signing secret.", "nebula_config")
        return cls(True, account_id, mode, origin, api_key, whsec)


class Payments:
    def __init__(self, store, config=None, provider=None):
        self.store = store
        self.config = config or Config()
        self._provider = provider
        self._lock = threading.Lock()

    def require_enabled(self):
        require(self.config.enabled, "NEBULA checkout is not activated for a verified merchant.",
                "nebula_checkout_disabled", 503)

    def provider(self):
        self.require_enabled()
        with self._lock:
            if self._provider is None:
                self._provider = VerifiedNebulaStripeProvider(self.config)
        return self._provider

    def catalog(self):
        return {
            "enabled": self.config.enabled,
            "currency": CURRENCY.upper(),
            "mode": "live" if self.config.livemode else "test",
            "provider": "Stripe Checkout",
            "serverFulfillment": True,
            "items": [
                {"sku": sku, "name": product[0], "kind": product[1],
                 "amountMinor": product[2], "repeatable": product[3],
                 "quantity": product[4]}
                for sku, product in CATALOG.items()
            ],
        }

    def inventory(self, user_id):
        with self.store.connect() as db:
            rows = db.execute(
                """SELECT sku,SUM(remaining) AS available,SUM(quantity) AS granted
                   FROM nebula_entitlements
                   WHERE user_id=? AND active=1 GROUP BY sku""", (user_id,)
            ).fetchall()
            orders = db.execute(
                """SELECT id,sku,state,created_at FROM nebula_orders
                   WHERE user_id=? ORDER BY created_at DESC LIMIT 25""",
                (user_id,),
            ).fetchall()
        return {"items": {r["sku"]: int(r["available"]) for r in rows},
                "orders": [{"orderId":r["id"],"sku":r["sku"],
                            "state":r["state"],"createdAt":r["created_at"]} for r in orders]}

    def _metadata(self, order):
        return {
            "nebula_order_id": order["id"],
            "nebula_user_id": order["user_id"],
            "nebula_sku": order["sku"],
            "nebula_account": order["account_id"],
            "nebula_mode": "live" if order["livemode"] else "test",
        }

    def _validate_session(self, session, order):
        require(session.get("livemode") is self.config.livemode and
                session.get("mode") == "payment" and
                session.get("client_reference_id") == order["id"] and
                session.get("currency") == CURRENCY and
                type(session.get("amount_total")) is int and
                session["amount_total"] == order["price_minor"],
                "Stripe session does not match the order.", "nebula_session", 409)
        metadata = session.get("metadata")
        require(isinstance(metadata, dict) and all(
                    metadata.get(k) == v for k,v in self._metadata(order).items()),
                "Stripe session metadata mismatch.", "nebula_metadata", 409)

    def _verified_charge(self, intent, order):
        require(intent.get("livemode") is self.config.livemode and
                intent.get("status") == "succeeded" and
                intent.get("currency") == CURRENCY and
                type(intent.get("amount_received")) is int and
                intent["amount_received"] == order["price_minor"],
                "Stripe payment has not settled for the correct amount.", "nebula_unsettled", 409)
        data = intent.get("metadata")
        require(isinstance(data, dict) and all(
                    data.get(k) == v for k,v in self._metadata(order).items()),
                "Stripe PaymentIntent metadata mismatch.", "nebula_metadata", 409)
        charge_id = _strict_id(intent.get("latest_charge"), r"ch_[A-Za-z0-9_]+")
        charge = self.provider().retrieve_charge(charge_id)
        require(charge.get("payment_intent") == intent.get("id") and
                charge.get("livemode") is self.config.livemode and
                charge.get("currency") == CURRENCY and
                charge.get("amount") == order["price_minor"] and
                charge.get("paid") is True and charge.get("captured") is True,
                "Stripe charge is not a captured payment for this order.", "nebula_charge", 409)
        return charge

    def checkout(self, user_id, sku, request_key):
        self.require_enabled()
        require(isinstance(sku,str) and sku in CATALOG,
                "Unknown NEBULA product.", "nebula_sku", 400)
        _strict_id(request_key, r"[A-Za-z0-9_-]{20,90}")
        name, kind, amount, repeatable, quantity = CATALOG[sku]
        with self.store.transaction() as db:
            existing = db.execute(
                "SELECT * FROM nebula_orders WHERE user_id=? AND request_key=?",
                (user_id, request_key)).fetchone()
            if existing:
                require(existing["sku"] == sku,
                        "Idempotency key was reused for a different item.",
                        "nebula_idempotency", 409)
                if existing["session_id"]:
                    return {"orderId":existing["id"],"url":existing["checkout_url"]
                            if existing["state"]=="open" else None,
                            "state":existing["state"],"replayed":True}
                require(existing["lease_until"] < time.time(),
                        "Checkout already in progress.", "nebula_checkout_busy", 409)
                require(time.time()-existing["started_at"] < RETRY_WINDOW,
                        "Checkout reconciliation required before retrying.",
                        "nebula_reconciliation", 409)
                order = dict(existing)
                db.execute("UPDATE nebula_orders SET state='calling',lease_until=? WHERE id=?",
                           (time.time()+LEASE, order["id"]))
            else:
                if not repeatable:
                    owned = db.execute(
                        "SELECT 1 FROM nebula_entitlements WHERE user_id=? AND sku=? AND active=1",
                        (user_id, sku)).fetchone()
                    require(owned is None, "You already own this item.", "nebula_owned", 409)
                    pending = db.execute(
                        """SELECT 1 FROM nebula_orders WHERE user_id=? AND sku=?
                           AND state IN ('calling','unknown','open','processing')""",
                        (user_id, sku)).fetchone()
                    require(pending is None,
                            "An existing checkout must be completed or expired first.",
                            "nebula_pending_order", 409)
                order_id = uid()
                provider_key = "nebula-" + order_id
                import secrets, string
                suffix = "".join(secrets.choice(string.ascii_lowercase) for _ in range(8))
                operation = {
                    "id":order_id, "user_id":user_id, "sku":sku,
                    "account_id":self.config.account_id,
                    "livemode":int(self.config.livemode),
                    "price_minor":amount
                }
                metadata = self._metadata(operation)
                params = {
                    "mode":"payment",
                    "client_reference_id":order_id,
                    "metadata":metadata,
                    "payment_intent_data":{"metadata":metadata},
                    "integration_identifier":"osgard-nebula-" + suffix,
                    "line_items":[{"price_data":{
                        "currency":CURRENCY, "unit_amount":amount,
                        "product_data":{"name":name, "description":"NEBULA digital game content"}
                    }, "quantity":1}],
                    "success_url":self.config.public_origin +
                        "/games/remix/arena-v2/nebula-3d/hangar.html?checkout=returned&order="+order_id,
                    "cancel_url":self.config.public_origin +
                        "/games/remix/arena-v2/nebula-3d/hangar.html?checkout=cancelled&order="+order_id,
                }
                db.execute(
                    """INSERT INTO nebula_orders(id,user_id,sku,price_minor,currency,account_id,
                       livemode,request_key,provider_key,params,state,started_at,lease_until,
                       created_at,updated_at)
                       VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (order_id,user_id,sku,amount,CURRENCY,self.config.account_id,
                     int(self.config.livemode),request_key,provider_key,_encoded(params),
                     "calling",time.time(),time.time()+LEASE,now(),now()))
                order=dict(db.execute("SELECT * FROM nebula_orders WHERE id=?",(order_id,)).fetchone())
        try:
            session = self.provider().create_checkout(
                json.loads(order["params"]), order["provider_key"])
            self._validate_session(session,order)
            session_id = _strict_id(session.get("id"), r"cs_[A-Za-z0-9_]+")
            url = session.get("url","")
            parsed = urlsplit(url)
            require(parsed.scheme=="https" and parsed.hostname=="checkout.stripe.com" and
                    not parsed.username and not parsed.password,
                    "Invalid hosted Stripe Checkout URL.", "nebula_checkout_url", 503)
        except Exception:
            with self.store.transaction() as db:
                db.execute(
                    """UPDATE nebula_orders SET state='unknown',lease_until=0,
                       updated_at=? WHERE id=? AND session_id IS NULL""", (now(),order["id"]))
            raise Fault("nebula_checkout_unknown",
                        "Stripe response unavailable. Retry with the SAME idempotency key.",
                        503)
        with self.store.transaction() as db:
            current=db.execute("SELECT session_id,state FROM nebula_orders WHERE id=?",
                               (order["id"],)).fetchone()
            require(current["session_id"] in (None,session_id),
                    "Checkout session ID changed.", "nebula_session", 409)
            db.execute(
                """UPDATE nebula_orders
                   SET session_id=?,checkout_url=?,lease_until=0,
                   state=CASE WHEN state IN ('calling','unknown') THEN 'open' ELSE state END,
                   updated_at=? WHERE id=?""",
                (session_id,url,now(),order["id"]))
            status = db.execute("SELECT state FROM nebula_orders WHERE id=?",
                                (order["id"],)).fetchone()["state"]
        return {"orderId":order["id"],"url":url if status=="open" else None,
                "state":status, "replayed":False}

    def webhook(self, raw, signature):
        self.require_enabled()
        event = verify_webhook(raw, signature, self.config.webhook_secret)
        event_id = _strict_id(event.get("id"), r"evt_[A-Za-z0-9_]+")
        body_hash = hashlib.sha256(raw).hexdigest()
        require(event.get("object")=="event" and event.get("api_version")==API_VERSION,
                "Unexpected Stripe event type or API snapshot.", "nebula_webhook_version", 409)
        require(event.get("livemode") is self.config.livemode and
                event.get("account") in (None,self.config.account_id),
                "Stripe webhook account mismatch.", "nebula_webhook_account", 403)
        event_type = event.get("type")
        permitted = {
            "checkout.session.completed","checkout.session.async_payment_succeeded",
            "checkout.session.async_payment_failed","checkout.session.expired",
            "charge.refunded","charge.dispute.created"
        }
        with self.store.connect() as db:
            previous=db.execute("SELECT body_hash FROM nebula_webhook_events WHERE event_id=?",
                                (event_id,)).fetchone()
        if previous:
            require(previous["body_hash"]==body_hash,
                    "Stripe event ID replay with different body.", "nebula_webhook_replay",409)
            return {"received":True,"replayed":True}
        if event_type not in permitted:
            return {"received":True,"ignored":True}
        payload=event.get("data",{}).get("object",{})
        require(isinstance(payload,dict), "Invalid Stripe event.", "nebula_webhook_body",400)
        session=None
        intent=None
        charge=None
        if event_type.startswith("checkout."):
            session = self.provider().retrieve_session(
                _strict_id(payload.get("id"), r"cs_[A-Za-z0-9_]+"))
            metadata=session.get("metadata",{})
        else:
            charge_id=(payload.get("id") if event_type=="charge.refunded"
                       else payload.get("charge"))
            charge=self.provider().retrieve_charge(
                _strict_id(charge_id,r"ch_[A-Za-z0-9_]+"))
            intent=self.provider().retrieve_intent(
                _strict_id(charge.get("payment_intent"),r"pi_[A-Za-z0-9_]+"))
            metadata=intent.get("metadata",{})
        require(isinstance(metadata,dict),"Missing Stripe order metadata.",
                "nebula_metadata",409)
        order_id=_strict_id(metadata.get("nebula_order_id"))
        with self.store.connect() as db:
            record=db.execute("SELECT * FROM nebula_orders WHERE id=?",
                              (order_id,)).fetchone()
        require(record is not None,"Unknown NEBULA order.", "nebula_order",409)
        order=dict(record)
        require(order["account_id"]==self.config.account_id and
                bool(order["livemode"])==self.config.livemode,
                "NEBULA order merchant mismatch.","nebula_account",403)
        paid=False
        revoked=False
        if session:
            self._validate_session(session,order)
            require(order["session_id"] in (None,session["id"]),
                    "Checkout session cannot switch orders.","nebula_session",409)
            if event_type in ("checkout.session.completed",
                              "checkout.session.async_payment_succeeded"):
                paid=(session.get("payment_status")=="paid" and
                      session.get("status")=="complete")
                if paid:
                    intent=self.provider().retrieve_intent(
                        _strict_id(session.get("payment_intent"),r"pi_[A-Za-z0-9_]+"))
                    charge=self._verified_charge(intent,order)
                    revoked=(event_type=="charge.dispute.created" or bool(charge.get("disputed")) or int(charge.get("amount_refunded",0))>0)
        else:
            charge=self._verified_charge(intent,order)
            revoked=bool(charge.get("disputed")) or int(charge.get("amount_refunded",0))>0
        with self.store.transaction() as db:
            replay=db.execute("SELECT body_hash FROM nebula_webhook_events WHERE event_id=?",
                              (event_id,)).fetchone()
            if replay:
                require(replay["body_hash"]==body_hash,
                        "Stripe event replay mismatch.","nebula_webhook_replay",409)
                return {"received":True,"replayed":True}
            current=db.execute("SELECT * FROM nebula_orders WHERE id=?",
                               (order_id,)).fetchone()
            status=current["state"]
            if revoked:
                status="revoked"
            elif paid and status not in ("revoked","refunded","disputed"):
                status="paid"
            elif status not in ("paid","revoked"):
                if event_type=="checkout.session.expired":
                    status="expired"
                elif event_type=="checkout.session.async_payment_failed":
                    status="failed"
                elif session:
                    status="processing"
            if session:
                db.execute(
                    """UPDATE nebula_orders SET session_id=COALESCE(session_id,?),
                       state=?,updated_at=? WHERE id=?""",
                    (session["id"],status,now(),order_id))
            else:
                db.execute("UPDATE nebula_orders SET state=?,updated_at=? WHERE id=?",
                           (status,now(),order_id))
            if intent:
                db.execute(
                    """UPDATE nebula_orders
                       SET payment_intent=COALESCE(payment_intent,?),
                           charge_id=COALESCE(charge_id,?) WHERE id=?""",
                    (intent["id"], charge["id"] if charge else None, order_id))
            if status=="paid":
                qty=CATALOG[order["sku"]][4]
                db.execute(
                    """INSERT INTO nebula_entitlements(
                       order_id,user_id,sku,quantity,remaining,active,granted_at)
                       VALUES(?,?,?,?,?,1,?)
                       ON CONFLICT(order_id) DO NOTHING""",
                    (order_id,order["user_id"],order["sku"],qty,qty,now()))
            if status=="revoked":
                db.execute(
                    """UPDATE nebula_entitlements
                       SET active=0,remaining=0,revoked_at=?
                       WHERE order_id=?""", (now(),order_id))
            db.execute(
                """INSERT INTO nebula_webhook_events
                   (event_id,body_hash,event_type,order_id,processed_at)
                   VALUES(?,?,?,?,?)""",
                (event_id,body_hash,event_type,order_id,now()))
        return {"received":True,"replayed":False}

    def consume_missile(self,user_id,request_key):
        _strict_id(request_key,r"[A-Za-z0-9_-]{20,90}")
        with self.store.transaction() as db:
            replay=db.execute(
                "SELECT order_id FROM nebula_consumption_keys WHERE user_id=? AND request_key=?",
                (user_id,request_key)).fetchone()
            if replay:
                count=db.execute(
                    "SELECT remaining FROM nebula_entitlements WHERE order_id=?",
                    (replay["order_id"],)).fetchone()
                return {"consumed":True,"replayed":True,
                        "orderId":replay["order_id"],"remainingInOrder":count["remaining"]}
            order=db.execute(
                """SELECT order_id,remaining FROM nebula_entitlements
                   WHERE user_id=? AND sku='missiles_6' AND active=1 AND remaining>0
                   ORDER BY granted_at,order_id LIMIT 1""",
                (user_id,)).fetchone()
            require(order is not None,"No purchased rockets remain.","nebula_no_ammo",409)
            changed=db.execute(
                """UPDATE nebula_entitlements SET remaining=remaining-1
                   WHERE order_id=? AND active=1 AND remaining>0""",
                (order["order_id"],))
            require(changed.rowcount==1,"Rocket stock changed.","nebula_no_ammo",409)
            db.execute(
                """INSERT INTO nebula_consumption_keys(user_id,request_key,order_id,created_at)
                   VALUES(?,?,?,?)""",
                (user_id,request_key,order["order_id"],now()))
            return {"consumed":True,"replayed":False,
                    "orderId":order["order_id"],"remainingInOrder":order["remaining"]-1}
