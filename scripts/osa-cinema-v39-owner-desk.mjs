/**
 * OSA CINEMA V39: password-protected, loopback-only, read-only audit desk.
 * The ONLY audit invoked in production is V38. Never sends MP4, VTT, PDFs, paths,
 * signer registry, passwords, keys or the V38 raw error text to the browser.
 * No production/public-release or payment path exists.
 */
import { createServer } from 'node:http'
import { createHash, randomBytes, scryptSync, timingSafeEqual } from 'node:crypto'
import { fileURLToPath } from 'node:url'
import { resolve } from 'node:path'
import { auditPrivateOwnerDossier, parseArgs as parseAuditArgs } from './osa-cinema-v38-owner-release-dossier.mjs'
import { EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'

const releaseLocked = Object.freeze({
  releaseDecision: 'NO_GO', publicationAuthorized: false, rightsCleared: false,
  paidCheckoutEnabled: false, publicCatalogueWriteAllowed: false,
  productionDeploymentPerformed: false,
})
const cookieName = 'osa_v39_session'
const challengeName = 'osa_v39_challenge'
const ttl = 45 * 60 * 1000
const csrfTtl = 5 * 60 * 1000
const randomHex = () => randomBytes(32).toString('hex')
const sha256 = input => createHash('sha256').update(input).digest('hex')
const insist = (condition, error) => { if (!condition) throw Error('OSA_V39_DESK_HOLD: ' + error) }
const safeString = value => typeof value === 'string' && value.length >= 16 && value.length <= 256

export function verifyV38Summary(report) {
  insist(report?.schemaVersion === 1 && report.project === 'OSA CINEMA' &&
    report.stage === 'V38_OWNER_OFFLINE_RELEASE_DOSSIER' &&
    report.status === 'TECHNICAL_EVIDENCE_VERIFIED_FOR_PRIVATE_REVIEW' &&
    Object.entries(releaseLocked).every(([key, expected]) => report[key] === expected) &&
    report.actualFinalFilmEditoriallyAccepted === false &&
    report.legalRightsIndependentReviewComplete === false &&
    report.publicHttpsAndDeviceQaComplete === false &&
    report.publisherLegalAuthorityEstablishedBySoftware === false,
    'V38 must remain private-only and explicitly unlicensed')
  const e = report.evidence
  insist(e?.genuineHistoricalDocuments === 3 && [4,6].includes(e.checkedPrivateReceiptReports) &&
    e.checkedLocalMP4 === 4 && e.checkedLocalWebVTT === 4 &&
    ((e.signedClaimCount === 0 && e.signedClaimsStatus === 'NOT_PROVIDED') ||
      (e.signedClaimCount === 8 && e.checkedPrivateReceiptReports === 6 &&
        e.signedClaimsStatus === 'CRYPTOGRAPHICALLY_VERIFIED_PRIVATE_ONLY')),
    'V38 evidence counters mismatch')
  const gates = report.independentLegalHumanAndProductionGatesStillRequired
  insist(Array.isArray(gates) && gates.length === EXTERNAL_GATES.length &&
    new Set(gates).size === EXTERNAL_GATES.length &&
    EXTERNAL_GATES.every(g => gates.includes(g)), 'external human approvals not all blocked')
  // Intentionally project a strict allowlist instead of returning a raw V38 report.
  const value = {
    schemaVersion: 1, project: 'OSA CINEMA', stage: 'V39_PRIVATE_OWNER_DESK_RESULT',
    audit: 'TECHNICALLY_VERIFIED_PRIVATE_ONLY',
    codeHistory: e.genuineHistoricalDocuments,
    privateReceipts: e.checkedPrivateReceiptReports,
    mp4Files: e.checkedLocalMP4, captions: e.checkedLocalWebVTT,
    cryptographicClaims: e.signedClaimCount,
    cryptographicClaimsStatus: e.signedClaimsStatus,
    outstandingIndependentGates: [...EXTERNAL_GATES],
    legalClearanceConfirmedBySoftware: false,
    editorialApprovalConfirmedBySoftware: false,
    productionDeploymentConfirmedBySoftware: false,
    ...releaseLocked,
    note: 'Private technical verification does not prove legal rights, artistic sign-off, publisher authority or production acceptance.',
  }
  return Object.freeze(value)
}

function securityHeaders(res, nonce) {
  res.setHeader('Cache-Control','no-store, max-age=0')
  res.setHeader('Pragma','no-cache')
  res.setHeader('X-Content-Type-Options','nosniff')
  res.setHeader('X-Frame-Options','DENY')
  res.setHeader('Cross-Origin-Resource-Policy','same-origin')
  res.setHeader('Cross-Origin-Opener-Policy','same-origin')
  res.setHeader('Referrer-Policy','no-referrer')
  res.setHeader('Permissions-Policy','camera=(), microphone=(), geolocation=(), payment=()')
  res.setHeader('Content-Security-Policy',
    `default-src 'none'; script-src 'nonce-${nonce}'; style-src 'nonce-${nonce}'; connect-src 'self'; ` +
    `form-action 'self'; base-uri 'none'; frame-ancestors 'none'; img-src 'none'; media-src 'none'; object-src 'none'`)
}
function response(res, status, data, type='application/json; charset=utf-8') {
  res.writeHead(status, {'Content-Type':type})
  res.end(type.startsWith('application/json') ? JSON.stringify(data) : data)
}
const deny = (res, status=403) => response(res,status,{error:status===401?'authentication_required':status===429?'try_again_later':'request_denied'})
function cookieValue(req,name) {
  const raw = req.headers.cookie || ''
  if (raw.length > 1024) return null
  const matches = raw.split(';').map(x=>x.trim()).filter(x=>x.startsWith(name+'='))
  if (matches.length !== 1) return null
  const value = matches[0].slice(name.length+1)
  return /^[a-f0-9]{64}$/.test(value) ? value : null
}
function postIsSameOrigin(req,url) {
  const origin = req.headers.origin
  const site = req.headers['sec-fetch-site']
  return (origin === url || (origin === 'null' && site === 'same-origin')) &&
    (!site || site === 'same-origin' || site === 'none')
}
async function bodyText(req) {
  const type = (req.headers['content-type']||'').split(';')[0].trim().toLowerCase()
  insist(type === 'application/x-www-form-urlencoded', 'unexpected request format')
  let size=0;const chunks=[]
  for await (const part of req) {
    size+=part.byteLength
    insist(size<=1024, 'request size exceeded')
    chunks.push(part)
  }
  return Buffer.concat(chunks).toString('utf8')
}
const display = `:root{color-scheme:dark;font-family:Inter,ui-sans-serif,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#0b0f14;color:#f5f1e9}*{box-sizing:border-box}body{margin:0;min-height:100vh;background:radial-gradient(ellipse 70% 75% at 80% 0%,#252734 0%,#10141d 60%,#0b0f14 100%)}main{max-width:1140px;margin:auto;padding:clamp(20px,4.5vw,64px)}.eyebrow{font-size:11px;font-weight:800;letter-spacing:.22em;color:#e5b885}h1,h2{font-family:Georgia,'Times New Roman',serif;font-weight:400;letter-spacing:-.045em}h1{font-size:clamp(42px,6vw,76px);line-height:1.04;margin:18px 0 26px}h2{font-size:clamp(24px,3vw,36px);margin:8px 0 14px}p{line-height:1.65}.lead{color:#c8c6c3;max-width:720px}.brand{font-size:15px;letter-spacing:.33em;font-weight:900;color:#e6b98b}.top{display:flex;justify-content:space-between;align-items:center;gap:20px;padding-bottom:22px;border-bottom:1px solid #5d5144}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:28px 0}.metric{background:#151a21;border:1px solid #51483d;padding:22px}.num{font:clamp(29px,3.5vw,44px) Georgia,serif;color:#f4d4a8}.desc{color:#bbb7b0;font-size:12px}.sheet{background:rgba(25,29,37,.96);border:1px solid #51483d;padding:clamp(22px,4vw,39px);margin-top:20px}.hero{margin-top:50px}.split{display:flex;justify-content:space-between;align-items:center;gap:20px;flex-wrap:wrap}.tag{display:inline-flex;border:1px solid #a57659;border-radius:99px;color:#eabf9f;padding:7px 14px;font-size:12px;font-weight:900;letter-spacing:.08em}.tag.good{border-color:#6b9884;color:#aad6bb}button{font:inherit;cursor:pointer;padding:13px 21px;background:transparent;color:#e8cbab;border:1px solid #937959}button.primary{background:#e1b989;color:#191713;font-weight:750}button:disabled{opacity:.5;cursor:not-allowed}button:hover:enabled{filter:brightness(1.16)}:focus-visible{outline:3px solid #f4d29d;outline-offset:3px}.warning{background:#352319;border-left:4px solid #e4a272;padding:16px 20px;color:#f7d1ba;margin:24px 0}.muted{color:#bdb7af}.notes{color:#bebbb5;margin:17px 0;padding-left:22px}.notes li{margin:10px 0}.small{font-size:12px;color:#b0ada8}.login{max-width:520px;margin:9vh auto}.formrow{margin-top:25px}label{display:block;margin-bottom:9px}input{background:#111722;border:1px solid #7b6b57;color:white;padding:13px 15px;width:100%;min-height:50px;font:inherit}.formrow button{margin-top:20px;width:100%}.actions{display:flex;gap:12px;flex-wrap:wrap}button[hidden],a[hidden]{display:none}.textlink{display:inline-flex;align-items:center;color:#e6c396;text-underline-offset:4px;padding:10px}a:focus-visible{outline-offset:5px}@media(max-width:820px){.grid{grid-template-columns:repeat(2,1fr)}}@media(max-width:480px){.grid{grid-template-columns:1fr}.top{align-items:flex-start}.actions>*{width:100%}.sheet{padding:20px}}`
function loginHtml(nonce,token) {return `<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OSA CINEMA · private owner sign in</title><style nonce="${nonce}">${display}</style><main class="login"><div class="brand">OSA CINEMA</div><section class="sheet"><p class="eyebrow">PRIVATE STUDIO / 39</p><h1>Только для владельца.</h1><p class="lead">Фильмы, соглашения и закрытые отчёты остаются на вашем компьютере. Коммерческая премьера не разрешена.</p><form action="/login" method="POST"><input type="hidden" name="csrf" value="${token}"><div class="formrow"><label for="password">Пароль локального кабинета</label><input id="password" type="password" name="password" autocomplete="current-password" minlength="16" maxlength="256" required><button class="primary" type="submit">Войти в закрытую студию</button></div></form></section><p class="small">Адрес доступен только с 127.0.0.1. Пароль и пути к материалам не публикуются.</p></main></html>`}
function dashboardHtml(nonce,token) {return `<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OSA CINEMA · private release desk</title><style nonce="${nonce}">${display}</style><main><header class="top"><span class="brand">OSA CINEMA</span><span class="tag">OFFLINE · NO-GO</span></header><p class="eyebrow hero">ENGINEERING ASSURANCE / V39</p><h1>Премьера начинается<br>с доказательств.</h1><p class="lead">Проверка оригинальных источников, отчётов, восьми локальных медиафайлов и независимых подписей. Никакие материалы не передаются за пределы компьютера.</p><section class="warning" role="status"><strong>ПУБЛИЧНЫЙ ПОКАЗ И ОПЛАТА ЗАПРЕЩЕНЫ</strong><div>Даже безошибочная проверка файлов не заменяет права, прослушивание RU/EN и решение издателя.</div></section><div class="grid"><article class="metric"><div class="num" id="historic">—</div><p class="desc">Исторические источники</p></article><article class="metric"><div class="num" id="receipts">—</div><p class="desc">Отчёты приёмки</p></article><article class="metric"><div class="num" id="media">—</div><p class="desc">MP4 и WebVTT</p></article><article class="metric"><div class="num" id="signatures">—</div><p class="desc">Проверенные подписи</p></article></div><section class="sheet"><div class="split"><div><p class="eyebrow">01 / LOCAL AUDIT</p><h2>Единая проверка V35–V38</h2></div><span class="tag" id="result-tag">НЕ ЗАПУЩЕНО</span></div><p class="lead" id="status-text" aria-live="polite">Владелец может провести техническую проверку на этом устройстве.</p><div class="actions"><button id="run" type="button" class="primary">Проверить файлы и отчёты</button><a id="report" href="/api/report" class="textlink" hidden download="OSA_CINEMA_V39_PRIVATE_NO_GO.json">Скачать закрытый отчёт (NO-GO)</a><button id="logout" type="button">Выйти</button></div><p class="small">Кнопка только читает файлы. Нет загрузки в облако, стриминга и публикации.</p></section><section class="sheet"><p class="eyebrow">02 / НЕЗАКРЫТЫЕ ВНЕШНИЕ СОГЛАСОВАНИЯ</p><h2>Что не может решить программа</h2><ol class="notes"><li>Права на музыку, изображение, голос и исходные сцены</li><li>Реальное прослушивание русской и английской дорожек</li><li>Приёмка режиссёра, звука и синхронизированных субтитров</li><li>Настоящие HTTPS и испытания на пользовательских устройствах</li><li>Правомочное письменное разрешение издателя на точные SHA-256</li></ol></section><p class="small">OSA CINEMA · Only loopback/private owner mode. No commercial release pathway exists.</p></main><script nonce="${nonce}">(()=>{'use strict';const csrf='${token}',get=id=>document.getElementById(id);async function query(path,method='GET'){const r=await fetch(path,{method,credentials:'same-origin',cache:'no-store',headers:method==='POST'?{'X-OSA-CSRF':csrf}:{}});if(!r.ok)throw Error('HTTP '+r.status);return r.json()}function view(s){const running=s.state==='running',ok=s.state==='completed',failed=s.state==='failed';get('run').disabled=running;get('result-tag').textContent=running?'ПРОВЕРКА':ok?'ПРОВЕРЕНО · NO-GO':failed?'HOLD · ПРИОСТАНОВЛЕНО':'НЕ ЗАПУЩЕНО';get('result-tag').classList.toggle('good',ok);get('status-text').textContent=running?'Проверяем закрытые материалы локально…':ok?'Байты совпали. Премьера, права и оплата всё равно не разрешены.':failed?'Обнаружено несоответствие или отсутствуют материалы. Проверьте локальные исходники.':'Владелец может провести техническую проверку на этом устройстве.';get('report').hidden=!ok;const d=s.summary;get('historic').textContent=ok?String(d.codeHistory)+'/3':'—';get('receipts').textContent=ok?String(d.privateReceipts):'—';get('media').textContent=ok?String(d.mp4Files+d.captions)+'/8':'—';get('signatures').textContent=ok?String(d.cryptographicClaims)+'/8':'—'}async function refresh(){try{view(await query('/api/status'))}catch{get('status-text').textContent='Доступ к кабинету потерян. Требуется повторный вход.'}}get('run').addEventListener('click',async()=>{try{await query('/api/run','POST');await refresh()}catch{get('status-text').textContent='Запуск отклонён. Повторите после проверки доступа.'}});get('logout').addEventListener('click',async()=>{try{await query('/api/logout','POST')}finally{location.href='/'}});refresh();setInterval(refresh,1600)})();</script></html>`}

/** Starts only on 127.0.0.1. The injected audit function is intended exclusively for hermetic tests. */
export async function startPrivateOwnerDesk({password, auditOptions = {}, audit = auditPrivateOwnerDossier,
  port=0, auditTimeoutMs=20*60*1000} = {}) {
  insist(safeString(password), 'owner password must be 16-256 characters')
  insist(Number.isInteger(port) && port >= 0 && port <= 65535, 'invalid private port')
  insist(Number.isSafeInteger(auditTimeoutMs) && auditTimeoutMs>0 && auditTimeoutMs<=60*60*1000,
    'invalid audit timeout')
  const salt=randomBytes(32),passHash=scryptSync(password,salt,32)
  const sessionMap=new Map(),challengeMap=new Map()
  let deskState={state:'idle',summary:null,runId:null}
  let failures=0,blockUntil=0,closed=false
  let server, address=''
  const getSession = req => {
    const token=cookieValue(req,cookieName),item=token&&sessionMap.get(token)
    if(!item)return null
    if(item.expires<=Date.now()){sessionMap.delete(token);return null}
    return item
  }
  const handle=async(req,res)=>{
    const nonce=randomBytes(16).toString('base64')
    securityHeaders(res,nonce)
    if(closed || !req.socket.remoteAddress?.replace('::ffff:','').startsWith('127.0.0.1') ||
      req.headers.host!==address.slice('http://'.length)) return deny(res)
    const method=req.method, path=req.url
    const session=getSession(req)
    if(method==='GET' && path==='/') {
      if(session)return response(res,200,dashboardHtml(nonce,session.csrf),'text/html; charset=utf-8')
      const challenge=randomHex(),cookie=randomHex()
      if(challengeMap.size>100)challengeMap.clear()
      challengeMap.set(cookie,{challenge,expires:Date.now()+csrfTtl})
      res.setHeader('Set-Cookie',`${challengeName}=${cookie}; HttpOnly; SameSite=Strict; Path=/; Max-Age=300`)
      return response(res,200,loginHtml(nonce,challenge),'text/html; charset=utf-8')
    }
    if(method==='POST' && path==='/login') {
      if(!postIsSameOrigin(req,address))return deny(res)
      if(Date.now()<blockUntil)return deny(res,429)
      const challengeCookie=cookieValue(req,challengeName)
      const saved=challengeCookie&&challengeMap.get(challengeCookie)
      if(challengeCookie)challengeMap.delete(challengeCookie)
      if(!saved || saved.expires<Date.now())return deny(res)
      let text=''
      try{text=await bodyText(req)}catch{return deny(res)}
      const form=new URLSearchParams(text)
      if(form.getAll('csrf').length!==1 || form.getAll('password').length!==1 ||
        form.get('csrf')!==saved.challenge)return deny(res)
      const candidate=form.get('password')
      const check=scryptSync(typeof candidate==='string' ? candidate : '',salt,32)
      if(!timingSafeEqual(passHash,check)){
        failures++
        if(failures>=5){blockUntil=Date.now()+60_000;failures=0}
        return deny(res,401)
      }
      failures=0
      const token=randomHex(),csrf=randomHex()
      if(sessionMap.size>=8)sessionMap.clear()
      sessionMap.set(token,{csrf,expires:Date.now()+ttl})
      res.setHeader('Set-Cookie',`${cookieName}=${token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=2700`)
      res.writeHead(303,{Location:'/'});res.end();return
    }
    if(path?.startsWith('/api/')){
      if(!session)return deny(res,401)
      if(method==='GET' && path==='/api/status')return response(res,200,{
        ...releaseLocked,state:deskState.state,
        summary:deskState.state==='completed'?deskState.summary:null,
      })
      if(method==='GET' && path==='/api/report'){
        if(deskState.state!=='completed')return deny(res,409)
        res.setHeader('Content-Disposition','attachment; filename="OSA_CINEMA_V39_PRIVATE_NO_GO.json"')
        return response(res,200,deskState.summary)
      }
      if(method==='POST' && ['/api/run','/api/logout'].includes(path)){
        if(!postIsSameOrigin(req,address) || req.headers['x-osa-csrf']!==session.csrf)return deny(res)
        if(path==='/api/logout'){
          sessionMap.delete(cookieValue(req,cookieName))
          res.setHeader('Set-Cookie',`${cookieName}=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0`)
          return response(res,200,{status:'session_closed'})
        }
        if(deskState.state==='running')return deny(res,409)
        const runId=randomHex()
        deskState={state:'running',summary:null,runId}
        // Never expose raw audit errors, system paths or names in browser responses.
        Promise.resolve().then(()=>audit({...auditOptions})).then(raw=>verifyV38Summary(raw))
          .then(summary=>{if(!closed&&deskState.runId===runId)deskState={state:'completed',summary,runId}})
          .catch(()=>{if(!closed&&deskState.runId===runId)deskState={state:'failed',summary:null,runId}})
        const timeout=setTimeout(()=>{if(!closed&&deskState.runId===runId&&deskState.state==='running')deskState={state:'failed',summary:null,runId}},auditTimeoutMs)
        timeout.unref()
        return response(res,202,{status:'running',...releaseLocked})
      }
      return deny(res,405)
    }
    return deny(res,404)
  }
  server=createServer((req,res)=>handle(req,res).catch(()=>{if(!res.headersSent)deny(res,500);else res.end()}))
  await new Promise((yes,no)=>{server.once('error',no);server.listen(port,'127.0.0.1',yes)})
  address='http://127.0.0.1:'+server.address().port
  return {url:address,binding:server.address().address,close:async()=>{
    closed=true;sessionMap.clear();challengeMap.clear()
    await new Promise((done,reject)=>server.close(err=>err?reject(err):done()))
  }}
}

/** Do not accept password on the command line or write it into files. */
export function parseDeskArgs(args) {
  insist(Array.isArray(args), 'invalid arguments')
  const options=[],seen=new Set()
  let port=0
  for(let i=0;i<args.length;i+=2){
    const key=args[i],value=args[i+1]
    insist(value && !seen.has(key), 'missing or duplicate argument')
    seen.add(key)
    if(key==='--port'){
      insist(/^\d{1,5}$/.test(value), 'invalid port')
      port=Number(value)
    } else options.push(key,value)
  }
  const auditOptions=parseAuditArgs(options)
  insist(port>=0&&port<=65535,'invalid port')
  return {auditOptions,port}
}
if(process.argv[1] && resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  try{
    const {auditOptions,port}=parseDeskArgs(process.argv.slice(2))
    const password=process.env.OSA_CINEMA_OWNER_PASSWORD || ''
    const service=await startPrivateOwnerDesk({auditOptions,password,port})
    console.log('OSA CINEMA V39: private owner desk at '+service.url+' (public film and payments NO-GO)')
    for(const signal of ['SIGINT','SIGTERM'])process.once(signal,()=>service.close().then(()=>process.exit(0)))
  }catch{
    console.error('OSA CINEMA V39: unable to start private desk. Check local password, paths and configuration.')
    process.exitCode=1
  }
}
