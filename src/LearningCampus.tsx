import {coreLoginLink} from './accountAccess'
import { useEffect, useState } from 'react';
import { coreRequest, downloadCore } from './coreClient';
import { useLearningProject } from './coreLearningClient';
import type { CurriculumLesson } from './coreLearningClient';
import CampusFinal from './CampusFinal';
import CampusPilot from './CampusPilot';
import './learningCampus.css';
export default function LearningCampus() {
    const core = useLearningProject(), [panel, setPanel] = useState<'path' | 'final' | 'pilot'>(() => { const v = new URLSearchParams(location.search).get('panel'); return v === 'final' || v === 'pilot' ? v : 'path'; }), [dirty, setDirty] = useState(false), [curriculum, setCurriculum] = useState<CurriculumLesson[]>([]), [loadError, setLoadError] = useState('');
    useEffect(() => { void core.connect(); }, []);
    useEffect(() => {
        if (core.phase !== 'ready')
            return;
        let active = true;
        coreRequest<{
            lessons: CurriculumLesson[];
        }>('curriculum').then(r => {
            if (active)
                setCurriculum(r.lessons);
        }).catch(e => {
            if (active)
                setLoadError(e instanceof Error ? e.message : 'Не удалось загрузить программу.');
        });
        return () => { active = false; };
    }, [core.phase]);
    useEffect(() => { setDirty(false); }, [core.project?.id]);
    useEffect(() => {
        const leave = (e: BeforeUnloadEvent) => {
            if (dirty) {
                e.preventDefault();
                e.returnValue = '';
            }
        };
        window.addEventListener('beforeunload', leave);
        return () => window.removeEventListener('beforeunload', leave);
    }, [dirty]);
    const switchPanel = (v: typeof panel) => {
        if (v === panel)
            return;
        if (dirty && !confirm('В этой форме есть несохранённые изменения. Перейти без сохранения?'))
            return;
        setPanel(v);
        setDirty(false);
    };
    const next = curriculum.find(l => !core.data?.completed.includes(l.slug)), total = curriculum.length || 8;
    return <main className="brand-container campus learning-campus"><section className="campus-hero"><p className="brand-eyebrow">OSA LEARNING / PRACTICE · SUBMIT · REVIEW</p><h1>Знание становится<br /><em>выполненной работой.</em></h1><p className="brand-lead">Практика из уроков, снимок итогового проекта и конкретная обратная связь. Один учебный маршрут внутри вашего серверного проекта.</p><div className="campus-actions"><a className="brand-button" href="/workspace">Открыть Core →</a><a className="brand-button" href="/learning/organizer">Очередь разборов и отчёты</a><a className="brand-button" href="/learning/program">Содержание программы</a></div></section>
 <div className="campus-status" role="status">{core.busy ? 'Загружаем или сохраняем данные…' : core.notice}{dirty && <p>Есть несохранённые поля в текущей форме.</p>}</div>{(core.error || loadError) && <div role="alert" className="campus-error">{core.error || loadError}</div>}
 {core.phase === 'idle' && <section className="campus-panel"><h2>Подключаем серверный маршрут</h2><p>Если Core недоступен, можно продолжить гостевое обучение.</p><button className="brand-button" disabled={core.busy} onClick={() => void core.connect()}>Проверить подключение</button></section>}
 {core.phase === 'login' && <section className="campus-panel"><h2>Войдите в Core</h2><p>Для серверной практики и сдачи работы нужен аккаунт. Существующие уроки и гостевой прогресс доступны без него.</p><a className="brand-button primary" href={coreLoginLink('/learning/campus'+location.search)}>Войти или создать аккаунт</a><a className="brand-button" href="/lectures">Учиться без аккаунта</a></section>}
 {core.phase === 'offline' && <section className="campus-panel"><h2>Core пока не подключён</h2><p>Запустите START-CORE-WINDOWS.bat из полного архива. Статическая загрузка на Cloudflare не запускает Python-сервер.</p><a className="brand-button" href="/learning/program">Открыть гостевую программу</a><button className="brand-button" disabled={core.busy} onClick={() => void core.connect()}>Проверить снова</button></section>}
 {core.phase === 'ready' && <><section className="campus-project-select"><label className="campus-field"><span>Ваш учебный проект / {core.user?.username}</span><select disabled={core.busy} value={core.project?.id || ''} onChange={e => {
                if (!dirty || confirm('Сменить проект без сохранения текущей формы?'))
                    void core.select(e.target.value);
            }}><option value="">Выберите проект</option>{core.projects.filter(p => p.data.consents.learning).map(p => <option key={p.id} value={p.id}>{p.data.title} / {p.role}</option>)}</select></label><button className="brand-button" disabled={core.busy || !core.project} onClick={() => {
                if (!dirty || confirm('Обновить данные? Несохранённая форма останется в полях.'))
                    void core.reload();
            }}>Обновить с сервера</button></section>{!core.projects.some(p => p.data.consents.learning) && <section className="campus-panel"><h2>Разрешите Learning в контракте</h2><p>Создайте проект в Core и включите использование его контекста Learning. Без согласия учебные записи на сервер не отправляются.</p><a href="/workspace">Открыть контракт →</a></section>}
 {core.pending && <section className="campus-error"><h2>Запись могла сохраниться</h2><p>Повтор использует тот же ключ. Сначала разрешите незавершённый запрос, затем создавайте новый.</p><button className="brand-button" disabled={core.busy || !core.project} onClick={() => void core.commit({}, true)}>Повторить тот же запрос</button><a href="/workspace">Проверить запрос в Core →</a></section>}
 {core.project && core.data && <><div className="campus-project-heading"><div><p className="brand-eyebrow">PROJECT / {core.project.id.slice(0, 8)} / v{core.project.version}</p><h2>{core.project.data.title}</h2></div><span>{core.data.completed.length} / {total} ваших актуальных практик</span></div><nav className="campus-tabs" aria-label="Учебное пространство">{[['path', 'Уроки и практика'], ['final', 'Итоговая работа'], ['pilot', 'Пилот и расписание']].map(([id, label]) => <button className="brand-button" key={id} aria-current={panel === id ? 'step' : undefined} disabled={core.busy} onClick={() => switchPanel(id as typeof panel)}>{label}</button>)}</nav>
 {panel === 'path' && <section className="campus-panel"><p className="brand-eyebrow">OSA ORIGINAL / EIGHT LESSONS</p><h2>{next ? 'Продолжите с нужной практики.' : 'Практики маршрута сохранены.'}</h2>{next && <a className="brand-button primary" href={'/lectures/' + next.slug}>Продолжить: {next.ru.exercise.title} →</a>}<p>Личный прогресс учитывает только ваши записи в этом проекте. Учебная запись содержит ответ самопроверки и результат упражнения. Ручные отметки в Core и гостевом браузере не заменяют эти записи. Верный тестовый ответ не подтверждает навык без разбора практики.</p><ol className="campus-lessons">{curriculum.map((l, i) => <li key={l.slug}><span>{core.data!.completed.includes(l.slug) ? '✓' : String(i + 1).padStart(2, '0')}</span><div><h3><a href={'/lectures/' + l.slug}>{l.ru.exercise.title}</a></h3><p>{l.ru.exercise.successCriteria}</p><a href={'/lectures/' + l.slug}>Открыть урок и сохранить практику →</a></div></li>)}</ol><details><summary>Последние учебные записи ({core.data.activities.length}, максимум 100)</summary>{core.data.activities.map(a => <article className="campus-record" key={a.id}><strong>{curriculum.find(l => l.slug === a.slug)?.ru.exercise.title || a.slug}</strong><p>{a.actor} / {new Date(a.createdAt).toLocaleString('ru-RU')} / {a.passed ? 'Самопроверка верна' : 'Нужен другой ответ'} {curriculum.find(l => l.slug === a.slug)?.hash !== a.hash ? ' / Предыдущая версия материала' : ''}</p><p>{a.practice}</p></article>)}</details></section>}
 {panel === 'final' && <CampusFinal key={core.project.id} core={core} onDirty={setDirty}/>}{panel === 'pilot' && <CampusPilot key={core.project.id} core={core} onDirty={setDirty}/>}
 <section className="campus-export"><h2>Материалы остаются вашими.</h2><p>JSON-экспорт Core включает практики, сдачи, разборы, расписание и посещения. Восстановление старой версии проекта не удаляет эти записи.</p><button className="brand-button" disabled={core.busy} onClick={async () => {
                    try {
                        downloadCore(await coreRequest('projects/' + core.project!.id + '/export'), 'osgard-learning-' + core.project!.id + '.json');
                    }
                    catch (e) {
                        core.setError(e instanceof Error ? e.message : 'Не удалось выгрузить проект.');
                    }
                }}>Скачать проект и учебную историю</button></section>
 </>}
 </>}
 <section className="campus-boundary"><h2>Честный статус обучения.</h2><p>Здесь работают серверные записи и инструменты организации пилота. Наличие интерфейса не означает, что наставники назначены, занятия проведены или навык независимо подтверждён. Реальный набор, результаты учеников и браузерная приёмка ещё нужны. Сертификаты не выдаются.</p></section>
 </main>;
}
