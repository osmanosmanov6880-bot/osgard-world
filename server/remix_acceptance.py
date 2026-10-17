"""Real HTTP acceptance helpers for a disposable, loopback REMIX server."""
from collections import deque
import json
import secrets
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

from remix_service import RULESET, verify_replay


class Actor:
    def __init__(self, base, token='', user=None):
        parsed = urlsplit(base)
        if parsed.scheme != 'http' or parsed.hostname not in ('127.0.0.1', 'localhost') or not parsed.port or parsed.path or parsed.username or parsed.query or parsed.fragment:
            raise ValueError('Acceptance writes require an explicit loopback HTTP origin.')
        self.base, self.token, self.user, self.requests = base, token, user, 0

    def request(self, route, body=None, key=None, expected=200, headers=None):
        path = route if route.startswith('/api/') else '/api/remix/v1/' + route
        request_headers = {'Accept': 'application/json'}
        if self.token:
            request_headers['Authorization'] = 'Bearer ' + self.token
        data = None
        if body is not None:
            data = json.dumps(body, separators=(',', ':'), allow_nan=False).encode()
            request_headers['Content-Type'] = 'application/json'
            request_headers['Idempotency-Key'] = key or secrets.token_hex(16)
        request_headers.update(headers or {})
        self.requests += 1
        try:
            response = urlopen(Request(self.base + path, data=data, headers=request_headers), timeout=10)
        except HTTPError as error:
            response = error
        with response:
            status = response.status
            raw = response.read(1024 * 1024 + 1)
        if len(raw) > 1024 * 1024:
            raise AssertionError('The local service exceeded its response bound.')
        try:
            value = json.loads(raw)
        except (ValueError, UnicodeError):
            raise AssertionError(f'{path} returned non-JSON HTTP {status}') from None
        if status != expected:
            # Never include credentials, response tokens or submitted bodies.
            raise AssertionError(f'{path}: expected HTTP {expected}, received {status} ({value.get("error", "unexpected response")})')
        return value


def register(base):
    actor = Actor(base)
    response = actor.request('/api/core/auth/register', dict(username='remix-' + secrets.token_hex(6), password=secrets.token_urlsafe(24)))
    actor.token, actor.user = response['token'], response['user']
    return actor


def route_to_goal(level, start):
    blocked = {(o['x'], o['y']) for o in level['objects'] if o['kind'] != 'goal'}
    goal = next((o['x'], o['y']) for o in level['objects'] if o['kind'] == 'goal')
    pending, visited = deque([(tuple(start), [])]), {tuple(start)}
    while pending:
        (x, y), path = pending.popleft()
        if (x, y) == goal:
            return path
        for dx, dy in ((1, 0), (0, 1), (0, -1), (-1, 0)):
            candidate = (x + dx, y + dy)
            if 0 <= candidate[0] < level['width'] and 0 <= candidate[1] < level['height'] and candidate not in blocked and candidate not in visited:
                pending.append((candidate, path + [(dx, dy)]))
                visited.add(candidate)
    raise AssertionError('The service created an unreachable challenge.')


def complete(actor, state):
    for dx, dy in route_to_goal(state['arena'], state['position']):
        response = actor.request('matches/' + state['id'] + '/input', dict(playerId=actor.user['id'], sequence=state['sequence'] + 1, moveX=dx, moveY=dy, jump=False))
        state = response['state']
    if state['phase'] != 'RESULTS' or not state['won']:
        raise AssertionError('Authoritative inputs did not reach the goal.')
    result = actor.request('matches/' + state['id'] + '/result')
    replay = actor.request('matches/' + state['id'] + '/replay')
    verify_replay(replay)
    if result['replayHash'] != replay['hash'] or result['timeMs'] != len(replay['inputs']) * 100:
        raise AssertionError('Result and input journal disagree.')
    return result, replay


def exercise(base, creator=None, challenger=None):
    """No fixed responses: all writes pass through Core HTTP and SQLite."""
    creator, challenger = creator or register(base), challenger or register(base)
    anonymous = Actor(base)
    checks = []

    def checked(name, condition=True):
        if not condition:
            raise AssertionError(name)
        checks.append(dict(name=name, passed=True))

    capabilities = anonymous.request('capabilities')
    checked('advertised authoritative ruleset', capabilities['ruleset'] == RULESET and capabilities['resultAuthority'] == 'server-input-journal')
    anonymous.request('challenges', dict(title='Rejected guest', seed=42), expected=401)
    checked('anonymous mutation rejected')
    key = secrets.token_hex(16)
    payload = dict(title='HTTP acceptance challenge', seed=42, mode='speed', visibility='public', creatorId=creator.user['id'])
    challenge = creator.request('challenges', payload, key=key)
    duplicate = creator.request('challenges', payload, key=key)
    checked('create retry preserves challenge identity', duplicate['id'] == challenge['id'] and duplicate['replayed'])
    creator.request('challenges', dict(payload, seed=43), key=key, expected=409)
    checked('idempotency key cannot change request')
    creator.request('challenges', dict(payload, creatorId=challenger.user['id']), expected=403)
    checked('creator identity comes from Core session')
    challenger.request('challenges/' + challenge['id'], expected=404)
    creator.request('challenges/' + challenge['id'] + '/publish', {}, expected=409)
    checked('draft remains private and requires creator proof')
    proof = creator.request('matches', dict(challengeId=challenge['id'], maxPlayers=1))
    creator.request('matches/' + proof['id'] + '/result', expected=409)
    challenger.request('matches/' + proof['id'] + '/state', expected=404)
    checked('unfinished results and another actor run are inaccessible')
    move = dict(sequence=1, moveX=1, moveY=0, jump=False)
    creator.request('matches/' + proof['id'] + '/input', dict(move, playerId=challenger.user['id']), expected=403)
    creator.request('matches/' + proof['id'] + '/input', dict(move, score=999999), expected=400)
    creator.request('matches/' + proof['id'] + '/input', dict(move, sequence=2), expected=409)
    checked('forged player, score and out-of-order input rejected')
    move_key = secrets.token_hex(16)
    first = creator.request('matches/' + proof['id'] + '/input', move, key=move_key)
    repeated = creator.request('matches/' + proof['id'] + '/input', move, key=move_key)
    repeated_sequence = creator.request('matches/' + proof['id'] + '/input', move)
    checked('input retries advance the simulation once', first['state']['sequence'] == repeated['state']['sequence'] == repeated_sequence['state']['sequence'] == 1)
    creator.request('matches/' + proof['id'] + '/input', dict(move, moveX=-1), expected=409)
    proof_result, proof_replay = complete(creator, first['state'])
    checked('creator completion has reproducible server result', proof_result['won'] and proof_result['purpose'] == 'creator-proof')
    validated = creator.request('challenges/' + challenge['id'] + '/validate', dict(matchId=proof['id']))
    published = creator.request('challenges/' + challenge['id'] + '/publish', {})
    checked('proof permits validate and publish', validated['status'] == 'VALIDATED' and published['status'] == 'PUBLISHED')
    shared = challenger.request('challenges/' + challenge['id'])
    checked('second actor receives exactly the published arena', shared['arena'] == challenge['arena'] and shared['seed'] == challenge['seed'])
    challenger.request('challenges/' + challenge['id'] + '/publish', {}, expected=403)
    run = challenger.request('matches', dict(challengeId=challenge['id'], maxPlayers=1))
    result, replay = complete(challenger, run)
    checked('second actor completes a separate authoritative run', result['won'] and result['playerId'] == challenger.user['id'])
    for suffix in ('state', 'result', 'replay'):
        creator.request('matches/' + run['id'] + '/' + suffix, expected=404)
    checked('run and replay ownership enforced')
    leaderboard = creator.request('challenges/' + challenge['id'] + '/leaderboard')
    checked('leaderboard excludes proof runs and records challenger', len(leaderboard['scores']) == 1 and leaderboard['scores'][0]['playerId'] == challenger.user['id'])
    fork = challenger.request('challenges/' + challenge['id'] + '/remix', dict(title='Second actor remix'))
    checked('remix retains parent and begins as a new owned draft', fork['parentId'] == challenge['id'] and fork['status'] == 'DRAFT' and fork['creatorId'] == challenger.user['id'])
    return dict(schemaVersion=1, status='passed', ruleset=RULESET, passed=len(checks), failed=0, checks=checks, challengeId=challenge['id'], creatorMatchId=proof['id'], challengerMatchId=run['id'], creatorReplayHash=proof_replay['hash'], challengerReplayHash=replay['hash'], httpRequests=creator.requests + challenger.requests + anonymous.requests, externalPublicationPerformed=False), creator, challenger
