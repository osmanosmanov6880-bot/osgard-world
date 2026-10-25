/**
 * OSA CINEMA V21 private loopback-only screening server.
 * This is explicitly NOT a public streaming server or a rights authorization tool.
 */
import { createServer } from 'node:http'
import { readFile, open, lstat } from 'node:fs/promises'
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto'
import { constants } from 'node:fs'
import { resolve, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { verifyOriginal, validateAsset } from './osa-cinema-v20-private-hls.mjs'

const TWO_HOURS=2*60*60*1000
const secureText=s=>String(s).replace(/[&<>"']/g,x=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[x]))
const csp=nonce=>"default-src 'none'; script-src 'nonce-"+nonce+"'; style-src 'nonce-"+nonce+"'; img-src data:; media-src 'self' blob:; connect-src 'none'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'; object-src 'none'"
function common(res){
  res.setHeader('Cache-Control','no-store, max-age=0')
  res.setHeader('Pragma','no-cache')
  res.setHeader('X-Content-Type-Options','nosniff')
  res.setHeader('Referrer-Policy','no-referrer')
  res.setHeader('X-Frame-Options','DENY')
  res.setHeader('Cross-Origin-Resource-Policy','same-origin')
}
function renderLogin(nonce){return `<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OSA CINEMA · Приватная приёмка</title><style nonce="${nonce}">:root{font:16px/1.6 system-ui,sans-serif;color:#f4e6cf;background:#100e0b}*{box-sizing:border-box}main{width:min(480px,90vw);margin:11vh auto;border:1px solid #785d3e;padding:clamp(22px,5vw,50px);background:#211a13}h1{font:normal 42px/1.14 Georgia,serif;color:#f1d2a0}label{display:block;margin-top:20px}input{width:100%;padding:15px;margin:8px 0 22px;background:#100e0b;color:white;border:1px solid #ab8b60;font:inherit}button{padding:14px 22px;background:#e2b878;color:#1b130a;border:0;font-weight:700;cursor:pointer;min-height:48px}p,small{color:#cbb7a0}</style><main><small>OSA CINEMA / PRIVATE EDITORIAL ONLY</small><h1>Просмотр только для редактора</h1><p>Реальные MP4 остаются на этом компьютере. Лицензии, речь, субтитры и публикация ещё не утверждены.</p><form method="POST" action="/login"><label for="password">Пароль локальной приёмки</label><input id="password" name="password" type="password" required autocomplete="current-password"><button type="submit">Открыть приватный просмотр</button></form></main></html>`}
function renderReview(nonce,asset,cuts){
  const safe=secureText(asset.id),locale=asset.locale.toUpperCase(),points=JSON.stringify(cuts.filter(x=>Number.isFinite(x)&&x>=0&&x<=asset.durationSeconds))
  return `<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>OSA CINEMA · Private screening</title><style nonce="${nonce}">:root{font:15px/1.55 system-ui,sans-serif;background:#0d0c0b;color:#efe6d5}*{box-sizing:border-box}main{max-width:1380px;margin:auto;padding:clamp(17px,4vw,45px)}header{display:flex;gap:18px;justify-content:space-between;align-items:center;border-bottom:1px solid #594832;padding-bottom:18px}.brand{font-weight:700;letter-spacing:.25em;color:#deb983}h1{font:normal clamp(34px,5vw,64px)/1.07 Georgia,serif;max-width:800px;margin:36px 0 14px}.tag{font-size:12px;color:#f2c599;text-transform:uppercase;letter-spacing:.15em}.muted{color:#c5b6a6}video{display:block;width:100%;aspect-ratio:16/9;background:black;border:1px solid #836442;max-height:70vh}.layout{display:grid;grid-template-columns:minmax(0,1.55fr) minmax(270px,1fr);gap:20px}.panel{border:1px solid #594832;background:#191611;padding:20px;min-width:0}.timeline{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:7px;max-height:400px;overflow:auto}.timeline button,button{color:#f5e1c0;background:#2e2419;border:1px solid #766044;min-height:44px;cursor:pointer;padding:10px}.timeline button:hover,button:focus-visible{outline:2px solid #e9c18c}button.primary{background:#d2ae76;color:#18130c;font-weight:700}input{max-width:100%;padding:10px;background:#30251a;color:white}textarea{width:100%;height:130px;padding:12px;background:#12100e;color:#f6e5cb;border:1px solid #8b6d49;resize:vertical}.row{display:flex;flex-wrap:wrap;gap:10px;align-items:center}.warning{color:#f7bea0;border-left:3px solid #ca7659;padding:10px 14px;background:#2b1e17;margin:20px 0}.status{font-size:13px;color:#ead0a9}@media(max-width:900px){.layout{grid-template-columns:1fr}h1{margin-top:22px}.timeline{grid-template-columns:repeat(4,minmax(0,1fr))}}@media(max-width:430px){.timeline{grid-template-columns:repeat(3,minmax(0,1fr))}header{align-items:start}}</style><main><header><div class="brand">OSA CINEMA</div><form method="POST" action="/logout"><button>Закрыть доступ</button></form></header><div class="tag">LOCAL PRIVATE SCREENING · ${locale} CANDIDATE · НЕ ПУБЛИКОВАТЬ</div><h1>Точная проверка киноматериала</h1><p class="muted">Исходник: ${safe} · ${asset.width}×${asset.height} · ${asset.durationSeconds} c · изолированный локальный сервер 127.0.0.1</p><div class="warning">Дорожка языка не прослушана и не утверждена; коммерческие права и финальные субтитры не подтверждены. Это рабочая приёмка, не публичная премьера.</div><div class="layout"><div><video id="film" src="/media" controls playsinline preload="metadata" aria-label="Приватный видеомастер"></video><div class="panel"><div class="row"><label for="vtt">Проверить локальный WebVTT без передачи на сервер:</label><input id="vtt" type="file" accept=".vtt,text/vtt"></div><p id="status" class="status" role="status">Медиа выдаётся с HTTP Range; субтитры можно открыть только локально.</p></div></div><section class="panel"><h2>Монтажные таймкоды</h2><div id="cuts" class="timeline" aria-label="Точки переходов"></div><h2>Частные заметки</h2><label for="note">Замечание к текущему таймкоду</label><textarea id="note" placeholder="Время, голос, цвет, склейка, читаемость…"></textarea><div class="row"><button class="primary" id="save" type="button">Добавить замечание</button><button id="export" type="button">Экспорт JSON</button></div><div id="notes" class="status" aria-live="polite"></div></section></div><p class="muted">Контроль оригинала: SHA-256 ${secureText(asset.sha256.slice(0,16))}… · Никакой видеозаписи, исходника или субтитров серверу не отправляется.</p></main><script nonce="${nonce}">(()=>{const video=document.getElementById('film'),status=document.getElementById('status'),cuts=${points},notes=[];let captionUrl=null;const fmt=t=>String(Math.floor(t/60)).padStart(2,'0')+':'+String(Math.floor(t%60)).padStart(2,'0');const box=document.getElementById('cuts');for(const t of cuts){const b=document.createElement('button');b.type='button';b.textContent=fmt(t);b.title=t.toFixed(3)+'s';b.addEventListener('click',()=>{video.currentTime=t;video.focus()});box.append(b)}document.getElementById('vtt').addEventListener('change',e=>{const f=e.target.files&&e.target.files[0];if(!f)return;if(f.size>2000000||!f.name.toLowerCase().endsWith('.vtt')){status.textContent='Неверный файл WebVTT';return}if(captionUrl)URL.revokeObjectURL(captionUrl);for(const t of video.querySelectorAll('track'))t.remove();captionUrl=URL.createObjectURL(f);const t=document.createElement('track');t.kind='subtitles';t.label='Private draft';t.srclang='${asset.locale}';t.src=captionUrl;t.default=true;video.append(t);status.textContent='Загружен приватный черновик WebVTT: нужна ручная проверка соответствия речи.'});document.getElementById('save').addEventListener('click',()=>{const txt=document.getElementById('note').value.trim();if(!txt)return;notes.push({timeSeconds:Number(video.currentTime.toFixed(3)),text:txt});document.getElementById('note').value='';document.getElementById('notes').textContent='Частных заметок: '+notes.length});document.getElementById('export').addEventListener('click',()=>{const body={type:'OSA_CINEMA_PRIVATE_REVIEW',sourceId:'${safe}',timestamp:new Date().toISOString(),notes,languageApproved:false,rightsCleared:false,publicationAuthorized:false};const url=URL.createObjectURL(new Blob([JSON.stringify(body,null,2)],{type:'application/json'}));const link=document.createElement('a');link.href=url;link.download='osa-private-review.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1500)});window.addEventListener('pagehide',()=>{if(captionUrl)URL.revokeObjectURL(captionUrl)})})();</script></html>`
}
export function parseByteRange(header,total){
  if(!header)return {start:0,end:total-1,status:200}
  if(typeof header!=='string'||!/^bytes=(\d*)-(\d*)$/.test(header))return null
  const match=/^bytes=(\d*)-(\d*)$/.exec(header)
  if(!match[1]&&!match[2])return null
  let start,end
  if(!match[1]) {const n=Number(match[2]);if(!Number.isSafeInteger(n)||n<1)return null;start=Math.max(0,total-n);end=total-1}
  else {start=Number(match[1]);end=match[2]?Number(match[2]):total-1;if(!Number.isSafeInteger(start)||!Number.isSafeInteger(end)||start>=total||end<start)return null;end=Math.min(end,total-1)}
  return {start,end,status:206}
}
function hashedEqual(a,b){
  const first=createHash('sha256').update(String(a)).digest(),last=createHash('sha256').update(String(b)).digest()
  return timingSafeEqual(first,last)
}
async function readBody(req,cap=2048){
  const arr=[];let size=0
  for await(const chunk of req){size+=chunk.length;if(size>cap)throw Error('Request body exceeds maximum');arr.push(chunk)}
  return Buffer.concat(arr).toString('utf8')
}
function sendHtml(res,code,html,nonce){res.statusCode=code;res.setHeader('Content-Type','text/html; charset=utf-8');res.setHeader('Content-Security-Policy',csp(nonce));res.end(html)}
function sameOrigin(req,port){const expected='http://127.0.0.1:'+port;const origin=req.headers.origin;const site=req.headers['sec-fetch-site'];return (!origin||origin===expected)&&(!site||site==='same-origin')&&(origin===expected||site==='same-origin')}

export async function startPrivateReviewServer({sourceDir,asset,password,cutTimes=[],port=0}){
  validateAsset(asset)
  if(typeof password!=='string'||password.length<16||password.length>256)throw Error('Private password must be 16-256 characters')
  const root=resolve(sourceDir)
  await verifyOriginal(root,asset)
  const sourceFile=await open(join(root,asset.file),constants.O_RDONLY | (constants.O_NOFOLLOW||0))
  const meta=await sourceFile.stat()
  const exact=createHash('sha256')
  for await (const chunk of sourceFile.createReadStream({autoClose:false})) exact.update(chunk)
  if(!meta.isFile()||meta.size!==asset.sizeBytes||exact.digest('hex')!==asset.sha256){await sourceFile.close();throw Error('Opened video does not match pinned source')}
  const sessions=new Map(), failures=new Map()
  const server=createServer(async(req,res)=>{
    common(res)
    try{
      if(req.headers.host!=='127.0.0.1:'+server.address().port){res.writeHead(403);res.end('Loopback Host required');return}
      const url=new URL(req.url||'/', 'http://127.0.0.1')
      if(url.search || url.hash || url.pathname.includes('%') || !['/','/login','/logout','/review','/media','/status'].includes(url.pathname)) {res.writeHead(404);res.end('Not found');return}
      const cookie=(req.headers.cookie||'').match(/(?:^|;\s*)osa_private_session=([a-f0-9]{64})(?:;|$)/)?.[1]
      const expiry=cookie&&sessions.get(cookie)
      const authed=Boolean(expiry && expiry>Date.now())
      if(url.pathname==='/login'){
        if(req.method!=='POST'||!sameOrigin(req,server.address().port)){res.writeHead(403);res.end('Forbidden');return}
        const now=Date.now(),hit=failures.get('local')||{count:0,first:now}
        if(now-hit.first>60000){hit.count=0;hit.first=now}
        if(hit.count>=6){res.writeHead(429);res.end('Too many attempts');return}
        const body=await readBody(req),submitted=new URLSearchParams(body).get('password')||''
        if(!hashedEqual(submitted,password)){hit.count++;failures.set('local',hit);res.writeHead(401);res.end('Access denied');return}
        failures.delete('local');const token=randomBytes(32).toString('hex');sessions.set(token,now+TWO_HOURS)
        res.writeHead(303,{'Location':'/review','Set-Cookie':'osa_private_session='+token+'; HttpOnly; SameSite=Strict; Path=/; Max-Age=7200'})
        res.end();return
      }
      if(url.pathname==='/logout'){
        if(req.method!=='POST'||!sameOrigin(req,server.address().port)){res.writeHead(403);res.end('Forbidden');return}
        if(cookie)sessions.delete(cookie)
        res.writeHead(303,{'Location':'/','Set-Cookie':'osa_private_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0'});res.end();return
      }
      if(url.pathname==='/' && req.method==='GET'&&!authed){const nonce=randomBytes(16).toString('base64');sendHtml(res,200,renderLogin(nonce),nonce);return}
      if(!authed){res.writeHead(401,{'Content-Type':'text/plain; charset=utf-8'});res.end('Local editor authentication required');return}
      if(url.pathname==='/' || url.pathname==='/review'){
        if(req.method!=='GET'){res.writeHead(405);res.end();return}
        const nonce=randomBytes(16).toString('base64');sendHtml(res,200,renderReview(nonce,asset,cutTimes),nonce);return
      }
      if(url.pathname==='/status'){
        if(req.method!=='GET'){res.writeHead(405);res.end();return}
        res.writeHead(200,{'Content-Type':'application/json; charset=utf-8'})
        res.end(JSON.stringify({sourceId:asset.id,sha256:asset.sha256,privacy:'loopback_only',rightsCleared:false,voiceVerified:false,publicationAuthorized:false}));return
      }
      if(url.pathname==='/media' && ['GET','HEAD'].includes(req.method)){
        const range=parseByteRange(req.headers.range,meta.size)
        if(!range){res.writeHead(416,{'Content-Range':'bytes */'+meta.size,'Accept-Ranges':'bytes'});res.end();return}
        const size=range.end-range.start+1
        const headers={'Content-Type':'video/mp4','Accept-Ranges':'bytes','Content-Length':size,'Content-Disposition':'inline; filename="osa-private-review.mp4"'}
        if(range.status===206)headers['Content-Range']='bytes '+range.start+'-'+range.end+'/'+meta.size
        res.writeHead(range.status,headers)
        if(req.method==='HEAD'){res.end();return}
        const stream=sourceFile.createReadStream({start:range.start,end:range.end,autoClose:false})
        stream.on('error',()=>{if(!res.destroyed)res.destroy()})
        stream.pipe(res);return
      }
      res.writeHead(405);res.end('Method not allowed')
    }catch(_error){if(!res.headersSent){res.statusCode=500;res.end('Private review error')}else res.destroy()}
  })
  try {await new Promise((ok,fail)=>{server.once('error',fail);server.listen(port,'127.0.0.1',ok)})}
  catch(e){await sourceFile.close();throw e}
  return {server,url:'http://127.0.0.1:'+server.address().port,async close(){await new Promise(ok=>server.close(ok));await sourceFile.close()}}
}
async function main(args){
  let root=null,id=null,port=0,manifest='docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json',cuts='docs/OSA_CINEMA_V18_PRIVATE_SCENE_CUT_QC.json'
  for(let i=0;i<args.length;i++){
    const k=args[i],v=args[++i];if(!v)throw Error('Missing CLI value for '+k)
    if(k==='--private-source-dir')root=v
    else if(k==='--source-id')id=v
    else if(k==='--port')port=Number(v)
    else if(k==='--manifest')manifest=v
    else if(k==='--cuts')cuts=v
    else throw Error('Unrecognized CLI flag '+k)
  }
  if(!root||!id||!Number.isInteger(port)||port<0||port>65535)throw Error('Expected --private-source-dir, --source-id and optional --port')
  const sources=JSON.parse(await readFile(manifest,'utf8')).assets
  const source=sources?.find(x=>x.id===id)
  if(!source||sources.filter(x=>x.id===id).length!==1)throw Error('Original source ID not in locked V16 manifest')
  const cutsData=JSON.parse(await readFile(cuts,'utf8')).assets
  const row=cutsData?.find(x=>x.id===id)
  if(!row||row.originalSha256!==source.sha256||row.sceneCutCount!==row.sceneCutTimecodes.length)throw Error('V18 cut map does not match original fingerprint')
  const served=await startPrivateReviewServer({sourceDir:root,asset:source,cutTimes:row.sceneCutTimecodes,password:process.env.OSA_CINEMA_PRIVATE_PASSWORD,port})
  console.log('OSA_PRIVATE_REVIEW_LOOPBACK_ONLY '+served.url+' (film not published)')
  for(const s of ['SIGINT','SIGTERM'])process.on(s,()=>served.close().then(()=>process.exit(0)))
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))main(process.argv.slice(2)).catch(e=>{console.error(e.message);process.exitCode=1})
