import { test, expect } from '@playwright/test'
import { mkdtemp, mkdir, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { startPrivateOwnerConsole } from './osa-cinema-v31-owner-console.mjs'

const password='browser-v31-local-private-test-password'
let service=null,temp=null

test.beforeEach(async()=>{
  temp=await mkdtemp(join(tmpdir(),'osa-v31-browser-'))
  const root=join(temp,'film'),reports=join(temp,'reports')
  await mkdir(join(root,'masters'),{recursive:true})
  await mkdir(join(root,'captions'))
  await mkdir(reports)
  service=await startPrivateOwnerConsole({root,reportsRoot:reports,password})
})
test.afterEach(async()=>{
  await service?.close();service=null
  if(temp)await rm(temp,{recursive:true,force:true})
  temp=null
})

test('actual Chromium desktop/mobile login, editable actions, clear NO-GO and logout',async({page},testInfo)=>{
  const jsErrors=[]
  page.on('pageerror',e=>jsErrors.push(String(e)))
  await page.goto(service.url+'/')
  await expect(page.getByRole('heading',{name:'Комната финальной приёмки'})).toBeVisible()
  await expect(page.getByLabel('Пароль владельца')).toBeVisible()
  await page.getByLabel('Пароль владельца').fill(password)
  await page.getByRole('button',{name:'Войти в закрытую студию'}).click()
  await expect(page.getByRole('heading',{name:'Премьера начинается с доказательств.'})).toBeVisible()
  await expect(page.getByText('ПУБЛИКАЦИЯ ЗАПРЕЩЕНА')).toBeVisible()
  await expect(page.locator('#run-preflight')).toBeEnabled()
  await expect(page.locator('#run-signatures')).toBeDisabled()
  await expect(page.locator('#primary-report')).toBeHidden()
  const overflow=await page.evaluate(()=>document.documentElement.scrollWidth-window.innerWidth)
  expect(overflow).toBeLessThanOrEqual(2)
  await page.locator('#run-preflight').click()
  await expect(page.locator('#preflight-pill')).toHaveText('Ошибка',{timeout:30000}) // no synthetic media created in browser smoke
  await expect(page.locator('#primary-report')).toBeHidden()
  await expect(page.locator('#run-preflight')).toBeEnabled()
  await page.getByRole('button',{name:'Закрыть сеанс'}).click()
  await expect(page.getByRole('heading',{name:'Комната финальной приёмки'})).toBeVisible()
  expect(jsErrors).toEqual([])
})
