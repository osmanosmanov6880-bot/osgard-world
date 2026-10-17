#!/usr/bin/env python3
"""OSGARD pilot server. SQLite is authoritative; Commerce is disabled by default."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlsplit
from contextlib import contextmanager
import html
import argparse
import functools
import hashlib
import hmac
import json
import os
import re
import secrets
import sqlite3
import threading
import time
import core_learning
import core_pilot_reports
import core_account
import core_acceptance
import core_delivery
import core_overview
import core_client_portal
import core_teams
import core_readiness
import core_commerce
import core_programs
import core_inherit
from core_model import Fault, require, text, initial, patch, action, economics, simulation, metrics, now, uid

SCHEMA='''
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY, username TEXT NOT NULL UNIQUE, salt TEXT NOT NULL, password_hash TEXT NOT NULL, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS sessions(token_hash TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,expires_at REAL NOT NULL);
CREATE TABLE IF NOT EXISTS projects(id TEXT PRIMARY KEY,owner_id TEXT NOT NULL REFERENCES users(id),version INTEGER NOT NULL,data TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS members(project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,user_id TEXT REFERENCES users(id) ON DELETE CASCADE,role TEXT NOT NULL CHECK(role IN ('editor','viewer')),PRIMARY KEY(project_id,user_id));
CREATE TABLE IF NOT EXISTS revisions(project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,version INTEGER NOT NULL,data TEXT NOT NULL,actor_id TEXT NOT NULL,created_at TEXT NOT NULL,PRIMARY KEY(project_id,version));
CREATE TABLE IF NOT EXISTS events(id INTEGER PRIMARY KEY AUTOINCREMENT,project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,actor_id TEXT NOT NULL,kind TEXT NOT NULL,detail TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS operations(user_id TEXT REFERENCES users(id) ON DELETE CASCADE,key TEXT NOT NULL,request_hash TEXT NOT NULL,response TEXT NOT NULL,created_at TEXT NOT NULL,PRIMARY KEY(user_id,key));
CREATE TABLE IF NOT EXISTS templates(id TEXT PRIMARY KEY,owner_id TEXT REFERENCES users(id),title TEXT NOT NULL,source_project TEXT NOT NULL,source_version INTEGER NOT NULL,data TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS jobs(id TEXT PRIMARY KEY,project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,actor_id TEXT NOT NULL,source_version INTEGER NOT NULL,status TEXT NOT NULL CHECK(status IN ('queued','running','completed','failed')),attempts INTEGER NOT NULL DEFAULT 0,result TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS assets(id TEXT PRIMARY KEY,project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,source_version INTEGER NOT NULL,content TEXT NOT NULL,sha256 TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS sessions_expiry ON sessions(expires_at);
CREATE INDEX IF NOT EXISTS project_owners ON projects(owner_id);
CREATE INDEX IF NOT EXISTS events_project ON events(project_id,id);
PRAGMA user_version=1;
'''

def encoded(v): return json.dumps(v,ensure_ascii=False,separators=(',',':'),allow_nan=False)
def digest(v): return hashlib.sha256(v.encode()).hexdigest()
def password_hash(password,salt): return hashlib.pbkdf2_hmac('sha256',password.encode(),bytes.fromhex(salt),600000).hex()

class Store:
    def __init__(self,path,commerce_config=None,commerce_provider=None):
        self.path=str(path)
        Path(path).parent.mkdir(parents=True,exist_ok=True)
        with self.connect() as db:
            require(db.execute('PRAGMA user_version').fetchone()[0] in (0,1),'Версия базы новее этого сервера. Обновите Core.')
            db.executescript(SCHEMA+core_learning.SCHEMA+core_pilot_reports.SCHEMA+core_account.SCHEMA+core_acceptance.SCHEMA+core_delivery.SCHEMA+core_client_portal.SCHEMA+core_teams.SCHEMA+core_commerce.SCHEMA+core_programs.SCHEMA+core_inherit.SCHEMA)
        self.commerce=core_commerce.Commerce(self,commerce_config,commerce_provider)
        try:os.chmod(path,0o600)
        except OSError:pass
    @contextmanager
    def connect(self):
        db=sqlite3.connect(self.path,timeout=15,isolation_level=None);db.row_factory=sqlite3.Row
        db.execute('PRAGMA foreign_keys=ON')
        try:yield db
        finally:db.close()
    @contextmanager
    def transaction(self):
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            try:yield db;db.commit()
            except BaseException:db.rollback();raise
    def actor(self,token):
        require(isinstance(token,str) and re.fullmatch(r'[A-Za-z0-9_-]{40,100}',token),'Войдите в аккаунт.','unauthorized',401)
        with self.connect() as db:row=db.execute('SELECT users.id,users.username FROM sessions JOIN users ON users.id=sessions.user_id WHERE token_hash=? AND expires_at>?',(digest(token),time.time())).fetchone()
        require(row is not None,'Сессия завершилась. Войдите снова.','unauthorized',401)
        return dict(row)
    def auth(self,kind,payload,label=''):
        username=text(payload.get('username'),64,3).lower()
        require(re.fullmatch('[a-z0-9_.-]{3,64}',username),'Логин: 3–64 латинские буквы, цифры, точка, дефис или подчёркивание.')
        password=payload.get('password');require(isinstance(password,str) and 12<=len(password)<=256,'Пароль: от 12 до 256 символов.')
        if kind=='register':
            salt=secrets.token_hex(16);ph=password_hash(password,salt)
            with self.transaction() as db:
                require(db.execute('SELECT COUNT(*) FROM users').fetchone()[0]<10000,'Достигнут лимит пилотного сервера.',status=409)
                try:db.execute('INSERT INTO users VALUES(?,?,?,?,?)',(uid(),username,salt,ph,now()))
                except sqlite3.IntegrityError:raise Fault('username_unavailable','Этот логин недоступен.',409)
        with self.connect() as db:row=db.execute('SELECT * FROM users WHERE username=?',(username,)).fetchone()
        candidate=password_hash(password,row['salt'] if row else '00'*16)
        require(row is not None and hmac.compare_digest(candidate,row['password_hash']),'Неверный логин или пароль.','invalid_credentials',401)
        token=secrets.token_urlsafe(32)
        with self.transaction() as db:
            current=db.execute('SELECT password_hash FROM users WHERE id=?',(row['id'],)).fetchone();require(current is not None and hmac.compare_digest(current['password_hash'],row['password_hash']),'Пароль изменился. Повторите вход.','credentials_changed',409)
            db.execute('DELETE FROM sessions WHERE expires_at<=?',(time.time(),))
            existing=db.execute('SELECT token_hash FROM sessions WHERE user_id=? ORDER BY expires_at DESC',(row['id'],)).fetchall()
            for old in existing[24:]:db.execute('DELETE FROM sessions WHERE token_hash=?',(old['token_hash'],))
            db.execute('INSERT INTO sessions VALUES(?,?,?)',(digest(token),row['id'],time.time()+8*3600))
            db.execute('INSERT INTO session_details VALUES(?,?,?)',(digest(token),now(),str(label)[:160]))
            core_account.event(db,row['id'],'session_started',{})
        return {'token':token,'user':{'id':row['id'],'username':username},'expiresInSeconds':8*3600}
    def access(self,db,pid,actor,write=False,owner=False):
        row=db.execute('SELECT p.*,CASE WHEN owner_id=? THEN \'owner\' ELSE m.role END AS role FROM projects p LEFT JOIN effective_project_members m ON m.project_id=p.id AND m.user_id=? WHERE p.id=? AND (p.owner_id=? OR m.user_id=?)',(actor,actor,pid,actor,actor)).fetchone()
        require(row is not None,'Проект не найден.','not_found',404)
        require(not write or row['role'] in ('owner','editor'),'Для этого действия нужны права редактора.','forbidden',403)
        require(not owner or row['role']=='owner','Действие доступно владельцу.','forbidden',403)
        return row
    def project(self,row):
        d=json.loads(row['data'])
        return dict(id=row['id'],version=row['version'],role=row['role'] if 'role' in row.keys() else 'owner',data=d,economics=economics(d),metrics=metrics(d),createdAt=row['created_at'],updatedAt=row['updated_at'])
    def event(self,db,pid,actor,kind,detail):db.execute('INSERT INTO events(project_id,actor_id,kind,detail,created_at) VALUES(?,?,?,?,?)',(pid,actor,kind,encoded(detail),now()))
    def save(self,db,row,actor,data,kind,detail):
        version=row['version']+1
        require(version<=500,'Лимит 500 версий пилотного проекта. Экспортируйте проект перед продолжением.',status=409)
        raw=encoded(data);require(len(raw.encode())<=512*1024,'Размер проекта превышает 512 КиБ. Экспортируйте данные и разделите проект.',status=409);stamp=now()
        db.execute('UPDATE projects SET version=?,data=?,updated_at=? WHERE id=?',(version,raw,stamp,row['id']))
        db.execute('INSERT INTO revisions VALUES(?,?,?,?,?)',(row['id'],version,raw,actor,stamp))
        self.event(db,row['id'],actor,kind,detail)
        return self.project(self.access(db,row['id'],actor))
    def get(self,route,actor):
        with self.connect() as db:
            db.execute('BEGIN')
            if route.startswith('inherit/'):return core_inherit.get(db,route,actor)
            if route=='commerce/config':return self.commerce.config_view(actor)
            if route=='commerce/purchases':return self.commerce.purchases(db,actor)
            if route=='learning/programs':return core_programs.catalog(self,actor)
            program_route=re.fullmatch(r'learning/enrollments/([a-f0-9]{32})(/export)?',route)
            if program_route:
                return core_programs.own_work(self,db,program_route[1],actor) if program_route[2] else core_programs.read(self,db,program_route[1],actor)
            purchase_file=re.fullmatch(r'commerce/purchases/([a-f0-9]{32})/file',route)
            if purchase_file:return self.commerce.download(db,purchase_file[1],actor)
            commerce_project=re.fullmatch(r'projects/([a-f0-9]{32})/commerce',route)
            if commerce_project:return self.commerce.project_orders(db,commerce_project[1],actor)
            if route=='teams':return core_teams.listing(self,db,actor)
            team_route=re.fullmatch(r'teams/([a-f0-9]{32})',route)
            if team_route:return core_teams.read(self,db,team_route[1],actor)
            team_project=re.fullmatch(r'projects/([a-f0-9]{32})/team',route)
            if team_project:return core_teams.project_context(self,db,team_project[1],actor)
            if route=='deliveries':return core_client_portal.inbox(self,db,actor)
            portal_route=re.fullmatch(r'deliveries/([a-f0-9]{32})',route)
            if portal_route:return core_client_portal.packet(self,db,portal_route[1],actor)
            portal_project=re.fullmatch(r'projects/([a-f0-9]{32})/client-deliveries',route)
            if portal_project:return core_client_portal.project_list(self,db,portal_project[1],actor)
            if route=='overview':return core_overview.overview(self,db,actor)
            readiness_route=re.fullmatch(r'projects/([a-f0-9]{32})/readiness',route)
            if readiness_route:return core_readiness.read(self,db,readiness_route[1],actor)
            delivery_route=re.fullmatch(r'projects/([a-f0-9]{32})/delivery(?:/tickets/([a-f0-9]{32}))?',route)
            if delivery_route:return core_delivery.read(self,db,delivery_route[1],actor,delivery_route[2])
            release_route=re.fullmatch(r'projects/([a-f0-9]{32})/releases(?:/([a-f0-9]{32}))?',route)
            if release_route:return core_acceptance.read(self,db,release_route[1],actor,release_route[2])
            if route=='learning/overview':return core_pilot_reports.overview(self,db,actor)
            report_route=re.fullmatch(r'projects/([a-f0-9]{32})/learning/report',route)
            if report_route:return core_pilot_reports.project_report(self,db,report_route[1],actor)
            if route=='curriculum':return core_learning.CURRICULUM
            if route=='templates':
                return {'templates':[dict(id=r['id'],title=r['title'],sourceVersion=r['source_version'],createdAt=r['created_at'],data=json.loads(r['data']),status='participant_reviewed_source' if core_delivery.template_origin(db,r['id']) else 'internal_review_only',provenance=core_delivery.template_origin(db,r['id'])) for r in db.execute('SELECT * FROM templates WHERE owner_id=? ORDER BY created_at DESC',(actor,))]}
            if route=='projects':
                rows=db.execute('SELECT p.*,CASE WHEN p.owner_id=? THEN \'owner\' ELSE m.role END AS role FROM projects p LEFT JOIN effective_project_members m ON m.project_id=p.id AND m.user_id=? WHERE p.owner_id=? OR m.user_id=? ORDER BY p.updated_at DESC LIMIT 200',(actor,actor,actor,actor)).fetchall()
                return {'projects':[self.project(r) for r in rows]}
            submission_route=re.fullmatch(r'projects/([a-f0-9]{32})/learning/submissions/([a-f0-9]{32})',route)
            if submission_route:
                pid,sid=submission_route.groups();context=self.access(db,pid,actor);require(json.loads(context['data'])['consents']['learning'],'Использование Learning отключено в контракте.')
                submission=db.execute('SELECT * FROM submissions WHERE project_id=? AND id=?',(pid,sid)).fetchone();require(submission is not None,'Сдача не найдена.','not_found',404)
                snapshot=db.execute('SELECT data FROM revisions WHERE project_id=? AND version=?',(pid,submission['source_version'])).fetchone();require(snapshot is not None,'Версия сдачи не найдена.','not_found',404)
                return {'submissionId':sid,'sourceVersion':submission['source_version'],'snapshot':json.loads(snapshot['data'])}
            asset_route=re.fullmatch(r'projects/([a-f0-9]{32})/assets(?:/([a-f0-9]{32}))?',route)
            if asset_route:
                pid,aid=asset_route.groups();self.access(db,pid,actor)
                if aid:
                    asset=db.execute('SELECT * FROM assets WHERE project_id=? AND id=?',(pid,aid)).fetchone();require(asset is not None,'Артефакт не найден.','not_found',404)
                    return {'asset':dict(id=asset['id'],html=asset['content'],sha256=asset['sha256'],sourceVersion=asset['source_version'])}
                return {'assets':[dict(id=v['id'],sha256=v['sha256'],sourceVersion=v['source_version'],createdAt=v['created_at']) for v in db.execute('SELECT * FROM assets WHERE project_id=? ORDER BY created_at DESC',(pid,))]}
            m=re.fullmatch(r'projects/([a-f0-9]{32})(?:/(history|export|members|jobs|learning))?',route)
            require(m is not None,'Маршрут API не найден.','not_found',404)
            pid,section=m.groups();row=self.access(db,pid,actor)
            if not section:return {'project':self.project(row)}
            if section=='learning':return core_learning.read(self,db,pid,actor)
            if section=='jobs':
                return {'jobs':[dict(id=v['id'],sourceVersion=v['source_version'],status=v['status'],attempts=v['attempts'],result=json.loads(v['result']) if v['result'] else None,createdAt=v['created_at']) for v in db.execute('SELECT * FROM jobs WHERE project_id=? ORDER BY created_at DESC LIMIT 200',(pid,))]}
            if section=='members':
                return {'members':[dict(v) for v in db.execute("SELECT u.username,m.role,d.role AS directRole,CASE WHEN EXISTS(SELECT 1 FROM team_projects tp JOIN teams t ON t.id=tp.team_id LEFT JOIN team_members tm ON tm.team_id=t.id AND tm.user_id=m.user_id WHERE tp.project_id=m.project_id AND (t.owner_id=m.user_id OR tm.user_id=m.user_id)) THEN 1 ELSE 0 END AS hasTeamAccess,CASE WHEN d.role IS NULL THEN 'team' ELSE 'direct_or_combined' END AS accessSource FROM effective_project_members m JOIN users u ON u.id=m.user_id LEFT JOIN members d ON d.project_id=m.project_id AND d.user_id=m.user_id JOIN projects p ON p.id=m.project_id WHERE m.project_id=? AND m.user_id!=p.owner_id",(pid,))]}
            revisions=[dict(v) for v in db.execute('SELECT version,created_at AS createdAt,actor_id AS actorId FROM revisions WHERE project_id=? ORDER BY version DESC',(pid,))]
            events=[dict(v) for v in db.execute('SELECT id,kind,detail,created_at AS createdAt FROM events WHERE project_id=? ORDER BY id DESC LIMIT 1000',(pid,))]
            result={'project':self.project(row),'revisions':revisions,'events':events}
            if section=='export':
                require(db.execute('SELECT COALESCE(SUM(LENGTH(CAST(data AS BLOB))),0) FROM revisions WHERE project_id=?',(pid,)).fetchone()[0]<=12*1024*1024,'История слишком велика для JSON. Используйте серверную резервную копию SQLite.',status=413)
                result['assets']=[dict(id=v['id'],html=v['content'],sha256=v['sha256'],sourceVersion=v['source_version']) for v in db.execute('SELECT * FROM assets WHERE project_id=?',(pid,))]
                result['jobs']=[dict(id=v['id'],status=v['status'],sourceVersion=v['source_version'],result=json.loads(v['result']) if v['result'] else None) for v in db.execute('SELECT * FROM jobs WHERE project_id=?',(pid,))]
                result['snapshots']=[dict(version=v['version'],data=json.loads(v['data']),createdAt=v['created_at']) for v in db.execute('SELECT * FROM revisions WHERE project_id=? ORDER BY version',(pid,))]
                result['learning']=core_learning.read(self,db,pid,actor,export=True)
                result['teamAccess']=core_teams.project_context(self,db,pid,actor)
                result['clientDeliveries']=core_client_portal.project_list(self,db,pid,actor,export=True)['deliveries'] if row['role'] in ('owner','editor') else []
                result['delivery']=core_delivery.read(self,db,pid,actor,export=True)
                result['releaseReviews']=core_acceptance.reviews(db,pid)
                result['releaseReadiness']=core_readiness.evaluate(db,pid,row['version'],json.loads(row['data'])) if json.loads(row['data'])['consents']['studio'] else None
                program_enrollment=db.execute('SELECT order_id FROM program_enrollments WHERE project_id=? AND buyer_id=?',(pid,actor)).fetchone()
                if program_enrollment:result['programWork']=core_programs.own_work(self,db,program_enrollment['order_id'],actor)
                result['format']='osgard-core-project-v1'
            return result
    def mutate(self,route,actor,payload,key):
        require(isinstance(key,str) and re.fullmatch('[a-zA-Z0-9_-]{16,100}',key),'Нужен уникальный ключ операции.')
        fingerprint=digest(encoded({'route':route,'payload':payload}))
        with self.transaction() as db:
            previous=db.execute('SELECT * FROM operations WHERE user_id=? AND key=?',(actor,key)).fetchone()
            if previous:
                require(previous['request_hash']==fingerprint,'Ключ уже использован для другого запроса.','idempotency_conflict',409)
                old=json.loads(previous['response'])
                if route=='teams':core_teams.access(db,old['teamId'],actor)
                if route.startswith('inherit/'):core_inherit.retry_guard(db,route,actor,old)
                team_retry=re.fullmatch(r'teams/([a-f0-9]{32})',route)
                if team_retry:core_teams.access(db,team_retry[1],actor)
                portal_retry=re.fullmatch(r'deliveries/([a-f0-9]{32})',route)
                if portal_retry:core_client_portal.access(self,db,portal_retry[1],actor)
                program_retry=re.fullmatch(r'learning/enrollments/([a-f0-9]{32})',route)
                if program_retry:core_programs.retry_guard(self,db,program_retry[1],actor,payload)
                # Re-check access on retries after a membership revocation.
                if 'project' in old:self.access(db,old['project']['id'],actor,write=not route.endswith('/delivery'))
                old['replayed']=True
                return old
            require(db.execute('SELECT COUNT(*) FROM operations WHERE user_id=?',(actor,)).fetchone()[0]<10000,'Достигнут лимит операций пилота.',status=409)
            portal_mutation=re.fullmatch(r'deliveries/([a-f0-9]{32})',route)
            team_mutation=re.fullmatch(r'teams/([a-f0-9]{32})',route)
            program_mutation=re.fullmatch(r'learning/enrollments/([a-f0-9]{32})',route)
            if route.startswith('inherit/'):result=core_inherit.mutate(db,route,actor,payload)
            elif program_mutation:result=core_programs.mutate(self,db,program_mutation[1],actor,payload)
            elif route=='teams':result=core_teams.create(db,actor,payload)
            elif team_mutation:result=core_teams.mutate(self,db,team_mutation[1],actor,payload)
            elif portal_mutation:result=core_client_portal.mutate(self,db,portal_mutation[1],actor,payload)
            elif route=='templates':
                row=self.access(db,payload.get('projectId'),actor,write=True);d=json.loads(row['data'])
                require(d['releases'],'Шаблон создаётся после внутреннего выпуска и ручной проверки.')
                require(db.execute('SELECT COUNT(*) FROM templates WHERE owner_id=?',(actor,)).fetchone()[0]<100,'Лимит шаблонов пилота.',status=409)
                released_version=d['releases'][-1].get('sourceVersion');require(type(released_version) is int,'У выпуска нет зафиксированной версии. Проведите выпуск заново.')
                snapshot=db.execute('SELECT data FROM revisions WHERE project_id=? AND version=?',(row['id'],released_version)).fetchone();require(snapshot is not None,'Снимок выпуска не найден.')
                released=json.loads(snapshot['data'])
                template=dict(tasks=[t['title'] for t in released['tasks']],acceptance=[a['title'] for a in released['acceptance']])
                tid=uid();title=text(payload.get('title'),160,2)
                db.execute('INSERT INTO templates VALUES(?,?,?,?,?,?,?)',(tid,actor,title,row['id'],released_version,encoded(template),now()))
                core_delivery.remember_template(db,tid,row['id'],d['releases'][-1]['id'])
                self.event(db,row['id'],actor,'template_created',{'templateId':tid,'sourceVersion':released_version})
                origin=core_delivery.template_origin(db,tid)
                result={'template':{'id':tid,'title':title,'data':template,'status':'participant_reviewed_source' if origin else 'internal_review_only','provenance':origin}}
            elif route=='projects':
                require(db.execute('SELECT COUNT(*) FROM projects WHERE owner_id=?',(actor,)).fetchone()[0]<100,'Лимит 100 проектов на аккаунт.',status=409)
                d=initial(payload.get('title'),payload.get('goal'))
                if payload.get('templateId'):
                    template=db.execute('SELECT data FROM templates WHERE id=? AND owner_id=?',(payload['templateId'],actor)).fetchone();require(template is not None,'Шаблон не найден.','not_found',404)
                    data=json.loads(template['data']);d['tasks']=[dict(id=uid(),title=t,done=False) for t in data['tasks']];d['acceptance']=[dict(id=uid(),title=t,done=False) for t in data['acceptance']]
                pid=uid();stamp=now();raw=encoded(d)
                db.execute('INSERT INTO projects VALUES(?,?,?,?,?,?)',(pid,actor,1,raw,stamp,stamp))
                db.execute('INSERT INTO revisions VALUES(?,?,?,?,?)',(pid,1,raw,actor,stamp));self.event(db,pid,actor,'project_created',{})
                result={'project':self.project(self.access(db,pid,actor))}
            else:
                m=re.fullmatch(r'projects/([a-f0-9]{32})(?:/(actions|restore|members|jobs|learning|release-review|delivery|client-deliveries|team|commerce))?',route)
                require(m is not None,'Маршрут API не найден.','not_found',404)
                pid,section=m.groups();row=self.access(db,pid,actor,write=section!='delivery',owner=section in ('members','team','commerce'))
                require(type(payload.get('expectedVersion')) is int and payload['expectedVersion']==row['version'],'Проект изменён в другой вкладке или на другом устройстве. Загрузите актуальную версию.','version_conflict',409)
                d=json.loads(row['data'])
                if section=='commerce':result=self.commerce.prepare(db,row,actor,payload)
                elif section=='team':result=core_teams.detach_owned(self,db,row,actor)
                elif section=='client-deliveries':result=core_client_portal.create(self,db,row,actor,payload)
                elif section=='delivery':result=core_delivery.mutate(self,db,row,actor,payload)
                elif section=='release-review':result=core_acceptance.mutate(self,db,row,actor,payload)
                elif section=='learning':result=core_learning.mutate(self,db,row,actor,payload)
                elif section=='jobs':
                    require(d['consents']['studio'] and 'local_checks' in d['allowedActions'],'Разрешите Studio и локальные проверки.')
                    require(db.execute('SELECT COUNT(*) FROM jobs WHERE project_id=?',(pid,)).fetchone()[0]<200,'Лимит фоновых проверок проекта.',status=409)
                    jid=uid();stamp=now();db.execute('INSERT INTO jobs VALUES(?,?,?,?,?,?,?,?,?)',(jid,pid,actor,row['version'],'queued',0,None,stamp,stamp))
                    self.event(db,pid,actor,'check_queued',{'jobId':jid,'sourceVersion':row['version']})
                    result={'project':self.project(row),'jobId':jid}
                elif section=='actions' and payload.get('kind')=='build_preview':
                    require(d['accepted'] and d['consents']['studio'] and 'build_preview' in d['allowedActions'],'Примите контракт и разрешите создание HTML-прототипа в Studio.')
                    require(db.execute('SELECT COUNT(*) FROM assets WHERE project_id=?',(pid,)).fetchone()[0]<50,'Лимит 50 HTML-прототипов.',status=409)
                    content=build_preview(d);aid=uid();checksum=digest(content)
                    db.execute('INSERT INTO assets VALUES(?,?,?,?,?,?)',(aid,pid,row['version'],content,checksum,now()))
                    d['artifact']={'assetId':aid,'url':'','checksum':checksum,'notes':'HTML-прототип, созданный из сохранённого контракта. Содержимое не является подключённым сервисом.'}
                    result={'project':self.save(db,row,actor,d,'preview_built',{'assetId':aid,'sha256':checksum}),'assetId':aid}
                elif section=='actions':
                    if payload.get('kind')=='cancel_order':self.commerce.guard_draft_cancellation(db,pid,payload.get('payload',{}).get('orderId'))
                    d,value=action(d,payload.get('kind'),payload.get('payload',{}))
                    if payload.get('kind') in ('simulate','release'):
                        report=core_readiness.evaluate(db,pid,row['version'],json.loads(row['data']))
                        if payload.get('kind')=='simulate':
                            value=report;value['at']=report['generatedAt']
                        else:
                            core_readiness.require_current_artifact(report)
                            value['sourceVersion']=row['version'];value['checks']=report['checks']
                            value['evidence']=dict(format=report['format'],sourceVersion=report['sourceVersion'],snapshotSha256=report['snapshotSha256'],artifactSha256=report['artifact']['actualSha256'],externalVerification=False,checkedAt=report['generatedAt'])
                    result={'project':self.save(db,row,actor,d,payload.get('kind'),value),'result':value}
                elif section=='restore':
                    require(type(payload.get('version')) is int,'Неверная версия.')
                    target=db.execute('SELECT data FROM revisions WHERE project_id=? AND version=?',(pid,payload.get('version'))).fetchone();require(target is not None,'Версия не найдена.','not_found',404)
                    old=json.loads(target['data'])
                    # Financial records and releases are append-only and never rolled back by restore.
                    for k in ('costs','orders','releases','measurements','currency'):old[k]=d[k]
                    old['accepted']=False
                    result={'project':self.save(db,row,actor,old,'version_restored',{'sourceVersion':payload['version']})}
                elif section=='members':
                    username=text(payload.get('username'),64,3).lower();target=db.execute('SELECT id FROM users WHERE username=?',(username,)).fetchone()
                    require(target is not None,'Аккаунт не найден.','not_found',404);require(target['id']!=row['owner_id'],'Владелец уже имеет полный доступ.')
                    role=payload.get('role');require(role in ('editor','viewer','remove'),'Неизвестная роль.')
                    if role=='remove':db.execute('DELETE FROM members WHERE project_id=? AND user_id=?',(pid,target['id']))
                    else:
                        require(db.execute('SELECT COUNT(*) FROM members WHERE project_id=?',(pid,)).fetchone()[0]<20 or db.execute('SELECT 1 FROM members WHERE project_id=? AND user_id=?',(pid,target['id'])).fetchone() is not None,'Лимит участников проекта.',status=409)
                        db.execute('INSERT INTO members VALUES(?,?,?) ON CONFLICT(project_id,user_id) DO UPDATE SET role=excluded.role',(pid,target['id'],role))
                    result={'project':self.save(db,row,actor,d,'membership_changed',{'username':username,'role':role})}
                else: result={'project':self.save(db,row,actor,patch(d,payload.get('changes')),'project_updated',{'fields':list(payload.get('changes',{}))})}
            db.execute('INSERT INTO operations VALUES(?,?,?,?,?)',(actor,key,fingerprint,encoded(result),now()))
            return result

def build_preview(d):
    """Deterministic, escaped HTML artifact; no model calls and no scripts."""
    esc=html.escape
    tasks=''.join('<li>'+esc(t['title'])+'</li>' for t in d['tasks'])
    criteria=''.join('<li>'+esc(a['title'])+'</li>' for a in d['acceptance'])
    return '<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>'+esc(d['title'])+'</title><style>body{margin:0;background:#f3f4f1;color:#172027;font:17px/1.7 system-ui,sans-serif}main{max-width:960px;padding:8vw 6vw;margin:auto}small{letter-spacing:.12em;color:#315a62}h1{font-size:clamp(40px,7vw,84px);line-height:1.08;letter-spacing:-.05em}section{border-top:1px solid #dce2e1;padding:28px 0;margin-top:28px}p,li{white-space:pre-wrap;overflow-wrap:anywhere}footer{font-size:13px;color:#59656b}</style><main><small>OSGARD STUDIO / HTML PROTOTYPE</small><h1>'+esc(d['title'])+'</h1><p>'+esc(d['goal'])+'</p><section><h2>Для кого</h2><p>'+esc(d['audience'] or 'Аудитория ещё не определена')+'</p></section><section><h2>Путь к результату</h2><ol>'+tasks+'</ol></section><section><h2>Критерии приёмки</h2><ul>'+criteria+'</ul></section><footer>Прототип создан из контракта OSGARD. Это статическая страница: функции продукта, платежи и отправка форм не подключены.</footer></main></html>'

class QueueWorker(threading.Thread):
    """Durable queue for pure local checks only. Never retries external actions."""
    def __init__(self,store):
        super().__init__(daemon=True);self.store=store;self.stopped=threading.Event();self.last_cycle_at=None;self.last_cycle_monotonic=None;self.storage_errors=0;self.last_storage_error_at=None;self.storage_healthy=None
        with store.transaction() as db:db.execute("UPDATE jobs SET status='queued',updated_at=? WHERE status='running'",(now(),))
    def run_one(self):
        with self.store.transaction() as db:
            job=db.execute("SELECT * FROM jobs WHERE status='queued' ORDER BY created_at,id LIMIT 1").fetchone()
            if job is None:return False
            db.execute("UPDATE jobs SET status='running',attempts=attempts+1,updated_at=? WHERE id=?",(now(),job['id']))
            snapshot=db.execute('SELECT data FROM revisions WHERE project_id=? AND version=?',(job['project_id'],job['source_version'])).fetchone()
        try:
            with self.store.connect() as db:
                db.execute('BEGIN')
                result=core_readiness.evaluate(db,job['project_id'],job['source_version'],json.loads(snapshot['data']))
            result['at']=result['generatedAt'];status='completed'
        except Exception:result={'error':'local_check_failed','message':'Не удалось проверить сохранённую версию.'};status='failed'
        with self.store.transaction() as db:
            db.execute('UPDATE jobs SET status=?,result=?,updated_at=? WHERE id=?',(status,encoded(result),now(),job['id']))
            self.store.event(db,job['project_id'],job['actor_id'],'check_'+status,{'jobId':job['id'],'sourceVersion':job['source_version']})
        return True
    def run(self):
        while not self.stopped.is_set():
            try:
                worked=self.run_one();self.last_cycle_at=now();self.last_cycle_monotonic=time.monotonic();self.storage_healthy=True
                if not worked:self.stopped.wait(.25)
            except sqlite3.OperationalError:
                self.storage_errors+=1;self.last_storage_error_at=now();self.storage_healthy=False;self.stopped.wait(1)
    def stop(self):self.stopped.set()

class Handler(SimpleHTTPRequestHandler):
    server_version='OSGARD-Core/1'
    def setup(self):
        super().setup();self.connection.settimeout(15)
    def log_message(self,fmt,*args): pass # Avoid credentials, tokens and project payloads in access logs.
    def end_headers(self):
        self.send_header('X-Content-Type-Options','nosniff');self.send_header('Referrer-Policy','same-origin')
        if self.path.startswith('/api/'):self.send_header('Cache-Control','no-store')
        else:self.send_header('Cache-Control','no-cache')
        super().end_headers()
    def list_directory(self,path):self.send_error(404);return None
    def send_head(self):
        requested=urlsplit(self.path).path
        path=Path(self.translate_path(self.path))
        if not path.exists() and re.fullmatch('/r/[A-Za-z0-9_-]{1,128}/?',requested):self.path='/index.html'
        return super().send_head()
    def send_error(self,code,message=None,explain=None):
        error_page=Path(self.directory)/'404.html'
        if code==404 and error_page.is_file():
            data=error_page.read_bytes();self.send_response(404);self.send_header('Content-Type','text/html; charset=utf-8');self.send_header('Content-Length',str(len(data)));self.end_headers()
            if self.command!='HEAD':self.wfile.write(data)
        else:super().send_error(code,message,explain)
    def output(self,value,status=200):
        data=encoded(value).encode();self.send_response(status);self.send_header('Content-Type','application/json; charset=utf-8');self.send_header('Content-Length',str(len(data)));self.end_headers()
        if self.command!='HEAD':self.wfile.write(data)
    def body(self):
        require(self.headers.get('Content-Type','').split(';')[0]=='application/json','Ожидается JSON.','content_type',415)
        try:size=int(self.headers.get('Content-Length','0'))
        except ValueError:raise Fault('body','Неверный размер запроса.')
        require(0<size<=256*1024,'Размер запроса превышен.','body_size',413)
        try:p=json.loads(self.rfile.read(size),parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
        except (ValueError,UnicodeError):raise Fault('json','Неверный JSON.')
        require(isinstance(p,dict),'Нужен JSON-объект.')
        return p
    def raw_json_body(self):
        require(self.headers.get('Content-Type','').split(';')[0]=='application/json','Ожидается JSON.','content_type',415)
        try:size=int(self.headers.get('Content-Length','0'))
        except ValueError:raise Fault('body','Неверный размер запроса.')
        require(0<size<=256*1024,'Размер запроса превышен.','body_size',413)
        raw=self.rfile.read(size);require(len(raw)==size,'Неполное тело запроса.','body',400)
        return raw
    def api(self,method):
        try:
            origin=self.headers.get('Origin');host=self.headers.get('Host','')
            require(host in self.server.allowed_hosts,'Недопустимый адрес сервера.','host',403)
            require(not origin or origin in self.server.allowed_origins,'Запрос с другого сайта запрещён.','origin',403)
            route=urlsplit(self.path).path.removeprefix('/api/core/').strip('/')
            if method=='GET' and route=='health':return self.output({'status':'ok','mode':'self-hosted-pilot','schemaVersion':1,'payments':self.server.store.commerce.config.enabled,'paymentMode':'live' if self.server.store.commerce.config.livemode else 'test','livePaymentTested':False,'ai':False})
            if method=='POST' and route=='commerce/webhook':return self.output(self.server.store.commerce.webhook(self.raw_json_body(),self.headers.get('Stripe-Signature')))
            if method=='POST' and route in ('auth/register','auth/login','auth/recover','auth/password','auth/recovery/prepare'):
                with self.server.rate_lock:
                    stamp=time.monotonic();buckets=self.server.rate_limits
                    for ip in list(buckets):
                        buckets[ip]=[t for t in buckets[ip] if stamp-t<900]
                        if not buckets[ip]:del buckets[ip]
                    require(len(buckets)<2048 or self.client_address[0] in buckets,'Слишком много попыток входа.','rate_limit',429)
                    attempts=buckets.setdefault(self.client_address[0],[]);require(len(attempts)<20,'Слишком много попыток. Повторите через 15 минут.','rate_limit',429);attempts.append(stamp)
                if route=='auth/recover':return self.output(core_account.recover(self.server.store,self.body()))
                if route in ('auth/register','auth/login'):return self.output(self.server.store.auth(route.split('/')[1],self.body(),self.headers.get('User-Agent','')))
            auth=self.headers.get('Authorization','');actor=self.server.store.actor(auth[7:] if auth.startswith('Bearer ') else '')
            if method=='POST' and re.fullmatch(r'commerce/orders/[a-f0-9]{32}/(checkout|refund)',route):return self.output(self.server.store.commerce.execute(route,actor['id'],self.body(),self.headers.get('Idempotency-Key')))
            if method=='GET' and route=='overview':
                report=self.server.store.get(route,actor['id']);worker=getattr(self.server,'worker',None)
                report['runtime']=dict(uptimeSeconds=round(time.monotonic()-self.server.started_monotonic),workerRegistered=worker is not None,workerAlive=worker.is_alive() if worker else None,lastCycleAt=worker.last_cycle_at if worker else None,secondsSinceCycle=round(time.monotonic()-worker.last_cycle_monotonic,2) if worker and worker.last_cycle_monotonic else None,storageHealthy=worker.storage_healthy if worker else None,storageErrorsSinceStart=worker.storage_errors if worker else None,lastStorageErrorAt=worker.last_storage_error_at if worker else None,scope='This HTTP server process only; no infrastructure uptime or backup guarantee')
                return self.output(report)
            if method=='GET' and route=='auth/security':return self.output(core_account.security(self.server.store,actor['id'],auth[7:]))
            if method=='POST' and route in ('auth/password','auth/sessions/revoke','auth/sessions/revoke-others','auth/recovery/prepare','auth/recovery/activate'):
                payload=self.body();handlers={'auth/password':core_account.change_password,'auth/sessions/revoke':core_account.revoke,'auth/recovery/prepare':core_account.prepare_codes,'auth/recovery/activate':core_account.activate_codes}
                if route=='auth/sessions/revoke-others':return self.output(core_account.revoke_others(self.server.store,actor['id'],auth[7:]))
                return self.output(handlers[route](self.server.store,actor['id'],auth[7:],payload))
            if method=='GET' and route=='auth/me':return self.output({'user':actor})
            if method=='POST' and route=='auth/logout':
                with self.server.store.transaction() as db:db.execute('DELETE FROM sessions WHERE token_hash=?',(digest(auth[7:]),))
                return self.output({'loggedOut':True})
            if method=='GET':return self.output(self.server.store.get(route,actor['id']))
            if method=='POST':return self.output(self.server.store.mutate(route,actor['id'],self.body(),self.headers.get('Idempotency-Key')))
            raise Fault('method','Метод не поддерживается.',405)
        except Fault as e:self.output({'error':e.code,'message':e.message},e.status)
        except sqlite3.OperationalError:self.output({'error':'storage_unavailable','message':'Хранилище временно недоступно. Повторите тот же запрос.'},503)
        except (TypeError,KeyError,ValueError,OverflowError):self.output({'error':'validation','message':'Проверьте формат полей запроса.'},400)
        except Exception:self.output({'error':'internal','message':'Не удалось выполнить запрос. Повторите с тем же ключом операции.'},500)
    def do_GET(self):
        if self.path.startswith('/api/'):return self.api('GET')
        return super().do_GET()
    def do_HEAD(self):
        if self.path.startswith('/api/'):return self.api('HEAD')
        return super().do_HEAD()
    def do_POST(self):return self.api('POST') if self.path.startswith('/api/') else self.send_error(405)

def create_server(root,database,host='127.0.0.1',port=4173,public_origin=None,commerce_config=None,commerce_provider=None):
    require(not Path(database).resolve().is_relative_to(Path(root).resolve()),'База данных должна быть вне публичной папки сайта.')
    server=ThreadingHTTPServer((host,port),functools.partial(Handler,directory=str(Path(root).resolve())))
    server.started_monotonic=time.monotonic();server.worker=None;server.store=Store(database,commerce_config or core_commerce.Config.from_env(),commerce_provider);server.rate_limits={};server.rate_lock=threading.Lock()
    actual=server.server_address[1]
    server.allowed_origins={f'http://127.0.0.1:{actual}',f'http://localhost:{actual}'}
    server.allowed_hosts={f'127.0.0.1:{actual}',f'localhost:{actual}'}
    if public_origin:
        parsed=urlsplit(public_origin)
        require(parsed.scheme=='https' and parsed.hostname and not parsed.path and not parsed.query and not parsed.fragment and not parsed.username,'Внешний адрес должен быть HTTPS origin без пути.')
        server.allowed_origins.add(public_origin);server.allowed_hosts.add(parsed.netloc)
    return server

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1]/'dist');parser.add_argument('--database',type=Path,default=Path.home()/'.osgard-core'/'core.sqlite3');parser.add_argument('--port',type=int,default=4173);parser.add_argument('--host',default='127.0.0.1');parser.add_argument('--public-origin')
    args=parser.parse_args();require((args.root/'index.html').is_file(),'Сначала соберите сайт: npm run build.')
    require(args.host in ('127.0.0.1','localhost') or args.public_origin,'Для внешнего интерфейса нужен HTTPS reverse proxy и --public-origin.')
    server=create_server(args.root,args.database,args.host,args.port,args.public_origin)
    worker=QueueWorker(server.store);server.worker=worker;worker.start()
    print(f'OSGARD Core: http://127.0.0.1:{server.server_address[1]}/workspace — data: {args.database}',flush=True)
    try:server.serve_forever()
    except KeyboardInterrupt:pass
    finally:worker.stop();worker.join(timeout=5);server.server_close()
if __name__=='__main__':main()
