import { coreRequest, CoreError, readPending, storePending } from './coreClient';
export type ReviewAssignment = {
    reviewerId: string;
    reviewer: string;
    deadline: string;
    note: string;
    status: 'open' | 'done' | 'withdrawn';
    updatedAt: string;
    hasAccess: boolean;
    overdue: boolean;
};
export type ReviewQueueItem = {
    submissionId: string;
    projectId: string;
    projectTitle: string;
    projectVersion: number;
    ownerId: string;
    role: string;
    authorId: string;
    author: string;
    sourceVersion: number;
    createdAt: string;
    isLatest: boolean;
    reviewCount: number;
    latestVerdict: 'pending' | 'needs_changes' | 'reviewed';
    latestReviewer: string | null;
    latestScore: number | null;
    assignment: ReviewAssignment | null;
    canReview: boolean;
};
export type PilotReport = {
    schemaVersion: 1;
    generatedAt: string;
    projectId: string;
    title: string;
    version: number;
    role: string;
    ownerId: string;
    pilot: {
        name: string;
        audience: string;
        hypothesis: string;
        status: string;
        notes: string;
    };
    participants: {
        id: string;
        username: string;
        role: string;
        currentPracticeCount: number;
    }[];
    counts: {
        accountsWithAccess: number;
        accountsWithPractice: number;
        accountsWithEightCurrentPractices: number;
        practiceAttempts: number;
        submissions: number;
        latestSubmittedAuthors: number;
        pendingLatestReviews: number;
        latestNeedChanges: number;
        latestReviewedByParticipant: number;
        sessionPlanned: number;
        sessionCompletedMarks: number;
        sessionCancelled: number;
        attendanceSelfReports: number;
    };
    measurements: {
        sampleSize: number;
        baselineSeconds: number;
        assistedTotalSeconds: number;
        speedRatio: number | null;
        successRate: number | null;
    };
    warnings: string[];
    limits: {
        skillIndependentlyVerified: boolean;
        attendanceIndependentlyVerified: boolean;
        realPilotConfirmed: boolean;
        measurementSource: string;
        reviewMeaning: string;
    };
    queue?: ReviewQueueItem[];
};
export type PilotOverview = {
    generatedAt: string;
    projects: PilotReport[];
    queue: ReviewQueueItem[];
    myAssignments: ReviewQueueItem[];
    scope: string;
    limits: {
        realPilotConfirmed: boolean;
        skillIndependentlyVerified: boolean;
    };
};
export async function pilotMutation(userId: string, route: string, body: Record<string, unknown>, retry = false) {
    const old = readPending();
    if (old && !retry)
        throw new Error('Есть незавершённый запрос. Сначала проверьте или повторите его.');
    if (retry && (!old || old.userId !== userId))
        throw new Error('Запрос относится к другому аккаунту.');
    const operation = retry ? old! : { userId, route, key: crypto.randomUUID(), body };
    storePending(operation);
    try {
        const result = await coreRequest<{
            replayed?: boolean;
        }>(operation.route, operation.body, operation.key);
        storePending(null);
        return result;
    }
    catch (e) {
        if (e instanceof CoreError && e.status >= 400 && e.status < 500)
            storePending(null);
        throw e;
    }
}
function csvCell(value: unknown) { let s = String(value ?? ''); if (/^[\s]*[=+\-@]/u.test(s) || /^[\t\r\n]/.test(s))
    s = "'" + s; return '"' + s.replaceAll('"', '""') + '"'; }
export function pilotReportCSV(report: PilotReport) {
    const rows: unknown[][] = [['Показатель', 'Значение', 'Контекст'], ['Проект', report.title, report.projectId], ['Версия', report.version, report.generatedAt], ['Аудитория', report.pilot.audience, 'Задана владельцем'], ['Аккаунтов с доступом', report.counts.accountsWithAccess, 'Не число реально обученных людей'], ['Аккаунтов с практикой', report.counts.accountsWithPractice, 'Только текущие участники с сохранёнными записями'], ['Аккаунтов с 8 актуальными практиками', report.counts.accountsWithEightCurrentPractices, 'Самопроверка, не подтверждение навыка'], ['Сданных версий', report.counts.submissions, 'Исторические версии, не уникальные ученики'], ['Авторов с актуальной сдачей', report.counts.latestSubmittedAuthors, 'Одна последняя сдача на автора'], ['Ожидают первого разбора', report.counts.pendingLatestReviews, 'Последние сдачи авторов'], ['Последние сдачи с замечаниями', report.counts.latestNeedChanges, 'Оценка участника'], ['Критерии отмечены участником', report.counts.latestReviewedByParticipant, 'Не сертификат'], ['Отметок о проведении занятий', report.counts.sessionCompletedMarks, 'Ручная отметка организатора'], ['Самоотчётов посещения', report.counts.attendanceSelfReports, 'Не независимая проверка присутствия'], ['Сопоставимых наблюдений', report.measurements.sampleSize, 'Данные вводит пользователь'], ['Отношение времени', report.measurements.speedRatio ?? 'Нет данных', 'Включая исправления и помощь человека'], ['Доля выполненных задач', report.measurements.successRate ?? 'Нет данных', 'Выборка пользователя, не общая успешность продукта'], ['Независимо подтверждённый навык', false, 'Испытания ещё нужны']];
    for (const p of report.participants)
        rows.push(['Участник', p.username, p.role + '; актуальных практик: ' + p.currentPracticeCount]);
    for (const w of report.warnings)
        rows.push(['Пробел в данных', w, '']);
    return '\uFEFF' + rows.map(row => row.map(csvCell).join(',')).join('\r\n') + '\r\n';
}
export function downloadPilotCSV(report: PilotReport) { const url = URL.createObjectURL(new Blob([pilotReportCSV(report)], { type: 'text/csv;charset=utf-8' })), a = document.createElement('a'); a.href = url; a.download = 'osgard-pilot-' + report.projectId + '-v' + report.version + '.csv'; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); }
export function campusProjectLink(projectId: string, panel: 'final' | 'pilot' | 'path' = 'final', submissionId?: string, review = false) { if (!['final', 'pilot', 'path'].includes(panel))
    throw new Error('Неизвестный раздел.'); if (submissionId && !/^[a-f0-9]{32}$/.test(submissionId))
    throw new Error('Неверная сдача.'); if (!/^[a-f0-9]{32}$/.test(projectId))
    throw new Error('Неверный идентификатор проекта.'); return '/learning/campus?project=' + projectId + '&panel=' + panel + (submissionId ? '&submission=' + submissionId : '') + (review ? '&intent=review' : ''); }
export function filterPilotQueue(queue: ReviewQueueItem[], filter: 'pending' | 'mine' | 'changes' | 'all', query: string, actorId: string | undefined) {
    const search = query.trim().toLocaleLowerCase('ru');
    return queue.filter(item => {
        if (!(item.projectTitle + ' ' + item.author + ' ' + (item.assignment?.reviewer || '')).toLocaleLowerCase('ru').includes(search))
            return false;
        return filter === 'all' || filter === 'mine' && !!actorId && item.assignment?.reviewerId === actorId && item.assignment.status === 'open' || filter === 'changes' && item.isLatest && item.latestVerdict === 'needs_changes' || filter === 'pending' && (item.isLatest && item.latestVerdict === 'pending' || item.assignment?.status === 'open');
    });
}
