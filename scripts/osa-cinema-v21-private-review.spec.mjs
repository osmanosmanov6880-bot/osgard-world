import { test, expect } from '@playwright/test'
import { mkdtemp, mkdir, stat, rm, readFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'
import { hashFile } from './osa-cinema-v20-private-hls.mjs'
import { startPrivateReviewServer } from './osa-cinema-v21-private-review-server.mjs'

let dir,service
const password='test-local-private-cinema-2026'
test.beforeAll(async()=>{
  dir=await mkdtemp(join(tmpdir(),'osa-v21-chrome-'))
  const src=join(dir,'media');await mkdir(src)
  const file=join(src,'private-browser-test.mp4')
  const p=spawnSync('ffmpeg',['-nostdin','-hide_banner','-loglevel','error','-f','lavfi','-i','testsrc2=s=1280x720:r=12:d=3','-f','lavfi','-i','sine=frequency=440:sample_rate=48000:duration=3','-map','0:v:0','-map','1:a:0','-c:v','libx264','-preset','ultrafast','-pix_fmt','yuv420p','-c:a','aac','-shortest','-y',file],{encoding:'utf8',timeout:60000})
  if(p.status!==0)throw Error('Synthetic cinema fixture was not encoded: '+p.stderr)
  const asset={id:'osa-test-trailer-ru',file:'private-browser-test.mp4',locale:'ru',edition:'trailer-workprint',sha256:await hashFile(file),sizeBytes:(await stat(file)).size,durationSeconds:3,width:1280,height:720,videoCodec:'h264',audioCodec:'aac'}
  service=await startPrivateReviewServer({sourceDir:src,asset,password,cutTimes:[.5,1.0,2.0],port:0})
})
test.afterAll(async()=>{if(service)await service.close();if(dir)await rm(dir,{recursive:true,force:true})})

test('real desktop/mobile Chrome private screening, seek, captions, notes and no HTTP exfiltration',async({page},info)=>{
  const errors=[],outside=[]
  page.on('pageerror',e=>errors.push(e.message))
  page.on('request',r=>{if(r.url().startsWith('http')&&!r.url().startsWith(service.url))outside.push(r.url())})
  await page.goto(service.url)
  await expect(page.locator('h1')).toContainText('Просмотр только для редактора')
  await page.locator('#password').fill(password)
  await page.getByRole('button',{name:'Открыть приватный просмотр'}).click()
  await expect(page).toHaveURL(service.url+'/review')
  await expect(page.locator('#cuts button')).toHaveCount(3)
  await expect(page.locator('.warning')).toContainText('не подтверждены')
  await page.locator('#cuts button').nth(1).click()
  await expect.poll(()=>page.locator('#film').evaluate(el=>el.currentTime)).toBeGreaterThan(.7)
  await page.locator('#vtt').setInputFiles({name:'local-only.vtt',mimeType:'text/vtt',buffer:Buffer.from('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nТест субтитров\n','utf8')})
  await expect(page.locator('#status')).toContainText('приватный черновик WebVTT')
  await page.locator('#note').fill('Проверить точность речи после отметки 1.0 секунды')
  await page.locator('#save').click()
  await expect(page.locator('#notes')).toContainText('1')
  const download=page.waitForEvent('download')
  await page.locator('#export').click()
  const result=await download
  const report=JSON.parse(await readFile(await result.path(),'utf8'))
  expect(report.publicationAuthorized).toBe(false)
  expect(report.rightsCleared).toBe(false)
  expect(report.notes.length).toBe(1)
  await page.screenshot({path:info.outputPath('osa-v21-private-screening.png'),animations:'disabled',fullPage:true})
  await page.getByRole('button',{name:'Закрыть доступ'}).click()
  await expect(page.locator('h1')).toContainText('Просмотр только для редактора')
  expect(errors).toEqual([])
  expect(outside).toEqual([])
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+2)).toBe(true)
})
