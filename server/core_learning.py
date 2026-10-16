"""Learning activities, immutable submissions/reviews and an explicitly configured pilot."""
from pathlib import Path
from datetime import datetime,timezone
import copy
import json
from core_model import require, text, date, url, now, uid

CURRICULUM=json.loads((Path(__file__).parent/'curriculum.json').read_text(encoding='utf-8'))
LESSONS={v['slug']:v for v in CURRICULUM['lessons']}
RUBRIC=[dict(id='definition',title='Постановка задачи'),dict(id='verification',title='Проверка фактов'),dict(id='repeatability',title='Повторяемость'),dict(id='oversight',title='Человеческий контроль'),dict(id='evaluation',title='Оценка результата')]
SCHEMA='''
CREATE TABLE IF NOT EXISTS lesson_activities(id TEXT PRIMARY KEY,project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,actor_id TEXT NOT NULL,slug TEXT NOT NULL,curriculum_hash TEXT NOT NULL,answer INTEGER NOT NULL,practice TEXT NOT NULL,passed INTEGER NOT NULL,locale TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS submissions(id TEXT PRIMARY KEY,project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,actor_id TEXT NOT NULL,source_version INTEGER NOT NULL,summary TEXT NOT NULL,evidence TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS reviews(id TEXT PRIMARY KEY,project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,submission_id TEXT REFERENCES submissions(id) ON DELETE CASCADE,actor_id TEXT NOT NULL,scores TEXT NOT NULL,note TEXT NOT NULL,verdict TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS pilot_profiles(project_id TEXT PRIMARY KEY REFERENCES projects(id) ON DELETE CASCADE,data TEXT NOT NULL,updated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS pilot_sessions(id TEXT PRIMARY KEY,project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,title TEXT NOT NULL,starts_at TEXT NOT NULL,ends_at TEXT NOT NULL,kind TEXT NOT NULL,facilitator_id TEXT NOT NULL,meeting_url TEXT NOT NULL,notes TEXT NOT NULL,status TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS pilot_attendance(session_id TEXT REFERENCES pilot_sessions(id) ON DELETE CASCADE,actor_id TEXT NOT NULL,note TEXT NOT NULL,created_at TEXT NOT NULL,PRIMARY KEY(session_id,actor_id));
CREATE INDEX IF NOT EXISTS activity_project ON lesson_activities(project_id,slug);
CREATE INDEX IF NOT EXISTS submission_project ON submissions(project_id,created_at);
'''

def completed(db,pid,actor):
    rows=db.execute('SELECT DISTINCT slug,curriculum_hash FROM lesson_activities WHERE project_id=? AND actor_id=? AND passed=1',(pid,actor))
    return [v['slug'] for v in rows if v['slug'] in LESSONS and v['curriculum_hash']==LESSONS[v['slug']]['hash']]

def readiness(db,pid,data,actor):
    done=completed(db,pid,actor)
    return [dict(id='lessons',label='Практика и самопроверка сохранены по восьми актуальным урокам',passed=len(done)==len(LESSONS)),dict(id='goal',label='Заданы цель, аудитория и критерии',passed=bool(data['goal'] and data['audience'] and data['acceptance'])),dict(id='artifact',label='Есть ссылка или созданный HTML-файл',passed=bool(data['artifact']['url'] or data['artifact'].get('assetId'))),dict(id='transfer',label='Описаны исходный результат, новая задача, результат и доказательства',passed=all(data['practice'].get(k,'').strip() for k in ('before','newTask','after','evidence'))),dict(id='sources',label='Добавлены минимум три источника со ссылками',passed=sum(bool(s['url']) for s in data['sources'])>=3)]

def read(store,db,pid,actor,export=False):
    row=store.access(db,pid,actor);data=json.loads(row['data'])
    require(export or data['consents']['learning'],'Использование Learning в этом проекте отключено. Включите его в контракте.')
    activities=[dict(id=r['id'],slug=r['slug'],hash=r['curriculum_hash'],answer=r['answer'],practice=r['practice'],passed=bool(r['passed']),locale=r['locale'],actor=r['username'],createdAt=r['created_at']) for r in db.execute('SELECT a.*,u.username FROM lesson_activities a JOIN users u ON u.id=a.actor_id WHERE project_id=? ORDER BY created_at DESC,a.rowid DESC LIMIT ?',(pid,1000 if export else 100))]
    submissions=[dict(id=r['id'],actorId=r['actor_id'],actor=r['username'],sourceVersion=r['source_version'],summary=r['summary'],evidence=r['evidence'],createdAt=r['created_at']) for r in db.execute('SELECT s.*,u.username FROM submissions s JOIN users u ON u.id=s.actor_id WHERE project_id=? ORDER BY s.created_at DESC,s.rowid DESC',(pid,))]
    reviews=[dict(id=r['id'],submissionId=r['submission_id'],actorId=r['actor_id'],actor=r['username'],scores=json.loads(r['scores']),note=r['note'],verdict=r['verdict'],createdAt=r['created_at']) for r in db.execute('SELECT r.*,u.username FROM reviews r JOIN users u ON u.id=r.actor_id WHERE project_id=? ORDER BY r.created_at DESC,r.rowid DESC',(pid,))]
    profile=db.execute('SELECT data FROM pilot_profiles WHERE project_id=?',(pid,)).fetchone()
    sessions=[dict(id=r['id'],title=r['title'],startsAt=r['starts_at'],endsAt=r['ends_at'],kind=r['kind'],facilitator=r['username'],meetingUrl=r['meeting_url'],notes=r['notes'],status=r['status']) for r in db.execute('SELECT s.*,u.username FROM pilot_sessions s JOIN users u ON u.id=s.facilitator_id WHERE project_id=? ORDER BY starts_at,id',(pid,))]
    attendees=[dict(sessionId=r['session_id'],actor=r['username'],note=r['note'],createdAt=r['created_at']) for r in db.execute('SELECT a.*,u.username FROM pilot_attendance a JOIN users u ON u.id=a.actor_id JOIN pilot_sessions s ON s.id=a.session_id WHERE s.project_id=?',(pid,))]
    people=[dict(id=row['owner_id'],username=db.execute('SELECT username FROM users WHERE id=?',(row['owner_id'],)).fetchone()[0],role='owner')]+[dict(r) for r in db.execute('SELECT u.id,u.username,m.role FROM effective_project_members m JOIN users u ON u.id=m.user_id WHERE m.project_id=? AND m.user_id!=(SELECT owner_id FROM projects WHERE id=m.project_id)',(pid,))]
    return dict(program=CURRICULUM['program'],completed=completed(db,pid,actor),readiness=readiness(db,pid,data,actor),activities=activities,submissions=submissions,reviews=reviews,rubric=RUBRIC,pilot=json.loads(profile['data']) if profile else dict(name='',audience='',hypothesis='',status='draft',notes=''),sessions=sessions,attendance=attendees,participants=people,assignments=[dict(submissionId=a['submission_id'],reviewerId=a['reviewer_id'],reviewer=a['username'],deadline=a['deadline'],note=a['note'],status=a['status']) for a in db.execute('SELECT a.*,u.username FROM review_assignments a JOIN users u ON u.id=a.reviewer_id WHERE project_id=?',(pid,))])

def mutate(store,db,row,actor,payload):
    kind=payload.get('action');pid=row['id'];data=json.loads(row['data']);detail={};feedback=None
    require(data['consents']['learning'],'Сначала разрешите использование контекста Learning в контракте.')
    if kind=='activity':
        slug=payload.get('slug');require(isinstance(slug,str) and slug in LESSONS,'Неизвестный урок.')
        locale=payload.get('locale','ru');require(locale in ('ru','en'),'Неверный язык.')
        lesson=LESSONS[slug][locale];answer=payload.get('answer')
        require(type(answer) is int and 0<=answer<len(lesson['check']['options']),'Выберите ответ в самопроверке урока.')
        practice=text(payload.get('practice'),10000,20);passed=answer==lesson['check']['correctIndex']
        require(db.execute('SELECT COUNT(*) FROM lesson_activities WHERE project_id=?',(pid,)).fetchone()[0]<1000,'Лимит учебных попыток проекта.',status=409)
        aid=uid();db.execute('INSERT INTO lesson_activities VALUES(?,?,?,?,?,?,?,?,?,?)',(aid,pid,actor,slug,LESSONS[slug]['hash'],answer,practice,int(passed),locale,now()))
        if passed and slug not in data['lessonCompletions']:data['lessonCompletions'].append(slug)
        detail={'activityId':aid,'slug':slug,'passed':passed};feedback={'passed':passed,'explanation':lesson['check']['explanation']}
    elif kind=='submit':
        checks=readiness(db,pid,data,actor);require(all(c['passed'] for c in checks),'Итоговая работа ещё не готова. Проверьте список готовности.','not_ready',409)
        require(db.execute('SELECT COUNT(*) FROM submissions WHERE project_id=?',(pid,)).fetchone()[0]<50,'Лимит сдач итоговой работы.',status=409)
        sid=uid();db.execute('INSERT INTO submissions VALUES(?,?,?,?,?,?,?)',(sid,pid,actor,row['version'],text(payload.get('summary'),10000,40),text(payload.get('evidence'),10000,20),now()));detail={'submissionId':sid,'sourceVersion':row['version']}
    elif kind=='assign_review':
        require(row['role']=='owner','Назначать разбор может владелец проекта.','forbidden',403)
        submitted=db.execute('SELECT * FROM submissions WHERE project_id=? AND id=?',(pid,payload.get('submissionId'))).fetchone();require(submitted is not None,'Сдача не найдена.','not_found',404)
        target=db.execute('SELECT id,username FROM users WHERE username=?',(text(payload.get('reviewer'),64,3).lower(),)).fetchone();require(target is not None,'Аккаунт проверяющего не найден.','not_found',404)
        store.access(db,pid,target['id'],write=True);require(target['id']!=submitted['actor_id'],'Автор не может быть проверяющим своей сдачи.','self_review',403)
        deadline=date(payload.get('deadline',''));note=text(payload.get('note',''),2000)
        db.execute("INSERT INTO review_assignments VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(submission_id) DO UPDATE SET reviewer_id=excluded.reviewer_id,assigned_by=excluded.assigned_by,deadline=excluded.deadline,note=excluded.note,status='open',updated_at=excluded.updated_at",(submitted['id'],pid,target['id'],actor,deadline,note,'open',now()))
        detail={'submissionId':submitted['id'],'reviewer':target['username'],'deadline':deadline}
    elif kind=='withdraw_review':
        require(row['role']=='owner','Снять назначение может владелец.','forbidden',403)
        found=db.execute('SELECT submission_id FROM review_assignments WHERE project_id=? AND submission_id=?',(pid,payload.get('submissionId'))).fetchone();require(found is not None,'Назначение не найдено.','not_found',404)
        db.execute("UPDATE review_assignments SET status='withdrawn',updated_at=? WHERE submission_id=?",(now(),found['submission_id']));detail={'submissionId':found['submission_id']}
    elif kind=='review':
        submitted=db.execute('SELECT * FROM submissions WHERE id=? AND project_id=?',(payload.get('submissionId'),pid)).fetchone();require(submitted is not None,'Сдача не найдена.','not_found',404)
        require(submitted['actor_id']!=actor,'Свою работу нельзя оценивать как разбор другого участника.','self_review',403)
        assigned=db.execute('SELECT reviewer_id,status FROM review_assignments WHERE project_id=? AND submission_id=?',(pid,submitted['id'])).fetchone()
        require(assigned is None or assigned['status']=='withdrawn' or assigned['reviewer_id']==actor,'Для этой сдачи назначен другой проверяющий.','assigned_reviewer',403)
        scores=payload.get('scores');require(isinstance(scores,list) and len(scores)==len(RUBRIC),'Заполните все пять критериев рубрики.')
        require(all(isinstance(v,dict) for v in scores),'Неверная рубрика.')
        require({v.get('id') for v in scores}=={v['id'] for v in RUBRIC},'Неверные или повторные критерии.')
        result=[]
        for score in scores:
            require(type(score.get('score')) is int and 0<=score['score']<=2,'Оценка критерия — 0, 1 или 2.')
            result.append(dict(id=score['id'],score=score['score'],evidence=text(score.get('evidence'),2000,10)))
        require(db.execute('SELECT COUNT(*) FROM reviews WHERE project_id=?',(pid,)).fetchone()[0]<100,'Лимит разборов проекта.',status=409)
        db.execute("UPDATE review_assignments SET status='done',updated_at=? WHERE project_id=? AND submission_id=? AND reviewer_id=? AND status='open'",(now(),pid,submitted['id'],actor))
        rid=uid();verdict='reviewed' if all(v['score']==2 for v in result) else 'needs_changes'
        db.execute('INSERT INTO reviews VALUES(?,?,?,?,?,?,?,?)',(rid,pid,submitted['id'],actor,json.dumps(result,ensure_ascii=False),text(payload.get('note'),4000,10),verdict,now()));detail={'reviewId':rid,'submissionId':submitted['id'],'verdict':verdict}
    elif kind=='pilot_config':
        require(row['role']=='owner','Настройки пилота меняет владелец.','forbidden',403)
        profile=dict(name=text(payload.get('name'),160,2),audience=text(payload.get('audience'),1000,10),hypothesis=text(payload.get('hypothesis'),2000,10),notes=text(payload.get('notes',''),4000),status=payload.get('status'))
        require(profile['status'] in ('draft','running','closed'),'Неизвестный статус пилота.')
        db.execute('INSERT INTO pilot_profiles VALUES(?,?,?) ON CONFLICT(project_id) DO UPDATE SET data=excluded.data,updated_at=excluded.updated_at',(pid,json.dumps(profile,ensure_ascii=False),now()));detail={'status':profile['status']}
    elif kind=='session':
        require(row['role']=='owner','Расписание меняет владелец.','forbidden',403)
        start=date(payload.get('startsAt'),False);end=date(payload.get('endsAt'),False)
        seconds=(datetime.fromisoformat(end)-datetime.fromisoformat(start)).total_seconds();require(0<seconds<=8*3600,'Занятие должно длиться от 1 секунды до 8 часов.')
        facilitator=text(payload.get('facilitator'),64,3).lower();person=db.execute('SELECT id FROM users WHERE username=?',(facilitator,)).fetchone();require(person is not None,'Ведущий не найден.','not_found',404)
        store.access(db,pid,person['id'],write=True)
        meeting=url(payload.get('meetingUrl',''));require(not meeting or meeting.startswith('https://'),'Ссылка встречи должна использовать HTTPS.')
        require(payload.get('kind') in ('practice','review','discussion'),'Неизвестный тип занятия.')
        require(db.execute('SELECT COUNT(*) FROM pilot_sessions WHERE project_id=?',(pid,)).fetchone()[0]<100,'Лимит занятий пилота.',status=409)
        sid=uid();db.execute('INSERT INTO pilot_sessions VALUES(?,?,?,?,?,?,?,?,?,?,?)',(sid,pid,text(payload.get('title'),200,3),start,end,payload['kind'],person['id'],meeting,text(payload.get('notes',''),4000),'planned',now()));detail={'sessionId':sid}
    elif kind=='session_status':
        require(row['role']=='owner','Расписание меняет владелец.','forbidden',403)
        require(payload.get('status') in ('planned','completed','cancelled'),'Неверный статус занятия.')
        found=db.execute('SELECT id FROM pilot_sessions WHERE project_id=? AND id=?',(pid,payload.get('sessionId'))).fetchone();require(found is not None,'Занятие не найдено.','not_found',404)
        db.execute('UPDATE pilot_sessions SET status=? WHERE id=?',(payload['status'],found['id']));detail={'sessionId':found['id'],'status':payload['status']}
    elif kind=='attendance':
        session=db.execute('SELECT * FROM pilot_sessions WHERE project_id=? AND id=?',(pid,payload.get('sessionId'))).fetchone();require(session is not None,'Занятие не найдено.','not_found',404);require(session['status']!='cancelled','Занятие отменено.')
        require(datetime.fromisoformat(session['starts_at'])<=datetime.now(timezone.utc),'Посещение нельзя отметить до начала занятия.')
        note=text(payload.get('note'),2000,10);db.execute('INSERT INTO pilot_attendance VALUES(?,?,?,?) ON CONFLICT(session_id,actor_id) DO UPDATE SET note=excluded.note,created_at=excluded.created_at',(session['id'],actor,note,now()));detail={'sessionId':session['id'],'selfReported':True}
    else:require(False,'Неизвестное учебное действие.')
    project=store.save(db,row,actor,data,'learning_'+kind,detail)
    return dict(project=project,feedback=feedback,learningChanged=True)
