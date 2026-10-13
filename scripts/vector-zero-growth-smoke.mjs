import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'

const html=readFileSync(new URL('../public/games/vector-zero/index.html',import.meta.url),'utf8')
const manifest=readFileSync(new URL('../src/core/manifest.ts',import.meta.url),'utf8')
const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(m=>m[1])
assert.equal(new Set(ids).size,ids.length,'DOM ids must be unique')
const scripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].map(m=>m[1]).filter(s=>s.trim())
assert.equal(scripts.length,1,'game remains self-contained')
new vm.Script(scripts[0],{filename:'vector-zero-inline.js'})
const refs=[...scripts[0].matchAll(/\$\('([^']+)'\)/g)].map(m=>m[1])
assert.deepEqual([...new Set(refs.filter(id=>!ids.includes(id)))],[],'every direct DOM lookup must have a matching element')
assert.ok(html.includes('id="objective-status"'),'portal readiness probe must find objective-status')
assert.ok(!html.includes('ctx.setTransform'),'resize must use the actual canvas context')
assert.ok(scripts[0].includes('const challengeDate=')&&scripts[0].includes('function stableHash('),'daily challenge target must be deterministic')
assert.ok(scripts[0].includes('const dailyTarget=Number((9+(challengeSeed%61)/10).toFixed(1))'),'daily target should remain in the testable 9–15 second range')
assert.ok(html.includes('osgard.core.events.pending.v1'),'growth events must use the first-party local queue')
assert.ok(scripts[0].includes("localStorage.getItem('osgard.games.analytics-consent.v1')==='yes'")&&scripts[0].includes("localStorage.getItem('osgard.auth.accessToken')||''"),'event queue writes must require explicit analytics consent and an authenticated player')
for(const event of ['game_opened','game_session_started','game_session_completed','score_submitted','challenge_created','challenge_invite_accepted','share_created','share_link_copied','share_dialog_opened','partner_cta_clicked','result_card_exported'])assert.ok(manifest.includes("'"+event+"'"),'missing manifest event: '+event)
assert.ok(html.includes('navigator.share')&&html.includes('id="share-result"')&&html.includes('id="save-card"'),'result sharing and PNG export must exist')
assert.ok(html.includes('vector_zero_sponsor'),'sponsor CTA must be attributable')
assert.ok(!/<script\b[^>]*\bsrc\s*=/i.test(html),'game must not add third-party scripts')
console.log('PASS VECTOR//ZERO growth smoke: syntax, IDs, readiness, daily seed, events, share, result card, sponsor lead, no third-party scripts')
