"""Authorized operational snapshot. Counts are stored records, never product-success claims."""
from datetime import datetime,timezone
import json
from core_model import now,simulation,economics,metrics
import core_learning
import core_acceptance
import core_delivery
import core_readiness


def overview(store,db,actor):
    rows=db.execute("SELECT p.*,CASE WHEN p.owner_id=? THEN 'owner' ELSE m.role END AS role FROM projects p LEFT JOIN effective_project_members m ON m.project_id=p.id AND m.user_id=? WHERE p.owner_id=? OR m.user_id=? ORDER BY p.updated_at DESC,p.id LIMIT 201",(actor,actor,actor,actor)).fetchall()
    truncated=len(rows)>200;projects=[];currencies={}
    for row in rows[:200]:
        d=json.loads(row['data']);pid=row['id'];checks=simulation(d);money=economics(d);jobs={s:0 for s in ('queued','running','completed','failed')};learning=None;delivery=None;latest=None;client_counts=None
        readiness=core_readiness.evaluate(db,pid,row['version'],d) if d['consents']['studio'] else None
        if readiness:checks=readiness['checks']
        artifact_problem=bool(readiness and any(item.startswith('asset_') for item in readiness['blockers']))
        if d['consents']['studio']:
            for j in db.execute('SELECT status,COUNT(*) AS n FROM jobs WHERE project_id=? GROUP BY status',(pid,)):jobs[j['status']]=j['n']
            if d['releases']:
                r=d['releases'][-1];rs=core_acceptance.reviews(db,pid,r['id']);latest=dict(id=r['id'],sourceVersion=r.get('sourceVersion'),reviewCount=len(rs),verdict=rs[0]['verdict'] if rs else None)
                source=db.execute('SELECT data FROM revisions WHERE project_id=? AND version=?',(pid,r.get('sourceVersion'))).fetchone();snapshot=json.loads(source['data']) if source else {}
                latest['matchesCurrentArtifactAndScope']=all(snapshot.get(k)==d.get(k) for k in ('title','goal','audience','acceptance','tasks','artifact'))
        if d['consents']['learning']:
            completed=set()
            for a in db.execute('SELECT slug,curriculum_hash,passed FROM lesson_activities WHERE project_id=? AND actor_id=?',(pid,actor)):
                lesson=core_learning.LESSONS.get(a['slug'])
                if lesson and a['passed'] and lesson['hash']==a['curriculum_hash']:completed.add(a['slug'])
            learning=dict(myCurrentPractices=len(completed),curriculumSize=len(core_learning.LESSONS))
        if d['consents']['business']:
            visible=core_delivery.read(store,db,pid,actor)
            delivery=dict(handoffs=len(visible['handoffs']),pendingReceipts=sum(h['status']=='pending' and h['recipientId']==actor for h in visible['handoffs']),openTickets=sum(t['status'] in ('open','active') for t in visible['tickets']),resolvedTickets=sum(t['status']=='resolved' for t in visible['tickets']))
            if row['role'] in ('owner','editor'):
                client_rows=list(db.execute("SELECT status,support_status FROM client_deliveries WHERE project_id=? AND status!='revoked'",(pid,)))
                client_counts=dict(active=len(client_rows),pendingReceipts=sum(c['status']=='pending' for c in client_rows),openSupport=sum(c['support_status'] in ('open','active') for c in client_rows))
            totals=currencies.setdefault(d['currency'],dict(costMinor=0,budgetMinor=0,contributionMinor=0,confirmedRevenueMinor=0,projects=0));totals['costMinor']+=money['costMinor'];totals['budgetMinor']+=d['budgetMinor'];totals['contributionMinor']+=money['contributionMinor'];totals['projects']+=1
        expired=sum(bool(s['expiresAt']) and datetime.fromisoformat(s['expiresAt'])<datetime.now(timezone.utc) for s in d['sources'])
        issues=[]
        if expired:issues.append('expired_sources')
        if d['consents']['business'] and money['budgetRemainingMinor']<0:issues.append('over_budget')
        if jobs['failed']:issues.append('failed_checks')
        if artifact_problem:issues.append('artifact_rebuild')
        if latest and not latest['matchesCurrentArtifactAndScope']:issues.append('unreleased_changes')
        if latest and latest['verdict']=='needs_changes':issues.append('release_changes')
        if delivery and delivery['pendingReceipts']:issues.append('receipt_waiting')
        if delivery and delivery['openTickets']:issues.append('open_support')
        if delivery and delivery['resolvedTickets']:issues.append('solution_waiting')
        if client_counts and client_counts['openSupport']:issues.append('client_support')
        if row['role']=='viewer':stage,label='history','Посмотреть проект'
        elif not d['accepted']:stage,label='contract','Уточнить и принять контракт'
        elif expired:stage,label='memory','Проверить устаревшие источники'
        elif d['consents']['business'] and money['budgetRemainingMinor']<0:stage,label='business','Проверить бюджет и расходы'
        elif artifact_problem:stage,label='studio','Пересобрать HTML по текущей цели'
        elif learning and learning['myCurrentPractices']<learning['curriculumSize']:stage,label='campus','Продолжить личную практику'
        elif d['consents']['studio'] and not (d['artifact']['url'] or d['artifact'].get('assetId')):stage,label='studio','Создать артефакт'
        elif d['consents']['studio'] and not latest:stage,label='studio','Проверить и зафиксировать выпуск'
        elif latest and not latest['matchesCurrentArtifactAndScope']:stage,label='studio','Зафиксировать изменённый результат'
        elif latest and latest['verdict'] is None:stage,label='acceptance','Организовать разбор выпуска'
        elif latest and latest['verdict']=='needs_changes':stage,label='studio','Доработать замечания'
        elif client_counts and (client_counts['pendingReceipts'] or client_counts['openSupport']):stage,label='clients','Открыть кабинет получателя'
        elif delivery and (not delivery['handoffs'] and not (client_counts and client_counts['active']) or delivery['openTickets'] or delivery['pendingReceipts'] or delivery['resolvedTickets']):stage,label='delivery','Открыть передачу и поддержку'
        elif not d['measurements']:stage,label='results','Записать исходное наблюдение'
        else:stage,label='history','Открыть историю и материалы'
        # A viewer's own receipt/support is actionable without permission to alter the project.
        if row['role']=='viewer' and delivery and (delivery['pendingReceipts'] or delivery['openTickets'] or delivery['resolvedTickets']):stage,label='delivery','Открыть получение и поддержку'
        projects.append(dict(id=pid,title=d['title'],version=row['version'],role=row['role'],updatedAt=row['updated_at'],consents=d['consents'],checks=dict(passed=sum(c['passed'] for c in checks),total=len(checks),meaning='Saved contract conditions and local HTML integrity/input checks; criteria remain manually declared'),expiredSourceCount=expired,jobs=jobs,learning=learning,latestRelease=latest,delivery=delivery,clientDeliveryCounts=client_counts,economics=dict(currency=d['currency'],**money) if d['consents']['business'] else None,measurements=metrics(d),issues=issues,nextAction=dict(stage=stage,label=label)))
    aggregate={s:sum(p['jobs'][s] for p in projects) for s in ('queued','running','completed','failed')}
    return dict(format='osgard-core-overview-v1',generatedAt=now(),projects=projects,counts=dict(projects=len(projects),attentionProjects=sum(bool(p['issues']) for p in projects),ownPracticeRecordsCompleted=sum(p['learning']['myCurrentPractices'] for p in projects if p['learning']),measurementRecords=sum(p['measurements']['sampleSize'] for p in projects)),jobs=aggregate,currencies=currencies,truncated=truncated,scope='At most 200 currently accessible projects; module consent and support visibility applied',limits=dict(independentCertification=False,fieldCoreWebVitals=False,actualPilotConfirmed=False,externalURLsChecked=False,payments=False,measurementSource='user_reported_observations',currencyTotals='Only visible projects with Business consent; do not add different currencies'))
