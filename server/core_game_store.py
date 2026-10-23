"""ZION-030 game-only digital cosmetics, safely disabled by default.

Catalog prices and entitlements are server-authoritative. Only signature-checked
Stripe Checkout webhooks (verified against Stripe API objects) grant ownership.
No game currency, power, progress or loot boxes are sold.
"""
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlsplit
import hashlib
import json
import os
import re
import time

from core_model import Fault, require, uid, now
from core_commerce import API_VERSION, StripeProvider, verify_webhook

CATALOG = {
    'car_onyx': dict(name='ONYX // Кузов', description='Чёрный металлик CITY RUNNER', amountMinor=499, currency='EUR', category='vehicle'),
    'car_aurora': dict(name='AURORA // Кузов', description='Голубой перламутр CITY RUNNER', amountMinor=699, currency='EUR', category='vehicle'),
    'suit_copper': dict(name='COPPER // Костюм', description='Костюм исследователя цвета меди', amountMinor=399, currency='EUR', category='avatar'),
    'city_afterglow': dict(name='AFTERGLOW // Город', description='Личный вариант городской подсветки', amountMinor=799, currency='EUR', category='environment'),
    'founder_pack': dict(name='FOUNDER // Коллекция', description='Все четыре облика в одном наборе', amountMinor=1499, currency='EUR', category='bundle'),
}
BUNDLE_CONTENTS = ('car_onyx', 'car_aurora', 'suit_copper', 'city_afterglow')
MAX_ORDERS_PER_BUYER = 150

SCHEMA = """
CREATE TABLE IF NOT EXISTS zion_game_orders (
 id TEXT PRIMARY KEY,
 buyer_id TEXT NOT NULL REFERENCES users(id),
 sku TEXT NOT NULL,
 amount_minor INTEGER NOT NULL CHECK(amount_minor>0),
 currency TEXT NOT NULL,
 account_id TEXT NOT NULL,
 livemode INTEGER NOT NULL,
 state TEXT NOT NULL,
 provider_key TEXT NOT NULL UNIQUE,
 session_id TEXT UNIQUE,
 checkout_url TEXT,
 payment_intent TEXT UNIQUE,
 charge_id TEXT,
 paid_minor INTEGER NOT NULL DEFAULT 0,
 refunded_minor INTEGER NOT NULL DEFAULT 0,
 confirmed INTEGER NOT NULL DEFAULT 0,
 started_at REAL NOT NULL,
 lease_until REAL NOT NULL DEFAULT 0,
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS zion_game_buyer_idx
 ON zion_game_orders(buyer_id,account_id,livemode,created_at);
CREATE TABLE IF NOT EXISTS zion_game_events(
 id TEXT PRIMARY KEY,
 body_sha256 TEXT NOT NULL,
 event_type TEXT NOT NULL,
 order_id TEXT NOT NULL REFERENCES zion_game_orders(id),
 processed_at TEXT NOT NULL);
"""

def _secret(name):
    filename = os.getenv(name+'_FILE','').strip()
    return Path(filename).read_text().strip() if filename else os.getenv(name,'').strip()

@dataclass(frozen=True)
class Config:
    enabled: bool = False
    account_id: str = ''
    livemode: bool = False
    public_origin: str = ''
    api_key: str = ''
    webhook_secret: str = ''

    @classmethod
    def from_env(cls):
        enabled = os.getenv('OSGARD_GAME_STORE_ENABLED','0') == '1'
        account_id = os.getenv('OSGARD_STRIPE_ACCOUNT_ID','').strip()
        livemode = os.getenv('OSGARD_STRIPE_LIVEMODE','0') == '1'
        origin = os.getenv('OSGARD_GAME_STORE_PUBLIC_ORIGIN','').rstrip('/')
        if not enabled:
            return cls(False,account_id,livemode,origin)
        require(re.fullmatch(r'acct_[A-Za-z0-9_]+',account_id) is not None,
                'Торговый аккаунт Stripe не настроен.','game_store_config',503)
        parsed = urlsplit(origin)
        require(parsed.scheme=='https' and parsed.hostname and not parsed.path
                and not parsed.query and not parsed.fragment and not parsed.username,
                'Нужен HTTPS origin для магазина.','game_store_config',503)
        api_key = _secret('OSGARD_STRIPE_API_KEY')
        secret = _secret('OSGARD_GAME_STRIPE_WEBHOOK_SECRET')
        expected = 'live' if livemode else 'test'
        require(re.fullmatch(r'(sk|rk)_'+expected+r'_[A-Za-z0-9]{12,}',api_key) is not None,
                'Режим ключа Stripe не совпадает с режимом магазина.','game_store_config',503)
        require(secret.startswith('whsec_') and len(secret)>=16,
                'Не подключён webhook магазина.','game_store_config',503)
        return cls(True,account_id,livemode,origin,api_key,secret)


class GameStore:
    def __init__(self, store, config=None, provider=None):
        self.store=store
        self.config=config if config is not None else Config.from_env()
        self._provider=provider

    def enabled(self):
        require(self.config.enabled,
                'Платёжный магазин пока не подключён. Игровые кредиты остаются бесплатными.',
                'game_store_disabled',503)

    def provider(self):
        self.enabled()
        if self._provider is None:
            # Core Stripe adapter independently confirms key ownership.
            self._provider=StripeProvider(self.config)
        return self._provider

    def _items(self,owned):
        return [dict(sku=sku,**data,owned=(sku in owned)) for sku,data in CATALOG.items()]

    def catalog(self):
        return dict(game='ZION-030',enabled=self.config.enabled,
                    mode='live' if self.config.livemode else 'test',
                    currency='EUR',oneTimeOnly=True,
                    source='server-authoritative',
                    note='Только косметика. Игровые кредиты и задания бесплатны.',
                    products=self._items(set()))

    def inventory(self, actor):
        with self.store.connect() as db:
            orders=db.execute("""
              SELECT sku,state,paid_minor,refunded_minor,amount_minor,confirmed
              FROM zion_game_orders
              WHERE buyer_id=? AND account_id=? AND livemode=?
              ORDER BY created_at DESC LIMIT 150""",
              (actor,self.config.account_id,int(self.config.livemode))).fetchall()
        paid={o['sku'] for o in orders if o['confirmed']
              and o['paid_minor']==o['amount_minor']
              and o['refunded_minor']<o['amount_minor']}
        owned=set(paid)
        if 'founder_pack' in paid:owned.update(BUNDLE_CONTENTS)
        safe_orders=[dict(sku=o['sku'],state=o['state'],confirmed=bool(o['confirmed']))
                     for o in orders]
        return dict(enabled=self.config.enabled,
                    mode='live' if self.config.livemode else 'test',
                    owned=sorted(owned),orders=safe_orders,
                    products=self._items(owned))

    def _metadata(self, order):
        return dict(zion_order_id=order['id'],zion_buyer_id=order['buyer_id'],
                    zion_sku=order['sku'],zion_account_id=order['account_id'],
                    zion_livemode=str(order['livemode']))

    def _validate_session(self, session, order):
        require(session.get('livemode') is self.config.livemode
                and session.get('mode')=='payment'
                and session.get('client_reference_id')==order['id']
                and session.get('metadata')==self._metadata(order)
                and session.get('amount_total')==order['amount_minor']
                and session.get('currency')==order['currency'].lower(),
                'Stripe Checkout не соответствует заказу игры.','game_checkout_mismatch',409)

    def checkout(self,actor,payload):
        self.enabled()
        require(isinstance(payload,dict) and set(payload)=={'sku'},
                'Выберите товар из каталога.','game_sku',400)
        sku=payload['sku']
        require(type(sku) is str and sku in CATALOG,
                'Этот товар не продаётся.','game_sku',400)
        if sku in self.inventory(actor)['owned']:
            return dict(alreadyOwned=True,sku=sku)
        with self.store.transaction() as db:
            require(db.execute('SELECT COUNT(*) FROM zion_game_orders WHERE buyer_id=?',
                               (actor,)).fetchone()[0]<MAX_ORDERS_PER_BUYER,
                    'Лимит заказов. Обратитесь в поддержку.','game_order_limit',409)
            old=db.execute("""
              SELECT * FROM zion_game_orders
              WHERE buyer_id=? AND sku=? AND account_id=? AND livemode=?
                AND state IN ('prepared','calling','unknown','checkout_open','processing')
              ORDER BY started_at DESC LIMIT 1""",
              (actor,sku,self.config.account_id,int(self.config.livemode))).fetchone()
            if old:
                order=dict(old)
                if order['state']=='calling' and order['lease_until']>time.time():
                    raise Fault('game_checkout_pending',
                                'Запрос на оплату ещё обрабатывается. Повторите позже.',409)
                if order['state']=='checkout_open' and order['checkout_url']:
                    return dict(orderId=order['id'],url=order['checkout_url'],
                                mode='live' if self.config.livemode else 'test',
                                reused=True)
                require(time.time()-order['started_at']<20*3600,
                        'Состояние старого заказа нужно сверить со Stripe.',
                        'game_checkout_reconciliation',409)
                db.execute("UPDATE zion_game_orders SET state='calling',lease_until=?,updated_at=? WHERE id=?",
                           (time.time()+90,now(),order['id']))
            else:
                order_id=uid()
                product=CATALOG[sku]
                order=dict(id=order_id,buyer_id=actor,sku=sku,
                           account_id=self.config.account_id,
                           livemode=int(self.config.livemode),
                           amount_minor=product['amountMinor'],
                           currency=product['currency'])
                stamp=now()
                db.execute("""
                  INSERT INTO zion_game_orders(
                  id,buyer_id,sku,amount_minor,currency,account_id,livemode,state,
                  provider_key,started_at,lease_until,created_at,updated_at)
                  VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                  (order_id,actor,sku,order['amount_minor'],order['currency'],
                   order['account_id'],order['livemode'],'calling',
                   'zion-game-checkout-'+order_id,time.time(),time.time()+90,stamp,stamp))
            stored=db.execute('SELECT * FROM zion_game_orders WHERE id=?',
                              (order['id'],)).fetchone()
            order=dict(stored)
        metadata=self._metadata(order)
        params=dict(
            mode='payment',
            client_reference_id=order['id'],
            metadata=metadata,
            payment_intent_data=dict(metadata=metadata),
            line_items=[dict(
                price_data=dict(
                    currency=order['currency'].lower(),
                    unit_amount=order['amount_minor'],
                    product_data=dict(name=CATALOG[sku]['name'],
                                      description=CATALOG[sku]['description'])
                ),quantity=1)],
            success_url=self.config.public_origin+
                '/games/zion-9/queue/ZION-030/?checkout=returned',
            cancel_url=self.config.public_origin+
                '/games/zion-9/queue/ZION-030/?checkout=cancelled',
        )
        try:
            session=self.provider().create_checkout(params,order['provider_key'])
            self._validate_session(session,order)
            session_id=session.get('id')
            require(isinstance(session_id,str) and re.fullmatch('cs_[A-Za-z0-9_]+',session_id),
                    'Stripe не вернул идентификатор оплаты.','game_checkout_session',503)
            url=session.get('url') or ''
            parsed=urlsplit(url)
            require(parsed.scheme=='https' and parsed.netloc=='checkout.stripe.com'
                    and not parsed.username and not parsed.password,
                    'Недопустимый адрес Stripe Checkout.','game_checkout_url',503)
        except Exception:
            with self.store.transaction() as db:
                db.execute("""UPDATE zion_game_orders
                    SET state='unknown',lease_until=0,updated_at=? WHERE id=? AND state='calling'""",
                           (now(),order['id']))
            raise Fault('game_checkout_unknown',
                        'Результат связи со Stripe неизвестен. Повтор использует прежний ключ.',
                        503)
        with self.store.transaction() as db:
            current=db.execute('SELECT * FROM zion_game_orders WHERE id=?',
                               (order['id'],)).fetchone()
            require(current['session_id'] in (None,session_id),
                    'У заказа другой Checkout. Требуется сверка.',
                    'game_checkout_mismatch',409)
            if current['state'] not in ('paid','partially_refunded','refunded'):
                db.execute("""UPDATE zion_game_orders
                    SET state='checkout_open',session_id=?,checkout_url=?,
                        lease_until=0,updated_at=? WHERE id=?""",
                    (session_id,url,now(),order['id']))
            else:
                return dict(orderId=order['id'],alreadyOwned=True)
        return dict(orderId=order['id'],url=url,
                    mode='live' if self.config.livemode else 'test',
                    reused=False)

    def _payment(self,order,intent):
        require(intent.get('livemode') is self.config.livemode
                and intent.get('status')=='succeeded'
                and intent.get('amount_received')==order['amount_minor']
                and intent.get('currency')==order['currency'].lower()
                and intent.get('metadata')==self._metadata(order),
                'Stripe не подтвердил полную сумму для игрового предмета.',
                'game_payment_mismatch',409)
        charge_id=intent.get('latest_charge')
        require(isinstance(charge_id,str) and re.fullmatch('ch_[A-Za-z0-9_]+',charge_id),
                'Не найдено подтверждённое списание.','game_charge',409)
        charge=self.provider().retrieve_charge(charge_id)
        refund=charge.get('amount_refunded',0)
        require(charge.get('livemode') is self.config.livemode
                and charge.get('paid') is True
                and charge.get('payment_intent')==intent.get('id')
                and charge.get('currency')==order['currency'].lower()
                and charge.get('amount')==order['amount_minor']
                and type(refund) is int and 0<=refund<=order['amount_minor'],
                'Списание или возврат не совпадает с заказом.',
                'game_charge_mismatch',409)
        return charge,refund

    def webhook(self,raw,signature):
        self.enabled()
        event=verify_webhook(raw,signature,self.config.webhook_secret)
        require(event.get('object')=='event'
                and event.get('api_version')==API_VERSION
                and event.get('livemode') is self.config.livemode
                and event.get('account') in (None,self.config.account_id),
                'Webhook другого Stripe аккаунта, режима или версии.',
                'game_webhook_tenant',403)
        event_id=event.get('id')
        require(isinstance(event_id,str) and re.fullmatch('evt_[A-Za-z0-9_]+',event_id),
                'Неверный ID Stripe webhook.','game_event',400)
        digest=hashlib.sha256(raw).hexdigest()
        with self.store.connect() as db:
            existing=db.execute('SELECT body_sha256 FROM zion_game_events WHERE id=?',
                                (event_id,)).fetchone()
            if existing:
                require(existing['body_sha256']==digest,
                        'Повторное событие отличается.','game_webhook_conflict',409)
                return dict(received=True,replayed=True)
        typ=event.get('type')
        session_events={'checkout.session.completed','checkout.session.async_payment_succeeded',
                        'checkout.session.async_payment_failed','checkout.session.expired'}
        refund_events={'charge.refunded','refund.created','refund.updated',
                       'refund.failed','charge.refund.updated'}
        if typ not in session_events|refund_events:
            return dict(received=True,ignored=True)
        obj=event.get('data',{}).get('object')
        require(isinstance(obj,dict),'В webhook отсутствует объект Stripe.','game_event',400)
        try:
            session=None
            if typ in session_events:
                sid=obj.get('id')
                require(isinstance(sid,str) and sid.startswith('cs_'),
                        'Неверная сессия Stripe.','game_event',400)
                session=self.provider().retrieve_session(sid)
                metadata=session.get('metadata') or {}
            else:
                charge_id=obj.get('id') if typ=='charge.refunded' else obj.get('charge')
                require(isinstance(charge_id,str) and charge_id.startswith('ch_'),
                        'Неверное списание Stripe.','game_event',400)
                charge=self.provider().retrieve_charge(charge_id)
                intent=self.provider().retrieve_intent(charge.get('payment_intent'))
                metadata=intent.get('metadata') or {}
            order_id=metadata.get('zion_order_id')
            require(isinstance(order_id,str) and re.fullmatch('[a-f0-9]{32}',order_id),
                    'Некорректный заказ Stripe.','game_order',409)
            with self.store.connect() as db:
                row=db.execute('SELECT * FROM zion_game_orders WHERE id=?',
                               (order_id,)).fetchone()
            require(row is not None,'Заказ webhook не найден.','game_order',409)
            order=dict(row)
            require(order['account_id']==self.config.account_id
                    and bool(order['livemode'])==self.config.livemode
                    and metadata==self._metadata(order),
                    'Событие Stripe не соответствует заказу.','game_webhook_mismatch',409)
            if session:
                self._validate_session(session,order)
                require(order['session_id'] in (None,session['id']),
                        'Сессия Stripe изменилась.','game_session_mismatch',409)
                settled=(typ in {'checkout.session.completed','checkout.session.async_payment_succeeded'}
                    and session.get('payment_status')=='paid'
                    and session.get('status')=='complete')
                if settled:
                    intent=self.provider().retrieve_intent(session.get('payment_intent'))
            else:
                settled=True
            verified_charge=None
            refunded=0
            if settled:
                verified_charge,refunded=self._payment(order,intent)
                if typ in refund_events:
                    require(verified_charge['id']==charge_id,
                            'Возврат относится к другому списанию.',
                            'game_charge_mismatch',409)
        except Fault:
            raise
        except Exception:
            raise Fault('game_stripe_unavailable',
                        'Не удалось сверить оплату со Stripe. Повторите событие.',503)
        with self.store.transaction() as db:
            old=db.execute('SELECT body_sha256 FROM zion_game_events WHERE id=?',
                           (event_id,)).fetchone()
            if old:
                require(old['body_sha256']==digest,'Изменённый Stripe webhook.',
                        'game_webhook_conflict',409)
                return dict(received=True,replayed=True)
            current=db.execute('SELECT * FROM zion_game_orders WHERE id=?',
                               (order_id,)).fetchone()
            paid=max(current['paid_minor'],order['amount_minor'] if settled else 0)
            refunded=max(current['refunded_minor'],refunded)
            confirmed=bool(current['confirmed']) or settled
            state=current['state']
            if refunded>=order['amount_minor']:state='refunded'
            elif refunded:state='partially_refunded'
            elif confirmed:state='paid'
            elif typ=='checkout.session.expired':state='expired'
            elif typ=='checkout.session.async_payment_failed':state='failed'
            elif session and session.get('payment_status')!='paid':state='processing'
            db.execute("""UPDATE zion_game_orders
                SET state=?,paid_minor=?,refunded_minor=?,confirmed=?,
                session_id=COALESCE(session_id,?),payment_intent=COALESCE(payment_intent,?),
                charge_id=COALESCE(charge_id,?),updated_at=?
                WHERE id=?""",
                (state,paid,refunded,int(confirmed),
                 session['id'] if session else None,
                 intent['id'] if settled else None,
                 verified_charge['id'] if verified_charge else None,
                 now(),order_id))
            db.execute('INSERT INTO zion_game_events VALUES(?,?,?,?,?)',
                       (event_id,digest,typ,order_id,now()))
        return dict(received=True,replayed=False)

