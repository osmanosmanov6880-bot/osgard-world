"""Team spaces with explicit project-owner sharing and effective, revocable project roles."""
import json
from core_model import require,text,uid,now
from core_delivery import identifier

SCHEMA='''
CREATE TABLE IF NOT EXISTS teams(id TEXT PRIMARY KEY,owner_id TEXT NOT NULL REFERENCES users(id),name TEXT NOT NULL,version INTEGER NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS team_members(team_id TEXT REFERENCES teams(id) ON DELETE CASCADE,user_id TEXT REFERENCES users(id),role TEXT NOT NULL CHECK(role IN ('admin','editor','viewer')),PRIMARY KEY(team_id,user_id));
CREATE TABLE IF NOT EXISTS team_projects(project_id TEXT PRIMARY KEY REFERENCES projects(id) ON DELETE CASCADE,team_id TEXT NOT NULL REFERENCES teams(id),attached_by TEXT NOT NULL REFERENCES users(id),created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS team_events(id INTEGER PRIMARY KEY AUTOINCREMENT,team_id TEXT REFERENCES teams(id),actor_id TEXT REFERENCES users(id),kind TEXT NOT NULL,detail TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE VIEW IF NOT EXISTS effective_project_members AS
SELECT project_id,user_id,CASE MAX(privilege) WHEN 2 THEN 'editor' ELSE 'viewer' END AS role FROM (
 SELECT project_id,user_id,CASE role WHEN 'editor' THEN 2 ELSE 1 END AS privilege FROM members
 UNION ALL SELECT tp.project_id,t.owner_id,2 FROM team_projects tp JOIN teams t ON t.id=tp.team_id
 UNION ALL SELECT tp.project_id,tm.user_id,CASE tm.role WHEN 'viewer' THEN 1 ELSE 2 END FROM team_projects tp JOIN team_members tm ON tm.team_id=tp.team_id
) GROUP BY project_id,user_id;
'''

def access(db,tid,actor):
    row=db.execute("SELECT t.*,CASE WHEN t.owner_id=? THEN 'owner' ELSE m.role END AS role FROM teams t LEFT JOIN team_members m ON m.team_id=t.id AND m.user_id=? WHERE t.id=? AND (t.owner_id=? OR m.user_id=?)",(actor,actor,tid,actor,actor)).fetchone();require(row is not None,'Команда не найдена.','not_found',404);return row

def event(db,tid,actor,kind,detail):
    require(db.execute('SELECT COUNT(*) FROM team_events WHERE team_id=?',(tid,)).fetchone()[0]<1000,'Лимит 1000 событий команды.',status=409)
    db.execute('INSERT INTO team_events(team_id,actor_id,kind,detail,created_at) VALUES(?,?,?,?,?)',(tid,actor,kind,json.dumps(detail,ensure_ascii=False),now()))
def header(row):return dict(id=row['id'],name=row['name'],version=row['version'],role=row['role'],createdAt=row['created_at'],updatedAt=row['updated_at'])
def read(store,db,tid,actor):
    row=access(db,tid,actor);people=[dict(id=row['owner_id'],username=db.execute('SELECT username FROM users WHERE id=?',(row['owner_id'],)).fetchone()[0],role='owner')]+[dict(v) for v in db.execute('SELECT u.id,u.username,m.role FROM team_members m JOIN users u ON u.id=m.user_id WHERE team_id=?',(tid,))]
    projects=[]
    for p in db.execute('SELECT p.id,p.data FROM projects p JOIN team_projects tp ON tp.project_id=p.id WHERE tp.team_id=? ORDER BY p.updated_at DESC',(tid,)):
        actual=store.access(db,p['id'],actor);projects.append(dict(id=p['id'],title=json.loads(p['data'])['title'],version=actual['version'],role=actual['role']))
    events=[dict(id=e['id'],kind=e['kind'],detail=json.loads(e['detail']),at=e['created_at']) for e in db.execute('SELECT * FROM team_events WHERE team_id=? ORDER BY id DESC LIMIT 100',(tid,))] if row['role'] in ('owner','admin') else []
    return dict(team=header(row),participants=people,projects=projects,events=events,limits=dict(externalInvitations=False,sso=False,billing=False,accessMeaning='All team members gain editor/viewer access to whole attached projects'))
def listing(store,db,actor):
    rows=db.execute("SELECT t.*,CASE WHEN t.owner_id=? THEN 'owner' ELSE m.role END AS role FROM teams t LEFT JOIN team_members m ON m.team_id=t.id AND m.user_id=? WHERE t.owner_id=? OR m.user_id=? ORDER BY t.updated_at DESC,t.id LIMIT 101",(actor,actor,actor,actor)).fetchall();return dict(teams=[header(r) for r in rows[:100]],truncated=len(rows)>100)
def project_context(store,db,pid,actor):
    p=store.access(db,pid,actor);team=db.execute('SELECT t.id,t.name,t.version FROM teams t JOIN team_projects tp ON tp.team_id=t.id WHERE tp.project_id=?',(pid,)).fetchone()
    return dict(projectVersion=p['version'],team=dict(team) if team else None,canDetach=p['role']=='owner')
def create(db,actor,payload):
    require(db.execute('SELECT COUNT(*) FROM teams WHERE owner_id=?',(actor,)).fetchone()[0]<20,'Лимит 20 собственных команд.',status=409);tid=uid();stamp=now();db.execute('INSERT INTO teams VALUES(?,?,?,?,?,?)',(tid,actor,text(payload.get('name'),120,3),1,stamp,stamp));event(db,tid,actor,'created',{});return dict(teamId=tid)
def mutate(store,db,tid,actor,payload):
    row=access(db,tid,actor);require(type(payload.get('expectedVersion')) is int and payload['expectedVersion']==row['version'],'Команда изменилась. Обновите её.','version_conflict',409);kind=payload.get('action');manager=row['role'] in ('owner','admin');detail={}
    if kind=='rename':require(manager,'Нужны права администратора команды.','forbidden',403);db.execute('UPDATE teams SET name=? WHERE id=?',(text(payload.get('name'),120,3),tid))
    elif kind=='member':
        require(manager,'Нужны права администратора команды.','forbidden',403);name=text(payload.get('username'),64,3).lower();user=db.execute('SELECT id FROM users WHERE username=?',(name,)).fetchone();require(user is not None,'Аккаунт не найден.','not_found',404);require(user['id']!=row['owner_id'],'Роль владельца команды неизменна.')
        previous=db.execute('SELECT role FROM team_members WHERE team_id=? AND user_id=?',(tid,user['id'])).fetchone();role=payload.get('role');require(role in ('admin','editor','viewer','remove'),'Неизвестная роль.')
        require(row['role']=='owner' or role!='admin' and (not previous or previous['role']!='admin'),'Назначать и изменять администраторов может только владелец.','forbidden',403)
        if role=='remove':db.execute('DELETE FROM team_members WHERE team_id=? AND user_id=?',(tid,user['id']))
        else:
            require(previous or db.execute('SELECT COUNT(*) FROM team_members WHERE team_id=?',(tid,)).fetchone()[0]<20,'Лимит 20 участников помимо владельца.',status=409);db.execute('INSERT INTO team_members VALUES(?,?,?) ON CONFLICT(team_id,user_id) DO UPDATE SET role=excluded.role',(tid,user['id'],role))
        detail=dict(username=name,role=role)
    elif kind=='leave':
        require(row['role']!='owner','Владелец не может покинуть свою команду.');db.execute('DELETE FROM team_members WHERE team_id=? AND user_id=?',(tid,actor))
    elif kind=='attach':
        require(manager,'Подключать проекты может администратор команды.','forbidden',403);require(payload.get('sharingAcknowledged') is True,'Подтвердите доступ всех участников команды ко всему проекту.')
        pid=identifier(payload.get('projectId'));p=store.access(db,pid,actor,owner=True);require(type(payload.get('projectVersion')) is int and payload['projectVersion']==p['version'],'Проект изменился. Проверьте текущую версию.','version_conflict',409)
        require(db.execute('SELECT 1 FROM team_projects WHERE project_id=?',(pid,)).fetchone() is None,'Проект уже подключён к команде.','already_attached',409);require(db.execute('SELECT COUNT(*) FROM team_projects WHERE team_id=?',(tid,)).fetchone()[0]<100,'Лимит 100 проектов команды.',status=409)
        db.execute('INSERT INTO team_projects VALUES(?,?,?,?)',(pid,tid,actor,now()));store.save(db,p,actor,json.loads(p['data']),'team_attached',dict(teamId=tid));detail=dict(projectId=pid)
    elif kind=='detach':
        pid=identifier(payload.get('projectId'));p=store.access(db,pid,actor);require(manager or p['role']=='owner','Недостаточно прав для отключения.','forbidden',403);require(type(payload.get('projectVersion')) is int and payload['projectVersion']==p['version'],'Проект изменился.','version_conflict',409)
        require(db.execute('SELECT 1 FROM team_projects WHERE project_id=? AND team_id=?',(pid,tid)).fetchone() is not None,'Проект не подключён к этой команде.','not_found',404)
        # Save while inherited access still exists, then remove the grant in the same transaction.
        store.save(db,p,actor,json.loads(p['data']),'team_detached',dict(teamId=tid));db.execute('DELETE FROM team_projects WHERE project_id=?',(pid,));detail=dict(projectId=pid)
    else:require(False,'Неизвестное действие команды.')
    stamp=now();db.execute('UPDATE teams SET version=version+1,updated_at=? WHERE id=?',(stamp,tid));event(db,tid,actor,kind,detail);return dict(teamId=tid,version=row['version']+1,left=kind=='leave')
def detach_owned(store,db,p,actor):
    binding=db.execute('SELECT team_id FROM team_projects WHERE project_id=?',(p['id'],)).fetchone();require(binding is not None,'Проект не подключён к команде.','not_found',404);tid=binding['team_id'];db.execute('DELETE FROM team_projects WHERE project_id=?',(p['id'],));db.execute('UPDATE teams SET version=version+1,updated_at=? WHERE id=?',(now(),tid));event(db,tid,actor,'owner_detached',dict(projectId=p['id']));return dict(project=store.save(db,p,actor,json.loads(p['data']),'team_detached',dict(teamId=tid)))
