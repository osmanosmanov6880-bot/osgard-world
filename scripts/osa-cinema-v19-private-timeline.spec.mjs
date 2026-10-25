import { test, expect } from '@playwright/test'
import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

test('V19 real Chrome offline shot timeline, WebVTT preview, private export and mobile guard', async ({page},info) => {
  const errors=[],remote=[]
  page.on('pageerror',error=>errors.push(error.message))
  page.on('request',request=>{if(/^https?:/i.test(request.url()))remote.push(request.url())})
  await page.goto(pathToFileURL(resolve('tools/osa-cinema-v19-private-timeline.html')).href)
  await expect(page.locator('#edition option')).toHaveCount(4)
  await expect(page.locator('#timeline .shot')).toHaveCount(65)
  await expect(page.locator('#cuts')).toHaveText('64')
  await page.locator('#edition').selectOption('osa-v15-trailer-en')
  await expect(page.locator('#timeline .shot')).toHaveCount(11)
  await expect(page.locator('#cuts')).toHaveText('10')
  await page.locator('#edition').selectOption('osa-v15-directors-ru')
  await expect(page.locator('#timeline .shot')).toHaveCount(65)
  await page.locator('#timeline .shot').nth(20).click()
  await expect(page.locator('#status')).toContainText('Load an original MP4')
  await page.locator('#video-file').setInputFiles({
    name:'OSA_CINEMA_V15_DIRECTORS_WORKPRINT_RU_1080P.mp4',mimeType:'video/mp4',
    buffer:Buffer.from('THIS IS NOT THE ORIGINAL PRIVATE WORKPRINT')
  })
  await expect(page.locator('#status')).toContainText('Wrong file name or byte length')
  await expect(page.locator('#verify')).toBeDisabled()
  const vtt='WEBVTT\n\n00:00:01.000 --> 00:00:02.900\nPrivate test subtitle.\n'
  await page.locator('#vtt-file').setInputFiles({name:'sample.vtt',mimeType:'text/vtt',buffer:Buffer.from(vtt)})
  await expect(page.locator('#vtt-status')).toContainText('1 local cues loaded')
  await page.locator('#decision').selectOption('caption')
  await page.locator('#note').fill('Human synchronization still pending')
  await page.locator('#save-note').click()
  await expect(page.locator('.note-item')).toHaveCount(1)
  const downloaded=page.waitForEvent('download')
  await page.locator('#export').click()
  const file=await downloaded
  expect(file.suggestedFilename()).toBe('OSA_CINEMA_V19_REVIEW_osa-v15-directors-ru.json')
  const report=JSON.parse(await readFile(await file.path(),'utf8'))
  expect(report.sourceVerified).toBe(false)
  expect(report.publicationAuthorized).toBe(false)
  expect(report.rightsCleared).toBe(false)
  expect(report.subtitleApproved).toBe(false)
  expect(report.cueCount).toBe(1)
  expect(report.notes[0].body).toContain('Human synchronization')
  expect(remote).toEqual([])
  expect(errors).toEqual([])
  expect(await page.evaluate(()=>document.documentElement.scrollWidth <= window.innerWidth+2)).toBe(true)
  await page.screenshot({path:info.outputPath('osa-v19-private-timeline.png'),fullPage:true,animations:'disabled'})
})
