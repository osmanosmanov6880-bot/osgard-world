import { useEffect, useRef, useState } from 'react';
import { coreRequest, downloadCore } from './coreClient';
import type { CoreProject } from './coreClient';
type Handoff = {
    id: string;
    releaseId: string;
    sourceVersion: number;
    creatorId: string;
    creator: string;
    recipientId: string;
    recipient: string;
    reviewId: string;
    note: string;
    status: 'pending' | 'acknowledged' | 'withdrawn';
    recipientHasAccess: boolean;
    latestReviewVerdict: string | null;
    reviewStillLatest: boolean;
};
type Ticket = {
    id: string;
    handoffId: string;
    requesterId: string;
    requester: string;
    title: string;
    status: string;
    messageCount: number;
    messages?: {
        id: string;
        actor: string;
        body: string;
        createdAt: string;
    }[];
    transitions?: {
        id: string;
        actor: string;
        fromStatus: string;
        toStatus: string;
        note: string;
        createdAt: string;
    }[];
};
type Delivery = {
    projectVersion: number;
    handoffs: Handoff[];
    tickets: Ticket[];
    participants: {
        id: string;
        username: string;
        role: string;
    }[];
};
type Release = {
    id: string;
    sourceVersion: number | null;
    latestReview: {
        verdict: string;
    } | null;
};
const labels: Record<string, string> = { pending: 'Ожидает подтверждения', acknowledged: 'Получение подтверждено', withdrawn: 'Отозвана', open: 'Открыто', active: 'В работе', resolved: 'Решение предложено', closed: 'Закрыто' };
export default function DeliveryPanel({ project, userId, disabled, onDirty, onAction }: {
    project: CoreProject;
    userId: string;
    disabled: boolean;
    onDirty: (v: boolean) => void;
    onAction: (v: Record<string, unknown>) => Promise<unknown>;
}) {
    const [data, setData] = useState<Delivery | null>(null), [releases, setReleases] = useState<Release[]>([]), [ticket, setTicket] = useState<Ticket | null>(null), [busy, setBusy] = useState(false), [error, setError] = useState(''), [message, setMessage] = useState(''), [loading, setLoading] = useState(true);
    const [draft, setDraft] = useState({ releaseId: '', recipient: '', note: '', handoffId: '', title: '', body: '', reply: '', statusNote: '' }), [draftVersion, setDraftVersion] = useState<number | null>(null), [formMode, setFormMode] = useState<string | null>(null);
    const ref = useRef<HTMLParagraphElement>(null), lock = useRef(false), sequence = useRef(0);
    const writer = project.role !== 'viewer', changed = draftVersion !== null, stale = changed && draftVersion !== project.version;
    useEffect(() => { onDirty(changed); return () => onDirty(false); }, [changed, onDirty]);
    useEffect(() => { if (error)
        ref.current?.focus(); }, [error]);
    useEffect(() => { const leave = (e: BeforeUnloadEvent) => { if (changed) {
        e.preventDefault();
        e.returnValue = '';
    } }; window.addEventListener('beforeunload', leave); return () => window.removeEventListener('beforeunload', leave); }, [changed]);
    function edit(changes: Partial<typeof draft>) { const k = Object.keys(changes)[0], mode = ['releaseId', 'recipient', 'note'].includes(k) ? 'handoff' : ['handoffId', 'title', 'body'].includes(k) ? 'ticket' : k === 'reply' ? 'reply' : 'status'; if (formMode && mode !== formMode) {
        if (!confirm('Перейти к другой форме без сохранения текущего текста?'))
            return;
        setDraft({ releaseId: '', recipient: '', note: '', handoffId: '', title: '', body: '', reply: '', statusNote: '', ...changes });
        setDraftVersion(data?.projectVersion ?? project.version);
    }
    else
        setDraft(v => ({ ...v, ...changes })); setFormMode(mode); if (draftVersion === null)
        setDraftVersion(data?.projectVersion ?? project.version); }
    function clear() { setDraft({ releaseId: '', recipient: '', note: '', handoffId: '', title: '', body: '', reply: '', statusNote: '' }); setDraftVersion(null); setFormMode(null); }
    async function load() { const d = await coreRequest<Delivery>('projects/' + project.id + '/delivery'); setData(d); if (project.data.consents.studio) {
        const r = await coreRequest<{
            releases: Release[];
        }>('projects/' + project.id + '/releases');
        setReleases(r.releases);
    }
    else
        setReleases([]); if (ticket) {
        const r = await coreRequest<{
            ticket: Ticket;
        }>('projects/' + project.id + '/delivery/tickets/' + ticket.id);
        setTicket(r.ticket);
    } }
    async function run(work: () => Promise<void>) { if (lock.current)
        return; lock.current = true; setBusy(true); setError(''); setMessage(''); try {
        await work();
    }
    catch (e) {
        setError(e instanceof Error ? e.message : 'Не удалось выполнить действие.');
    }
    finally {
        lock.current = false;
        setBusy(false);
    } }
    useEffect(() => { const id = ++sequence.current; setLoading(true); void coreRequest<Delivery>('projects/' + project.id + '/delivery').then(d => { if (sequence.current === id)
        setData(d); }).catch(e => { if (sequence.current === id)
        setError(e.message); }).finally(() => { if (sequence.current === id)
        setLoading(false); }); if (project.data.consents.studio)
        void coreRequest<{
            releases: Release[];
        }>('projects/' + project.id + '/releases').then(r => { if (sequence.current === id)
            setReleases(r.releases); }).catch(() => { }); return () => { sequence.current++; }; }, [project.id, project.version]);
    async function action(body: Record<string, unknown>) { await onAction({ ...body, expectedVersion: draftVersion ?? data?.projectVersion ?? project.version }); clear(); await load(); setMessage('Изменения сохранены. Уведомления и деньги не отправлялись.'); }
    async function openTicket(id: string) { if (changed && !confirm('Закрыть несохранённый текст?'))
        return; await run(async () => { const r = await coreRequest<{
        ticket: Ticket;
        projectVersion: number;
    }>('projects/' + project.id + '/delivery/tickets/' + id); clear(); setTicket(r.ticket); setData(d => d ? { ...d, projectVersion: r.projectVersion } : d); }); }
    const blocked = busy || disabled || stale;
    const statuses = ticket ? ({ open: ['active', 'resolved'], active: ['resolved'], resolved: ['open', 'closed'], closed: ['open'] } as Record<string, string[]>)[ticket.status] || [] : [];
    return <section className="core-panel"><p className="brand-eyebrow">BUSINESS / HANDOFF & SUPPORT</p><h2>Передать результат и довести до решения</h2><p>Передача фиксирует выпуск и его положительный разбор. Получатель уже должен иметь доступ к проекту. Подтверждение означает получение материалов, а не покупку, оплату или независимую приёмку.</p><p>Никакие приглашения, письма и внешние ссылки доступа не создаются. Участники видят общий проект в пределах выданной роли.</p><p ref={ref} tabIndex={-1} role={error ? 'alert' : undefined} hidden={!error} className="core-alert">{error}</p><p role="status">{loading || busy ? 'Загружаем состояние передачи…' : message}</p><button className="brand-button" disabled={busy || disabled} onClick={() => void run(load)}>Обновить передачи и обращения</button>{changed && <button className="brand-button" disabled={busy} onClick={() => { if (confirm('Убрать несохранённый текст?'))
        clear(); }}>Очистить черновик</button>}{stale && <p className="core-alert">Проект изменился. Текст сохранён на экране; перед новой отправкой обновите проект и проверьте данные.</p>}
 {writer && data && <form onSubmit={e => { e.preventDefault(); void run(() => action({ action: 'handoff', releaseId: draft.releaseId, recipient: draft.recipient, note: draft.note })); }}><fieldset disabled={blocked || !project.data.consents.studio} className="core-editor"><legend>Передать проверенный выпуск</legend><label className="core-field"><span>Выпуск с последним положительным разбором</span><select required value={draft.releaseId} onChange={e => edit({ releaseId: e.target.value })}><option value="">Выберите выпуск</option>{releases.filter(r => r.latestReview?.verdict === 'accepted').map(r => <option key={r.id} value={r.id}>{r.id.slice(0, 8)} · исходная версия {r.sourceVersion}</option>)}</select></label><label className="core-field"><span>Получатель — существующий участник проекта</span><select required value={draft.recipient} onChange={e => edit({ recipient: e.target.value })}><option value="">Выберите участника</option>{data.participants.filter(p => p.id !== userId).map(p => <option key={p.id} value={p.username}>{p.username} · {p.role}</option>)}</select></label><label className="core-field"><span>Что передаётся, как открыть и что делать дальше</span><textarea required minLength={20} maxLength={2000} value={draft.note} onChange={e => edit({ note: e.target.value })}/></label><button className="brand-button primary">Зафиксировать передачу</button></fieldset></form>}
 <h3>Передачи</h3>{data && !data.handoffs.length && <p>Передач пока нет. Подготовьте выпуск, получите разбор другого редактора и выберите участника.</p>}{data?.handoffs.map(h => <article className="core-source" key={h.id}><h4>Выпуск {h.releaseId.slice(0, 8)} · v{h.sourceVersion}</h4><p>{h.creator} → {h.recipient} · {labels[h.status]}</p><p>{h.note}</p>{!h.recipientHasAccess && <p className="core-alert">У получателя больше нет доступа к проекту. Передача не восстанавливает права.</p>}<p>Разбор при передаче: {h.reviewId.slice(0, 8)}.</p>{h.latestReviewVerdict === 'needs_changes' && <p className="core-alert">После передачи появились замечания к этому выпуску. Подтверждение получения их не отменяет.</p>}<div className="brand-actions"><button className="brand-button" disabled={busy} onClick={() => void run(async () => downloadCore(await coreRequest('projects/' + project.id + '/releases/' + h.releaseId), 'osgard-handoff-' + h.id + '.json'))}>Скачать материалы выпуска</button>{h.status === 'pending' && h.recipientId === userId && <button className="brand-button primary" disabled={blocked || changed} onClick={() => void run(() => action({ action: 'acknowledge', handoffId: h.id }))}>Подтвердить получение</button>}{h.status !== 'withdrawn' && (project.role === 'owner' || h.creatorId === userId && writer) && <button className="brand-button" disabled={blocked || changed} onClick={() => { if (confirm('Отозвать передачу? Материалы проекта и существующие обращения сохранятся.'))
        void run(() => action({ action: 'withdraw', handoffId: h.id })); }}>Отозвать передачу</button>}</div></article>)}
 {data && <form onSubmit={e => { e.preventDefault(); void run(() => action({ action: 'ticket', handoffId: draft.handoffId, title: draft.title, body: draft.body })); }}><fieldset disabled={blocked} className="core-editor"><legend>Обратиться по переданному выпуску</legend><label className="core-field"><span>Действующая передача</span><select required value={draft.handoffId} onChange={e => edit({ handoffId: e.target.value })}><option value="">Выберите передачу</option>{data.handoffs.filter(h => h.status !== 'withdrawn' && (writer || h.recipientId === userId)).map(h => <option key={h.id} value={h.id}>{h.releaseId.slice(0, 8)} → {h.recipient}</option>)}</select></label><label className="core-field"><span>Кратко о проблеме</span><input required minLength={5} maxLength={160} value={draft.title} onChange={e => edit({ title: e.target.value })}/></label><label className="core-field"><span>Шаги, ожидаемый и фактический результат</span><textarea required minLength={20} maxLength={4000} value={draft.body} onChange={e => edit({ body: e.target.value })}/></label><button className="brand-button">Создать обращение</button></fieldset></form>}
 <h3>Обращения</h3>{data && !data.tickets.length && <p>Доступных обращений пока нет.</p>}{data?.tickets.map(t => <article className="core-source" key={t.id}><strong>{t.title}</strong><p>{labels[t.status]} · {t.requester} · сообщений: {t.messageCount}</p><button className="brand-button" disabled={busy || disabled} onClick={() => void openTicket(t.id)}>Открыть переписку</button></article>)}
 {ticket && <article className="core-source"><h3>{ticket.title}</h3><p>{labels[ticket.status]} · {ticket.requester}</p><button className="brand-button" onClick={() => downloadCore(ticket, 'osgard-support-' + ticket.id + '.json')}>Скачать историю обращения</button>{ticket.messages?.map(m => <div className="delivery-message" key={m.id}><strong>{m.actor}</strong><small>{new Date(m.createdAt).toLocaleString('ru-RU')}</small><p>{m.body}</p></div>)}{ticket.status !== 'closed' && <form onSubmit={e => { e.preventDefault(); void run(() => action({ action: 'reply', ticketId: ticket.id, body: draft.reply })); }}><fieldset disabled={blocked} className="core-editor"><legend>Ответить</legend><label className="core-field"><span>Сообщение</span><textarea required minLength={10} maxLength={4000} value={draft.reply} onChange={e => edit({ reply: e.target.value })}/></label><button className="brand-button">Сохранить ответ</button></fieldset></form>}
 <fieldset disabled={blocked} className="core-editor"><legend>Изменить статус</legend><label className="core-field"><span>Основание изменения — от 10 символов</span><textarea minLength={10} maxLength={2000} value={draft.statusNote} onChange={e => edit({ statusNote: e.target.value })}/></label>{statuses.filter(s => writer || s === 'open' || s === 'closed').map(s => <button className="brand-button" key={s} disabled={draft.statusNote.trim().length < 10} onClick={() => void run(() => action({ action: 'ticket_status', ticketId: ticket.id, status: s, note: draft.statusNote }))}>{labels[s]}</button>)}</fieldset><details><summary>История статусов</summary>{!ticket.transitions?.length && <p>Статус ещё не менялся.</p>}{ticket.transitions?.map(t => <p key={t.id}>{t.actor}: {labels[t.fromStatus]} → {labels[t.toStatus]} · {t.note}</p>)}</details></article>}
 </section>;
}
