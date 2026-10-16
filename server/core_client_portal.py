"""Explicitly shared release envelopes, separate from project membership. No payments or email."""
import hashlib
import json
from core_model import require,text,now,uid
import core_acceptance
from core_delivery import identifier

SCHEMA='''
CREATE TABLE IF NOT EXISTS client_deliveries(id TEXT PRIMARY KEY,project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,release_id TEXT NOT NULL,recipient_id TEXT NOT NULL REFERENCES users(id),creator_id TEXT NOT NULL REFERENCES users(id),version INTEGER NOT NULL,envelope TEXT NOT NULL,status TEXT NOT NULL CHECK(status IN ('pending','acknowledged','revoked')),support_status TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS client_delivery_log(id TEXT PRIMARY KEY,delivery_id TEXT NOT NULL REFERENCES client_deliveries(id) ON DELETE CASCADE,actor_id TEXT NOT NULL REFERENCES users(id),kind TEXT NOT NULL,body TEXT NOT NULL,from_status TEXT NOT NULL,to_status TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS client_delivery_recipient ON client_deliveries(recipient_id,status);
'''

def access(store,db,did,actor,export=False):
    row=db.execute('SELECT * FROM client_deliveries WHERE id=?',(did,)).fetchone();require(row is not None,'Передача не найдена.','not_found',404)
    project=db.execute('SELECT data FROM projects WHERE id=?',(row['project_id'],)).fetchone();enabled=bool(project and json.loads(project['data'])['consents']['business'])
    if export:store.access(db,row['project_id'],actor,write=True)
    recipient=row['recipient_id']==actor and not export
    if recipient:require(row['status']!='revoked' and enabled,'Передача не найдена.','not_found',404)
    else:store.access(db,row['project_id'],actor,write=True);require(export or enabled,'Использование Business отключено в контракте.')
    return row,recipient

def summary(db,row,staff=False):
    envelope=json.loads(row['envelope'])
    result=dict(id=row['id'],title=envelope['title'],version=row['version'],status=row['status'],supportStatus=row['support_status'],createdAt=row['created_at'],updatedAt=row['updated_at'])
    if staff:result['recipient']=db.execute('SELECT username FROM users WHERE id=?',(row['recipient_id'],)).fetchone()[0]
    return result

def packet(store,db,did,actor,export=False):
    row,recipient=access(store,db,did,actor,export);result=summary(db,row,not recipient);result['role']='recipient' if recipient else 'staff';result['materials']=json.loads(row['envelope']);materials=result['materials'];materials['integrityMatches']=hashlib.sha256(materials['html'].encode()).hexdigest()==materials['sha256'] if materials['html'] is not None else None
    # No project snapshot, owner identity, internal review or project ID enters this envelope.
    result['history']=[dict(id=v['id'],actor='Вы' if v['actor_id']==actor else 'Получатель' if v['actor_id']==row['recipient_id'] else 'Команда проекта',kind=v['kind'],body=v['body'],fromStatus=v['from_status'],toStatus=v['to_status'],createdAt=v['created_at']) for v in db.execute('SELECT * FROM client_delivery_log WHERE delivery_id=? ORDER BY created_at,rowid',(did,))]
    result['limits']=dict(projectAccess=False,payments=False,externalDelivery=False,receiptMeaning='Materials received, not purchase or certification',downloadRevocation=False)
    return dict(delivery=result)

def inbox(store,db,actor):
    records=[]
    for row in db.execute("SELECT c.*,p.data AS project_data FROM client_deliveries c JOIN projects p ON p.id=c.project_id WHERE c.recipient_id=? AND c.status!='revoked' ORDER BY c.updated_at DESC,c.rowid DESC",(actor,)):
        if json.loads(row['project_data'])['consents']['business']:records.append(summary(db,row))
        if len(records)>200:break
    return dict(deliveries=records[:200],truncated=len(records)>200,scope='Only active envelopes addressed to this account; no project membership is granted')

def project_list(store,db,pid,actor,export=False):
    p=store.access(db,pid,actor,write=True);require(export or json.loads(p['data'])['consents']['business'],'Использование Business отключено в контракте.')
    rows=list(db.execute('SELECT * FROM client_deliveries WHERE project_id=? ORDER BY created_at DESC,rowid DESC',(pid,)))
    return dict(deliveries=[packet(store,db,r['id'],actor,export)['delivery'] if export else summary(db,r,True) for r in rows],projectVersion=p['version'])

def create(store,db,project,actor,payload):
    data=json.loads(project['data']);require(data['consents']['business'] and data['consents']['studio'],'Разрешите Studio и Business в контракте.')
    require(payload.get('sharingAcknowledged') is True,'Подтвердите проверку состава передаваемых материалов.')
    rid=identifier(payload.get('releaseId'));release,snapshot,_,asset=core_acceptance.release_source(db,project,rid);reviews=core_acceptance.reviews(db,project['id'],rid)
    require(reviews and reviews[0]['verdict']=='accepted','Нужен последний положительный разбор выпуска.','review_required',409)
    require(asset is None or asset['integrityMatches'],'Сохранённый HTML повреждён.','integrity_mismatch',409)
    require(asset is None or asset['inputsMatchSnapshot'],'HTML не соответствует исходным данным выпуска. Создайте и примите новый выпуск.','artifact_stale',409)
    username=text(payload.get('recipient'),64,3).lower();user=db.execute('SELECT id FROM users WHERE username=?',(username,)).fetchone();require(user is not None,'Аккаунт получателя не найден.','not_found',404);require(user['id']!=actor,'Выберите другой аккаунт.')
    require(db.execute('SELECT COUNT(*) FROM client_deliveries WHERE project_id=?',(project['id'],)).fetchone()[0]<100,'Лимит 100 изолированных передач.',status=409)
    require(db.execute("SELECT 1 FROM client_deliveries WHERE project_id=? AND release_id=? AND recipient_id=? AND status!='revoked'",(project['id'],rid,user['id'])).fetchone() is None,'Этот выпуск уже передан аккаунту.','delivery_exists',409)
    envelope=dict(title=text(payload.get('title'),160,3),description=text(payload.get('description'),4000,20),instructions=text(payload.get('instructions'),4000,20),sourceVersion=release['sourceVersion'],html=asset['html'] if asset else None,sha256=asset['sha256'] if asset else snapshot['artifact']['checksum'],url=snapshot['artifact']['url'] if not asset else '',externalURLVerified=False)
    did=uid();stamp=now();db.execute('INSERT INTO client_deliveries VALUES(?,?,?,?,?,?,?,?,?,?,?)',(did,project['id'],rid,user['id'],actor,1,json.dumps(envelope,ensure_ascii=False),'pending','none',stamp,stamp));store.event(db,project['id'],actor,'client_delivery_created',dict(deliveryId=did,releaseId=rid,recipientId=user['id'],reviewId=reviews[0]['id']))
    updated=store.save(db,project,actor,data,'client_delivery_version',dict(deliveryId=did))
    return dict(project=updated,deliveryId=did)

def mutate(store,db,did,actor,payload):
    row,recipient=access(store,db,did,actor);require(type(payload.get('expectedVersion')) is int and payload['expectedVersion']==row['version'],'Передача изменена. Обновите её перед отправкой.','version_conflict',409)
    kind=payload.get('action');status=row['status'];support=row['support_status'];body='';before='';after=''
    require(status!='revoked','Передача отозвана.','revoked',409)
    require(db.execute('SELECT COUNT(*) FROM client_delivery_log WHERE delivery_id=?',(did,)).fetchone()[0]<100,'Лимит 100 записей истории.',status=409)
    if kind=='acknowledge':require(recipient,'Подтверждает только получатель.','forbidden',403);require(status=='pending','Получение уже подтверждено.','delivery_state',409);status='acknowledged';before=row['status'];after=status
    elif kind=='revoke':require(not recipient,'Отзывает только редактор проекта.','forbidden',403);status='revoked';before=row['status'];after=status;body=text(payload.get('body'),2000,10)
    elif kind=='message':
        require(support!='closed','Сначала откройте обсуждение снова.','support_state',409);require(db.execute("SELECT COUNT(*) FROM client_delivery_log WHERE delivery_id=? AND kind='message'",(did,)).fetchone()[0]<50,'Лимит 50 сообщений.',status=409);body=text(payload.get('body'),4000,10)
        if support=='none':before='none';support='open';after=support
    elif kind=='support_status':
        target=payload.get('status');allowed={'none':set(),'open':{'active','resolved'},'active':{'resolved'},'resolved':{'closed','open'},'closed':{'open'}}
        require(isinstance(target,str) and target in allowed[support],'Этот переход недоступен.','support_state',409);require(not recipient or target in ('open','closed'),'Отметить решение может команда проекта.','forbidden',403);body=text(payload.get('body'),2000,10);before=support;support=target;after=support
    else:require(False,'Неизвестное действие кабинета.')
    stamp=now();db.execute('INSERT INTO client_delivery_log VALUES(?,?,?,?,?,?,?,?)',(uid(),did,actor,kind,body,before,after,stamp));db.execute('UPDATE client_deliveries SET version=version+1,status=?,support_status=?,updated_at=? WHERE id=?',(status,support,stamp,did));store.event(db,row['project_id'],actor,'client_delivery_'+kind,dict(deliveryId=did))
    # No project response is returned to a nonmember recipient.
    return dict(deliveryId=did,version=row['version']+1,status=status,supportStatus=support)
