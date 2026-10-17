"""INHERIT pilot lineage: one custodian per generation, consented handoff, immutable snapshots.

This is an opt-in Core account API. The original anonymous /api/world/quiet-reach
demo is not silently converted into a public, writable shared world.
"""
import hashlib
import json
import math
import re

from core_model import Fault, now, require, text, uid

SCHEMA = """
CREATE TABLE IF NOT EXISTS inherit_worlds(
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    founder_id TEXT NOT NULL REFERENCES users(id),
    keeper_id TEXT NOT NULL REFERENCES users(id),
    generation INTEGER NOT NULL CHECK(generation BETWEEN 1 AND 101),
    version INTEGER NOT NULL CHECK(version >= 1),
    objects_json TEXT NOT NULL,
    pending_to TEXT REFERENCES users(id),
    pending_delta TEXT,
    pending_message TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS inherit_members(
    world_id TEXT NOT NULL REFERENCES inherit_worlds(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TEXT NOT NULL,
    PRIMARY KEY(world_id,user_id)
);
CREATE TABLE IF NOT EXISTS inherit_generations(
    world_id TEXT NOT NULL REFERENCES inherit_worlds(id) ON DELETE CASCADE,
    number INTEGER NOT NULL,
    keeper_id TEXT NOT NULL REFERENCES users(id),
    passed_to TEXT NOT NULL REFERENCES users(id),
    message TEXT NOT NULL,
    delta_json TEXT NOT NULL,
    snapshot_json TEXT NOT NULL,
    previous_hash TEXT NOT NULL,
    record_hash TEXT NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY(world_id,number)
);
CREATE TABLE IF NOT EXISTS inherit_events(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    world_id TEXT NOT NULL REFERENCES inherit_worlds(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK(kind IN ('invited','invitation_cancelled','handoff_accepted','new_generation')),
    generation INTEGER NOT NULL,
    detail TEXT NOT NULL,
    created_at TEXT NOT NULL,
    read_at TEXT
);
CREATE INDEX IF NOT EXISTS inherit_events_inbox ON inherit_events(user_id,id DESC);
"""

IDENTIFIER = re.compile(r"[a-f0-9]{32}\Z")
USERNAME = re.compile(r"[a-z0-9_.-]{3,64}\Z")
TOOLS = frozenset(("tree", "stone", "light", "path", "flower",
                   "arch", "chime", "moss", "cairn", "marker"))
MAX_GENERATIONS = 100
MAX_OBJECTS = 500
MAX_DELTA = 30


def _json(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False)


def _world(db, wid):
    require(isinstance(wid, str) and IDENTIFIER.fullmatch(wid),
            "Неверный идентификатор мира.")
    row = db.execute("SELECT * FROM inherit_worlds WHERE id=?", (wid,)).fetchone()
    require(row is not None, "Мир не найден.", "not_found", 404)
    return row


def _member(db, row, actor):
    member = db.execute(
        "SELECT 1 FROM inherit_members WHERE world_id=? AND user_id=?",
        (row["id"], actor)).fetchone()
    require(member is not None, "Мир не найден.", "not_found", 404)


def _username(db, user_id):
    row = db.execute("SELECT username FROM users WHERE id=?", (user_id,)).fetchone()
    require(row is not None, "Участник не найден.", "storage_unavailable", 503)
    return row["username"]


def _event(db, wid, user_id, kind, generation, detail):
    db.execute(
        "INSERT INTO inherit_events(world_id,user_id,kind,generation,detail,created_at) VALUES(?,?,?,?,?,?)",
        (wid, user_id, kind, generation, _json(detail), now()))
    # Keep notifications bounded; authoritative generations are not removed.
    db.execute(
        "DELETE FROM inherit_events WHERE user_id=? AND id NOT IN "
        "(SELECT id FROM inherit_events WHERE user_id=? ORDER BY id DESC LIMIT 300)",
        (user_id, user_id))


def _delta(value):
    require(isinstance(value, list) and 1 <= len(value) <= MAX_DELTA,
            "Передайте от 1 до 30 следов.")
    result = []
    for item in value:
        require(isinstance(item, dict) and set(item) in
                ({"type", "x", "y"}, {"tool", "x", "y"}),
                "Неверный формат следа.")
        kind = item.get("type", item.get("tool"))
        require(type(kind) is str and kind in TOOLS, "Неизвестный тип следа.")
        x, y = item.get("x"), item.get("y")
        require(type(x) in (int, float) and type(y) in (int, float)
                and math.isfinite(x) and math.isfinite(y)
                and 0 <= x <= 100 and 0 <= y <= 100,
                "Координаты должны быть от 0 до 100.")
        result.append({"type": kind, "x": round(x, 3), "y": round(y, 3)})
    return result


def _check_version(row, payload):
    require(type(payload.get("expectedVersion")) is int
            and payload["expectedVersion"] == row["version"],
            "Поколение изменилось. Загрузите актуальную версию.",
            "version_conflict", 409)
    require(type(payload.get("expectedGeneration")) is int
            and payload["expectedGeneration"] == row["generation"],
            "Поколение изменилось. Загрузите актуальный мир.",
            "generation_conflict", 409)


def _public_row(db, row, actor):
    pending = None
    if row["pending_to"] is not None and row["keeper_id"] == actor:
        pending = {
            "to": _username(db, row["pending_to"]),
            "message": row["pending_message"],
            "deltaCount": len(json.loads(row["pending_delta"]))
        }
    return {
        "id": row["id"],
        "title": row["title"],
        "generation": row["generation"],
        "version": row["version"],
        "keeper": _username(db, row["keeper_id"]),
        "founder": _username(db, row["founder_id"]),
        "myTurn": row["keeper_id"] == actor,
        "status": "awaiting_acceptance" if row["pending_to"] is not None else "active",
        "pending": pending,
        "updatedAt": row["updated_at"],
    }


def _check_history(db, row):
    records = db.execute(
        "SELECT * FROM inherit_generations WHERE world_id=? ORDER BY number",
        (row["id"],)).fetchall()
    previous = ""
    for number, item in enumerate(records, 1):
        require(item["number"] == number
                and item["previous_hash"] == previous,
                "История мира повреждена.", "lineage_integrity", 503)
        record = {
            "worldId": row["id"],
            "number": item["number"],
            "keeperId": item["keeper_id"],
            "passedTo": item["passed_to"],
            "message": item["message"],
            "delta": json.loads(item["delta_json"]),
            "snapshot": json.loads(item["snapshot_json"]),
            "createdAt": item["created_at"],
        }
        actual = hashlib.sha256((previous + ":" + _json(record)).encode()).hexdigest()
        require(actual == item["record_hash"], "История мира повреждена.",
                "lineage_integrity", 503)
        previous = actual
    require(len(records) + 1 == row["generation"],
            "История мира неполная.", "lineage_integrity", 503)
    expected_snapshot = json.loads(records[-1]["snapshot_json"]) if records else []
    require(json.loads(row["objects_json"]) == expected_snapshot,
            "Состояние не соответствует истории мира.", "lineage_integrity", 503)
    return records, previous


def listing(db, actor):
    rows = db.execute(
        "SELECT w.* FROM inherit_worlds w JOIN inherit_members m ON m.world_id=w.id "
        "WHERE m.user_id=? ORDER BY w.updated_at DESC,w.id LIMIT 51",
        (actor,)).fetchall()
    return {"worlds": [_public_row(db, row, actor) for row in rows[:50]],
            "truncated": len(rows) > 50, "format": "inherit-world-v1"}


def read(db, wid, actor):
    row = _world(db, wid)
    _member(db, row, actor)
    records, head = _check_history(db, row)
    return {
        "world": _public_row(db, row, actor),
        "snapshot": {"objects": json.loads(row["objects_json"])},
        "history": [{
            "number": item["number"], "keeper": _username(db, item["keeper_id"]),
            "passedTo": _username(db, item["passed_to"]),
            "message": item["message"], "delta": json.loads(item["delta_json"]),
            "snapshot": {"objects": json.loads(item["snapshot_json"])},
            "hash": item["record_hash"], "createdAt": item["created_at"]
        } for item in records],
        "historyHead": head,
        "limits": {"maximumGenerations": MAX_GENERATIONS,
                   "maximumObjects": MAX_OBJECTS, "maximumPerPass": MAX_DELTA},
    }


def inbox(db, actor):
    invitations = db.execute(
        "SELECT w.id,w.title,w.generation,w.version,u.username AS from_username "
        "FROM inherit_worlds w JOIN users u ON u.id=w.keeper_id "
        "WHERE w.pending_to=? ORDER BY w.updated_at DESC LIMIT 50",
        (actor,)).fetchall()
    events = db.execute(
        "SELECT id,world_id,kind,generation,detail,created_at,read_at "
        "FROM inherit_events WHERE user_id=? ORDER BY id DESC LIMIT 50",
        (actor,)).fetchall()
    return {
        "invitations": [dict(worldId=r["id"], title=r["title"],
                             generation=r["generation"], expectedVersion=r["version"],
                             fromUsername=r["from_username"]) for r in invitations],
        "events": [dict(id=r["id"], worldId=r["world_id"], kind=r["kind"],
                        generation=r["generation"], detail=json.loads(r["detail"]),
                        createdAt=r["created_at"], readAt=r["read_at"]) for r in events],
    }


def create(db, actor, payload):
    require(db.execute(
        "SELECT COUNT(*) FROM inherit_worlds WHERE founder_id=?", (actor,)).fetchone()[0] < 20,
        "Лимит 20 миров на аккаунт.", "limit", 409)
    wid, stamp = uid(), now()
    title = text(payload.get("title"), 100, 3)
    db.execute(
        "INSERT INTO inherit_worlds(id,title,founder_id,keeper_id,generation,version,"
        "objects_json,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?)",
        (wid, title, actor, actor, 1, 1, "[]", stamp, stamp))
    db.execute("INSERT INTO inherit_members VALUES(?,?,?)", (wid, actor, stamp))
    return {"worldId": wid, "world": _public_row(db, _world(db, wid), actor)}


def pass_world(db, wid, actor, payload):
    row = _world(db, wid)
    _member(db, row, actor)
    require(row["keeper_id"] == actor, "Только текущий хранитель меняет мир.",
            "forbidden", 403)
    _check_version(row, payload)
    _check_history(db, row)
    require(row["pending_to"] is None, "Сначала завершите текущую передачу.",
            "handoff_pending", 409)
    require(row["generation"] <= MAX_GENERATIONS, "Лимит поколений достигнут.",
            "generation_limit", 409)
    delta = _delta(payload.get("delta"))
    old_objects = json.loads(row["objects_json"])
    require(len(old_objects) + len(delta) <= MAX_OBJECTS,
            "Мир достиг лимита 500 следов. Экспортируйте историю.",
            "world_full", 409)
    target = text(payload.get("toUsername"), 64, 3).lower()
    require(USERNAME.fullmatch(target), "Неверное имя аккаунта.")
    user = db.execute("SELECT id FROM users WHERE username=?", (target,)).fetchone()
    require(user is not None, "Аккаунт получателя не найден.", "not_found", 404)
    require(user["id"] != actor, "Передача самому себе недоступна.")
    message = text(payload.get("message"), 240, 5)
    stamp = now()
    db.execute(
        "UPDATE inherit_worlds SET pending_to=?,pending_delta=?,pending_message=?,"
        "version=version+1,updated_at=? WHERE id=?",
        (user["id"], _json(delta), message, stamp, wid))
    _event(db, wid, user["id"], "invited", row["generation"],
           {"title": row["title"], "fromUsername": _username(db, actor)})
    return {"worldId": wid, "version": row["version"] + 1, "status": "awaiting_acceptance",
            "toUsername": target}


def accept(db, wid, actor, payload):
    row = _world(db, wid)
    require(row["pending_to"] == actor, "Приглашение не найдено.",
            "not_found", 404)
    _check_version(row, payload)
    records, prev_hash = _check_history(db, row)
    delta = json.loads(row["pending_delta"])
    objects = json.loads(row["objects_json"]) + delta
    require(len(objects) <= MAX_OBJECTS, "Лимит следов превышен.",
            "world_full", 409)
    stamp = now()
    record = {
        "worldId": wid, "number": row["generation"],
        "keeperId": row["keeper_id"], "passedTo": actor,
        "message": row["pending_message"], "delta": delta, "snapshot": objects,
        "createdAt": stamp,
    }
    record_hash = hashlib.sha256((prev_hash + ":" + _json(record)).encode()).hexdigest()
    db.execute(
        "INSERT INTO inherit_generations VALUES(?,?,?,?,?,?,?,?,?,?)",
        (wid, row["generation"], row["keeper_id"], actor, row["pending_message"],
         _json(delta), _json(objects), prev_hash, record_hash, stamp))
    db.execute(
        "INSERT OR IGNORE INTO inherit_members VALUES(?,?,?)", (wid, actor, stamp))
    db.execute(
        "UPDATE inherit_worlds SET keeper_id=?,generation=generation+1,version=version+1,"
        "objects_json=?,pending_to=NULL,pending_delta=NULL,pending_message=NULL,"
        "updated_at=? WHERE id=?",
        (actor, _json(objects), stamp, wid))
    _event(db, wid, row["keeper_id"], "new_generation", row["generation"] + 1,
           {"newKeeper": _username(db, actor)})
    _event(db, wid, actor, "handoff_accepted", row["generation"] + 1,
           {"fromUsername": _username(db, row["keeper_id"])})
    return {"worldId": wid, "generation": row["generation"] + 1,
            "version": row["version"] + 1, "recordHash": record_hash,
            "accepted": True}


def cancel(db, wid, actor, payload):
    row = _world(db, wid)
    _member(db, row, actor)
    require(row["keeper_id"] == actor, "Только хранитель отменяет передачу.",
            "forbidden", 403)
    _check_version(row, payload)
    require(row["pending_to"] is not None, "Нет ожидающей передачи.",
            "not_found", 404)
    stamp = now()
    target = row["pending_to"]
    db.execute(
        "UPDATE inherit_worlds SET pending_to=NULL,pending_delta=NULL,"
        "pending_message=NULL,version=version+1,updated_at=? WHERE id=?",
        (stamp, wid))
    _event(db, wid, target, "invitation_cancelled", row["generation"],
           {"title": row["title"]})
    return {"worldId": wid, "version": row["version"] + 1, "cancelled": True}


def acknowledge(db, actor, payload):
    eid = payload.get("eventId")
    require(type(eid) is int and eid > 0, "Неверный идентификатор уведомления.")
    changed = db.execute(
        "UPDATE inherit_events SET read_at=COALESCE(read_at,?) "
        "WHERE id=? AND user_id=? RETURNING id",
        (now(), eid, actor)).fetchone()
    require(changed is not None, "Уведомление не найдено.", "not_found", 404)
    return {"acknowledged": True, "eventId": eid}


def retry_guard(db, route, actor, old):
    # An operation can be retried after logout/login, but its account must still
    # have access. The original request is never executed for a second time.
    if route == "inherit/worlds":
        wid = old.get("worldId")
        _member(db, _world(db, wid), actor)
    elif route.startswith("inherit/worlds/"):
        matched = re.fullmatch(r"inherit/worlds/([a-f0-9]{32})/(pass|accept|cancel)", route)
        if matched:
            _member(db, _world(db, matched[1]), actor)
    elif route == "inherit/inbox/ack":
        eid = old.get("eventId")
        require(db.execute(
            "SELECT 1 FROM inherit_events WHERE id=? AND user_id=?",
            (eid, actor)).fetchone() is not None,
            "Уведомление не найдено.", "not_found", 404)


def get(db, route, actor):
    if route == "inherit/worlds":
        return listing(db, actor)
    if route == "inherit/inbox":
        return inbox(db, actor)
    match = re.fullmatch(r"inherit/worlds/([a-f0-9]{32})", route)
    require(match is not None, "Маршрут API не найден.", "not_found", 404)
    return read(db, match[1], actor)


def mutate(db, route, actor, payload):
    if route == "inherit/worlds":
        return create(db, actor, payload)
    if route == "inherit/inbox/ack":
        return acknowledge(db, actor, payload)
    match = re.fullmatch(r"inherit/worlds/([a-f0-9]{32})/(pass|accept|cancel)", route)
    require(match is not None, "Маршрут API не найден.", "not_found", 404)
    return {"pass": pass_world, "accept": accept, "cancel": cancel}[match[2]](
        db, match[1], actor, payload)
