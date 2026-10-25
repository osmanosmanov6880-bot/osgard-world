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
import { parseArgs as parseAuditArgs } from './osa-cinema-v38-owner-release-dossier.mjs'
import { EXTERNAL_GATES } from './osa-cinema-v27-release-board.mjs'
import { runIsolatedPrivateAudit } from './osa-cinema-v40-isolated-audit.mjs'
import { renderOwnerLogin, renderOwnerDesk } from './osa-cinema-v41-owner-ui.mjs'

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
function loginHtml(nonce, token) { return renderOwnerLogin(nonce, token) }
function dashboardHtml(nonce, token) { return renderOwnerDesk(nonce, token) }

/** Starts only on 127.0.0.1. The injected audit function is intended exclusively for hermetic tests. */
export async function startPrivateOwnerDesk({password, auditOptions = {}, audit = runIsolatedPrivateAudit,
  port=0, auditTimeoutMs=20*60*1000} = {}) {
  insist(safeString(password), 'owner password must be 16-256 characters')
  insist(Number.isInteger(port) && port >= 0 && port <= 65535, 'invalid private port')
  insist(Number.isSafeInteger(auditTimeoutMs) && auditTimeoutMs>0 && auditTimeoutMs<=60*60*1000,
    'invalid audit timeout')
  const salt=randomBytes(32),passHash=scryptSync(password,salt,32)
  const sessionMap=new Map(),challengeMap=new Map()
  let deskState={state:'idle',summary:null,runId:null}
  let activeController=null,activeTimeout=null
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
          activeController?.abort()
          activeController=null
          if(activeTimeout)clearTimeout(activeTimeout)
          activeTimeout=null
          deskState={state:'idle',summary:null,runId:null}
          sessionMap.delete(cookieValue(req,cookieName))
          res.setHeader('Set-Cookie',`${cookieName}=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0`)
          return response(res,200,{status:'session_closed'})
        }
        if(deskState.state==='running')return deny(res,409)
        const runId=randomHex()
        deskState={state:'running',summary:null,runId}
        // V40: each real V38 verification runs in a killable child with no password.
        // Existing injected audits remain available ONLY for hermetic unit tests.
        const controller=new AbortController()
        activeController=controller
        activeTimeout=setTimeout(()=>{
          if(!closed&&deskState.runId===runId&&deskState.state==='running') {
            deskState={state:'failed',summary:null,runId}
            controller.abort() // Stops real V40 worker, not just the UI state.
          }
        },auditTimeoutMs)
        activeTimeout.unref()
        Promise.resolve().then(()=>audit({...auditOptions},{signal:controller.signal}))
          .then(raw=>verifyV38Summary(raw))
          .then(summary=>{if(!closed&&deskState.runId===runId&&deskState.state==='running')deskState={state:'completed',summary,runId}})
          .catch(()=>{if(!closed&&deskState.runId===runId&&deskState.state==='running')deskState={state:'failed',summary:null,runId}})
          .finally(()=>{if(activeController===controller){activeController=null;clearTimeout(activeTimeout);activeTimeout=null}})
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
    closed=true;activeController?.abort();activeController=null
    if(activeTimeout)clearTimeout(activeTimeout)
    activeTimeout=null;deskState={state:'idle',summary:null,runId:null}
    sessionMap.clear();challengeMap.clear()
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
