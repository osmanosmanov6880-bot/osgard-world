"""Explicit member-to-member handoff and scoped support. No email, payment or access grants."""
import json
import re
from core_model import require,text,now,uid
import core_acceptance

SCHEMA='''
CREATE TABLE IF NOT EXISTS handoffs(id TEXT PRIMARY KEY,project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,release_id TEXT NOT NULL,source_version INTEGER NOT NULL,creator_id TEXT NOT NULL REFERENCES users(id),recipient_id TEXT NOT NULL REFERENCES users(id),review_id TEXT NOT NULL REFERENCES release_reviews(id),note TEXT NOT NULL,status TEXT NOT NULL CHECK(status IN ('pending','acknowledged','withdrawn')),created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
CREATE UNIQUE INDEX IF NOT EXISTS handoff_active ON handoffs(project_id,release_id,recipient_id) WHERE status!='withdrawn';
CREATE TABLE IF NOT EXISTS support_tickets(id TEXT PRIMARY KEY,project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,handoff_id TEXT NOT NULL REFERENCES handoffs(id),requester_id TEXT NOT NULL REFERENCES users(id),title TEXT NOT NULL,status TEXT NOT NULL CHECK(status IN ('open','active','resolved','closed')),created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS support_messages(id TEXT PRIMARY KEY,ticket_id TEXT NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,actor_id TEXT NOT NULL REFERENCES users(id),body TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS support_transitions(id TEXT PRIMARY KEY,ticket_id TEXT NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,actor_id TEXT NOT NULL REFERENCES users(id),from_status TEXT NOT NULL,to_status TEXT NOT NULL,note TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS template_provenance(template_id TEXT PRIMARY KEY REFERENCES templates(id) ON DELETE CASCADE,release_id TEXT NOT NULL,review_id TEXT NOT NULL REFERENCES release_reviews(id),reviewer TEXT NOT NULL,reviewed_at TEXT NOT NULL);
'''

def identifier(value):
    value=text(value,32,32);require(re.fullmatch('[a-f0-9]{32}',value),'Неверный идентификатор записи.');return value

def writer(row):return row['role'] in ('owner','editor')
def can_ticket(row,ticket,actor):return writer(row) or ticket['requester_id']==actor

def handoff_dict(db,h):
    names={u['id']:u['username'] for u in db.execute('SELECT id,username FROM users WHERE id IN (?,?)',(h['creator_id'],h['recipient_id']))}
    access=db.execute('SELECT 1 FROM projects p LEFT JOIN effective_project_members m ON p.id=m.project_id AND m.user_id=? WHERE p.id=? AND (p.owner_id=? OR m.user_id=?)',(h['recipient_id'],h['project_id'],h['recipient_id'],h['recipient_id'])).fetchone() is not None
    latest=core_acceptance.reviews(db,h['project_id'],h['release_id'])
    return dict(latestReviewVerdict=latest[0]['verdict'] if latest else None,reviewStillLatest=bool(latest and latest[0]['id']==h['review_id']),id=h['id'],releaseId=h['release_id'],sourceVersion=h['source_version'],creatorId=h['creator_id'],creator=names[h['creator_id']],recipientId=h['recipient_id'],recipient=names[h['recipient_id']],reviewId=h['review_id'],note=h['note'],status=h['status'],recipientHasAccess=access,createdAt=h['created_at'],updatedAt=h['updated_at'])
def ticket_dict(db,t):
    return dict(id=t['id'],handoffId=t['handoff_id'],requesterId=t['requester_id'],requester=db.execute('SELECT username FROM users WHERE id=?',(t['requester_id'],)).fetchone()[0],title=t['title'],status=t['status'],messageCount=db.execute('SELECT COUNT(*) FROM support_messages WHERE ticket_id=?',(t['id'],)).fetchone()[0],createdAt=t['created_at'],updatedAt=t['updated_at'])
def conversation(db,t):
    d=ticket_dict(db,t)
    d['messages']=[dict(id=m['id'],actorId=m['actor_id'],actor=m['username'],body=m['body'],createdAt=m['created_at']) for m in db.execute('SELECT m.*,u.username FROM support_messages m JOIN users u ON u.id=m.actor_id WHERE ticket_id=? ORDER BY m.created_at,m.rowid',(t['id'],))]
    d['transitions']=[dict(id=m['id'],actor=m['username'],fromStatus=m['from_status'],toStatus=m['to_status'],note=m['note'],createdAt=m['created_at']) for m in db.execute('SELECT m.*,u.username FROM support_transitions m JOIN users u ON u.id=m.actor_id WHERE ticket_id=? ORDER BY m.created_at,m.rowid',(t['id'],))]
    return d

def read(store,db,pid,actor,ticket_id=None,export=False):
    row=store.access(db,pid,actor);data=json.loads(row['data']);require(export or data['consents']['business'],'Использование Business отключено в контракте.')
    if ticket_id:
        t=db.execute('SELECT * FROM support_tickets WHERE project_id=? AND id=?',(pid,ticket_id)).fetchone();require(t is not None and can_ticket(row,t,actor),'Обращение не найдено.','not_found',404)
        return dict(ticket=conversation(db,t),projectVersion=row['version'])
    handoffs=[handoff_dict(db,h) for h in db.execute('SELECT * FROM handoffs WHERE project_id=? ORDER BY created_at DESC,rowid DESC',(pid,)) if writer(row) or actor in (h['creator_id'],h['recipient_id'])]
    ts=[t for t in db.execute('SELECT * FROM support_tickets WHERE project_id=? ORDER BY updated_at DESC,rowid DESC',(pid,)) if can_ticket(row,t,actor)]
    people=[dict(id=row['owner_id'],username=db.execute('SELECT username FROM users WHERE id=?',(row['owner_id'],)).fetchone()[0],role='owner')]+[dict(p) for p in db.execute('SELECT u.id,u.username,m.role FROM effective_project_members m JOIN users u ON u.id=m.user_id WHERE m.project_id=? AND m.user_id!=(SELECT owner_id FROM projects WHERE id=m.project_id)',(pid,))]
    return dict(projectVersion=row['version'],handoffs=handoffs,tickets=[conversation(db,t) if export else ticket_dict(db,t) for t in ts],participants=people,limits=dict(externalDelivery=False,payments=False,accessGranted=False,receiptMeaning='Acknowledgement of materials only, not purchase or independent acceptance'))

def mutate(store,db,row,actor,payload):
    data=json.loads(row['data']);require(data['consents']['business'],'Использование Business отключено в контракте.')
    kind=payload.get('action');detail={};stamp=now();result={}
    if kind=='handoff':
        require(writer(row),'Передавать выпуск может редактор.','forbidden',403);require(data['consents']['studio'],'Использование Studio отключено в контракте.')
        rid=identifier(payload.get('releaseId'));release,_,_,asset=core_acceptance.release_source(db,row,rid)
        rs=core_acceptance.reviews(db,row['id'],rid);require(rs and rs[0]['verdict']=='accepted','Нужен последний положительный разбор этого выпуска другим участником.','review_required',409)
        require(asset is None or asset['integrityMatches'],'Файл выпуска повреждён.','integrity_mismatch',409)
        require(asset is None or asset['inputsMatchSnapshot'],'HTML не соответствует исходным данным выпуска. Создайте и примите новый выпуск.','artifact_stale',409)
        username=text(payload.get('recipient'),64,3).lower();recipient=db.execute('SELECT id FROM users WHERE username=?',(username,)).fetchone();require(recipient is not None,'Участник не найден.','not_found',404)
        store.access(db,row['id'],recipient['id']);require(recipient['id']!=actor,'Выберите другого участника.')
        require(db.execute("SELECT 1 FROM handoffs WHERE project_id=? AND release_id=? AND recipient_id=? AND status!='withdrawn'",(row['id'],rid,recipient['id'])).fetchone() is None,'Этому участнику уже передан данный выпуск.','handoff_exists',409)
        require(db.execute('SELECT COUNT(*) FROM handoffs WHERE project_id=?',(row['id'],)).fetchone()[0]<200,'Лимит 200 передач.',status=409)
        hid=uid();note=text(payload.get('note'),2000,20)
        db.execute('INSERT INTO handoffs VALUES(?,?,?,?,?,?,?,?,?,?,?)',(hid,row['id'],rid,release['sourceVersion'],actor,recipient['id'],rs[0]['id'],note,'pending',stamp,stamp));detail=dict(handoffId=hid,releaseId=rid,recipientId=recipient['id'],reviewId=rs[0]['id']);result={'handoffId':hid}
    elif kind in ('acknowledge','withdraw'):
        h=db.execute('SELECT * FROM handoffs WHERE project_id=? AND id=?',(row['id'],identifier(payload.get('handoffId')))).fetchone();require(h is not None,'Передача не найдена.','not_found',404)
        if kind=='acknowledge':
            require(h['recipient_id']==actor,'Подтверждает только получатель.','forbidden',403);require(h['status']=='pending','Передача уже подтверждена или отозвана.','handoff_state',409);status='acknowledged'
        else:
            require(row['role']=='owner' or h['creator_id']==actor and writer(row),'Отозвать может отправитель-редактор или владелец.','forbidden',403);require(h['status']!='withdrawn','Передача уже отозвана.','handoff_state',409);status='withdrawn'
        db.execute('UPDATE handoffs SET status=?,updated_at=? WHERE id=?',(status,stamp,h['id']));detail=dict(handoffId=h['id'],fromStatus=h['status'],toStatus=status);result={'handoffId':h['id']}
    elif kind=='ticket':
        h=db.execute('SELECT * FROM handoffs WHERE project_id=? AND id=?',(row['id'],identifier(payload.get('handoffId')))).fetchone();require(h is not None and (writer(row) or h['recipient_id']==actor),'Передача не найдена.','not_found',404)
        require(h['status']!='withdrawn','Передача отозвана. Для нового обращения нужна действующая передача.','handoff_state',409)
        require(db.execute('SELECT COUNT(*) FROM support_tickets WHERE project_id=?',(row['id'],)).fetchone()[0]<100,'Лимит 100 обращений.',status=409)
        tid=uid();title=text(payload.get('title'),160,5);body=text(payload.get('body'),4000,20)
        message_limit(db,row['id'],None)
        db.execute('INSERT INTO support_tickets VALUES(?,?,?,?,?,?,?,?)',(tid,row['id'],h['id'],actor,title,'open',stamp,stamp));db.execute('INSERT INTO support_messages VALUES(?,?,?,?,?)',(uid(),tid,actor,body,stamp));detail=dict(ticketId=tid,handoffId=h['id']);result={'ticketId':tid}
    elif kind in ('reply','ticket_status'):
        t=db.execute('SELECT * FROM support_tickets WHERE project_id=? AND id=?',(row['id'],identifier(payload.get('ticketId')))).fetchone();require(t is not None and can_ticket(row,t,actor),'Обращение не найдено.','not_found',404)
        if kind=='reply':
            require(t['status']!='closed','Обращение закрыто. Сначала откройте его снова.','ticket_state',409);message_limit(db,row['id'],t['id']);body=text(payload.get('body'),4000,10);db.execute('INSERT INTO support_messages VALUES(?,?,?,?,?)',(uid(),t['id'],actor,body,stamp));detail=dict(ticketId=t['id'])
        else:
            status=payload.get('status');allowed={'open':{'active','resolved'},'active':{'resolved'},'resolved':{'open','closed'},'closed':{'open'}}
            require(isinstance(status,str) and status in allowed[t['status']],'Этот переход статуса недоступен.','ticket_state',409)
            require(writer(row) or status in ('open','closed'),'Взять в работу и отметить решение может редактор.','forbidden',403)
            require(db.execute('SELECT COUNT(*) FROM support_transitions WHERE ticket_id=?',(t['id'],)).fetchone()[0]<100,'Лимит изменений статуса обращения.',status=409)
            note=text(payload.get('note'),2000,10);db.execute('INSERT INTO support_transitions VALUES(?,?,?,?,?,?,?)',(uid(),t['id'],actor,t['status'],status,note,stamp));db.execute('UPDATE support_tickets SET status=? WHERE id=?',(status,t['id']));detail=dict(ticketId=t['id'],fromStatus=t['status'],toStatus=status)
        db.execute('UPDATE support_tickets SET updated_at=? WHERE id=?',(stamp,t['id']));result={'ticketId':t['id']}
    else:require(False,'Неизвестное действие передачи.')
    project=store.save(db,row,actor,data,'delivery_'+kind,detail)
    return dict(project=project,**result)

def message_limit(db,pid,tid):
    require(db.execute('SELECT COUNT(*) FROM support_messages m JOIN support_tickets t ON t.id=m.ticket_id WHERE t.project_id=?',(pid,)).fetchone()[0]<500,'Лимит 500 сообщений проекта.',status=409)
    require(tid is None or db.execute('SELECT COUNT(*) FROM support_messages WHERE ticket_id=?',(tid,)).fetchone()[0]<50,'Лимит 50 сообщений обращения.',status=409)

def template_origin(db,template_id):
    p=db.execute('SELECT * FROM template_provenance WHERE template_id=?',(template_id,)).fetchone()
    return dict(releaseId=p['release_id'],reviewId=p['review_id'],reviewer=p['reviewer'],reviewedAt=p['reviewed_at'],meaning='Participant review of source release, not certification of this process') if p else None

def remember_template(db,tid,pid,rid):
    rs=core_acceptance.reviews(db,pid,rid)
    if rs and rs[0]['verdict']=='accepted':
        r=rs[0];db.execute('INSERT INTO template_provenance VALUES(?,?,?,?,?)',(tid,rid,r['id'],r['actor'],r['createdAt']))
