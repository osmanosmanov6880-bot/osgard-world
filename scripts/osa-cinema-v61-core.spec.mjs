import { test,expect } from '@playwright/test'
import { readFileSync } from 'node:fs'

const api='/api/core/'
const pwd='safe production pilot password 2026'
function name(prefix){return (prefix+Math.random().toString(36).slice(2,10)).toLowerCase()}
async function register(request,prefix='cine'){
 const username=name(prefix)
 const result=await request.post(api+'auth/register',{data:{username,password:pwd}})
 expect(result.status()).toBe(200)
 const body=await result.json()
 expect(body.token).toBeTruthy()
 return {...body,username}
}
async function withSession(page,token){
 await page.addInitScript(value=>sessionStorage.setItem('osgard:core-session:v1',value),token)
}
async function call(request,method,route,token,payload,versionKey){
 const result=await request.fetch(api+route,{
  method,headers:token?{'Authorization':'Bearer '+token,...(payload?{'Idempotency-Key':versionKey||crypto.randomUUID()}:{})}:{},
  ...(payload?{data:payload}:{})
 })
 return {status:result.status(),body:await result.json()}
}
test('V61 no session gives authentic sign-in gate, no fake multiuser data',async ({page,request})=>{
 expect((await request.get(api+'cinema/spaces')).status()).toBe(401)
 await page.goto('/osa-cinema/studio/collaboration?lang=en')
 const root=page.locator('main.osa-collab-page')
 await expect(root).toBeVisible()
 await expect(root).toHaveAttribute('data-release-state','no-go')
 await expect(page.locator('meta[name="robots"]')).toHaveAttribute('content','noindex,follow')
 await expect(root.getByRole('heading',{name:'Sign in to Core.'})).toBeVisible()
 await expect(root.locator('.osa-collab-task')).toHaveCount(0)
 await expect(root.getByRole('link',{name:/OSGARD account/})).toHaveAttribute('href','/account')
})
test('V61 real Core: create film space, task, replay-safe server export, member roles and revocation',async ({page,request,context},info)=>{
 const owner=await register(request,'own'),editor=await register(request,'edit'),viewer=await register(request,'watch')
 await withSession(page,owner.token)
 await page.goto('/osa-cinema/studio/collaboration?lang=en')
 const root=page.locator('main.osa-collab-page')
 await expect(root.getByRole('heading',{name:'Production coordination.'})).toBeVisible()
 await expect(root.getByRole('heading',{name:'New workspace'})).toBeVisible()
 await root.getByRole('textbox',{name:'Workspace title'}).fill('Cinema V61 audit workspace')
 await root.getByRole('button',{name:'Create server workspace'}).click()
 await expect(root.getByRole('heading',{name:'Cinema V61 audit workspace'})).toBeVisible()
 await expect(root.locator('.osa-collab-kpis')).toContainText('NO-GO')
 await root.locator('.osa-collab-task-form').getByRole('textbox',{name:'Title',exact:true}).fill('Check actor call sheets')
 await root.getByRole('textbox',{name:'Planning notes, not filming evidence'}).fill('Draft document. Does not verify a filmed scene.')
 await root.getByRole('button',{name:'Save task to SQLite'}).click()
 const task=root.locator('.osa-collab-task',{hasText:'Check actor call sheets'})
 await expect(task).toBeVisible()
 await task.getByRole('combobox',{name:'Planning status'}).selectOption('ready_for_review')
 await expect(task.locator('select')).toHaveValue('ready_for_review')
 const [dl]=await Promise.all([page.waitForEvent('download'),root.getByRole('button',{name:'Export snapshot'}).click()])
 const data=JSON.parse(readFileSync(await dl.path(),'utf8'))
 expect(data.format).toBe('OSA_CINEMA_CORE_COLLAB_EXPORT_V1')
 expect(data.doesNotAuthorizeRelease).toBe(true)
 expect(data.tasks).toHaveLength(1)
 expect(data.workspace.publicFilmReleaseAuthorized).toBe(false)
 expect(JSON.stringify(data)).not.toContain(owner.token)
 const spaceId=data.workspace.id
 const [editorSpace,ownerSpaces]=await Promise.all([
  call(request,'GET','cinema/spaces/'+spaceId,editor.token),
  call(request,'GET','cinema/spaces',owner.token)
 ])
 expect(editorSpace.status).toBe(404)
 expect(ownerSpaces.body.spaces).toHaveLength(1)
 await root.getByRole('tab',{name:'Team'}).click()
 await root.getByRole('textbox',{name:'Existing account username'}).fill(editor.username)
 await root.getByRole('button',{name:'Save server-side role'}).click()
 await expect(root.locator('.osa-collab-people')).toContainText(editor.username)
 await root.getByRole('textbox',{name:'Existing account username'}).fill(viewer.username)
 await root.getByRole('combobox',{name:'Role'}).selectOption('viewer')
 await root.getByRole('button',{name:'Save server-side role'}).click()
 const editorPage=await context.newPage()
 await withSession(editorPage,editor.token)
 await editorPage.goto('/osa-cinema/studio/collaboration?lang=en')
 await expect(editorPage.locator('.osa-collab-workspace')).toContainText('Cinema V61 audit workspace')
 await expect(editorPage.getByRole('button',{name:'Create server workspace'})).toBeVisible()
 await editorPage.getByRole('tab',{name:'Tasks'}).click()
 await expect(editorPage.getByRole('button',{name:'Save task to SQLite'})).toBeVisible()
 const viewerPage=await context.newPage()
 await withSession(viewerPage,viewer.token)
 await viewerPage.goto('/osa-cinema/studio/collaboration?lang=en')
 await expect(viewerPage.locator('.osa-collab-workspace')).toContainText('Cinema V61 audit workspace')
 await expect(viewerPage.locator('.osa-collab-task-form')).toHaveCount(0)
 const viewerDenied=await call(request,'POST','cinema/spaces/'+spaceId,viewer.token,{
  kind:'task.create',expectedVersion:data.workspace.version+3,sceneId:'S01',category:'camera',title:'Unauthorized edit'
 })
 expect(viewerDenied.status).toBe(403)
 await root.getByRole('button',{name:'Remove'}).first().click()
 await root.getByRole('button',{name:'Confirm removal'}).click()
 const editorRevoked=await call(request,'GET','cinema/spaces/'+spaceId,editor.token)
 expect(editorRevoked.status).toBe(404)
 await expect(root.locator('.osa-collab-kpis')).toContainText('NO-GO')
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true)
 await page.screenshot({path:info.outputPath('osa-v61-collab-desktop.png'),fullPage:true,animations:'disabled'})
})
test('V61 mobile 320px, bilingual controls and real threshold PREVIZ, no film publication',async ({page,request},info)=>{
 const owner=await register(request,'mobile')
 await withSession(page,owner.token)
 await page.goto('/osa-cinema/studio/collaboration?lang=ru')
 await expect(page.locator('main.osa-collab-page')).toBeVisible()
 await page.getByRole('combobox',{name:'Фильм'}).selectOption('threshold')
 await page.getByRole('textbox',{name:'Название пространства'}).fill('THRESHOLD QA')
 await page.getByRole('button',{name:'Создать серверное пространство'}).click()
 await expect(page.locator('.osa-collab-workspace')).toContainText('THRESHOLD QA')
 await page.getByRole('textbox',{name:'Название',exact:true}).fill('Проверить субтитры локального превиза')
 await page.getByRole('button',{name:'Записать задачу в SQLite'}).click()
 await expect(page.locator('.osa-collab-task')).toHaveCount(1)
 await expect(page.locator('.osa-collab-task')).toContainText('PREVIZ')
 await page.getByRole('button',{name:'Switch to English'}).click()
 await expect(page.locator('main.osa-collab-page')).toHaveAttribute('lang','en')
 await expect(page.locator('.osa-collab-kpis')).toContainText('NO-GO')
 await page.setViewportSize({width:320,height:720})
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2)).toBe(true)
 await page.screenshot({path:info.outputPath('osa-v61-collab-320.png'),fullPage:true,animations:'disabled'})
})
