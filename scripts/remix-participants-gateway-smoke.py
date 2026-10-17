#!/usr/bin/env python3
"""Two real Core participants through a disposable loopback Nginx/guard fixture.

Temporary mode-0600 session state only bridges the fixture's guard restarts.
The caller removes that directory and both QA volumes. No production URL works.
"""
import http.client
import json
import os
from pathlib import Path
import secrets
import sys
from urllib.parse import urlsplit


base, stage, state_path = sys.argv[1:]
parsed = urlsplit(base)
assert parsed.scheme == 'http' and parsed.hostname == '127.0.0.1' and parsed.port
assert not parsed.path.strip('/') and not parsed.username and not parsed.query and not parsed.fragment
state_file = Path(state_path)
checks = 0


def request(method, path, expected=200, body=None, token=None, key=None):
    global checks
    assert path.startswith('/api/') and '\r' not in path and '\n' not in path
    headers = {'Host': 'osgard.world', 'Origin': 'https://osgard.world', 'Accept': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    if key:
        headers['Idempotency-Key'] = key
    if body is not None:
        headers['Content-Type'] = 'application/json'
    connection = http.client.HTTPConnection(parsed.hostname, parsed.port, timeout=12)
    try:
        connection.request(method, path, json.dumps(body).encode() if body is not None else None, headers)
        response = connection.getresponse()
        raw = response.read(1_048_577)
        assert response.status == expected, (stage, method, path, response.status, expected)
        assert len(raw) <= 1_048_576 and 'application/json' in response.getheader('Content-Type', '')
        assert 'no-store' in response.getheader('Cache-Control', '')
        checks += 1
        return raw
    finally:
        connection.close()


def obj(*args, **kwargs):
    return json.loads(request(*args, **kwargs))


def save(value):
    descriptor = os.open(state_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'w') as output:
        json.dump(value, output)


if stage == 'active':
    caps = obj('GET', '/api/remix/v2/capabilities')
    assert caps['participantPolicyVersion'] == 1 and caps['participantAdmissionEnabled'] is True
    people = {}
    for name in ('owner', 'participant', 'outsider'):
        people[name] = obj('POST', '/api/core/auth/register', body=dict(
            username='qa_participants_' + name + '_' + secrets.token_hex(6), password=secrets.token_urlsafe(32)))
    owner, member, outsider = (people[name] for name in ('owner', 'participant', 'outsider'))
    challenge = obj('POST', '/api/remix/v1/challenges', 201, dict(
        creatorId='qa-participant-fixture', title='Isolated two-participant fixture', mode='speed', seed=20261017, visibility='private'))
    match = obj('POST', '/api/remix/v2/matches', 201, dict(challengeId=challenge['id'], maxPlayers=2),
                owner['token'], secrets.token_hex(16))
    route = '/api/remix/v2/matches/' + match['id']
    old = '/api/remix/v1/matches/' + match['id']
    for prefix in (route, old):
        request('GET', prefix + '/state', 401)
        request('GET', prefix + '/state', 403, token=member['token'])
    invite_key = secrets.token_hex(16)
    invited = obj('POST', route + '/invitations', 201, dict(recipientAccountId=member['user']['id']), owner['token'], invite_key)
    invitation = invited['invitation']
    invite_route = '/api/remix/v2/invitations/' + invitation['id']
    assert invited['status'] == 'ready' and invited['operation'] == 'invite'
    assert obj('GET', '/api/remix/v2/admission-attempts/' + invite_key, token=owner['token']) == invited
    request('GET', invite_route, 401)
    request('GET', invite_route, 403, token=outsider['token'])
    preview = obj('GET', invite_route, token=member['token'])
    assert preview['recipientAccountId'] == member['user']['id'] and preview['admissionAllowed'] is True
    request('POST', invite_route + '/accept', 403, {}, outsider['token'], secrets.token_hex(16))
    accept_key = secrets.token_hex(16)
    accepted = obj('POST', invite_route + '/accept', 201, {}, member['token'], accept_key)
    assert accepted['status'] == 'ready' and accepted['invitation']['status'] == 'accepted'
    participant_match = accepted['match']
    assert participant_match['id'] == match['id'] and participant_match['playerId'] != match['playerId']
    assert participant_match['role'] == 'participant' and participant_match['participantCount'] == 2
    assert obj('GET', '/api/remix/v2/admission-attempts/' + accept_key, token=member['token']) == accepted
    for account, own_match in ((owner, match), (member, participant_match)):
        token = account['token']
        command = dict(playerId=own_match['playerId'], sequence=1, moveX=1, moveY=0, jump=False)
        reply = obj('POST', route + '/input', body=command, token=token)
        assert reply['playerId'] == own_match['playerId'] and reply['lastSequence'] == 1
        request('POST', route + '/input', 409, command, token)
        metadata = obj('GET', route, token=token)
        assert metadata['highestSubmittedSequence'] == 1 and metadata['participantCount'] == 2
        assert obj('GET', '/api/remix/v2/matches', token=token)['matches'] == [metadata]
    request('POST', old + '/input', 403, dict(playerId=match['playerId'], sequence=2, moveX=1, moveY=0, jump=False), member['token'])
    request('GET', old + '/state', 403, token=outsider['token'])
    assert obj('GET', '/api/remix/v2/matches', token=outsider['token'])['matches'] == []
    evidence = obj('GET', '/api/remix/__fixture/ownership-evidence')
    assert evidence == dict(creates=1, inputs=2, credentialHeaders=0), evidence
    assert obj('GET', '/api/remix/health')['schemaVersion'] == 3
    save(dict(ownerToken=owner['token'], participantToken=member['token'], outsiderToken=outsider['token'],
              match=match, participantMatch=participant_match, invitationId=invitation['id'], acceptKey=accept_key))
else:
    saved = json.loads(state_file.read_text())
    owner, member, outsider = saved['ownerToken'], saved['participantToken'], saved['outsiderToken']
    route = '/api/remix/v2/matches/' + saved['match']['id']
    old = '/api/remix/v1/matches/' + saved['match']['id']
    if stage in ('finalized', 'restored', 'legacy-offline'):
        result = request('GET', route + '/result', token=owner).decode()
        value = json.loads(result)
        assert value['phase'] == 'RESULTS' and value['replayFrames'] == 2
        assert {item['playerId'] for item in value['scores']} == {saved['match']['playerId'], saved['participantMatch']['playerId']}
        assert len(value['scores']) == 2
        if stage == 'finalized':
            saved['result'] = result
            save(saved)
        else:
            assert result == saved['result'], 'Frozen two-player result changed after restart/outage'
        for prefix in (route, old):
            request('GET', prefix + '/result', 401)
            request('GET', prefix + '/result', 403, token=outsider)
            for token in (owner, member):
                assert request('GET', prefix + '/result', token=token).decode() == result
                assert obj('GET', prefix + '/state', token=token)['players'] == 2
        for token, role in ((owner, 'owner'), (member, 'participant')):
            metadata = obj('GET', route, token=token)
            assert metadata['role'] == role and metadata['highestSubmittedSequence'] == 1
            request('POST', route + '/input', 409, dict(sequence=2, moveX=1, moveY=0, jump=False), token)
        assert request('GET', route + '/result', token=member).decode() == result
        if stage == 'restored':
            caps = obj('GET', '/api/remix/v2/capabilities')
            assert caps['participantPolicyVersion'] == 1 and caps['participantAdmissionEnabled'] is False
            assert caps['creationEnabled'] is False and obj('GET', '/api/remix/health')['schemaVersion'] == 3
            recovery = obj('GET', '/api/remix/v2/admission-attempts/' + saved['acceptKey'], token=member)
            assert recovery['match']['playerId'] == saved['participantMatch']['playerId']
            assert recovery['match']['highestSubmittedSequence'] == 1
    elif stage == 'core-offline':
        for prefix in (route, old):
            request('GET', prefix + '/result', 401)
            for token in (owner, member):
                request('GET', prefix + '/result', 503, token=token)
    elif stage == 'logout':
        for token in (owner, member, outsider):
            request('POST', '/api/core/auth/logout', body={}, token=token)
        for token in (owner, member):
            request('GET', route + '/result', 401, token=token)
            request('GET', old + '/result', 401, token=token)
    else:
        raise AssertionError('Unknown participant fixture stage')

print(f'PASS REMIX participant gateway {stage}: {checks} real HTTP assertions; disposable accounts and engine fixture only')
