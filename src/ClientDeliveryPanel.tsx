import { useEffect, useRef, useState } from 'react';
import { coreRequest } from './coreClient';
import type { CoreProject } from './coreClient';
type Props = {
    project: CoreProject;
    disabled: boolean;
    onDirty: (v: boolean) => void;
    onCreate: (body: Record<string, unknown>) => Promise<unknown>;
};
export default function ClientDeliveryPanel({ project, disabled, onDirty, onCreate }: Props) {
    const [releases, setReleases] = useState<{
        id: string;
        sourceVersion: number;
        latestReview: {
            verdict: string;
        } | null;
    }[]>([]), [deliveries, setDeliveries] = useState<{
        id: string;
        title: string;
        recipient: string;
        status: string;
        version: number;
    }[]>([]), [form, setForm] = useState({ releaseId: '', recipient: '', title: '', description: '', instructions: '', sharingAcknowledged: false }), [version, setVersion] = useState<number | null>(null), [busy, setBusy] = useState(false), [error, setError] = useState(''), [preview, setPreview] = useState<string | null>(null);
    const lock = useRef(false), alert = useRef<HTMLParagraphElement>(null), changed = version !== null, stale = changed && version !== project.version;
    useEffect(() => { onDirty(changed); return () => onDirty(false); }, [changed, onDirty]);
    useEffect(() => { if (error)
        alert.current?.focus(); }, [error]);
    useEffect(() => { let active = true; void Promise.all([coreRequest<{
            releases: typeof releases;
        }>('projects/' + project.id + '/releases'), coreRequest<{
            deliveries: typeof deliveries;
        }>('projects/' + project.id + '/client-deliveries')]).then(([r, d]) => { if (active) {
        setReleases(r.releases);
        setDeliveries(d.deliveries);
    } }).catch(e => { if (active)
        setError(e.message); }); return () => { active = false; }; }, [project.id, project.version]);
    function edit(changes: Partial<typeof form>) { if (version === null)
        setVersion(project.version); setForm(v => ({ ...v, ...changes })); if (changes.releaseId !== undefined) {
        setPreview(null);
        setForm(v => ({ ...v, sharingAcknowledged: false }));
    } }
    async function run(work: () => Promise<void>) { if (lock.current)
        return; lock.current = true; setBusy(true); setError(''); try {
        await work();
    }
    catch (e) {
        setError(e instanceof Error ? e.message : 'Не удалось выполнить действие.');
    }
    finally {
        lock.current = false;
        setBusy(false);
    } }
    return <section className="core-panel"><p className="brand-eyebrow">BUSINESS / LIMITED DELIVERY</p><h2>Передать выпуск без доступа к проекту</h2><p>Получатель увидит только заданные здесь описание, инструкцию, файл или ссылку выпуска и переписку по этой передаче. Его не добавляют в участники проекта. Нужен существующий аккаунт на этом сервере.</p><p>Сохранённый HTML может содержать цель, аудиторию, задачи и критерии исходного выпуска. Прочитайте файл перед передачей. Внешняя ссылка тоже может раскрывать данные; сервер её не проверял.</p><p ref={alert} tabIndex={-1} role={error ? 'alert' : undefined} hidden={!error} className="core-alert">{error}</p><p role="status">{busy ? 'Выполняем запрос…' : ''}</p>{stale && <p className="core-alert">Проект изменился. Черновик сохранён на экране; обновите проект и проверьте материалы заново.</p>}
 {project.role !== 'viewer' ? <form onSubmit={e => { e.preventDefault(); void run(async () => { await onCreate({ ...form, expectedVersion: version ?? project.version }); }); }}><fieldset className="core-editor" disabled={busy || disabled || stale}><legend>Состав изолированной передачи</legend><label className="core-field"><span>Положительно разобранный выпуск</span><select required value={form.releaseId} onChange={e => edit({ releaseId: e.target.value })}><option value="">Выберите выпуск</option>{releases.filter(r => r.latestReview?.verdict === 'accepted').map(r => <option key={r.id} value={r.id}>{r.id.slice(0, 8)} · исходная версия {r.sourceVersion}</option>)}</select></label><button type="button" className="brand-button" disabled={!form.releaseId} onClick={() => void run(async () => { const p = await coreRequest<{
            snapshot: {
                artifact: {
                    url: string;
                };
            };
            asset: {
                html: string;
            } | null;
        }>('projects/' + project.id + '/releases/' + form.releaseId); setPreview(p.asset?.html ?? null); if (!p.asset)
            setError('Выпуск содержит внешнюю ссылку. Проверьте её самостоятельно: ' + p.snapshot.artifact.url); })}>Проверить содержимое файла</button>{preview !== null && <iframe title="Файл, который увидит получатель" className="core-preview" sandbox="" srcDoc={preview}/>}
 <label className="core-field"><span>Логин получателя</span><input required minLength={3} maxLength={64} value={form.recipient} onChange={e => edit({ recipient: e.target.value })}/></label><label className="core-field"><span>Название для получателя</span><input required minLength={3} maxLength={160} value={form.title} onChange={e => edit({ title: e.target.value })}/></label><label className="core-field"><span>Что передаётся — без внутренних записей проекта</span><textarea required minLength={20} maxLength={4000} value={form.description} onChange={e => edit({ description: e.target.value })}/></label><label className="core-field"><span>Как открыть, проверить и обратиться по результату</span><textarea required minLength={20} maxLength={4000} value={form.instructions} onChange={e => edit({ instructions: e.target.value })}/></label><label className="core-check"><input required type="checkbox" checked={form.sharingAcknowledged} onChange={e => edit({ sharingAcknowledged: e.target.checked })}/>Я проверил описание, инструкцию и содержимое файла или ссылки и разрешаю передать их этому аккаунту</label><button className="brand-button primary" disabled={!form.sharingAcknowledged}>Создать изолированную передачу</button></fieldset></form> : <p>Создание доступно редакторам проекта.</p>}
 <h3>Созданные передачи</h3>{!deliveries.length && <p>Записей пока нет или Business ещё не включён.</p>}{deliveries.map(d => <article className="core-source" key={d.id}><strong>{d.title}</strong><p>{d.recipient} · {d.status === 'revoked' ? 'Доступ отозван' : d.status === 'acknowledged' ? 'Получение подтверждено' : 'Ожидает подтверждения'} · v{d.version}</p><a className="brand-button" href={'/deliveries?delivery=' + d.id}>Открыть передачу и поддержку</a></article>)}<p>Письма и приглашения не отправляются. Отзыв закрывает дальнейший доступ на сервере, но не удаляет ранее скачанные файлы.</p>
 </section>;
}
