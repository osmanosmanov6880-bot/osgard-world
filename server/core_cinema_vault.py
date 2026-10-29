"""OSA CINEMA V63: private small-file ingestion using real bytes and SQLite BLOB.

SELF-HOSTED PILOT ONLY. Not a production media CDN, AV scanner, encrypted
evidence vault, rights-clearance engine, or public film delivery. Every byte is
kept within the private Core SQLite database, outside the public Vite webroot.
All downloads are authenticated attachments with a server-computed SHA-256.
"""
import hashlib
import json
from pathlib import PurePath
from urllib.parse import unquote
import re
import core_cinema
import core_cinema_ops
from core_model import Fault, require, now, uid

SCHEMA = '''
CREATE TABLE IF NOT EXISTS cinema_vault_assets(
  id TEXT PRIMARY KEY,
  space_id TEXT NOT NULL REFERENCES cinema_spaces(id) ON DELETE CASCADE,
  evidence_id TEXT REFERENCES cinema_evidence(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  mime TEXT NOT NULL,
  size_bytes INTEGER NOT NULL CHECK(size_bytes>0 AND size_bytes<=8388608),
  actual_sha256 TEXT NOT NULL,
  content BLOB NOT NULL,
  uploader_id TEXT NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL,
  CHECK(length(actual_sha256)=64),
  CHECK(length(content)=size_bytes)
);
CREATE INDEX IF NOT EXISTS cinema_vault_assets_space
  ON cinema_vault_assets(space_id,created_at);
'''
MAX_ASSET_BYTES=8*1024*1024
MAX_SPACE_BYTES=32*1024*1024
MAX_ASSETS=16
ID_PATTERN=re.compile(r'[a-f0-9]{32}\Z')
KEY_PATTERN=re.compile(r'[A-Za-z0-9_-]{16,100}\Z')
MIMES={
 'application/pdf':('.pdf',),
 'text/plain':('.txt',),
 'image/png':('.png',),
 'image/jpeg':('.jpg','.jpeg'),
 'image/webp':('.webp',),
 'video/mp4':('.mp4',),
}

def file_name(encoded_name,mime):
    require(isinstance(encoded_name,str) and 0<len(encoded_name)<=480,
            'Требуется короткое имя файла.','filename',400)
    try:name=unquote(encoded_name,encoding='utf-8',errors='strict')
    except UnicodeError:raise Fault('filename','Неверная кодировка имени файла.',400)
    name=name.strip()
    require(1<=len(name)<=120 and name not in ('.','..') and
            not any(c in name for c in ('/','\\','\x00',':')) and
            not any(ord(c)<32 or ord(c)==127 for c in name) and
            '..' not in name,
            'Имя файла не должно содержать путь или управляющие символы.','filename',400)
    require(name.lower().endswith(MIMES[mime]),
            'Расширение файла не соответствует разрешённому типу.','file_type',415)
    return name

def inspect_bytes(data,mime):
    require(isinstance(data,bytes) and 0<len(data)<=MAX_ASSET_BYTES,
            'Файл пустой или превышает 8 МиБ.','file_size',413)
    if mime=='application/pdf':ok=data.startswith(b'%PDF-')
    elif mime=='image/png':ok=data.startswith(b'\x89PNG\r\n\x1a\n')
    elif mime=='image/jpeg':ok=data.startswith(b'\xff\xd8\xff')
    elif mime=='image/webp':ok=data[:4]==b'RIFF' and data[8:12]==b'WEBP'
    elif mime=='video/mp4':ok=len(data)>=12 and data[4:8]==b'ftyp'
    elif mime=='text/plain':
        try:
            content=data.decode('utf-8')
            ok='\x00' not in content
        except UnicodeError:ok=False
    else:ok=False
    require(ok,'Сигнатура не соответствует объявленному формату. Это не AV-проверка.','file_signature',415)
    return hashlib.sha256(data).hexdigest()

def safe_space(space_id):
    require(isinstance(space_id,str) and ID_PATTERN.fullmatch(space_id),
            'Кинопространство не найдено.','not_found',404)
    return space_id

def snapshot(row):
    return dict(id=row['id'],spaceId=row['space_id'],evidenceId=row['evidence_id'],
                name=row['name'],mime=row['mime'],bytes=row['size_bytes'],
                actualSha256=row['actual_sha256'],checksumComputedFromBytes=True,
                malwareScanned=False,rightsIndependentlyVerified=False,
                filmReleaseAuthorized=False,uploader=row['username'],createdAt=row['created_at'])

def listing(db,space_id,actor):
    safe_space(space_id)
    space=core_cinema.access(db,space_id,actor)
    rows=db.execute('''SELECT a.id,a.space_id,a.evidence_id,a.name,a.mime,a.size_bytes,
                   a.actual_sha256,a.created_at,u.username
                   FROM cinema_vault_assets a JOIN users u ON u.id=a.uploader_id
                   WHERE a.space_id=? ORDER BY a.rowid DESC LIMIT 16''',(space_id,)).fetchall()
    assets=[snapshot(row) for row in rows]
    owner_quota=core_cinema_ops.owner_usage(db,space['owner_id'])
    return dict(spaceId=space_id,spaceVersion=space['version'],role=space['role'],
                assets=assets,usedBytes=sum(a['bytes'] for a in assets),
                limits=dict(maxAssetBytes=MAX_ASSET_BYTES,maxSpaceBytes=MAX_SPACE_BYTES,
                            maxAssets=MAX_ASSETS,maxOwnerBytes=core_cinema_ops.MAX_OWNER_BYTES),
                ownerUsedBytes=owner_quota['usedBytes'] if space['role']=='owner' else None,
                ownerRemainingBytes=owner_quota['remainingBytes'] if space['role']=='owner' else None,
                ownerQuotaEnforced=True,
                scope='Authenticated local SQLite BLOB storage; unencrypted and not antivirus scanned.',
                releaseAuthorized=False,publicVideoUrl=None,publicStreamingEnabled=False,
                encryptionAtRest=False,serverAntivirus=False)

def upload(store,space_id,actor,content,encoded_name,mime,key,expected_version,evidence_id=''):
    safe_space(space_id)
    require(isinstance(mime,str) and mime in MIMES,
            'Разрешены PDF, TXT, PNG, JPEG, WebP и MP4.','file_type',415)
    name=file_name(encoded_name,mime)
    actual_sha256=inspect_bytes(content,mime)
    require(isinstance(key,str) and KEY_PATTERN.fullmatch(key),
            'Нужен ключ идемпотентной загрузки.','idempotency',400)
    require(type(expected_version) is int and expected_version>0,
            'Требуется версия кинопространства.','version_conflict',409)
    evidence_id=evidence_id or ''
    require(not evidence_id or ID_PATTERN.fullmatch(evidence_id),
            'Неверный идентификатор материала.','validation',400)
    descriptor=json.dumps(dict(route='cinema-vault-upload',spaceId=space_id,
          expectedVersion=expected_version,name=name,mime=mime,hash=actual_sha256,
          bytes=len(content),evidenceId=evidence_id),sort_keys=True,separators=(',',':'))
    fingerprint=hashlib.sha256(descriptor.encode('utf-8')).hexdigest()
    with store.transaction() as db:
        space=core_cinema.access(db,space_id,actor,write=True)
        existing=db.execute('SELECT request_hash,response FROM operations WHERE user_id=? AND key=?',
                            (actor,key)).fetchone()
        if existing:
            require(existing['request_hash']==fingerprint,
                    'Ключ уже использован для других байтов или метаданных.','idempotency_conflict',409)
            prior=json.loads(existing['response'])
            prior['replayed']=True
            return prior
        require(space['version']==expected_version,
                'Версия пространства изменилась, обновите список файлов.','version_conflict',409)
        count,total=db.execute('''SELECT COUNT(*),COALESCE(SUM(size_bytes),0)
                     FROM cinema_vault_assets WHERE space_id=?''',(space_id,)).fetchone()
        require(count<MAX_ASSETS,'Максимум 16 файлов в пространстве пилота.','quota',409)
        require(total+len(content)<=MAX_SPACE_BYTES,
                'Ограничение пространства: максимум 32 МиБ.','quota',409)
        owner_used=core_cinema_ops.owner_usage(db,space['owner_id'])['usedBytes']
        require(owner_used+len(content)<=core_cinema_ops.MAX_OWNER_BYTES,
                'Общая квота владельца: максимум 64 МиБ для всех кинопространств.',
                'owner_quota',409)
        if evidence_id:
            link=db.execute('SELECT id FROM cinema_evidence WHERE id=? AND space_id=?',
                            (evidence_id,space_id)).fetchone()
            require(link is not None,'Связанный материал не принадлежит кинопространству.','not_found',404)
        aid=uid()
        db.execute('''INSERT INTO cinema_vault_assets
                 (id,space_id,evidence_id,name,mime,size_bytes,actual_sha256,content,uploader_id,created_at)
                 VALUES(?,?,?,?,?,?,?,?,?,?)''',
                 (aid,space_id,evidence_id or None,name,mime,len(content),
                  actual_sha256,content,actor,now()))
        db.execute('UPDATE cinema_spaces SET version=version+1,updated_at=? WHERE id=?',
                   (now(),space_id))
        core_cinema.event(db,space_id,actor,'vault_asset_uploaded',
                          {'assetId':aid,'actualSha256':actual_sha256,'bytes':len(content),
                           'evidenceLinked':bool(evidence_id)})
        result=dict(assetId=aid,spaceId=space_id,spaceVersion=space['version']+1,
              actualSha256=actual_sha256,checksumComputedFromBytes=True,
              bytes=len(content),mime=mime,name=name,
              malwareScanned=False,encryptionAtRest=False,releaseAuthorized=False,
              publicVideoUrl=None,replayed=False)
        require(db.execute('SELECT COUNT(*) FROM operations WHERE user_id=?',
                           (actor,)).fetchone()[0]<10000,
                'Достигнут лимит операций пилота.','quota',409)
        db.execute('INSERT INTO operations(user_id,key,request_hash,response,created_at) VALUES(?,?,?,?,?)',
                   (actor,key,fingerprint,json.dumps(result,ensure_ascii=False,separators=(',',':')),now()))
        return result

def download(store,space_id,asset_id,actor):
    safe_space(space_id)
    require(isinstance(asset_id,str) and ID_PATTERN.fullmatch(asset_id),
            'Файл не найден.','not_found',404)
    with store.connect() as db:
        db.execute('BEGIN')
        core_cinema.access(db,space_id,actor)
        row=db.execute('''SELECT a.* FROM cinema_vault_assets a
                 WHERE a.space_id=? AND a.id=?''',(space_id,asset_id)).fetchone()
        require(row is not None,'Файл не найден.','not_found',404)
        data=bytes(row['content'])
        require(len(data)==row['size_bytes'] and
                hashlib.sha256(data).hexdigest()==row['actual_sha256'],
                'Проверка целостности не пройдена. Файл не отправлен.','integrity',503)
        return dict(bytes=data,actualSha256=row['actual_sha256'],name=row['name'],
                    mime=row['mime'],size=len(data),assetId=asset_id)

def mutate(db,space_id,actor,payload):
    safe_space(space_id)
    require(isinstance(payload,dict) and set(payload)=={'kind','expectedVersion','assetId'},
            'Разрешено только удаление по ID и точной версии.','validation',400)
    require(payload.get('kind')=='asset.delete','Неизвестная операция.','validation',400)
    space=core_cinema.access(db,space_id,actor,write=True)
    require(type(payload.get('expectedVersion')) is int and
            payload['expectedVersion']==space['version'],
            'Версия пространства изменилась, обновите данные.','version_conflict',409)
    asset_id=payload.get('assetId')
    require(isinstance(asset_id,str) and ID_PATTERN.fullmatch(asset_id),
            'Файл не найден.','not_found',404)
    row=db.execute('SELECT actual_sha256,size_bytes FROM cinema_vault_assets WHERE space_id=? AND id=?',
                   (space_id,asset_id)).fetchone()
    require(row is not None,'Файл не найден.','not_found',404)
    db.execute('DELETE FROM cinema_vault_assets WHERE space_id=? AND id=?',(space_id,asset_id))
    db.execute('UPDATE cinema_spaces SET version=version+1,updated_at=? WHERE id=?',
               (now(),space_id))
    core_cinema.event(db,space_id,actor,'vault_asset_deleted',
                      {'assetId':asset_id,'actualSha256':row['actual_sha256'],
                       'bytes':row['size_bytes']})
    return dict(deleted=True,assetId=asset_id,spaceVersion=space['version']+1,
                releaseAuthorized=False,publicVideoUrl=None,
                backupMayRetainDeletedBytes=True)
