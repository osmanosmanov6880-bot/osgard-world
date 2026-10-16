import { useCallback, useEffect, useRef, useState } from 'react';
import { coreRequest, downloadCore } from './coreClient';

type Readiness = {
    format: 'osgard-studio-readiness-v1';
    projectId: string;
    sourceVersion: number;
    snapshotSha256: string;
    generatedAt: string;
    canCreateInternalRelease: boolean;
    checks: { id: string; label: string; passed: boolean }[];
    nextAction: string;
    warnings: string[];
    artifact: {
        kind: 'local_html' | 'external_url' | 'missing';
        sourceVersion: number | null;
        actualSha256: string | null;
        integrityMatches: boolean | null;
        inputsMatch: boolean | null;
    };
};

export default function CoreReleaseReadiness({ projectId, version, studioEnabled, hasUnsavedChanges, disabled }: {
    projectId: string;
    version: number;
    studioEnabled: boolean;
    hasUnsavedChanges: boolean;
    disabled: boolean;
}) {
    const [report, setReport] = useState<Readiness | null>(null);
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState('');
    const requestNumber = useRef(0);
    const refresh = useCallback(async () => {
        const request = ++requestNumber.current;
        setBusy(true);
        setError('');
        try {
            const result = await coreRequest<Readiness>('projects/' + projectId + '/readiness');
            if (request === requestNumber.current) setReport(result);
        } catch (failure) {
            if (request === requestNumber.current) {
                setReport(null);
                setError(failure instanceof Error ? failure.message : 'Не удалось проверить сохранённую версию.');
            }
        } finally {
            if (request === requestNumber.current) setBusy(false);
        }
    }, [projectId]);

    useEffect(() => {
        setReport(null);
        setError('');
        if (studioEnabled) void refresh();
        else setBusy(false);
        return () => { requestNumber.current += 1; };
    }, [projectId, version, studioEnabled, refresh]);

    const newerVersion = report !== null && report.sourceVersion !== version;
    const canExport = report !== null && !newerVersion && !hasUnsavedChanges && !busy;
    return <section className="core-panel" aria-labelledby="core-readiness-title" aria-busy={busy}>
        <p className="brand-eyebrow">Studio / проверяемый выпуск</p>
        <h2 id="core-readiness-title">Проверка версии перед выпуском</h2>
        <p>Сверяем сохранённый HTML, его контрольную сумму и данные, из которых он собран. После изменения цели или состава проекта старый файл потребуется пересобрать.</p>
        {!studioEnabled ? <p>Включите Studio в контракте и сохраните разрешение, чтобы проверить результат.</p> : <>
            {hasUnsavedChanges && <p className="core-note" role="status">В редакторе есть изменения. Сохраните их, чтобы отчёт учитывал текущую работу.</p>}
            {newerVersion && <p className="core-alert" role="status">На сервере уже версия {report.sourceVersion}, в редакторе — {version}. Нажмите «Обновить» в шапке проекта.</p>}
            {error && <p className="core-alert" role="alert">{error}</p>}
            <div className="brand-actions">
                <button type="button" className="brand-button" disabled={disabled || busy || hasUnsavedChanges} onClick={() => void refresh()}>{busy ? 'Проверяем сохранённую версию…' : 'Обновить проверку'}</button>
                <button type="button" className="brand-button" disabled={disabled || !canExport} onClick={() => {
                    if (report) downloadCore(report, 'osgard-readiness-' + projectId + '-v' + report.sourceVersion + '.json');
                }}>Скачать отчёт</button>
            </div>
            {report && <>
                <p role="status"><strong>{hasUnsavedChanges || newerVersion ? 'Отчёт относится к сохранённой версии ' + report.sourceVersion : report.canCreateInternalRelease ? 'Готово к внутреннему выпуску' : 'Перед выпуском нужны изменения'}</strong></p>
                <p>{report.nextAction}</p>
                <ul className="core-report">{report.checks.map(check => <li key={check.id}><strong>{check.passed ? 'Пройдено' : 'Требует действия'}</strong> — {check.label}</li>)}</ul>
                <details className="core-source">
                    <summary>Версия, файл и границы проверки</summary>
                    <p>Версия проекта: {report.sourceVersion}. Проверено: {new Date(report.generatedAt).toLocaleString('ru-RU')}.</p>
                    <p>Артефакт: {report.artifact.kind === 'local_html' ? 'сохранённый HTML; исходная версия ' + report.artifact.sourceVersion : report.artifact.kind === 'external_url' ? 'внешняя ссылка, её содержимое не проверено' : 'ещё не создан'}.</p>
                    <p>SHA-256 снимка проекта:</p><code style={{ overflowWrap: 'anywhere' }}>{report.snapshotSha256}</code>
                    {report.artifact.actualSha256 && <><p>SHA-256 содержимого HTML:</p><code style={{ overflowWrap: 'anywhere' }}>{report.artifact.actualSha256}</code></>}
                    <ul>{report.warnings.map(warning => <li key={warning}>{warning}</li>)}</ul>
                    <p>Отчёт не публикует сайт, не запускает произвольный код, не проверяет внешние ссылки и не подтверждает оплату. Разбор другим участником выполняется отдельно во вкладке «Приёмка».</p>
                </details>
            </>}
        </>}
    </section>;
}
