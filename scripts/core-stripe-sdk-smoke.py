#!/usr/bin/env python3
"""Exercise the pinned SDK adapter through its actual HTTP transport, without network."""
from pathlib import Path
from unittest.mock import patch
from urllib.parse import urlsplit
import json
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'server'))
from stripe import RequestsClient
from core_commerce import API_VERSION, Config, StripeProvider

requests = []


def fake_request(_client, method, url, headers, post_data=None, **_kwargs):
    parsed = urlsplit(url)
    assert parsed.scheme == 'https' and parsed.hostname == 'api.stripe.com'
    requests.append((method.lower(), parsed.path, {key.lower(): value for key, value in headers.items()}))
    if parsed.path == '/v1/account':
        value = {'id': 'acct_fixture', 'object': 'account'}
    elif parsed.path == '/v1/checkout/sessions':
        value = {'id': 'cs_test_fixture', 'object': 'checkout.session', 'url': 'https://checkout.stripe.com/c/pay/cs_test_fixture'}
    elif parsed.path.startswith('/v1/checkout/sessions/'):
        value = {'id': 'cs_test_fixture', 'object': 'checkout.session', 'payment_status': 'unpaid'}
    elif parsed.path.startswith('/v1/payment_intents/'):
        value = {'id': 'pi_fixture', 'object': 'payment_intent', 'status': 'succeeded'}
    elif parsed.path.startswith('/v1/charges/'):
        value = {'id': 'ch_fixture', 'object': 'charge', 'paid': True}
    elif parsed.path == '/v1/refunds' and method.lower() == 'get':
        value = {'object': 'list', 'data': [{'id': 're_fixture', 'object': 'refund', 'status': 'succeeded', 'amount': 100}], 'has_more': False, 'url': '/v1/refunds'}
    elif parsed.path == '/v1/refunds':
        value = {'id': 're_fixture', 'object': 'refund', 'status': 'succeeded', 'amount': 100}
    else:
        raise AssertionError('Unexpected SDK request path: ' + parsed.path)
    return json.dumps(value), 200, {'request-id': 'req_offline_fixture'}


config = Config(enabled=True, account_id='acct_fixture', api_key='sk_test_' + '0' * 32)
with patch.object(RequestsClient, 'request', fake_request):
    provider = StripeProvider(config)
    assert provider.create_checkout({'mode': 'payment'}, 'fixture-checkout')['id'] == 'cs_test_fixture'
    assert provider.retrieve_session('cs_test_fixture')['payment_status'] == 'unpaid'
    assert provider.retrieve_intent('pi_fixture')['status'] == 'succeeded'
    assert provider.retrieve_charge('ch_fixture')['paid'] is True
    assert provider.refunds_for_charge('ch_fixture')[0]['amount'] == 100
    assert provider.create_refund({'charge': 'ch_fixture', 'amount': 100}, 'fixture-refund')['id'] == 're_fixture'

assert len(requests) == 7, 'Account verification must be reused within this adapter'
assert requests[0][1] == '/v1/account', 'The current-account SDK method must use its documented route'
assert all(item[2].get('stripe-version') == API_VERSION for item in requests)
assert requests[1][2].get('idempotency-key') == 'fixture-checkout'
assert requests[-1][2].get('idempotency-key') == 'fixture-refund'
print('PASS Stripe 15.6.0 adapter: real SDK imports, account/Checkout/intent/charge/refund methods, API version and idempotency headers; 7 intercepted requests, no network or payments')
