import { test, expect } from '@playwright/test'
import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

test('V16 private review edits local-only workprint, rejects mismatched bytes and exports a non-release JSON', async ({ page }, info) => {
  const errors=[]
  const externalRequests=[]
  page.on('pageerror',error=>errors.push(error.message))
  page.on('request',request=>{ if (/^https?:/i.test(request.url())) externalRequests.push(request.url()) })
  await page.goto(pathToFileURL(resolve('tools/osa-cinema-private-review.html')).href)
  await expect(page.locator('#title')).toHaveText('Проверка оригинальных видеомонтажей')
  await page.locator('#lang').click()
  await expect(page.locator('#title')).toHaveText('Review original video workprints')
  await page.locator('#lang').click()
  const invalid=Buffer.from('Not really an MP4; uploaded locally for browser acceptance')
  await page.locator('#file').setInputFiles({name:'OSA_CINEMA_V15_45SEC_PREVIEW_RU_720P.mp4',mimeType:'video/mp4',buffer:invalid})
  await expect(page.locator('#edition')).toContainText('RU')
  await expect(page.locator('#status')).toContainText('Размер отличается')
  await page.locator('#verify').click()
  await expect(page.locator('#status')).toContainText('Несовпадение оригинала')
  await page.locator('#mark').click()
  await page.locator('#note').fill('00:00 — тестовое замечание монтажёра')
  await page.locator('#addNote').click()
  await expect(page.locator('.note')).toHaveCount(1)
  await page.locator('#rights').check()
  await page.locator('#edit').check()
  await page.locator('#rightsRef').fill('TEST_DOC_DOES_NOT_PROVE_A_LICENSE')
  const downloadPromise=page.waitForEvent('download')
  await page.locator('#export').click()
  const download=await downloadPromise
  expect(download.suggestedFilename()).toContain('OSA_PRIVATE_REVIEW_osa-v15-trailer-ru.json')
  const payload=JSON.parse(await readFile(await download.path(),'utf8'))
  expect(payload.releaseAuthorized).toBe(false)
  expect(payload.sha256MatchesExpected).toBe(false)
  expect(payload.checks.rights).toBe(true)
  expect(payload.notes).toHaveLength(1)
  expect(payload.decision).toBe('needs_revision')
  const vttPromise=page.waitForEvent('download')
  await page.locator('#vtt').click()
  const vtt=await vttPromise
  const vttText=await readFile(await vtt.path(),'utf8')
  expect(vttText).toContain('PRIVATE BLANK CAPTION DRAFT')
  expect(vttText).not.toContain('-->')
  expect(externalRequests).toEqual([])
  expect(errors).toEqual([])
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true)
  await page.screenshot({path:info.outputPath('v16-private-review.png'),fullPage:true,animations:'disabled'})
})
