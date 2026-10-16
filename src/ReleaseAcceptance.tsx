import { useEffect, useRef, useState } from 'react';
import { coreRequest, downloadCore } from './coreClient';
import type { CoreData, CoreProject } from './coreClient';
export type ReleaseReview = {
    id: string;
    releaseId: string;
    sourceVersion: number;
    actor: string;
    verdict: 'accepted' | 'needs_changes';
    criteria: {
        id: string;
        passed: boolean;
        evidence: string;
    }[];
    note: string;
    createdAt: string;
};
type ReleaseItem = {
    id: string;
    at: string;
    sourceVersion: number | null;
    canReview: boolean;
    reviewCount: number;
    latestReview: ReleaseReview | null;
};
export type ReleasePacket = {
    format: string;
    projectId: string;
    projectVersion: number;
    release: {
        id: string;
    };
    sourceVersion: number;
    releaseActorId: string;
    snapshot: CoreData;
    asset: {
        html: string;
        sha256: string;
        integrityMatches: boolean;
    } | null;
    reviews: ReleaseReview[];
};
type Props = {
    project: CoreProject;
    disabled: boolean;
    userId: string;
    onDirty: (dirty: boolean) => void;
    onReview: (body: Record<string, unknown>) => Promise<unknown>;
};
export default function ReleaseAcceptance({ project, disabled, userId, onDirty, onReview }: Props) {
    const [items, setItems] = useState<ReleaseItem[]>([]), [packet, setPacket] = useState<ReleasePacket | null>(null), [version, setVersion] = useState(0), [answers, setAnswers] = useState<Record<string, {
        passed: string;
        evidence: string;
    }>>({}), [note, setNote] = useState(''), [busy, setBusy] = useState(false), [error, setError] = useState(''), [message, setMessage] = useState(''), [preview, setPreview] = useState(false), [loading, setLoading] = useState(true);
    const lock = useRef(false), seq = useRef(0), alert = useRef<HTMLParagraphElement>(null);
    const changed = !!note || Object.values(answers).some(v => v.passed || v.evidence);
    const stale = !!packet && version !== project.version;
    useEffect(() => { onDirty(changed); return () => onDirty(false); }, [changed, onDirty]);
    useEffect(() => { if (error)
        alert.current?.focus(); }, [error]);
    useEffect(() => { const leave = (e: BeforeUnloadEvent) => { if (changed) {
        e.preventDefault();
        e.returnValue = '';
    } }; window.addEventListener('beforeunload', leave); return () => window.removeEventListener('beforeunload', leave); }, [changed]);
    async function run(work: () => Promise<void>) { if (lock.current)
        return; lock.current = true; setBusy(true); setError(''); setMessage(''); try {
        await work();
    }
    catch (e) {
        setError(e instanceof Error ? e.message : 'Не удалось загрузить выпуск.');
    }
    finally {
        lock.current = false;
        setBusy(false);
    } }
    async function list() { const r = await coreRequest<{
        releases: ReleaseItem[];
    }>('projects/' + project.id + '/releases'); setItems(r.releases); }
    useEffect(() => { const id = ++seq.current; setLoading(true); void coreRequest<{
        releases: ReleaseItem[];
    }>('projects/' + project.id + '/releases').then(r => { if (seq.current === id)
        setItems(r.releases); }).catch(e => { if (seq.current === id)
        setError(e.message); }).finally(() => { if (seq.current === id)
        setLoading(false); }); return () => { seq.current++; }; }, [project.id, project.version]);
    async function open(id: string) { if (changed && !confirm('Закрыть несохранённый разбор?'))
        return; await run(async () => { const r = await coreRequest<ReleasePacket>('projects/' + project.id + '/releases/' + id); setPacket(r); setVersion(r.projectVersion); setAnswers(Object.fromEntries(r.snapshot.acceptance.map(c => [c.id, { passed: '', evidence: '' }]))); setNote(''); setPreview(false); }); }
    const canReview = packet && project.role !== 'viewer' && packet.releaseActorId !== userId;
    return <section className="core-panel"><p className="brand-eyebrow">STUDIO / RELEASE ACCEPTANCE</p><h2>Принять конкретный результат</h2><p>Другой участник проверяет критерии зафиксированного выпуска. Разбор относится только к его исходной версии; он не подтверждает новые изменения и не является независимой сертификацией.</p><button className="brand-button" disabled={busy || disabled} onClick={() => void run(list)}>Обновить список выпусков</button><p ref={alert} tabIndex={-1} role={error ? 'alert' : undefined} hidden={!error} className="core-alert">{error}</p><p role="status">{busy || loading ? 'Загружаем материалы…' : message}</p>{!loading && !error && !items.length && <p>Выпусков пока нет. В Studio сохраните контракт, создайте артефакт, проверьте критерии и зафиксируйте внутренний выпуск.</p>}{items.map(item => <article key={item.id} className="core-source"><h3>Выпуск {item.id.slice(0, 8)} · {item.sourceVersion ? 'исходная версия ' + item.sourceVersion : 'версия не зафиксирована'}</h3><p>{new Date(item.at).toLocaleString('ru-RU')} · Разборов: {item.reviewCount}</p><p>{item.latestReview ? (item.latestReview.verdict === 'accepted' ? 'Принят участником' : 'Есть замечания') + ' · ' + item.latestReview.actor : 'Ещё не разобран'}</p><button className="brand-button" disabled={busy || disabled || !item.sourceVersion} onClick={() => void open(item.id)}>Открыть материалы выпуска</button></article>)}
 {packet && <article className="core-source"><h3>Материалы исходной версии {packet.sourceVersion}</h3><p>{packet.snapshot.title}</p><p>Это снимок выпуска, а не текущий редактор. В JSON входят цель, источники, условия, история выпусков в снимке и разборы; проверьте личные данные перед передачей файла.</p><button className="brand-button" disabled={busy} onClick={() => downloadCore(packet, 'osgard-release-' + packet.release.id + '.json')}>Скачать материалы JSON</button><details><summary>Прочитать контракт выпуска</summary><pre className="release-snapshot">{JSON.stringify(packet.snapshot, null, 2)}</pre></details>{packet.asset ? <><p>{packet.asset.integrityMatches ? 'SHA-256 сохранённого HTML совпадает с выпуском.' : 'SHA-256 не совпадает: приёмка заблокирована.'}</p><p className="release-checksum">{packet.asset.sha256}</p><button className="brand-button" onClick={() => setPreview(v => !v)}>{preview ? 'Закрыть HTML' : 'Показать сохранённый HTML'}</button>{preview && <iframe className="core-preview" title="HTML конкретного выпуска" sandbox="" srcDoc={packet.asset.html}/>}</> : <p>Во внешней ссылке содержимое могло измениться. Сервер её не открывал и не проверял; основание решения укажите в разборе.</p>}
 {stale && <p className="core-alert">Проект изменился после открытия материалов. Текст разбора сохранён на экране. Нажмите «Обновить» у заголовка проекта, затем заново откройте выпуск и проверьте актуальные данные.</p>}
 {!canReview && <p>{project.role === 'viewer' ? 'Наблюдатель читает материалы и разборы. Для приёмки нужно право редактирования.' : 'Автор выпуска не принимает собственную работу. Добавьте другого редактора через историю проекта.'}</p>}
 {canReview && <form onSubmit={e => { e.preventDefault(); void run(async () => { await onReview({ expectedVersion: version, releaseId: packet.release.id, criteria: packet.snapshot.acceptance.map(c => ({ id: c.id, passed: answers[c.id]?.passed === 'yes', evidence: answers[c.id]?.evidence || '' })), note }); setAnswers({}); setNote(''); setPacket(null); setPreview(false); await list(); setMessage('Разбор сохранён для исходной версии выпуска.'); }); }}><fieldset disabled={busy || disabled || stale} className="core-editor"><legend>Проверка каждого критерия</legend>{packet.snapshot.acceptance.map(c => <div className="core-source" key={c.id}><strong>{c.title}</strong><label className="core-field"><span>Результат</span><select required value={answers[c.id]?.passed || ''} onChange={e => setAnswers(v => ({ ...v, [c.id]: { ...v[c.id], passed: e.target.value } }))}><option value="">Выберите результат</option><option value="yes">Выполнен</option><option value="no">Требует доработки</option></select></label><label className="core-field"><span>Что проверили, на каких данных и что получилось</span><textarea required minLength={20} maxLength={2000} value={answers[c.id]?.evidence || ''} onChange={e => setAnswers(v => ({ ...v, [c.id]: { ...v[c.id], evidence: e.target.value } }))}/></label></div>)}<label className="core-field"><span>Общий вывод, ограничения и следующий шаг</span><textarea required minLength={20} maxLength={4000} value={note} onChange={e => setNote(e.target.value)}/></label><button className="brand-button primary">Сохранить разбор выпуска</button><p>Все критерии выполнены — «Принят участником». Хотя бы один не выполнен — «Есть замечания».</p></fieldset></form>}
 <h3>История разборов на момент открытия</h3>{!packet.reviews.length && <p>Пока нет разборов этой версии.</p>}{packet.reviews.map(r => <details className="core-source" key={r.id}><summary>{r.verdict === 'accepted' ? 'Принят участником' : 'Есть замечания'} · {r.actor} · {new Date(r.createdAt).toLocaleString('ru-RU')}</summary><p>{r.note}</p>{r.criteria.map(c => <p key={c.id}>{packet.snapshot.acceptance.find(v => v.id === c.id)?.title || c.id}: {c.passed ? 'выполнен' : 'доработать'} — {c.evidence}</p>)}</details>)}</article>}
 </section>;
}
