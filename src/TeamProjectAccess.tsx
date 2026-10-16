import { useEffect, useState } from 'react';
import { coreRequest } from './coreClient';
export default function TeamProjectAccess({ projectId, version, disabled, onDetach }: {
    projectId: string;
    version: number;
    disabled: boolean;
    onDetach: () => Promise<unknown>;
}) {
    const [context, setContext] = useState<{
        team: {
            id: string;
            name: string;
        } | null;
        canDetach: boolean;
    } | null>(null), [error, setError] = useState('');
    useEffect(() => { let active = true;setContext(null);setError(''); void coreRequest<typeof context>('projects/' + projectId + '/team').then(r => { if (active)
        setContext(r); }).catch(e => { if (active)
        setError(e.message); }); return () => { active = false; }; }, [projectId, version]);
    return <section className="core-panel"><h3>Командный доступ</h3>{error && <p role="alert">{error}</p>}{!context && !error && <p>Проверяем подключение команды…</p>}{context?.team ? <><p>Проект подключён: {context.team.name}. Командные роли дополняют личные.</p><a className="brand-button" href={'/teams?team=' + context.team.id}>Открыть команду</a>{context.canDetach && <button className="brand-button" disabled={disabled} onClick={() => { if (confirm('Отключить весь командный доступ? Отдельно назначенные личные роли сохранятся.'))
        void onDetach(); }}>Отключить проект от команды</button>}</> : context && <p>Проект не подключён к команде. Подключение выполняет владелец проекта в разделе «Команды».</p>}<a className="brand-button" href="/teams">Все команды</a></section>;
}
