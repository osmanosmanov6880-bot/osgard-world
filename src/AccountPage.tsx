import { useEffect, useRef, useState } from 'react';
import { coreRequest, CoreError, setCoreToken } from './coreClient';
import type { CoreUser } from './coreClient';
import { coreLoginLink, downloadRecovery } from './accountAccess';
import './coreWorkspace.css';
type Security = {
    sessions: {
        id: string;
        current: boolean;
        expiresAt: string;
        createdAt: string | null;
        label: string;
    }[];
    recoveryRemaining: number;
    recoveryBatch: {
        id: string;
        activatedAt: string;
    } | null;
    events: {
        id: number;
        kind: string;
        detail: unknown;
        at: string;
    }[];
    emailRecovery: boolean;
    mfa: boolean;
};
type Preview = {
    batchId: string;
    confirmation: string;
    codes: string[];
    expiresInSeconds: number;
};
export default function AccountPage() {
    const [user, setUser] = useState<CoreUser | null>(null), [security, setSecurity] = useState<Security | null>(null), [phase, setPhase] = useState<'loading' | 'ready' | 'login' | 'offline'>('loading'), [busy, setBusy] = useState(false), [error, setError] = useState(''), [message, setMessage] = useState(''), [current, setCurrent] = useState(''), [next, setNext] = useState(''), [repeat, setRepeat] = useState(''), [preview, setPreview] = useState<Preview | null>(null), [saved, setSaved] = useState(false), [activated, setActivated] = useState(false), [recovery, setRecovery] = useState({ username: '', code: '', password: '', repeat: '' });
    const accountOwner = useRef<string | null>(null);
    const lock = useRef(false), errorRef = useRef<HTMLDivElement>(null);
    const dirty = !!(current || next || repeat || recovery.code || recovery.password || preview && !activated);
    async function load() { await coreRequest('health'); const u = (await coreRequest<{
        user: CoreUser;
    }>('auth/me')).user; const s = await coreRequest<Security>('auth/security'); if (accountOwner.current && accountOwner.current !== u.id) {
        setPreview(null);
        setCurrent('');
        setNext('');
        setRepeat('');
        setRecovery({ username: '', code: '', password: '', repeat: '' });
    } accountOwner.current = u.id; setUser(u); setSecurity(s); setPhase('ready'); }
    async function run(work: () => Promise<void>) { if (lock.current)
        return; lock.current = true; setBusy(true); setError(''); setMessage(''); try {
        await work();
    }
    catch (e) {
        setError(e instanceof Error ? e.message : 'Не удалось выполнить действие.');
        if (e instanceof CoreError && e.status === 401) {
            setUser(null);
            setSecurity(null);
            setPreview(null);
            setCurrent('');
            setNext('');
            setRepeat('');
            setPhase('login');
        }
        else if (e instanceof CoreError && (e.code === 'server_offline' || e.code === 'connection' && !security))
            setPhase('offline');
    }
    finally {
        lock.current = false;
        setBusy(false);
    } }
    useEffect(() => { void run(load); const resume = (event: PageTransitionEvent) => { if (event.persisted)
        void run(load); }; window.addEventListener('pageshow', resume); return () => window.removeEventListener('pageshow', resume); }, []);
    useEffect(() => { if (error)
        errorRef.current?.focus(); }, [error]);
    useEffect(() => { const leave = (e: BeforeUnloadEvent) => { if (dirty) {
        e.preventDefault();
        e.returnValue = '';
    } }; window.addEventListener('beforeunload', leave); return () => window.removeEventListener('beforeunload', leave); }, [dirty]);
    const events: Record<string, string> = { session_started: 'Начата сессия', password_changed: 'Пароль изменён', session_revoked: 'Сессия отозвана', other_sessions_revoked: 'Другие сессии отозваны', recovery_prepared: 'Подготовлен набор кодов', recovery_activated: 'Набор кодов активирован', account_recovered: 'Доступ восстановлен, старые сессии и коды отозваны' };
    return <main className="brand-container core-workspace"><section className="core-intro"><p className="brand-eyebrow">OSGARD CORE / ACCOUNT ACCESS</p><h1>Доступ под<br /><em>вашим контролем.</em></h1><p className="brand-lead">Управляйте сессиями, меняйте пароль и подготовьте резервный способ входа в ваш серверный аккаунт.</p><div className="brand-actions"><a className="brand-button" href="/workspace">Рабочее пространство</a><a className="brand-button" href="/learning/organizer">Очередь разборов</a></div></section>
 <div ref={errorRef} tabIndex={-1} role={error ? 'alert' : undefined} hidden={!error} className="core-alert">{error}</div><p role="status" className="core-status">{busy ? 'Выполняем запрос…' : message}</p>
 {phase === 'loading' && <p>Проверяем подключение к Core…</p>}{phase === 'offline' && <section className="core-panel"><h2>Подключите Core</h2><p>Управление аккаунтом работает в серверном режиме полного архива. Запустите START-CORE-WINDOWS.bat.</p><button disabled={busy} className="brand-button" onClick={() => void run(load)}>Проверить снова</button></section>}
 {phase === 'login' && <section className="core-panel"><h2>Войдите в аккаунт</h2><p>Для управления доступом требуется действующая сессия.</p><a className="brand-button primary" href={coreLoginLink('/account')}>Войти и вернуться сюда</a></section>}
 {phase === 'ready' && security && user && <><section className="core-account"><strong>{user.username}</strong><button disabled={busy} className="brand-button" onClick={() => void run(load)}>Обновить сессии и журнал</button></section><section className="core-panel"><h2>Сессии аккаунта</h2><p>Показаны только ваши действующие сессии. Название приложения приходит от браузера и не подтверждает личность устройства.</p>{security.sessions.map(s => <article className="core-source" key={s.id}><strong>{s.current ? 'Текущая сессия' : 'Другая сессия'}</strong><p>{s.label}</p><p>{s.createdAt ? 'Начата ' + new Date(s.createdAt).toLocaleString('ru-RU') : 'Дата начала не записана'} · завершится {new Date(s.expiresAt).toLocaleString('ru-RU')}</p><button disabled={busy} className="brand-button" onClick={() => { if (!confirm(s.current ? 'Завершить текущую сессию?' : 'Отозвать эту сессию?'))
            return; void run(async () => { const r = await coreRequest<{
            current: boolean;
        }>('auth/sessions/revoke', { sessionId: s.id }); if (r.current) {
            setCoreToken('');
            setSecurity(null);
            setUser(null);
            setPhase('login');
        }
        else {
            await load();
            setMessage('Сессия отозвана.');
        } }); }}>{s.current ? 'Выйти из этой сессии' : 'Отозвать сессию'}</button></article>)}<button disabled={busy || security.sessions.length < 2} className="brand-button" onClick={() => { if (confirm('Завершить все сессии, кроме текущей?'))
            void run(async () => { await coreRequest('auth/sessions/revoke-others', {}); await load(); setMessage('Остальные сессии завершены.'); }); }}>Завершить остальные сессии</button></section>
 <section className="core-panel"><h2>Сменить пароль</h2><p>После смены пароля остальные сессии завершатся. Текущая останется действующей. Активированные резервные коды сохранятся.</p><form onSubmit={e => { e.preventDefault(); void run(async () => { if (next !== repeat)
            throw new Error('Новые пароли не совпадают.'); await coreRequest('auth/password', { currentPassword: current, newPassword: next }); setCurrent(''); setNext(''); setRepeat(''); setPreview(null); await load(); setMessage('Пароль изменён. Остальные сессии отозваны.'); }); }}><label className="core-field"><span>Текущий пароль</span><input required disabled={busy} type="password" autoComplete="current-password" minLength={12} maxLength={256} value={current} onChange={e => setCurrent(e.target.value)}/></label><div className="core-two"><label className="core-field"><span>Новый пароль — от 12 символов</span><input required disabled={busy} type="password" autoComplete="new-password" minLength={12} maxLength={256} value={next} onChange={e => setNext(e.target.value)}/></label><label className="core-field"><span>Повторите новый пароль</span><input required disabled={busy} type="password" autoComplete="new-password" minLength={12} maxLength={256} value={repeat} onChange={e => setRepeat(e.target.value)}/></label></div><button disabled={busy} className="brand-button primary">Сменить пароль</button></form></section>
 <section className="core-panel"><h2>Резервные коды</h2><p>Активных кодов: {security.recoveryRemaining}. {security.recoveryBatch ? 'Набор ' + security.recoveryBatch.id.slice(0, 8) + ' активирован ' + new Date(security.recoveryBatch.activatedAt).toLocaleString('ru-RU') : 'Набор ещё не активирован.'}</p><p>Код позволяет сменить пароль без старого пароля. Сервер хранит только хеши и не показывает коды повторно. Почтовое восстановление и MFA не подключены.</p>{!preview ? <form onSubmit={e => { e.preventDefault(); void run(async () => { const r = await coreRequest<Preview>('auth/recovery/prepare', { currentPassword: current }); setPreview(r); setSaved(false); setActivated(false); setCurrent(''); setMessage('Набор подготовлен, но ещё не активен. Сохраните коды и подтвердите активацию.'); }); }}><label className="core-field"><span>Подтвердите текущий пароль</span><input required type="password" autoComplete="current-password" minLength={12} maxLength={256} disabled={busy} value={current} onChange={e => setCurrent(e.target.value)}/></label><button disabled={busy} className="brand-button">Подготовить новый набор</button></form> : <><p>Набор: {preview.batchId}. Для активации есть 10 минут с момента подготовки.</p><pre className="account-codes">{preview.codes.join('\n')}</pre><button className="brand-button" disabled={busy} onClick={() => downloadRecovery(user.username, preview.batchId, preview.codes)}>Скачать коды в TXT</button><p>Файл даёт возможность восстановить доступ. Храните его отдельно от пароля и вне общих папок.</p>{!activated && <><label className="core-check"><input disabled={busy} type="checkbox" checked={saved} onChange={e => setSaved(e.target.checked)}/>Я сохранил этот набор в безопасном месте</label><button disabled={busy || !saved} className="brand-button primary" onClick={() => void run(async () => { await coreRequest('auth/recovery/activate', { batchId: preview.batchId, confirmation: preview.confirmation }); setActivated(true); await load(); setMessage('Набор активирован. Предыдущие коды больше не работают.'); })}>Активировать сохранённый набор</button></>}<button disabled={busy} className="brand-button" onClick={() => { if (activated || confirm('Закрыть подготовленный набор? Без активации действующие коды не меняются.')) {
            setPreview(null);
            setSaved(false);
            setActivated(false);
        } }}>{activated ? 'Скрыть коды с экрана' : 'Закрыть без активации'}</button></>}</section>
 <section className="core-panel"><h2>История доступа</h2>{!security.events.length && <p>Записей пока нет.</p>}<ol>{security.events.map(e => <li key={e.id}>{new Date(e.at).toLocaleString('ru-RU')} · {events[e.kind] || e.kind}</li>)}</ol><p>Показаны последние 50 записей. Пароли, токены и коды в журнал не записываются.</p></section></>}
 {phase !== 'offline' && <section className="core-panel"><h2>Восстановить пароль по коду</h2><p>Нужен заранее активированный резервный код. После восстановления все старые сессии и все коды старого набора станут недействительными. Затем войдите с новым паролем и подготовьте новый набор.</p><form onSubmit={e => { e.preventDefault(); void run(async () => { if (recovery.password !== recovery.repeat)
        throw new Error('Новые пароли не совпадают.'); await coreRequest('auth/recover', { username: recovery.username, code: recovery.code, newPassword: recovery.password }); setCoreToken(''); setUser(null); setSecurity(null); setPreview(null); setRecovery({ username: recovery.username, code: '', password: '', repeat: '' }); setPhase('login'); setMessage('Пароль восстановлен. Войдите с новым паролем; старые сессии и коды отозваны.'); }); }}><label className="core-field"><span>Логин аккаунта</span><input required minLength={3} maxLength={64} autoComplete="username" value={recovery.username} disabled={busy} onChange={e => setRecovery(v => ({ ...v, username: e.target.value }))}/></label><label className="core-field"><span>Один резервный код</span><input required maxLength={100} autoComplete="off" spellCheck={false} value={recovery.code} disabled={busy} onChange={e => setRecovery(v => ({ ...v, code: e.target.value }))}/></label><div className="core-two">{(['password', 'repeat'] as const).map((field, i) => <label className="core-field" key={field}><span>{i ? 'Повторите новый пароль' : 'Новый пароль'}</span><input required type="password" minLength={12} maxLength={256} autoComplete="new-password" value={recovery[field]} disabled={busy} onChange={e => setRecovery(v => ({ ...v, [field]: e.target.value }))}/></label>)}</div><button className="brand-button" disabled={busy}>Восстановить и завершить старые сессии</button></form></section>}
 </main>;
}
