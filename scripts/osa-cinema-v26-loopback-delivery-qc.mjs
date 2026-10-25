/** V26 local staging HTTP Range and byte-identity tester. No public-domain requests. */
import { createHash } from 'node:crypto'
import { createReadStream, constants } from 'node:fs'
import { lstat, open, readFile, writeFile, mkdir } from 'node:fs/promises'
import { basename, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
const HEX=/^[0-9a-f]{64}$/
export function verifyLoopbackURL(raw){
  if(typeof raw!=='string')throw Error('URL not provided')
  let u;try{u=new URL(raw)}catch{throw Error('Malformed URL')}
  if(u.protocol!=='http:'||u.hostname!=='127.0.0.1'||!u.port||!/^\/media$/.test(u.pathname)||u.search||u.hash||u.username||u.password)throw Error('Private QA only accepts exact loopback http://127.0.0.1:PORT/media')
  return u.href
}
async function safeSource(path,expectedSha){
  if(!HEX.test(expectedSha||''))throw Error('Expected SHA-256 missing')
  const s=await lstat(path)
  if(!s.isFile()||s.isSymbolicLink()||s.size<1||s.size>4_000_000_000)throw Error('Unsafe local candidate MP4')
  const h=createHash('sha256');for await(const part of createReadStream(path))h.update(part)
  if(h.digest('hex')!==expectedSha)throw Error('Local source SHA-256 mismatch')
  const f=await open(path,constants.O_RDONLY|constants.O_NOFOLLOW)
  try{
    const head=Buffer.alloc(Math.min(16,s.size)),tail=Buffer.alloc(Math.min(8,s.size))
    await f.read(head,0,head.length,0);await f.read(tail,0,tail.length,s.size-tail.length)
    return {size:s.size,head,tail}
  }finally{await f.close()}
}
async function request(url,method,headers={}){
  const controller=new AbortController(),clock=setTimeout(()=>controller.abort(),15000)
  try{return await fetch(url,{method,headers,redirect:'manual',signal:controller.signal,cache:'no-store'})}
  finally{clearTimeout(clock)}
}
export async function checkLoopbackDelivery({url,source,sha256,cookie=''}){
  const safe=verifyLoopbackURL(url)
  const sourceData=await safeSource(resolve(source),sha256)
  const headers=cookie?{Cookie:cookie}:{}
  const errors=[]
  // No login => no private video bytes, regardless of the client user agent.
  const denied=await request(safe,'GET',{Range:'bytes=0-15'})
  if(denied.status!==401&&denied.status!==403)errors.push('unauthenticated_video_exposure')
  await denied.body?.cancel()
  const head=await request(safe,'HEAD',headers)
  if(head.status!==200)errors.push('authorized_HEAD_not_200')
  if(!/^video\/mp4(?:\s*;|$)/i.test(head.headers.get('content-type')||''))errors.push('invalid_mp4_mime')
  if(head.headers.get('accept-ranges')!=='bytes')errors.push('missing_range_support')
  if(Number(head.headers.get('content-length'))!==sourceData.size)errors.push('wrong_content_length')
  await head.body?.cancel()
  async function range(from,to,expected){
    const res=await request(safe,'GET',{...headers,Range:`bytes=${from}-${to}`})
    const data=Buffer.from(await res.arrayBuffer())
    if(res.status!==206)errors.push('range_not_206')
    if(res.headers.get('content-range')!==`bytes ${from}-${to}/${sourceData.size}`)errors.push('incorrect_content_range')
    if(Number(res.headers.get('content-length'))!==expected.length)errors.push('incorrect_range_length')
    if(!data.equals(expected))errors.push('range_bytes_differ_from_verified_master')
    return {status:res.status,byteCount:data.length}
  }
  const start=await range(0,sourceData.head.length-1,sourceData.head)
  const last=await range(sourceData.size-sourceData.tail.length,sourceData.size-1,sourceData.tail)
  // First/last ranges alone do NOT prove the film's middle bytes were delivered.
  // Hash the entire authorized body incrementally, with bounded bytes and time.
  async function fullGet(){
    const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),30000)
    let response,received=0,digest=null
    try{
      response=await fetch(safe,{method:'GET',headers,redirect:'manual',cache:'no-store',signal:controller.signal})
      if(response.status!==200){errors.push('full_get_not_200');await response.body?.cancel();return {status:response.status,byteCount:0,sha256:null}}
      if(!/^video\/mp4(?:\s*;|$)/i.test(response.headers.get('content-type')||''))errors.push('full_get_invalid_mp4_mime')
      if(Number(response.headers.get('content-length'))!==sourceData.size)errors.push('full_get_wrong_content_length')
      const h=createHash('sha256')
      if(!response.body){errors.push('full_get_body_missing')}
      else{
        for await (const chunk of response.body){
          received+=chunk.byteLength
          if(received>sourceData.size){errors.push('full_get_oversized');break}
          h.update(chunk)
        }
        digest=h.digest('hex')
      }
      if(received!==sourceData.size)errors.push('full_get_size_mismatch')
      if(digest!==sha256)errors.push('full_get_sha256_mismatch')
      return {status:response.status,byteCount:received,sha256:digest}
    }catch(e){errors.push('full_get_failed_or_timeout');return {status:response?.status||0,byteCount:received,sha256:digest}}
    finally{clearTimeout(timer)}
  }
  const full=await fullGet()
  const beyond=await request(safe,'GET',{...headers,Range:`bytes=${sourceData.size}-`})
  if(beyond.status!==416)errors.push('invalid_range_not_416')
  if(beyond.headers.get('content-range')!==`bytes */${sourceData.size}`)errors.push('invalid_range_missing_size')
  await beyond.body?.cancel()
  return {schemaVersion:1,project:'OSA CINEMA',status:errors.length?'STAGING_DELIVERY_HOLD':'LOOPBACK_RANGE_QA_PASS_NOT_PUBLIC',
    safeLoopbackVerified:true,fullContentVerified:full.status===200&&full.byteCount===sourceData.size&&full.sha256===sha256,sourceSha256:sha256,bytes:sourceData.size,tests:{unauthorizedDenied:!errors.includes('unauthenticated_video_exposure'),head:head.status,firstRange:start,lastRange:last,fullGet:full,invalidRange:beyond.status},errors,
    productionDeploymentVerified:false,actualPhysicalDevicesVerified:false,publicationAuthorized:false,paidCheckoutEnabled:false}
}
async function main(args){
  const o={url:'',source:'',sha:'',report:'',strict:false}
  for(let i=0;i<args.length;i++){
    const x=args[i]
    if(x==='--url')o.url=args[++i]
    else if(x==='--source')o.source=args[++i]
    else if(x==='--sha256')o.sha=args[++i]
    else if(x==='--report')o.report=args[++i]
    else if(x==='--strict')o.strict=true
    else throw Error('Unknown option '+x)
  }
  if(!o.url||!o.source||!o.sha)throw Error('Expected --url --source --sha256')
  const report=await checkLoopbackDelivery({url:o.url,source:o.source,sha256:o.sha,cookie:process.env.OSA_CINEMA_PRIVATE_SESSION_COOKIE||''})
  if(o.report){await mkdir(dirname(resolve(o.report)),{recursive:true});await writeFile(resolve(o.report),JSON.stringify(report,null,2)+'\n',{mode:0o600,flag:'wx'})}
  console.log('OSA_V26_STAGING_QA '+JSON.stringify({status:report.status,errors:report.errors,publicationAuthorized:false}))
  if(o.strict&&report.errors.length)process.exitCode=1
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))main(process.argv.slice(2)).catch(e=>{console.error(e.message);process.exitCode=2})
