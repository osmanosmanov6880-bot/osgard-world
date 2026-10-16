import { useState } from 'react';
import { coreRequest, downloadCore } from './coreClient';
import type { LearningConnection } from './coreLearningClient';
export default function CampusFinal({ core, onDirty }: {
    core: LearningConnection;
    onDirty: (v: boolean) => void;
}) {
    const [editVersion, setEditVersion] = useState(core.project!.version);
    const [mode, setMode] = useState<'submit' | 'review'>(() => new URLSearchParams(location.search).get('intent') === 'review' ? 'review' : 'submit'), [summary, setSummary] = useState(''), [evidence, setEvidence] = useState(''), [target, setTarget] = useState(() => { const wanted = new URLSearchParams(location.search).get('submission') || ''; const submission = core.data!.submissions.find(s => s.id === wanted && s.actorId !== core.user?.id); const assignment = core.data!.assignments?.find(a => a.submissionId === wanted); return submission && (!assignment || assignment.status === 'withdrawn' || assignment.reviewerId === core.user?.id) ? wanted : ''; }), [note, setNote] = useState(''), [scores, setScores] = useState<Record<string, {
        score: number;
        evidence: string;
    }>>({}), [snapshot, setSnapshot] = useState<{
        sourceVersion: number;
        snapshot: unknown;
    } | null>(null), [loading, setLoading] = useState(false), [changed, setChanged] = useState(false), [failure, setFailure] = useState('');
    const data = core.data!, project = core.project!, viewer = project.role === 'viewer';
    const eligible = data.submissions.filter(s => { const assignment = data.assignments?.find(a => a.submissionId === s.id); return s.actorId !== core.user?.id && (!assignment || assignment.status === 'withdrawn' || assignment.reviewerId === core.user?.id); });
    const dirty = () => { if (!changed)
        setEditVersion(core.project!.version); setChanged(true); onDirty(true); };
    function switchMode(next: 'submit' | 'review') {
        if (changed && !confirm('Изменения этой формы будут потеряны. Продолжить?'))
            return;
        setMode(next);
        setEditVersion(core.project!.version);
        setChanged(false);
        onDirty(false);
        setSummary('');
        setEvidence('');
        setTarget('');
        setScores({});
        setNote('');
        setFailure('');
    }
    async function show(id: string) {
        setLoading(true);
        setFailure('');
        try {
            setSnapshot(await coreRequest('projects/' + project.id + '/learning/submissions/' + id));
        }
        catch (e) {
            setFailure(e instanceof Error ? e.message : 'Не удалось загрузить снимок.');
        }
        finally {
            setLoading(false);
        }
    }
    return <section className="campus-panel"><p className="brand-eyebrow">FINAL PROJECT / VERSIONED HANDOFF</p><h2>Работа, которую можно разобрать.</h2>{mode === 'submit' && <ul className="campus-checklist">{data.readiness.map(c => <li key={c.id}><span>{c.passed ? '✓' : '○'}</span>{c.label}</li>)}</ul>}<p>Готовность проверяет наличие материалов, а не качество работы. Разбор выполняет другой участник проекта с правами редактора. Квалификация наставника и независимый экзамен не подтверждены.</p>
 {changed && editVersion !== project.version && <p role="status">Версия проекта изменилась. Скопируйте нужный текст и переключите форму перед новой записью. Сохранение старого черновика не затрёт чужие изменения.</p>}<div className="campus-actions"><button className="brand-button" aria-pressed={mode === 'submit'} disabled={core.busy} onClick={() => switchMode('submit')}>Сдать работу</button><button className="brand-button" aria-pressed={mode === 'review'} disabled={core.busy} onClick={() => switchMode('review')}>Разобрать работу</button></div>
 {mode === 'submit' ? <form onSubmit={async (e) => {
                e.preventDefault();
                const r = await core.commit({ expectedVersion: editVersion, action: 'submit', summary, evidence });
                if (r) {
                    setSummary('');
                    setEvidence('');
                    setChanged(false);
                    onDirty(false);
                }
            }}><label className="campus-field"><span>Что сделано и как воспроизвести — минимум 40 символов</span><textarea required minLength={40} maxLength={10000} disabled={viewer || core.busy} value={summary} onChange={e => { setSummary(e.target.value); dirty(); }}/></label><label className="campus-field"><span>Доказательства, ограничения и новая задача — минимум 20 символов</span><textarea required minLength={20} maxLength={10000} disabled={viewer || core.busy} value={evidence} onChange={e => { setEvidence(e.target.value); dirty(); }}/></label><button className="brand-button primary" disabled={viewer || core.busy || !!core.pending || !data.readiness.every(c => c.passed)}>Сдать снимок версии {project.version}</button><p>Текущая версия сохранится в истории. Последующие изменения проекта не изменят сданную работу.</p></form> : <form onSubmit={async (e) => {
                e.preventDefault();
                const r = await core.commit({ expectedVersion: editVersion, action: 'review', submissionId: target, note, scores: data.rubric.map(k => ({ id: k.id, score: scores[k.id]?.score ?? 0, evidence: scores[k.id]?.evidence || '' })) });
                if (r) {
                    setChanged(false);
                    onDirty(false);
                    setScores({});
                    setNote('');
                }
            }}><label className="campus-field"><span>Сданная работа другого участника</span><select required value={target} disabled={viewer || core.busy} onChange={e => {
                if (changed && !confirm('Сменить работу и очистить текущий разбор?'))
                    return;
                setTarget(e.target.value);
                setEditVersion(core.project!.version);
                setScores({});
                setNote('');
                setChanged(false);
                onDirty(false);
            }}><option value="">Выберите работу</option>{eligible.map(s => <option key={s.id} value={s.id}>{s.actor} / v{s.sourceVersion} / {new Date(s.createdAt).toLocaleString('ru-RU')}</option>)}</select></label>{!eligible.length && <p>Нет доступных вам работ для разбора: они могут быть своими или назначенными другому проверяющему. Свою работу нельзя оценивать как чужой разбор. Владелец может добавить редактора по логину в Core.</p>}{target && <><button type="button" className="brand-button" disabled={loading} onClick={() => void show(target)}>Прочитать снимок версии</button><p>0 — нет доказательств; 1 — частично; 2 — показано на новом примере. Для каждого балла приведите обоснование.</p>{data.rubric.map(k => <div key={k.id} className="campus-rubric"><h3>{k.title}</h3><label className="campus-field"><span>Оценка</span><select disabled={viewer || core.busy} value={scores[k.id]?.score ?? 0} onChange={e => { setScores(v => ({ ...v, [k.id]: { score: Number(e.target.value), evidence: v[k.id]?.evidence || '' } })); dirty(); }}>{[0, 1, 2].map(n => <option key={n}>{n}</option>)}</select></label><label className="campus-field"><span>Доказательство или конкретное замечание</span><textarea required minLength={10} maxLength={2000} disabled={viewer || core.busy} value={scores[k.id]?.evidence || ''} onChange={e => { setScores(v => ({ ...v, [k.id]: { score: v[k.id]?.score ?? 0, evidence: e.target.value } })); dirty(); }}/></label></div>)}<label className="campus-field"><span>Следующий шаг для автора</span><textarea required minLength={10} maxLength={4000} disabled={viewer || core.busy} value={note} onChange={e => { setNote(e.target.value); dirty(); }}/></label><button className="brand-button primary" disabled={viewer || core.busy || !!core.pending}>Сохранить разбор</button></>}</form>}
 {failure && <p role="alert">{failure}</p>}{snapshot && <details open><summary>Снимок сданной версии {snapshot.sourceVersion}</summary><button className="brand-button" onClick={() => downloadCore(snapshot, 'osgard-submission-v' + snapshot.sourceVersion + '.json')}>Скачать снимок</button><pre className="campus-json">{JSON.stringify(snapshot.snapshot, null, 2)}</pre></details>}
 <h3>История сдач и обратной связи</h3>{!data.submissions.length && <p>Пока нет сданных работ.</p>}{data.submissions.map(s => <article className="campus-record" key={s.id}><p className="brand-eyebrow">{s.actor} / VERSION {s.sourceVersion}</p><h3>{new Date(s.createdAt).toLocaleString('ru-RU')}</h3><p>{s.summary}</p><p>{s.evidence}</p><button className="brand-button" disabled={loading} onClick={() => void show(s.id)}>Снимок работы</button>{data.reviews.filter(r => r.submissionId === s.id).map(r => <section className="campus-review" key={r.id}><strong>{r.actor} · {r.scores.reduce((n, v) => n + v.score, 0)} / 10 · {r.verdict === 'reviewed' ? 'Критерии отмечены участником' : 'Нужны доработки'}</strong><p>{r.note}</p><details><summary>Оценки и основания</summary>{r.scores.map(score => <p key={score.id}>{data.rubric.find(v => v.id === score.id)?.title} / {score.score}: {score.evidence}</p>)}</details></section>)}</article>)}
 </section>;
}
