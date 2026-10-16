import { useEffect, useRef, useState } from 'react';
import { coreRequest, CoreError, readPending, storePending, downloadCore } from './coreClient';
import type { CoreUser, PendingOperation } from './coreClient';
import { coreLoginLink } from './accountAccess';
import './coreWorkspace.css';
type Item = {
    id: string;
    title: string;
    version: number;
    status: string;
    supportStatus: string;
    createdAt: string;
};
type Delivery = Item & {
    role: 'recipient' | 'staff';
    recipient?: string;
    materials: {
        title: string;
        description: string;
        instructions: string;
        sourceVersion: number;
        html: string | null;
        sha256: string;
        url: string;
        externalURLVerified: boolean;
        integrityMatches: boolean | null;
    };
    history: {
        id: string;
        actor: string;
        kind: string;
        body: string;
        fromStatus: string;
        toStatus: string;
        createdAt: string;
    }[];
};
const labels: Record<string, string> = { pending: 'Ожидает подтверждения', acknowledged: 'Получение подтверждено', revoked: 'Доступ отозван', none: 'Обсуждения пока нет', open: 'Открыто', active: 'В работе', resolved: 'Решение предложено', closed: 'Закрыто' };
export default function ClientPortal() {
    const [phase, setPhase] = useState<'loading' | 'ready' | 'login' | 'offline'>('loading'), [user, setUser] = useState<CoreUser | null>(null), [items, setItems] = useState<Item[]>([]), [delivery, setDelivery] = useState<Delivery | null>(null), [busy, setBusy] = useState(false), [error, setError] = useState(''), [message, setMessage] = useState(''), [text, setText] = useState(''), [draftVersion, setDraftVersion] = useState<number | null>(null), [preview, setPreview] = useState(false), [pending, setPending] = useState<PendingOperation | null>(readPending), [needsReconnect, setNeedsReconnect] = useState(false), [truncated, setTruncated] = useState(false);
    const accountOwner = useRef<string | null>(null), lock = useRef(false), alert = useRef<HTMLParagraphElement>(null);
    const changed = !!text, stale = changed && draftVersion !== null && delivery?.version !== draftVersion;
    async function list() { const r = await coreRequest<{
        deliveries: Item[];
        truncated: boolean;
    }>('deliveries'); setItems(r.deliveries); setTruncated(r.truncated); }
    async function fetchOne(id: string) { const r = await coreRequest<{
        delivery: Delivery;
    }>('deliveries/' + id); setDelivery(r.delivery); return r.delivery; }
    async function run(work: () => Promise<void>) { if (lock.current)
        return; lock.current = true; setBusy(true); setError(''); setMessage(''); try {
        await work();
    }
    catch (e) {
        setError(e instanceof Error ? e.message : 'Не удалось выполнить действие.');
        if (e instanceof CoreError && e.status === 401) {
            setUser(null);
            setItems([]);
            setDelivery(null);
            setText('');
            setPhase('login');
        }
        else if (e instanceof CoreError && e.status === 404) {
            setDelivery(null);
            setText('');
            setDraftVersion(null);
            setPreview(false);
        }
    }
    finally {
        lock.current = false;
        setBusy(false);
    } }
    async function connect() { try {
        const u = (await coreRequest<{
            user: CoreUser;
        }>('auth/me')).user;
        if (accountOwner.current && accountOwner.current !== u.id) {
            setDelivery(null);
            setText('');
            setDraftVersion(null);
            setPreview(false);
        }
        accountOwner.current = u.id;
        setUser(u);
        await list();
        setPhase('ready');
        const id = new URLSearchParams(location.search).get('delivery');
        if (id && /^[a-f0-9]{32}$/.test(id))
            await fetchOne(id);
        setNeedsReconnect(false);
    }
    catch (e) {
        if (e instanceof CoreError && e.status === 401) {
            setUser(null);
            setDelivery(null);
            setItems([]);
            setPhase('login');
        }
        else if (e instanceof CoreError && e.status === 404) {
            setDelivery(null);
            setError('Передача недоступна или отозвана.');
        }
        else {
            setPhase('offline');
            setError(e instanceof Error ? e.message : 'Сервер недоступен.');
        }
    } }
    useEffect(() => { void run(connect); }, []);
    useEffect(() => { const resume = (e: PageTransitionEvent) => { if (e.persisted) {
        if (changed) {
            setNeedsReconnect(true);
            setError('Проверьте аккаунт и обновите передачу перед отправкой сохранённого текста.');
        }
        else
            void run(connect);
    } }; window.addEventListener('pageshow', resume); return () => window.removeEventListener('pageshow', resume); }, [changed]);
    useEffect(() => { if (error)
        alert.current?.focus(); }, [error]);
    useEffect(() => { const leave = (e: BeforeUnloadEvent) => { if (changed) {
        e.preventDefault();
        e.returnValue = '';
    } }; window.addEventListener('beforeunload', leave); return () => window.removeEventListener('beforeunload', leave); }, [changed]);
    async function mutate(body: Record<string, unknown>, retry?: PendingOperation) { if (!user || !delivery && !retry)
        throw Error('Откройте передачу.'); const operation = retry || { route: 'deliveries/' + delivery!.id, key: crypto.randomUUID(), userId: user.id, body: { ...body, expectedVersion: draftVersion ?? delivery!.version } }; if (operation.userId !== user.id)
        throw Error('Запрос принадлежит другому аккаунту.'); if (pending && !retry)
        throw Error('Сначала разрешите незавершённый запрос.'); setPending(operation); storePending(operation); try {
        await coreRequest(operation.route, operation.body, operation.key);
        setPending(null);
        storePending(null);
        setText('');
        setDraftVersion(null);
        await list();
        await fetchOne(operation.route.split('/')[1]);
        setMessage('Действие сохранено. Оплата и внешние уведомления не выполнялись.');
    }
    catch (e) {
        if (e instanceof CoreError && e.status >= 400 && e.status < 500) {
            setPending(null);
            storePending(null);
        }
        throw e;
    } }
    const blocked = busy || !!pending || stale || needsReconnect;
    return <main className="brand-container core-workspace"><section className="core-intro"><p className="brand-eyebrow">OSGARD BUSINESS / RECEIVED MATERIALS</p><h1>Ваш результат.<br /><em>Его продолжение.</em></h1><p className="brand-lead">Полученные материалы и обсуждение по конкретному выпуску. Кабинет не открывает внутренний проект и не принимает платежи.</p><div className="brand-actions"><a className="brand-button" href="/workspace/overview">Рабочий центр</a><a className="brand-button" href="/account">Аккаунт и доступ</a></div></section><p ref={alert} tabIndex={-1} role={error ? 'alert' : undefined} hidden={!error} className="core-alert">{error}</p><p role="status">{busy ? 'Выполняем запрос…' : message}</p>{phase === 'loading' && <p>Подключаем кабинет…</p>}{phase === 'login' && <section className="core-panel"><h2>Войдите в свой аккаунт</h2><a className="brand-button primary" href={coreLoginLink('/deliveries' + location.search)}>Войти и вернуться</a></section>}{phase === 'offline' && <section className="core-panel"><h2>Нужен сервер Core</h2><p>Изолированные передачи доступны в полном серверном комплекте. Статический хостинг не исполняет этот API.</p><button className="brand-button" onClick={() => void run(connect)}>Повторить подключение</button></section>}
 {phase === 'ready' && user && <><section className="core-panel"><h2>Получено аккаунтом {user.username}</h2><button className="brand-button" disabled={busy} onClick={() => void run(async () => { await connect(); if (delivery)
            await fetchOne(delivery.id); })}>Обновить состояние</button>{truncated && <p className="core-alert">Показаны первые 200 активных передач. Для остальных используйте адрес конкретной передачи.</p>}{!items.length && <p>Активных передач этому аккаунту пока нет. Если команда дала вам ссылку, откройте её под тем же логином.</p>}{items.map(i => <article className="core-source" key={i.id}><strong>{i.title}</strong><p>{labels[i.status]} · {labels[i.supportStatus]}</p><button className="brand-button" disabled={busy} onClick={() => { if (changed && !confirm('Закрыть несохранённый текст?'))
            return; setText(''); setDraftVersion(null); setPreview(false); void run(async () => { await fetchOne(i.id); }); }}>Открыть материалы</button></article>)}</section>
 {pending && <section className="core-panel"><h2>Незавершённый запрос</h2><p>Ответ мог потеряться после сохранения. Повтор использует исходный ключ. Текст этого запроса временно хранится в сессии вкладки. Запрос из другого раздела разрешите в рабочем пространстве.</p><button className="brand-button" disabled={busy || pending.userId !== user.id || !/^deliveries\/[a-f0-9]{32}$/.test(pending.route)} onClick={() => void run(() => mutate({}, pending))}>Повторить тот же запрос</button><a className="brand-button" href="/workspace">Открыть рабочее пространство</a><button className="brand-button" disabled={busy} onClick={() => void run(async () => { await list(); if (delivery)
            await fetchOne(delivery.id); if (confirm('Запрос не отменён. Вы проверили актуальные материалы и историю и хотите убрать его из ожидания?')) {
            setPending(null);
            storePending(null);
        } })}>Проверить данные</button></section>}
 {delivery && <section className="core-panel"><p className="brand-eyebrow">DELIVERY / {delivery.id.slice(0, 8)} / v{delivery.version}</p><h2>{delivery.materials.title}</h2><p>{labels[delivery.status]} · {delivery.role === 'staff' ? 'Вы просматриваете передачу как редактор проекта' : 'Вы — получатель материалов'}</p><p className="client-copy">{delivery.materials.description}</p><h3>Как использовать</h3><p className="client-copy">{delivery.materials.instructions}</p><p>Исходная версия выпуска: {delivery.materials.sourceVersion}. Внешние ссылки сервер не проверял.</p><button className="brand-button" onClick={() => downloadCore(delivery, 'osgard-received-' + delivery.id + '.json')}>Скачать материалы и историю JSON</button><p>Отзыв закрывает будущий доступ к серверу. Ранее скачанные копии удалить у получателя невозможно.</p>{delivery.materials.html !== null ? <><p>{delivery.materials.integrityMatches ? 'SHA-256 переданного HTML совпадает.' : 'SHA-256 не совпадает: сообщите команде.'}</p><p className="release-checksum">{delivery.materials.sha256}</p><button className="brand-button" onClick={() => setPreview(v => !v)}>{preview ? 'Скрыть HTML' : 'Открыть переданный HTML'}</button>{preview && <iframe className="core-preview" title="Переданный HTML без доступа к проекту" sandbox="" srcDoc={delivery.materials.html}/>}</> : delivery.materials.url && <a className="brand-button" href={delivery.materials.url} target="_blank" rel="noopener noreferrer">Открыть переданную внешнюю ссылку</a>}
 {delivery.status === 'pending' && delivery.role === 'recipient' && <button className="brand-button primary" disabled={blocked || changed} onClick={() => void run(() => mutate({ action: 'acknowledge' }))}>Подтвердить получение материалов</button>}{stale && <div className="core-alert"><p>Версия изменилась. Текст сохранён на экране; обновите передачу и проверьте историю перед новым действием.</p><button className="brand-button" disabled={busy||!!pending||needsReconnect} onClick={()=>{if(confirm('Вы сверили обновлённые материалы и историю и хотите использовать сохранённый текст для текущей версии?'))setDraftVersion(delivery.version)}}>Использовать текст после сверки</button></div>}
 <h3>Обсуждение · {labels[delivery.supportStatus]}</h3>{delivery.history.map(h => <article className="delivery-message" key={h.id}><strong>{h.actor}</strong><small>{new Date(h.createdAt).toLocaleString('ru-RU')}</small>{h.body && <p>{h.body}</p>}{h.toStatus && <p>{labels[h.fromStatus] || h.fromStatus} → {labels[h.toStatus] || h.toStatus}</p>}</article>)}{delivery.status !== 'revoked' && <><label className="core-field"><span>Сообщение или основание действия — минимум 10 символов</span><textarea disabled={busy || !!pending} minLength={10} maxLength={4000} value={text} onChange={e => { if (!e.target.value)
                setDraftVersion(null);
            else if (draftVersion === null)
                setDraftVersion(delivery.version); setText(e.target.value); }}/></label>{text && <button className="brand-button" onClick={() => { if (confirm('Убрать несохранённый текст?')) {
                setText('');
                setDraftVersion(null);
            } }}>Очистить черновик</button>}<button className="brand-button" disabled={blocked || text.trim().length < 10 || delivery.supportStatus === 'closed'} onClick={() => void run(() => mutate({ action: 'message', body: text }))}>Сохранить сообщение</button>{(({ none: [], open: ['active', 'resolved'], active: ['resolved'], resolved: ['open', 'closed'], closed: ['open'] } as Record<string, string[]>)[delivery.supportStatus] || []).filter(s => delivery.role === 'staff' || s === 'open' || s === 'closed').map(s => <button key={s} className="brand-button" disabled={blocked || text.trim().length < 10 || text.trim().length > 2000} onClick={() => void run(() => mutate({ action: 'support_status', status: s, body: text }))}>{labels[s]}</button>)}{delivery.role === 'staff' && <button className="brand-button" disabled={blocked || text.trim().length < 10 || text.trim().length > 2000} onClick={() => { if (confirm('Отозвать весь дальнейший доступ получателя к этой передаче?'))
                void run(() => mutate({ action: 'revoke', body: text })); }}>Отозвать доступ</button>}</>}
 </section>}</>}
 </main>;
}
