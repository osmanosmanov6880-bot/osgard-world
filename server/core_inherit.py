"""Private INHERIT lineages: one custodian, immutable generations, explicit handoff.

All calls run inside Core's authenticated, actor-scoped SQLite transaction. No
anonymous-world migration, external notification, or background network action.
"""
from datetime import datetime, timezone
import hashlib
import json
import math
import re
import time

from core_model import Fault, now, require, text, uid

PREFIX = 'inherit/v1/'
TEMPLATE = 'quiet-reach-v1'
LIMITS = dict(worlds=32, objects=1024, generations=128, delta=100, members=64,
              handoffs=256, notifications=200)
KINDS = {'tree', 'stone', 'light', 'path', 'flower', 'arch', 'chime', 'moss', 'cairn', 'marker'}
ID = r'[a-f0-9]{32}'
KEY = r'[A-Za-z0-9_-]{16,100}'
TABLE_COLUMNS = {
    'inherit_meta': {'version'},
    'inherit_worlds': {'id', 'title', 'template', 'source', 'creator_id', 'custodian_id',
                       'revision', 'generation', 'custody_start', 'baseline', 'objects',
                       'baseline_hash', 'snapshot_hash', 'pending_handoff', 'created_at', 'updated_at'},
    'inherit_members': {'world_id', 'user_id', 'joined_at'},
    'inherit_generations': {'world_id', 'number', 'author_id', 'message', 'delta', 'objects',
                            'parent_hash', 'snapshot_hash', 'created_at'},
    'inherit_handoffs': {'id', 'world_id', 'from_id', 'to_id', 'status', 'expected_revision',
                         'created_at', 'expires_at'},
    'inherit_notifications': {'id', 'user_id', 'world_id', 'invitation_id', 'generation',
                             'actor_id', 'kind', 'created_at', 'read_at'},
    'inherit_operations': {'user_id', 'key', 'world_id', 'invitation_id', 'response', 'created_at'},
}

SCHEMA = '''
CREATE TABLE inherit_meta(version INTEGER NOT NULL CHECK(version=1));
INSERT INTO inherit_meta VALUES(1);
CREATE TABLE inherit_worlds(
 id TEXT PRIMARY KEY, title TEXT NOT NULL, template TEXT NOT NULL,
 source TEXT NOT NULL CHECK(source IN ('template','local-copy')),
 creator_id TEXT NOT NULL REFERENCES users(id), custodian_id TEXT NOT NULL REFERENCES users(id),
 revision INTEGER NOT NULL CHECK(revision>0), generation INTEGER NOT NULL CHECK(generation>0),
 custody_start INTEGER NOT NULL CHECK(custody_start>0), baseline TEXT NOT NULL, objects TEXT NOT NULL,
 baseline_hash TEXT NOT NULL, snapshot_hash TEXT NOT NULL, pending_handoff TEXT,
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
CREATE TABLE inherit_members(
 world_id TEXT NOT NULL REFERENCES inherit_worlds(id), user_id TEXT NOT NULL REFERENCES users(id),
 joined_at TEXT NOT NULL, PRIMARY KEY(world_id,user_id));
CREATE TABLE inherit_generations(
 world_id TEXT NOT NULL REFERENCES inherit_worlds(id), number INTEGER NOT NULL CHECK(number>0),
 author_id TEXT NOT NULL REFERENCES users(id), message TEXT NOT NULL, delta TEXT NOT NULL,
 objects TEXT NOT NULL, parent_hash TEXT NOT NULL, snapshot_hash TEXT NOT NULL,
 created_at TEXT NOT NULL, PRIMARY KEY(world_id,number));
CREATE TABLE inherit_handoffs(
 id TEXT PRIMARY KEY, world_id TEXT NOT NULL REFERENCES inherit_worlds(id),
 from_id TEXT NOT NULL REFERENCES users(id), to_id TEXT NOT NULL REFERENCES users(id),
 status TEXT NOT NULL CHECK(status IN ('pending','accepted','cancelled','declined','expired')),
 expected_revision INTEGER NOT NULL, created_at TEXT NOT NULL, expires_at REAL NOT NULL,
 CHECK(from_id<>to_id));
CREATE TABLE inherit_notifications(
 id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT NOT NULL REFERENCES users(id),
 world_id TEXT NOT NULL REFERENCES inherit_worlds(id), invitation_id TEXT REFERENCES inherit_handoffs(id),
 generation INTEGER, actor_id TEXT NOT NULL REFERENCES users(id), kind TEXT NOT NULL,
 created_at TEXT NOT NULL, read_at TEXT);
CREATE TABLE inherit_operations(
 user_id TEXT NOT NULL REFERENCES users(id), key TEXT NOT NULL,
 world_id TEXT REFERENCES inherit_worlds(id), invitation_id TEXT REFERENCES inherit_handoffs(id),
 response TEXT NOT NULL, created_at TEXT NOT NULL, PRIMARY KEY(user_id,key));
CREATE INDEX inherit_members_user ON inherit_members(user_id,world_id);
CREATE INDEX inherit_notifications_user ON inherit_notifications(user_id,id);
CREATE INDEX inherit_handoffs_world ON inherit_handoffs(world_id,status);
CREATE TRIGGER inherit_generation_no_update BEFORE UPDATE ON inherit_generations
 BEGIN SELECT RAISE(ABORT, 'INHERIT generations are immutable'); END;
CREATE TRIGGER inherit_generation_no_delete BEFORE DELETE ON inherit_generations
 BEGIN SELECT RAISE(ABORT, 'INHERIT generations are immutable'); END;
'''


def encoded(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'), sort_keys=True, allow_nan=False)


def checksum(value):
    return hashlib.sha256(encoded(value).encode()).hexdigest()


def validate_schema(db, allow_absent=False):
    tables = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    present = tables & TABLE_COLUMNS.keys()
    if not present and allow_absent:
        return False
    require(set(TABLE_COLUMNS) <= tables, 'Неполная схема INHERIT. Восстановите проверенную базу.', 'inherit_storage', 503)
    for table, required in TABLE_COLUMNS.items():
        columns = {row[1] for row in db.execute('PRAGMA table_info("' + table + '")')}
        require(required <= columns, 'Неполная схема INHERIT.', 'inherit_storage', 503)
    require([row[0] for row in db.execute('SELECT version FROM inherit_meta')] == [1],
            'Неподдерживаемая версия INHERIT.', 'inherit_storage', 503)
    triggers = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='trigger'")}
    require({'inherit_generation_no_update', 'inherit_generation_no_delete'} <= triggers,
            'Отсутствует защита истории INHERIT.', 'inherit_storage', 503)
    return True


def initialize(db):
    # Never quietly recreate a lost ACL or operation table beside existing data.
    if not validate_schema(db, allow_absent=True):
        db.executescript('BEGIN IMMEDIATE;\n' + SCHEMA + '\nCOMMIT;')
    validate_schema(db)


def person(db, actor):
    row = db.execute('SELECT id,username FROM users WHERE id=?', (actor,)).fetchone()
    require(row is not None, 'Аккаунт не найден.', 'not_found', 404)
    return dict(row)


def fields(payload, allowed):
    require(isinstance(payload, dict) and set(payload) <= set(allowed), 'Недопустимые поля INHERIT.')


def objects(value, maximum, minimum=0):
    require(isinstance(value, list) and minimum <= len(value) <= maximum, 'Проверьте число следов.')
    result = []
    for item in value:
        require(isinstance(item, dict) and set(item) == {'type', 'x', 'y'}, 'Неверный формат следа.')
        require(isinstance(item['type'], str) and item['type'] in KINDS, 'Неизвестный тип следа.')
        for axis in ('x', 'y'):
            n = item[axis]
            require(type(n) in (int, float) and math.isfinite(n) and 0 <= n <= 100,
                    'Координаты должны быть конечными числами от 0 до 100.')
        result.append(dict(type=item['type'], x=item['x'], y=item['y']))
    return result


def access(db, world_id, actor, write=False):
    row = db.execute('SELECT w.* FROM inherit_worlds w JOIN inherit_members m ON m.world_id=w.id '
                     'WHERE w.id=? AND m.user_id=?', (world_id, actor)).fetchone()
    require(row is not None, 'Мир не найден.', 'not_found', 404)
    require(not write or row['custodian_id'] == actor, 'Мир изменяет текущий хранитель.', 'forbidden', 403)
    return row


def handoff_access(db, invitation_id, actor):
    row = db.execute('SELECT * FROM inherit_handoffs WHERE id=? AND (from_id=? OR to_id=?)',
                     (invitation_id, actor, actor)).fetchone()
    require(row is not None, 'Приглашение не найдено.', 'not_found', 404)
    return row


def invitation_status(row):
    return 'expired' if row['status'] == 'pending' and row['expires_at'] <= time.time() else row['status']


def invitation_view(db, row):
    world = db.execute('SELECT title FROM inherit_worlds WHERE id=?', (row['world_id'],)).fetchone()
    return dict(id=row['id'], worldId=row['world_id'], worldTitle=world['title'],
                **{'from': person(db, row['from_id']), 'to': person(db, row['to_id'])},
                status=invitation_status(row), expectedRevision=row['expected_revision'],
                createdAt=row['created_at'],
                expiresAt=datetime.fromtimestamp(row['expires_at'], timezone.utc).isoformat(timespec='seconds'))


def pending(db, row):
    if row['pending_handoff']:
        invitation = db.execute('SELECT * FROM inherit_handoffs WHERE id=?', (row['pending_handoff'],)).fetchone()
        require(invitation is not None, 'Не найдена запись передачи.', 'inherit_storage', 503)
        if invitation_status(invitation) == 'pending':
            return invitation
    return None


def generation_view(db, row, snapshot=False):
    result = dict(number=row['number'], author=person(db, row['author_id']), message=row['message'],
                  delta=json.loads(row['delta']), createdAt=row['created_at'],
                  parentHash=row['parent_hash'], snapshotHash=row['snapshot_hash'])
    if snapshot:
        result['objects'] = json.loads(row['objects'])
    return result


def world_view(db, row, actor, summary=False):
    invitation = pending(db, row)
    result = dict(id=row['id'], title=row['title'], template=row['template'], source=row['source'],
                  creator=person(db, row['creator_id']), custodian=person(db, row['custodian_id']),
                  role='custodian' if row['custodian_id'] == actor else 'reader',
                  canEdit=row['custodian_id'] == actor and invitation is None,
                  revision=row['revision'], currentGeneration=row['generation'],
                  snapshotHash=row['snapshot_hash'], baselineHash=row['baseline_hash'],
                  sourceVerified=row['source'] == 'template',
                  pendingHandoff=invitation_view(db, invitation) if invitation else None,
                  canOfferHandoff=row['custodian_id'] == actor and invitation is None and row['generation'] > row['custody_start'],
                  createdAt=row['created_at'], updatedAt=row['updated_at'])
    if not summary:
        result['objects'] = json.loads(row['objects'])
        result['generations'] = [generation_view(db, g) for g in db.execute(
            'SELECT * FROM inherit_generations WHERE world_id=? ORDER BY number', (row['id'],))]
    return result


def notify(db, recipient, world_id, actor, kind, invitation_id=None, generation=None):
    stamp = now()
    db.execute('INSERT INTO inherit_notifications(user_id,world_id,invitation_id,generation,actor_id,kind,created_at) '
               'VALUES(?,?,?,?,?,?,?)', (recipient, world_id, invitation_id, generation, actor, kind, stamp))
    # Inbox retention is separate from the complete immutable lineage.
    db.execute('DELETE FROM inherit_notifications WHERE user_id=? AND id NOT IN '
               '(SELECT id FROM inherit_notifications WHERE user_id=? ORDER BY id DESC LIMIT ?)',
               (recipient, recipient, LIMITS['notifications']))


def notification_view(db, row):
    return dict(id=row['id'], kind=row['kind'], worldId=row['world_id'], invitationId=row['invitation_id'],
                generation=row['generation'], actor=person(db, row['actor_id']),
                createdAt=row['created_at'], readAt=row['read_at'])


def recovery_access(db, saved, actor):
    # Core auth is checked afresh before every GET/replayed POST; the cached body
    # is additionally actor-scoped and its underlying world access is rechecked.
    if saved['invitation_id']:
        handoff_access(db, saved['invitation_id'], actor)
    if saved['world_id']:
        access(db, saved['world_id'], actor)


def retry_guard(db, actor, key):
    row = db.execute('SELECT * FROM inherit_operations WHERE user_id=? AND key=?', (actor, key)).fetchone()
    require(row is not None, 'Журнал INHERIT неполон.', 'inherit_storage', 503)
    recovery_access(db, row, actor)


def get(db, route, actor):
    route = route.removeprefix(PREFIX)
    if route == 'capabilities':
        return dict(schemaVersion=1, template=TEMPLATE, permissions='single-custodian-retained-history',
                    limits=LIMITS, externalNotifications=False, operationRecovery='get-only',
                    importedHistoryVerified=False)
    if route == 'worlds':
        rows = db.execute('SELECT w.* FROM inherit_worlds w JOIN inherit_members m ON m.world_id=w.id '
                          'WHERE m.user_id=? ORDER BY w.updated_at DESC,w.id LIMIT 256', (actor,)).fetchall()
        return {'worlds': [world_view(db, row, actor, summary=True) for row in rows]}
    if route == 'notifications':
        rows = db.execute('SELECT * FROM inherit_notifications WHERE user_id=? ORDER BY id DESC LIMIT ?',
                          (actor, LIMITS['notifications'])).fetchall()
        return dict(notifications=[notification_view(db, row) for row in rows],
                    unreadCount=sum(row['read_at'] is None for row in rows), retention=LIMITS['notifications'])
    match = re.fullmatch('worlds/(' + ID + ')(?:/generations/([1-9][0-9]{0,2}))?', route)
    if match:
        row = access(db, match[1], actor)
        if match[2]:
            generation = db.execute('SELECT * FROM inherit_generations WHERE world_id=? AND number=?',
                                    (row['id'], int(match[2]))).fetchone()
            require(generation is not None, 'Поколение не найдено.', 'not_found', 404)
            return {'worldId': row['id'], 'generation': generation_view(db, generation, snapshot=True)}
        return {'world': world_view(db, row, actor)}
    match = re.fullmatch('handoffs/(' + ID + ')', route)
    if match:
        return {'invitation': invitation_view(db, handoff_access(db, match[1], actor))}
    match = re.fullmatch('operations/(' + KEY + ')', route)
    if match:
        row = db.execute('SELECT * FROM inherit_operations WHERE user_id=? AND key=?', (actor, match[1])).fetchone()
        require(row is not None, 'Подтверждение операции пока не найдено.', 'not_found', 404)
        recovery_access(db, row, actor)
        result = json.loads(row['response'])
        return dict(status='committed', operation=result['operation'], result=result)
    raise Fault('not_found', 'Маршрут INHERIT не найден.', 404)


def expected(row, payload):
    require(type(payload.get('expectedRevision')) is int and payload['expectedRevision'] == row['revision'],
            'Мир изменился. Черновик сохранён; откройте актуальную версию.', 'version_conflict', 409)


def clear_expired(db, row):
    if row['pending_handoff']:
        db.execute("UPDATE inherit_handoffs SET status='expired' WHERE id=? AND status='pending' AND expires_at<=?",
                   (row['pending_handoff'], time.time()))


def create(db, actor, payload):
    fields(payload, ('title', 'template', 'source', 'objects'))
    title = text(payload.get('title'), 120, 1)
    require(payload.get('template') == TEMPLATE and payload.get('source') in ('template', 'local-copy'),
            'Выберите шаблон и происхождение мира.')
    baseline = objects(payload.get('objects'), LIMITS['objects'])
    require(payload['source'] != 'template' or not baseline, 'Готовый шаблон не содержит импортированных следов.')
    require(db.execute('SELECT COUNT(*) FROM inherit_worlds WHERE creator_id=?', (actor,)).fetchone()[0] < LIMITS['worlds'],
            'Лимит 32 личных миров.', 'world_limit', 409)
    require(db.execute('SELECT COUNT(*) FROM inherit_members WHERE user_id=?', (actor,)).fetchone()[0] < 256,
            'Достигнут предел доступных миров.', 'membership_limit', 409)
    world_id, stamp = uid(), now()
    raw = encoded(baseline)
    baseline_hash = checksum(dict(template=TEMPLATE, source=payload['source'], objects=baseline))
    db.execute('INSERT INTO inherit_worlds VALUES(?,?,?,?,?,?,1,1,1,?,?,?,?,NULL,?,?)',
               (world_id, title, TEMPLATE, payload['source'], actor, actor, raw, raw,
                baseline_hash, baseline_hash, stamp, stamp))
    db.execute('INSERT INTO inherit_members VALUES(?,?,?)', (world_id, actor, stamp))
    return {'world': world_view(db, access(db, world_id, actor), actor)}


def append(db, world_id, actor, payload):
    fields(payload, ('expectedRevision', 'expectedGeneration', 'message', 'delta'))
    row = access(db, world_id, actor, write=True)
    expected(row, payload)
    require(type(payload.get('expectedGeneration')) is int and payload['expectedGeneration'] == row['generation'],
            'У мира уже другое поколение.', 'generation_conflict', 409)
    require(pending(db, row) is None, 'Дождитесь принятия передачи или отмените её.', 'handoff_pending', 409)
    require(row['generation'] <= LIMITS['generations'], 'Достигнут предел истории мира.', 'generation_limit', 409)
    message = text(payload.get('message'), 1000, 1)
    delta = objects(payload.get('delta'), LIMITS['delta'], 1)
    snapshot = json.loads(row['objects']) + delta
    require(len(snapshot) <= LIMITS['objects'], 'В этом мире достигнут лимит следов.', 'object_limit', 409)
    stamp = now()
    snapshot_hash = checksum(dict(worldId=world_id, number=row['generation'], authorId=actor, message=message,
                                  delta=delta, objects=snapshot, parentHash=row['snapshot_hash'], createdAt=stamp))
    db.execute('INSERT INTO inherit_generations VALUES(?,?,?,?,?,?,?,?,?)',
               (world_id, row['generation'], actor, message, encoded(delta), encoded(snapshot),
                row['snapshot_hash'], snapshot_hash, stamp))
    clear_expired(db, row)
    db.execute('UPDATE inherit_worlds SET revision=revision+1,generation=generation+1,objects=?,snapshot_hash=?, '
               'pending_handoff=NULL,updated_at=? WHERE id=?', (encoded(snapshot), snapshot_hash, stamp, world_id))
    for member in db.execute('SELECT user_id FROM inherit_members WHERE world_id=? AND user_id<>?', (world_id, actor)).fetchall():
        notify(db, member['user_id'], world_id, actor, 'generation_created', generation=row['generation'])
    generation = db.execute('SELECT * FROM inherit_generations WHERE world_id=? AND number=?',
                            (world_id, row['generation'])).fetchone()
    return dict(world=world_view(db, access(db, world_id, actor), actor), generation=generation_view(db, generation))


def offer(db, world_id, actor, payload):
    fields(payload, ('expectedRevision', 'targetUserId', 'sharingAcknowledged'))
    row = access(db, world_id, actor, write=True)
    expected(row, payload)
    require(payload.get('sharingAcknowledged') is True, 'Подтвердите передачу и доступ хранителей к истории.')
    target_id = payload.get('targetUserId')
    require(isinstance(target_id, str) and re.fullmatch(ID, target_id) and target_id != actor,
            'Укажите ID другого аккаунта Core.')
    person(db, target_id)
    require(pending(db, row) is None, 'У мира уже ожидается передача.', 'handoff_pending', 409)
    require(row['generation'] > row['custody_start'], 'Сначала сохраните поколение со своим следом.', 'generation_required', 409)
    require(db.execute('SELECT COUNT(*) FROM inherit_handoffs WHERE world_id=?', (world_id,)).fetchone()[0] < LIMITS['handoffs'],
            'Достигнут предел передач мира.', 'handoff_limit', 409)
    require(db.execute('SELECT COUNT(*) FROM inherit_members WHERE world_id=?', (world_id,)).fetchone()[0] < LIMITS['members'] or
            db.execute('SELECT 1 FROM inherit_members WHERE world_id=? AND user_id=?', (world_id, target_id)).fetchone(),
            'Достигнут предел хранителей мира.', 'member_limit', 409)
    clear_expired(db, row)
    invitation_id, stamp = uid(), now()
    db.execute('INSERT INTO inherit_handoffs VALUES(?,?,?,?,?,?,?,?)',
               (invitation_id, world_id, actor, target_id, 'pending', row['revision'] + 1, stamp, time.time() + 7*86400))
    db.execute('UPDATE inherit_worlds SET revision=revision+1,pending_handoff=?,updated_at=? WHERE id=?',
               (invitation_id, stamp, world_id))
    notify(db, target_id, world_id, actor, 'handoff_offered', invitation_id)
    return dict(world=world_view(db, access(db, world_id, actor), actor),
                invitation=invitation_view(db, handoff_access(db, invitation_id, actor)))


def transition(db, invitation_id, action, actor, payload):
    fields(payload, ('expectedRevision',))
    invitation = handoff_access(db, invitation_id, actor)
    allowed_actor = invitation['from_id'] if action == 'cancel' else invitation['to_id']
    require(actor == allowed_actor, 'Действие недоступно этому аккаунту.', 'forbidden', 403)
    row = db.execute('SELECT * FROM inherit_worlds WHERE id=?', (invitation['world_id'],)).fetchone()
    expected(row, payload)
    require(row['pending_handoff'] == invitation_id and row['custodian_id'] == invitation['from_id'] and
            row['revision'] == invitation['expected_revision'], 'Передача уже изменилась.', 'handoff_conflict', 409)
    require(invitation_status(invitation) == 'pending', 'Передача завершена или истекла.', 'handoff_closed', 409)
    stamp = now()
    status = {'accept': 'accepted', 'cancel': 'cancelled', 'decline': 'declined'}[action]
    if action == 'accept':
        require(db.execute('SELECT COUNT(*) FROM inherit_members WHERE user_id=?', (actor,)).fetchone()[0] < 256 or
                db.execute('SELECT 1 FROM inherit_members WHERE world_id=? AND user_id=?', (row['id'], actor)).fetchone(),
                'Достигнут предел доступных миров.', 'membership_limit', 409)
    db.execute('UPDATE inherit_handoffs SET status=? WHERE id=?', (status, invitation_id))
    if action == 'accept':
        db.execute('INSERT OR IGNORE INTO inherit_members VALUES(?,?,?)', (row['id'], actor, stamp))
        db.execute('UPDATE inherit_worlds SET revision=revision+1,custodian_id=?,custody_start=generation, '
                   'pending_handoff=NULL,updated_at=? WHERE id=?', (actor, stamp, row['id']))
    else:
        db.execute('UPDATE inherit_worlds SET revision=revision+1,pending_handoff=NULL,updated_at=? WHERE id=?',
                   (stamp, row['id']))
    other = invitation['from_id'] if actor == invitation['to_id'] else invitation['to_id']
    notify(db, other, row['id'], actor, 'handoff_' + status, invitation_id)
    result = {'invitation': invitation_view(db, handoff_access(db, invitation_id, actor))}
    # Declining an invitation grants no access to the private world's contents.
    if action != 'decline' or db.execute('SELECT 1 FROM inherit_members WHERE world_id=? AND user_id=?', (row['id'], actor)).fetchone():
        result['world'] = world_view(db, access(db, row['id'], actor), actor)
    return result


def mutate(db, route, actor, payload, key):
    route = route.removeprefix(PREFIX)
    world_id = invitation_id = None
    if route == 'worlds':
        kind, result = 'create', create(db, actor, payload)
    else:
        match = re.fullmatch('worlds/(' + ID + ')/(generations|handoffs)', route)
        handoff = re.fullmatch('handoffs/(' + ID + ')/(accept|cancel|decline)', route)
        notification = re.fullmatch(r'notifications/([1-9][0-9]{0,17})/read', route)
        if match:
            world_id = match[1]
            kind = 'generation' if match[2] == 'generations' else 'offer'
            result = append(db, world_id, actor, payload) if kind == 'generation' else offer(db, world_id, actor, payload)
        elif handoff:
            invitation_id, kind = handoff[1], handoff[2]
            result = transition(db, invitation_id, kind, actor, payload)
        elif notification:
            fields(payload, ())
            row = db.execute('SELECT * FROM inherit_notifications WHERE id=? AND user_id=?', (int(notification[1]), actor)).fetchone()
            require(row is not None, 'Уведомление не найдено.', 'not_found', 404)
            db.execute('UPDATE inherit_notifications SET read_at=COALESCE(read_at,?) WHERE id=?', (now(), row['id']))
            result = {'notification': notification_view(db, db.execute('SELECT * FROM inherit_notifications WHERE id=?', (row['id'],)).fetchone())}
            kind = 'notification_read'
        else:
            raise Fault('not_found', 'Маршрут INHERIT не найден.', 404)
    if 'world' in result:
        world_id = result['world']['id']
    if 'invitation' in result:
        invitation_id = result['invitation']['id']
    result['operation'] = dict(key=key, kind=kind, status='committed', worldId=world_id, invitationId=invitation_id)
    db.execute('INSERT INTO inherit_operations VALUES(?,?,?,?,?,?)',
               (actor, key, world_id, invitation_id, encoded(result), now()))
    return result
