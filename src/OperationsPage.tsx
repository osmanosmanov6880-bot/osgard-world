import { useEffect, useRef, useState } from 'react';
import { coreRequest, CoreError, downloadCore, formatMoney } from './coreClient';
import { coreLoginLink } from './accountAccess';
import './coreWorkspace.css';
export type OverviewProject = {
    id: string;
    title: string;
    version: number;
    role: string;
    updatedAt: string;
    issues: string[];
    nextAction: {
        stage: string;
        label: string;
    };
    jobs: {
        queued: number;
        running: number;
        completed: number;
        failed: number;
    };
    checks: {
        passed: number;
        total: number;
    };
    learning: {
        myCurrentPractices: number;
        curriculumSize: number;
    } | null;
    latestRelease: {
        sourceVersion: number | null;
        verdict: string | null;
        matchesCurrentArtifactAndScope: boolean;
    } | null;
    delivery: {
        pendingReceipts: number;
        openTickets: number;
        resolvedTickets: number;
        handoffs: number;
    } | null;
    economics: {
        currency: string;
        costMinor: number;
        budgetRemainingMinor: number;
    } | null;
    measurements: {
        sampleSize: number;
        speedRatio: number | null;
        successRate: number | null;
    };
};
type Overview = {
    generatedAt: string;
    projects: OverviewProject[];
    counts: {
        projects: number;
        attentionProjects: number;
        measurementRecords: number;
    };
    jobs: {
        queued: number;
        running: number;
        completed: number;
        failed: number;
    };
    currencies: Record<string, {
        costMinor: number;
        budgetMinor: number;
        contributionMinor: number;
        confirmedRevenueMinor: number;
        projects: number;
    }>;
    truncated: boolean;
    runtime: {
        uptimeSeconds: number;
        workerRegistered: boolean;
        workerAlive: boolean | null;
        lastCycleAt: string | null;
        secondsSinceCycle: number | null;
        storageHealthy: boolean | null;
        storageErrorsSinceStart: number | null;
    };
};
export function projectActionLink(p: Pick<OverviewProject, 'id' | 'nextAction'>) { if (!/^[a-f0-9]{32}$/.test(p.id))
    throw Error('Некорректный проект.'); return p.nextAction.stage === 'campus' ? '/learning/campus?project=' + p.id : '/workspace?project=' + p.id + '&tab=' + (['contract', 'learning', 'studio', 'acceptance', 'delivery', 'clients', 'business', 'memory', 'results', 'history'].includes(p.nextAction.stage) ? p.nextAction.stage : 'contract'); }
const issues: Record<string, string> = { client_support:'Открытая поддержка в кабинете получателя',expired_sources: 'Источники требуют проверки', over_budget: 'Расходы выше бюджета', failed_checks: 'Есть неудачные фоновые проверки', release_changes: 'Замечания к выпуску', unreleased_changes: 'Есть изменения после выпуска', receipt_waiting: 'Ожидается ваше подтверждение', open_support: 'Открытая поддержка', solution_waiting: 'Предложенное решение требует проверки' };
export default function OperationsPage() {
    const [phase, setPhase] = useState<'loading' | 'ready' | 'login' | 'offline'>('loading'), [report, setReport] = useState<Overview | null>(null), [busy, setBusy] = useState(false), [error, setError] = useState(''), [search, setSearch] = useState(''), [filter, setFilter] = useState('all');
    const lock = useRef(false), ref = useRef<HTMLParagraphElement>(null);
    async function load() { if (lock.current)
        return; lock.current = true; setBusy(true); setError(''); try {
        const r = await coreRequest<Overview>('overview');
        setReport(r);
        setPhase('ready');
    }
    catch (e) {
        setError(e instanceof Error ? e.message : 'Не удалось получить состояние.');
        if (e instanceof CoreError && e.status === 401) {
            setReport(null);
            setPhase('login');
        }
        else if (!report)
            setPhase('offline');
    }
    finally {
        lock.current = false;
        setBusy(false);
    } }
    useEffect(() => { void load(); const resume = (e: PageTransitionEvent) => { if (e.persisted)
        void load(); }; window.addEventListener('pageshow', resume); return () => window.removeEventListener('pageshow', resume); }, []);
    useEffect(() => { if (error)
        ref.current?.focus(); }, [error]);
    const list = report?.projects.filter(p => (filter === 'all' || filter === 'attention' && p.issues.length || filter === 'queue' && (p.jobs.queued + p.jobs.running > 0)) && p.title.toLocaleLowerCase('ru').includes(search.trim().toLocaleLowerCase('ru'))) || [];
    return <main className="brand-container core-workspace"><section className="core-intro"><p className="brand-eyebrow">OSGARD CORE / OPERATIONS</p><h1>Видеть состояние.<br /><em>Двигаться дальше.</em></h1><p className="brand-lead">Проекты, очередь проверок, передача и поддержка в одном рабочем центре. Рекомендации основаны на сохранённых данных, а не на ответах подключённой AI-модели.</p><div className="brand-actions"><a className="brand-button primary" href="/workspace">Создать или открыть проект</a><a className="brand-button" href="/learning/organizer">Организация обучения</a><a className="brand-button" href="/account">Доступ к аккаунту</a></div></section><p ref={ref} tabIndex={-1} role={error ? 'alert' : undefined} hidden={!error} className="core-alert">{error}</p><p role="status">{busy ? 'Обновляем состояние…' : ''}</p>
 {phase === 'loading' && <p role="status">Подключаем рабочий центр…</p>}{phase === 'login' && <section className="core-panel"><h2>Войдите в Core</h2><p>Сводка доступна только для проектов вашего аккаунта.</p><a className="brand-button primary" href={coreLoginLink('/workspace/overview')}>Войти и вернуться к сводке</a></section>}{phase === 'offline' && <section className="core-panel"><h2>Нужен сервер Core</h2><p>Запустите полный комплект через START-CORE-WINDOWS.bat. Статическая версия не хранит серверные проекты и не исполняет очередь.</p><button className="brand-button" onClick={() => void load()} disabled={busy}>Проверить подключение</button><a className="brand-button" href="/learning/workspace">Гостевая мастерская</a></section>}
 {phase === 'ready' && report && <><section className="core-panel"><h2>Снимок состояния</h2><p>{new Date(report.generatedAt).toLocaleString('ru-RU')} · проектов: {report.counts.projects} · требуют внимания: {report.counts.attentionProjects} · пользовательских наблюдений: {report.counts.measurementRecords}</p><p>Это снимок на указанное время. Автоматического опроса и внешних уведомлений нет.</p><button className="brand-button" disabled={busy} onClick={() => void load()}>Обновить сводку</button><button className="brand-button" disabled={busy} onClick={() => downloadCore(report, 'osgard-operational-snapshot.json')}>Скачать снимок JSON</button><p>В файле есть названия и состояние доступных проектов. Тексты практик, переписки, пароли и токены в сводку не входят.</p>{report.truncated && <p className="core-alert">Показаны первые 200 доступных проектов. Итоги относятся только к этому списку.</p>}</section>
 <section className="core-panel"><h2>Исполнение в этом процессе</h2><p>{!report.runtime.workerRegistered ? 'Исполнитель не зарегистрирован в этом HTTP-сервере.' : report.runtime.workerAlive ? 'Поток исполнителя запущен.' : 'Поток исполнителя остановлен.'} Последний успешный цикл: {report.runtime.lastCycleAt ? new Date(report.runtime.lastCycleAt).toLocaleString('ru-RU') : 'ещё не зафиксирован'}.</p><p>Очередь доступных проектов: ожидают {report.jobs.queued}, выполняются {report.jobs.running}, завершены {report.jobs.completed}, ошибки {report.jobs.failed}. Завершение проверки не означает, что все критерии пройдены.</p><p>Ошибок хранилища у исполнителя с запуска: {report.runtime.storageErrorsSinceStart ?? 'нет данных'}. {report.runtime.storageHealthy === false ? 'Последний цикл столкнулся с ошибкой хранилища.' : ''}</p><p>Работающий поток не подтверждает здоровье всей инфраструктуры, внешних сервисов и резервных копий.</p></section>
 <section className="core-panel"><h2>Учтённые расходы</h2>{!Object.keys(report.currencies).length && <p>Нет проектов с включённым Business. Итог не рассчитан.</p>}{Object.entries(report.currencies).map(([currency, total]) => <div className="core-source" key={currency}><strong>{currency} · проектов: {total.projects}</strong><p>Расходы: {formatMoney(total.costMinor, currency)} · бюджет: {formatMoney(total.budgetMinor, currency)} · вклад: {formatMoney(total.contributionMinor, currency)}</p></div>)}<p>Валюты не складываются друг с другом. Выручка не подтверждена; платежи не подключены. Расходы внесены участниками.</p></section>
 <section className="core-panel"><h2>Проекты и следующий шаг</h2><div className="core-two"><label className="core-field"><span>Найти по названию</span><input type="search" value={search} onChange={e => setSearch(e.target.value)}/></label><label className="core-field"><span>Показать</span><select value={filter} onChange={e => setFilter(e.target.value)}><option value="all">Все доступные</option><option value="attention">Требуют внимания</option><option value="queue">Есть работа в очереди</option></select></label></div><p role="status">Найдено: {list.length}.</p>{!report.projects.length && <p>Пока нет доступных проектов. Создайте одну цель в рабочем пространстве.</p>}{report.projects.length > 0 && !list.length && <p>Под эти условия ничего не найдено. Измените запрос или покажите все проекты.</p>}{list.map(p => <article className="core-source" key={p.id}><p className="brand-eyebrow">{p.role} / v{p.version}</p><h3>{p.title}</h3><p>Структурных условий: {p.checks.passed}/{p.checks.total}. Отметки критериев задаются человеком.</p>{p.learning && <p>Ваших практик текущей версии: {p.learning.myCurrentPractices}/{p.learning.curriculumSize}.</p>}{p.latestRelease && <p>Последний выпуск из версии {p.latestRelease.sourceVersion ?? 'не записана'}: {p.latestRelease.verdict === 'accepted' ? 'разобран положительно участником' : p.latestRelease.verdict === 'needs_changes' ? 'есть замечания' : 'ожидает разбора'}. {p.latestRelease.matchesCurrentArtifactAndScope ? '' : 'Текущий результат отличается от снимка выпуска.'}</p>}{p.issues.map(i => <p key={i}>{issues[i] || 'Проверьте состояние проекта'}</p>)}{p.measurements.sampleSize > 0 && <p>Наблюдений: {p.measurements.sampleSize}. Соотношение времени: {p.measurements.speedRatio ?? 'нет данных'}. Это введённые участниками данные, не доказательство улучшения навыка.</p>}<a className="brand-button primary" href={projectActionLink(p)}>{p.nextAction.label}</a></article>)}</section></>}
 </main>;
}
