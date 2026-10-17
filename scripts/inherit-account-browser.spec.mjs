import { test, expect } from '@playwright/test';
import { API, CORE_KEY, ids, tokens, serviceFixture } from './inherit-account-smoke.mjs';

// Actual Chromium and shipped assets, with isolated Core contract fixtures.
// No production accounts, messages or network writes.
function localSeed(){
 return {generation:173,budget:99,objects:[{tool:'flower',x:45,y:40}],pending:[{type:'flower',x:45,y:40}],
  changes:['planted moonflowers'],history:[{generation:172,by:'@Local',action:'A local-only story.',when:'Yesterday'}],snapshots:[]};
}
async function install(context,info,service,{user='alice',local=localSeed(),intercept,deniedStorage=false}={}){
 const origin=new URL(info.project.use.baseURL).origin;
 await context.addInitScript(({origin,key,token,local,deniedStorage})=>{
  if(location.origin!==origin)return;
  if(token)sessionStorage.setItem(key,token);else sessionStorage.removeItem(key);
  if(deniedStorage){Object.defineProperty(window,'localStorage',{configurable:true,get(){throw new DOMException('Fixture access denied','SecurityError')}});return}
  if(!sessionStorage.getItem('inherit-fixture-seeded')){
   localStorage.setItem('inherit-world-v1',JSON.stringify(local));sessionStorage.setItem('inherit-fixture-seeded','1');
  }
 },{origin,key:CORE_KEY,token:tokens[user]||'',local,deniedStorage});
 await context.route('**/api/world/quiet-reach**',route=>route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({error:'fixture_local',message:'No shared world in this fixture'})}));
 await context.route('**/api/analytics',route=>route.fulfill({status:204,body:''}));
 await context.route('**/api/core/**',async route=>{
  const request=route.request(),url=new URL(request.url());
  const call={url:url.href,path:url.pathname,method:request.method(),headers:request.headers(),body:request.postData()?JSON.parse(request.postData()):undefined};
  if(intercept&&await intercept(route,call,service))return;
  const reply=service.handle(call);
  await route.fulfill({status:reply.status,contentType:'application/json',headers:{'Cache-Control':'no-store'},body:JSON.stringify(reply.body)});
 });
}
function errorsFor(page){const errors=[];page.on('pageerror',error=>errors.push(error.message));return errors}
async function createWorld(page,title='Browser private world'){
 await expect(page.locator('#inherit-account-identity')).toContainText('@alice');
 const details=page.locator('#inherit-account-authorized > details').first();
 if(!(await details.getAttribute('open')))await details.locator('summary').click();
 await page.locator('#inherit-account-title').fill(title);
 await page.locator('#inherit-account-new').click();
 await expect(page.locator('#inherit-account-world-title')).toHaveText(title);
 await expect(page.locator('#pass')).toBeEnabled();
}
async function saveTrace(page,message,key='1'){
 await page.locator('#world').press(key);
 await page.locator('#world').press('Enter');
 await page.locator('#inherit-account-message').fill(message);
 await page.locator('#pass').click();
 await expect(page.locator('#inherit-account-status')).toContainText('The server confirmed');
 await expect(page.locator('#pass')).toBeEnabled();
}
function assertTokenIsolation(service){
 for(const call of service.calls){
  if(call.headers.authorization){
   expect(call.path==='/api/core/auth/me'||call.path.startsWith(API)).toBe(true);
   expect(new URL(call.url).search).toBe('');
   for(const token of Object.values(tokens)){expect(call.url).not.toContain(token);expect(JSON.stringify(call.body||{})).not.toContain(token)}
  }
 }
}

test('INHERIT account: two custodians save, pass, return through a persisted notification and view an immutable generation',async({page,browser},info)=>{
 const service=serviceFixture();await install(page.context(),info,service);const errors=errorsFor(page);
 await page.goto('/games/inherit/?mode=account&lang=en',{waitUntil:'domcontentloaded'});
 await createWorld(page);
 await saveTrace(page,'A path from the first keeper','4');
 await expect(page.locator('#gen')).toHaveText('GEN 2');
 const first=[...service.worlds.values()][0].generations[0],originalSnapshot=JSON.stringify(first.objects);
 await page.locator('#inherit-account-selected details > summary').click();
 await page.locator('#inherit-account-target').fill(ids.bob);
 await page.locator('#inherit-account-sharing').check();
 await page.locator('#inherit-account-offer').click();
 await expect(page.locator('#inherit-account-invitation-copy')).toContainText('@alice → @bob');
 await expect(page.locator('#pass')).toBeDisabled();
 const invitation=[...service.invitations.values()][0];
 const other=await browser.newContext({baseURL:info.project.use.baseURL,viewport:info.project.use.viewport,isMobile:info.project.use.isMobile,hasTouch:info.project.use.hasTouch,locale:'ru-RU',reducedMotion:'reduce'});
 try{
  await install(other,info,service,{user:'bob'});const bob=await other.newPage(),bobErrors=errorsFor(bob);
  await bob.goto('/games/inherit/?mode=account&lang=en&invitation='+invitation.id,{waitUntil:'domcontentloaded'});
  await expect(bob.locator('#inherit-account-invitation-copy')).toContainText('@alice → @bob');
  await expect(bob.locator('#objects > .placed')).toHaveCount(0);
  expect(service.calls.filter(call=>call.headers.authorization==='Bearer '+tokens.bob&&/^\/api\/core\/inherit\/v1\/worlds\/[a-f0-9]{32}$/.test(call.path))).toHaveLength(0);
  await bob.locator('#inherit-account-accept').click();
  await expect(bob.locator('#pass')).toBeEnabled();
  await expect(bob.locator('#objects > .placed')).toHaveCount(1);
  await saveTrace(bob,'A lantern from the next keeper','3');
  await expect(bob.locator('#gen')).toHaveText('GEN 3');
  await page.locator('#inherit-account-refresh').click();
  await expect(page.locator('#inherit-account-world-access')).toContainText('@bob');
  await expect(page.locator('#pass')).toBeDisabled();
  const before=await page.locator('#objects > .placed').count();await page.locator('#world').press('Enter');
  await expect(page.locator('#objects > .placed')).toHaveCount(before);
  const note=page.locator('#inherit-account-notifications li').filter({hasText:'New generation'});
  await expect(note).toHaveAttribute('data-unread','true');await note.getByRole('button',{name:'Open',exact:true}).click();
  await expect(page.locator('#replay-copy')).toContainText('Viewing generation 2');
  await expect(page.locator('#objects > .placed')).toHaveCount(2);
  await expect(page.locator('#inherit-account-notifications li').filter({hasText:'New generation'})).toHaveAttribute('data-unread','false');
  await page.locator('#return-now').click();await page.locator('#showHistory').click();
  await page.locator('#timeline .entry').last().getByRole('button',{name:'View traces'}).click();
  await expect(page.locator('#replay-copy')).toContainText('Viewing generation 1');
  await expect(page.locator('#objects > .placed')).toHaveCount(1);
  expect(JSON.stringify([...service.worlds.values()][0].generations[0].objects)).toBe(originalSnapshot);
  await page.screenshot({path:info.outputPath('inherit-confirmed-generation-return.png'),fullPage:true});
  await page.locator('#return-now').click();await page.locator('[data-memory="tree"]').first().press('Enter');
  await expect(page.locator('#memoryTitle')).toHaveText('Template memory');
  await expect(page.locator('#memoryText')).toContainText('fictional island template');
  await page.locator('#close').click();
  await page.locator('[data-game-language="ru"]').click();
  await expect(page.locator('#inherit-local-mode')).toHaveText('Вернуться к локальному миру');
  await expect(page.locator('#inherit-account-status')).not.toContainText('The server');
  await page.locator('#inherit-local-mode').click();
  expect(await page.evaluate(()=>JSON.parse(localStorage.getItem('inherit-world-v1')))).toEqual(localSeed());
  expect(await page.evaluate(()=>window.InheritGame.snapshot())).toEqual(localSeed());
  expect(errors).toEqual([]);expect(bobErrors).toEqual([]);assertTokenIsolation(service);
 }finally{await other.close()}
});

test('INHERIT account: missing session offers a canonical sign-in return and keeps the local mode available',async({page},info)=>{
 const service=serviceFixture();await install(page.context(),info,service,{user:null});const errors=errorsFor(page);
 const id='b'.repeat(32);
 await page.goto('/games/inherit/?mode=account&lang=en&world='+id+'&api=https://example.invalid&token=never-copy',{waitUntil:'domcontentloaded'});
 await expect(page.locator('#inherit-account-signin')).toBeVisible();
 const href=await page.locator('#inherit-account-signin').getAttribute('href');
 const returnTo=new URL(href,info.project.use.baseURL).searchParams.get('returnTo');
 expect(returnTo).toBe('/games/inherit/?mode=account&lang=en&world='+id);
 expect(service.calls).toHaveLength(0);
 await expect(page.locator('#pass')).toBeDisabled();
 await page.locator('#inherit-local-mode').click();await expect(page.locator('#pass')).toBeEnabled();
 expect(await page.evaluate(()=>window.InheritGame.snapshot())).toEqual(localSeed());
 expect(errors).toEqual([]);
});

test('INHERIT account: a lost create response survives real reload and only GET recovers its original operation',async({page},info)=>{
 const service=serviceFixture();let lost=false;
 await install(page.context(),info,service,{intercept:async(route,call)=>{
  if(!lost&&call.method==='POST'&&call.path===API+'worlds'){lost=true;service.handle(call);await route.abort('failed');return true}
  return false;
 }});
 const errors=errorsFor(page);await page.goto('/games/inherit/?mode=account&lang=en',{waitUntil:'domcontentloaded'});
 await expect(page.locator('#inherit-account-identity')).toContainText('@alice');
 await page.locator('#inherit-account-authorized > details').first().locator('summary').click();
 await page.locator('#inherit-account-title').fill('Lost response');await page.locator('#inherit-account-copy').click();
 await expect(page.locator('#inherit-account-operations button')).toHaveCount(1);
 await expect(page.locator('#inherit-account-status')).toContainText('result is unknown');
 const journal=await page.evaluate(()=>Object.keys(localStorage).filter(key=>key.startsWith('osgard:inherit-operation:v1:')));
 expect(journal).toHaveLength(1);
 await page.reload({waitUntil:'domcontentloaded'});
 await expect(page.locator('#inherit-account-operations button')).toHaveCount(1);
 await page.locator('#inherit-account-operations button').click();
 await expect(page.locator('#inherit-account-world-title')).toHaveText('Lost response');
 await expect(page.locator('#inherit-account-operations button')).toHaveCount(0);
 await expect(page.locator('#objects > .placed.flower')).toHaveCount(1);
 await expect(page.locator('#budget')).toHaveText('99');
 expect(service.calls.filter(call=>call.method==='POST'&&call.path===API+'worlds')).toHaveLength(1);
 expect(service.calls.filter(call=>call.method==='GET'&&call.path.startsWith(API+'operations/'))).toHaveLength(1);
 expect(await page.evaluate(()=>JSON.parse(localStorage.getItem('inherit-world-v1')))).toEqual(localSeed());
 expect(errors).toEqual([]);assertTokenIsolation(service);
});

test('INHERIT account: account change while POST is pending preserves the old journal and blocks stale completion',async({page},info)=>{
 const service=serviceFixture();let release,heldCall,hold=false;
 const pending=new Promise(resolve=>{release=resolve});
 await install(page.context(),info,service,{intercept:async(route,call)=>{
  if(hold&&call.method==='POST'&&call.path.endsWith('/generations')){
   heldCall=call;await pending;const reply=service.handle(call);
   await route.fulfill({status:reply.status,contentType:'application/json',body:JSON.stringify(reply.body)});return true;
  }return false;
 }});
 const errors=errorsFor(page);
 try{
  await page.goto('/games/inherit/?mode=account&lang=en',{waitUntil:'domcontentloaded'});await createWorld(page);
  hold=true;await page.locator('#world').press('Enter');await page.locator('#pass').click();
  await expect.poll(()=>!!heldCall).toBe(true);
  await expect(page.locator('#pass')).toBeDisabled();
  await page.evaluate(({key,token})=>{sessionStorage.setItem(key,token);window.dispatchEvent(new Event('focus'))},{key:CORE_KEY,token:tokens.bob});
  await page.locator('#inherit-account-refresh').click();
  await expect(page.locator('#inherit-account-identity')).toContainText('@bob');
  release();await expect.poll(()=>service.worlds.values().next().value.generations.length).toBe(1);
  await expect(page.locator('#inherit-account-identity')).toContainText('@bob');
  await expect(page.locator('#pass')).toBeDisabled();await expect(page.locator('#inherit-account-world-title')).toHaveText('');
  const journals=await page.evaluate(()=>Object.keys(localStorage).filter(key=>key.startsWith('osgard:inherit-operation:v1:')).map(key=>JSON.parse(localStorage.getItem(key))));
  expect(journals).toHaveLength(1);expect(journals[0].accountId).toBe(ids.alice);
  expect(service.calls.filter(call=>call.method==='POST'&&call.path.endsWith('/generations'))).toHaveLength(1);
  expect(errors).toEqual([]);assertTokenIsolation(service);
 }finally{release()}
});

test('INHERIT account: denied storage getter keeps the launcher usable and prevents any protected mutation',async({page},info)=>{
 const service=serviceFixture();await install(page.context(),info,service,{deniedStorage:true});const errors=errorsFor(page);
 await page.goto('/games/inherit/?mode=account&lang=en',{waitUntil:'domcontentloaded'});
 await expect(page.locator('#inherit-account-status')).toContainText('Persistent storage is unavailable');
 await expect(page.locator('#pass')).toBeDisabled();
 await expect(page.locator('#inherit-account-new')).toBeDisabled();
 await page.locator('#inherit-local-mode').click();
 await expect(page.locator('#inherit-save-state')).toContainText('Save unavailable');
 await page.locator('#world').press('Enter');
 await expect(page.locator('#objects > .placed')).toHaveCount(1);
 expect(service.calls.filter(call=>call.method==='POST')).toHaveLength(0);
 expect(errors).toEqual([]);
});
