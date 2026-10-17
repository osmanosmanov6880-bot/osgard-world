"""Opt-in REMIX arena service. This is not the external Unity match backend.

One authenticated actor owns each run. Published challenges can be attempted by
other actors. Every fixed simulation step and replay checkpoint is calculated
here; the browser supplies direction and jump intent, never a score or position.
"""
from collections import deque
import hashlib
import json
import re

from core_model import Fault, now, require, text, uid

RULESET = 'remix-arena-v1'
WIDTH, HEIGHT, STEP_MS, MAX_INPUTS = 12, 7, 100, 256
START = [0, 3]
SCHEMA = '''
CREATE TABLE IF NOT EXISTS remix_challenges(
 id TEXT PRIMARY KEY, creator_id TEXT NOT NULL REFERENCES users(id),
 title TEXT NOT NULL, seed INTEGER NOT NULL, visibility TEXT NOT NULL,
 status TEXT NOT NULL, arena_json TEXT NOT NULL, proof_match_id TEXT,
 parent_id TEXT REFERENCES remix_challenges(id), created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS remix_matches(
 id TEXT PRIMARY KEY, challenge_id TEXT NOT NULL REFERENCES remix_challenges(id),
 player_id TEXT NOT NULL REFERENCES users(id), purpose TEXT NOT NULL,
 phase TEXT NOT NULL, state_json TEXT NOT NULL, result_json TEXT,
 replay_hash TEXT, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS remix_inputs(
 match_id TEXT NOT NULL REFERENCES remix_matches(id), sequence INTEGER NOT NULL,
 input_json TEXT NOT NULL, checkpoint_json TEXT NOT NULL, response_json TEXT NOT NULL,
 PRIMARY KEY(match_id, sequence));
CREATE TABLE IF NOT EXISTS remix_operations(
 actor_id TEXT NOT NULL REFERENCES users(id), operation_key TEXT NOT NULL,
 request_hash TEXT NOT NULL, response_json TEXT NOT NULL,
 PRIMARY KEY(actor_id, operation_key));
CREATE INDEX IF NOT EXISTS remix_challenge_owners ON remix_challenges(creator_id);
CREATE INDEX IF NOT EXISTS remix_match_owners ON remix_matches(player_id,challenge_id);
CREATE INDEX IF NOT EXISTS remix_challenge_results ON remix_matches(challenge_id,phase,purpose,player_id);
'''


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False)


def checksum(value):
    return hashlib.sha256(canonical(value).encode()).hexdigest()


def fields(payload, allowed):
    require(isinstance(payload, dict) and set(payload) <= set(allowed), 'Недопустимые поля запроса.')


def integer(value, minimum, maximum):
    require(type(value) is int and minimum <= value <= maximum, 'Нужно целое число в допустимом диапазоне.')
    return value


def reachable(objects):
    blocked = {(o['x'], o['y']) for o in objects if o['kind'] != 'goal'}
    goal = next((o for o in objects if o['kind'] == 'goal'), None)
    if goal is None:
        return False
    pending, seen = deque([tuple(START)]), {tuple(START)}
    while pending:
        point = pending.popleft()
        if point == (goal['x'], goal['y']):
            return True
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            candidate = point[0] + dx, point[1] + dy
            if 0 <= candidate[0] < WIDTH and 0 <= candidate[1] < HEIGHT and candidate not in blocked and candidate not in seen:
                pending.append(candidate)
                seen.add(candidate)
    return False


def generated_objects(seed):
    objects = [{'id': 'goal', 'kind': 'goal', 'x': WIDTH - 1, 'y': 3}]
    for column in (4, 8):
        gap = 1 + hashlib.sha256(f'{RULESET}:{seed}:{column}'.encode()).digest()[0] % 5
        for row in range(HEIGHT):
            if row != gap:
                objects.append({'id': f'wall-{column}-{row}', 'kind': 'platform', 'x': column, 'y': row})
    # Keep a walkable route and the first rightward move available for every seed.
    digest = hashlib.sha256(f'{RULESET}:{seed}:hazards'.encode()).digest()
    occupied = {(o['x'], o['y']) for o in objects} | {(0, 3), (1, 3)}
    for index in range(0, 18, 2):
        x, y = 2 + digest[index] % 8, digest[index + 1] % HEIGHT
        if (x, y) in occupied:
            continue
        candidate = {'id': f'hazard-{index}', 'kind': 'hazard', 'x': x, 'y': y}
        if reachable(objects + [candidate]):
            objects.append(candidate)
            occupied.add((x, y))
        if sum(o['kind'] == 'hazard' for o in objects) == 3:
            break
    return objects


def arena(seed, supplied=None):
    objects = generated_objects(seed) if supplied is None else supplied
    require(isinstance(objects, list) and 1 <= len(objects) <= 40, 'Испытанию нужны 1–40 объектов.')
    normalized, ids, occupied = [], set(), set()
    for obj in objects:
        fields(obj, ('id', 'kind', 'x', 'y'))
        identifier = text(obj.get('id'), 40, 1)
        require(re.fullmatch(r'[A-Za-z0-9_-]+', identifier) and identifier not in ids, 'Идентификаторы объектов должны быть уникальными.')
        kind = obj.get('kind')
        require(kind in ('platform', 'hazard', 'goal'), 'Неизвестный тип объекта.')
        x, y = integer(obj.get('x'), 0, WIDTH - 1), integer(obj.get('y'), 0, HEIGHT - 1)
        require((x, y) not in occupied and [x, y] != START, 'Объекты не должны перекрываться или занимать старт.')
        ids.add(identifier)
        occupied.add((x, y))
        normalized.append(dict(id=identifier, kind=kind, x=x, y=y))
    require(sum(o['kind'] == 'goal' for o in normalized) == 1, 'Нужна ровно одна цель.')
    require(reachable(normalized), 'К цели должен существовать безопасный путь.')
    return dict(width=WIDTH, height=HEIGHT, start=START[:], objects=normalized, ruleset=RULESET, stepMs=STEP_MS, maxInputs=MAX_INPUTS)


def initial_state():
    return dict(position=START[:], sequence=0, steps=0, falls=0, jumps=0, blocked=0, timeMs=0, finished=False, won=False)


def input_intent(payload, actor):
    fields(payload, ('playerId', 'sequence', 'moveX', 'moveY', 'jump'))
    require('playerId' not in payload or payload['playerId'] == actor, 'Нельзя передать ход за другого игрока.', 'forbidden', 403)
    sequence = integer(payload.get('sequence'), 1, MAX_INPUTS)
    dx, dy = integer(payload.get('moveX'), -1, 1), integer(payload.get('moveY'), -1, 1)
    require(abs(dx) + abs(dy) == 1, 'Ход должен иметь одно направление.')
    jump = payload.get('jump', False)
    require(type(jump) is bool, 'Прыжок должен быть логическим значением.')
    return dict(sequence=sequence, moveX=dx, moveY=dy, jump=jump)


def advance(level, previous, intent):
    require(not previous['finished'], 'Заезд уже завершён.', 'match_finished', 409)
    require(intent['sequence'] == previous['sequence'] + 1, 'Нарушен порядок ходов.', 'sequence_conflict', 409)
    state = dict(previous, position=previous['position'][:])
    state['sequence'] = intent['sequence']
    state['steps'] += 1
    state['jumps'] += int(intent['jump'])
    dx, dy = intent['moveX'], intent['moveY']
    distance = 2 if intent['jump'] else 1
    x, y = state['position']
    target = [x + dx * distance, y + dy * distance]
    platforms = {(o['x'], o['y']) for o in level['objects'] if o['kind'] == 'platform'}
    traversed = [(x + dx * n, y + dy * n) for n in range(1, distance + 1)]
    if not (0 <= target[0] < WIDTH and 0 <= target[1] < HEIGHT) or any(p in platforms for p in traversed):
        state['blocked'] += 1
    else:
        state['position'] = target
        landed = next((o['kind'] for o in level['objects'] if [o['x'], o['y']] == target), None)
        if landed == 'hazard':
            state['falls'] += 1
            state['position'] = START[:]
        elif landed == 'goal':
            state['won'] = True
    state['timeMs'] = state['steps'] * STEP_MS + state['falls'] * 1500 + state['jumps'] * STEP_MS
    state['finished'] = state['won'] or state['steps'] >= MAX_INPUTS
    return state


def result_values(state):
    return dict(won=state['won'], outcome='finished' if state['won'] else 'input-limit', steps=state['steps'], falls=state['falls'], jumps=state['jumps'], timeMs=state['timeMs'], score=max(0, 100000 - state['timeMs']) if state['won'] else 0)


def result_record(row, state):
    result = dict(schemaVersion=1, matchId=row['id'], challengeId=row['challenge_id'], playerId=row['player_id'], purpose=row['purpose'], ruleset=RULESET, **result_values(state))
    result['scores'] = [dict(playerId=row['player_id'], score=result['score'], timeMs=result['timeMs'])]
    return result


def verify_replay(envelope):
    """Re-simulate the complete journal; a matching hash alone is insufficient."""
    require(isinstance(envelope, dict), 'Неверный повтор.', 'replay_integrity', 503)
    content = {key: value for key, value in envelope.items() if key != 'hash'}
    require(envelope.get('hash') == checksum(content), 'Хеш повтора не совпадает.', 'replay_integrity', 503)
    require(envelope.get('schemaVersion') == 1 and envelope.get('game') == 'remix' and envelope.get('gameVersion') == RULESET, 'Версия повтора не поддерживается.', 'replay_integrity', 503)
    require(envelope.get('purpose') in ('creator-proof', 'challenge'), 'Назначение заезда не подтверждено.', 'replay_integrity', 503)
    level = arena(integer(envelope.get('seed'), 1, 2147483647), envelope.get('arena', {}).get('objects'))
    require(level == envelope.get('arena'), 'Арена повтора изменена.', 'replay_integrity', 503)
    inputs, checkpoints = envelope.get('inputs'), envelope.get('checkpoints')
    require(isinstance(inputs, list) and 1 <= len(inputs) <= MAX_INPUTS and isinstance(checkpoints, list) and len(inputs) == len(checkpoints), 'Журнал повтора неполон.', 'replay_integrity', 503)
    state = initial_state()
    require(envelope.get('initialState') == state, 'Начальное состояние изменено.', 'replay_integrity', 503)
    for raw, checkpoint in zip(inputs, checkpoints):
        intent = input_intent(raw, envelope.get('playerId'))
        state = advance(level, state, intent)
        require(checkpoint == dict(sequence=state['sequence'], state=state, hash=checksum(state)), 'Контрольная точка не воспроизводится.', 'replay_integrity', 503)
    require(state['finished'] and envelope.get('result') == result_values(state), 'Результат не воспроизводится.', 'replay_integrity', 503)
    return True


class RemixService:
    def __init__(self, store):
        self.store = store

    def capabilities(self):
        return dict(schemaVersion=1, service='osgard-remix-arena', ruleset=RULESET, auth='osgard-core-bearer-v1', mode='self-hosted-arena', playersPerMatch=1, comparison='separate-runs-on-published-challenges', maxInputs=MAX_INPUTS, stepMs=STEP_MS, resultAuthority='server-input-journal', creatorProofRequired=True)

    def challenge_row(self, db, identifier, actor, owner=False):
        require(isinstance(identifier, str) and re.fullmatch(r'[a-f0-9]{32}', identifier), 'Неверный идентификатор испытания.')
        row = db.execute('SELECT * FROM remix_challenges WHERE id=?', (identifier,)).fetchone()
        require(row is not None and (row['creator_id'] == actor or (row['status'] == 'PUBLISHED' and row['visibility'] == 'public')), 'Испытание не найдено.', 'not_found', 404)
        require(not owner or row['creator_id'] == actor, 'Действие доступно автору испытания.', 'forbidden', 403)
        return row

    def match_row(self, db, identifier, actor):
        require(isinstance(identifier, str) and re.fullmatch(r'[a-f0-9]{32}', identifier), 'Неверный идентификатор заезда.')
        row = db.execute('SELECT * FROM remix_matches WHERE id=? AND player_id=?', (identifier, actor)).fetchone()
        require(row is not None, 'Заезд не найден.', 'not_found', 404)
        return row

    def challenge_view(self, row):
        return dict(schemaVersion=1, id=row['id'], creatorId=row['creator_id'], title=row['title'], seed=row['seed'], mode='speed', visibility=row['visibility'], status=row['status'], arena=json.loads(row['arena_json']), ruleset=RULESET, parentId=row['parent_id'], createdAt=row['created_at'])

    def state_view(self, db, row):
        challenge = db.execute('SELECT * FROM remix_challenges WHERE id=?', (row['challenge_id'],)).fetchone()
        return dict(schemaVersion=1, id=row['id'], challengeId=row['challenge_id'], playerId=row['player_id'], phase=row['phase'], players=1, maxPlayers=1, purpose=row['purpose'], ruleset=RULESET, seed=challenge['seed'], arena=json.loads(challenge['arena_json']), replayFrames=json.loads(row['state_json'])['sequence'], **json.loads(row['state_json']))

    def replay(self, db, row):
        require(row['phase'] == 'RESULTS', 'Заезд ещё не завершён.', 'result_not_ready', 409)
        challenge = db.execute('SELECT * FROM remix_challenges WHERE id=?', (row['challenge_id'],)).fetchone()
        entries = db.execute('SELECT * FROM remix_inputs WHERE match_id=? ORDER BY sequence', (row['id'],)).fetchall()
        result = json.loads(row['result_json'])
        envelope = dict(schemaVersion=1, game='remix', gameVersion=RULESET, seed=challenge['seed'], challengeId=challenge['id'], matchId=row['id'], playerId=row['player_id'], purpose=row['purpose'], arena=json.loads(challenge['arena_json']), initialState=initial_state(), inputs=[json.loads(entry['input_json']) for entry in entries], checkpoints=[json.loads(entry['checkpoint_json']) for entry in entries], result={key: result[key] for key in result_values(json.loads(row['state_json']))}, hash=row['replay_hash'])
        verify_replay(envelope)
        final_state = envelope['checkpoints'][-1]['state']
        require(json.loads(row['state_json']) == final_state and result == result_record(row, final_state), 'Сохранённый результат не соответствует повтору.', 'replay_integrity', 503)
        return envelope

    def get(self, route, actor):
        with self.store.connect() as db:
            db.execute('BEGIN')
            match = re.fullmatch(r'matches/([a-f0-9]{32})/(state|result|replay)', route)
            if match:
                row = self.match_row(db, match[1], actor)
                if match[2] == 'state':
                    return self.state_view(db, row)
                replay = self.replay(db, row)
                if match[2] == 'replay':
                    return replay
                return dict(json.loads(row['result_json']), replayHash=replay['hash'], replayKey=row['id'])
            challenge = re.fullmatch(r'challenges/([a-f0-9]{32})(/leaderboard)?', route)
            if challenge:
                row = self.challenge_row(db, challenge[1], actor)
                if not challenge[2]:
                    return self.challenge_view(row)
                require(row['status'] == 'PUBLISHED', 'Испытание ещё не опубликовано.', 'not_published', 409)
                # Bound both the response and Python memory before replay verification.
                # A player appears once, with their best completed challenge run.
                rows = db.execute('''WITH ranked AS (
                    SELECT remix_matches.*, ROW_NUMBER() OVER (
                        PARTITION BY player_id ORDER BY json_extract(result_json,'$.timeMs'),created_at,id
                    ) AS player_rank
                    FROM remix_matches WHERE challenge_id=? AND phase='RESULTS' AND purpose='challenge'
                        AND json_extract(result_json,'$.won')=1
                    ) SELECT * FROM ranked WHERE player_rank=1
                    ORDER BY json_extract(result_json,'$.timeMs'),player_id LIMIT 20''', (row['id'],)).fetchall()
                scores = []
                for run in rows:
                    replay = self.replay(db, run)
                    result = replay['result']
                    scores.append(dict(playerId=run['player_id'], matchId=run['id'], score=result['score'], timeMs=result['timeMs']))
                return dict(schemaVersion=1, challengeId=row['id'], ruleset=RULESET, scores=scores)
            raise Fault('not_found', 'Маршрут REMIX не найден.', 404)

    def mutate(self, route, actor, payload, key):
        require(isinstance(key, str) and re.fullmatch(r'[A-Za-z0-9_-]{16,100}', key), 'Нужен уникальный ключ операции.', 'idempotency_required', 400)
        fingerprint = checksum(dict(route=route, payload=payload))
        with self.store.transaction() as db:
            previous = db.execute('SELECT * FROM remix_operations WHERE actor_id=? AND operation_key=?', (actor, key)).fetchone()
            if previous:
                require(previous['request_hash'] == fingerprint, 'Ключ уже использован для другого запроса.', 'idempotency_conflict', 409)
                return dict(json.loads(previous['response_json']), replayed=True)
            require(db.execute('SELECT COUNT(*) FROM remix_operations WHERE actor_id=?', (actor,)).fetchone()[0] < 40000, 'Достигнут лимит операций REMIX.', 'quota', 409)
            result = self._mutate(db, route, actor, payload)
            db.execute('INSERT INTO remix_operations VALUES(?,?,?,?)', (actor, key, fingerprint, canonical(result)))
            return result

    def _create(self, db, actor, payload, parent=None):
        fields(payload, ('creatorId', 'title', 'mode', 'seed', 'visibility', 'objects'))
        require('creatorId' not in payload or payload['creatorId'] == actor, 'Нельзя создать испытание от другого автора.', 'forbidden', 403)
        require(payload.get('mode', 'speed') == 'speed', 'Этот режим не поддерживается.', 'unsupported_mode', 409)
        require(payload.get('visibility', 'public') in ('public', 'private'), 'Неизвестная видимость испытания.')
        seed = integer(payload.get('seed'), 1, 2147483647)
        level = arena(seed, payload.get('objects'))
        require(db.execute('SELECT COUNT(*) FROM remix_challenges WHERE creator_id=?', (actor,)).fetchone()[0] < 100, 'Достигнут лимит испытаний.', 'quota', 409)
        identifier = uid()
        db.execute('INSERT INTO remix_challenges VALUES(?,?,?,?,?,?,?,?,?,?)', (identifier, actor, text(payload.get('title'), 100, 2), seed, payload.get('visibility', 'public'), 'DRAFT', canonical(level), None, parent, now()))
        return self.challenge_view(self.challenge_row(db, identifier, actor))

    def _mutate(self, db, route, actor, payload):
        if route == 'challenges':
            return self._create(db, actor, payload)
        if route == 'matches':
            fields(payload, ('challengeId', 'maxPlayers'))
            require(type(payload.get('maxPlayers', 1)) is int and payload.get('maxPlayers', 1) == 1, 'Этот режим поддерживает отдельные заезды одного игрока.', 'unsupported_players', 409)
            challenge = self.challenge_row(db, payload.get('challengeId'), actor)
            require(challenge['status'] == 'PUBLISHED' or challenge['creator_id'] == actor, 'Сначала опубликуйте испытание.', 'not_published', 409)
            require(db.execute('SELECT COUNT(*) FROM remix_matches WHERE player_id=?', (actor,)).fetchone()[0] < 500, 'Достигнут лимит заездов.', 'quota', 409)
            identifier = uid()
            db.execute('INSERT INTO remix_matches VALUES(?,?,?,?,?,?,?,?,?)', (identifier, challenge['id'], actor, 'challenge' if challenge['status'] == 'PUBLISHED' else 'creator-proof', 'PLAYING', canonical(initial_state()), None, None, now()))
            return self.state_view(db, self.match_row(db, identifier, actor))
        challenge_action = re.fullmatch(r'challenges/([a-f0-9]{32})/(validate|publish|remix)', route)
        if challenge_action:
            challenge = self.challenge_row(db, challenge_action[1], actor, owner=challenge_action[2] != 'remix')
            if challenge_action[2] == 'remix':
                require(challenge['status'] == 'PUBLISHED', 'Можно развить только опубликованное испытание.', 'not_published', 409)
                fields(payload, ('title', 'objects', 'seed'))
                return self._create(db, actor, dict(title=payload.get('title', 'REMIX / ' + challenge['title']), seed=payload.get('seed', challenge['seed']), objects=payload.get('objects', json.loads(challenge['arena_json'])['objects']), visibility='public'), challenge['id'])
            if challenge_action[2] == 'validate':
                fields(payload, ('matchId',))
                proof = self.match_row(db, payload.get('matchId'), actor)
                require(proof['challenge_id'] == challenge['id'] and proof['purpose'] == 'creator-proof', 'Нужен проверочный заезд этого испытания.', 'proof_required', 409)
                replay = self.replay(db, proof)
                require(replay['result']['won'], 'Автор должен достичь цели.', 'proof_required', 409)
                require(challenge['status'] in ('DRAFT', 'VALIDATED'), 'Испытание уже опубликовано.', 'published', 409)
                db.execute("UPDATE remix_challenges SET status='VALIDATED',proof_match_id=? WHERE id=?", (proof['id'], challenge['id']))
            else:
                fields(payload, ())
                require(challenge['status'] == 'VALIDATED' and challenge['proof_match_id'], 'Сначала подтвердите прохождение автора.', 'proof_required', 409)
                proof = self.match_row(db, challenge['proof_match_id'], actor)
                require(proof['challenge_id'] == challenge['id'] and proof['purpose'] == 'creator-proof', 'Проверочный заезд должен относиться к этому испытанию.', 'proof_required', 409)
                replay = self.replay(db, proof)
                require(replay['result']['won'], 'Автор должен достичь цели.', 'proof_required', 409)
                db.execute("UPDATE remix_challenges SET status='PUBLISHED' WHERE id=?", (challenge['id'],))
            return self.challenge_view(self.challenge_row(db, challenge['id'], actor))
        match_input = re.fullmatch(r'matches/([a-f0-9]{32})/input', route)
        if match_input:
            row = self.match_row(db, match_input[1], actor)
            intent = input_intent(payload, actor)
            old = db.execute('SELECT * FROM remix_inputs WHERE match_id=? AND sequence=?', (row['id'], intent['sequence'])).fetchone()
            if old:
                require(old['input_json'] == canonical(intent), 'Этот номер уже занят другим ходом.', 'sequence_conflict', 409)
                return dict(json.loads(old['response_json']), replayed=True)
            challenge = db.execute('SELECT * FROM remix_challenges WHERE id=?', (row['challenge_id'],)).fetchone()
            state = advance(json.loads(challenge['arena_json']), json.loads(row['state_json']), intent)
            db.execute('UPDATE remix_matches SET state_json=?,phase=? WHERE id=?', (canonical(state), 'RESULTS' if state['finished'] else 'PLAYING', row['id']))
            checkpoint = dict(sequence=state['sequence'], state=state, hash=checksum(state))
            db.execute('INSERT INTO remix_inputs VALUES(?,?,?,?,?)', (row['id'], intent['sequence'], canonical(intent), canonical(checkpoint), '{}'))
            if state['finished']:
                result = result_record(row, state)
                entries = db.execute('SELECT input_json,checkpoint_json FROM remix_inputs WHERE match_id=? ORDER BY sequence', (row['id'],)).fetchall()
                envelope = dict(schemaVersion=1, game='remix', gameVersion=RULESET, seed=challenge['seed'], challengeId=challenge['id'], matchId=row['id'], playerId=actor, purpose=row['purpose'], arena=json.loads(challenge['arena_json']), initialState=initial_state(), inputs=[json.loads(entry['input_json']) for entry in entries], checkpoints=[json.loads(entry['checkpoint_json']) for entry in entries], result=result_values(state))
                replay_hash = checksum(envelope)
                verify_replay(dict(envelope, hash=replay_hash))
                db.execute('UPDATE remix_matches SET result_json=?,replay_hash=? WHERE id=?', (canonical(result), replay_hash, row['id']))
            response = dict(schemaVersion=1, accepted=True, replayed=False, sequence=intent['sequence'], position=state['position'], state=self.state_view(db, self.match_row(db, row['id'], actor)))
            db.execute('UPDATE remix_inputs SET response_json=? WHERE match_id=? AND sequence=?', (canonical(response), row['id'], intent['sequence']))
            return response
        raise Fault('not_found', 'Маршрут REMIX не найден.', 404)
