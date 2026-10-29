"""OSA CINEMA V61: authenticated, owner-scoped collaboration *pilot* for production planning.
No public media URLs, film rights approval, payments or release authorization.
"""
from datetime import date as calendar_date
import json
import re
from core_model import Fault, require, text, uid, now

SCHEMA = '''
CREATE TABLE IF NOT EXISTS cinema_spaces(
 id TEXT PRIMARY KEY,
 owner_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 film_id TEXT NOT NULL CHECK(film_id IN ('zero-window','threshold')),
 title TEXT NOT NULL,
 version INTEGER NOT NULL CHECK(version>=1),
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL,
 UNIQUE(owner_id,film_id)
);
CREATE TABLE IF NOT EXISTS cinema_members(
 space_id TEXT NOT NULL REFERENCES cinema_spaces(id) ON DELETE CASCADE,
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 role TEXT NOT NULL CHECK(role IN ('editor','viewer')),
 PRIMARY KEY(space_id,user_id)
);
CREATE TABLE IF NOT EXISTS cinema_tasks(
 id TEXT PRIMARY KEY,
 space_id TEXT NOT NULL REFERENCES cinema_spaces(id) ON DELETE CASCADE,
 scene_id TEXT NOT NULL,
 category TEXT NOT NULL CHECK(category IN ('script','casting','location','camera','sound','rights','safety','post')),
 title TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('planned','in_progress','blocked','ready_for_review')),
 owner_label TEXT NOT NULL,
 due_date TEXT NOT NULL,
 notes TEXT NOT NULL,
 created_by TEXT NOT NULL REFERENCES users(id),
 updated_by TEXT NOT NULL REFERENCES users(id),
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS cinema_audit(
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 space_id TEXT NOT NULL REFERENCES cinema_spaces(id) ON DELETE CASCADE,
 actor_id TEXT NOT NULL REFERENCES users(id),
 kind TEXT NOT NULL,
 detail TEXT NOT NULL,
 created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS cinema_spaces_owner ON cinema_spaces(owner_id,updated_at);
CREATE INDEX IF NOT EXISTS cinema_tasks_space ON cinema_tasks(space_id,created_at);
CREATE INDEX IF NOT EXISTS cinema_audit_space ON cinema_audit(space_id,id);
'''

FILMS = ('zero-window','threshold')
CATEGORIES = ('script','casting','location','camera','sound','rights','safety','post')
TASK_STATES = ('planned','in_progress','blocked','ready_for_review')
SCENES = frozenset('S'+str(i).zfill(2) for i in range(1,14))
MAX_WORKSPACES = 10
MAX_TEAM_MEMBERS = 20
MAX_TASKS = 100
MAX_AUDIT = 2000
# Strict request fields: the collaboration plane cannot accept release or video controls.
CREATE_FIELDS = frozenset(('filmId','title'))
TASK_FIELDS = frozenset(('kind','expectedVersion','sceneId','category','title','status','owner','dueDate','notes'))
TASK_EDIT_FIELDS = TASK_FIELDS | {'taskId'}
DELETE_FIELDS = frozenset(('kind','expectedVersion','taskId'))
MEMBER_FIELDS = frozenset(('kind','expectedVersion','username','role'))
RENAME_FIELDS = frozenset(('kind','expectedVersion','title'))
LEAVE_FIELDS = frozenset(('kind','expectedVersion'))
ALLOWED_FIELDS = {
 'task.create': TASK_FIELDS,
 'task.update': TASK_EDIT_FIELDS,
 'task.delete': DELETE_FIELDS,
 'member.set': MEMBER_FIELDS,
 'member.remove': MEMBER_FIELDS - {'role'},
 'space.rename': RENAME_FIELDS,
 'leave': LEAVE_FIELDS,
}
def allowed_payload(payload,allowed):
    require(set(payload).issubset(allowed),'Поле не допускается в планировщике. Он не управляет выпуском фильмов.')


def safe_string(value, maximum, minimum=0):
    result = text(value,maximum,minimum)
    require(not any(ord(x)<32 and x not in '\n\t' for x in result),
            'Уберите управляющие символы из текста.')
    return result

def due_date(value):
    require(isinstance(value,str) and (not value or re.fullmatch(r'\d{4}-\d{2}-\d{2}',value)),
            'Неверная плановая дата.')
    if value:
        try:require(calendar_date.fromisoformat(value).isoformat()==value,'Неверная плановая дата.')
        except ValueError:raise Fault('validation','Неверная плановая дата.')
    return value

def access(db,space_id,actor,write=False,owner=False):
    require(isinstance(space_id,str) and re.fullmatch('[a-f0-9]{32}',space_id),
            'Рабочее пространство не найдено.','not_found',404)
    row=db.execute("""
      SELECT s.*,CASE WHEN s.owner_id=? THEN 'owner' ELSE m.role END role
      FROM cinema_spaces s LEFT JOIN cinema_members m
        ON m.space_id=s.id AND m.user_id=?
      WHERE s.id=? AND (s.owner_id=? OR m.user_id=?)
    """,(actor,actor,space_id,actor,actor)).fetchone()
    require(row is not None,'Рабочее пространство не найдено.','not_found',404)
    require(not write or row['role'] in ('owner','editor'),
            'Нужны права редактора.','forbidden',403)
    require(not owner or row['role']=='owner',
            'Нужны права владельца.','forbidden',403)
    return row

def summary(row):
    return dict(id=row['id'],filmId=row['film_id'],title=row['title'],version=row['version'],
                role=row['role'],createdAt=row['created_at'],updatedAt=row['updated_at'],
                publicFilmReleaseAuthorized=False,
                rightsIndependentlyVerified=False,publicVideoUrl=None)

def task_summary(t):
    return dict(id=t['id'],sceneId=t['scene_id'],category=t['category'],
                title=t['title'],status=t['status'],owner=t['owner_label'],
                dueDate=t['due_date'],notes=t['notes'],
                createdAt=t['created_at'],updatedAt=t['updated_at'])

def event(db,space_id,actor,kind,details):
    require(db.execute('SELECT COUNT(*) FROM cinema_audit WHERE space_id=?',(space_id,)).fetchone()[0]<MAX_AUDIT,
            'Лимит событий пилота достигнут. Сохраните резервную копию.',status=409)
    db.execute('INSERT INTO cinema_audit(space_id,actor_id,kind,detail,created_at) VALUES(?,?,?,?,?)',
              (space_id,actor,kind,json.dumps(details,ensure_ascii=False,separators=(',',':')),now()))

def read(db,space_id,actor):
    row=access(db,space_id,actor)
    people=[dict(id=row['owner_id'],username=db.execute(
        'SELECT username FROM users WHERE id=?',(row['owner_id'],)).fetchone()['username'],role='owner')]
    people.extend(dict(v) for v in db.execute("""
      SELECT u.id,u.username,m.role FROM cinema_members m JOIN users u ON u.id=m.user_id
      WHERE m.space_id=? ORDER BY u.username
    """,(space_id,)))
    tasks=[task_summary(t) for t in db.execute(
      'SELECT * FROM cinema_tasks WHERE space_id=? ORDER BY created_at DESC,id DESC',(space_id,))]
    audit=[dict(id=e['id'],kind=e['kind'],detail=json.loads(e['detail']),actor=e['actor'],
                at=e['created_at']) for e in db.execute("""
      SELECT a.*,u.username AS actor FROM cinema_audit a JOIN users u ON u.id=a.actor_id
      WHERE a.space_id=? ORDER BY a.id DESC LIMIT 100
    """,(space_id,))]
    return dict(space=summary(row),members=people,tasks=tasks,audit=audit,
                limits=dict(maxTasks=MAX_TASKS,maxTeamMembers=MAX_TEAM_MEMBERS,
                    noIndependentRightsAudit=True,noFilmPremiere=True,noPublicVideo=True,
                    serverScope='Self-hosted Core SQLite pilot; no managed cloud availability, encrypted evidence vault or SSO',
                    notesAreProductionPlanningOnly=True))

def listing(db,actor):
    rows=db.execute("""
      SELECT s.*,CASE WHEN s.owner_id=? THEN 'owner' ELSE m.role END role
      FROM cinema_spaces s LEFT JOIN cinema_members m
        ON m.space_id=s.id AND m.user_id=?
      WHERE s.owner_id=? OR m.user_id=?
      ORDER BY s.updated_at DESC,s.id LIMIT 101
    """,(actor,actor,actor,actor)).fetchall()
    return dict(spaces=[summary(r) for r in rows[:100]],truncated=len(rows)>100,
                releaseAuthorized=False,publicFilmPlayback=False)

def create(db,actor,payload):
    require(isinstance(payload,dict),'Неверный формат объекта.')
    allowed_payload(payload,CREATE_FIELDS)
    film=payload.get('filmId')
    require(film in FILMS,'Разрешены только подтверждённые кинопроекты.')
    require(db.execute('SELECT COUNT(*) FROM cinema_spaces WHERE owner_id=?',(actor,)).fetchone()[0]<MAX_WORKSPACES,
            'Достигнут лимит рабочих кинопространств.',status=409)
    require(db.execute('SELECT 1 FROM cinema_spaces WHERE owner_id=? AND film_id=?',(actor,film)).fetchone() is None,
            'У вас уже есть пространство для этого фильма.','duplicate',409)
    name=safe_string(payload.get('title'),120,3)
    wid=uid();stamp=now()
    db.execute('INSERT INTO cinema_spaces VALUES(?,?,?,?,?,?,?)',
               (wid,actor,film,name,1,stamp,stamp))
    event(db,wid,actor,'space_created',{'filmId':film})
    return dict(workspaceId=wid,version=1,releaseAuthorized=False)

def check_scene(film,value):
    valid=(value in SCENES) if film=='zero-window' else value=='PREVIZ'
    require(isinstance(value,str) and valid,'Номер сцены не разрешён для этого проекта.')
    return value

def task_fields(payload,film):
    require(payload.get('category') in CATEGORIES,'Неизвестное направление работы.')
    require(payload.get('status','planned') in TASK_STATES,
            'Доступны только плановые статусы, не подтверждения съёмки.')
    return dict(scene=check_scene(film,payload.get('sceneId')),
                category=payload['category'],
                title=safe_string(payload.get('title'),120,2),
                status=payload.get('status','planned'),
                label=safe_string(payload.get('owner',''),80),
                due=due_date(payload.get('dueDate','')),
                notes=safe_string(payload.get('notes',''),600))

def mutate(db,space_id,actor,payload):
    require(isinstance(payload,dict),'Ожидается объект изменений.')
    kind=payload.get('kind')
    require(isinstance(kind,str) and kind in ALLOWED_FIELDS,'Неизвестная операция кинопроизводства.')
    allowed_payload(payload,ALLOWED_FIELDS[kind])
    row=access(db,space_id,actor,write=kind!='leave',owner=kind in ('member.set','member.remove','space.rename'))
    require(type(payload.get('expectedVersion')) is int and payload['expectedVersion']==row['version'],
            'Пространство изменено в другой вкладке. Обновите данные.','version_conflict',409)
    detail={}
    if kind=='task.create':
        require(db.execute('SELECT COUNT(*) FROM cinema_tasks WHERE space_id=?',(space_id,)).fetchone()[0]<MAX_TASKS,
                'Лимит задач кинопространства достигнут.',status=409)
        fields=task_fields(payload,row['film_id']);tid=uid();stamp=now()
        db.execute('INSERT INTO cinema_tasks VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)',
            (tid,space_id,fields['scene'],fields['category'],fields['title'],fields['status'],
             fields['label'],fields['due'],fields['notes'],actor,actor,stamp,stamp))
        detail={'taskId':tid,'status':fields['status'],'sceneId':fields['scene']}
    elif kind=='task.update':
        tid=payload.get('taskId')
        require(isinstance(tid,str) and re.fullmatch('[a-f0-9]{32}',tid),'Задача не найдена.','not_found',404)
        old=db.execute('SELECT * FROM cinema_tasks WHERE space_id=? AND id=?',(space_id,tid)).fetchone()
        require(old is not None,'Задача не найдена.','not_found',404)
        fields=task_fields({
          'sceneId':payload.get('sceneId',old['scene_id']),
          'category':payload.get('category',old['category']),
          'title':payload.get('title',old['title']),
          'status':payload.get('status',old['status']),
          'owner':payload.get('owner',old['owner_label']),
          'dueDate':payload.get('dueDate',old['due_date']),
          'notes':payload.get('notes',old['notes'])
        },row['film_id'])
        db.execute('UPDATE cinema_tasks SET scene_id=?,category=?,title=?,status=?,owner_label=?,due_date=?,notes=?,updated_by=?,updated_at=? WHERE id=? AND space_id=?',
                   (fields['scene'],fields['category'],fields['title'],fields['status'],
                    fields['label'],fields['due'],fields['notes'],actor,now(),tid,space_id))
        detail={'taskId':tid,'status':fields['status'],'sceneId':fields['scene']}
    elif kind=='task.delete':
        tid=payload.get('taskId')
        require(isinstance(tid,str) and re.fullmatch('[a-f0-9]{32}',tid),'Задача не найдена.','not_found',404)
        deleted=db.execute('DELETE FROM cinema_tasks WHERE id=? AND space_id=?',(tid,space_id)).rowcount
        require(deleted==1,'Задача не найдена.','not_found',404)
        detail={'taskId':tid}
    elif kind in ('member.set','member.remove'):
        username=safe_string(payload.get('username'),64,3).lower()
        require(re.fullmatch(r'[a-z0-9_.-]{3,64}',username),'Неверный логин участника.')
        member=db.execute('SELECT id FROM users WHERE username=?',(username,)).fetchone()
        require(member is not None,'Участник не найден.','not_found',404)
        require(member['id']!=row['owner_id'],'Невозможно изменить права владельца.')
        if kind=='member.set':
            role=payload.get('role')
            require(role in ('editor','viewer'),'Неизвестная роль.')
            require(db.execute('SELECT 1 FROM cinema_members WHERE space_id=? AND user_id=?',(space_id,member['id'])).fetchone()
                    or db.execute('SELECT COUNT(*) FROM cinema_members WHERE space_id=?',(space_id,)).fetchone()[0]<MAX_TEAM_MEMBERS,
                    'Достигнут лимит участников.',status=409)
            db.execute("""INSERT INTO cinema_members VALUES(?,?,?)
                          ON CONFLICT(space_id,user_id) DO UPDATE SET role=excluded.role""",
                       (space_id,member['id'],role))
            detail={'username':username,'role':role}
        else:
            db.execute('DELETE FROM cinema_members WHERE space_id=? AND user_id=?',(space_id,member['id']))
            detail={'username':username}
    elif kind=='space.rename':
        name=safe_string(payload.get('title'),120,3)
        db.execute('UPDATE cinema_spaces SET title=? WHERE id=?',(name,space_id))
        detail={'renamed':True}
    elif kind=='leave':
        require(row['role']!='owner','Владелец не может покинуть пространство.')
        db.execute('DELETE FROM cinema_members WHERE space_id=? AND user_id=?',(space_id,actor))
        detail={'memberLeft':True}
    else:
        raise Fault('validation','Неизвестная операция кинопроизводства.',400)
    stamp=now()
    db.execute('UPDATE cinema_spaces SET version=version+1,updated_at=? WHERE id=?',(stamp,space_id))
    event(db,space_id,actor,kind,detail)
    return dict(workspaceId=space_id,version=row['version']+1,left=kind=='leave',
                releaseAuthorized=False,publicVideoUrl=None,
                kind=kind,detail=detail)
