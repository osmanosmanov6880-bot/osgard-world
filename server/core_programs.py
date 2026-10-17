"""Versioned, one-time OSA practice enrollment. Free Learning remains independent.

Payment state is read from Commerce's authoritative transaction, never copied
into an independently mutable enrollment flag. Learner work is exportable after
a refund, while all paid practice operations recheck entitlement and consent.
"""
import copy
import hashlib
import json

import core_learning
from core_model import require, text, initial, now, uid

PROGRAM_ID = 'osa-practical-ai'
POLICY_VERSION = 'osa-private-practice-v1'
TITLE = 'OSA — ИИ для полезного проекта'
SCOPE = 'Разовая версия программы: восемь практик, отдельный личный проект, история попыток и сохранённая итоговая работа. Лекции открыты бесплатно. Наставник, сертификат и размещение сервиса не включены.'
WORK_FIELDS = ('result', 'verification', 'newTask', 'transferResult')
SCHEMA = '''
CREATE TABLE IF NOT EXISTS program_enrollments(
 order_id TEXT PRIMARY KEY REFERENCES commerce_orders(id),
 project_id TEXT NOT NULL UNIQUE REFERENCES projects(id),buyer_id TEXT NOT NULL REFERENCES users(id),
 program_id TEXT NOT NULL,program_version TEXT NOT NULL,version INTEGER NOT NULL DEFAULT 1,
 work TEXT NOT NULL,activated_at TEXT NOT NULL,updated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS program_activities(
 id TEXT PRIMARY KEY,order_id TEXT NOT NULL REFERENCES program_enrollments(order_id),
 slug TEXT NOT NULL,lesson_hash TEXT NOT NULL,answer INTEGER NOT NULL,practice TEXT NOT NULL,
 passed INTEGER NOT NULL,locale TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS program_submissions(
 id TEXT PRIMARY KEY,order_id TEXT NOT NULL REFERENCES program_enrollments(order_id),
 source_version INTEGER NOT NULL,snapshot TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS program_buyer ON program_enrollments(buyer_id);
CREATE INDEX IF NOT EXISTS program_activity_order ON program_activities(order_id,created_at);
'''


def encoded(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False)


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def current_program():
    snapshot = dict(format='osgard-practice-program-v1', programId=PROGRAM_ID,
                    policyVersion=POLICY_VERSION, title=TITLE, scope=SCOPE,
                    mentorIncluded=False, curriculum=copy.deepcopy(core_learning.CURRICULUM))
    snapshot['version'] = digest(encoded(snapshot))
    return snapshot


def program_header(snapshot):
    return {key: snapshot[key] for key in ('programId', 'policyVersion', 'version', 'title', 'scope', 'mentorIncluded')} | {
        'lessonCount': len(snapshot['curriculum']['lessons']),
        'freeModule': '/learning/program',
    }


def catalog(store, actor):
    return dict(program=program_header(current_program()), configuration=store.commerce.config_view(actor))


def offer(payload):
    snapshot = current_program()
    require(payload.get('programId') == snapshot['programId'] and payload.get('programVersion') == snapshot['version']
            and payload.get('policyVersion') == POLICY_VERSION,
            'Версия программы или условий изменилась. Загрузите программу и подтвердите предложение заново.',
            'program_version_conflict', 409)
    return dict(kind='learning_program', title=TITLE, description=SCOPE, program=snapshot)


def program_snapshot(order):
    raw = order['envelope']
    require(digest(raw) == order['envelope_sha256'], 'Снимок оплаченной программы повреждён.', 'integrity_mismatch', 409)
    envelope = json.loads(raw)
    require(envelope.get('kind') == 'learning_program', 'Этот заказ не является учебной программой.', 'wrong_order_kind', 409)
    snapshot = envelope.get('program')
    require(isinstance(snapshot, dict) and snapshot.get('programId') == PROGRAM_ID,
            'Версия программы не поддерживается.', 'program_version', 409)
    require(snapshot.get('version') == digest(encoded({k: v for k, v in snapshot.items() if k != 'version'})),
            'Версия снимка программы не совпадает с содержимым.', 'integrity_mismatch', 409)
    return snapshot


def authorized(store, db, order_id, actor, active=False, consent=False):
    order = store.commerce.access(db, order_id, actor)
    snapshot = program_snapshot(order)
    entitlement = db.execute('SELECT active FROM commerce_entitlements WHERE order_id=? AND buyer_id=?', (order_id, actor)).fetchone()
    paid = bool(entitlement and entitlement['active'] and order['checkout_confirmed']
                and order['paid_minor'] == order['amount_minor'] and order['refunded_minor'] < order['amount_minor']
                and order['state'] != 'refunded')
    require(not active or paid, 'Оплаченный доступ к программе не выдан или отозван. Собственные работы можно экспортировать.', 'payment_required', 403)
    enrollment = db.execute('SELECT * FROM program_enrollments WHERE order_id=? AND buyer_id=?', (order_id, actor)).fetchone()
    project = None
    if enrollment:
        require(enrollment['program_version'] == snapshot['version'], 'Версия зачисления не совпадает с заказом.', 'integrity_mismatch', 409)
        project = store.access(db, enrollment['project_id'], actor, owner=True)
        require(not consent or json.loads(project['data'])['consents']['learning'],
                'Learning отключён в контракте личного проекта. Включите согласие для продолжения; экспорт своих работ доступен.', 'learning_consent_required', 403)
    return order, snapshot, enrollment, project, paid


def own_enrollment(db, order_id, actor):
    enrollment = db.execute('SELECT * FROM program_enrollments WHERE order_id=? AND buyer_id=?', (order_id, actor)).fetchone()
    require(enrollment is not None, 'Личная программа не найдена.', 'not_found', 404)
    return enrollment


def own_work(store, db, order_id, actor):
    """No payment/config/consent gate on export of the buyer's own contribution."""
    enrollment = own_enrollment(db, order_id, actor)
    project = store.access(db, enrollment['project_id'], actor, owner=True)
    activities = [dict(id=r['id'], slug=r['slug'], lessonHash=r['lesson_hash'], answer=r['answer'],
                       practice=r['practice'], passed=bool(r['passed']), locale=r['locale'], createdAt=r['created_at'])
                  for r in db.execute('SELECT * FROM program_activities WHERE order_id=? ORDER BY rowid', (order_id,))]
    submissions = [dict(id=r['id'], sourceVersion=r['source_version'], snapshot=json.loads(r['snapshot']), createdAt=r['created_at'])
                   for r in db.execute('SELECT * FROM program_submissions WHERE order_id=? ORDER BY rowid', (order_id,))]
    return dict(format='osgard-program-own-work-v1', orderId=order_id, programId=enrollment['program_id'],
                programVersion=enrollment['program_version'], version=enrollment['version'], projectId=enrollment['project_id'],
                project=store.project(project), work=json.loads(enrollment['work']), activities=activities,
                submissions=submissions, activatedAt=enrollment['activated_at'], updatedAt=enrollment['updated_at'])


def read(store, db, order_id, actor):
    order, snapshot, enrollment, project, paid = authorized(store, db, order_id, actor)
    consent = bool(project and json.loads(project['data'])['consents']['learning'])
    status = 'refunded' if order['state'] == 'refunded' else 'payment_required' if not paid else 'activation_required' if not enrollment else 'consent_required' if not consent else 'active'
    result = dict(order=store.commerce.summary(db, order), program=program_header(snapshot), status=status,
                  exportAvailable=enrollment is not None, projectId=enrollment['project_id'] if enrollment else None,
                  version=enrollment['version'] if enrollment else 0)
    if paid and consent:
        work = own_work(store, db, order_id, actor)
        lessons = snapshot['curriculum']['lessons']
        completed = [lesson['slug'] for lesson in lessons if any(item['slug'] == lesson['slug'] and item['lessonHash'] == lesson['hash'] and item['passed'] for item in work['activities'])]
        result.update(curriculum=snapshot['curriculum'], practice=work, completed=completed,
                      nextLesson=next((lesson['slug'] for lesson in lessons if lesson['slug'] not in completed), None))
    return result


def retry_guard(store, db, order_id, actor, payload):
    _, _, enrollment, _, _ = authorized(store, db, order_id, actor, active=True, consent=True)
    if payload.get('action') != 'activate':
        require(enrollment is not None, 'Сначала активируйте программу.', 'enrollment_required', 409)


def mutate(store, db, order_id, actor, payload):
    order, snapshot, enrollment, project, _ = authorized(store, db, order_id, actor, active=True, consent=True)
    kind = payload.get('action')
    if kind == 'activate':
        require(payload.get('learningConsent') is True, 'Разрешите Learning использовать контекст нового личного проекта.', 'learning_consent_required', 400)
        if enrollment:
            return dict(orderId=order_id, projectId=enrollment['project_id'], version=enrollment['version'], alreadyActivated=True)
        require(db.execute('SELECT COUNT(*) FROM projects WHERE owner_id=?', (actor,)).fetchone()[0] < 100, 'Лимит проектов аккаунта.', status=409)
        data = initial(TITLE + ' — моя работа', text(payload.get('goal'), 4000, 10))
        data['consents']['learning'] = True
        project_id = uid(); stamp = now(); raw = encoded(data)
        db.execute('INSERT INTO projects VALUES(?,?,?,?,?,?)', (project_id, actor, 1, raw, stamp, stamp))
        db.execute('INSERT INTO revisions VALUES(?,?,?,?,?)', (project_id, 1, raw, actor, stamp))
        db.execute('INSERT INTO program_enrollments VALUES(?,?,?,?,?,1,?,?,?)',
                   (order_id, project_id, actor, snapshot['programId'], snapshot['version'], encoded({field: '' for field in WORK_FIELDS}), stamp, stamp))
        store.event(db, project_id, actor, 'program_activated', dict(orderId=order_id, programId=snapshot['programId'], programVersion=snapshot['version']))
        return dict(orderId=order_id, projectId=project_id, version=1, alreadyActivated=False)
    require(enrollment is not None, 'Сначала активируйте программу.', 'enrollment_required', 409)
    require(type(payload.get('expectedVersion')) is int and payload['expectedVersion'] == enrollment['version'],
            'Практика изменена в другой вкладке. Загрузите последнюю версию.', 'version_conflict', 409)
    feedback = None
    if kind == 'activity':
        lesson = next((item for item in snapshot['curriculum']['lessons'] if item['slug'] == payload.get('slug')), None)
        require(lesson is not None, 'Урок не относится к оплаченной версии программы.')
        locale = payload.get('locale', 'ru'); require(locale in ('ru', 'en'), 'Неверный язык.')
        guide = lesson[locale]; answer = payload.get('answer')
        require(type(answer) is int and 0 <= answer < len(guide['check']['options']), 'Выберите ответ самопроверки.')
        practice = text(payload.get('practice'), 10000, 20)
        passed = answer == guide['check']['correctIndex']
        require(db.execute('SELECT COUNT(*) FROM program_activities WHERE order_id=?', (order_id,)).fetchone()[0] < 200, 'Лимит 200 попыток программы.', status=409)
        db.execute('INSERT INTO program_activities VALUES(?,?,?,?,?,?,?,?,?)', (uid(), order_id, lesson['slug'], lesson['hash'], answer, practice, int(passed), locale, now()))
        feedback = dict(passed=passed, explanation=guide['check']['explanation'], humanPracticeReview=False)
    elif kind == 'save_work':
        work = payload.get('work'); require(isinstance(work, dict) and set(work) == set(WORK_FIELDS), 'Неверные поля итоговой работы.')
        work = {field: text(work[field], 10000) for field in WORK_FIELDS}
        db.execute('UPDATE program_enrollments SET work=? WHERE order_id=?', (encoded(work), order_id))
    elif kind == 'submit':
        current = read(store, db, order_id, actor)
        require(len(current['completed']) == len(snapshot['curriculum']['lessons']), 'Сначала сохраните практики всех уроков с верной самопроверкой.', 'not_ready', 409)
        work = json.loads(enrollment['work'])
        require(all(len(work[field].strip()) >= 20 for field in WORK_FIELDS), 'Заполните результат, проверку и перенос на новую задачу.', 'not_ready', 409)
        require(db.execute('SELECT COUNT(*) FROM program_submissions WHERE order_id=?', (order_id,)).fetchone()[0] < 20, 'Лимит 20 сдач программы.', status=409)
        frozen = dict(programId=snapshot['programId'], programVersion=snapshot['version'], work=work,
                      project=store.project(project), activities=current['practice']['activities'],
                      verification='learner_submission_not_independent_assessment', mentorAssigned=False)
        db.execute('INSERT INTO program_submissions VALUES(?,?,?,?,?)', (uid(), order_id, enrollment['version'], encoded(frozen), now()))
    else:
        require(False, 'Неизвестное действие программы.')
    version = enrollment['version'] + 1
    db.execute('UPDATE program_enrollments SET version=?,updated_at=? WHERE order_id=?', (version, now(), order_id))
    store.event(db, enrollment['project_id'], actor, 'program_' + kind, dict(orderId=order_id, version=version))
    return dict(orderId=order_id, projectId=enrollment['project_id'], version=version, feedback=feedback)
