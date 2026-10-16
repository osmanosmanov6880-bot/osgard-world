import { useEffect,useRef, useState } from 'react';
import { coreRequest, CoreError, readPending, storePending } from './coreClient';
import type { CoreProject, CoreUser, PendingOperation } from './coreClient';
export type LearningData = {
    program: string;
    completed: string[];
    readiness: {
        id: string;
        label: string;
        passed: boolean;
    }[];
    activities: {
        id: string;
        slug: string;
        practice: string;
        passed: boolean;
        actor: string;
        createdAt: string;
        hash: string;
    }[];
    submissions: {
        id: string;
        actorId: string;
        actor: string;
        sourceVersion: number;
        summary: string;
        evidence: string;
        createdAt: string;
    }[];
    reviews: {
        id: string;
        submissionId: string;
        actor: string;
        actorId: string;
        scores: {
            id: string;
            score: number;
            evidence: string;
        }[];
        note: string;
        verdict: string;
        createdAt: string;
    }[];
    rubric: {
        id: string;
        title: string;
    }[];
    pilot: {
        name: string;
        audience: string;
        hypothesis: string;
        notes: string;
        status: 'draft' | 'running' | 'closed';
    };
    sessions: LearningSession[];
    attendance: {
        sessionId: string;
        actor: string;
        note: string;
        createdAt: string;
    }[];
    assignments: {
        submissionId: string;
        reviewerId: string;
        reviewer: string;
        deadline: string;
        note: string;
        status: 'open' | 'done' | 'withdrawn';
    }[];
    participants: {
        id: string;
        username: string;
        role: string;
    }[];
};
export type LearningSession = {
    id: string;
    title: string;
    startsAt: string;
    endsAt: string;
    kind: string;
    facilitator: string;
    meetingUrl: string;
    notes: string;
    status: string;
};
export type CurriculumLesson = {
    slug: string;
    hash: string;
    ru: {
        exercise: {
            title: string;
            steps: string[];
            successCriteria: string;
        };
        objectives: string[];
    };
    en: {
        exercise: {
            title: string;
        };
    };
};
export type LearningReply = {
    project: CoreProject;
    feedback: {
        passed: boolean;
        explanation: string;
    } | null;
    replayed?: boolean;
};
const CONTEXT = 'osgard:learning-project:v1';
function remember(userId: string, projectId: string) {
    try {
        sessionStorage.setItem(CONTEXT, JSON.stringify({ userId, projectId }));
    }
    catch { /* This selection lasts only on the current page. */ }
}
function previous(userId: string) {
    try {
        const p = JSON.parse(sessionStorage.getItem(CONTEXT) || 'null');
        return p?.userId === userId && typeof p.projectId === 'string' ? p.projectId : '';
    }
    catch {
        return '';
    }
}
export function useLearningProject() {
    const [user, setUser] = useState<CoreUser | null>(null), [projects, setProjects] = useState<CoreProject[]>([]), [project, setProject] = useState<CoreProject | null>(null), [data, setData] = useState<LearningData | null>(null), [phase, setPhase] = useState<'idle' | 'ready' | 'offline' | 'login'>('idle'), [busy, setBusy] = useState(false), [error, setError] = useState(''), [notice, setNotice] = useState(''), [pending, setPending] = useState<PendingOperation | null>(readPending);
    const lock = useRef(false);
    async function run<T>(work: () => Promise<T>): Promise<T | undefined> {
        if (lock.current)
            return;
        lock.current = true;
        setBusy(true);
        setError('');
        setNotice('');
        try {
            return await work();
        }
        catch (e) {
            setError(e instanceof Error ? e.message : 'Не удалось загрузить данные.');
            if (e instanceof CoreError && e.status === 401) {
                setPhase('login');
                setUser(null);
                setProjects([]);
                setProject(null);
                setData(null);
            }
            else if (e instanceof CoreError && e.code === 'server_offline')
                setPhase('offline');
            return undefined;
        }
        finally {
            lock.current = false;
            setBusy(false);
            setPending(readPending());
        }
    }
    async function load(id: string, u: CoreUser) {
        const p = await coreRequest<{
            project: CoreProject;
        }>('projects/' + id);
        setProjects(items => items.map(item => item.id === id ? p.project : item));
        if (!p.project.data.consents.learning) {
            setProject(null);
            setData(null);
            throw new Error('Использование Learning отключено. Включите его в контракте Core.');
        }
        const d = await coreRequest<LearningData>('projects/' + id + '/learning');
        setProject(p.project);
        setData(d);
        remember(u.id, id);
        return p.project;
    }
    async function connect() {
        return run(async () => {
            await coreRequest('health');
            const u = (await coreRequest<{
                user: CoreUser;
            }>('auth/me')).user;
            const list = (await coreRequest<{
                projects: CoreProject[];
            }>('projects')).projects;
            setUser(u);
            setProjects(list);
            setPhase('ready');
            const requested = new URLSearchParams(location.search).get('project') || '', stored = requested || previous(u.id), selected = list.find(p => p.id === stored && p.data.consents.learning);
            if (requested && !selected)
                setNotice('Указанный проект недоступен или Learning отключён. Выберите доступный проект.');
            if (selected)
                await load(selected.id, u);
            else { setProject(null); setData(null); }
        });
    }
    async function select(id: string) {
        return run(async () => {
            if (!user)
                return;
            if (!id) {
                setProject(null);
                setData(null);
                remember(user.id, '');
                return;
            }
            await load(id, user);
        });
    }
    async function reload() {
        return run(async () => {
            if (user && project)
                await load(project.id, user);
        });
    }
    async function commit(payload: Record<string, unknown>, retry = false) {
        return run(async () => {
            if (!user || !project)
                throw new Error('Выберите серверный проект.');
            const route = 'projects/' + project.id + '/learning', old = readPending();
            if (old && !retry)
                throw new Error('Есть незавершённая операция. Повторите её с тем же ключом или проверьте данные в Core.');
            if (retry && (!old || old.userId !== user.id || old.route !== route))
                throw new Error('Эта операция относится к другому проекту или разделу. Откройте Core для проверки.');
            const operation = retry ? old! : { userId: user.id, route, key: crypto.randomUUID(), body: { expectedVersion: project.version, ...payload } };
            storePending(operation);
            let result: LearningReply;
            try {
                result = await coreRequest<LearningReply>(operation.route, operation.body, operation.key);
                storePending(null);
            }
            catch (e) {
                if (e instanceof CoreError && e.status >= 400 && e.status < 500)
                    storePending(null);
                throw e;
            }
            // A replay may be older than changes made on another device. Always load the current state.
            await load(project.id, user);
            setNotice(result.replayed ? 'Получен сохранённый результат. Действие не повторялось.' : 'Сохранено на сервере.');
            return result;
        });
    }
    useEffect(()=>{const resume=(event:PageTransitionEvent)=>{if(event.persisted&&phase!=='idle')void connect()};window.addEventListener('pageshow',resume);return()=>window.removeEventListener('pageshow',resume)},[phase])
    return { user, projects, project, data, phase, busy, error, notice, pending, connect, select, reload, commit, setError };
}
const escapeICS = (value: string) => value.replace(/\\/g, '\\\\').replace(/\r\n|\r|\n/g, '\\n').replace(/;/g, '\\;').replace(/,/g, '\\,');
function foldICS(line: string) {
    let bytes = 0, out = '';
    for (const char of line) {
        const size = new TextEncoder().encode(char).length;
        if (bytes + size > 75) {
            out += '\r\n ';
            bytes = 1;
        }
        out += char;
        bytes += size;
    }
    return out;
}
export function learningCalendar(sessions: LearningSession[], stamp = new Date().toISOString()) {
    const utc = (v: string) => {
        const d = new Date(v);
        if (!Number.isFinite(d.getTime()))
            throw new Error('Неверная дата занятия.');
        return d.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
    };
    const lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//OSGARD//Learning Pilot//RU', 'CALSCALE:GREGORIAN', 'METHOD:PUBLISH'];
    for (const s of sessions) {
        lines.push('BEGIN:VEVENT', 'UID:' + escapeICS(s.id) + '@osgard.local', 'DTSTAMP:' + utc(stamp), 'DTSTART:' + utc(s.startsAt), 'DTEND:' + utc(s.endsAt), 'SUMMARY:' + escapeICS(s.title), 'DESCRIPTION:' + escapeICS(s.notes + '\nВедущий: ' + s.facilitator), 'STATUS:' + (s.status === 'cancelled' ? 'CANCELLED' : 'CONFIRMED'));
        if (s.meetingUrl)
            lines.push('URL:' + escapeICS(s.meetingUrl));
        lines.push('END:VEVENT');
    }
    return lines.map(foldICS).join('\r\n') + '\r\nEND:VCALENDAR\r\n';
}
export function downloadCalendar(sessions: LearningSession[]) { const blob = new Blob([learningCalendar(sessions)], { type: 'text/calendar;charset=utf-8' }), url = URL.createObjectURL(blob), a = document.createElement('a'); a.href = url; a.download = 'osgard-learning.ics'; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); }
export type LearningConnection = ReturnType<typeof useLearningProject>;
