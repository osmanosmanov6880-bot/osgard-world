"""OSA CINEMA V62: private evidence *metadata* review, not verification of media or legal rights.

Source URLs and checksums are user declarations: no document upload, URL fetch,
cryptographic attestation by this service, independent legal review or permission
to publish films. Access is authenticated via the existing OSGARD Core server.
"""
from urllib.parse import urlsplit
import ipaddress
import re
import json
import core_cinema
from core_model import Fault,require,uid,now

SCHEMA = '''
CREATE TABLE IF NOT EXISTS cinema_evidence(
  id TEXT PRIMARY KEY,
  space_id TEXT NOT NULL REFERENCES cinema_spaces(id) ON DELETE CASCADE,
  version INTEGER NOT NULL CHECK(version>=1),
  scene_id TEXT NOT NULL,
  category TEXT NOT NULL CHECK(category IN ('script','shotlist','casting','location','safety','rights','post','master','delivery')),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  source_url TEXT NOT NULL,
  declared_sha256 TEXT NOT NULL,
  state TEXT NOT NULL CHECK(state IN ('draft','review_requested','needs_changes','internally_reviewed')),
  author_id TEXT NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS cinema_evidence_reviews(
  id TEXT PRIMARY KEY,
  evidence_id TEXT NOT NULL REFERENCES cinema_evidence(id) ON DELETE CASCADE,
  space_id TEXT NOT NULL REFERENCES cinema_spaces(id) ON DELETE CASCADE,
  item_version INTEGER NOT NULL,
  reviewer_id TEXT NOT NULL REFERENCES users(id),
  verdict TEXT NOT NULL CHECK(verdict IN ('needs_changes','internally_reviewed')),
  note TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS cinema_evidence_space ON cinema_evidence(space_id,updated_at);
CREATE INDEX IF NOT EXISTS cinema_evidence_review_space ON cinema_evidence_reviews(space_id,evidence_id,created_at);
'''

MAX_ITEMS = 80
MAX_REVIEWS = 500
CATEGORIES = frozenset(('script','shotlist','casting','location','safety','rights','post','master','delivery'))
STATES = frozenset(('draft','review_requested','needs_changes','internally_reviewed'))
REVIEW_DECISIONS = frozenset(('needs_changes','internally_reviewed'))
ID_PATTERN = re.compile(r'[a-f0-9]{32}\Z')
HEX64 = re.compile(r'[a-fA-F0-9]{64}\Z')
FIELDS = {
 'evidence.create':frozenset(('kind','expectedVersion','sceneId','category','title','description','sourceUrl','declaredSha256')),
 'evidence.update':frozenset(('kind','expectedVersion','evidenceId','expectedItemVersion','sceneId','category','title','description','sourceUrl','declaredSha256')),
 'evidence.request_review':frozenset(('kind','expectedVersion','evidenceId','expectedItemVersion')),
 'evidence.review':frozenset(('kind','expectedVersion','evidenceId','expectedItemVersion','verdict','note')),
}

def bounded(value,max_len,min_len=0):
    require(isinstance(value,str) and min_len<=len(value.strip())<=max_len,'Проверьте длину текста.')
    require(not any(ord(c)<32 and c not in ('\n','\t') for c in value),
            'Управляющие символы в тексте недопустимы.')
    return value.strip()

def https_reference(value):
    value=bounded(value,800)
    if not value:return ''
    p=urlsplit(value)
    require(p.scheme=='https' and p.hostname and not p.username and not p.password and not any(c.isspace() for c in value),
            'Источник должен быть ссылкой HTTPS без пароля.')
    require(not p.fragment,'Не включайте скрытые фрагменты или токены в ссылку.')
    host=p.hostname
    require(host and '.' in host and not host.endswith(('.local','.internal','.localhost','.test')),
            'Не используйте внутренние адреса для общего реестра.')
    try:
        ip=ipaddress.ip_address(host)
        require(ip.is_global,'IP-адрес источника должен быть публичным.')
    except ValueError:
        pass
    return value

def checksum(value):
    require(isinstance(value,str) and (not value or HEX64.fullmatch(value)),
            'Объявленный SHA-256 должен быть пустым или содержать 64 шестнадцатеричных символа.')
    return value.lower()

def evidence_fields(payload,film):
    category=payload.get('category')
    require(isinstance(category,str) and category in CATEGORIES,'Неизвестный тип материала.')
    return dict(
      scene=core_cinema.check_scene(film,payload.get('sceneId')),
      category=category,
      title=bounded(payload.get('title'),140,3),
      description=bounded(payload.get('description',''),1000),
      source=https_reference(payload.get('sourceUrl','')),
      sha=checksum(payload.get('declaredSha256',''))
    )

def ensure_item(db,space_id,item_id):
    require(isinstance(item_id,str) and ID_PATTERN.fullmatch(item_id),
            'Материал не найден.','not_found',404)
    item=db.execute('SELECT * FROM cinema_evidence WHERE id=? AND space_id=?',
                    (item_id,space_id)).fetchone()
    require(item is not None,'Материал не найден.','not_found',404)
    return item

def check_item_version(item,payload):
    require(type(payload.get('expectedItemVersion')) is int and
            payload['expectedItemVersion']==item['version'],
            'Материал изменён. Загрузите актуальную версию.','version_conflict',409)

def listing(db,space_id,actor):
    space=core_cinema.access(db,space_id,actor)
    items=[]
    for item in db.execute('''
         SELECT e.*,u.username AS author FROM cinema_evidence e
         JOIN users u ON u.id=e.author_id
         WHERE e.space_id=? ORDER BY e.updated_at DESC,e.rowid DESC
         LIMIT 80''',(space_id,)):
        row=dict(
           id=item['id'],sceneId=item['scene_id'],category=item['category'],
           title=item['title'],description=item['description'],
           sourceUrl=item['source_url'],declaredSha256=item['declared_sha256'],
           checksumVerifiedByServer=False,externalRightsVerified=False,
           state=item['state'],version=item['version'],authorId=item['author_id'],
           author=item['author'],createdAt=item['created_at'],updatedAt=item['updated_at']
        )
        rows=db.execute('''
          SELECT r.id,r.verdict,r.note,r.item_version,r.created_at,u.username AS reviewer
          FROM cinema_evidence_reviews r JOIN users u ON u.id=r.reviewer_id
          WHERE r.evidence_id=? AND r.space_id=? ORDER BY r.created_at DESC,r.rowid DESC
          LIMIT 30''',(item['id'],space_id)).fetchall()
        row['reviews']=[dict(id=r['id'],verdict=r['verdict'],note=r['note'],
                    itemVersion=r['item_version'],reviewer=r['reviewer'],createdAt=r['created_at']) for r in rows]
        items.append(row)
    return dict(spaceId=space_id,spaceVersion=space['version'],role=space['role'],
                evidence=items,scope='Private metadata declared by users. No files fetched or verified.',
                releaseAuthorized=False,rightsIndependentlyVerified=False,publicVideoUrl=None,
                verificationLimits={'independentProfessionalAudit':False,'checksumCalculatedFromFiles':False,
                                    'legalRightsClearance':False,'actualFilmingCertified':False})

def mutate(db,space_id,actor,payload):
    require(isinstance(payload,dict),'Ожидается объект изменений.')
    kind=payload.get('kind')
    require(isinstance(kind,str) and kind in FIELDS,'Неизвестное действие с материалами.')
    require(set(payload)<=FIELDS[kind],
            'Служебные поля публикации и неизвестные свойства запрещены.')
    space=core_cinema.access(db,space_id,actor,write=True)
    require(type(payload.get('expectedVersion')) is int and payload['expectedVersion']==space['version'],
            'Пространство изменено в другой вкладке. Обновите данные.','version_conflict',409)
    stamp=now()
    if kind=='evidence.create':
        require(db.execute('SELECT COUNT(*) FROM cinema_evidence WHERE space_id=?',(space_id,)).fetchone()[0]<MAX_ITEMS,
                'Достигнут лимит материалов пространства.',status=409)
        fields=evidence_fields(payload,space['film_id'])
        item_id=uid()
        db.execute('''INSERT INTO cinema_evidence
            (id,space_id,version,scene_id,category,title,description,source_url,
             declared_sha256,state,author_id,created_at,updated_at)
            VALUES (?,?,1,?,?,?,?,?,?,'draft',?,?,?)''',
            (item_id,space_id,fields['scene'],fields['category'],fields['title'],
             fields['description'],fields['source'],fields['sha'],actor,stamp,stamp))
        action='evidence_created';state='draft'
    else:
        item=ensure_item(db,space_id,payload.get('evidenceId'))
        check_item_version(item,payload)
        item_id=item['id']
        if kind=='evidence.update':
            require(item['state'] in ('draft','needs_changes'),
                    'Материал на проверке или уже внутренне рассмотрен. Новый цикл потребуется отдельно.','review_locked',409)
            require(item['author_id']==actor or space['role']=='owner',
                    'Изменять черновик может автор или владелец.','forbidden',403)
            fields=evidence_fields(payload,space['film_id'])
            db.execute('''UPDATE cinema_evidence SET version=version+1,scene_id=?,category=?,
               title=?,description=?,source_url=?,declared_sha256=?,state='draft',updated_at=?
               WHERE id=? AND space_id=?''',
               (fields['scene'],fields['category'],fields['title'],fields['description'],
                fields['source'],fields['sha'],stamp,item_id,space_id))
            action='evidence_updated';state='draft'
        elif kind=='evidence.request_review':
            require(item['state'] in ('draft','needs_changes'),'Материал не готов к повторной отправке.','review_locked',409)
            require(item['author_id']==actor or space['role']=='owner',
                    'Отправить на проверку может автор или владелец.','forbidden',403)
            require(bool(item['source_url'] or item['declared_sha256']),
                    'Для рассмотрения нужно указать ссылку или объявленную SHA-256.')
            db.execute('''UPDATE cinema_evidence SET version=version+1,state='review_requested',updated_at=?
                          WHERE id=? AND space_id=?''',(stamp,item_id,space_id))
            action='evidence_review_requested';state='review_requested'
        else:
            require(kind=='evidence.review','Неподдерживаемый тип действия.')
            require(item['state']=='review_requested','Материал ещё не направлен на проверку.','review_locked',409)
            require(item['author_id']!=actor,'Нельзя проверить собственный материал.','self_review',403)
            verdict=payload.get('verdict')
            require(isinstance(verdict,str) and verdict in REVIEW_DECISIONS,'Неверное решение.')
            note=bounded(payload.get('note'),1000,20)
            require(db.execute('SELECT COUNT(*) FROM cinema_evidence_reviews WHERE space_id=?',(space_id,)).fetchone()[0]<MAX_REVIEWS,
                    'Лимит внутренних проверок достигнут.',status=409)
            db.execute('''INSERT INTO cinema_evidence_reviews
                  (id,evidence_id,space_id,item_version,reviewer_id,verdict,note,created_at)
                  VALUES (?,?,?,?,?,?,?,?)''',
                  (uid(),item_id,space_id,item['version'],actor,verdict,note,stamp))
            db.execute('''UPDATE cinema_evidence SET version=version+1,state=?,updated_at=?
                      WHERE id=? AND space_id=?''',(verdict,stamp,item_id,space_id))
            action='evidence_internal_reviewed' if verdict=='internally_reviewed' else 'evidence_changes_requested'
            state=verdict
    db.execute('UPDATE cinema_spaces SET version=version+1,updated_at=? WHERE id=?',(stamp,space_id))
    core_cinema.event(db,space_id,actor,action,{'evidenceId':item_id,'state':state})
    return dict(workspaceId=space_id,spaceVersion=space['version']+1,evidenceId=item_id,
                state=state,releaseAuthorized=False,publicVideoUrl=None,
                rightsIndependentlyVerified=False,professionalAuditCompleted=False)
