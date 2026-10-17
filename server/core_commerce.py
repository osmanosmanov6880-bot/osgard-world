"""Disabled-by-default, single-merchant Checkout and paid artifact access.

All network operations have durable, immutable provider idempotency keys. Only
verified Checkout webhooks grant access. A return URL never changes payment state.
"""
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlsplit
import hashlib
import hmac
import json
import os
import re
import sqlite3
import threading
import time

from core_model import Fault, require, text, uid, now
import core_acceptance
import core_programs

API_VERSION = '2026-08-26.dahlia'
RETRY_WINDOW = 20 * 3600  # Stop before Stripe's minimum 24-hour key retention.
LEASE_SECONDS = 90
SCHEMA = '''
CREATE TABLE IF NOT EXISTS commerce_orders(
 id TEXT PRIMARY KEY,project_id TEXT NOT NULL REFERENCES projects(id),source_order_id TEXT NOT NULL,
 release_id TEXT NOT NULL,merchant_id TEXT NOT NULL REFERENCES users(id),buyer_id TEXT NOT NULL REFERENCES users(id),
 account_id TEXT NOT NULL,livemode INTEGER NOT NULL,version INTEGER NOT NULL DEFAULT 1,
 title TEXT NOT NULL,scope TEXT NOT NULL,envelope TEXT NOT NULL,envelope_sha256 TEXT NOT NULL,
 amount_minor INTEGER NOT NULL CHECK(amount_minor>0),currency TEXT NOT NULL,
 state TEXT NOT NULL DEFAULT 'prepared',paid_minor INTEGER NOT NULL DEFAULT 0,
 refunded_minor INTEGER NOT NULL DEFAULT 0,checkout_confirmed INTEGER NOT NULL DEFAULT 0,
 payment_intent TEXT UNIQUE,charge_id TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,
 UNIQUE(project_id,source_order_id));
CREATE TABLE IF NOT EXISTS commerce_checkout_ops(
 id TEXT PRIMARY KEY,order_id TEXT NOT NULL UNIQUE REFERENCES commerce_orders(id),
 provider_key TEXT NOT NULL UNIQUE,params TEXT NOT NULL,state TEXT NOT NULL,
 started_at REAL NOT NULL,lease_until REAL NOT NULL DEFAULT 0,
 session_id TEXT UNIQUE,checkout_url TEXT,last_error TEXT);
CREATE TABLE IF NOT EXISTS commerce_refund_ops(
 id TEXT PRIMARY KEY,order_id TEXT NOT NULL REFERENCES commerce_orders(id),target_minor INTEGER NOT NULL,
 provider_key TEXT NOT NULL UNIQUE,params TEXT NOT NULL,state TEXT NOT NULL,
 started_at REAL NOT NULL,lease_until REAL NOT NULL DEFAULT 0,refund_id TEXT UNIQUE,last_error TEXT,
 UNIQUE(order_id,target_minor));
CREATE TABLE IF NOT EXISTS commerce_webhook_events(
 id TEXT PRIMARY KEY,body_sha256 TEXT NOT NULL,event_type TEXT NOT NULL,order_id TEXT REFERENCES commerce_orders(id),
 processed_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS commerce_entitlements(
 order_id TEXT PRIMARY KEY REFERENCES commerce_orders(id),buyer_id TEXT NOT NULL REFERENCES users(id),
 active INTEGER NOT NULL DEFAULT 0,granted_at TEXT,revoked_at TEXT);
CREATE TABLE IF NOT EXISTS commerce_requests(
 user_id TEXT NOT NULL REFERENCES users(id),key TEXT NOT NULL,request_hash TEXT NOT NULL,response TEXT,
 PRIMARY KEY(user_id,key));
CREATE INDEX IF NOT EXISTS commerce_buyer ON commerce_orders(buyer_id,created_at);
CREATE INDEX IF NOT EXISTS commerce_project ON commerce_orders(project_id,created_at);
'''


def encoded(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False)


def sha(value):
    return hashlib.sha256(value.encode() if isinstance(value, str) else value).hexdigest()


def identifier(value, prefix=None):
    pattern = r'[a-f0-9]{32}' if prefix is None else re.escape(prefix) + r'[A-Za-z0-9_]+'
    require(isinstance(value, str) and re.fullmatch(pattern, value), 'Некорректный идентификатор.', 'commerce_validation')
    return value


def secret(name):
    filename = os.getenv(name + '_FILE')
    value = Path(filename).read_text().strip() if filename else os.getenv(name, '').strip()
    return value


@dataclass(frozen=True)
class Config:
    enabled: bool = False
    merchant_id: str = ''
    account_id: str = ''
    livemode: bool = False
    public_origin: str = ''
    api_key: str = ''
    webhook_secret: str = ''

    @classmethod
    def from_env(cls):
        if os.getenv('OSGARD_COMMERCE_ENABLED', '0') != '1':
            return cls(False, os.getenv('OSGARD_COMMERCE_MERCHANT_USER_ID',''), os.getenv('OSGARD_STRIPE_ACCOUNT_ID',''),
                       os.getenv('OSGARD_STRIPE_LIVEMODE','0')=='1', os.getenv('OSGARD_COMMERCE_PUBLIC_ORIGIN','').rstrip('/'))
        config = cls(True, os.getenv('OSGARD_COMMERCE_MERCHANT_USER_ID', ''),
                     os.getenv('OSGARD_STRIPE_ACCOUNT_ID', ''), os.getenv('OSGARD_STRIPE_LIVEMODE', '0') == '1',
                     os.getenv('OSGARD_COMMERCE_PUBLIC_ORIGIN', '').rstrip('/'),
                     secret('OSGARD_STRIPE_API_KEY'), secret('OSGARD_STRIPE_WEBHOOK_SECRET'))
        identifier(config.merchant_id)
        identifier(config.account_id, 'acct_')
        origin = urlsplit(config.public_origin)
        require(origin.scheme == 'https' and origin.hostname and not origin.path and not origin.query and not origin.fragment and not origin.username, 'Для Commerce нужен HTTPS origin без пути.', 'commerce_config')
        expected = 'live' if config.livemode else 'test'
        require(re.fullmatch(r'(rk|sk)_' + expected + r'_[A-Za-z0-9]{12,}', config.api_key) is not None,
                'Режим ключа Stripe не совпадает с настройкой Commerce.', 'commerce_config')
        require(config.webhook_secret.startswith('whsec_') and len(config.webhook_secret) >= 16,
                'Не настроен секрет подписи webhook.', 'commerce_config')
        return config


class StripeProvider:
    """Real SDK adapter, constructed lazily only for an enabled installation."""
    def __init__(self, config):
        from stripe import StripeClient, RequestsClient
        self.client = StripeClient(config.api_key, stripe_version=API_VERSION,
                                   max_network_retries=0, http_client=RequestsClient(timeout=20))
        self.config = config
        self.checked = False
        self.lock = threading.Lock()

    def verify_account(self):
        with self.lock:
            if not self.checked:
                account = self.client.v1.accounts.retrieve_current()
                require(account['id'] == self.config.account_id, 'Ключ Stripe принадлежит другому торговому аккаунту.', 'merchant_mismatch', 503)
                self.checked = True

    def create_checkout(self, params, key):
        self.verify_account()
        return self.client.v1.checkout.sessions.create(params=params, options={'idempotency_key': key}).to_dict()

    def retrieve_session(self, session_id):
        self.verify_account()
        return self.client.v1.checkout.sessions.retrieve(session_id).to_dict()

    def retrieve_intent(self, intent_id):
        self.verify_account()
        return self.client.v1.payment_intents.retrieve(intent_id).to_dict()

    def retrieve_charge(self, charge_id):
        self.verify_account()
        return self.client.v1.charges.retrieve(charge_id).to_dict()

    def refunds_for_charge(self, charge_id):
        self.verify_account()
        records = []
        for refund in self.client.v1.refunds.list(params={'charge': charge_id, 'limit': 100}).auto_paging_iter():
            require(len(records) < 1000, 'Слишком много возвратов для автоматической сверки.', 'refund_reconciliation', 503)
            records.append(refund.to_dict())
        return records

    def create_refund(self, params, key):
        self.verify_account()
        return self.client.v1.refunds.create(params=params, options={'idempotency_key': key}).to_dict()


def verify_webhook(raw, signature, signing_secret, clock=time.time):
    """Stripe v1 HMAC protocol over the exact received bytes, never reserialized."""
    require(isinstance(raw, bytes) and 0 < len(raw) <= 256 * 1024, 'Неверный размер webhook.', 'webhook_body', 400)
    require(isinstance(signature, str) and len(signature) <= 4096 and signing_secret, 'Нет подписи webhook.', 'webhook_signature', 400)
    try:
        parts = [item.split('=', 1) for item in signature.split(',')]
        stamps = [value for key, value in parts if key == 't']
        signatures = [value for key, value in parts if key == 'v1']
        require(len(stamps) == 1 and stamps[0].isdigit(), 'Неверная подпись webhook.', 'webhook_signature')
        stamp = int(stamps[0])
    except (ValueError, TypeError):
        raise Fault('webhook_signature', 'Неверная подпись webhook.')
    require(abs(clock() - stamp) <= 300, 'Время подписи webhook истекло.', 'webhook_timestamp')
    expected = hmac.new(signing_secret.encode(), str(stamp).encode() + b'.' + raw, hashlib.sha256).hexdigest()
    require(any(re.fullmatch('[a-f0-9]{64}', candidate) and hmac.compare_digest(expected, candidate) for candidate in signatures),
            'Подпись webhook не совпадает.', 'webhook_signature')
    try:
        event = json.loads(raw, parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
    except (ValueError, UnicodeError):
        raise Fault('webhook_body', 'Неверный JSON webhook.')
    require(isinstance(event, dict), 'Неверный webhook.')
    return event


class Commerce:
    def __init__(self, store, config=None, provider=None):
        self.store = store
        self.config = config or Config()
        self._adapter = provider
        self._adapter_lock = threading.Lock()

    def enabled(self):
        require(self.config.enabled, 'Приём платежей выключен. Сначала настройте торговый аккаунт и webhook.', 'commerce_disabled', 503)

    def provider(self):
        self.enabled()
        with self._adapter_lock:
            if self._adapter is None:
                self._adapter = StripeProvider(self.config)
        return self._adapter

    def config_view(self, actor):
        return dict(enabled=self.config.enabled, canManage=actor == self.config.merchant_id,
                    mode='live' if self.config.livemode else 'test', currencies=['USD', 'EUR'], oneTimeOnly=True,
                    scope='One configured merchant; immutable HTML or versioned OSA private practice',
                    purchaseKinds=['html_release', 'learning_program'], livePaymentTested=False)

    def access(self, db, order_id, actor, merchant=False):
        identifier(order_id)
        order = db.execute('SELECT * FROM commerce_orders WHERE id=?', (order_id,)).fetchone()
        allowed = order is not None and (order['merchant_id'] == actor if merchant else order['buyer_id'] == actor)
        require(allowed, 'Заказ не найден.', 'not_found', 404)
        if merchant:
            require(actor == self.config.merchant_id, 'Оператор Commerce не совпадает.', 'forbidden', 403)
            self.store.access(db, order['project_id'], actor, owner=True)
        require(order['account_id'] == self.config.account_id and bool(order['livemode']) == self.config.livemode,
                'Заказ относится к другой настройке торгового аккаунта.', 'merchant_mismatch', 409)
        return order

    def summary(self, db, order, merchant=False):
        entitlement = db.execute('SELECT active FROM commerce_entitlements WHERE order_id=?', (order['id'],)).fetchone()
        checkout = db.execute('SELECT state,session_id FROM commerce_checkout_ops WHERE order_id=?', (order['id'],)).fetchone()
        refund = db.execute('SELECT state,target_minor FROM commerce_refund_ops WHERE order_id=? ORDER BY started_at DESC LIMIT 1',(order['id'],)).fetchone()
        result = dict(id=order['id'], version=order['version'], title=order['title'], scope=order['scope'],
                      amountMinor=order['amount_minor'], currency=order['currency'], status=order['state'],
                      paidMinor=order['paid_minor'], refundedMinor=order['refunded_minor'],
                      checkoutConfirmed=bool(order['checkout_confirmed']), accessGranted=bool(entitlement and entitlement['active']),
                      checkoutState=checkout['state'] if checkout else None, mode='live' if order['livemode'] else 'test',
                      refundState=refund['state'] if refund else None, refundTargetMinor=refund['target_minor'] if refund else None,
                      createdAt=order['created_at'], updatedAt=order['updated_at'])
        envelope = json.loads(order['envelope'])
        result['kind'] = envelope.get('kind', 'html_release')
        if result['kind'] == 'learning_program':
            result['program'] = core_programs.program_header(core_programs.program_snapshot(order))
            result['enrollmentActivated'] = db.execute('SELECT 1 FROM program_enrollments WHERE order_id=?', (order['id'],)).fetchone() is not None
        if merchant:
            buyer = db.execute('SELECT username FROM users WHERE id=?', (order['buyer_id'],)).fetchone()
            result.update(buyer=buyer['username'], sourceOrderId=order['source_order_id'], releaseId=order['release_id'])
        return result

    def purchases(self, db, actor):
        orders = db.execute('SELECT * FROM commerce_orders WHERE buyer_id=? AND account_id=? AND livemode=? ORDER BY created_at DESC LIMIT 200',
                            (actor, self.config.account_id, int(self.config.livemode))).fetchall()
        return dict(orders=[self.summary(db, order) for order in orders], configuration=self.config_view(actor))

    def project_orders(self, db, project_id, actor):
        row = self.store.access(db, project_id, actor, owner=True)
        require(actor == self.config.merchant_id, 'Только настроенный оператор видит коммерческие заказы.', 'forbidden', 403)
        orders = db.execute('SELECT * FROM commerce_orders WHERE project_id=? AND account_id=? AND livemode=? ORDER BY created_at DESC',
                            (row['id'], self.config.account_id, int(self.config.livemode))).fetchall()
        return dict(orders=[self.summary(db, order, True) for order in orders], configuration=self.config_view(actor))

    def prepare(self, db, row, actor, payload):
        self.enabled()
        require(actor == self.config.merchant_id and actor == row['owner_id'], 'Заказ создаёт настроенный оператор — владелец проекта.', 'forbidden', 403)
        data = json.loads(row['data'])
        require(data['accepted'] and data['consents']['business'], 'Примите контракт и разрешите Business.')
        require(payload.get('sharingAcknowledged') is True, 'Подтвердите состав передаваемого файла и выбранного покупателя.')
        draft = next((item for item in data['orders'] if item['id'] == payload.get('draftOrderId') and item['status'] == 'draft'), None)
        require(draft is not None, 'Нужен существующий неотменённый черновик заказа.')
        require(draft['currency'] in ('USD', 'EUR'), 'Commerce поддерживает USD и EUR. RUB в этом модуле не подключён.', 'unsupported_currency')
        require(type(payload.get('confirmedAmountMinor')) is int and payload['confirmedAmountMinor'] == draft['amountMinor'] and payload.get('confirmedCurrency') == draft['currency'], 'Подтвердите точную сумму и валюту черновика.', 'amount_confirmation')
        require(0 < draft['amountMinor'] <= 99999999, 'Сумма заказа выходит за пределы модуля.')
        kind = payload.get('kind', 'html_release')
        require(kind in ('html_release', 'learning_program'), 'Неизвестный вид предложения.', 'wrong_order_kind')
        if kind == 'learning_program':
            envelope = core_programs.offer(payload)
            release_id = envelope['program']['version']
            title, scope = envelope['title'], envelope['description']
        else:
            require(data['consents']['studio'], 'Разрешите Studio для передачи HTML.')
            release_id = identifier(payload.get('releaseId'))
            release, snapshot, _, asset = core_acceptance.release_source(db, row, release_id)
            reviews = core_acceptance.reviews(db, row['id'], release_id)
            require(reviews and reviews[0]['verdict'] == 'accepted', 'Нужен положительный разбор этого выпуска другим участником.', 'review_required', 409)
            require(asset and asset['integrityMatches'] and asset['inputsMatchSnapshot'], 'Для продажи нужен проверенный сохранённый HTML этого выпуска.', 'artifact_required', 409)
            envelope = dict(title=draft['title'], description=draft['scope'], html=asset['html'], sha256=asset['sha256'], sourceVersion=release['sourceVersion'])
            title, scope = draft['title'], draft['scope']
        buyer = db.execute('SELECT id FROM users WHERE username=?', (text(payload.get('buyerUsername'), 64, 3).lower(),)).fetchone()
        require(buyer is not None and buyer['id'] != actor, 'Выберите другой существующий аккаунт покупателя.')
        require(db.execute('SELECT COUNT(*) FROM commerce_orders WHERE merchant_id=?', (actor,)).fetchone()[0] < 1000, 'Лимит коммерческого пилота.', status=409)
        raw = encoded(envelope); order_id = uid(); stamp = now()
        try:
            db.execute('INSERT INTO commerce_orders(id,project_id,source_order_id,release_id,merchant_id,buyer_id,account_id,livemode,title,scope,envelope,envelope_sha256,amount_minor,currency,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
                       (order_id,row['id'],draft['id'],release_id,actor,buyer['id'],self.config.account_id,int(self.config.livemode),title,scope,raw,sha(raw),draft['amountMinor'],draft['currency'],stamp,stamp))
        except sqlite3.IntegrityError:
            raise Fault('commerce_order_exists', 'Этот черновик уже связан с коммерческим заказом.', 409)
        self.store.event(db,row['id'],actor,'commerce_order_prepared',dict(orderId=order_id,releaseId=release_id))
        order = db.execute('SELECT * FROM commerce_orders WHERE id=?', (order_id,)).fetchone()
        return dict(project=self.store.project(row), order=self.summary(db,order,True))

    def metadata(self, order, operation_id):
        return dict(osgard_order_id=order['id'], osgard_buyer_id=order['buyer_id'],
                    osgard_merchant_id=order['merchant_id'], osgard_account_id=order['account_id'],
                    osgard_livemode='1' if order['livemode'] else '0', osgard_envelope_sha256=order['envelope_sha256'],
                    osgard_checkout_operation=operation_id)

    def validate_object(self, value, order, operation_id, session=False):
        require(value.get('livemode') is self.config.livemode, 'Режим объекта Stripe не совпадает.', 'stripe_mode', 409)
        metadata=value.get('metadata')
        require(isinstance(metadata,dict) and all(metadata.get(k) == v for k,v in self.metadata(order,operation_id).items()),
                'Объект Stripe не соответствует заказу.', 'stripe_metadata', 409)
        amount = value.get('amount_total') if session else value.get('amount')
        require(type(amount) is int and amount == order['amount_minor'] and value.get('currency') == order['currency'].lower(),
                'Сумма или валюта Stripe не совпадает с заказом.', 'stripe_amount', 409)
        if session:
            require(value.get('mode') == 'payment' and value.get('client_reference_id') == order['id'], 'Неверный тип Checkout.', 'stripe_session', 409)

    def checkout(self, order_id, actor):
        self.enabled()
        with self.store.transaction() as db:
            order = self.access(db, order_id, actor)
            project=db.execute('SELECT data FROM projects WHERE id=?',(order['project_id'],)).fetchone()
            require(project is not None and json.loads(project['data'])['consents']['business'],'Приём новой оплаты по этому проекту приостановлен.','commerce_consent',409)
            require(order['state'] not in ('paid','partially_refunded','refunded','cancelled','expired','failed'), 'Оплата этого заказа уже завершена или закрыта.', 'checkout_closed', 409)
            operation = db.execute('SELECT * FROM commerce_checkout_ops WHERE order_id=?', (order_id,)).fetchone()
            if operation and operation['session_id']:
                url=operation['checkout_url'] if order['state'] in ('checkout_pending','checkout_open') else None
                return dict(orderId=order_id,url=url,reused=True,pending=not bool(url),status=order['state'])
            require(operation is None or operation['lease_until'] < time.time(), 'Запрос Checkout уже выполняется. Обновите заказ через минуту.', 'checkout_in_progress', 409)
            require(operation is None or time.time() - operation['started_at'] < RETRY_WINDOW, 'Результат старого запроса нужно сверить со Stripe. Новый Checkout автоматически не создаётся.', 'reconciliation_required', 409)
            if operation is None:
                operation_id=uid(); metadata=self.metadata(order,operation_id)
                suffix=''.join(chr(97+int(ch,16)) for ch in operation_id[:8])
                params=dict(mode='payment',client_reference_id=order_id,metadata=metadata,payment_intent_data={'metadata':metadata},
                            integration_identifier='osgard-core-'+suffix,
                            line_items=[dict(price_data=dict(currency=order['currency'].lower(),unit_amount=order['amount_minor'],product_data={'name':order['title']}),quantity=1)],
                            success_url=self.config.public_origin+'/purchases?order='+order_id+'&checkout=returned',
                            cancel_url=self.config.public_origin+'/purchases?order='+order_id+'&checkout=cancelled')
                db.execute('INSERT INTO commerce_checkout_ops(id,order_id,provider_key,params,state,started_at,lease_until) VALUES(?,?,?,?,?,?,?)',
                           (operation_id,order_id,'osgard-checkout-'+operation_id,encoded(params),'calling',time.time(),time.time()+LEASE_SECONDS))
            else:
                operation_id=operation['id']
                db.execute("UPDATE commerce_checkout_ops SET state='calling',lease_until=? WHERE id=?",(time.time()+LEASE_SECONDS,operation_id))
            db.execute("UPDATE commerce_orders SET state='checkout_pending',version=version+1,updated_at=? WHERE id=?",(now(),order_id))
            operation=dict(db.execute('SELECT * FROM commerce_checkout_ops WHERE id=?',(operation_id,)).fetchone()); order=dict(order)
        try:
            session=self.provider().create_checkout(json.loads(operation['params']),operation['provider_key'])
            self.validate_object(session,order,operation_id,session=True)
            session_id=identifier(session.get('id'),'cs_'); url=session.get('url') or ''
            parsed=urlsplit(url)
            require(parsed.scheme=='https' and parsed.netloc=='checkout.stripe.com', 'Stripe не вернул допустимый Checkout URL.', 'stripe_checkout_url', 503)
        except Exception:
            with self.store.transaction() as db:
                db.execute("UPDATE commerce_checkout_ops SET state=CASE WHEN session_id IS NULL THEN 'unknown' ELSE state END,lease_until=0,last_error='provider_result_unknown' WHERE id=?",(operation_id,))
            raise Fault('checkout_unknown','Результат запроса Stripe неизвестен. Повтор использует тот же заказ и тот же ключ; новый Checkout не создаётся.',503)
        with self.store.transaction() as db:
            current=db.execute('SELECT session_id FROM commerce_checkout_ops WHERE id=?',(operation_id,)).fetchone()
            require(current['session_id'] in (None,session_id),'Получены разные Checkout для одной операции. Нужна сверка.', 'reconciliation_required',409)
            db.execute("UPDATE commerce_checkout_ops SET state='ready',session_id=?,checkout_url=?,lease_until=0,last_error=NULL WHERE id=?",(session_id,url,operation_id))
            db.execute("UPDATE commerce_orders SET state=CASE WHEN state IN ('prepared','checkout_pending') AND paid_minor=0 AND refunded_minor=0 THEN 'checkout_open' ELSE state END,version=version+1,updated_at=? WHERE id=?",(now(),order_id))
            state=db.execute('SELECT state FROM commerce_orders WHERE id=?',(order_id,)).fetchone()['state']
            self.store.event(db,order['project_id'],actor,'commerce_checkout_ready',dict(orderId=order_id))
        return dict(orderId=order_id,url=url if state=='checkout_open' else None,reused=False,
                    pending=state=='payment_processing',closed=state in ('paid','partially_refunded','refunded','expired','failed','cancelled'),status=state)

    def paid_charge(self, intent, order, operation_id):
        self.validate_object(intent,order,operation_id)
        require(intent.get('status')=='succeeded' and intent.get('amount_received')==order['amount_minor'], 'Платёж Stripe ещё не подтверждён полностью.', 'payment_not_settled',409)
        charge=self.provider().retrieve_charge(identifier(intent.get('latest_charge'),'ch_'))
        require(charge.get('livemode') is self.config.livemode and charge.get('payment_intent')==intent['id'] and charge.get('paid') is True and charge.get('captured') is True and charge.get('amount')==order['amount_minor'] and charge.get('currency')==order['currency'].lower(),
                'Списание Stripe не соответствует заказу.', 'stripe_charge',409)
        refunded=0;pending=False;records=self.provider().refunds_for_charge(charge['id'])
        for refund in records:
            require(refund.get('charge')==charge['id'] and refund.get('currency')==order['currency'].lower() and type(refund.get('amount')) is int and refund['amount']>0, 'Возврат не соответствует списанию.', 'stripe_refund',409)
            if refund.get('status')=='succeeded':refunded+=refund['amount']
            elif refund.get('status') not in ('failed','canceled'):pending=True
        require(refunded<=order['amount_minor'], 'Возвраты превышают сумму заказа.', 'stripe_refund',409)
        charge['hasPendingRefunds']=pending
        charge['refundRecords']=records
        return charge,refunded

    def reconcile_refund_operations(self, db, order, charge):
        """Bind a refund arriving before its create response using trusted metadata."""
        for refund in charge['refundRecords']:
            metadata=refund.get('metadata') or {}
            operation=db.execute('SELECT * FROM commerce_refund_ops WHERE order_id=? AND (refund_id=? OR id=?)',
                                 (order['id'],refund.get('id'),metadata.get('osgard_refund_operation'))).fetchone()
            if not operation:continue
            params=json.loads(operation['params'])
            require(metadata.get('osgard_order_id')==order['id'] and metadata.get('osgard_refund_operation')==operation['id']
                    and refund.get('payment_intent')==params['payment_intent'] and refund['amount']==params['amount']
                    and operation['refund_id'] in (None,refund.get('id')),
                    'Возврат не соответствует сохранённой операции.', 'stripe_refund',409)
            refund_id=identifier(refund.get('id'),'re_')
            failed=refund.get('status') in ('failed','canceled')
            db.execute("UPDATE commerce_refund_ops SET refund_id=?,state=CASE WHEN state IN ('confirmed','failed') THEN state WHEN ? THEN 'failed' ELSE 'awaiting_webhook' END,lease_until=0 WHERE id=?",
                       (refund_id,int(failed),operation['id']))

    def webhook(self, raw, signature):
        self.enabled()
        event=verify_webhook(raw,signature,self.config.webhook_secret)
        event_id=identifier(event.get('id'),'evt_'); body_hash=sha(raw)
        require(event.get('object')=='event' and event.get('api_version')==API_VERSION, 'Нужен snapshot webhook согласованной версии API.', 'webhook_version')
        require(event.get('livemode') is self.config.livemode and event.get('account') in (None,self.config.account_id), 'Webhook другого аккаунта или режима.', 'webhook_tenant',403)
        event_type=event.get('type'); data=event.get('data')
        require(isinstance(data,dict),'Неверные данные webhook.')
        obj=data.get('object',{})
        require(isinstance(obj,dict), 'Неверный объект webhook.')
        with self.store.connect() as db:
            previous=db.execute('SELECT body_sha256 FROM commerce_webhook_events WHERE id=?',(event_id,)).fetchone()
            if previous:
                require(previous['body_sha256']==body_hash,'ID webhook повторно использован с другим содержимым.','webhook_conflict',409)
                return dict(received=True,replayed=True)
        session_events={'checkout.session.completed','checkout.session.async_payment_succeeded','checkout.session.async_payment_failed','checkout.session.expired'}
        refund_events={'charge.refunded','refund.created','refund.updated','refund.failed','charge.refund.updated'}
        if event_type not in session_events|refund_events:
            return dict(received=True,ignored=True)
        try:
            session=None; intent=None; charge=None; refunded=0; fulfill=False
            if event_type in session_events:
                session=self.provider().retrieve_session(identifier(obj.get('id'),'cs_'))
                metadata=session.get('metadata',{})
            else:
                charge_id=obj.get('id') if event_type=='charge.refunded' else obj.get('charge')
                charge=self.provider().retrieve_charge(identifier(charge_id,'ch_'))
                intent=self.provider().retrieve_intent(identifier(charge.get('payment_intent'),'pi_'))
                metadata=intent.get('metadata',{})
            order_id=identifier(metadata.get('osgard_order_id'))
            with self.store.connect() as db:
                record=db.execute('SELECT * FROM commerce_orders WHERE id=?',(order_id,)).fetchone()
                operation=db.execute('SELECT * FROM commerce_checkout_ops WHERE order_id=?',(order_id,)).fetchone()
                require(record is not None and operation is not None,'Заказ webhook не найден.','webhook_order',409)
                order=dict(record); operation=dict(operation)
            require(order['account_id']==self.config.account_id and bool(order['livemode'])==self.config.livemode,'Заказ другого аккаунта.','webhook_tenant',403)
            if session:
                self.validate_object(session,order,operation['id'],session=True)
                require(operation['session_id'] in (None,session['id']),'Checkout ID не совпадает.','stripe_session',409)
                fulfill=event_type in {'checkout.session.completed','checkout.session.async_payment_succeeded'} and session.get('payment_status')=='paid' and session.get('status')=='complete'
                if fulfill:
                    intent=self.provider().retrieve_intent(identifier(session.get('payment_intent'),'pi_'))
            if intent:
                charge,refunded=self.paid_charge(intent,order,operation['id'])
                if event_type in refund_events:
                    require(charge['id']==charge_id,'Возврат относится к другому списанию.','stripe_charge',409)
        except Fault:
            raise
        except Exception:
            raise Fault('stripe_unavailable','Не удалось сверить webhook со Stripe. Повторите событие.',503)
        with self.store.transaction() as db:
            previous=db.execute('SELECT body_sha256 FROM commerce_webhook_events WHERE id=?',(event_id,)).fetchone()
            if previous:
                require(previous['body_sha256']==body_hash,'Повторный ID с другим содержимым.','webhook_conflict',409)
                return dict(received=True,replayed=True)
            current=db.execute('SELECT * FROM commerce_orders WHERE id=?',(order_id,)).fetchone()
            paid=max(current['paid_minor'],order['amount_minor'] if intent else 0)
            refund_total=max(current['refunded_minor'],refunded)
            confirmed=bool(current['checkout_confirmed']) or fulfill
            state=current['state']
            if refund_total>=order['amount_minor']:state='refunded'
            elif refund_total:state='partially_refunded'
            elif confirmed:state='paid'
            elif event_type=='checkout.session.expired' and not paid:state='expired'
            elif event_type=='checkout.session.async_payment_failed' and not paid:state='failed'
            elif session and session.get('payment_status')!='paid' and not paid and state not in ('expired','failed','cancelled'):state='payment_processing'
            payment_intent=intent['id'] if intent else current['payment_intent']
            require(current['payment_intent'] in (None,payment_intent),'PaymentIntent изменился.','stripe_intent',409)
            db.execute('UPDATE commerce_orders SET paid_minor=?,refunded_minor=?,checkout_confirmed=?,payment_intent=?,charge_id=?,state=?,version=version+1,updated_at=? WHERE id=?',
                       (paid,refund_total,int(confirmed),payment_intent,charge['id'] if charge else current['charge_id'],state,now(),order_id))
            if session:
                current_operation=db.execute('SELECT session_id FROM commerce_checkout_ops WHERE id=?',(operation['id'],)).fetchone()
                require(current_operation['session_id'] in (None,session['id']),'Checkout ID изменился во время сверки.','stripe_session',409)
                db.execute("UPDATE commerce_checkout_ops SET session_id=?,state='ready',lease_until=0 WHERE id=?",(session['id'],operation['id']))
            active=confirmed and paid==order['amount_minor'] and refund_total<order['amount_minor'] and state!='refunded'
            if active:
                db.execute('INSERT INTO commerce_entitlements VALUES(?,?,1,?,NULL) ON CONFLICT(order_id) DO UPDATE SET active=1', (order_id,order['buyer_id'],now()))
            elif refund_total>=order['amount_minor']:
                db.execute('INSERT INTO commerce_entitlements VALUES(?,?,0,NULL,?) ON CONFLICT(order_id) DO UPDATE SET active=0,revoked_at=excluded.revoked_at',(order_id,order['buyer_id'],now()))
            if charge:self.reconcile_refund_operations(db,order,charge)
            db.execute("UPDATE commerce_refund_ops SET state='confirmed',lease_until=0 WHERE order_id=? AND target_minor<=?",(order_id,refund_total))
            db.execute('INSERT INTO commerce_webhook_events VALUES(?,?,?,?,?)',(event_id,body_hash,event_type,order_id,now()))
            self.store.event(db,order['project_id'],order['merchant_id'],'commerce_webhook_applied',dict(orderId=order_id,eventId=event_id,state=state))
        return dict(received=True,replayed=False)

    def refund(self, order_id, actor, target):
        self.enabled()
        require(type(target) is int and target>0,'Укажите суммарную сумму возврата в минимальных единицах.')
        with self.store.connect() as db:
            preliminary=dict(self.access(db,order_id,actor,merchant=True))
            existing=db.execute("SELECT 1 FROM commerce_refund_ops WHERE order_id=? AND state!='confirmed'",(order_id,)).fetchone()
        if not existing and preliminary['payment_intent'] and target>preliminary['refunded_minor']:
            try:
                intent=self.provider().retrieve_intent(preliminary['payment_intent'])
                with self.store.connect() as db:
                    operation=db.execute('SELECT id FROM commerce_checkout_ops WHERE order_id=?',(order_id,)).fetchone()
                remote,refunded=self.paid_charge(intent,preliminary,operation['id'])
                require(refunded==preliminary['refunded_minor'] and not remote['hasPendingRefunds'],
                        'В Stripe есть ещё не применённый или незавершённый возврат. Дождитесь webhook перед новым запросом.', 'refund_reconciliation',409)
            except Fault:raise
            except Exception:raise Fault('stripe_unavailable','Не удалось сверить остаток возврата со Stripe.',503)
        with self.store.transaction() as db:
            order=self.access(db,order_id,actor,merchant=True)
            require(order['paid_minor']==order['amount_minor'] and order['payment_intent'],'Сначала подтвердите оплату webhook.','payment_required',409)
            require(target<=order['amount_minor'],'Возврат превышает сумму заказа.')
            if target<=order['refunded_minor']:return dict(orderId=order_id,confirmed=True,refundedMinor=order['refunded_minor'])
            pending=db.execute("SELECT * FROM commerce_refund_ops WHERE order_id=? AND state!='confirmed' ORDER BY started_at DESC LIMIT 1",(order_id,)).fetchone()
            require(pending is not None or order['refunded_minor']==preliminary['refunded_minor'],'Состояние возвратов изменилось. Обновите заказ.','version_conflict',409)
            require(pending is None or pending['state']!='failed','Stripe сообщил о неуспешном возврате. Нужна ручная сверка перед новой операцией.','refund_reconciliation',409)
            require(pending is None or pending['target_minor']==target,'Сначала завершите сверку предыдущего возврата.','refund_pending',409)
            if pending and pending['refund_id']:return dict(orderId=order_id,confirmed=False,awaitingWebhook=True)
            require(pending is None or pending['lease_until']<time.time(),'Возврат уже запрашивается.','refund_in_progress',409)
            require(pending is None or time.time()-pending['started_at']<RETRY_WINDOW,'Старый возврат нужно сверить со Stripe; новый запрос не создаётся.','reconciliation_required',409)
            if pending is None:
                operation_id=uid();params=dict(payment_intent=order['payment_intent'],amount=target-order['refunded_minor'],metadata=dict(osgard_order_id=order_id,osgard_refund_operation=operation_id))
                db.execute('INSERT INTO commerce_refund_ops(id,order_id,target_minor,provider_key,params,state,started_at,lease_until) VALUES(?,?,?,?,?,?,?,?)',(operation_id,order_id,target,'osgard-refund-'+operation_id,encoded(params),'calling',time.time(),time.time()+LEASE_SECONDS))
            else:
                operation_id=pending['id'];db.execute("UPDATE commerce_refund_ops SET state='calling',lease_until=? WHERE id=?",(time.time()+LEASE_SECONDS,operation_id))
            operation=dict(db.execute('SELECT * FROM commerce_refund_ops WHERE id=?',(operation_id,)).fetchone())
        try:
            result=self.provider().create_refund(json.loads(operation['params']),operation['provider_key'])
            refund_id=identifier(result.get('id'),'re_')
            params=json.loads(operation['params'])
            require(result.get('payment_intent')==order['payment_intent'] and result.get('amount')==params['amount'] and result.get('currency')==order['currency'].lower() and result.get('metadata')==params['metadata'],'Stripe вернул другой возврат.','stripe_refund',409)
        except Exception:
            with self.store.transaction() as db:
                db.execute("UPDATE commerce_refund_ops SET state=CASE WHEN state IN ('confirmed','failed') THEN state ELSE 'unknown' END,lease_until=0,last_error='provider_result_unknown' WHERE id=?",(operation_id,))
            raise Fault('refund_unknown','Результат запроса возврата неизвестен. Повтор использует прежний ключ; новый возврат не создаётся.',503)
        with self.store.transaction() as db:
            db.execute("UPDATE commerce_refund_ops SET refund_id=?,state=CASE WHEN state IN ('confirmed','failed') THEN state WHEN ? THEN 'failed' ELSE 'awaiting_webhook' END,lease_until=0,last_error=NULL WHERE id=?",(refund_id,int(result.get('status') in ('failed','canceled')),operation_id))
            state=db.execute('SELECT state FROM commerce_refund_ops WHERE id=?',(operation_id,)).fetchone()['state']
            self.store.event(db,order['project_id'],actor,'commerce_refund_requested',dict(orderId=order_id,targetMinor=target))
        return dict(orderId=order_id,confirmed=state=='confirmed',awaitingWebhook=state=='awaiting_webhook',failed=state=='failed')

    def download(self, db, order_id, actor):
        order=self.access(db,order_id,actor)
        require(json.loads(order['envelope']).get('kind', 'html_release') == 'html_release',
                'Учебная программа открывается в личной практике, а не через скачивание HTML.', 'wrong_order_kind', 409)
        entitlement=db.execute('SELECT active FROM commerce_entitlements WHERE order_id=? AND buyer_id=?',(order_id,actor)).fetchone()
        require(entitlement and entitlement['active'] and order['refunded_minor']<order['amount_minor'],'Доступ к файлу не выдан или отозван после полного возврата.','payment_required',403)
        envelope=json.loads(order['envelope'])
        require(sha(order['envelope'])==order['envelope_sha256'] and sha(envelope['html'])==envelope['sha256'],'Сохранённый оплаченный файл повреждён.','integrity_mismatch',409)
        return dict(orderId=order_id,title=envelope['title'],html=envelope['html'],sha256=envelope['sha256'])

    def guard_draft_cancellation(self, db, project_id, draft_id):
        require(db.execute('SELECT 1 FROM commerce_orders WHERE project_id=? AND source_order_id=?',(project_id,draft_id)).fetchone() is None,
                'Черновик уже связан с Commerce. После оплаты используйте проверяемый возврат; отмена черновика не отменяет Stripe.', 'commerce_order_bound',409)

    def execute(self, route, actor, payload, key):
        require(isinstance(key,str) and re.fullmatch('[a-zA-Z0-9_-]{16,100}',key),'Нужен уникальный ключ операции.')
        match=re.fullmatch(r'commerce/orders/([a-f0-9]{32})/(checkout|refund)',route)
        require(match is not None,'Маршрут Commerce не найден.','not_found',404)
        order_id,action=match.groups(); fingerprint=sha(encoded(dict(route=route,payload=payload)))
        with self.store.transaction() as db:
            self.access(db,order_id,actor,merchant=action=='refund')
            previous=db.execute('SELECT * FROM commerce_requests WHERE user_id=? AND key=?',(actor,key)).fetchone()
            if previous:
                require(previous['request_hash']==fingerprint,'Ключ уже использован для другого запроса.','idempotency_conflict',409)
                if previous['response']:return dict(json.loads(previous['response']),replayed=True)
            else:
                require(db.execute('SELECT COUNT(*) FROM commerce_requests WHERE user_id=?',(actor,)).fetchone()[0]<10000,'Лимит операций Commerce.',status=409)
                db.execute('INSERT INTO commerce_requests VALUES(?,?,?,NULL)',(actor,key,fingerprint))
        result=self.checkout(order_id,actor) if action=='checkout' else self.refund(order_id,actor,payload.get('targetRefundMinor'))
        with self.store.transaction() as db:
            db.execute('UPDATE commerce_requests SET response=? WHERE user_id=? AND key=?',(encoded(result),actor,key))
        return result
