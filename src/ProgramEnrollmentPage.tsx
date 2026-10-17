import { useEffect, useRef, useState } from 'react';
import { coreLoginLink } from './accountAccess';
import { CoreError, coreRequest, downloadCore, setCoreToken } from './coreClient';
import { commerceMutation } from './commerceClient';
import type { CommerceOrder, ProgramHeader } from './commerceClient';
import './coreWorkspace.css';
import './programEnrollment.css';

type Work = { result: string; verification: string; newTask: string; transferResult: string };
type Lesson = { slug: string; hash: string; ru: {
  objectives: string[]; example: string;
  check: { question: string; options: string[]; correctIndex: number; explanation: string };
  exercise: { title: string; steps: string[]; successCriteria: string };
  sources: { title: string; url: string; context: string }[];
} };
export type EnrollmentView = {
  order: CommerceOrder; program: ProgramHeader;
  status: 'payment_required' | 'activation_required' | 'consent_required' | 'active' | 'refunded';
  version: number; projectId: string | null; exportAvailable: boolean;
  curriculum?: { lessons: Lesson[] }; completed?: string[]; nextLesson?: string | null;
  practice?: { work: Work; activities: { id: string; slug: string; practice: string; passed: boolean; createdAt: string }[];
    submissions: { id: string; sourceVersion: number; createdAt: string }[] };
};
const emptyWork: Work = { result: '', verification: '', newTask: '', transferResult: '' };
const workLabels: Record<keyof Work, string> = {
  result: 'Итоговый результат: текст, ссылка или описание созданного проекта',
  verification: 'Как вы проверили результат и что остаётся ограничением',
  newTask: 'Новая задача для проверки навыка',
  transferResult: 'Результат на новой задаче, доказательства и помощь человека',
};
const statusLabels = {
  payment_required: 'Ожидаем подтверждённую оплату', activation_required: 'Оплата подтверждена — можно начать',
  consent_required: 'Нужно согласие на использование Learning', active: 'Личная программа активна', refunded: 'Оплаченный доступ отозван после полного возврата',
};

export default function ProgramEnrollmentPage() {
  const orderId = new URLSearchParams(typeof location === 'undefined' ? '' : location.search).get('order') || '';
  const validId = /^[a-f0-9]{32}$/.test(orderId), route = 'learning/enrollments/' + orderId;
  const [data, setData] = useState<EnrollmentView | null>(null), [phase, setPhase] = useState<'loading' | 'ready' | 'login' | 'error'>(validId ? 'loading' : 'ready');
  const [busy, setBusy] = useState(false), [error, setError] = useState(''), [message, setMessage] = useState('');
  const [goal, setGoal] = useState(''), [consent, setConsent] = useState(false), [selected, setSelected] = useState('');
  const [answer, setAnswer] = useState(''), [practice, setPractice] = useState(''), [work, setWork] = useState<Work>(emptyWork);
  const [activityDirty, setActivityDirty] = useState(false), [workDirty, setWorkDirty] = useState(false);
  const lock = useRef(false), sequence = useRef(0), alert = useRef<HTMLParagraphElement>(null);
  const routeHeading = useRef<HTMLHeadingElement>(null), focusRoute = useRef(false);
  const dirty = activityDirty || workDirty;
  function fail(cause: unknown) {
    if (cause instanceof CoreError && cause.status === 401) { setCoreToken(''); setData(null); setPhase('login'); }
    else { setError(cause instanceof Error ? cause.message : 'Не удалось открыть личную программу.'); setPhase('error'); }
  }
  async function load() {
    const stamp = ++sequence.current;
    const next = await coreRequest<EnrollmentView>(route);
    if (stamp !== sequence.current) return;
    setData(next); setPhase('ready'); setWork(next.practice?.work || emptyWork);
    setAnswer(''); setPractice('');
    setSelected(current => next.curriculum?.lessons.some(lesson => lesson.slug === current) ? current : next.nextLesson || next.curriculum?.lessons[0]?.slug || '');
    setActivityDirty(false); setWorkDirty(false);
  }
  useEffect(() => {
    if (!validId) return;
    let active = true;
    void load().catch(cause => { if (active) fail(cause); });
    const resume = (event: PageTransitionEvent) => { if (event.persisted) location.reload(); };
    window.addEventListener('pageshow', resume);
    return () => { active = false; sequence.current++; window.removeEventListener('pageshow', resume); };
  }, [orderId]);
  useEffect(() => { if (error) alert.current?.focus(); }, [error]);
  useEffect(() => { if (focusRoute.current && data?.status === 'active') { focusRoute.current = false; routeHeading.current?.focus(); } }, [data?.status]);
  useEffect(() => {
    const leave = (event: BeforeUnloadEvent) => { if (dirty) { event.preventDefault(); event.returnValue = ''; } };
    window.addEventListener('beforeunload', leave); return () => window.removeEventListener('beforeunload', leave);
  }, [dirty]);
  async function run(job: () => Promise<void>) {
    if (lock.current) return;
    lock.current = true; setBusy(true); setError(''); setMessage('');
    try { await job(); } catch (cause) { fail(cause); } finally { lock.current = false; setBusy(false); }
  }
  async function mutate(action: string, body: Record<string, unknown> = {}) {
    const result = await commerceMutation<{ feedback?: { passed: boolean; explanation: string } }>(route, { action, expectedVersion: data?.version || 0, ...body });
    await load();
    return result;
  }
  const lesson = data?.curriculum?.lessons.find(item => item.slug === selected);
  const projectHref = data?.projectId ? '/workspace?project=' + data.projectId : '/workspace';
  return <main className="brand-container core-workspace program-enrollment">
    <section className="core-intro"><p className="brand-eyebrow">OSA LEARNING / ЛИЧНАЯ ПРОГРАММА</p><h1>Практика, которая<br /><em>остаётся с вами.</em></h1>
      <p className="brand-lead">Версия программы, личные попытки и сохранённый итоговый результат. Публичные лекции остаются бесплатными.</p>
      <p><a href="/purchases">Мои покупки</a> · <a href="/learning/program">Бесплатная программа</a></p>
    </section>
    <p ref={alert} tabIndex={-1} role={error ? 'alert' : undefined} hidden={!error} className="core-alert">{error}</p>
    <p role="status">{busy || phase === 'loading' ? 'Проверяем доступ и сохраняем состояние…' : message}</p>
    {!validId && <section className="core-panel"><h2>Выберите учебный заказ</h2><p>Откройте конкретную программу из своих покупок. Приём платежей по умолчанию выключен; до настройки доступны бесплатные лекции.</p><a className="brand-button primary" href="/purchases">Открыть мои покупки</a></section>}
    {phase === 'login' && <section className="core-panel"><h2>Войдите в аккаунт покупателя</h2><p>Работа привязана к аккаунту, для которого оформлен заказ.</p><a className="brand-button primary" href={coreLoginLink('/learning/enrollment?order=' + orderId)}>Войти и продолжить</a></section>}
    {validId && phase !== 'login' && <button className="brand-button" disabled={busy || phase === 'loading'} onClick={() => {
      if (dirty && !confirm('Загрузить серверную версию и заменить несохранённый текст?')) return;
      void run(load);
    }}>Обновить доступ и программу</button>}
    {data && <section className="core-panel"><h2>{data.program.title}</h2><p>{data.program.scope}</p><p><strong>{statusLabels[data.status]}</strong></p>
      <p className="brand-meta">Версия {data.program.version.slice(0, 12)} · {data.program.lessonCount} практик · {data.order.mode === 'test' ? 'Тестовый заказ — реальная оплата не подтверждена' : 'Разовая покупка'}</p>
      <p>Наставник и независимая оценка в эту покупку не входят. Верный ответ самопроверки и сохранённый текст не подтверждают квалификацию.</p>
      {data.status === 'payment_required' && <p>Возврат со страницы Stripe не выдаёт доступ. После подтверждения платежа сервером обновите программу. <a href="/purchases">Проверить заказ →</a></p>}
      {data.status === 'refunded' && <p>{data.exportAvailable ? 'Новые платные практики закрыты. Созданный проект и экспорт ваших работ сохранены.' : 'Новые платные практики закрыты. Этот заказ не был активирован, поэтому личная работа по нему не создавалась.'} Бесплатные лекции доступны по ссылке выше.</p>}
      {data.status === 'consent_required' && <p>Вы отключили Learning в контракте личного проекта. <a href={projectHref}>Открыть проект и проверить согласие →</a></p>}
      {data.status === 'activation_required' && <form onSubmit={event => { event.preventDefault(); void run(async () => {
        focusRoute.current = true; await mutate('activate', { goal, learningConsent: consent }); setGoal(''); setConsent(false); setMessage('Личный проект создан. Начните первую практику.');
      }); }}><fieldset className="core-editor" disabled={busy}><legend>Начать личную практику</legend>
        <label className="core-field"><span>Какой полезный результат вы хотите получить</span><textarea required minLength={10} maxLength={4000} value={goal} onChange={e => setGoal(e.target.value)} /></label>
        <p>Опишите цель минимум в 10 символах и подтвердите согласие ниже — после этого кнопка станет доступна.</p>
        <label className="core-check"><input required type="checkbox" checked={consent} onChange={e => setConsent(e.target.checked)} />Разрешаю Learning использовать контекст нового личного проекта. Продавец не получает доступ к моим практикам.</label>
        <button className="brand-button primary" disabled={!consent || goal.trim().length < 10}>Создать личную практику</button>
      </fieldset></form>}
      {data.projectId && <p><a href={projectHref}>Открыть свой проект в Core и Studio →</a></p>}
    </section>}
    {validId && phase !== 'login' && (data?.exportAvailable || phase === 'error') && <section className="core-panel"><h2>{data?.exportAvailable ? 'Ваши работы доступны для экспорта' : 'Проверить возможность экспорта'}</h2><p>{data?.exportAvailable ? 'Экспорт содержит ваш проект, попытки и итоговые снимки. Он доступен после полного возврата и отключения Learning.' : 'Доступность работы пока не подтверждена. Если вы уже активировали этот заказ в текущем аккаунте, можно отдельно запросить экспорт собственных данных.'}</p>
      <button className="brand-button" disabled={busy} onClick={() => void run(async () => { const exported = await coreRequest<unknown>(route + '/export'); downloadCore(exported, 'osa-program-own-work-' + orderId + '.json'); setMessage('Экспорт ваших работ передан браузеру.'); })}>Экспортировать мои работы</button>
    </section>}
    {data?.status === 'active' && <>
      <section className="core-panel"><h2 ref={routeHeading} tabIndex={-1}>Маршрут практики</h2><p>Сохранено с верной самопроверкой: {data.completed?.length || 0} из {data.program.lessonCount}.</p>
        <label className="core-field"><span>Практика программы</span><select value={selected} disabled={busy} onChange={e => {
          if (activityDirty && !confirm('Сменить практику и удалить её несохранённый ответ?')) return;
          setSelected(e.target.value); setAnswer(''); setPractice(''); setActivityDirty(false);
        }}>{data.curriculum?.lessons.map((item, index) => <option key={item.slug} value={item.slug}>{index + 1}. {item.ru.exercise.title}{data.completed?.includes(item.slug) ? ' · сохранено' : ''}</option>)}</select></label>
        {lesson && <><h3>{lesson.ru.exercise.title}</h3><p>{lesson.ru.example}</p><ol>{lesson.ru.exercise.steps.map(step => <li key={step}>{step}</li>)}</ol><p>{lesson.ru.exercise.successCriteria}</p>
          <details><summary>Источники этой версии</summary>{lesson.ru.sources.map(source => <p key={source.url}><a href={source.url} target="_blank" rel="noopener noreferrer">{source.title}</a> — {source.context}</p>)}</details>
          <form onSubmit={event => { event.preventDefault(); if (workDirty && !confirm('Сохранить практику и загрузить серверную версию итоговой работы? Несохранённый итоговый текст будет заменён.')) return; void run(async () => {
            const result = await mutate('activity', { slug: lesson.slug, locale: 'ru', answer: Number(answer), practice });
            setAnswer(''); setPractice(''); setMessage((result.feedback?.passed ? 'Самопроверка пройдена. ' : 'Ответ требует пересмотра. ') + (result.feedback?.explanation || '') + ' Практический текст сохранён; экспертная оценка не проводилась.');
          }); }}><fieldset className="core-editor" disabled={busy}><legend>Сохранить попытку</legend>
            <label className="core-field"><span>{lesson.ru.check.question}</span><select required value={answer} onChange={e => { setAnswer(e.target.value); setActivityDirty(true); }}><option value="">Выберите ответ</option>{lesson.ru.check.options.map((option, index) => <option key={option} value={index}>{option}</option>)}</select></label>
            <label className="core-field"><span>Результат вашей практики и доказательства</span><textarea required minLength={20} maxLength={10000} value={practice} onChange={e => { setPractice(e.target.value); setActivityDirty(true); }} /></label>
            <p>Выберите ответ и опишите практику минимум в 20 символах. Сохранится и неверная попытка; прогресс изменится только при верной самопроверке.</p>
            <button className="brand-button primary" disabled={answer === '' || practice.trim().length < 20}>Сохранить практику</button>
          </fieldset></form>
          <details><summary>Мои сохранённые попытки этой практики</summary>{data.practice?.activities.filter(item => item.slug === lesson.slug).map(item => <article key={item.id} className="core-source"><p>{new Date(item.createdAt).toLocaleString('ru-RU')} · {item.passed ? 'Верная самопроверка' : 'Нужен другой ответ'}</p><p className="client-copy">{item.practice}</p></article>)}</details>
        </>}
      </section>
      <section className="core-panel"><h2>Итоговая работа</h2><p>Сохраните результат и проверку на новой задаче. Сдача фиксирует вашу версию; она не является одобрением наставника.</p>
        <form onSubmit={event => { event.preventDefault(); if (activityDirty && !confirm('Сохранить итоговый текст и сбросить несохранённую попытку практики?')) return; void run(async () => { await mutate('save_work', { work }); setAnswer(''); setPractice(''); setMessage('Черновик итоговой работы сохранён на сервере.'); }); }}>
          <fieldset className="core-editor" disabled={busy}>{(Object.keys(workLabels) as (keyof Work)[]).map(field => <label className="core-field" key={field}><span>{workLabels[field]}</span><textarea maxLength={10000} value={work[field]} onChange={e => { setWork(value => ({ ...value, [field]: e.target.value })); setWorkDirty(true); }} /></label>)}
            <button className="brand-button" disabled={!workDirty}>Сохранить итоговую работу</button>
          </fieldset>
        </form>
        <p>Для итогового снимка нужны все {data.program.lessonCount} практик с верной самопроверкой, не менее 20 символов в каждом итоговом поле и сохранённые изменения. Это проверка заполнения, без оценки содержания наставником.</p>
        <button className="brand-button primary" disabled={busy || dirty || data.completed?.length !== data.program.lessonCount || Object.values(work).some(value => value.trim().length < 20)} onClick={() => void run(async () => { await mutate('submit'); setMessage('Итоговая версия сохранена. Это ваша сдача, без независимой оценки навыка.'); })}>Зафиксировать итоговую версию</button>
        {data.practice?.submissions.map(item => <p key={item.id}>Сдача {item.id.slice(0, 8)} · версия практики {item.sourceVersion} · {new Date(item.createdAt).toLocaleString('ru-RU')} · доступна в экспорте.</p>)}
      </section>
    </>}
  </main>;
}
