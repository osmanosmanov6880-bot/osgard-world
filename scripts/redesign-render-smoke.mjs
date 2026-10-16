import { build } from 'esbuild'
import { mkdir,writeFile,unlink } from 'node:fs/promises'
import { createRequire } from 'node:module'
import assert from 'node:assert/strict'
const output='node_modules/.tmp/redesign-render.cjs'
await mkdir('node_modules/.tmp',{recursive:true})
const source=`import React from 'react';import {renderToStaticMarkup} from 'react-dom/server';import {BrandShell} from './src/BrandShell';import WorldHome from './src/WorldHome';import IntelligenceHome from './src/IntelligenceHome';import PlayHome from './src/PlayHome';import BrandPages from './src/BrandPages';import DataCenter from './src/DataCenter';import CoreWorkspace from './src/CoreWorkspace';import LearningCampus from './src/LearningCampus';import ServerLessonProgress from './src/ServerLessonProgress';import PilotOrganizer from './src/PilotOrganizer';import AccountPage from './src/AccountPage';import ReleaseAcceptance from './src/ReleaseAcceptance';import DeliveryPanel from './src/DeliveryPanel';import OperationsPage from './src/OperationsPage';import ClientPortal from './src/ClientPortal';import TeamsPage from './src/TeamsPage';
export function renderPage(page,gameId){globalThis.location={pathname:gameId?'/play/world/'+gameId:page==='world'?'/':'/'+page,search:''};globalThis.localStorage={getItem:()=>null};const theme=['intelligence','campus','lesson-bridge','organizer'].includes(page)?'intelligence':['world','quality','brand','data','workspace','account','acceptance','delivery','operations','deliveries','teams'].includes(page)?'world':'play';return renderToStaticMarkup(<BrandShell theme={theme}>{page==='teams'?<TeamsPage/>:page==='deliveries'?<ClientPortal/>:page==='operations'?<OperationsPage/>:page==='delivery'?<><h1>Передача</h1><DeliveryPanel project={{id:'a'.repeat(32),version:1,role:'viewer',data:{consents:{studio:true,business:true}}}} userId='viewer' disabled={false} onDirty={()=>{}} onAction={async()=>{}}/></>:page==='acceptance'?<><h1>Приёмка</h1><ReleaseAcceptance project={{id:'a'.repeat(32),version:1,role:'viewer'}} userId='viewer' disabled={false} onDirty={()=>{}} onReview={async()=>{}}/></>:page==='account'?<AccountPage/>:page==='organizer'?<PilotOrganizer/>:page==='campus'?<LearningCampus/>:page==='lesson-bridge'?<><h1>Lesson bridge</h1><ServerLessonProgress slug="how-language-models-work" answer={null} locale="ru"/></>:page==='workspace'?<CoreWorkspace/>:page==='data'?<DataCenter/>:page==='world'?<WorldHome/>:page==='intelligence'?<IntelligenceHome/>:page==='quality'||page==='brand'?<BrandPages quality={page==='quality'}/>:<PlayHome gameId={gameId}/>}</BrandShell>)};`
const result=await build({stdin:{contents:source,resolveDir:process.cwd(),loader:'tsx'},bundle:true,format:'cjs',platform:'node',packages:'external',write:false,loader:{'.css':'empty'},jsx:'automatic'})
await writeFile(output,result.outputFiles[0].text)
try{
 const require=createRequire(import.meta.url),{renderPage}=require('../'+output)
 for(const name of ['world','intelligence','play','quality','brand','data','workspace','campus','lesson-bridge','organizer','account','acceptance','delivery','operations','deliveries','teams']){
  const html=renderPage(name)
  assert.equal((html.match(/<h1\b/g)||[]).length,1,name+' requires one primary heading')
  assert.ok(html.includes('aria-label="Продукты OSGARD"')&&html.includes('id="product-main"'),name+' shell')
  assert.ok(html.includes('href="/intelligence"')&&html.includes('href="/play"'))
  if(name==='world')assert.ok(html.includes('id="contact"')&&html.includes('Заявка не отправлена')===false&&html.includes('форма сама ничего не отправляет'))
  if(name==='intelligence')assert.ok(html.includes('id="demo-sources" hidden')&&html.includes('type="checkbox"')&&html.includes('НЕ ОТВЕТ ПОДКЛЮЧЁННОЙ МОДЕЛИ'))
  if(name==='teams')assert.ok(html.includes('CORE / TEAMS')&&html.includes('Подключаем команды'));
  if(name==='deliveries')assert.ok(html.includes('RECEIVED MATERIALS')&&html.includes('Подключаем кабинет'));
  if(name==='operations')assert.ok(html.includes('CORE / OPERATIONS')&&html.includes('Подключаем рабочий центр'));
  if(name==='delivery')assert.ok(html.includes('HANDOFF &amp; SUPPORT')&&html.includes('Загружаем состояние передачи')&&html.includes('Никакие приглашения, письма'));
  if(name==='acceptance')assert.ok(html.includes('RELEASE ACCEPTANCE')&&html.includes('Загружаем материалы')&&html.includes('не является независимой сертификацией'));
  if(name==='account')assert.ok(html.includes('ACCOUNT ACCESS')&&html.includes('Восстановить пароль по коду')&&!html.includes('account-codes'));
  if(name==='organizer')assert.ok(html.includes('Работы не теряются')&&html.includes('Панель помогает провести пилот'))
  if(name==='campus')assert.ok(html.includes('Знание становится')&&html.includes('Честный статус обучения'))
  if(name==='lesson-bridge')assert.ok(html.includes('Сохранить практику в проект')&&html.includes('Подключить серверный проект'))
  if(name==='workspace')assert.ok(html.includes('OSGARD CORE')&&html.includes('Рубеж пилота')&&!html.includes('type="password"'))
  if(name==='data')assert.ok(html.includes('Скачать текущие данные')&&html.includes('type="file"'))
  if(name==='play')assert.equal((html.match(/class="play-card"/g)||[]).length,6)
 }
 const missing=renderPage('play','null-shift');assert.ok(missing.includes('disabled=""')&&!missing.includes('data-game-launch="null-shift"'))
 const ready=renderPage('play','vector-zero');assert.ok(ready.includes('data-game-launch="vector-zero"')&&ready.includes('Избранное и история открытия'))
 const notFound=renderPage('play','unknown');assert.ok(notFound.includes('Мир не найден'))
 console.log('Server rendering checks passed: sixteen surfaces, landmarks, demo controls, six worlds and honest launch states')
}finally{await unlink(output)}
