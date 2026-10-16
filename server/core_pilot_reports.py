"""Read-only pilot summaries derived from authorized project records, never revenue or claims of skill."""
from datetime import datetime,timezone
import json
from core_model import metrics, now, require
import core_learning

SCHEMA='''
CREATE TABLE IF NOT EXISTS review_assignments(submission_id TEXT PRIMARY KEY REFERENCES submissions(id) ON DELETE CASCADE,project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,reviewer_id TEXT NOT NULL REFERENCES users(id),assigned_by TEXT NOT NULL,deadline TEXT NOT NULL,note TEXT NOT NULL,status TEXT NOT NULL CHECK(status IN ('open','done','withdrawn')),updated_at TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS review_assignment_reviewer ON review_assignments(reviewer_id,status);
'''

def participants(db,row):
    people=[dict(id=row['owner_id'],username=db.execute('SELECT username FROM users WHERE id=?',(row['owner_id'],)).fetchone()[0],role='owner')]
    people += [dict(v) for v in db.execute('SELECT u.id,u.username,m.role FROM effective_project_members m JOIN users u ON u.id=m.user_id WHERE m.project_id=? AND m.user_id!=(SELECT owner_id FROM projects WHERE id=m.project_id)',(row['id'],))]
    return people

def assignment(db,pid,sid,people):
    row=db.execute('SELECT a.*,u.username FROM review_assignments a JOIN users u ON u.id=a.reviewer_id WHERE project_id=? AND submission_id=?',(pid,sid)).fetchone()
    if row is None:return None
    access=any(p['id']==row['reviewer_id'] and p['role'] in ('owner','editor') for p in people)
    overdue=row['status']=='open' and bool(row['deadline']) and datetime.fromisoformat(row['deadline'])<datetime.now(timezone.utc)
    return dict(reviewerId=row['reviewer_id'],reviewer=row['username'],deadline=row['deadline'],note=row['note'],status=row['status'],updatedAt=row['updated_at'],hasAccess=access,overdue=overdue)

def project_report(store,db,pid,actor):
    row=store.access(db,pid,actor);data=json.loads(row['data']);require(data['consents']['learning'],'Использование Learning отключено в контракте.')
    people=participants(db,row);active={p['id'] for p in people}
    # Never read exercise bodies into the overview. Personal text stays in project detail/export.
    activities=list(db.execute('SELECT actor_id,slug,curriculum_hash,passed FROM lesson_activities WHERE project_id=?',(pid,)))
    counts={p['id']:set() for p in people}
    for v in activities:
        lesson=core_learning.LESSONS.get(v['slug'])
        if v['actor_id'] in counts and v['passed'] and lesson and lesson['hash']==v['curriculum_hash']:counts[v['actor_id']].add(v['slug'])
    submissions=list(db.execute('SELECT s.*,u.username FROM submissions s JOIN users u ON u.id=s.actor_id WHERE project_id=? ORDER BY s.created_at DESC,s.rowid DESC',(pid,)))
    latest_by_author={}
    queue=[]
    for s in submissions:
        latest=s['actor_id'] not in latest_by_author
        if latest:latest_by_author[s['actor_id']]=s['id']
        reviews=list(db.execute('SELECT r.*,u.username FROM reviews r JOIN users u ON u.id=r.actor_id WHERE submission_id=? AND project_id=? ORDER BY r.created_at DESC,r.rowid DESC',(s['id'],pid)))
        review=reviews[0] if reviews else None;assigned=assignment(db,pid,s['id'],people)
        can_review=row['role'] in ('owner','editor') and s['actor_id']!=actor and (not assigned or assigned['status']=='withdrawn' or assigned['reviewerId']==actor)
        queue.append(dict(submissionId=s['id'],projectId=pid,projectTitle=data['title'],projectVersion=row['version'],ownerId=row['owner_id'],role=row['role'],authorId=s['actor_id'],author=s['username'],sourceVersion=s['source_version'],createdAt=s['created_at'],isLatest=latest,reviewCount=len(reviews),latestVerdict=review['verdict'] if review else 'pending',latestReviewer=review['username'] if review else None,latestScore=sum(v['score'] for v in json.loads(review['scores'])) if review else None,assignment=assigned,canReview=can_review))
    latest=[v for v in queue if v['isLatest']]
    sessions=list(db.execute('SELECT * FROM pilot_sessions WHERE project_id=? ORDER BY starts_at,id',(pid,)))
    attendance=list(db.execute('SELECT a.actor_id,a.session_id FROM pilot_attendance a JOIN pilot_sessions s ON s.id=a.session_id WHERE s.project_id=?',(pid,)))
    profile=db.execute('SELECT data FROM pilot_profiles WHERE project_id=?',(pid,)).fetchone()
    pilot=json.loads(profile['data']) if profile else dict(name='',audience='',hypothesis='',status='draft',notes='')
    observations=metrics(data)
    warnings=[]
    if not activities:warnings.append('Нет сохранённых учебных практик.')
    if not submissions:warnings.append('Нет сданных итоговых работ.')
    if observations['sampleSize']==0:warnings.append('Нет сопоставимых наблюдений времени и качества.')
    if not pilot.get('audience'):warnings.append('Аудитория пилота не определена.')
    if not any(v['role']=='editor' for v in people):warnings.append('Нет другого участника-редактора для разбора работы владельца.')
    if any(v['assignment'] and v['assignment']['status']=='open' and not v['assignment']['hasAccess'] for v in queue):warnings.append('Один из назначенных проверяющих больше не имеет права редактирования.')
    return dict(schemaVersion=1,generatedAt=now(),projectId=pid,title=data['title'],version=row['version'],role=row['role'],ownerId=row['owner_id'],pilot=pilot,participants=[dict(**p,currentPracticeCount=len(counts[p['id']])) for p in people],counts=dict(accountsWithAccess=len(people),accountsWithPractice=len({a['actor_id'] for a in activities if a['actor_id'] in active}),accountsWithEightCurrentPractices=sum(len(v)==len(core_learning.LESSONS) for v in counts.values()),practiceAttempts=len(activities),submissions=len(submissions),latestSubmittedAuthors=len(latest),pendingLatestReviews=sum(v['latestVerdict']=='pending' for v in latest),latestNeedChanges=sum(v['latestVerdict']=='needs_changes' for v in latest),latestReviewedByParticipant=sum(v['latestVerdict']=='reviewed' for v in latest),sessionPlanned=sum(s['status']=='planned' for s in sessions),sessionCompletedMarks=sum(s['status']=='completed' for s in sessions),sessionCancelled=sum(s['status']=='cancelled' for s in sessions),attendanceSelfReports=len(attendance)),queue=queue,measurements=observations,warnings=warnings,limits=dict(skillIndependentlyVerified=False,attendanceIndependentlyVerified=False,realPilotConfirmed=False,measurementSource='user_reported',reviewMeaning='latest participant rubric for each submitted version, not certification'))

def overview(store,db,actor):
    rows=db.execute("SELECT p.*,CASE WHEN p.owner_id=? THEN 'owner' ELSE m.role END AS role FROM projects p LEFT JOIN effective_project_members m ON m.project_id=p.id AND m.user_id=? WHERE p.owner_id=? OR m.user_id=? ORDER BY p.updated_at DESC,p.id LIMIT 200",(actor,actor,actor,actor)).fetchall()
    reports=[]
    for row in rows:
        if json.loads(row['data'])['consents']['learning']:reports.append(project_report(store,db,row['id'],actor))
    queue=[item for r in reports for item in r['queue']]
    tasks=[v for v in queue if v['assignment'] and v['assignment']['reviewerId']==actor and v['assignment']['status']=='open']
    return dict(generatedAt=now(),projects=[{k:v for k,v in r.items() if k!='queue'} for r in reports],queue=queue,myAssignments=tasks,scope='Projects with current access and Learning consent, at most 200',limits=dict(realPilotConfirmed=False,skillIndependentlyVerified=False))
