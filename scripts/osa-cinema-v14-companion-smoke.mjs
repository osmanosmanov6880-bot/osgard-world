import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { buildCinemaTranscript, getCinemaScenePath, searchCinemaScenes } from '../src/osaCinemaCompanionText.ts'

const ru = Array.from({length:8}, (_, index) => ({
  act: index < 2 ? 1 : index < 6 ? 2 : 3,
  tag: 'СЦЕНА ' + (index + 1),
  title: 'Тема ' + (index + 1),
  body: 'Смысл главы ' + (index + 1),
  takeaway: 'Проверить вывод ' + (index + 1),
  ...(index === 5 ? {prompt:'Как защитить приватность?',choices:[{label:'Удалить данные',result:'Данные защищены',insight:'Передавать только необходимое'}]} : {}),
}))
const en = ru.map((scene,index)=>({...scene,tag:'SCENE '+(index+1),title:'Topic '+(index+1),body:'Meaning '+(index+1),takeaway:'Verify '+(index+1)}))
assert.deepEqual(searchCinemaScenes(ru,'ru',''), [0,1,2,3,4,5,6,7])
assert.deepEqual(searchCinemaScenes(ru,'ru','  ПРИВАТНОСТЬ '),[5])
assert.deepEqual(searchCinemaScenes(ru,'ru','Передавать только необходимое'),[5])
assert.deepEqual(searchCinemaScenes(en,'en','topic 3'),[2])
assert.deepEqual(searchCinemaScenes(en,'en','NO MATCH'),[])
const russianTranscript=buildCinemaTranscript(ru,'ru')
const englishTranscript=buildCinemaTranscript(en,'en')
assert.equal((russianTranscript.match(/^СЦЕНА [0-9]{2} \/ 08/gm)||[]).length,8)
assert.equal((englishTranscript.match(/^SCENE [0-9]{2} \/ 08/gm)||[]).length,8)
assert.ok(russianTranscript.includes('Удалить данные') && russianTranscript.includes('Передавать только необходимое'))
assert.ok(englishTranscript.includes('Full interactive course transcript'))
assert.ok(russianTranscript.includes('Не является записью фильма'), 'A transcript must not impersonate recorded cinema')
assert.equal(
  getCinemaScenePath('/osa-cinema','?lang=ru&utm_campaign=film&scene=7','#chapter','en',4,8),
  '/osa-cinema?lang=en&utm_campaign=film&scene=4#chapter',
)
assert.equal(getCinemaScenePath('/osa-cinema','','','ru',0,8),'/osa-cinema?lang=ru&scene=0')
assert.throws(()=>getCinemaScenePath('/osa-cinema','','','ru',-1,8),RangeError)
assert.throws(()=>getCinemaScenePath('/osa-cinema','','','en',8,8),RangeError)

const cinema=readFileSync('src/OSACinema.tsx','utf8')
const component=readFileSync('src/OSACinemaCompanion.tsx','utf8')
const css=readFileSync('src/osaCinemaCompanion.css','utf8')
assert.ok(cinema.includes('<OSACinemaCompanion locale={locale}'), 'Companion is not mounted')
assert.ok(cinema.includes('getCinemaScenePath(pathname,search,hash,locale,index'), 'Browser address must track chapter changes')
assert.ok(component.includes("setCanSpeak(typeof window !== 'undefined'"), 'Never assume device voice support')
assert.ok(component.includes('new SpeechSynthesisUtterance'), 'Only browser opt-in narration is advertised')
assert.ok(component.includes('window.speechSynthesis.cancel()'), 'Narration must stop when changing chapters')
assert.ok(component.includes('navigator.clipboard?.writeText'), 'Share should report actual clipboard success')
assert.ok(component.includes("type: 'text/plain;charset=utf-8'"), 'Download must be a real UTF-8 plain text file')
assert.ok(component.includes('aria-expanded={scriptOpen}') && component.includes('aria-current='), 'Chapters and script visibility need accessible states')
assert.ok(component.includes('aria-live='), 'User feedback should be announced to assistive technology')
assert.ok(css.includes('@media (max-width: 700px)') && css.includes('min-height: 48px'), 'Mobile buttons must be touch-friendly')
assert.ok(css.includes('[hidden]') && css.includes('display: none !important'), 'Hidden full transcript must not leak into screen layout')
assert.ok(css.includes('prefers-reduced-motion'), 'Motion preference is not respected')
console.log('OSA_CINEMA_V14_COMPANION_PASS: 8-scene bilingual transcript, search, URL safety, honest narration, mobile and a11y contracts')
