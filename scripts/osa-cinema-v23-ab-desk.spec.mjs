import { test, expect } from '@playwright/test'
import { createServer } from 'node:http'
import { mkdtemp, writeFile, readFile, copyFile, stat, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createHash } from 'node:crypto'
import { spawn } from 'node:child_process'

const V18='f3ce06afd5b64de9be77d5422bc888b79376c8d87d57d4b0a6c234230446deac'
let dir,host,server
async function createMedia(path,hz){
  const args=['-y','-nostdin','-hide_banner','-loglevel','error','-filter_threads','1',
    '-f','lavfi','-i','testsrc2=s=320x180:r=12:d=4',
    '-f','lavfi','-i',`sine=frequency=${hz}:sample_rate=48000:duration=4`,
    '-map','0:v:0','-map','1:a:0','-c:v','libx264','-threads','1',
    '-preset','ultrafast','-pix_fmt','yuv420p','-c:a','aac',
    '-movflags','+faststart','-shortest',path]
  await new Promise((resolve,reject)=>{
    const child=spawn('ffmpeg',args,{stdio:['ignore','ignore','pipe']})
    let stderr='';const timer=setTimeout(()=>child.kill('SIGKILL'),60000)
    child.stderr.on('data',data=>{stderr+=data.toString().slice(-2048)})
    child.once('error',e=>{clearTimeout(timer);reject(e)})
    child.once('close',(code,signal)=>{clearTimeout(timer);code===0?resolve():reject(Error(`FFmpeg failed: ${code}/${signal}: ${stderr}`))})
  })
}
async function sha(file){return createHash('sha256').update(await readFile(file)).digest('hex')}
test.beforeAll(async()=>{
  dir=await mkdtemp(join(tmpdir(),'osa-v23-ab-'))
  for(const mode of ['original','draft']){
    const tmp=join(dir,mode+'.mp4')
    await createMedia(tmp,mode==='original'?330:550)
    const exports=[]
    for(const locale of ['ru','en']){
      const name=`OSA_CINEMA_V22_PRIVATE_${locale.toUpperCase()}_${mode.toUpperCase()}.mp4`
      const f=join(dir,name);await copyFile(tmp,f)
      exports.push({file:name,intendedLocale:locale,selectedV18AudioIndex:mode==='original'?(locale==='ru'?0:1):(locale==='ru'?2:3),fileSha256:await sha(f),bytes:(await stat(f)).size,spokenLanguageVerified:false,rightsCleared:false,publicationAuthorized:false})
    }
    await writeFile(join(dir,mode+'-qa.json'),JSON.stringify({schemaVersion:1,edition:mode,publicationAuthorized:false,rightsCleared:false,publicDistributionAllowed:false,sourceV18Sha256:V18,exports}))
  }
  const content=await readFile('tools/osa-cinema-v23-private-ab-sound-desk.html')
  server=createServer((req,res)=>{if(req.url==='/private-review.html'){res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'});res.end(content)}else{res.writeHead(404);res.end('Not found')}})
  await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',resolve)})
  host='http://127.0.0.1:'+server.address().port
})
test.afterAll(async()=>{if(server)await new Promise(resolve=>server.close(resolve));if(dir)await rm(dir,{recursive:true,force:true})})

async function loadLocale(page,locale){
  await page.locator('#original-qa').setInputFiles(join(dir,'original-qa.json'))
  await page.locator('#draft-qa').setInputFiles(join(dir,'draft-qa.json'))
  await page.locator('#original-file').setInputFiles(join(dir,`OSA_CINEMA_V22_PRIVATE_${locale.toUpperCase()}_ORIGINAL.mp4`))
  await page.locator('#draft-file').setInputFiles(join(dir,`OSA_CINEMA_V22_PRIVATE_${locale.toUpperCase()}_DRAFT.mp4`))
  await expect(page.locator('#screen')).toHaveClass(/loaded/)
  await expect.poll(()=>page.locator('#picture').evaluate(x=>x.readyState)).toBeGreaterThan(0)
}

test('RU/EN: real private MP4s, A/B switching, SHA, timecoded JSON export and no remote calls',async({page},info)=>{
  const jsErrors=[],remote=[]
  page.on('pageerror',e=>jsErrors.push(e.message))
  page.on('request',r=>{if(/^https?:/i.test(r.url())&&!r.url().startsWith(host+'/'))remote.push(r.url())})
  await page.goto(host+'/private-review.html')
  await expect(page.locator('#cuts button')).toHaveCount(64)
  await loadLocale(page,'ru')
  await page.locator('#verify').click()
  await expect(page.locator('#loader')).toContainText('Оба MP4 проверены')
  await page.locator('#play').click()
  await expect.poll(()=>page.locator('#picture').evaluate(x=>x.currentTime)).toBeGreaterThan(.05)
  await page.locator('#b').click()
  await expect(page.locator('#b')).toHaveAttribute('aria-pressed','true')
  await page.locator('#seek').evaluate(el=>{el.value='1';el.dispatchEvent(new Event('input',{bubbles:true}))})
  await page.locator('#subtitle').setInputFiles({name:'private-test.vtt',mimeType:'text/vtt',buffer:Buffer.from('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nПроверка речи\n')})
  await expect(page.locator('#loader')).toContainText('Черновой WebVTT подключён')
  await page.locator('#note').fill('Проверить дикторскую дорожку и корректность произношения')
  await page.locator('#save').click()
  await expect(page.locator('.note')).toHaveCount(1)
  const download=page.waitForEvent('download')
  await page.locator('#export').click()
  const file=await download,report=JSON.parse(await readFile(await file.path(),'utf8'))
  expect(report.publicationAuthorized).toBe(false)
  expect(report.rightsCleared).toBe(false)
  expect(report.spokenLanguageApproved).toBe(false)
  expect(report.originalShaVerified).toBe(true)
  expect(report.draftShaVerified).toBe(true)
  expect(report.notes).toHaveLength(1)
  expect(report.notes[0].audioMode).toBe('b')
  await page.locator('#en').click()
  await loadLocale(page,'en')
  await expect(page.locator('#en')).toHaveAttribute('aria-pressed','true')
  await page.screenshot({path:info.outputPath('osa-v23-ab-review.png'),animations:'disabled',fullPage:true})
  expect(jsErrors).toEqual([])
  expect(remote).toEqual([])
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+2)).toBe(true)
})

test('Forged public approval in a local QA JSON is always rejected',async({page})=>{
  await page.goto(host+'/private-review.html')
  const manifest=JSON.parse(await readFile(join(dir,'original-qa.json'),'utf8'))
  manifest.publicationAuthorized=true
  await page.locator('#original-qa').setInputFiles({name:'forged-qa.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(manifest))})
  await expect(page.locator('#loader')).toContainText('не соответствует приватному')
  await expect(page.locator('#screen')).not.toHaveClass(/loaded/)
})
