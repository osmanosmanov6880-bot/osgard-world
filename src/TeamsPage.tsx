import { useEffect, useRef, useState } from 'react';
import { coreRequest, CoreError, readPending, storePending, downloadCore } from './coreClient';
import type { CoreUser, CoreProject, PendingOperation } from './coreClient';
import { coreLoginLink } from './accountAccess';
import './coreWorkspace.css';
type Team = {
    id: string;
    name: string;
    role: string;
    version: number;
};
type Detail = {
    team: Team;
    participants: {
        id: string;
        username: string;
        role: string;
    }[];
    projects: {
        id: string;
        title: string;
        version: number;
        role: string;
    }[];
    events: {
        id: number;
        kind: string;
        detail: unknown;
        at: string;
    }[];
};
export default function TeamsPage() {
    const [phase, setPhase] = useState<'loading' | 'ready' | 'login' | 'offline'>('loading'), [user, setUser] = useState<CoreUser | null>(null), [teams, setTeams] = useState<Team[]>([]), [projects, setProjects] = useState<CoreProject[]>([]), [detail, setDetail] = useState<Detail | null>(null), [busy, setBusy] = useState(false), [error, setError] = useState(''), [message, setMessage] = useState(''), [pending, setPending] = useState<PendingOperation | null>(readPending), [form, setForm] = useState({ name: '', username: '', role: 'viewer', projectId: '', ack: false }), [mode, setMode] = useState(''), [version, setVersion] = useState<number | null>(null), [projectVersion, setProjectVersion] = useState<number | null>(null), [needsReconnect, setNeedsReconnect] = useState(false),[truncated,setTruncated]=useState(false);
    const lock = useRef(false), alert = useRef<HTMLParagraphElement>(null), owner = useRef<string | null>(null);
    const dirty = !!mode, stale = version !== null && detail?.team.version !== version, blocked = busy || !!pending || stale || needsReconnect;
    function clear() { setForm({ name: '', username: '', role: 'viewer', projectId: '', ack: false }); setMode(''); setVersion(null); setProjectVersion(null); }
    function edit(kind: string, changes: Partial<typeof form>) { if (mode && mode !== kind) {
        if (!confirm('Перейти к другой форме без сохранения текущих полей?'))
            return;
        clear();
        setForm({ name: '', username: '', role: 'viewer', projectId: '', ack: false, ...changes });
    }
    else
        setForm(v => ({ ...v, ...changes })); if (mode !== kind) {
        setVersion(kind === 'create' ? null : detail?.team.version ?? null);
        setMode(kind);
    } if (changes.projectId !== undefined) {
        setProjectVersion(projects.find(p => p.id === changes.projectId)?.version ?? null);
        setForm(v => ({ ...v, ack: false }));
    } }
    async function list() { const [ts, ps] = await Promise.all([coreRequest<{
            teams: Team[];truncated:boolean;
        }>('teams'), coreRequest<{
            projects: CoreProject[];
        }>('projects')]); setTeams(ts.teams);setTruncated(ts.truncated); setProjects(ps.projects); }
    async function fetchTeam(id: string) { const r = await coreRequest<Detail>('teams/' + id); setDetail(r); }
    async function connect() { const u = (await coreRequest<{
        user: CoreUser;
    }>('auth/me')).user; if (owner.current && owner.current !== u.id) {
        setDetail(null);
        clear();
    } owner.current = u.id; setUser(u); await list(); setPhase('ready'); const requested = new URLSearchParams(location.search).get('team'); if (requested && /^[a-f0-9]{32}$/.test(requested))
        await fetchTeam(requested); setNeedsReconnect(false); }
    async function run(work: () => Promise<void>) { if (lock.current)
        return; lock.current = true; setBusy(true); setError(''); setMessage(''); try {
        await work();
    }
    catch (e) {
        setError(e instanceof Error ? e.message : 'Не удалось выполнить действие.');
        if (e instanceof CoreError && e.status === 401) {
            setUser(null);
            setDetail(null);
            setTeams([]);
            setProjects([]);
            clear();
            setPhase('login');
        }
        else if (e instanceof CoreError && e.status === 404) {
            setDetail(null);
        }
        else if (!user)
            setPhase('offline');
    }
    finally {
        lock.current = false;
        setBusy(false);
    } }
    useEffect(() => { void run(connect); }, []);
    useEffect(() => { if (error)
        alert.current?.focus(); }, [error]);
    useEffect(() => { const leave = (e: BeforeUnloadEvent) => { if (dirty) {
        e.preventDefault();
        e.returnValue = '';
    } }; const resume = (e: PageTransitionEvent) => { if (e.persisted) {
        if (dirty) {
            setNeedsReconnect(true);
            setError('Форма восстановлена из истории. Проверьте аккаунт и обновите команду перед отправкой.');
        }
        else
            void run(connect);
    } }; window.addEventListener('beforeunload', leave); window.addEventListener('pageshow', resume); return () => { window.removeEventListener('beforeunload', leave); window.removeEventListener('pageshow', resume); }; }, [dirty]);
    async function mutate(action: string, fields: Record<string, unknown> = {}, retry?: PendingOperation) { if (!user)
        throw Error('Войдите в аккаунт.'); if (needsReconnect)
        throw Error('Сначала проверьте аккаунт и обновите команду.'); const operation = retry || { route: action === 'create' ? 'teams' : 'teams/' + detail!.team.id, key: crypto.randomUUID(), userId: user.id, body: action === 'create' ? { name: form.name } : { action, expectedVersion: version ?? detail!.team.version, ...fields } }; if (operation.userId !== user.id)
        throw Error('Запрос принадлежит другому аккаунту.'); if (pending && !retry)
        throw Error('Сначала разрешите незавершённый запрос.'); setPending(operation); storePending(operation); try {
        const r = await coreRequest<{
            teamId: string;
            left?: boolean;
        }>(operation.route, operation.body, operation.key);
        setPending(null);
        storePending(null);
        clear();
        await list();
        if (r.left)
            setDetail(null);
        else
            await fetchTeam(r.teamId);
        setMessage('Изменения сохранены. Внешних приглашений и писем не отправлялось.');
    }
    catch (e) {
        if (e instanceof CoreError && e.status >= 400 && e.status < 500) {
            setPending(null);
            storePending(null);
        }
        throw e;
    } }
    const manager = detail && ['owner', 'admin'].includes(detail.team.role);
    return <main className="brand-container core-workspace"><section className="core-intro"><p className="brand-eyebrow">OSGARD CORE / TEAMS</p><h1>Общая работа.<br /><em>Явные границы.</em></h1><p className="brand-lead">Команды объединяют участников и выбранные проекты. Только владелец проекта разрешает подключение; личные роли сохраняются отдельно.</p><div className="brand-actions"><a className="brand-button" href="/workspace/overview">Рабочий центр</a><a className="brand-button" href="/workspace">Проекты</a></div></section><p ref={alert} tabIndex={-1} role={error ? 'alert' : undefined} hidden={!error} className="core-alert">{error}</p><p role="status">{busy ? 'Обновляем данные…' : message}</p>{phase === 'loading' && <p>Подключаем команды…</p>}{phase === 'login' && <section className="core-panel"><h2>Войдите в Core</h2><a className="brand-button primary" href={coreLoginLink('/teams' + location.search)}>Войти и вернуться</a></section>}{phase === 'offline' && <section className="core-panel"><h2>Нужен сервер Core</h2><p>Командные пространства работают в полном комплекте START-CORE, а не на статическом хостинге.</p><button className="brand-button" onClick={() => void run(connect)}>Повторить подключение</button></section>}
 {phase === 'ready' && user && <><section className="core-panel"><h2>Ваши команды</h2>{truncated&&<p className="core-alert">Показаны первые 100 команд. Остальные доступны по своему адресу.</p>}<button className="brand-button" disabled={busy} onClick={() => void run(async () => { await connect(); if (detail)
            await fetchTeam(detail.team.id); })}>Обновить список и выбранную команду</button>{dirty && <button className="brand-button" disabled={busy} onClick={() => { if (confirm('Убрать несохранённые поля?'))
            clear(); }}>Убрать черновик</button>}{stale && <p className="core-alert">Версия команды изменилась. Поля сохранены на экране; обновите данные, проверьте изменения и заполните форму заново.</p>}{!teams.length && <p>Команд пока нет. Создайте пространство или попросите владельца добавить ваш существующий логин.</p>}{teams.map(t => <article className="core-source" key={t.id}><strong>{t.name}</strong><p>{t.role} · v{t.version}</p><button className="brand-button" disabled={busy} onClick={() => { if (dirty && !confirm('Открыть команду без сохранения полей?'))
            return; clear(); void run(() => fetchTeam(t.id)); }}>Открыть команду</button></article>)}<form onSubmit={e => { e.preventDefault(); void run(() => mutate('create')); }}><fieldset className="core-editor" disabled={busy || !!pending || needsReconnect}><legend>Новое пространство</legend><label className="core-field"><span>Название команды</span><input required minLength={3} maxLength={120} value={mode === 'create' ? form.name : ''} onChange={e => edit('create', { name: e.target.value })}/></label><button className="brand-button primary">Создать команду</button></fieldset></form></section>
 {pending && <section className="core-panel"><h2>Незавершённый запрос</h2><p>Повтор использует тот же ключ. Запросы из других разделов разрешите в рабочем пространстве.</p><button className="brand-button" disabled={busy || needsReconnect || pending.userId !== user.id || !/^teams(?:\/[a-f0-9]{32})?$/.test(pending.route)} onClick={() => void run(() => mutate('', {}, pending))}>Повторить запрос</button><a className="brand-button" href="/workspace">Рабочее пространство</a><button className="brand-button" disabled={busy} onClick={() => void run(async () => { await list(); if (detail)
            await fetchTeam(detail.team.id); if (confirm('После проверки данных убрать ожидание? Сам запрос не отменяется.')) {
            setPending(null);
            storePending(null);
        } })}>Проверить состояние</button></section>}
 {detail && <section className="core-panel"><p className="brand-eyebrow">TEAM / v{detail.team.version}</p><h2>{detail.team.name}</h2><p>Ваша роль: {detail.team.role}. Администраторы и редакторы команды получают роль редактора подключённых проектов; наблюдатели — чтение. Владелец проекта сохраняет свою роль.</p><button className="brand-button" onClick={() => downloadCore(detail, 'osgard-team-' + detail.team.id + '.json')}>Скачать доступную сводку команды</button>{manager && <><form onSubmit={e => { e.preventDefault(); void run(() => mutate('rename', { name: form.name })); }}><fieldset className="core-editor" disabled={blocked}><legend>Название</legend><label className="core-field"><span>Новое название</span><input required minLength={3} maxLength={120} value={mode === 'rename' ? form.name : ''} onChange={e => edit('rename', { name: e.target.value })}/></label><button className="brand-button">Сохранить название</button></fieldset></form><form onSubmit={e => { e.preventDefault(); void run(() => mutate('member', { username: form.username, role: form.role })); }}><fieldset className="core-editor" disabled={blocked}><legend>Участник и роль</legend><label className="core-field"><span>Существующий логин</span><input required minLength={3} maxLength={64} value={form.username} onChange={e => edit('member', { username: e.target.value })}/></label><label className="core-field"><span>Роль команды</span><select value={form.role} onChange={e => edit('member', { role: e.target.value })}>{detail.team.role === 'owner' && <option value="admin">Администратор</option>}<option value="editor">Редактор</option><option value="viewer">Наблюдатель</option><option value="remove">Убрать из команды</option></select></label><button className="brand-button">Сохранить командную роль</button></fieldset></form></>}
 <h3>Участники</h3>{detail.participants.map(p => <p key={p.id}>{p.username} · {p.role}</p>)}{detail.team.role !== 'owner' && <button className="brand-button" disabled={blocked || dirty} onClick={() => { if (confirm('Покинуть команду? Личные роли проектов, если они выданы, сохранятся.'))
                void run(() => mutate('leave')); }}>Покинуть команду</button>}
 <h3>Подключённые проекты</h3>{!detail.projects.length && <p>Проектов пока нет.</p>}{detail.projects.map(p => <article className="core-source" key={p.id}><strong>{p.title}</strong><p>v{p.version} · {p.role}</p><a className="brand-button" href={'/workspace?project=' + p.id}>Открыть проект</a>{(manager || p.role === 'owner') && <button className="brand-button" disabled={blocked || dirty} onClick={() => { if (confirm('Отключить проект от команды? Личные роли не удалятся.'))
                void run(() => mutate('detach', { projectId: p.id, projectVersion: p.version })); }}>Отключить от команды</button>}</article>)}
 {manager && <form onSubmit={e => { e.preventDefault(); void run(() => mutate('attach', { projectId: form.projectId, projectVersion, sharingAcknowledged: form.ack })); }}><fieldset className="core-editor" disabled={blocked}><legend>Подключить свой проект</legend><label className="core-field"><span>Проект, которым вы владеете</span><select required value={form.projectId} onChange={e => edit('attach', { projectId: e.target.value })}><option value="">Выберите проект</option>{projects.filter(p => p.role === 'owner').map(p => <option key={p.id} value={p.id}>{p.data.title} · v{p.version}</option>)}</select></label><label className="core-check"><input required type="checkbox" checked={form.ack} onChange={e => edit('attach', { ack: e.target.checked })}/>Разрешаю всем текущим и будущим участникам команды доступ ко всему проекту по их роли; редакторам — также к служебным обращениям и передачам</label><button className="brand-button primary" disabled={!form.ack}>Подключить проект</button></fieldset></form>}
 <p>Удаление личной роли не отменяет командную, и наоборот. Для закрытия доступа проверьте оба источника. Владелец проекта может отключить его через рабочее пространство, даже если больше не входит в команду.</p><details><summary>Последние события команды</summary>{!detail.events.length && <p>Журнал виден владельцу и администраторам.</p>}{detail.events.map(e => <p key={e.id}>{new Date(e.at).toLocaleString('ru-RU')} · {e.kind} · {JSON.stringify(e.detail)}</p>)}</details></section>}</>}
 </main>;
}
