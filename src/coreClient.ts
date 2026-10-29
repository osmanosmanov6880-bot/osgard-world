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
/* V63: real authenticated private byte transfer, never a public streaming URL. */
export type CinemaVaultUploadResult = {
 assetId:string; spaceId:string; spaceVersion:number; actualSha256:string;
 checksumComputedFromBytes:true;bytes:number;mime:string;name:string;
 malwareScanned:false;encryptionAtRest:false;releaseAuthorized:false;publicVideoUrl:null;replayed:boolean;
};
const cinemaVaultTypes: Record<string,string> = {
 pdf:'application/pdf',txt:'text/plain',png:'image/png',jpg:'image/jpeg',
 jpeg:'image/jpeg',webp:'image/webp',mp4:'video/mp4'
};
export function cinemaVaultMime(filename:string): string {
 const ext=filename.toLowerCase().split('.').pop()||'';
 return cinemaVaultTypes[ext]||'';
}
async function vaultError(response:Response):Promise<CoreError>{
 if(!response.headers.get('Content-Type')?.includes('application/json'))
  return new CoreError('server_offline','OSGARD Core не подключён.',response.status);
 try{
  const result=await response.json() as {error?:string;message?:string};
  return new CoreError(result.error||'request',result.message||'Не удалось передать файл.',response.status);
 }catch{return new CoreError('invalid_response','Сервер вернул неверный ответ.',response.status)}
}
export async function uploadCoreCinemaAsset(
 spaceId:string,expectedVersion:number,file:File,key:string,evidenceId=''
):Promise<CinemaVaultUploadResult>{
 if(!/^[a-f0-9]{32}$/.test(spaceId)||!Number.isInteger(expectedVersion)||expectedVersion<1)
  throw new CoreError('validation','Выберите действительное рабочее пространство.');
 if(file.size<=0||file.size>8*1024*1024)
  throw new CoreError('file_size','Доступны файлы до 8 МиБ.');
 const mime=cinemaVaultMime(file.name);
 if(!mime)throw new CoreError('file_type','Разрешены PDF, TXT, PNG, JPG, WebP и MP4.');
 if(!/^[A-Za-z0-9_-]{16,100}$/.test(key))
  throw new CoreError('idempotency','Неверный ключ загрузки.');
 if(evidenceId&&!/^[a-f0-9]{32}$/.test(evidenceId))
  throw new CoreError('validation','Неверный идентификатор материала.');
 const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),45000);
 try{
  const r=await fetch('/api/core/cinema/spaces/'+spaceId+'/vault/upload',{
   method:'POST',credentials:'omit',cache:'no-store',signal:controller.signal,
   headers:{'Authorization':'Bearer '+token,'Content-Type':mime,
    'X-Cinema-File-Name':encodeURIComponent(file.name),
    'X-Space-Version':String(expectedVersion),'Idempotency-Key':key,
    ...(evidenceId?{'X-Cinema-Evidence-Id':evidenceId}:{})},
   body:file
  });
  if(!r.ok)throw await vaultError(r);
  if(!r.headers.get('Content-Type')?.includes('application/json'))
   throw new CoreError('invalid_response','Сервер вернул неверный ответ.');
  return await r.json() as CinemaVaultUploadResult;
 }catch(e){
  if(e instanceof CoreError)throw e;
  throw new CoreError('connection','Связь прервалась. Повторите загрузку с тем же файлом и ключом.');
 }finally{clearTimeout(timer)}
}
export async function downloadCoreCinemaAsset(
 spaceId:string,assetId:string,name:string,knownSha256:string
):Promise<void>{
 if(!/^[a-f0-9]{32}$/.test(spaceId)||!/^[a-f0-9]{32}$/.test(assetId))
  throw new CoreError('validation','Неверный идентификатор файла.');
 if(!/^[a-f0-9]{64}$/.test(knownSha256))
  throw new CoreError('validation','Неизвестная контрольная сумма файла.');
 if(!crypto?.subtle)throw new CoreError('secure_context','Для проверки файла нужен защищённый контекст HTTPS/localhost.');
 const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),30000);
 try{
  const r=await fetch('/api/core/cinema/spaces/'+spaceId+'/vault/'+assetId+'/download',{
   method:'GET',credentials:'omit',cache:'no-store',signal:controller.signal,
   headers:{'Authorization':'Bearer '+token,'Accept':'application/octet-stream'}
  });
  if(!r.ok)throw await vaultError(r);
  if(!r.headers.get('Content-Type')?.includes('application/octet-stream'))
   throw new CoreError('invalid_response','Ожидался закрытый бинарный файл.');
  if(r.headers.get('X-OSA-Cinema-SHA256')!==knownSha256)
   throw new CoreError('integrity','Контрольная сумма не совпадает с серверной записью.');
  const bytes=await r.arrayBuffer();
  if(bytes.byteLength>8*1024*1024)throw new CoreError('file_size','Файл превышает допустимый размер.');
  const digest=await crypto.subtle.digest('SHA-256',bytes);
  const localHash=Array.from(new Uint8Array(digest),n=>n.toString(16).padStart(2,'0')).join('');
  if(localHash!==knownSha256)throw new CoreError('integrity','Контрольная сумма загруженного файла не совпадает. Сохранение отменено.');
  const url=URL.createObjectURL(new Blob([bytes],{type:'application/octet-stream'}));
  try{const a=document.createElement('a');a.href=url;a.download=name;a.click();}
  finally{setTimeout(()=>URL.revokeObjectURL(url),1500);}
 }catch(e){
  if(e instanceof CoreError)throw e;
  throw new CoreError('connection','Не удалось получить файл из Core.');
 }finally{clearTimeout(timer);}
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
