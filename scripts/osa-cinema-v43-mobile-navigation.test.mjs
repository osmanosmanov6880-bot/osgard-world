import test from 'node:test'
import assert from 'node:assert/strict'
import {readFileSync} from 'node:fs'
import {join,resolve} from 'node:path'
const root=resolve(import.meta.dirname,'..')
const component=readFileSync(join(root,'src/OSAObsidianSceneNavigator.tsx'),'utf8')
const css=readFileSync(join(root,'src/osaCinemaV43.css'),'utf8')
const viewer=readFileSync(join(root,'src/OSACinema.tsx'),'utf8')

test('V43 uses only the eight existing scene titles and no film URLs',()=>{
 assert.match(component,/titles: readonly string\[\]/)
 assert.match(component,/titles\.map\(\(title, index\)/)
 assert.match(viewer,/titles=\{data\.map\(chapter=>chapter\.title\)\}/)
 assert.doesNotMatch(component,/\.(?:mp4|m3u8)|checkout|subscribe|paid access/i)
})
test('scene selection is bounded, no duplicate or invalid navigations',()=>{
 assert.match(component,/Number\.isInteger\(scene\)/)
 assert.match(component,/scene >= 0 && scene < titles\.length/)
 assert.match(component,/scene !== safeIndex/)
 assert.match(component,/Math\.max\(0, Math\.min\(currentIndex, titles\.length - 1\)\)/)
})
test('chapter select and arrows preserve bilingual accessibility',()=>{
 assert.match(component,/<select value=\{safeIndex\} onChange=/)
 assert.match(component,/aria-label=\{ru \? 'Выбрать сцену истории' : 'Choose a story scene'\}/)
 assert.match(component,/disabled=\{safeIndex === 0\}/)
 assert.match(component,/disabled=\{safeIndex === titles\.length - 1\}/)
 assert.match(component,/aria-live='polite'/)
})
test('the real public React route mounts one V43 navigator without replacing V42',()=>{
 assert.equal(viewer.split("<OSAObsidianSceneNavigator ").length-1,1)
 assert.match(viewer,/import OSAObsidianSceneNavigator from '\.\/OSAObsidianSceneNavigator'/)
 assert.match(viewer,/import '\.\/osaCinemaV43\.css'/)
 assert.match(viewer,/onSelectScene=\{sceneIndex=>\{setIndex\(sceneIndex\);setCompleted\(false\);/)
 assert.match(viewer,/data-cinema-art='obsidian'/)
 assert.match(viewer,/key='osa42-stable-story'/)
 assert.match(viewer,/className='osa42-scene-heading'>\{scene\.title\}/)
})
test('V43 mobile styling is scoped and desktop visual identity is unchanged',()=>{
 assert.match(css,/\.osa43-mobile-nav\s*\{\s*display:\s*none/)
 assert.match(css,/@media\s*\(max-width:\s*760px\)/)
 assert.match(css,/scroll-margin-top:\s*150px/)
 assert.match(css,/@media\s*\(prefers-reduced-motion:\s*reduce\)/)
 assert.doesNotMatch(css,/https?:\/\/|url\(/)
})
test('screening, media player and progress safeguards survive integration',()=>{
 assert.equal(viewer.split("<OSACinemaScreening ").length-1,1)
 assert.match(viewer,/getOSACinemaMedia\(index,locale,'video'\)/)
 assert.match(viewer,/saveOSACinemaProgress\(\{index,answers,locale,completed,selfChecks\}\)/)
 assert.doesNotMatch(component,/stripe|payment|invoice|publishNow/i)
})
