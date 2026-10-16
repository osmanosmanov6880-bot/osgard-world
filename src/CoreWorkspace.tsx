import TeamProjectAccess from './TeamProjectAccess'
import CommercePanel from './CommercePanel'
import CoreReleaseReadiness from './CoreReleaseReadiness'
import ClientDeliveryPanel from './ClientDeliveryPanel'
import DeliveryPanel from './DeliveryPanel'
import ReleaseAcceptance from './ReleaseAcceptance'
import {coreAuthReturn} from './accountAccess'
import { useEffect, useRef, useState } from 'react';
import type { FormEvent, ReactNode } from 'react';
import { coreRequest, CoreError, setCoreToken, readPending, storePending, minorUnits, formatMoney, downloadCore, practiceRecommendation } from './coreClient';
import type { CoreProject, CoreData, CoreUser, PendingOperation } from './coreClient';
import { OSA_LESSON_SLUGS } from './osaLessonRegistry';
import { getOSALearningProgress } from './osaProgress';
import './coreWorkspace.css';
const tabs = [['contract', 'Контракт'], ['learning', 'Learning'], ['studio', 'Studio'], ['acceptance', 'Приёмка'], ['delivery', 'Передача'], ['clients', 'Кабинет получателя'], ['business', 'Business'], ['memory', 'Источники'], ['results', 'Результат'], ['history', 'История']] as const;
type Tab = typeof tabs[number][0];
const key = () => crypto.randomUUID();
const fail = (e: unknown) => e instanceof Error ? e.message : 'Не удалось выполнить действие.';
function Field({ label, children }: {
    label: string;
    children: ReactNode;
}) { return <label className="core-field"><span>{label}</span>{children}</label>; }
export default function CoreWorkspace() {
    const [available, setAvailable] = useState<boolean | null>(null), [user, setUser] = useState<CoreUser | null>(null), [projects, setProjects] = useState<CoreProject[]>([]), [selected, setSelected] = useState<CoreProject | null>(null), [draft, setDraft] = useState<CoreData | null>(null), [tab, setTab] = useState<Tab>('contract'), [busy, setBusy] = useState(false), [error, setError] = useState(''), [message, setMessage] = useState(''), [dirty, setDirty] = useState(false), [pending, setPending] = useState<PendingOperation | null>(readPending);
    const [assets, setAssets] = useState<{
        id: string;
        sha256: string;
        sourceVersion: number;
    }[]>([]), [preview, setPreview] = useState('');
    const [observation, setObservation] = useState({ task: '', beforeSeconds: '', afterSeconds: '', correctionSeconds: '0', manualSeconds: '0', success: false, evidence: '' });
    const [jobs, setJobs] = useState<{
        id: string;
        sourceVersion: number;
        status: string;
        attempts: number;
        result: {
            checks?: {
                label: string;
                passed: boolean;
            }[];
        } | null;
    }[]>([]);
    const [templates, setTemplates] = useState<{
        id: string;
        title: string;data:{tasks:string[];acceptance:string[]};status:string;sourceVersion:number;provenance:{releaseId:string;reviewer:string;reviewedAt:string}|null;
    }[]>([]), [templateId, setTemplateId] = useState('');
    const [register, setRegister] = useState(false), [username, setUsername] = useState(''), [password, setPassword] = useState(''), [title, setTitle] = useState(''), [goal, setGoal] = useState(''), [report, setReport] = useState<{
        label: string;
        passed: boolean;
    }[] | null>(null), [history, setHistory] = useState<{
        revisions: {
            version: number;
            createdAt: string;
        }[];
        events: {
            id: number;
            kind: string;
            createdAt: string;
            detail: string;
        }[];
    } | null>(null), [members, setMembers] = useState<{
        username: string;
        role: string;directRole?:string|null;hasTeamAccess?:number;
    }[]>([]), [member, setMember] = useState(''), [role, setRole] = useState('viewer'), [cost, setCost] = useState(''), [costNote, setCostNote] = useState(''), [category, setCategory] = useState('compute'), [money, setMoney] = useState(''), [offerMoney, setOfferMoney] = useState('');
    const [reviewDirty,setReviewDirty]=useState(false),[selectionKey,setSelectionKey]=useState(0);
    const busyRef = useRef(false);
    const errorRef = useRef<HTMLDivElement>(null);
    useEffect(() => { let active = true; coreRequest<{
        status: string;
    }>('health').then(() => { if (active)
        setAvailable(true); return coreRequest<{
        user: CoreUser;
    }>('auth/me'); }).then(async (r) => { if (active) {
        setUser(r.user);
        const list = await coreRequest<{
            projects: CoreProject[];
        }>('projects');
        if (active) {
            setProjects(list.projects);
            const library = await coreRequest<{
                templates: {
                    id: string;
                    title: string;data:{tasks:string[];acceptance:string[]};status:string;sourceVersion:number;provenance:{releaseId:string;reviewer:string;reviewedAt:string}|null;
                }[];
            }>('templates');
            if (active) {
                setTemplates(library.templates);
                const query=new URLSearchParams(location.search),requested=query.get('project');
                if(requested){const target=list.projects.find(p=>p.id===requested);if(target){choose(target);const requestedTab=query.get('tab');if(tabs.some(([id])=>id===requestedTab))setTab(requestedTab as Tab)}else setError('Указанный проект недоступен этому аккаунту. Выберите проект из списка.')}
            }
        }
    } }).catch(e => { if (!active)
        return; if (e instanceof CoreError && e.status === 401) {
        setCoreToken('');
        return;
    } setAvailable(false); }); return () => { active = false; }; }, []);
    useEffect(() => { if (error)
        errorRef.current?.focus(); }, [error]);
    useEffect(() => { const leave = (e: BeforeUnloadEvent) => { if (dirty || reviewDirty) {
        e.preventDefault();
        e.returnValue = '';
    } }; window.addEventListener('beforeunload', leave); return () => window.removeEventListener('beforeunload', leave); }, [dirty,reviewDirty]);
    useEffect(()=>{const resume=(event:PageTransitionEvent)=>{if(event.persisted){if(!(dirty||reviewDirty))location.reload();else setError('Форма восстановлена из истории браузера. Проверьте аккаунт и обновите данные перед сохранением.')}};window.addEventListener('pageshow',resume);return()=>window.removeEventListener('pageshow',resume)},[dirty,reviewDirty])
    function choose(p: CoreProject) { setSelectionKey(v=>v+1); setReviewDirty(false); setSelected(p); setDraft(structuredClone(p.data)); setMoney(String(p.data.budgetMinor / 100)); setOfferMoney(String(p.data.offer.amountMinor / 100)); setDirty(false); setReport(null); setAssets([]); setPreview(''); setJobs([]); setHistory(null); setMembers([]); setMessage(''); setError(''); }
    function edit(changes: Partial<CoreData>) { setDraft(d => d ? { ...d, ...changes } : d); setDirty(true); setMessage(''); }
    async function refresh() { const library = await coreRequest<{
        templates: {
            id: string;
            title: string;data:{tasks:string[];acceptance:string[]};status:string;sourceVersion:number;provenance:{releaseId:string;reviewer:string;reviewedAt:string}|null;
        }[];
    }>('templates'); setTemplates(library.templates); const r = await coreRequest<{
        projects: CoreProject[];
    }>('projects'); setProjects(r.projects); return r.projects; }
    async function guard(work: () => Promise<void>) { if (busyRef.current)
        return; busyRef.current = true; setBusy(true); setError(''); setMessage(''); try {
        await work();
    }
    catch (e) {
        setError(fail(e));
        if (e instanceof CoreError && e.status === 401) {
            setCoreToken('');
            setUser(null);
            setProjects([]);
            setTemplates([]);
            setSelected(null);
            setDraft(null);
            setDirty(false);
        }
    }
    finally {
        busyRef.current = false;
        setBusy(false);
    } }
    async function auth(e: FormEvent) { e.preventDefault(); await guard(async () => { const r = await coreRequest<{
        token: string;
        user: CoreUser;
    }>('auth/' + (register ? 'register' : 'login'), { username, password }); setCoreToken(r.token); setUser(r.user); setPassword(''); setAvailable(true); await refresh(); const target=coreAuthReturn(location.pathname,location.search);if(target!=='/workspace')location.assign(target); }); }
    async function mutate(route: string, body: Record<string, unknown>, retry?: PendingOperation) {
        if (!user)
            throw new Error('Войдите в аккаунт.');
        if (pending && !retry)
            throw new Error('Сначала разрешите незавершённую операцию: повторите её или проверьте актуальные данные.');
        const operation = retry || { route, body, key: key(), userId: user.id };
        if (operation.userId !== user.id)
            throw new Error('Операция принадлежит другому аккаунту.');
        setPending(operation);
        storePending(operation);
        try {
            const r = await coreRequest<{
                project?: CoreProject;
                result?: {
                    checks?: {
                        label: string;
                        passed: boolean;
                    }[];
                };
                replayed?: boolean;
            }>(route, body, operation.key);
            setPending(null);
            storePending(null);
            await refresh();
            if (r.project) {
                if(route.endsWith('/delivery')){setSelected(r.project);setDraft(structuredClone(r.project.data));setDirty(false)}
                else choose(r.project);
            }
            if (r.result?.checks)
                setReport(r.result.checks);
            setMessage(r.replayed ? 'Сервер вернул ранее сохранённый результат. Действие не повторялось.' : 'Изменения сохранены на сервере.');
            return r;
        }
        catch (e) {
            if (e instanceof CoreError && e.status >= 400 && e.status < 500) {
                setPending(null);
                storePending(null);
            }
            throw e;
        }
    }
    async function save() { if (!selected || !draft)
        return; const { costs: _c, orders: _o, releases: _r, measurements: _m, schemaVersion: _s, ...changes } = draft; changes.budgetMinor = minorUnits(money); changes.offer = { ...changes.offer, amountMinor: minorUnits(offerMoney) }; await mutate('projects/' + selected.id, { expectedVersion: selected.version, changes }); }
    async function act(kind: string, payload: Record<string, unknown> = {}) { if (!selected)
        return; if (dirty)
        throw new Error('Сначала сохраните изменения проекта.'); await mutate('projects/' + selected.id + '/actions', { expectedVersion: selected.version, kind, payload }); }
    async function loadHistory() { if (!selected)
        return; const r = await coreRequest<{
        revisions: {
            version: number;
            createdAt: string;
        }[];
        events: {
            id: number;
            kind: string;
            createdAt: string;
            detail: string;
        }[];
    }>('projects/' + selected.id + '/history'); setHistory(r); const m = await coreRequest<{
        members: {
            username: string;
            role: string;
        }[];
    }>('projects/' + selected.id + '/members'); setMembers(m.members); }
    const readonly = selected?.role === 'viewer', moneyFmt = (v: number) => formatMoney(v, draft?.currency || 'RUB');
    return <main className="brand-container core-workspace"><section className="core-intro"><p className="brand-eyebrow">OSGARD CORE / LEARN · BUILD · OFFER</p><h1>От цели<br /><em>к проверенному результату.</em></h1><p className="brand-lead">Один контракт, одна история проекта. Учитесь, создавайте артефакт и готовьте предложение в общем рабочем пространстве.</p><div className="core-capabilities"><span>Серверные версии</span><span>Контроль бюджета</span><span>Повтор без дублирования</span><span>Экспорт данных</span></div></section>
 <div ref={errorRef} tabIndex={-1} role={error ? 'alert' : undefined} hidden={!error} className="core-alert">{error}</div><p role="status" className="core-status">{busy ? 'Выполняем запрос…' : message}</p>
 {available === null && <p role="status">Проверяем доступность Core…</p>}
 {available === false && <section className="core-panel"><h2>Подключите серверное ядро</h2><p>Статический ZIP содержит интерфейс. Аккаунты, общие проекты и версии работают в полном архиве: запустите <code>START-CORE-WINDOWS.bat</code>. Сейчас соединение с сервером недоступно. Проверьте подключение или повторите запрос позже.</p><p><a href="/learning/workspace">Открыть работающую гостевую мастерскую →</a></p><button className="brand-button" onClick={() => location.reload()}>Проверить подключение</button></section>}
 {available && !user && <section className="core-panel core-auth"><h2>{register ? 'Создать аккаунт пилота' : 'Войти в рабочее пространство'}</h2><p><a href="/account">Восстановить доступ по резервному коду →</a></p><p>Данные сохраняются на этом сервере и доступны в других браузерах по тому же адресу. Сессия — 8 часов. Восстановление по резервным кодам настраивается в разделе аккаунта; почтовое восстановление не подключено.</p><form onSubmit={auth}><Field label="Логин"><input autoComplete="username" required pattern="[A-Za-z0-9_.\-]{3,64}" minLength={3} maxLength={64} value={username} onChange={e => setUsername(e.target.value)}/></Field><Field label="Пароль — минимум 12 символов"><input required type="password" autoComplete={register ? 'new-password' : 'current-password'} minLength={12} maxLength={256} value={password} onChange={e => setPassword(e.target.value)}/></Field><button disabled={busy} className="brand-button primary">{register ? 'Создать аккаунт' : 'Войти'}</button></form><button disabled={busy} className="core-text-button" onClick={() => { setRegister(!register); setError(''); }}>{register ? 'Уже есть аккаунт' : 'Создать аккаунт'}</button></section>}
 {user && <><section className="core-account"><span><strong>{user.username}</strong> / Core pilot · <a href="/workspace/overview">Рабочий центр</a> · <a href="/account">Аккаунт и сессии</a></span><button disabled={busy} className="brand-button" onClick={() => { if ((dirty || reviewDirty) && !confirm('Есть несохранённые изменения. Выйти?'))
            return; void guard(async () => { await coreRequest('auth/logout', {}); setCoreToken(''); setUser(null); setProjects([]); setTemplates([]); setSelected(null); setDraft(null); setDirty(false); setPending(null); storePending(null); }); }}>Выйти</button></section>
 {pending && <section className="core-alert"><h2>Есть незавершённый запрос</h2><p>Связь могла прерваться после сохранения. Повтор использует исходный ключ и не создаёт второе действие. Если запрос принадлежит другому аккаунту, войдите в тот аккаунт.</p><button className="brand-button" disabled={busy || pending.userId !== user.id} onClick={() => void guard(async () => { await mutate(pending.route, pending.body, pending); })}>Повторить тот же запрос</button><button className="brand-button" disabled={busy} onClick={() => void guard(async () => { const list = await refresh(); if (selected) {
            const current = list.find(p => p.id === selected.id);
            if (current)
                choose(current);
        } setPending(null); storePending(null); setMessage('Актуальные проекты загружены. Предыдущий запрос не отменён: проверьте историю перед новым действием.'); })}>Проверить данные и убрать запрос</button></section>}
 <div className="core-layout"><aside className="core-sidebar"><h2>Проекты <small>{projects.length}</small></h2><nav aria-label="Выбор проекта">{projects.map(p => <button key={p.id} className={p.id === selected?.id ? 'selected' : ''} disabled={busy} aria-current={p.id === selected?.id ? 'true' : undefined} onClick={() => { if (!(dirty || reviewDirty) || confirm('Перейти без сохранения изменений?'))
            choose(p); }}><span>{p.data.title}</span><small>v{p.version} · {p.role}</small></button>)}</nav>{!projects.length && <p>Пока нет проектов. Начните с конкретной цели.</p>}<form onSubmit={e => { e.preventDefault(); void guard(async () => { if ((dirty || reviewDirty) && !confirm('Создать проект без сохранения текущих изменений?'))
            return; await mutate('projects', { title, goal, ...(templateId ? { templateId } : {}) }); setTitle(''); setGoal(''); }); }}><h3>Новая цель</h3><Field label="Название"><input required minLength={2} maxLength={160} value={title} onChange={e => setTitle(e.target.value)}/></Field><Field label="Какой результат нужен"><textarea required minLength={10} maxLength={4000} value={goal} onChange={e => setGoal(e.target.value)}/></Field><Field label="Процесс"><select value={templateId} onChange={e => setTemplateId(e.target.value)}><option value="">Начальный маршрут</option>{templates.map(t => <option key={t.id} value={t.id}>{t.title}{t.provenance?' · разобран исходный выпуск':''}</option>)}</select></Field>{templateId && templates.filter(t=>t.id===templateId).map(t=><details className="core-source" key={t.id} open><summary>Что перенесётся в новый проект</summary><p>Исходная версия: {t.sourceVersion}. {t.provenance?'На момент создания процесса выпуск разобрал '+t.provenance.reviewer+'; это не сертификация процесса.':'Только внутренняя проверка; отдельный положительный разбор не зафиксирован.'}</p><p>Переносятся формулировки задач и критериев. Готовность и отметки выполнения сбрасываются.</p><h4>Задачи</h4><ol>{t.data.tasks.map((v,i)=><li key={i}>{v}</li>)}</ol><h4>Критерии</h4><ul>{t.data.acceptance.map((v,i)=><li key={i}>{v}</li>)}</ul></details>)}<button disabled={busy || !!pending} className="brand-button primary">Создать проект</button></form></aside>
 <div className="core-main">{!selected || !draft ? <section className="core-panel"><h2>Выберите или создайте проект</h2><p>Начните с одной аудитории и измеримого результата. Начальный план создаётся по шести фиксированным этапам; AI-модель не подключена.</p></section> : <><header className="core-project-header"><div><p className="brand-eyebrow">PROJECT / {selected.id.slice(0, 8)} / v{selected.version}</p><h2>{selected.data.title}</h2><p>{readonly ? 'Вы можете просматривать проект и экспортировать данные.' : (dirty || reviewDirty) ? 'Есть несохранённые изменения.' : 'Сохранено на сервере.'}</p></div><div className="brand-actions"><button disabled={busy || readonly || !dirty || !!pending} className="brand-button primary" onClick={() => void guard(save)}>Сохранить</button><button disabled={busy} className="brand-button" onClick={() => void guard(async () => { if ((dirty || reviewDirty) && !confirm('Загрузить серверную версию без сохранения изменений?'))
                return; const r = await coreRequest<{
                project: CoreProject;
            }>('projects/' + selected.id); choose(r.project); })}>Обновить</button><button disabled={busy} className="brand-button" onClick={() => void guard(async () => downloadCore(await coreRequest('projects/' + selected.id + '/export'), 'osgard-project-' + selected.id + '.json'))}>Экспорт</button></div></header>
 <nav className="core-tabs" aria-label="Этапы проекта">{tabs.map(([id, label]) => <button key={id} disabled={busy} aria-current={tab === id ? 'step' : undefined} onClick={() => {if(id===tab)return;if(!reviewDirty||confirm('Закрыть несохранённый разбор?')){setReviewDirty(false);setTab(id)}}}>{label}</button>)}</nav>
 <fieldset disabled={busy || readonly} className="core-editor"><legend className="core-sr">Редактор проекта</legend>
 {tab === 'contract' && <section className="core-panel"><h2>Контракт результата</h2><p>Сначала определите цель, ограничения и критерии. После изменения условий контракт нужно принять заново.</p><Field label="Название"><input value={draft.title} maxLength={160} onChange={e => edit({ title: e.target.value })}/></Field><Field label="Цель"><textarea value={draft.goal} maxLength={4000} onChange={e => edit({ goal: e.target.value })}/></Field><Field label="Для кого"><input value={draft.audience} maxLength={1000} onChange={e => edit({ audience: e.target.value })}/></Field><div className="core-two"><Field label="Бюджет — сумма в выбранной валюте"><input inputMode="decimal" value={money} onChange={e => { setMoney(e.target.value); setDirty(true); }}/></Field><Field label="Валюта"><select value={draft.currency} disabled={!!draft.costs.length || !!draft.orders.length} onChange={e => edit({ currency: e.target.value as CoreData['currency'] })}>{['RUB', 'USD', 'EUR'].map(v => <option key={v}>{v}</option>)}</select></Field></div><Field label="Срок (UTC)"><input type="datetime-local" value={draft.deadline.slice(0, 16)} onChange={e => edit({ deadline: e.target.value ? e.target.value + ':00Z' : '' })}/></Field><h3>Разрешённые действия</h3>{[['local_checks', 'Локальные проверки'], ['prepare_offer', 'Подготовка предложения'], ['build_preview', 'Создание статического HTML-прототипа']].map(([id, label]) => <label className="core-check" key={id}><input type="checkbox" checked={draft.allowedActions.includes(id)} onChange={e => edit({ allowedActions: e.target.checked ? [...draft.allowedActions, id] : draft.allowedActions.filter(v => v !== id) })}/>{label}</label>)}<p>Публикация, AI-запросы и сообщения покупателям не выполняются автоматически. Для оплаты нужен отдельно настроенный Commerce в разделе Business; его действия запускает покупатель или оператор.</p><h3>Критерии приёмки</h3>{draft.acceptance.map((a, i) => <div className="core-inline" key={a.id}><input type="checkbox" aria-label={'Выполнен критерий ' + (i + 1)} checked={a.done} onChange={e => edit({ acceptance: draft.acceptance.map(x => x.id === a.id ? { ...x, done: e.target.checked } : x) })}/><input aria-label={'Критерий ' + (i + 1)} maxLength={500} value={a.title} onChange={e => edit({ acceptance: draft.acceptance.map(x => x.id === a.id ? { ...x, title: e.target.value } : x) })}/><button className="core-text-button" onClick={() => edit({ acceptance: draft.acceptance.filter(x => x.id !== a.id) })}>Удалить</button></div>)}<button className="brand-button" disabled={draft.acceptance.length >= 30} onClick={() => edit({ acceptance: [...draft.acceptance, { id: key(), title: 'Новый критерий', done: false }] })}>Добавить критерий</button><h3>Передача контекста</h3>{(['learning', 'studio', 'business'] as const).map(id => <label key={id} className="core-check"><input type="checkbox" checked={draft.consents[id]} onChange={e => edit({ consents: { ...draft.consents, [id]: e.target.checked } })}/>{id === 'learning' ? 'Learning — использовать цель для подбора практики' : id === 'studio' ? 'Studio — проверять артефакт в контексте цели' : 'Business — использовать контекст для предложения'}</label>)}<p>Разрешения определяют работу модулей в этом проекте. Участники с доступом видят проект целиком.</p><label className="core-check"><input type="checkbox" checked={draft.accepted} onChange={e => edit({ accepted: e.target.checked })}/>Принимаю текущий контракт и лимиты</label><p className="core-note">Сохраните условия, затем примите контракт отдельным сохранением. При изменении условий сервер снимет принятие.</p></section>}
 {tab === 'learning' && <section className="core-panel"><h2>OSA Learning / нужная практика</h2><p><a href="/learning/campus">Открыть серверные практики, итоговую работу и расписание →</a></p><p>Цель: {draft.consents.learning ? draft.goal : 'Использование цели в Learning не разрешено.'}</p><Field label="Где возникло затруднение"><textarea maxLength={4000} value={draft.practice.problem} onChange={e => edit({ practice: { ...draft.practice, problem: e.target.value } })}/></Field>{draft.consents.learning && draft.practice.problem && <p>По ключевым словам рекомендуем <a href={'/lectures/' + practiceRecommendation(draft.practice.problem)} target="_blank" rel="noopener">короткий урок →</a>. Это правило, не AI-диагностика.</p>}<div className="core-two"><Field label="Результат до практики"><textarea value={draft.practice.before} onChange={e => edit({ practice: { ...draft.practice, before: e.target.value } })}/></Field><Field label="Новая задача для повторной проверки"><textarea value={draft.practice.newTask} onChange={e => edit({ practice: { ...draft.practice, newTask: e.target.value } })}/></Field></div><Field label="Результат на новой задаче"><textarea value={draft.practice.after} onChange={e => edit({ practice: { ...draft.practice, after: e.target.value } })}/></Field><Field label="Доказательства и помощь человека"><textarea value={draft.practice.evidence} onChange={e => edit({ practice: { ...draft.practice, evidence: e.target.value } })}/></Field><h3>Серверный прогресс</h3><p>Отметки сохраняются в проекте между сессиями. Они означают самопроверку, а не сертификат.</p>{OSA_LESSON_SLUGS.map((slug, i) => <label key={slug} className="core-check"><input type="checkbox" checked={draft.lessonCompletions.includes(slug)} onChange={e => edit({ lessonCompletions: e.target.checked ? [...draft.lessonCompletions, slug] : draft.lessonCompletions.filter(v => v !== slug) })}/><a href={'/lectures/' + slug} target="_blank" rel="noopener">{i + 1}. {slug}</a></label>)}<button className="brand-button" onClick={() => { if (!draft.consents.learning) {
                setError('Сначала разрешите использование контекста Learning.');
                return;
            } edit({ lessonCompletions: [...new Set([...draft.lessonCompletions, ...getOSALearningProgress().lessonCompletions])] }); }}>Импортировать гостевые отметки с этого устройства</button><p>Импорт выполняется только по этой кнопке и попадёт на сервер после сохранения.</p></section>}
 {tab === 'studio' && <section className="core-panel"><h2>OSGARD Studio / создать и проверить</h2><h3>Статический HTML-прототип</h3><p>Studio собирает самостоятельную HTML-страницу из сохранённой цели, аудитории, задач и критериев. Это фиксированный шаблон без AI и серверных функций. Перед сборкой разрешите это действие в контракте.</p><button className="brand-button primary" disabled={dirty || !!pending} onClick={() => void guard(() => act('build_preview'))}>Создать HTML-прототип</button><button className="brand-button" onClick={() => void guard(async () => { const r = await coreRequest<{
                assets: typeof assets;
            }>('projects/' + selected.id + '/assets'); setAssets(r.assets); })}>Мои файлы</button>{assets.map(a => <div key={a.id} className="core-source"><p>HTML / версия {a.sourceVersion} / SHA-256 {a.sha256.slice(0, 12)}…</p><button className="brand-button" onClick={() => void guard(async () => { const r = await coreRequest<{
                asset: {
                    html: string;
                };
            }>('projects/' + selected.id + '/assets/' + a.id); setPreview(r.asset.html); })}>Предпросмотр</button><button className="brand-button" onClick={() => void guard(async () => { const r = await coreRequest<{
                asset: {
                    html: string;
                };
            }>('projects/' + selected.id + '/assets/' + a.id); const url = URL.createObjectURL(new Blob([r.asset.html], { type: 'text/html;charset=utf-8' })); const link = document.createElement('a'); link.href = url; link.download = 'osgard-prototype-' + a.id + '.html'; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); })}>Скачать HTML</button></div>)}{preview && <><iframe title="Предпросмотр HTML-прототипа" className="core-preview" sandbox="" srcDoc={preview}/><button className="brand-button" onClick={() => setPreview('')}>Закрыть предпросмотр</button></>}<h3>План работ</h3>{draft.tasks.map((task, i) => <div key={task.id} className="core-inline"><span>{task.done ? '✓' : String(i + 1).padStart(2, '0')}</span><input aria-label={'Задача ' + (i + 1)} value={task.title} onChange={e => edit({ tasks: draft.tasks.map(t => t.id === task.id ? { ...t, title: e.target.value } : t) })}/><button className="brand-button" disabled={task.done || dirty || !!pending} onClick={() => void guard(() => act('complete_task', { taskId: task.id }))}>{task.done ? 'Выполнена' : 'Завершить'}</button></div>)}<button className="brand-button" disabled={draft.tasks.length >= 30} onClick={() => edit({ tasks: [...draft.tasks, { id: key(), title: 'Новая задача', done: false }] })}>Добавить задачу</button><Field label="Артефакт — HTTP(S)-ссылка"><input type="url" value={draft.artifact.url} onChange={e => edit({ artifact: { ...draft.artifact, url: e.target.value } })}/></Field><Field label="SHA-256 файла — если вычислен"><input maxLength={64} value={draft.artifact.checksum} onChange={e => edit({ artifact: { ...draft.artifact, checksum: e.target.value } })}/></Field><Field label="Как воспроизвести проверку; результаты тестов"><textarea value={draft.artifact.notes} onChange={e => edit({ artifact: { ...draft.artifact, notes: e.target.value } })}/></Field><div className="brand-actions"><button className="brand-button" disabled={dirty || !!pending} onClick={() => void guard(() => act('simulate'))}>Предварительная проверка</button><button className="brand-button" disabled={dirty || !!pending} onClick={() => void guard(async () => { await mutate('projects/' + selected.id + '/jobs', { expectedVersion: selected.version }); setMessage('Проверка поставлена в серверную очередь. Она продолжится после перезапуска сервера.'); })}>Проверить в фоне</button><button className="brand-button primary" disabled={dirty || !!pending} onClick={() => void guard(() => act('release'))}>Зафиксировать внутренний выпуск</button></div><p>Проверка проверяет поля, сроки источников, разрешения и бюджет. Сервер не открывает URL, не запускает произвольный код и не подтверждает работоспособность внешнего сайта. Внутренний выпуск не публикует артефакт.</p><button className="brand-button" onClick={() => void guard(async () => { const r = await coreRequest<{
                jobs: typeof jobs;
            }>('projects/' + selected.id + '/jobs'); setJobs(r.jobs); })}>Обновить фоновые проверки</button>{jobs.map(j => <details className="core-source" key={j.id}><summary>Версия {j.sourceVersion} / {j.status} / попыток {j.attempts}</summary>{j.result?.checks?.map(c => <p key={c.label}>{c.passed ? '✓' : '○'} {c.label}</p>)}</details>)}{report && <ul className="core-report">{report.map(c => <li key={c.label}>{c.passed ? '✓' : '○'} {c.label}</li>)}</ul>}{draft.releases.length > 0 && <><h3>Внутренние выпуски</h3><button className="brand-button" disabled={dirty || !!pending} onClick={() => void guard(async () => { await mutate('templates', { projectId: selected.id, title: selected.data.title + ' — процесс' }); setMessage('Шаблон сохранён: только задачи и критерии, без источников, покупателей и денежных записей.'); })}>Сохранить процесс как шаблон</button><p>Шаблон прошёл только внутреннюю проверку проекта. Независимая оценка качества не заявляется.</p>{draft.releases.map(r => <p key={r.id}>{new Date(r.at).toLocaleString('ru-RU')} / {r.status} / {r.url ? <a href={r.url} target="_blank" rel="noopener noreferrer">Артефакт →</a> : <span>Сохранённый HTML-прототип</span>}</p>)}</>}</section>}
 {tab === 'business' && <section className="core-panel"><h2>OSGARD Business / предложение</h2><p>Сохраните предложение и создайте черновик. В блоке оплаты ниже настроенный оператор связывает его с принятым выпуском и аккаунтом покупателя. Доступность платежей зависит от настройки Commerce.</p>{(['title', 'customer', 'scope'] as const).map((field, i) => <Field key={field} label={['Название предложения', 'Покупатель / контакт (не отправляется)', 'Что входит, условия, поддержка'][i]}><textarea value={draft.offer[field]} maxLength={4000} onChange={e => edit({ offer: { ...draft.offer, [field]: e.target.value } })}/></Field>)}<Field label={'Цена, ' + draft.currency}><input inputMode="decimal" value={offerMoney} onChange={e => { setOfferMoney(e.target.value); setDirty(true); }}/></Field><button className="brand-button primary" disabled={dirty || !!pending} onClick={() => void guard(() => act('create_order'))}>Создать черновик заказа</button><h3>Учёт переменных расходов</h3><div className="core-two"><Field label="Сумма"><input inputMode="decimal" value={cost} onChange={e => setCost(e.target.value)}/></Field><Field label="Категория"><select value={category} onChange={e => setCategory(e.target.value)}>{[['compute', 'Вычисления'], ['payment_fees', 'Платёжные расходы'], ['mentors', 'Наставники'], ['support', 'Поддержка'], ['other', 'Другое']].map(([v, label]) => <option key={v} value={v}>{label}</option>)}</select></Field></div><Field label="Основание расхода"><input value={costNote} maxLength={1000} onChange={e => setCostNote(e.target.value)}/></Field><button className="brand-button" disabled={dirty || !!pending} onClick={() => void guard(async () => { await act('record_cost', { amountMinor: minorUnits(cost), category, note: costNote }); setCost(''); setCostNote(''); })}>Записать расход</button><p>Это запись фактических расходов пользователем. Деньги не списываются. Записи не удаляются при восстановлении старой версии.</p><dl className="core-economics"><div><dt>Учтённые расходы</dt><dd>{moneyFmt(selected.economics.costMinor)}</dd></div><div><dt>Остаток бюджета</dt><dd>{moneyFmt(selected.economics.budgetRemainingMinor)}</dd></div></dl><p>Здесь показаны введённые расходы и остаток бюджета. Подтверждённые платежи, возвраты и расчёт после расходов находятся в блоке оплаты ниже. Черновики не считаются выручкой.</p>{draft.costs.map(c => <p key={c.id}>{c.note} · {c.category} · {moneyFmt(c.amountMinor)}</p>)}<h3>Заказы</h3>{!draft.orders.length && <p>Черновиков пока нет.</p>}{draft.orders.map(o => <div className="core-order" key={o.id}><strong>{o.title}</strong><p>{o.customer} / {moneyFmt(o.amountMinor)} / {o.status === 'draft' ? 'Черновик — не оплачен' : 'Отменён'}</p>{o.status === 'draft' && <button className="brand-button" disabled={dirty || !!pending} onClick={() => void guard(() => act('cancel_order', { orderId: o.id }))}>Отменить черновик</button>}</div>)}</section>}
 {tab === 'memory' && <section className="core-panel"><h2>Управляемая память</h2><p>Храните источник, время проверки и срок актуальности. Эти даты задаёт человек; сервер не проверяет содержание ссылки.</p>{draft.sources.map((s, i) => <div className="core-source" key={s.id}><Field label={'Источник ' + (i + 1)}><input value={s.title} onChange={e => edit({ sources: draft.sources.map(v => v.id === s.id ? { ...v, title: e.target.value } : v) })}/></Field><Field label="URL"><input type="url" value={s.url} onChange={e => edit({ sources: draft.sources.map(v => v.id === s.id ? { ...v, url: e.target.value } : v) })}/></Field><Field label="Контекст и ограничения"><textarea value={s.notes} onChange={e => edit({ sources: draft.sources.map(v => v.id === s.id ? { ...v, notes: e.target.value } : v) })}/></Field><div className="core-two">{(['checkedAt', 'expiresAt'] as const).map((field, n) => <Field key={field} label={n ? 'Актуален до (UTC)' : 'Проверен (UTC)'}><input type="datetime-local" value={s[field].slice(0, 16)} onChange={e => edit({ sources: draft.sources.map(v => v.id === s.id ? { ...v, [field]: e.target.value ? e.target.value + ':00Z' : '' } : v) })}/></Field>)}</div><button className="core-text-button" onClick={() => edit({ sources: draft.sources.filter(v => v.id !== s.id) })}>Удалить источник</button></div>)}<button className="brand-button" disabled={draft.sources.length >= 50} onClick={() => edit({ sources: [...draft.sources, { id: key(), title: 'Новый источник', url: '', notes: '', checkedAt: '', expiresAt: '' }] })}>Добавить источник</button><h3>Решения</h3>{draft.decisions.map(d => <div className="core-source" key={d.id}><small>{new Date(d.at).toLocaleString('ru-RU')}</small><textarea aria-label="Обоснование решения" value={d.text} onChange={e => edit({ decisions: draft.decisions.map(v => v.id === d.id ? { ...v, text: e.target.value } : v) })}/></div>)}<button className="brand-button" disabled={draft.decisions.length >= 50} onClick={() => edit({ decisions: [...draft.decisions, { id: key(), text: 'Новое решение и обоснование', at: new Date().toISOString() }] })}>Записать решение</button></section>}
 {tab === 'results' && <section className="core-panel"><h2>Проверяемые преимущества</h2><p>Сравнивайте одинаковые по сложности задачи. Учитывайте исправления и помощь человека. Данные вводятся вами; независимая верификация не заявляется. Цели 3× и 85% пока не достигнутые показатели.</p><Field label="Повторяемый процесс и условия"><textarea value={observation.task} onChange={e => setObservation(v => ({ ...v, task: e.target.value }))}/></Field><div className="core-two">{(['beforeSeconds', 'afterSeconds', 'correctionSeconds', 'manualSeconds'] as const).map((field, i) => <Field key={field} label={['Время без помощи, секунд', 'Основное время с помощью, секунд', 'Исправления, секунд', 'Помощь человека, секунд'][i]}><input inputMode="numeric" value={observation[field]} onChange={e => setObservation(v => ({ ...v, [field]: e.target.value }))}/></Field>)}</div><Field label="Доказательства, сложность, ограничения"><textarea value={observation.evidence} onChange={e => setObservation(v => ({ ...v, evidence: e.target.value }))}/></Field><label className="core-check"><input type="checkbox" checked={observation.success} onChange={e => setObservation(v => ({ ...v, success: e.target.checked }))}/>Критерии результата выполнены</label><button className="brand-button" disabled={dirty || !!pending} onClick={() => void guard(async () => { const numbers = Object.fromEntries((['beforeSeconds', 'afterSeconds', 'correctionSeconds', 'manualSeconds'] as const).map(k => { if (!/^\d{1,8}$/.test(observation[k]))
                throw new Error('Время: целое число секунд, максимум 8 цифр.'); return [k, Number(observation[k])]; })); await act('record_measurement', { ...observation, ...numbers }); setObservation({ task: '', beforeSeconds: '', afterSeconds: '', correctionSeconds: '0', manualSeconds: '0', success: false, evidence: '' }); })}>Записать наблюдение</button><dl className="core-economics"><div><dt>Размер выборки</dt><dd>{selected.metrics.sampleSize}</dd></div><div><dt>Отношение времени с учётом исправлений и помощи</dt><dd>{selected.metrics.speedRatio === null ? 'Нет данных' : selected.metrics.speedRatio + '×'}</dd></div><div><dt>Доля выполненных задач</dt><dd>{selected.metrics.successRate === null ? 'Нет данных' : (selected.metrics.successRate * 100).toFixed(1) + '%'}</dd></div><div><dt>Учтённые переменные расходы</dt><dd>{moneyFmt(selected.economics.costMinor)}</dd></div></dl>{draft.measurements.map(m => <p key={m.id}>{m.task} / {m.success ? 'Критерии выполнены' : 'Критерии не выполнены'} / {m.beforeSeconds} с → {m.afterSeconds + m.correctionSeconds + m.manualSeconds} с</p>)}</section>}
 {tab === 'history' && <section className="core-panel"><h2>История и совместная работа</h2><button className="brand-button" onClick={() => void guard(loadHistory)}>Загрузить историю и участников</button><p>Обновления проверяют номер версии. Восстановление создаёт новую версию, сохраняя актуальные расходы, заказы и выпуски.</p>{history && <><h3>Версии</h3><div className="core-history">{history.revisions.map(r => <div key={r.version}><span>v{r.version} · {new Date(r.createdAt).toLocaleString('ru-RU')}</span><button className="brand-button" disabled={r.version === selected.version || dirty || !!pending} onClick={() => { if (confirm('Восстановить содержимое версии ' + r.version + '? Текущая версия останется в истории.'))
                void guard(async () => { await mutate('projects/' + selected.id + '/restore', { expectedVersion: selected.version, version: r.version }); }); }}>Восстановить</button></div>)}</div><h3>Журнал действий</h3><ol>{history.events.map(e => <li key={e.id}>{new Date(e.createdAt).toLocaleString('ru-RU')} · {e.kind}<details><summary>Детали</summary><pre>{e.detail}</pre></details></li>)}</ol></>}<h3>Участники</h3><p>Владелец добавляет уже созданные аккаунты по логину. Уведомления не отправляются. Редактор видит и изменяет весь проект; наблюдатель только читает. Удаление личной роли не отменяет доступ через команду.</p>{members.map(m => <p key={m.username}>{m.username} / {m.role} · {m.directRole?'личная роль':'командная роль'}{m.hasTeamAccess&&m.directRole?' + командный доступ':''}</p>)}{selected.role === 'owner' && <><Field label="Логин участника"><input value={member} onChange={e => setMember(e.target.value)}/></Field><Field label="Доступ"><select value={role} onChange={e => setRole(e.target.value)}><option value="viewer">Наблюдатель</option><option value="editor">Редактор</option><option value="remove">Убрать личный доступ</option></select></Field><button className="brand-button" disabled={dirty || !!pending} onClick={() => { if (confirm('Изменить доступ для ' + member + '?'))
                void guard(async () => { await mutate('projects/' + selected.id + '/members', { expectedVersion: selected.version, username: member, role }); }); }}>Применить доступ</button></>}</section>}
 </fieldset>{tab === 'business' && <CommercePanel key={selected.id+':'+selectionKey} project={selected} disabled={busy || dirty || !!pending} onDirty={setReviewDirty} onPrepare={async body=>{if(busyRef.current)throw new Error('Дождитесь текущего запроса.');busyRef.current=true;setBusy(true);try{return await mutate('projects/'+selected.id+'/commerce',body)}finally{busyRef.current=false;setBusy(false)}}}/>}{tab === 'studio' && <CoreReleaseReadiness projectId={selected.id} version={selected.version} studioEnabled={selected.data.consents.studio} hasUnsavedChanges={dirty} disabled={busy || !!pending}/>}{tab === 'history' && <TeamProjectAccess projectId={selected.id} version={selected.version} disabled={busy || dirty || !!pending} onDetach={()=>guard(async()=>{await mutate('projects/'+selected.id+'/team',{expectedVersion:selected.version})})}/>}{tab === 'clients' && <ClientDeliveryPanel key={selected.id+':'+selectionKey} project={selected} disabled={busy || dirty || !!pending} onDirty={setReviewDirty} onCreate={async body=>{if(busyRef.current)throw new Error('Дождитесь текущего запроса.');busyRef.current=true;setBusy(true);try{return await mutate('projects/'+selected.id+'/client-deliveries',body)}finally{busyRef.current=false;setBusy(false)}}}/>}{tab === 'delivery' && <DeliveryPanel key={selected.id+':'+selectionKey} project={selected} userId={user.id} disabled={busy || dirty || !!pending} onDirty={setReviewDirty} onAction={async body=>{if(busyRef.current)throw new Error('Дождитесь текущего запроса.');busyRef.current=true;setBusy(true);try{return await mutate('projects/'+selected.id+'/delivery',body)}finally{busyRef.current=false;setBusy(false)}}}/>}{tab === 'acceptance' && <ReleaseAcceptance key={selected.id+':'+selectionKey} project={selected} userId={user.id} disabled={busy || dirty || !!pending} onDirty={setReviewDirty} onReview={async body=>{if(busyRef.current)throw new Error('Дождитесь текущего запроса.');busyRef.current=true;setBusy(true);try{return await mutate('projects/'+selected.id+'/release-review',body)}finally{busyRef.current=false;setBusy(false)}}}/>}{readonly && tab === 'history' && <button disabled={busy} className="brand-button" onClick={() => void guard(loadHistory)}>Загрузить историю</button>}
 </>}</div></div></>}
 <section className="core-boundaries"><h2>Рубеж пилота</h2><p>Работают аккаунты сервера, проектные роли, версии, прогресс, внутренние проверки, журнал расходов и черновики заказов. Модуль разовой оплаты и доступа к принятому HTML подготовлен и по умолчанию выключен; его текущее состояние видно в Business. AI-наставник, внешнее исполнение и автоматическая публикация не подключены. Показатели «3× быстрее» и «85% успешных задач» — цели испытаний.</p><p><a href="/learning/experiments">Собрать исходный уровень и результаты экспериментов →</a></p></section>
 </main>;
}
