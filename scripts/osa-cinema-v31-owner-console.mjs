/**
 * OSA CINEMA V31 - a localhost-only private owner control room.
 * It does NOT serve movies, accept uploads, publish media, enable payment or grant legal release.
 * A real V29/V30 executable is invoked in a separate child process per owner action.
 */
import { createServer } from 'node:http'
import { randomBytes, createHash, timingSafeEqual } from 'node:crypto'
import { spawn } from 'node:child_process'
import { lstat, open, realpath, readdir } from 'node:fs/promises'
import { constants } from 'node:fs'
import { basename, join, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const V29 = fileURLToPath(new URL('./osa-cinema-v29-owner-preflight.mjs', import.meta.url))
const V30 = fileURLToPath(new URL('./osa-cinema-v30-external-attestations.mjs', import.meta.url))
const ORIGINALS = fileURLToPath(new URL('../docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json', import.meta.url))
const MAX_BODY = 2048
const TTL = 2 * 60 * 60 * 1000
const SHA = /^[a-f0-9]{64}$/
const ALLOWED_REPORTS = new Set([
  'V28_CANDIDATE_MANIFEST.json', 'V24_MEDIA_QA.json',
  'V26_PRIVATE_DELIVERY_QA.json', 'V25_RIGHTS_BYTES_QA.json',
  'V27_FINAL_NO_GO_BOARD.json', 'V29_OWNER_PREFLIGHT_NO_GO.json', 'CHECKSUMS.sha256',
])
const safeHash = s => createHash('sha256').update(String(s)).digest()
function equal(a, b) { return timingSafeEqual(safeHash(a), safeHash(b)) }
const nonce = () => randomBytes(24).toString('base64')
const secret = () => randomBytes(32).toString('hex')
const nowIso = () => new Date().toISOString()
function headers(res, nonceValue) {
  res.setHeader('Cache-Control','no-store, max-age=0')
  res.setHeader('Pragma','no-cache')
  res.setHeader('X-Content-Type-Options','nosniff')
  res.setHeader('X-Frame-Options','DENY')
  res.setHeader('Cross-Origin-Resource-Policy','same-origin')
  res.setHeader('Referrer-Policy','no-referrer')
  res.setHeader('Permissions-Policy','camera=(), microphone=(), geolocation=()')
  res.setHeader('Content-Security-Policy',`default-src 'none'; script-src 'nonce-${nonceValue}'; style-src 'nonce-${nonceValue}'; connect-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'; object-src 'none'; img-src 'none'; media-src 'none'`)
}
function html(res, code, content) { res.writeHead(code, {'Content-Type':'text/html; charset=utf-8'});res.end(content) }
function json(res, code, data) { res.writeHead(code, {'Content-Type':'application/json; charset=utf-8'});res.end(JSON.stringify(data)) }
function reject(res,code=403) { json(res,code,{error:code===401?'authentication_required':code===409?'action_unavailable':'request_denied'}) }
async function safeDirectory(path) {
  const st=await lstat(path)
  if (!st.isDirectory()||st.isSymbolicLink()) throw Error('Private input/output folder is not a real directory')
  return realpath(path)
}
async function safeFile(path,maxBytes=2_000_000) {
  const st=await lstat(path)
  if (!st.isFile()||st.isSymbolicLink()||st.size<1||st.size>maxBytes) throw Error('Unsafe private configuration file')
  return realpath(path)
}
async function readReport(path,max=3_000_000) {
  const st=await lstat(path)
  if (!st.isFile()||st.isSymbolicLink()||st.size<1||st.size>max) throw Error('Unsafe report file')
  const fd=await open(path,constants.O_RDONLY | (constants.O_NOFOLLOW||0))
  try {const actual=await fd.stat();if(!actual.isFile()||actual.size!==st.size)throw Error('Report changed while opened');return await fd.readFile()}
  finally{await fd.close()}
}
async function consume(req) {
  let total=0;const chunks=[]
  for await(const part of req) {total+=part.byteLength;if(total>MAX_BODY)throw Error('Request too large');chunks.push(part)}
  return Buffer.concat(chunks).toString('utf8')
}
async function pinReports(folder) {
  const control=await readReport(join(folder,'CHECKSUMS.sha256'))
  const lines=control.toString('utf8').trim().split('\n')
  if(lines.length<4||lines.length>6)throw Error('Incomplete private report checksums')
  const pins=new Map([['CHECKSUMS.sha256',createHash('sha256').update(control).digest('hex')]])
  for(const line of lines){
    const match=/^([a-f0-9]{64})  ([A-Z][A-Za-z0-9_.-]{3,85})$/.exec(line)
    if(!match||!ALLOWED_REPORTS.has(match[2])||pins.has(match[2]))throw Error('Unsafe report integrity record')
    const bytes=await readReport(join(folder,match[2]))
    if(createHash('sha256').update(bytes).digest('hex')!==match[1])throw Error('Report integrity mismatch')
    pins.set(match[2],match[1])
  }
  if(!pins.has('V29_OWNER_PREFLIGHT_NO_GO.json'))throw Error('Final NO-GO report missing')
  return pins
}
function childJob(script,args,{timeoutMs=25*60*1000}={}) {
  let child=null
  const finished=new Promise((resolveJob) => {
    child=spawn(process.execPath,[script,...args],{stdio:['ignore','pipe','pipe'],windowsHide:true,env:{...process.env,OSA_CINEMA_OWNER_CONSOLE_PASSWORD:''}})
    let settled=false,code=null,timedOut=false
    const settle=(status)=>{if(settled)return;settled=true;clearTimeout(timer);resolveJob({status,exitCode:code,timedOut})}
    const timer=setTimeout(()=>{timedOut=true;child.kill('SIGKILL');settle('failed')},timeoutMs)
    // Discard child messages to avoid accidentally serving media paths or secrets to a browser.
    child.stdout.on('data',()=>{})
    child.stderr.on('data',()=>{})
    child.once('error',()=>settle('failed'))
    child.once('close',c=>{code=c;settle(c===0?'completed':'failed')})
  })
  return {finished,abort:()=>child?.kill('SIGKILL')}
}
const safeName = name => typeof name==='string' && /^[A-Z][A-Za-z0-9_.-]{3,85}$/.test(name)
function loginPage(n,csrf) {return `<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OSA CINEMA · Закрытая редакция</title><style nonce="${n}">${STYLE}</style><main class="login"><p class="eyebrow">OSA CINEMA / ПРИВАТНЫЙ ДОСТУП</p><h1>Комната финальной приёмки</h1><p class="muted">Рабочие видео и договоры остаются на компьютере владельца. Публичный релиз не разрешён.</p><form method="POST" action="/login"><input type="hidden" name="csrf" value="${csrf}"><label for="password">Пароль владельца</label><input id="password" type="password" name="password" required autocomplete="current-password" minlength="16" placeholder="Не менее 16 символов"><button type="submit" class="primary">Войти в закрытую студию</button></form><p class="note">Адрес работает только на 127.0.0.1. Пароль не выводится в логи и не попадает в URL.</p></main></html>`}
const STYLE = `:root{color-scheme:dark;font:15px/1.55 system-ui,-apple-system,sans-serif;background:#0e1013;color:#efe9df}*{box-sizing:border-box}body{margin:0;background:radial-gradient(ellipse at 70% 0%,#23232c 0%,#0e1013 47%);min-height:100vh}main{max-width:1200px;margin:auto;padding:clamp(18px,4vw,46px)}main.login{max-width:520px;padding:44px;border:1px solid #5c5040;margin:10vh auto;background:#19191f}h1,h2{font-family:Georgia,'Times New Roman',serif;font-weight:400;letter-spacing:-.035em}h1{font-size:clamp(36px,5.5vw,68px);line-height:1.06;margin:13px 0 22px}h2{font-size:clamp(24px,3vw,37px);margin:4px 0 14px}.hero-label{margin-top:36px}.final-panel{margin-top:20px}.eyebrow,.caps{font-size:11px;font-weight:700;letter-spacing:.22em;color:#dcb783}.muted,.note{color:#b6b5b4}.note{font-size:12px;margin:17px 0}a{color:#e8c790;text-underline-offset:4px}label{display:block;margin:25px 0 7px}input{display:block;width:100%;min-height:48px;background:#12131a;color:#fff;border:1px solid #74644d;padding:12px 14px;font:inherit}button{background:#25272d;color:#f5e9d7;border:1px solid #8d7758;font:inherit;min-height:45px;padding:12px 18px;cursor:pointer}button.primary{background:#dfba83;color:#171615;border-color:#dfba83;font-weight:700}button:hover:enabled{filter:brightness(1.14)}button:disabled{opacity:.43;cursor:not-allowed}:focus-visible{outline:3px solid #e4c690;outline-offset:3px}header{display:flex;gap:20px;align-items:center;justify-content:space-between;padding:0 0 22px;border-bottom:1px solid #534a3d}.brand{font-size:15px;letter-spacing:.27em;color:#e6bf87;font-weight:800}.layout{display:grid;grid-template-columns:1.35fr 1fr;gap:20px;margin:28px 0}.panel{background:rgba(27,28,33,.95);border:1px solid #4e4a43;padding:clamp(20px,3vw,30px);min-width:0}.pill{padding:5px 12px;border:1px solid #926c49;border-radius:40px;color:#f2c998;white-space:nowrap;font-size:12px;font-weight:700}.pill.ok{border-color:#6c9d87;color:#a9e6c2}.pill.hold{border-color:#b47b4f;color:#eac398}.split{display:flex;flex-wrap:wrap;align-items:center;gap:10px;justify-content:space-between}.metric{font:38px Georgia,serif;color:#eecb98}.grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}.stat{background:#121418;border:1px solid #403c37;padding:17px}.stat p{margin:0;font-size:12px;color:#aeb0b4}.callout{border-left:3px solid #d4a46d;padding:13px 18px;background:#282117;color:#eccd9e;margin:22px 0}.progress{height:7px;background:#393633;overflow:hidden;margin:16px 0}.progress span{display:block;width:0;height:100%;background:#d5a969;transition:width .4s}.progress span.running{animation:scanning 1.3s linear infinite}@keyframes scanning{from{transform:translateX(-100%)}to{transform:translateX(380%)}}.checks{margin:0;padding-left:22px}.checks li{margin:10px 0}.row{display:flex;flex-wrap:wrap;gap:10px}.files{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.files a{display:block;padding:12px;background:#13151a;border:1px solid #474138;overflow-wrap:anywhere}.fine{font-size:12px;color:#aaa6a0;margin-top:20px}.alert{color:#ffb49b}.statusline{min-height:23px;color:#d6c2a9}section{scroll-margin-top:20px}@media(max-width:810px){.layout{grid-template-columns:1fr}.grid3{grid-template-columns:1fr 1fr}}@media(max-width:500px){header{align-items:flex-start}main.login{margin:20px;padding:25px}.files{grid-template-columns:1fr}.grid3{grid-template-columns:1fr}.row button{width:100%}}`
function dashboardPage(n,csrf) {return `<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OSA CINEMA · Owner Release Desk</title><style nonce="${n}">${STYLE}</style><main><header><div><div class="brand">OSA CINEMA</div><div class="caps">OWNER RELEASE DESK / LOCAL V31</div></div><button type="button" id="logout">Закрыть сеанс</button></header><p class="eyebrow hero-label">Технический контроль · RU / EN</p><h1>Премьера начинается с доказательств.</h1><p class="muted">Четыре фильма, четыре файла субтитров, отдельные документы и восемь подписей. Все исходники остаются на этом устройстве.</p><div class="callout"><strong>ПУБЛИКАЦИЯ ЗАПРЕЩЕНА · NO-GO</strong><div>Даже если технические тесты и подписи проходят, реальные права и production-приёмку утверждают люди.</div></div><div class="grid3"><div class="stat"><div class="metric" id="master-count">—</div><p>MP4 + субтитры</p></div><div class="stat"><div class="metric" id="http-count">—</div><p>Приватная выдача</p></div><div class="stat"><div class="metric" id="signature-count">—</div><p>Подписи Ed25519</p></div></div><div class="layout"><section class="panel"><div class="split"><p class="caps">01 / Автоматическая проверка</p><span class="pill" id="preflight-pill">Не начата</span></div><h2>Проверить мастер-файлы</h2><p class="muted">V28 → V24 → защищённый сервер V21 → полный HTTP/SHA-256 V26 → при наличии документов V25/V27.</p><div class="progress"><span id="progress"></span></div><p id="preflight-message" class="statusline" role="status">Начните с готовой папки: ровно четыре MP4 и четыре WebVTT.</p><div class="row"><button class="primary" id="run-preflight">Запустить полную проверку</button><a id="primary-report" hidden href="/api/report/V29_OWNER_PREFLIGHT_NO_GO.json" download>Скачать итоговый NO-GO</a></div></section><section class="panel"><div class="split"><p class="caps">02 / Независимые согласования</p><span class="pill hold" id="sign-pill">Требуются</span></div><h2>Проверить подписи</h2><p class="muted">V30 подтверждает криптографические подписи на точные SHA-256. Само наличие подписи не подтверждает законность лицензии или готовность сайта.</p><p class="statusline" id="sign-message" role="status">Доступно после завершения технической проверки и настройки доверенного реестра.</p><div class="row"><button id="run-signatures">Проверить Ed25519</button><a id="signature-report" href="/api/signature-report" hidden download>Скачать протокол подписей</a></div></section></div><section class="panel"><div class="split"><div><p class="caps">03 / Доказательный пакет</p><h2>Файлы отчёта</h2></div><span class="pill hold">Private only</span></div><div id="report-files" class="files"><p class="muted">Ссылки появятся после проверки.</p></div><p class="fine">Документы о правах и сам фильм не загружаются в браузер. Отчёты доступны только после входа и сохраняются в закрытой папке на компьютере.</p></section><section class="panel final-panel"><p class="caps">04 / Контроль внешних разрешений</p><h2>Последние обязательные решения</h2><ol class="checks"><li>Коммерческие права на все изображения, голоса и музыку</li><li>Реальное подтверждение RU/EN речи</li><li>Подписи режиссёра и звукорежиссёра</li><li>Проверка финальных RU/EN-субтитров</li><li>Настоящее HTTPS-хранилище и доступ</li><li>Независимая проверка реальных ПК и телефонов</li><li>Разрешение издателя на точные версии файлов</li><li>Испытанный откат и мониторинг production</li></ol><p class="fine">Этот интерфейс не содержит кнопки публикации или активации оплаты.</p></section></main><script nonce="${n}">(()=>{'use strict';const csrf='${csrf}',q=id=>document.getElementById(id);let busy=false;const request=async(path,method='GET')=>{const r=await fetch(path,{method,credentials:'same-origin',cache:'no-store',headers:method==='POST'?{'X-OSA-CSRF':csrf}:{}});if(!r.ok)throw Error('HTTP '+r.status);return method==='GET'?r.json():r.json()};const text=(id,v)=>{q(id).textContent=v};const reportNames=['V28_CANDIDATE_MANIFEST.json','V24_MEDIA_QA.json','V26_PRIVATE_DELIVERY_QA.json','V25_RIGHTS_BYTES_QA.json','V27_FINAL_NO_GO_BOARD.json','V29_OWNER_PREFLIGHT_NO_GO.json','CHECKSUMS.sha256'];function present(s){const p=s.preflight,g=s.signatures;text('preflight-pill',p.status==='running'?'Проверяется':p.status==='completed'?'Готово':p.status==='failed'?'Ошибка':'Не начата');text('preflight-message',p.status==='running'?'Идёт глубокая проверка видео и байтовой доставки…':p.status==='completed'?'Технический отчёт готов. Права и премьера не утверждены.':p.status==='failed'?'Проверка остановлена. Проверьте исходные файлы и повторите.':'Проверяется только материал, находящийся на вашем компьютере.');text('master-count',p.status==='completed'?String(p.mastersPassed||0)+'/4':'—');text('http-count',p.status==='completed'?String(p.privateHttpPassed||0)+'/4':'—');text('signature-count',g.status==='completed'||g.status==='hold'?String(g.verified||0)+'/8':'—');q('run-preflight').disabled=p.status==='running'||g.status==='running';q('run-signatures').disabled=!s.signatureConfigured||p.status!=='completed'||g.status==='running';q('primary-report').hidden=p.status!=='completed';q('signature-report').hidden=!(g.status==='completed'||g.status==='hold');text('sign-pill',g.status==='completed'?'Проверены':g.status==='running'?'Проверяются':g.status==='hold'?'Неполные':'Требуются');text('sign-message',!s.signatureConfigured?'Не настроен независимый реестр подписантов на компьютере.':g.status==='completed'?'Криптографические подписи проверены; решение о выпуске всё равно NO-GO.':g.status==='hold'?'Не все подписи подтверждены. Доступен закрытый отчёт.':g.status==='running'?'Проверяются восемь независимых подписей…':g.status==='failed'?'Проверка подписей не завершена.':'Доступно после технической приёмки.');q('progress').classList.toggle('running',p.status==='running');q('progress').style.width=p.status==='completed'?'100%':p.status==='running'?'27%':'0%';const slot=q('report-files');slot.replaceChildren();if(p.status==='completed')for(const name of reportNames){if(!p.files.includes(name))continue;const a=document.createElement('a');a.href='/api/report/'+name;a.download=name;a.textContent=name;slot.append(a)}if(!slot.childElementCount){const el=document.createElement('p');el.className='muted';el.textContent='Пока нет отчётов';slot.append(el)}}async function refresh(){try{const s=await request('/api/status');present(s)}catch(e){text('preflight-message','Сеанс недоступен. Войдите заново.') }}async function act(path){if(busy)return;busy=true;try{await request(path,'POST');await refresh()}catch(e){text(path.includes('signatures')?'sign-message':'preflight-message','Операция отклонена: '+e.message)}finally{busy=false}}q('run-preflight').addEventListener('click',()=>act('/api/run-preflight'));q('run-signatures').addEventListener('click',()=>act('/api/check-signatures'));q('logout').addEventListener('click',async()=>{try{await request('/api/logout','POST')}finally{location.href='/'}});refresh();setInterval(refresh,2200)})();</script></html>`}

export async function startPrivateOwnerConsole({root,reportsRoot,originals=ORIGINALS,password,port=0,rightsUsage=null,pinnedPlan=null,signoff=null}) {
  if (typeof password!=='string'||password.length<16||password.length>256) throw Error('A 16-256 character password must come from OSA_CINEMA_OWNER_CONSOLE_PASSWORD')
  if (!Number.isSafeInteger(port)||port<0||port>65535) throw Error('Invalid loopback port')
  if (!root||!reportsRoot) throw Error('Set the private media folder and separate reports root')
  const media=await safeDirectory(resolve(root)), reports=await safeDirectory(resolve(reportsRoot))
  if(media===reports||reports.startsWith(media+sep)||media.startsWith(reports+sep)) throw Error('Reports must be in a separate owner-only folder')
  const original=await safeFile(resolve(originals))
  const rights=rightsUsage?await safeFile(resolve(rightsUsage)):null
  const pinned=pinnedPlan?await safeFile(resolve(pinnedPlan)):null
  if(signoff&&(!rights||!pinned))throw Error('Signature review requires pinned media and the source rights ledger')
  if(signoff){
    if(!SHA.test(signoff.registrySha256||''))throw Error('Pinned independent signer registry SHA-256 required')
    signoff={...signoff,registry:await safeFile(resolve(signoff.registry)),attestations:await safeFile(resolve(signoff.attestations)),evidenceDir:await safeDirectory(resolve(signoff.evidenceDir))}
  }
  const sessions=new Map(),logins=new Map(),failures=new Map()
  const state={preflight:{status:'idle',startedAt:null,finishedAt:null,mastersPassed:0,privateHttpPassed:0,files:[],runDir:null,pins:null},signatures:{status:'idle',verified:0,report:null,pin:null}}
  let currentChild=null,closed=false
  const publicState=()=>({signatureConfigured:Boolean(signoff),publicationAuthorized:false,paidCheckoutEnabled:false,releaseDecision:'NO_GO',preflight:{status:state.preflight.status,startedAt:state.preflight.startedAt,finishedAt:state.preflight.finishedAt,mastersPassed:state.preflight.mastersPassed,privateHttpPassed:state.preflight.privateHttpPassed,files:state.preflight.files},signatures:{status:state.signatures.status,verified:state.signatures.verified}})
  const sameOrigin=(req,server)=>!req.headers.origin||req.headers.origin===`http://127.0.0.1:${server.address().port}`
  const server=createServer(async(req,res)=>{
    const n=nonce();headers(res,n)
    try{
      if(req.headers.host!==`127.0.0.1:${server.address().port}`){reject(res);return}
      if(!['GET','POST'].includes(req.method)){reject(res,405);return}
      const url=new URL(req.url||'/','http://127.0.0.1')
      if(url.search||url.hash||url.pathname.includes('%')){reject(res,404);return}
      const cookie=/^(?:.*?;\s*)?osa_owner_session=([a-f0-9]{64})(?:;|$)/.exec(req.headers.cookie||'')?.[1]
      const session=cookie?sessions.get(cookie):null
      const authed=Boolean(session&&session.expires>Date.now())
      if(req.method==='GET'&&url.pathname==='/'){
        if(authed){html(res,200,dashboardPage(n,session.csrf));return}
        const key=secret();if(logins.size>=256)logins.delete(logins.keys().next().value)
        logins.set(key,Date.now()+10*60*1000)
        html(res,200,loginPage(n,key));return
      }
      if(req.method==='POST'&&url.pathname==='/login'){
        if(!sameOrigin(req,server)){reject(res);return}
        const data=new URLSearchParams(await consume(req))
        const challenge=data.get('csrf'),valid=typeof challenge==='string'&&logins.has(challenge)&&logins.get(challenge)>Date.now()
        logins.delete(challenge)
        if(!valid){reject(res);return}
        const attempts=failures.get('loopback')||{n:0,expiry:Date.now()+600000}
        if(attempts.expiry<Date.now()){attempts.n=0;attempts.expiry=Date.now()+600000}
        if(attempts.n>=8){reject(res,429);return}
        if(!equal(data.get('password')||'',password)){attempts.n++;failures.set('loopback',attempts);reject(res,401);return}
        failures.delete('loopback')
        const sid=secret();sessions.set(sid,{expires:Date.now()+TTL,csrf:secret()})
        res.setHeader('Set-Cookie',`osa_owner_session=${sid}; HttpOnly; SameSite=Strict; Path=/; Max-Age=7200`)
        res.writeHead(303,{Location:'/'});res.end();return
      }
      if(!authed){reject(res,401);return}
      if(req.method==='POST'){
        if(!sameOrigin(req,server)||req.headers['x-osa-csrf']!==session.csrf){reject(res);return}
        if(req.headers['transfer-encoding']||(req.headers['content-length']||'0')!=='0'){reject(res);return}
      }
      if(req.method==='POST'&&url.pathname==='/api/logout'){
        sessions.delete(cookie)
        res.setHeader('Set-Cookie','osa_owner_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0')
        json(res,200,{loggedOut:true});return
      }
      if(req.method==='GET'&&url.pathname==='/api/status'){json(res,200,publicState());return}
      if(req.method==='POST'&&url.pathname==='/api/run-preflight'){
        if(state.preflight.status==='running'||state.signatures.status==='running'){reject(res,409);return}
        const dir=join(reports,`OSA-V31-${new Date().toISOString().replace(/[^0-9]/g,'').slice(0,14)}-${randomBytes(5).toString('hex')}`)
        state.preflight={status:'running',startedAt:nowIso(),finishedAt:null,mastersPassed:0,privateHttpPassed:0,files:[],runDir:null,pins:null}
        state.signatures={status:'idle',verified:0,report:null,pin:null}
        const args=['--root',media,'--originals',original,'--out',dir]
        if(rights)args.push('--rights-usage',rights)
        if(pinned)args.push('--pinned-plan',pinned)
        const child=childJob(V29,args);currentChild=child
        child.finished.then(async output=>{
          if(closed)return
          state.preflight.finishedAt=nowIso()
          if(output.status!=='completed'){state.preflight.status='failed';return}
          try{
            const report=JSON.parse((await readReport(join(dir,'V29_OWNER_PREFLIGHT_NO_GO.json'))).toString('utf8'))
            if(report.result!=='NO_GO'||report.publicationAuthorized!==false||report.paidCheckoutEnabled!==false)throw Error('Unsafe preflight report')
            const pins=await pinReports(dir)
            const present=(await readdir(dir)).filter(y=>ALLOWED_REPORTS.has(y))
            state.preflight.pins=pins
            state.preflight.runDir=dir
            state.preflight.mastersPassed=report.technical.mastersPassed
            state.preflight.privateHttpPassed=report.technical.privateHttpPassed
            state.preflight.files=present
            state.preflight.status='completed'
          }catch{state.preflight.status='failed'}
        }).catch(()=>{state.preflight.status='failed'})
        json(res,202,{accepted:true,status:'running',publicationAuthorized:false});return
      }
      if(req.method==='POST'&&url.pathname==='/api/check-signatures'){
        if(!signoff||state.preflight.status!=='completed'||state.signatures.status==='running'){reject(res,409);return}
        const frozen=await readReport(join(state.preflight.runDir,'V29_OWNER_PREFLIGHT_NO_GO.json'))
        if(createHash('sha256').update(frozen).digest('hex')!==state.preflight.pins?.get('V29_OWNER_PREFLIGHT_NO_GO.json')){reject(res,409);return}
        const destination=join(reports,'OSA-V31-SIGNOFF-'+randomBytes(8).toString('hex')+'.json')
        const args=['--preflight',join(state.preflight.runDir,'V29_OWNER_PREFLIGHT_NO_GO.json'),'--registry',signoff.registry,'--registry-sha256',signoff.registrySha256,'--attestations',signoff.attestations,'--evidence-dir',signoff.evidenceDir,'--out',destination]
        state.signatures={status:'running',verified:0,report:null,pin:null}
        const child=childJob(V30,args,{timeoutMs:3*60*1000});currentChild=child
        child.finished.then(async output=>{
          if(closed)return
          try{
            if(![0,2].includes(output.exitCode))throw Error('Signature review failed')
            const report=JSON.parse((await readReport(destination)).toString('utf8'))
            if(report.publicFilmPublicationAuthorized!==false||report.paidCheckoutEnabled!==false||!String(report.decision).startsWith('NO_GO'))throw Error('Signoff tried to approve release')
            state.signatures={status:output.exitCode===0?'completed':'hold',verified:report.verifiedSignatures||0,report:destination,pin:createHash('sha256').update(await readReport(destination)).digest('hex')}
          }catch{state.signatures={status:'failed',verified:0,report:null,pin:null}}
        }).catch(()=>{state.signatures.status='failed'})
        json(res,202,{accepted:true,status:'running',publicationAuthorized:false});return
      }
      if(req.method==='GET'&&url.pathname==='/api/signature-report'){
        if(!state.signatures.report){reject(res,404);return}
        const data=await readReport(state.signatures.report)
        if(createHash('sha256').update(data).digest('hex')!==state.signatures.pin){reject(res,409);return}
        res.writeHead(200,{'Content-Type':'application/json; charset=utf-8','Content-Disposition':'attachment; filename="V30_PRIVATE_SIGNATURE_REVIEW.json"'});res.end(data);return
      }
      if(req.method==='GET'&&url.pathname.startsWith('/api/report/')){
        const filename=url.pathname.slice('/api/report/'.length)
        if(!safeName(filename)||!ALLOWED_REPORTS.has(filename)||state.preflight.status!=='completed'||!state.preflight.files.includes(filename)){reject(res,404);return}
        const bytes=await readReport(join(state.preflight.runDir,filename))
        if(createHash('sha256').update(bytes).digest('hex')!==state.preflight.pins?.get(filename)){reject(res,409);return}
        res.writeHead(200,{'Content-Type':filename.endsWith('.json')?'application/json; charset=utf-8':'text/plain; charset=utf-8','Content-Disposition':`attachment; filename="${filename}"`});res.end(bytes);return
      }
      reject(res,404)
    }catch{reject(res,400)}
  })
  await new Promise((done,fail)=>{server.once('error',fail);server.listen(port,'127.0.0.1',done)})
  const url=`http://127.0.0.1:${server.address().port}`
  return {url,state,close:async()=>{if(closed)return;closed=true;currentChild?.abort();await new Promise(resolve=>server.close(resolve));sessions.clear();logins.clear()}}
}

function parseArgs(args){
  const o={}
  const fields=new Set(['--root','--reports-root','--originals','--port','--rights-usage','--pinned-plan','--registry','--registry-sha256','--attestations','--evidence-dir'])
  for(let i=0;i<args.length;i++){
    const k=args[i],v=args[++i]
    if(!fields.has(k)||!v||v.startsWith('--')||Object.hasOwn(o,k))throw Error('Unexpected or repeated launch option '+k)
    o[k]=v
  }
  const signKeys=['--registry','--registry-sha256','--attestations','--evidence-dir']
  const count=signKeys.filter(k=>o[k]).length
  if(count!==0&&count!==4)throw Error('All 4 signer config options must be provided together')
  return {root:o['--root'],reportsRoot:o['--reports-root'],originals:o['--originals']||ORIGINALS,port:o['--port']?Number(o['--port']):0,rightsUsage:o['--rights-usage']||null,pinnedPlan:o['--pinned-plan']||null,signoff:count===4?{registry:o['--registry'],registrySha256:o['--registry-sha256'],attestations:o['--attestations'],evidenceDir:o['--evidence-dir']}:null}
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  startPrivateOwnerConsole({...parseArgs(process.argv.slice(2)),password:process.env.OSA_CINEMA_OWNER_CONSOLE_PASSWORD}).then(service=>{
    console.log('OSA_CINEMA_V31_OWNER_CONSOLE '+service.url+' (loopback-only; NO-GO)')
    for(const signal of ['SIGINT','SIGTERM'])process.once(signal,()=>{service.close().then(()=>process.exit(0))})
  }).catch(e=>{console.error('OSA_V31_START_FAILED '+e.message);process.exitCode=1})
}
