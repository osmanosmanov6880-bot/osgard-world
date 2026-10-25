import test from 'node:test'
import assert from 'node:assert/strict'
import {readFileSync,statSync} from 'node:fs'
import {join,resolve} from 'node:path'
const root=resolve(import.meta.dirname,'..')
const read=p=>readFileSync(join(root,p),'utf8')
const front=read('src/OSACinema.tsx')
const css=read('src/osaCinemaObsidian.css')
const archive=read('src/OSAObsidianArchive.tsx')
test('V42 is a scoped additive art theme',()=>{
 assert.match(front,/data-cinema-art='obsidian'/)
 assert.match(front,/import '\.\/osaCinemaObsidian\.css'/)
 assert.match(css,/\[data-cinema-art="obsidian"\]/)
 assert.match(css,/prefers-reduced-motion/)
})
test('the existing interactive screening and scene progression survive',()=>{
 assert.equal(front.split('<OSACinemaScreening ').length-1,1)
 assert.match(front,/onFinish=\{\(\)=>setCompleted\(true\)\}/)
 assert.match(front,/const scenes:Record<Locale,Scene\[]>/)
 assert.match(front,/getOSALearningProgress/)
 assert.match(front,/saveOSACinemaProgress/)
})
test('eight actual scenes and language toggle remain functional',()=>{
 assert.match(front,/data\.map\(\(chapter,sceneIndex\)/)
 assert.match(front,/aria-current=\{index===sceneIndex\?'step':undefined\}/)
 assert.match(front,/changeLocale/)
 assert.match(front,/onAnswer=\{\(sceneIndex,choiceIndex\)=>setAnswers/)
})
test('four thematic links open existing scenes, not fictional films',()=>{
 assert.equal(archive.split("id:'").length-1,4)
 for(const n of [0,2,4,6]) assert.match(archive,new RegExp('scene:'+n+'[,}]'))
 assert.doesNotMatch(archive,/\/subscribe|paymentIntent|\/checkout/i)
})
test('two existing media players remain; no fake video URLs',()=>{
 assert.equal(front.split('<OSAMediaPlayer ').length-1,2)
 assert.match(front,/getOSACinemaMedia\(index,locale,'video'\)/)
 assert.doesNotMatch(archive,/\.mp4|\.m3u8/i)
})
test('approved local art is present, within size limits, and not remote',()=>{
 const asset=join(root,'public/osa-cinema/obsidian/portal-640.webp')
 assert.ok(statSync(asset).size>9000&&statSync(asset).size<250000)
 assert.equal(readFileSync(asset).subarray(0,4).toString(),'RIFF')
 assert.match(css,/\/osa-cinema\/obsidian\/portal-640\.webp/)
 assert.doesNotMatch(css,/https?:\/\//)
})
test('historic public media catalog remains fail-closed',()=>{
 const media=read('src/osaMediaCatalog.ts')
 assert.match(media,/The entries intentionally have null sources/)
 assert.match(media,/if \(!resource\?\.src\) return 'not_published'/)
})
test('V42 cannot inadvertently add published-film or payment claims',()=>{
 assert.doesNotMatch(front,/\.stripe\.com|\/paid-film\/|\/checkout\(/i)
 assert.doesNotMatch(archive,/paid access|subscription price|\/subscribe/i)
})
// V42.1 regression: preserve semantic scene titles for RU/EN deep links and
// keep full-screen screening mounted while a viewer advances through scenes.
test('V42.1 keeps real scene H1 and screening mounted across chapter changes',()=>{
 assert.match(front,/className='osa42-scene-heading'>\{scene\.title\}<\/h1>/)
 assert.match(front,/key='osa42-stable-story'/)
 assert.doesNotMatch(front,/key=\{locale\+'-'\+index\}/)
 assert.match(front,/className='osa42-film-title' aria-hidden='true'/)
 assert.match(css,/\.osa42-scene-note h1\{/)
 assert.equal(front.split('<OSACinemaScreening ').length-1,1)
})

// Explicit regression for the mobile V13 visibility contract.
test('V42.2 mobile scene heading stays legible and above 48px at two lines',()=>{
 assert.match(css,/\.osa42-scene-note h1\{font-size:22px;line-height:1\.25\}/)
 assert.match(front,/className='osa42-scene-heading'>\{scene\.title\}<\/h1>/)
})
