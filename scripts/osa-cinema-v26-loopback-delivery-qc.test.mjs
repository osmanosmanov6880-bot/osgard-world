import test from 'node:test'
import assert from 'node:assert/strict'
import { createServer } from 'node:http'
import { mkdtemp, writeFile, rm } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { verifyLoopbackURL, checkLoopbackDelivery } from './osa-cinema-v26-loopback-delivery-qc.mjs'
let root,source,server,url,sha,broken=false,brokenFull=false
const bytes=Buffer.from('This is synthetic test media and not a human-licensed film.'.repeat(12))
test.before(async()=>{
 root=await mkdtemp(join(tmpdir(),'osa-v26-'));source=join(root,'private.mp4');await writeFile(source,bytes)
 sha=createHash('sha256').update(bytes).digest('hex')
 server=createServer((req,res)=>{
  const authenticated=req.headers.cookie==='session=valid'
  if(!authenticated){res.writeHead(401,{'Cache-Control':'no-store'});res.end('Authentication required');return}
  const common={'Content-Type':broken?'application/octet-stream':'video/mp4','Accept-Ranges':'bytes','Content-Length':bytes.length}
  const range=req.headers.range
  if(req.method==='HEAD'){res.writeHead(200,common);res.end();return}
  if(range){const m=/^bytes=(\d+)-(\d*)$/.exec(range);const start=m?Number(m[1]):-1,end=m?(m[2]?Number(m[2]):bytes.length-1):-1
   if(!m||start>=bytes.length||end<start){res.writeHead(416,{'Content-Range':`bytes */${bytes.length}`});res.end();return}
   const chunk=bytes.subarray(start,end+1)
   res.writeHead(206,{'Content-Type':'video/mp4','Accept-Ranges':'bytes','Content-Length':chunk.length,'Content-Range':`bytes ${start}-${end}/${bytes.length}`});res.end(chunk);return
  }
  const full=Buffer.from(bytes)
  if(brokenFull)full[Math.floor(full.length/2)]^=1
  res.writeHead(200,common);res.end(full)
 })
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve))
 url=`http://127.0.0.1:${server.address().port}/media`
})
test.after(async()=>{await new Promise(resolve=>server.close(resolve));await rm(root,{recursive:true,force:true})})
test('real authenticated HEAD, 206, 416, unauthenticated rejection and exact byte segments',async()=>{
 const r=await checkLoopbackDelivery({url,source,sha256:sha,cookie:'session=valid'})
 assert.equal(r.status,'LOOPBACK_RANGE_QA_PASS_NOT_PUBLIC')
 assert.equal(r.errors.length,0)
 assert.deepEqual([r.tests.head,r.tests.firstRange.status,r.tests.invalidRange],[200,206,416])
 assert.equal(r.publicationAuthorized,false)
 assert.equal(r.fullContentVerified,true)
 assert.equal(r.tests.fullGet.status,200)
 assert.equal(r.tests.fullGet.sha256,sha)
})
test('external, credential-bearing, tokenized or nonlocal URL is denied before network access',()=>{
 for(const bad of ['https://example.com/media','http://169.254.169.254:80/media','http://127.0.0.1:1234/media?token=x','http://u:p@127.0.0.1:1234/media','http://127.0.0.1:1234/other','http://localhost:1234/media'])assert.throws(()=>verifyLoopbackURL(bad))
})
test('missing session cookie cannot pass QA',async()=>{
 const r=await checkLoopbackDelivery({url,source,sha256:sha,cookie:''})
 assert.ok(r.errors.length>0)
 assert.equal(r.productionDeploymentVerified,false)
})
test('incorrect local source SHA blocks delivery before HTTP',async()=>{
 await assert.rejects(checkLoopbackDelivery({url,source,sha256:'a'.repeat(64),cookie:'session=valid'}),/SHA-256 mismatch/)
})
test('incorrect MIME on HEAD produces staging HOLD',async()=>{
 broken=true
 const r=await checkLoopbackDelivery({url,source,sha256:sha,cookie:'session=valid'})
 assert.ok(r.errors.includes('invalid_mp4_mime'))
 broken=false
})

test('mutated middle of full HTTP movie is blocked even if first/last 206 ranges match',async()=>{
 brokenFull=true
 try{
  const r=await checkLoopbackDelivery({url,source,sha256:sha,cookie:'session=valid'})
  assert.equal(r.status,'STAGING_DELIVERY_HOLD')
  assert.ok(r.errors.includes('full_get_sha256_mismatch'))
  assert.equal(r.fullContentVerified,false)
  assert.equal(r.tests.firstRange.status,206)
 }finally{brokenFull=false}
})
