#!/usr/bin/env python3
"""Bounded acceptance of two Core participants on the fixed published origin.

Default is read-only. Writes require --exercise-participants and an exact release
marker. Two newly registered, verified QA accounts and one private QA match remain.
Credentials stay in memory. A dispatched POST is never retried; the intentional
duplicate command checks use sequence 1 only to verify its rejection. No existing
user data, production restart, browser, Unity or replay validation is exercised.
"""
import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import secrets
import sys
import time
import types


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


base = module('_participants_frozen_transport', 'remix-owned-live-smoke.py')
transport = module('_participants_fixed_proxy', 'with-remix-runtime-proxy.py')
require, ProbeFailure = base.require, base.ProbeFailure
V2 = '/api/remix/v2/'


class Probe(base.Probe):
    def __init__(self, exercise=False, expected_release=''):
        super().__init__(exercise, expected_release)
        self.report['mode'] = 'two-new-core-participants-one-owned-match' if exercise else 'read-only'
        self.report['limits'] = [
            'Two new QA accounts, one private challenge and one owned match remain; no credentials are retained',
            'No dispatched POST retry, external message, existing user data or production restart',
            'The deliberate sequence-1 duplicates verify rejection; they are not transport retries',
            'GET operation recovery is checked after received responses; no live response is intentionally dropped',
            'No browser, Unity, replay validation or active-engine recovery proof',
            'A lost authentication response can leave an unknown session until expiry',
        ]

    def request(self, method, path, **kwargs):
        require(method in ('GET', 'POST') and isinstance(path, str) and (
            path in ('/', '/api/core/auth/register', '/api/core/auth/me', '/api/core/auth/logout',
                     '/api/remix/v1/challenges', V2 + 'capabilities', V2 + 'matches') or
            re.fullmatch(r'/api/remix/v[12]/matches/[A-Za-z0-9_.-]{1,128}(?:/(?:state|input|result|invitations))?', path) or
            re.fullmatch(r'/api/remix/v2/invitations/inv_[a-f0-9]{32}(?:/accept)?', path) or
            re.fullmatch(r'/api/remix/v2/(?:creation|admission)-attempts/[a-f0-9]{32}', path)
        ), 'QA route rejected')
        return super().request(method, path, **kwargs)

    def account(self, suffix):
        username = 'qa_participant_' + suffix + '_' + secrets.token_hex(8)
        registered = self.request('POST', '/api/core/auth/register', body=dict(
            username=username, password=secrets.token_urlsafe(32)))
        token = registered.get('token')
        require(isinstance(token, str) and re.fullmatch(r'[A-Za-z0-9_-]{40,100}', token), 'Core returned no valid QA session')
        self.tokens.append(token)
        self.report['authOutcomeUncertain'] = False
        user = registered.get('user')
        require(isinstance(user, dict) and isinstance(user.get('id'), str)
                and re.fullmatch(r'[a-f0-9]{32}', user['id']) and user.get('username') == username,
                'Core did not confirm the newly registered QA identity')
        verified = self.request('GET', '/api/core/auth/me', token=token).get('user')
        require(isinstance(verified, dict) and verified.get('id') == user['id'] and verified.get('username') == username,
                'Core QA identity verification failed')
        return token, user['id']

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
        self.report['allQaSessionsLoggedOut'] = set(self.tokens) == self.closed_tokens and not self.report['authOutcomeUncertain']
        if not self.report['allQaSessionsLoggedOut']:
            self.report['status'] = 'FAIL'

    def exercise(self):
        owner, owner_id = self.account('owner')
        member, member_id = self.account('member')
        self.check('Two distinct newly registered Core QA accounts are verified', owner != member and owner_id != member_id)
        challenge = self.request('POST', '/api/remix/v1/challenges', expected=201, body=dict(
            creatorId='qa-two-core-participants', title='QA two Core participants', mode='speed',
            seed=20261017, visibility='private'))
        require(base.valid_id(challenge.get('id')), 'Invalid QA challenge ID')
        create_key = secrets.token_hex(16)
        match = self.request('POST', V2 + 'matches', expected=201, token=owner, key=create_key,
                             body=dict(challengeId=challenge['id'], maxPlayers=2))
        require(base.valid_id(match.get('id')) and base.valid_id(match.get('playerId')), 'Invalid owned match/player ID')
        self.check('Owner has one durable server-assigned player before admission', match.get('role') == 'owner'
                   and match.get('participantCount') == 1 and match.get('maxParticipants') == 2 and match.get('highestSubmittedSequence') == 0
                   and match.get('accessMode') == 'core-owned' and match.get('challengeId') == challenge['id'])
        route, legacy = V2 + 'matches/' + match['id'], '/api/remix/v1/matches/' + match['id']
        self.report['match'] = dict(id=match['id'], challengeId=challenge['id'], ownerPlayerId=match['playerId'])
        self.request('GET', route + '/state', expected=403, token=member)
        self.request('GET', legacy + '/state', expected=401)
        self.check('Second account has no match access before explicit admission')
        invite_key = secrets.token_hex(16)
        invited = self.request('POST', route + '/invitations', expected=201, token=owner, key=invite_key,
                                body=dict(recipientAccountId=member_id))
        invitation = invited.get('invitation', {})
        require(isinstance(invitation.get('id'), str) and re.fullmatch(r'inv_[a-f0-9]{32}', invitation['id']), 'Invalid invitation ID')
        require(invited.get('status') == 'ready' and invited.get('operation') == 'invite'
                and invited.get('operationKey') == invite_key and invitation.get('matchId') == match['id']
                and invitation.get('challengeId') == challenge['id'] and invitation.get('recipientAccountId') == member_id
                and invitation.get('role') == 'owner' and invitation.get('status') == 'pending', 'Invite operation mismatch')
        invite_route = V2 + 'invitations/' + invitation['id']
        preview = self.request('GET', invite_route, token=member)
        self.request('GET', invite_route, expected=401)
        self.check('Authenticated recipient can preview their addressed invitation', preview.get('recipientAccountId') == member_id
                   and preview.get('id') == invitation['id'] and preview.get('matchId') == match['id']
                   and preview.get('challengeId') == challenge['id'] and preview.get('status') == 'pending'
                   and preview.get('role') == 'recipient' and preview.get('admissionAllowed') is True)
        accept_key = secrets.token_hex(16)
        accepted = self.request('POST', invite_route + '/accept', expected=201, token=member, key=accept_key, body={})
        participant = accepted.get('match', {})
        self.check('Acceptance durably assigns a distinct second player', accepted.get('status') == 'ready'
                   and accepted.get('operation') == 'accept' and accepted.get('operationKey') == accept_key
                   and accepted.get('invitation', {}).get('status') == 'accepted'
                   and accepted.get('invitation', {}).get('id') == invitation['id']
                   and accepted.get('invitation', {}).get('matchId') == match['id']
                   and accepted.get('invitation', {}).get('challengeId') == challenge['id']
                   and accepted.get('invitation', {}).get('recipientAccountId') == member_id
                   and accepted.get('invitation', {}).get('role') == 'recipient'
                   and participant.get('id') == match['id'] and participant.get('role') == 'participant'
                   and participant.get('challengeId') == challenge['id'] and participant.get('accessMode') == 'core-owned'
                   and participant.get('participantCount') == 2 and participant.get('maxParticipants') == 2
                   and participant.get('highestSubmittedSequence') == 0
                   and base.valid_id(participant.get('playerId')) and participant['playerId'] != match['playerId'])
        self.report['match']['participantPlayerId'] = participant['playerId']
        self.report['invitationId'] = invitation['id']
        self.check('Accepted operation is confirmed by GET without repeating POST',
                   self.request('GET', V2 + 'admission-attempts/' + accept_key, token=member) == accepted)
        state = self.request('GET', route + '/state', token=owner)
        while state.get('phase') == 'COUNTDOWN':
            require(time.monotonic() < self.deadline - 20, 'Countdown exceeded QA budget')
            time.sleep(1.5)
            state = self.request('GET', route + '/state', token=owner)
        require(state.get('phase') == 'PLAYING' and state.get('players') == 0, 'Fresh QA match did not become playable')
        command = dict(sequence=1, moveX=1, moveY=0, jump=False)
        for token, player in ((owner, match['playerId']), (member, participant['playerId'])):
            ack = self.request('POST', route + '/input', token=token, body=command)
            require(ack.get('playerId') == player and ack.get('lastSequence') == 1, 'Input actor assignment mismatch')
            self.request('POST', route + '/input', expected=409, token=token, body=command)
            metadata = self.request('GET', route, token=token)
            require(metadata.get('playerId') == player and metadata.get('highestSubmittedSequence') == 1
                    and metadata.get('participantCount') == 2, 'Caller-specific sequence metadata mismatch')
        self.check('Each participant submits their own sequence 1; duplicate sequences are rejected independently')
        self.request('POST', legacy + '/input', expected=403, token=member,
                     body=dict(command, playerId=match['playerId'], sequence=2))
        self.check('Second account cannot submit the owner player identity')
        state = self.request('GET', route + '/state', token=member)
        while state.get('phase') in ('COUNTDOWN', 'PLAYING'):
            require(time.monotonic() < self.deadline - 12, 'Completion exceeded QA budget')
            time.sleep(1.5)
            state = self.request('GET', route + '/state', token=member)
        require(state.get('phase') == 'RESULTS', 'QA match did not finish')
        result = self.request('GET', route + '/result', token=owner)
        scores = result.get('scores')
        require(result.get('matchId') == match['id'] and result.get('phase') == 'RESULTS'
                and result.get('replayFrames') == 2 and isinstance(scores, list) and len(scores) == 2
                and all(isinstance(item, dict) for item in scores)
                and {item.get('playerId') for item in scores} == {match['playerId'], participant['playerId']}
                and all(type(item.get('score')) in (int, float) and math.isfinite(item['score']) for item in scores),
                'Completed result is not the two-command/two-player QA result')
        for prefix in (route, legacy):
            self.request('GET', prefix + '/result', expected=401)
            for token in (owner, member):
                require(self.request('GET', prefix + '/result', token=token) == result, 'Participant result aliases differ')
        self.check('Both Core participants read the same protected two-player result through both aliases')
        for token, player in ((owner, match['playerId']), (member, participant['playerId'])):
            history = self.request('GET', V2 + 'matches', token=token).get('matches')
            require(isinstance(history, list) and len(history) <= 50 and any(
                item.get('id') == match['id'] and item.get('playerId') == player for item in history), 'Participant history missing QA match')
        self.check('Match history is present with each caller-specific player identity')
        self.request('POST', route + '/input', expected=409, token=member, body=dict(command, sequence=2))
        self.check('Late participant input cannot change the frozen result', self.request('GET', route + '/result', token=member) == result)
        retained = dict(matchId=match['id'], phase='RESULTS', replayFrames=2,
                        scores=[dict(playerId=item['playerId'], score=item['score']) for item in scores])
        self.report['result'] = retained
        self.report['resultSha256'] = hashlib.sha256(json.dumps(retained, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        for token in (owner, member):
            self.logout(token)
            self.request('GET', route + '/result', expected=401, token=token)
        self.request('GET', V2 + 'admission-attempts/' + accept_key, expected=401, token=member)
        self.check('Both logouts revoke result access and the participant operation recovery')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--exercise-participants', action='store_true')
    parser.add_argument('--expected-release', default='')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    require(not args.expected_release or re.fullmatch(r'[a-f0-9]{12}', args.expected_release), 'Expected release must be 12 lowercase hex characters')
    require(not args.exercise_participants or args.expected_release, 'Write verification requires the exact published release')
    if args.output:
        require(not args.output.exists() and not args.output.is_symlink() and args.output.parent.is_dir(), 'Refusing to overwrite QA evidence')
    probe = Probe(args.exercise_participants, args.expected_release)
    try:
        factory = transport.connection_factory(transport.runtime_proxy())
        # Replace only this separately loaded frozen module's namespace.
        base.http = types.SimpleNamespace(client=types.SimpleNamespace(HTTPSConnection=factory))
        before = probe.request('GET', '/')
        caps = probe.request('GET', V2 + 'capabilities')
        probe.report['release'] = before
        probe.report['capabilities'] = {name: caps.get(name) for name in (
            'authPolicyVersion', 'provider', 'ownershipPolicy', 'creationEnabled', 'participantPolicyVersion',
            'participantAdmissionEnabled', 'maxParticipants', 'activeMatchRecovery', 'replayVerification')}
        probe.check('Published ownership policy is Core confirmed-durable-binding', caps.get('authPolicyVersion') == 1
                    and caps.get('provider') == 'core' and caps.get('ownershipPolicy') == 'confirmed-durable-binding')
        if args.exercise_participants:
            require(caps.get('creationEnabled') is True and caps.get('participantPolicyVersion') == 1
                    and caps.get('participantAdmissionEnabled') is True and caps.get('maxParticipants') == 2,
                    'Two-participant admission is not enabled; no QA account was created')
            probe.exercise()
        probe.check('Published release remained unchanged during verification', probe.request('GET', '/') == before)
        probe.report['status'] = 'PASS'
    except Exception as error:
        probe.report['status'] = 'FAIL'
        probe.report['failure'] = str(error) if isinstance(error, ProbeFailure) else 'Transport or parsing failure: ' + type(error).__name__
    finally:
        probe.cleanup()
        probe.report['finishedAt'] = dt.datetime.now(dt.timezone.utc).isoformat()
        probe.report['durationSeconds'] = round(time.monotonic() - probe.started, 3)
        evidence = json.dumps(probe.report, ensure_ascii=False, indent=2) + '\n'
        require(not any(token in evidence for token in probe.tokens), 'Credential detected in evidence')
        if args.output:
            with args.output.open('x') as output:
                output.write(evidence)
        print(json.dumps({name: probe.report[name] for name in ('status', 'mode', 'allQaSessionsLoggedOut', 'authOutcomeUncertain')} |
                         dict(requests=len(probe.report['requests']), checks=len(probe.report['checks']))))
    return 0 if probe.report['status'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
