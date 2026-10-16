"""Account security with session revocation and two-phase offline recovery codes. No email."""
from datetime import datetime,timezone
import hashlib
import hmac
import json
import re
import secrets
import time
from core_model import Fault, require, text, now, uid

SCHEMA='''
CREATE TABLE IF NOT EXISTS session_details(token_hash TEXT PRIMARY KEY REFERENCES sessions(token_hash) ON DELETE CASCADE,created_at TEXT NOT NULL,label TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS recovery_codes(user_id TEXT REFERENCES users(id) ON DELETE CASCADE,code_hash TEXT NOT NULL,created_at TEXT NOT NULL,PRIMARY KEY(user_id,code_hash));
CREATE TABLE IF NOT EXISTS recovery_pending(user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,batch_id TEXT NOT NULL,session_hash TEXT NOT NULL,confirmation_hash TEXT NOT NULL,code_hashes TEXT NOT NULL,expires_at REAL NOT NULL);
CREATE TABLE IF NOT EXISTS recovery_batches(user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,batch_id TEXT NOT NULL,session_hash TEXT NOT NULL,confirmation_hash TEXT NOT NULL,activated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS account_events(id INTEGER PRIMARY KEY AUTOINCREMENT,user_id TEXT REFERENCES users(id) ON DELETE CASCADE,kind TEXT NOT NULL,detail TEXT NOT NULL,created_at TEXT NOT NULL);
'''

def digest(value):return hashlib.sha256(value.encode()).hexdigest()
def phash(password,salt):return hashlib.pbkdf2_hmac('sha256',password.encode(),bytes.fromhex(salt),600000).hex()
def valid_password(value):require(isinstance(value,str) and 12<=len(value)<=256,'Пароль: от 12 до 256 символов.');return value

def event(db,user,kind,detail):
    db.execute('INSERT INTO account_events(user_id,kind,detail,created_at) VALUES(?,?,?,?)',(user,kind,json.dumps(detail,ensure_ascii=False),now()))
    db.execute('DELETE FROM account_events WHERE user_id=? AND id NOT IN (SELECT id FROM account_events WHERE user_id=? ORDER BY id DESC LIMIT 500)',(user,user))

def session_id(hashed):return digest('session-id:'+hashed)

def guard_session(db,user,hashed):
    require(db.execute('SELECT 1 FROM sessions WHERE token_hash=? AND user_id=? AND expires_at>?',(hashed,user,time.time())).fetchone() is not None,'Сессия завершилась. Войдите снова.','unauthorized',401)

def checked_user(store,user,password):
    valid_password(password)
    with store.connect() as db:row=db.execute('SELECT * FROM users WHERE id=?',(user,)).fetchone()
    candidate=phash(password,row['salt'] if row else '00'*16)
    require(row is not None and hmac.compare_digest(candidate,row['password_hash']),'Текущий пароль неверен.','current_password',403)
    return row

def recheck(db,row):
    found=db.execute('SELECT password_hash FROM users WHERE id=?',(row['id'],)).fetchone()
    require(found is not None and hmac.compare_digest(found['password_hash'],row['password_hash']),'Пароль изменён другим запросом. Войдите заново.','credentials_changed',409)

def security(store,user,token):
    hashed=digest(token)
    with store.connect() as db:
        db.execute('BEGIN');guard_session(db,user,hashed)
        sessions=[dict(id=session_id(v['token_hash']),current=v['token_hash']==hashed,expiresAt=datetime.fromtimestamp(v['expires_at'],timezone.utc).isoformat(),createdAt=v['created_at'],label=v['label'] or 'Название приложения не передано') for v in db.execute('SELECT s.*,d.created_at,d.label FROM sessions s LEFT JOIN session_details d ON d.token_hash=s.token_hash WHERE s.user_id=? AND s.expires_at>? ORDER BY s.expires_at DESC',(user,time.time()))]
        batch=db.execute('SELECT batch_id,activated_at FROM recovery_batches WHERE user_id=?',(user,)).fetchone()
        logs=[dict(id=v['id'],kind=v['kind'],detail=json.loads(v['detail']),at=v['created_at']) for v in db.execute('SELECT * FROM account_events WHERE user_id=? ORDER BY id DESC LIMIT 50',(user,))]
        return dict(sessions=sessions,recoveryRemaining=db.execute('SELECT COUNT(*) FROM recovery_codes WHERE user_id=?',(user,)).fetchone()[0],recoveryBatch=dict(id=batch['batch_id'],activatedAt=batch['activated_at']) if batch else None,events=logs,emailRecovery=False,mfa=False)

def change_password(store,user,token,payload):
    row=checked_user(store,user,payload.get('currentPassword'));new=valid_password(payload.get('newPassword'));require(new!=payload['currentPassword'],'Новый пароль должен отличаться.')
    salt=secrets.token_hex(16);hashed=phash(new,salt);current=digest(token)
    with store.transaction() as db:
        guard_session(db,user,current);recheck(db,row)
        db.execute('UPDATE users SET salt=?,password_hash=? WHERE id=?',(salt,hashed,user))
        count=db.execute('SELECT COUNT(*) FROM sessions WHERE user_id=? AND token_hash!=?',(user,current)).fetchone()[0]
        db.execute('DELETE FROM sessions WHERE user_id=? AND token_hash!=?',(user,current));db.execute('DELETE FROM recovery_pending WHERE user_id=?',(user,))
        event(db,user,'password_changed',{'otherSessionsRevoked':count})
    return dict(changed=True,otherSessionsRevoked=count,currentSessionKept=True)

def revoke(store,user,token,payload):
    current=digest(token);target=payload.get('sessionId');require(isinstance(target,str) and re.fullmatch('[a-f0-9]{64}',target),'Неверный идентификатор сессии.')
    with store.transaction() as db:
        guard_session(db,user,current)
        rows=db.execute('SELECT token_hash FROM sessions WHERE user_id=?',(user,)).fetchall();found=next((r['token_hash'] for r in rows if hmac.compare_digest(session_id(r['token_hash']),target)),None)
        if found is None:return dict(revoked=True,current=False,alreadyAbsent=True)
        db.execute('DELETE FROM sessions WHERE token_hash=? AND user_id=?',(found,user));db.execute('DELETE FROM recovery_pending WHERE user_id=? AND session_hash=?',(user,found));event(db,user,'session_revoked',{'current':found==current})
        return dict(revoked=True,current=found==current)

def revoke_others(store,user,token):
    current=digest(token)
    with store.transaction() as db:
        guard_session(db,user,current);count=db.execute('SELECT COUNT(*) FROM sessions WHERE user_id=? AND token_hash!=?',(user,current)).fetchone()[0]
        db.execute('DELETE FROM sessions WHERE user_id=? AND token_hash!=?',(user,current));db.execute('DELETE FROM recovery_pending WHERE user_id=? AND session_hash!=?',(user,current));event(db,user,'other_sessions_revoked',{'count':count})
    return dict(revoked=count)

def prepare_codes(store,user,token,payload):
    row=checked_user(store,user,payload.get('currentPassword'));current=digest(token)
    raw=[secrets.token_hex(16) for _ in range(8)];codes=['-'.join(v[i:i+4] for i in range(0,32,4)) for v in raw];confirmation=secrets.token_urlsafe(32);batch=uid()
    with store.transaction() as db:
        guard_session(db,user,current);recheck(db,row)
        db.execute('INSERT INTO recovery_pending VALUES(?,?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET batch_id=excluded.batch_id,session_hash=excluded.session_hash,confirmation_hash=excluded.confirmation_hash,code_hashes=excluded.code_hashes,expires_at=excluded.expires_at',(user,batch,current,digest(confirmation),json.dumps([digest(v) for v in raw]),time.time()+600))
        event(db,user,'recovery_prepared',{'batchId':batch})
    return dict(batchId=batch,confirmation=confirmation,codes=codes,expiresInSeconds=600,active=False)

def activate_codes(store,user,token,payload):
    batch=text(payload.get('batchId'),32,32);confirmation=text(payload.get('confirmation'),100,40);current=digest(token)
    with store.transaction() as db:
        guard_session(db,user,current)
        active=db.execute('SELECT * FROM recovery_batches WHERE user_id=?',(user,)).fetchone()
        if active and active['batch_id']==batch and active['session_hash']==current and hmac.compare_digest(active['confirmation_hash'],digest(confirmation)):
            return dict(active=True,replayed=True,batchId=batch,remaining=db.execute('SELECT COUNT(*) FROM recovery_codes WHERE user_id=?',(user,)).fetchone()[0])
        pending=db.execute('SELECT * FROM recovery_pending WHERE user_id=?',(user,)).fetchone()
        require(pending is not None and pending['batch_id']==batch and pending['session_hash']==current and pending['expires_at']>time.time() and hmac.compare_digest(pending['confirmation_hash'],digest(confirmation)),'Подготовленный набор устарел или относится к другой сессии. Создайте новый.','recovery_pending',409)
        db.execute('DELETE FROM recovery_codes WHERE user_id=?',(user,));db.executemany('INSERT INTO recovery_codes VALUES(?,?,?)',[(user,v,now()) for v in json.loads(pending['code_hashes'])])
        db.execute('INSERT INTO recovery_batches VALUES(?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET batch_id=excluded.batch_id,session_hash=excluded.session_hash,confirmation_hash=excluded.confirmation_hash,activated_at=excluded.activated_at',(user,batch,current,digest(confirmation),now()))
        db.execute('DELETE FROM recovery_pending WHERE user_id=?',(user,));event(db,user,'recovery_activated',{'batchId':batch})
    return dict(active=True,batchId=batch,remaining=8)

def recover(store,payload):
    username=text(payload.get('username'),64,3).lower();new=valid_password(payload.get('newPassword'));code=payload.get('code')
    require(isinstance(code,str) and len(code)<=100,'Неверный код восстановления.')
    normalized=code.replace('-','').replace(' ','').lower();require(re.fullmatch('[a-f0-9]{32}',normalized),'Неверный код восстановления.','invalid_recovery',401)
    salt=secrets.token_hex(16);hashed=phash(new,salt)
    with store.transaction() as db:
        row=db.execute('SELECT id FROM users WHERE username=?',(username,)).fetchone()
        valid=db.execute('SELECT 1 FROM recovery_codes WHERE user_id=? AND code_hash=?',(row['id'],digest(normalized))).fetchone() if row else None
        require(valid is not None,'Логин или код восстановления неверен.','invalid_recovery',401)
        user=row['id'];db.execute('UPDATE users SET salt=?,password_hash=? WHERE id=?',(salt,hashed,user));db.execute('DELETE FROM sessions WHERE user_id=?',(user,))
        db.execute('DELETE FROM recovery_codes WHERE user_id=?',(user,));db.execute('DELETE FROM recovery_batches WHERE user_id=?',(user,));db.execute('DELETE FROM recovery_pending WHERE user_id=?',(user,));event(db,user,'account_recovered',{'allSessionsRevoked':True,'allOldCodesInvalidated':True})
    return dict(passwordReset=True,loginRequired=True,allOldCodesInvalidated=True)
