#!/usr/bin/env python3
"""Bounded INHERIT acceptance on new QA accounts only; default is read-only.

Writes require --exercise-inherit and the exact published 12-character release.
No POST is retried. Credentials remain in memory; only redacted evidence is saved.
"""
import argparse
import datetime as dt
import importlib.util
import json
from pathlib import Path
import re
import secrets
import sys
import time


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


transport = module('_inherit_fixed_proxy', 'with-remix-runtime-proxy.py')
deadlines = module('_inherit_request_deadline', 'remix-owned-live-smoke.py')
API = '/api/core/inherit/v1/'


class ProbeFailure(Exception):
    pass


def require(value, message):
    if not value:
        raise ProbeFailure(message)


class Probe:
    def __init__(self, connection, expected_release=''):
        self.connection = connection
        self.expected_release = expected_release
        self.started = time.monotonic()
        self.deadline = self.started + 100
        self.tokens, self.logout_attempted, self.closed_tokens = [], set(), set()
        self.report = dict(schemaVersion=1, origin='https://osgard.world', status='running',
                           startedAt=dt.datetime.now(dt.timezone.utc).isoformat(),
                           requests=[], checks=[], authOutcomeUncertain=False,
                           limits=['Two new QA accounts and one private QA world remain after this run',
                                   'No external messages, existing user data, POST retry or credential file',
                                   'GET recovery is checked after received responses; no live connection is intentionally dropped',
                                   'This run does not restart production or verify browser rendering',
                                   'An unknown authentication response can leave an unknown session until expiry'])

    def request(self, method, path, *, body=None, token=None, key=None, expected=200, cleanup=False):
        require(method in ('GET', 'POST') and isinstance(path, str) and path.startswith('/')
                and not re.search(r'[\r\n]', path), 'Invalid QA request')
        require(len(self.report['requests']) < (80 if cleanup else 72), 'QA request limit reached')
        remaining = self.deadline - time.monotonic()
        require(cleanup or remaining > 0, 'QA deadline reached')
        if token:
            require(path in ('/api/core/auth/me', '/api/core/auth/logout') or
                    re.fullmatch(r'/api/core/inherit/v1/[A-Za-z0-9_/-]+', path), 'Credential destination rejected')
        timeout = 5 if cleanup else min(12, remaining)
        deadline = time.monotonic() + timeout
        headers = {'Accept': 'application/json', 'Origin': 'https://osgard.world',
                   'Cache-Control': 'no-cache', 'User-Agent': 'OSGARD-INHERIT-acceptance/1'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        if key:
            headers['Idempotency-Key'] = key
        raw_body = None
        if body is not None:
            headers['Content-Type'] = 'application/json'
            raw_body = json.dumps(body, allow_nan=False).encode()
        entry = dict(method=method, path=path, outcome='pending')
        self.report['requests'].append(entry)
        if method == 'POST' and path == '/api/core/auth/register':
            self.report['authOutcomeUncertain'] = True
        try:
            with deadlines.request_timeout(timeout):
                connection = self.connection('osgard.world', timeout=timeout)
                try:
                    connection.request(method, path, raw_body, headers)
                    response = connection.getresponse()
                    raw = response.read(1_048_577)
                    entry.update(status=response.status, bytes=len(raw))
                    require(response.status in ((expected,) if isinstance(expected, int) else expected),
                            f'{method} {path}: unexpected HTTP {response.status}')
                    require(len(raw) <= 1_048_576, 'QA response limit reached')
                    if path == '/':
                        require('text/html' in response.getheader('Content-Type', ''), 'Release response is not HTML')
                        markers = set(re.findall(rb'/brand/osa-transition\.js\?v=([a-f0-9]{12})', raw))
                        require(len(markers) == 1, 'Published release marker is missing or ambiguous')
                        value = markers.pop().decode()
                        require(not self.expected_release or value == self.expected_release, 'Published release changed')
                    else:
                        require('application/json' in response.getheader('Content-Type', '') and
                                'no-store' in response.getheader('Cache-Control', ''), 'API response/cache contract failed')
                        value = json.loads(raw, parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
                        require(isinstance(value, dict), 'API response is not an object')
                finally:
                    connection.close()
            require(time.monotonic() < deadline and (cleanup or time.monotonic() < self.deadline), 'QA request deadline reached')
            entry['outcome'] = 'received'
            return value
        except BaseException as error:
            entry.update(outcome='uncertain' if method == 'POST' else 'failed', errorType=type(error).__name__)
            raise

    def check(self, label, condition=True):
        require(condition, label)
        self.report['checks'].append(label)

    def account(self, suffix):
        username = 'qa_inherit_' + suffix + '_' + secrets.token_hex(8)
        response = self.request('POST', '/api/core/auth/register', body=dict(
            username=username, password=secrets.token_urlsafe(32)))
        token = response.get('token')
        require(isinstance(token, str) and re.fullmatch(r'[A-Za-z0-9_-]{40,100}', token), 'Core returned no valid QA session')
        self.tokens.append(token)
        self.report['authOutcomeUncertain'] = False
        registered = response.get('user')
        require(isinstance(registered, dict) and isinstance(registered.get('id'), str)
                and re.fullmatch(r'[a-f0-9]{32}', registered['id']) and registered.get('username') == username,
                'Core did not confirm the newly registered QA identity')
        actor = self.request('GET', '/api/core/auth/me', token=token).get('user')
        require(isinstance(actor, dict) and actor.get('id') == registered['id'] and actor.get('username') == username,
                'Core returned no verified QA account')
        return token, actor['id']

    def logout(self, token):
        if token in self.logout_attempted:
            return
        self.logout_attempted.add(token)
        result = self.request('POST', '/api/core/auth/logout', token=token, body={}, expected=(200, 401), cleanup=True)
        require(self.report['requests'][-1].get('status') == 401 or result.get('loggedOut') is True,
                'Core did not confirm QA session logout')
        self.closed_tokens.add(token)

    def cleanup(self):
        for token in self.tokens:
            try:
                self.logout(token)
            except Exception:
                pass
        self.report['allQaSessionsLoggedOut'] = len(self.closed_tokens) == len(set(self.tokens)) and not self.report['authOutcomeUncertain']
        if not self.report['allQaSessionsLoggedOut']:
            self.report['status'] = 'FAIL'


def exercise(p):
    first, first_id = p.account('first')
    next_token, next_id = p.account('next')
    p.check('Two distinct newly registered Core QA accounts are verified', first_id != next_id and first != next_token)
    caps = p.request('GET', API + 'capabilities', token=first)
    p.check('Core confirms single-custodian immutable lineage support',
            caps.get('schemaVersion') == 1 and caps.get('permissions') == 'single-custodian-retained-history')
    create_key = secrets.token_hex(16)
    created = p.request('POST', API + 'worlds', token=first, key=create_key,
                        body=dict(title='QA INHERIT release acceptance', template='quiet-reach-v1', source='template', objects=[]))
    world = created['world']
    require(re.fullmatch(r'[a-f0-9]{32}', world['id']), 'Invalid QA world ID')
    route = API + 'worlds/' + world['id']
    p.report['worldId'] = world['id']
    p.check('New world is private and starts a separate server lineage', world['creator']['id'] == first_id and
            world['custodian']['id'] == first_id and world['currentGeneration'] == 1 and world['objects'] == [] and world['generations'] == [])
    p.request('GET', route, expected=401)
    p.request('GET', route, token=next_token, expected=404)
    p.request('GET', API + 'operations/' + create_key, token=next_token, expected=404)
    p.check('Create is recoverable only by the initiating verified account',
            p.request('GET', API + 'operations/' + create_key, token=first)['result'] == created)
    first_key = secrets.token_hex(16)
    saved = p.request('POST', route + '/generations', token=first, key=first_key, body=dict(
        expectedRevision=world['revision'], expectedGeneration=world['currentGeneration'],
        message='QA first custodian left one tree.', delta=[dict(type='tree', x=30, y=45)]))
    world = saved['world']
    first_snapshot = p.request('GET', route + '/generations/1', token=first)['generation']
    p.check('Exactly one first generation, snapshot and author are confirmed', len(world['objects']) == 1 and
            world['currentGeneration'] == 2 and saved['generation']['author']['id'] == first_id and
            p.request('GET', API + 'operations/' + first_key, token=first)['result'] == saved)
    offered = p.request('POST', route + '/handoffs', token=first, key=secrets.token_hex(16), body=dict(
        expectedRevision=world['revision'], targetUserId=next_id, sharingAcknowledged=True))
    invitation = offered['invitation']
    p.report['invitationId'] = invitation['id']
    preview = p.request('GET', API + 'handoffs/' + invitation['id'], token=next_token)
    p.check('Invitation is addressed to the second Core account and freezes editing',
            preview['invitation']['to']['id'] == next_id and offered['world']['canEdit'] is False)
    p.request('GET', route, token=next_token, expected=404)
    acceptance_key = secrets.token_hex(16)
    accepted = p.request('POST', API + 'handoffs/' + invitation['id'] + '/accept', token=next_token,
                         key=acceptance_key, body=dict(expectedRevision=invitation['expectedRevision']))
    world = accepted['world']
    p.check('Explicit acceptance switches custody and recovers from the same operation record',
            world['custodian']['id'] == next_id and world['canEdit'] is True and
            p.request('GET', API + 'operations/' + acceptance_key, token=next_token)['result'] == accepted)
    old_reader = p.request('GET', route, token=first)['world']
    p.check('Previous custodian retains history access with read-only permissions',
            old_reader['role'] == 'reader' and old_reader['canEdit'] is False)
    body = dict(expectedRevision=world['revision'], expectedGeneration=world['currentGeneration'],
                message='QA next custodian left one lantern.', delta=[dict(type='light', x=60, y=45)])
    p.request('POST', route + '/generations', token=first, key=secrets.token_hex(16), body=body, expected=403)
    second_key = secrets.token_hex(16)
    second = p.request('POST', route + '/generations', token=next_token, key=second_key, body=body)
    p.request('POST', route + '/generations', token=next_token, key=secrets.token_hex(16), body=body, expected=409)
    returned = p.request('GET', route, token=first)['world']
    p.check('New custodian creates one new generation; a stale revision cannot append another',
            returned['currentGeneration'] == 3 and len(returned['objects']) == 2 and len(returned['generations']) == 2 and
            returned['generations'][1]['author']['id'] == next_id and
            returned['generations'][1]['parentHash'] == first_snapshot['snapshotHash'])
    p.check('The previous generation snapshot remains byte-for-byte equivalent as JSON',
            p.request('GET', route + '/generations/1', token=first)['generation'] == first_snapshot)
    notifications = p.request('GET', API + 'notifications', token=first)['notifications']
    notice = next((n for n in notifications if n['kind'] == 'generation_created' and n['worldId'] == world['id'] and n['generation'] == 2), None)
    p.check('Previous custodian receives a persisted notification for the changed world', notice is not None)
    p.request('POST', API + 'notifications/' + str(notice['id']) + '/read', token=first, key=secrets.token_hex(16), body={})
    p.check('Notification can be marked read without changing the world',
            next(n for n in p.request('GET', API + 'notifications', token=first)['notifications'] if n['id'] == notice['id'])['readAt'] is not None)
    p.report['generations'] = [dict(number=g['number'], snapshotHash=g['snapshotHash'], parentHash=g['parentHash']) for g in returned['generations']]
    p.logout(first)
    p.request('GET', route, token=first, expected=401)
    p.request('GET', API + 'operations/' + first_key, token=first, expected=401)
    p.logout(next_token)
    p.request('GET', route, token=next_token, expected=401)
    p.check('Logout revokes world and operation access for both QA sessions')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exercise-inherit', action='store_true')
    parser.add_argument('--expected-release', default='')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    require(not args.expected_release or re.fullmatch(r'[a-f0-9]{12}', args.expected_release), 'Expected release must be 12 hex characters')
    require(not args.exercise_inherit or args.expected_release, 'Live writes require an expected release')
    if args.output:
        require(not args.output.exists() and not args.output.is_symlink() and args.output.parent.is_dir(), 'Evidence output must be a new file')
    try:
        connection = transport.connection_factory(transport.runtime_proxy())
    except Exception:
        print(json.dumps(dict(status='FAIL', phase='proxy-setup', requests=0)))
        return 2
    p = Probe(connection, args.expected_release)
    p.report['mode'] = 'two-qa-custodians-one-world' if args.exercise_inherit else 'read-only'
    try:
        before = p.request('GET', '/')
        p.report['release'] = before
        p.check('Published Core is healthy', p.request('GET', '/api/core/health').get('status') == 'ok')
        if args.exercise_inherit:
            exercise(p)
        p.check('Published release remained unchanged', p.request('GET', '/') == before)
        p.report['status'] = 'PASS'
    except Exception as error:
        p.report.update(status='FAIL', failure=str(error) if isinstance(error, ProbeFailure) else 'QA failure: ' + type(error).__name__)
    finally:
        p.cleanup()
        p.report.update(finishedAt=dt.datetime.now(dt.timezone.utc).isoformat(), durationSeconds=round(time.monotonic() - p.started, 3))
        evidence = json.dumps(p.report, ensure_ascii=False, indent=2) + '\n'
        require(not any(token in evidence for token in p.tokens), 'Credential detected in evidence')
        if args.output:
            with args.output.open('x') as output:
                output.write(evidence)
        print(json.dumps(dict(status=p.report['status'], requests=len(p.report['requests']), checks=len(p.report['checks']),
                              allQaSessionsLoggedOut=p.report['allQaSessionsLoggedOut'])))
    return 0 if p.report['status'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
