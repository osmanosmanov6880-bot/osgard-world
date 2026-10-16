import {coreLoginLink} from './accountAccess'
import { useEffect, useState } from 'react';
import { useLearningProject } from './coreLearningClient';
import './learningCampus.css';
export default function ServerLessonProgress({ slug, answer, locale }: {
    slug: string;
    answer: number | null;
    locale: 'ru' | 'en';
}) {
    const core = useLearningProject(), [practice, setPractice] = useState(''), [feedback, setFeedback] = useState<{
        passed: boolean;
        explanation: string;
    } | null>(null);
    const en = locale === 'en', t = (ru: string, english: string) => en ? english : ru;
    useEffect(() => { const leave = (e: BeforeUnloadEvent) => { if (practice.trim()) {
        e.preventDefault();
        e.returnValue = '';
    } }; window.addEventListener('beforeunload', leave); return () => window.removeEventListener('beforeunload', leave); }, [practice]);
    useEffect(() => { setPractice(''); setFeedback(null); }, [slug]);
    const history = core.data?.activities.filter(a => a.slug === slug) || [];
    return <section className="learning-bridge campus"><p className="brand-eyebrow">OSA / SERVER LEARNING RECORD</p><h2>{t('Сохранить практику в проект', 'Save practice to a project')}</h2><p>{t('Гостевая отметка выше остаётся в браузере. Здесь можно отдельно сохранить ответ и практику на сервере Core. Данные передаются только по кнопке сохранения.', 'The guest mark above stays in this browser. Save your answer and practice separately to the Core server. Content is sent only when you save.')}</p>
 {core.phase === 'idle' && <button className="brand-button" disabled={core.busy} onClick={() => void core.connect()}>{t('Подключить серверный проект', 'Connect a server project')}</button>}
 {core.phase === 'login' && <p><a href={coreLoginLink('/learning/campus')}>{t('Войти в Core или создать аккаунт →', 'Sign in to Core or create an account →')}</a></p>}
 {core.phase === 'offline' && <p>{t('Сервер Core не подключён. Гостевое обучение продолжает работать.', 'Core server is not connected. Guest learning remains available.')}</p>}
 {core.error && <p role="alert" className="campus-error">{core.error}</p>}<p role="status">{core.busy ? t('Сохраняем или загружаем…', 'Saving or loading…') : core.notice}</p>
 {core.phase === 'ready' && <><label className="campus-field"><span>{t('Проект с разрешением Learning', 'Project with Learning permission')}</span><select value={core.project?.id || ''} disabled={core.busy} onChange={e => { if (!practice.trim() || confirm(t('Сменить проект? Текст практики останется в поле.', 'Switch project? Your practice text stays in the field.')))
            void core.select(e.target.value); }}><option value="">{t('Выберите проект', 'Select a project')}</option>{core.projects.filter(p => p.data.consents.learning).map(p => <option key={p.id} value={p.id}>{p.data.title} / v{p.version}</option>)}</select></label>{!core.projects.some(p => p.data.consents.learning) && <p><a href="/workspace">{t('Создайте проект и разрешите Learning в контракте →', 'Create a project and enable Learning in its contract →')}</a></p>}
 {core.project && <><p>{core.data?.completed.includes(slug) ? t('По этому уроку уже сохранены практика и верный ответ текущей версии.', 'Practice and a correct answer are already saved for the current lesson version.') : t('Практика этого урока ещё не зафиксирована.', 'This lesson practice has not been recorded yet.')}</p><label className="campus-field"><span>{t('Результат упражнения и ограничения — минимум 20 символов', 'Exercise result and limitations — at least 20 characters')}</span><textarea maxLength={10000} value={practice} disabled={core.busy || core.project.role === 'viewer'} onChange={e => setPractice(e.target.value)}/></label><p>{answer === null ? t('Выберите ответ в самопроверке урока выше.', 'Choose an answer in the lesson self-check above.') : t('В серверную запись попадёт выбранный ответ самопроверки.', 'The selected self-check answer will be included in the server record.')}</p><div className="campus-actions"><button className="brand-button primary" disabled={core.busy || core.project.role === 'viewer' || practice.trim().length < 20 || answer === null || !!core.pending} onClick={async () => { const r = await core.commit({ action: 'activity', slug, answer, practice, locale }); if (r) {
            setFeedback(r.feedback);
            setPractice('');
        } }}>{t('Сохранить ответ и практику', 'Save answer and practice')}</button><button className="brand-button" disabled={core.busy} onClick={() => void core.reload()}>{t('Обновить с сервера', 'Refresh from server')}</button></div>{feedback && <p role="status">{feedback.passed ? t('Самопроверка верна. ', 'Self-check correct. ') : t('Ответ требует пересмотра. ', 'Review your answer. ')}{feedback.explanation}</p>}{core.pending && <p><button className="brand-button" disabled={core.busy} onClick={async () => { const r = await core.commit({}, true); if (r) {
            setFeedback(r.feedback);
            setPractice('');
        } }}>{t('Повторить незавершённую запись', 'Retry pending record')}</button> <a href="/workspace">Core →</a></p>}{history.length > 0 && <details><summary>{t('Сохранённые попытки этого урока', 'Saved attempts for this lesson')} ({history.length})</summary>{history.map(a => <article key={a.id} className="campus-record"><p>{a.actor} · {new Date(a.createdAt).toLocaleString(en ? 'en-GB' : 'ru-RU')} · {a.passed ? '✓' : '○'}</p><p>{a.practice}</p></article>)}</details>}<p><a href="/learning/campus">{t('Перейти к итоговой работе и расписанию →', 'Open final project and schedule →')}</a></p></>}
 </>}
 <p className="campus-muted">{t('Верный ответ проверяет сервер по существующему учебному материалу. Содержание практики требует человеческого разбора; это не экзамен и не сертификат.', 'The server checks the answer against the existing curriculum. Practice content requires human review; this is not an exam or a certificate.')}</p>
 </section>;
}
