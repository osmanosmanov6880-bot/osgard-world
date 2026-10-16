export type CheckItem = {
    id: string;
    title: string;
    done: boolean;
};
export type SourceItem = {
    id: string;
    title: string;
    url: string;
    notes: string;
    checkedAt: string;
    expiresAt: string;
};
export type CoreData = {
    schemaVersion: 1;
    title: string;
    goal: string;
    audience: string;
    deadline: string;
    currency: 'RUB' | 'USD' | 'EUR';
    budgetMinor: number;
    accepted: boolean;
    allowedActions: string[];
    acceptance: CheckItem[];
    tasks: CheckItem[];
    sources: SourceItem[];
    decisions: {
        id: string;
        text: string;
        at: string;
    }[];
    lessonCompletions: string[];
    practice: {
        problem: string;
        before: string;
        newTask: string;
        after: string;
        evidence: string;
    };
    artifact: {
        url: string;
        checksum: string;
        notes: string;
        assetId: string;
    };
    offer: {
        title: string;
        customer: string;
        scope: string;
        amountMinor: number;
    };
    measurements: {
        id: string;
        task: string;
        beforeSeconds: number;
        afterSeconds: number;
        correctionSeconds: number;
        manualSeconds: number;
        success: boolean;
        evidence: string;
        at: string;
    }[];
    consents: {
        learning: boolean;
        studio: boolean;
        business: boolean;
    };
    costs: {
        id: string;
        amountMinor: number;
        category: string;
        note: string;
        at: string;
    }[];
    orders: {
        id: string;
        status: 'draft' | 'cancelled';
        amountMinor: number;
        currency: string;
        title: string;
        customer: string;
        scope: string;
        at: string;
    }[];
    releases: {
        id: string;
        at: string;
        url: string;
        status: string;
    }[];
};
export type CoreProject = {
    id: string;
    version: number;
    role: 'owner' | 'editor' | 'viewer';
    data: CoreData;
    economics: {
        draftOfferMinor: number;
        confirmedRevenueMinor: number;
        refundsMinor: number;
        costMinor: number;
        contributionMinor: number;
        budgetRemainingMinor: number;
    };
    metrics: {
        sampleSize: number;
        baselineSeconds: number;
        assistedTotalSeconds: number;
        speedRatio: number | null;
        successRate: number | null;
    };
    updatedAt: string;
    createdAt: string;
};
export type CoreUser = {
    id: string;
    username: string;
};
export type PendingOperation = {
    userId: string;
    route: string;
    key: string;
    body: Record<string, unknown>;
};
const TOKEN = 'osgard:core-session:v1', PENDING = 'osgard:core-pending:v1';
let token = '';
try {
    token = sessionStorage.getItem(TOKEN) || '';
}
catch { /* Memory-only sessions still work. */ }
export function setCoreToken(value: string) { token = value; try {
    if (value)
        sessionStorage.setItem(TOKEN, value);
    else
        sessionStorage.removeItem(TOKEN);
}
catch { /* Explicit login remains valid in this tab. */ } }
export function refreshCoreToken(){try{token=sessionStorage.getItem(TOKEN)||''}catch{/* Preserve a memory-only session. */}}
if(typeof window!=='undefined')window.addEventListener('pageshow',event=>{if(event.persisted)refreshCoreToken()})
export class CoreError extends Error {
    constructor(public code: string, message: string, public status = 0) { super(message); }
}
export async function coreRequest<T>(route: string, body?: Record<string, unknown>, key?: string): Promise<T> {
    const controller = new AbortController(), timer = setTimeout(() => controller.abort(), 20000);
    try {
        const response = await fetch('/api/core/' + route, { method: body ? 'POST' : 'GET', headers: { Accept: 'application/json', ...(body ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: 'Bearer ' + token } : {}), ...(key ? { 'Idempotency-Key': key } : {}) }, body: body ? JSON.stringify(body) : undefined, signal: controller.signal, credentials: 'omit', cache: 'no-store' });
        if (!response.headers.get('content-type')?.includes('application/json'))
            throw new CoreError('server_offline', 'Сервер Core не подключён. Используйте серверный запуск из полного архива.', response.status);
        const result = await response.json();
        if (!response.ok)
            throw new CoreError(result.error || 'request', result.message || 'Не удалось выполнить запрос.', response.status);
        return result as T;
    }
    catch (error) {
        if (error instanceof CoreError)
            throw error;
        throw new CoreError('connection', 'Связь прервалась. Операция могла сохраниться: повторите её с тем же ключом.');
    }
    finally {
        clearTimeout(timer);
    }
}
let memoryPending: PendingOperation | null | undefined
export function readPending(): PendingOperation | null { if(memoryPending!==undefined)return memoryPending;try {
    const v = JSON.parse(sessionStorage.getItem(PENDING) || 'null');
    return v && typeof v.userId === 'string' && typeof v.route === 'string' && /^[a-zA-Z0-9_-]{16,100}$/.test(v.key) && v.body && typeof v.body === 'object' ? v : null;
}
catch {
    return null;
} }
export function storePending(v: PendingOperation | null) { memoryPending=v;try {
    if (v)
        sessionStorage.setItem(PENDING, JSON.stringify(v));
    else
        sessionStorage.removeItem(PENDING);
}
catch { /* UI keeps an in-memory retry even when storage is blocked. */ } }
export function minorUnits(value: string): number { if (!/^\d{1,9}(?:[.,]\d{1,2})?$/.test(value.trim()))
    throw new Error('Введите неотрицательную сумму, максимум два знака после запятой.'); const [major, fraction = ''] = value.trim().replace(',', '.').split('.'); return Number(major) * 100 + Number(fraction.padEnd(2, '0')); }
export function formatMoney(value: number, currency: string) { return new Intl.NumberFormat('ru-RU', { style: 'currency', currency }).format(value / 100); }
export function downloadCore(value: unknown, name: string) { const url = URL.createObjectURL(new Blob([JSON.stringify(value, null, 2)], { type: 'application/json' })); const a = document.createElement('a'); a.href = url; a.download = name; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); }
export function practiceRecommendation(problem: string) { return /приват|персонал|парол|privacy|personal/i.test(problem) ? 'privacy-before-prompting' : /источник|факт|провер|source|verif/i.test(problem) ? 'verify-an-ai-answer' : 'how-language-models-work'; }
