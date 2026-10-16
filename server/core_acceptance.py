"""Participant acceptance of an immutable Studio release. Never certifies or fetches URLs."""
import hashlib
import json
import core_readiness
from core_model import require, text, now, uid

SCHEMA='''
CREATE TABLE IF NOT EXISTS release_reviews(id TEXT PRIMARY KEY,project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,release_id TEXT NOT NULL,source_version INTEGER NOT NULL,actor_id TEXT NOT NULL REFERENCES users(id),verdict TEXT NOT NULL CHECK(verdict IN ('accepted','needs_changes')),criteria TEXT NOT NULL,note TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS release_reviews_project ON release_reviews(project_id,release_id,created_at);
'''

def reviews(db,pid,rid=None):
    sql='SELECT r.*,u.username FROM release_reviews r JOIN users u ON u.id=r.actor_id WHERE project_id=?';args=[pid]
    if rid is not None:sql+=' AND release_id=?';args.append(rid)
    return [dict(id=r['id'],releaseId=r['release_id'],sourceVersion=r['source_version'],actorId=r['actor_id'],actor=r['username'],verdict=r['verdict'],criteria=json.loads(r['criteria']),note=r['note'],createdAt=r['created_at']) for r in db.execute(sql+' ORDER BY r.created_at DESC,r.rowid DESC',args)]

def release_source(db,row,rid):
    data=json.loads(row['data']);release=next((r for r in data['releases'] if r['id']==rid),None)
    require(release is not None,'Выпуск не найден.','not_found',404)
    version=release.get('sourceVersion');require(type(version) is int,'У старого выпуска нет зафиксированной версии. Создайте новый выпуск.','legacy_release',409)
    source=db.execute('SELECT data FROM revisions WHERE project_id=? AND version=?',(row['id'],version)).fetchone()
    created=db.execute('SELECT actor_id,data FROM revisions WHERE project_id=? AND version=?',(row['id'],version+1)).fetchone()
    require(source is not None and created is not None and any(r['id']==rid for r in json.loads(created['data'])['releases']),'Снимок выпуска недоступен.','release_snapshot',409)
    snapshot=json.loads(source['data'])
    artifact=snapshot['artifact'];asset=None
    if artifact.get('assetId'):
        a=db.execute('SELECT * FROM assets WHERE project_id=? AND id=?',(row['id'],artifact['assetId'])).fetchone()
        require(a is not None,'Файл выпуска недоступен.','release_asset',409)
        actual=hashlib.sha256(a['content'].encode()).hexdigest()
        evidence,_=core_readiness.artifact_evidence(db,row['id'],snapshot)
        asset=dict(id=a['id'],html=a['content'],sha256=a['sha256'],sourceVersion=a['source_version'],integrityMatches=actual==a['sha256']==artifact['checksum'],inputsMatchSnapshot=evidence['inputsMatch'],sourceSnapshotAvailable=evidence['sourceSnapshotAvailable'])
    return release,snapshot,created['actor_id'],asset

def read(store,db,pid,actor,rid=None):
    row=store.access(db,pid,actor);data=json.loads(row['data']);require(data['consents']['studio'],'Использование Studio отключено в контракте.')
    if rid:
        release,snapshot,author,asset=release_source(db,row,rid)
        return dict(format='osgard-studio-release-v1',projectId=pid,projectVersion=row['version'],release=release,sourceVersion=release['sourceVersion'],releaseActorId=author,snapshot=snapshot,asset=asset,reviews=reviews(db,pid,rid),limits=dict(participantReviewOnly=True,externalURLVerified=False,independentCertification=False,appliesTo='Only this immutable source version'))
    items=[]
    for release in reversed(data['releases']):
        version=release.get('sourceVersion');created=db.execute('SELECT actor_id FROM revisions WHERE project_id=? AND version=?',(pid,version+1)).fetchone() if type(version) is int else None
        rs=reviews(db,pid,release['id'])
        items.append(dict(id=release['id'],at=release['at'],sourceVersion=version,releaseActorId=created['actor_id'] if created else None,reviewCount=len(rs),latestReview=rs[0] if rs else None,canReview=row['role'] in ('owner','editor') and created is not None and created['actor_id']!=actor))
    return dict(projectVersion=row['version'],releases=items,limits=dict(participantReviewOnly=True,independentCertification=False))

def mutate(store,db,row,actor,payload):
    data=json.loads(row['data']);require(data['consents']['studio'],'Использование Studio отключено в контракте.')
    rid=text(payload.get('releaseId'),32,32);release,snapshot,author,asset=release_source(db,row,rid)
    require(author!=actor,'Автор выпуска не может принять собственный выпуск. Нужен другой участник с правом редактирования.','self_review',403)
    require(db.execute('SELECT COUNT(*) FROM release_reviews WHERE project_id=?',(row['id'],)).fetchone()[0]<300,'Лимит 300 разборов выпуска.',status=409)
    entries=payload.get('criteria');criteria=snapshot['acceptance'];require(isinstance(entries,list) and len(entries)==len(criteria) and len(criteria)>0,'Нужна проверка каждого критерия версии выпуска.')
    expected={c['id'] for c in criteria};seen=set();validated=[]
    for item in entries:
        require(isinstance(item,dict) and isinstance(item.get('id'),str) and item.get('id') in expected and item['id'] not in seen,'Критерии не совпадают с версией выпуска.')
        seen.add(item['id']);require(type(item.get('passed')) is bool,'Выберите результат каждого критерия.')
        validated.append(dict(id=item['id'],passed=item['passed'],evidence=text(item.get('evidence'),2000,20)))
    note=text(payload.get('note'),4000,20);verdict='accepted' if all(v['passed'] for v in validated) else 'needs_changes'
    require(verdict!='accepted' or asset is None or asset['integrityMatches'],'Содержимое файла не совпадает с SHA-256 выпуска. Приёмка заблокирована.','integrity_mismatch',409)
    require(verdict!='accepted' or asset is None or asset['inputsMatchSnapshot'],'HTML собран из другой цели, аудитории, задач или критериев. Создайте новый прототип и выпуск.','artifact_stale',409)
    review_id=uid();db.execute('INSERT INTO release_reviews VALUES(?,?,?,?,?,?,?,?,?)',(review_id,row['id'],rid,release['sourceVersion'],actor,verdict,json.dumps(validated,ensure_ascii=False),note,now()))
    project=store.save(db,row,actor,data,'release_reviewed',dict(reviewId=review_id,releaseId=rid,sourceVersion=release['sourceVersion'],verdict=verdict))
    return dict(project=project,reviewId=review_id,verdict=verdict)
