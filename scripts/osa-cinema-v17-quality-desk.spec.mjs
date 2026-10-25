import { test, expect } from '@playwright/test'
import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

test('Private V17 quality desk cross-references ten masters and seeks measured video edit markers', async ({ page }, info) => {
  const errors=[]
  const remote=[]
  page.on('pageerror',error=>errors.push(error.message))
  page.on('request',request=>{if(/^https?:/i.test(request.url())) remote.push(request.url())})
  await page.goto(pathToFileURL(resolve('tools/osa-cinema-v17-quality-desk.html')).href)
  await expect(page.locator('#title')).toHaveText('Визуальная и звуковая приёмка')
  await expect(page.locator('#asset option')).toHaveCount(10)
  await page.locator('#asset').selectOption('osa-v15-directors-ru')
  await expect(page.locator('.marker')).toHaveCount(5)
  const black=page.locator('.marker').filter({hasText:'Чёрный интервал'})
  await expect(black).toHaveCount(1)
  await page.locator('#local').setInputFiles({
    name:'OSA_CINEMA_V15_DIRECTORS_WORKPRINT_RU_1080P.mp4',
    mimeType:'video/mp4',
    buffer:Buffer.from('INVALID MOCK VIDEO; private browser QA only'),
  })
  await expect(page.locator('#status')).toContainText('Размер или SHA-256')
  await page.locator('#verify').click()
  await expect(page.locator('#status')).toContainText('Размер или SHA-256')
  await black.click()
  await expect(page.locator('#note')).toHaveValue(/00:23\.83/)
  await page.locator('#add-note').click()
  await expect(page.locator('.note')).toHaveCount(1)
  const downloadPromise=page.waitForEvent('download')
  await page.locator('#export').click()
  const downloaded=await downloadPromise
  expect(downloaded.suggestedFilename()).toBe('OSA_PRIVATE_QC_osa-v15-directors-ru.json')
  const report=JSON.parse(await readFile(await downloaded.path(),'utf8'))
  expect(report.sourceVerified).toBe(false)
  expect(report.releaseAuthorized).toBe(false)
  expect(report.rightsVerified).toBe(false)
  expect(report.finalCaptionsApproved).toBe(false)
  expect(report.notes).toHaveLength(1)
  expect(report.notes[0].text).toMatch(/23\.83/)
  expect(report.notes[0].time).toBeCloseTo(23.833, 2)
  await page.locator('#switchlang').click()
  await expect(page.locator('#title')).toHaveText('Picture and sound quality review')
  await page.locator('#asset').selectOption('osa-voice-ru-act-2')
  await expect(page.locator('.marker')).toHaveCount(1)
  await expect(page.locator('.marker').first()).toContainText('Silence')
  await page.locator('#local').setInputFiles({
    name:'OSA Cinema — Act II — Russian narrator final.mp3',
    mimeType:'audio/mpeg',
    buffer:Buffer.from('not an audio file'),
  })
  await expect(page.locator('#status')).toContainText('differs')
  expect(remote).toEqual([])
  expect(errors).toEqual([])
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+2)).toBe(true)
  await page.screenshot({path:info.outputPath('osa-v17-quality-desk.png'),fullPage:true,animations:'disabled'})
})
