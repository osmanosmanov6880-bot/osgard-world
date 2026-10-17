// INHERIT Core account API. No cookie transport, no mutation after an unknown POST.
const TOKEN_KEY = 'osgard:core-session:v1';
const PENDING_PREFIX = 'inherit:core:pending:v1:';
export class WorldRequestError extends Error {
  constructor(message, status=0, code='connection') {
    super(message); this.status=status; this.code=code;
  }
}
function validId(value){ return /^[a-f0-9]{32}$/.test(value||''); }
export function createWorldClient({storage,fetcher,makeKey,base='/api/core/'}={}) {
  const session=storage??globalThis.sessionStorage;
  const transport=fetcher??globalThis.fetch.bind(globalThis);
  const keyFactory=makeKey??(()=>globalThis.crypto.randomUUID().replaceAll('-',''));
  let user=null;
  const token=()=>{try {return session.getItem(TOKEN_KEY)||''}catch{return ''}};
  function journalKey(){if(!user)throw new WorldRequestError('Сначала войдите в Core.',401,'unauthorized');return PENDING_PREFIX+user.id}
  function pending(){
    let raw;
    try{raw=session.getItem(journalKey())}catch{throw new WorldRequestError('Хранилище сеанса недоступно. Новые действия остановлены.',0,'storage')}
    if(!raw)return null;
    try{
      const entry=JSON.parse(raw);
      if(entry.owner!==user.id||!entry.route?.startsWith('inherit/')||!entry.payload||!(/^[a-zA-Z0-9_-]{16,100}$/.test(entry.key)))throw Error('invalid');
      return entry;
    }catch{throw new WorldRequestError('Запись восстановления повреждена. Сохраните её до очистки.',0,'recovery')}
  }
  function storePending(entry){
    try{
      session.setItem(journalKey(),JSON.stringify(entry));
      if(session.getItem(journalKey())!==JSON.stringify(entry))throw Error('not saved');
    }catch{throw new WorldRequestError('Нельзя надёжно сохранить запрос. Отправка отменена.',0,'storage')}
  }
  function clearPending(){
    try{session.removeItem(journalKey());return !session.getItem(journalKey())}catch{return false}
  }
  async function request(route,{method='GET',payload=null,key=null,limitMs=20000}={}){
    if(!/^([a-z0-9_-]+\/)*[a-z0-9_-]+$/.test(route)||!(route==='auth/me'||route.startsWith('inherit/')))
      throw new WorldRequestError('Недопустимый маршрут.',400,'route');
    const bearer=token();
    if(!bearer)throw new WorldRequestError('Войдите в аккаунт Core.',401,'unauthorized');
    const abort=new AbortController(),timer=setTimeout(()=>abort.abort(),limitMs);
    try{
      const reply=await transport(base+route,{
        method,headers:{Accept:'application/json',Authorization:'Bearer '+bearer,...(payload?{'Content-Type':'application/json'}:{}),...(key?{'Idempotency-Key':key}:{})},
        body:payload?JSON.stringify(payload):undefined,credentials:'omit',cache:'no-store',redirect:'error',signal:abort.signal
      });
      if(!reply.headers.get('content-type')?.includes('application/json'))throw new WorldRequestError('Сервер не вернул JSON.',reply.status,'invalid_response');
      const body=await reply.json();
      if(!reply.ok)throw new WorldRequestError(body?.message||'Запрос отклонён.',reply.status,body?.error||'server');
      return body;
    }catch(error){
      if(error instanceof WorldRequestError)throw error;
      throw new WorldRequestError('Связь прервалась. Не повторяйте действие с новым ключом.',0,'connection');
    }finally{clearTimeout(timer)}
  }
  async function verify(){
    const identity=(await request('auth/me')).user;
    if(!identity||!validId(identity.id))throw new WorldRequestError('Некорректный ответ об аккаунте.',0,'invalid_response');
    user={id:identity.id,username:identity.username};
    return {...user};
  }
  function getUser(){return user?{...user}:null}
  async function mutate(route,payload){
    if(pending())throw new WorldRequestError('Сначала восстановите незавершённый запрос.',409,'pending');
    const key=keyFactory();
    if(!/^[a-zA-Z0-9_-]{16,100}$/.test(key))throw new WorldRequestError('Неверный ключ операции.',0,'key');
    const entry={owner:user.id,route,payload,key};
    storePending(entry);
    const result=await request(route,{method:'POST',payload,key});
    clearPending();
    return result;
  }
  // Only explicit user action may replay the same POST. A lost response never
  // triggers automatic retries or submits a different idempotency key.
  async function recover(){
    const entry=pending();
    if(!entry)throw new WorldRequestError('Нет запроса для восстановления.',404,'not_found');
    const result=await request(entry.route,{method:'POST',payload:entry.payload,key:entry.key});
    clearPending();
    return result;
  }
  async function read(route){return request(route)}
  return {verify,getUser,read,mutate,recover,pending,clearPending};
}
