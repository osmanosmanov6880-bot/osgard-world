import { test,expect } from '@playwright/test'
import { createHash } from 'node:crypto'

const pdf=Buffer.from('%PDF-1.7\n1 0 obj <</Type/Catalog>>\nendobj\n%%EOF\n')
const api='/api/core/'
const headers=t=>({Authorization:'Bearer '+t})
async function setup(page,request){
 const username='ops'+Math.random().toString(36).slice(2,10)
 const r=await request.post(api+'auth/register',{data:{username,password:'validated v64 pilot account password 2026'}})
 expect(r.status()).toBe(200)
 const actor=await r.json()
 await page.addInitScript(t=>sessionStorage.setItem('osgard:core-session:v1',t),actor.token)
 await page.goto('/osa-cinema/studio/collaboration?lang=en')
 const root=page.locator('main.osa-collab-page')
 await root.getByRole('textbox',{name:'Workspace title'}).fill('Verified V64 workspace')
 await root.getByRole('button',{name:'Create server workspace'}).click()
 await expect(root.getByRole('heading',{name:'Verified V64 workspace'})).toBeVisible()
 await root.getByRole('tab',{name:'File vault'}).click()
 return {root,actor}
}
test('V64 real Core owner integrity and 64 MiB cross-space quota in desktop',async({page,request},info)=>{
 const {root,actor}=await setup(page,request)
 const vault=root.locator('.osa-vault')
 await expect(vault.locator('[data-owner-storage-quota="enforced"]')).toContainText('64 MiB')
 await vault.locator('input[type=file]').setInputFiles({name:'verification.pdf',mimeType:'application/pdf',buffer:pdf})
 await vault.getByRole('button',{name:'Store actual bytes in Core'}).click()
 await expect(vault.locator('.osa-vault-asset')).toHaveCount(1)
 await vault.getByRole('button',{name:'Check stored bytes'}).click()
 await expect(vault.locator('[data-integrity-status="PASS"]')).toContainText('Files checked: 1')
 const list=await request.get(api+'cinema/spaces',{headers:headers(actor.token)})
 const id=(await list.json()).spaces[0].id
 const report=await request.get(api+'cinema/spaces/'+id+'/vault/integrity',{headers:headers(actor.token)})
 expect(report.status()).toBe(200)
 const body=await report.json()
 expect(body.assets[0].computedSha256).toBe(createHash('sha256').update(pdf).digest('hex'))
 expect(body.productionReady).toBe(false)
 expect(body.publicFilmReleaseAuthorized).toBe(false)
 await page.screenshot({path:info.outputPath('osa-v64-real-integrity-desktop.png'),fullPage:true,animations:'disabled'})
})
test('V64 320px RU integrity and NO-GO',async({page,request},info)=>{
 const {root}=await setup(page,request)
 const vault=root.locator('.osa-vault')
 await vault.getByRole('button',{name:'Check stored bytes'}).click()
 await expect(vault.locator('[data-integrity-status="PASS"]')).toContainText('Files checked: 0')
 await root.getByRole('button',{name:'Переключить на русский'}).click()
 await expect(vault.getByRole('button',{name:'Проверить целостность'})).toBeVisible()
 await page.setViewportSize({width:320,height:720})
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true)
 await expect(root).toHaveAttribute('data-release-state','no-go')
 await page.screenshot({path:info.outputPath('osa-v64-real-integrity-mobile.png'),fullPage:true,animations:'disabled'})
})
