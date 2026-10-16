import { useState } from 'react';
import { downloadCalendar } from './coreLearningClient';
import type { LearningConnection } from './coreLearningClient';
export default function CampusPilot({ core, onDirty }: {
    core: LearningConnection;
    onDirty: (v: boolean) => void;
}) {
    const data = core.data!, owner = core.project?.role === 'owner', viewer = core.project?.role === 'viewer';
    const [editVersion, setEditVersion] = useState(core.project!.version);
    const [mode, setMode] = useState<'overview' | 'config' | 'session'>('overview'), [pilot, setPilot] = useState({ ...data.pilot }), [session, setSession] = useState({ title: '', startsAt: '', endsAt: '', kind: 'practice', facilitator: core.user?.username || '', meetingUrl: '', notes: '' }), [attendance, setAttendance] = useState<Record<string, string>>({}), [changed, setChanged] = useState(false);
    function dirty() { if (!changed)
        setEditVersion(core.project!.version); setChanged(true); onDirty(true); }
    function switchMode(v: typeof mode) {
        if (changed && !confirm('Изменения формы будут потеряны. Продолжить?'))
            return;
        setMode(v);
        setEditVersion(core.project!.version);
        setPilot({ ...data.pilot });
        setSession({ title: '', startsAt: '', endsAt: '', kind: 'practice', facilitator: core.user?.username || '', meetingUrl: '', notes: '' });
        setAttendance({});
        setChanged(false);
        onDirty(false);
    }
    return <section className="campus-panel"><p className="brand-eyebrow">PILOT / LEARNING OPERATIONS</p><h2>Ритм программы.</h2>{changed && editVersion !== core.project!.version && <p role="status">Проект изменился после начала формы. Сохранение со старой версией будет отклонено. Скопируйте нужный текст и переключите форму, чтобы начать заново.</p>}<p>Расписание пустое, пока владелец не назначит занятия и ведущего из участников проекта. Встречи, уведомления и календарные приглашения автоматически не отправляются.</p><div className="campus-actions"><button className="brand-button" disabled={core.busy} aria-pressed={mode === 'overview'} onClick={() => switchMode('overview')}>Расписание</button>{owner && <><button className="brand-button" disabled={core.busy} aria-pressed={mode === 'config'} onClick={() => switchMode('config')}>Настроить пилот</button><button className="brand-button" disabled={core.busy} aria-pressed={mode === 'session'} onClick={() => switchMode('session')}>Добавить занятие</button></>}</div>
 {mode === 'config' && <form onSubmit={async (e) => {
                e.preventDefault();
                if (await core.commit({ expectedVersion: editVersion, action: 'pilot_config', ...pilot })) {
                    setChanged(false);
                    onDirty(false);
                    setMode('overview');
                }
            }}>{(['name', 'audience', 'hypothesis', 'notes'] as const).map((field, i) => <label className="campus-field" key={field}><span>{['Название пилота', 'Аудитория и ограничения', 'Какую пользу проверяем', 'Организация, поддержка и ограничения'][i]}</span><textarea required={field !== 'notes'} minLength={field === 'name' ? 2 : field === 'notes' ? 0 : 10} maxLength={field === 'name' ? 160 : field === 'audience' ? 1000 : field === 'hypothesis' ? 2000 : 4000} value={pilot[field]} disabled={core.busy} onChange={e => { setPilot(v => ({ ...v, [field]: e.target.value })); dirty(); }}/></label>)}<label className="campus-field"><span>Состояние — устанавливает владелец</span><select value={pilot.status} disabled={core.busy} onChange={e => { setPilot(v => ({ ...v, status: e.target.value as typeof pilot.status })); dirty(); }}><option value="draft">Подготовка</option><option value="running">Проводится</option><option value="closed">Закрыт</option></select></label><button className="brand-button primary" disabled={core.busy || !!core.pending}>Сохранить настройки</button></form>}
 {mode === 'session' && <form onSubmit={async (e) => {
                e.preventDefault();
                if (await core.commit({ expectedVersion: editVersion, action: 'session', ...session, startsAt: session.startsAt + ':00Z', endsAt: session.endsAt + ':00Z' })) {
                    setChanged(false);
                    onDirty(false);
                    setMode('overview');
                }
            }}><label className="campus-field"><span>Название занятия</span><input required minLength={3} maxLength={200} disabled={core.busy} value={session.title} onChange={e => { setSession(v => ({ ...v, title: e.target.value })); dirty(); }}/></label><div className="campus-grid">{(['startsAt', 'endsAt'] as const).map((field, i) => <label className="campus-field" key={field}><span>{i ? 'Окончание (UTC)' : 'Начало (UTC)'}</span><input required type="datetime-local" disabled={core.busy} value={session[field]} onChange={e => { setSession(v => ({ ...v, [field]: e.target.value })); dirty(); }}/></label>)}</div><label className="campus-field"><span>Формат</span><select value={session.kind} disabled={core.busy} onChange={e => { setSession(v => ({ ...v, kind: e.target.value })); dirty(); }}><option value="practice">Практика</option><option value="review">Разбор работ</option><option value="discussion">Обсуждение</option></select></label><label className="campus-field"><span>Ведущий — участник с правом редактирования</span><select required value={session.facilitator} disabled={core.busy} onChange={e => { setSession(v => ({ ...v, facilitator: e.target.value })); dirty(); }}>{data.participants.filter(p => p.role !== 'viewer').map(p => <option key={p.id} value={p.username}>{p.username}</option>)}</select></label><label className="campus-field"><span>HTTPS-ссылка встречи — необязательно</span><input type="url" maxLength={2000} value={session.meetingUrl} disabled={core.busy} onChange={e => { setSession(v => ({ ...v, meetingUrl: e.target.value })); dirty(); }}/></label><label className="campus-field"><span>Подготовка и повестка</span><textarea maxLength={4000} value={session.notes} disabled={core.busy} onChange={e => { setSession(v => ({ ...v, notes: e.target.value })); dirty(); }}/></label><button className="brand-button primary" disabled={core.busy || !!core.pending}>Сохранить занятие</button></form>}
 {mode === 'overview' && <><div className="campus-pilot-summary"><h3>{data.pilot.name || 'Пилот ещё не настроен'}</h3><p>{data.pilot.audience || 'Аудитория не задана.'}</p><p>{data.pilot.hypothesis}</p><p>{data.pilot.notes}</p><p>Состояние: {data.pilot.status === 'draft' ? 'подготовка' : data.pilot.status === 'running' ? 'проводится по отметке владельца' : 'закрыт по отметке владельца'}. Участников с доступом: {data.participants.length}.</p><p>Количество аккаунтов не доказывает участие людей в реальном пилоте.</p></div><div className="campus-actions"><button className="brand-button" disabled={!data.sessions.length} onClick={() => downloadCalendar(data.sessions)}>Скачать расписание .ics</button></div>{!data.sessions.length && <p>Занятий пока нет. Даты и ведущие не выдуманы.</p>}{data.sessions.map(s => <article className="campus-record" key={s.id}><p className="brand-eyebrow">{s.kind.toUpperCase()} / {s.status}</p><h3>{s.title}</h3><p>{new Date(s.startsAt).toLocaleString('ru-RU')} — {new Date(s.endsAt).toLocaleTimeString('ru-RU')} · время вашего устройства</p><p>Ведущий: {s.facilitator}</p><p>{s.notes}</p>{s.meetingUrl && <p><a href={s.meetingUrl} target="_blank" rel="noopener noreferrer">Открыть ссылку встречи ↗</a></p>}{owner && <div className="campus-actions">{[['completed', 'Отметить проведённым'], ['cancelled', 'Отменить'], ['planned', 'Вернуть в план']].filter(([value]) => value !== s.status).map(([value, label]) => <button key={value} className="brand-button" disabled={core.busy || !!core.pending || changed} onClick={() => {
                            if (confirm(label + '? Это ручная отметка, уведомления не отправляются.'))
                                void core.commit({ action: 'session_status', sessionId: s.id, status: value });
                        }}>{label}</button>)}</div>}<details><summary>Посещение и заметки</summary>{data.attendance.filter(a => a.sessionId === s.id).map(a => <p key={a.actor}>{a.actor}: {a.note} · самоотчёт</p>)}{s.status !== 'cancelled' && !viewer && <form onSubmit={async (e) => {
                        e.preventDefault();
                        const r = await core.commit({ expectedVersion: editVersion, action: 'attendance', sessionId: s.id, note: attendance[s.id] || '' });
                        if (r) {
                            setEditVersion(r.project.version);
                            setAttendance(v => ({ ...v, [s.id]: '' }));
                            const remaining = Object.entries(attendance).some(([id, value]) => id !== s.id && value.trim());
                            setChanged(remaining);
                            onDirty(remaining);
                        }
                    }}><label className="campus-field"><span>Что удалось сделать на занятии — самоотчёт</span><textarea required minLength={10} maxLength={2000} disabled={core.busy} value={attendance[s.id] || ''} onChange={e => { setAttendance(v => ({ ...v, [s.id]: e.target.value })); dirty(); }}/></label><button className="brand-button" disabled={core.busy || !!core.pending || new Date(s.startsAt).getTime() > Date.now()}>Сохранить своё посещение</button></form>}</details></article>)}<p className="campus-muted">.ics — файл для ручного импорта. Изменения и отмены нужно экспортировать и импортировать заново; автоматической подписки на календарь нет.</p></>}
 </section>;
}
