const ALLOWED = new Set(['/teams','/deliveries','/purchases','/workspace', '/workspace/overview', '/account', '/learning/campus', '/learning/organizer', '/learning/enrollment', '/games/remix']);
export function safeReturnTo(value: string | null | undefined) {
    if (!value || value.length > 1000 || /[\\\r\n]/.test(value) || !value.startsWith('/') || value.startsWith('//'))
        return '/workspace';
    try {
        const u = new URL(value, 'https://osgard.invalid'), pathname=u.pathname.replace(/\/+$/, '')||'/';
        if (u.origin !== 'https://osgard.invalid' || !ALLOWED.has(pathname) || u.hash)
            return '/workspace';
        const p = new URLSearchParams();
        if (pathname === '/games/remix') {
            const challenge = u.searchParams.get('challenge'), lang = u.searchParams.get('lang');
            if (challenge && /^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$/.test(challenge)) p.set('challenge', challenge);
            if (lang === 'ru' || lang === 'en') p.set('lang', lang);
            if (u.searchParams.get('mode') === 'account') p.set('mode', 'account');
            return '/games/remix/' + (p.size ? '?' + p : '');
        }
        for (const key of ['project', 'submission','delivery','team','order']) {
            const v = u.searchParams.get(key);
            if (v && /^[a-f0-9]{32}$/.test(v))
                p.set(key, v);
        }
        const tab = u.searchParams.get('tab');
        if(tab&&['contract','learning','studio','acceptance','delivery','clients','business','memory','results','history'].includes(tab))p.set('tab',tab);
        const panel = u.searchParams.get('panel');
        if (panel && ['path', 'final', 'pilot'].includes(panel))
            p.set('panel', panel);
        if (u.searchParams.get('intent') === 'review')
            p.set('intent', 'review');
        return pathname + (p.size ? '?' + p : '');
    }
    catch {
        return '/workspace';
    }
}
export function coreLoginLink(value: string) { return '/workspace?returnTo=' + encodeURIComponent(safeReturnTo(value)); }
export function recoveryDocument(username: string, batchId: string, codes: string[]) { return ['OSGARD Core — резервные коды', `Аккаунт: ${username}`, `Набор: ${batchId}`, 'Активируйте этот набор на странице аккаунта после сохранения.', 'Один код восстанавливает доступ и аннулирует все старые коды и сессии.', 'Храните файл отдельно от пароля. Сервер не показывает коды повторно.', '', ...codes].join('\n') + '\n'; }
export function downloadRecovery(username: string, batchId: string, codes: string[]) { const url = URL.createObjectURL(new Blob([recoveryDocument(username, batchId, codes)], { type: 'text/plain;charset=utf-8' })), a = document.createElement('a'); a.href = url; a.download = 'osgard-recovery-' + batchId + '.txt'; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); }

export function coreAuthReturn(pathname:string,search:string){const requested=new URLSearchParams(search).get('returnTo');return safeReturnTo(requested===null?pathname+search:requested)}
