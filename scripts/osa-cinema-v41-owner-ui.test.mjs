import { test } from 'node:test'
import assert from 'node:assert/strict'
import { Script } from 'node:vm'
import { renderOwnerLogin, renderOwnerDesk } from './osa-cinema-v41-owner-ui.mjs'

const nonce='I3v41capturednonceABC123='
const csrf='a'.repeat(64)
const render=()=>renderOwnerDesk(nonce,csrf)
const banned=/(?:<iframe\b|<video\b|<audio\b|<img\b|<source\b|<form[^>]+action="(?!\/login)|https?:\/\/|id="publish"|id="pay"|<script[^>]+src=|onerror=|onclick=| style=")/i

test('V41 login is a real same-origin HTML form and does not load external resources',()=>{
  const h=renderOwnerLogin(nonce,csrf)
  assert.match(h,/<html lang="ru">/)
  assert.match(h,/<meta name="viewport"/)
  assert.match(h,new RegExp(`style nonce="${nonce.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')}"`))
  assert.match(h,new RegExp(`name="csrf" value="${csrf}"`))
  assert.match(h,/method="POST"/)
  assert.match(h,/action="\/login"/)
  assert.match(h,/name="password"/)
  assert.match(h,/autocomplete="current-password"/)
  assert.match(h,/minlength="16"/)
  assert.match(h,/OSA CINEMA/)
  assert.match(h,/Публичный показ и оплата запрещены/)
  assert.doesNotMatch(h,banned)
})

test('V41 dashboard reflects actual four private editions and seven external human gates without claiming publication',()=>{
  const h=render()
  for(const id of ['overview','audit','materials','approvals','historic','receipts','media','signatures','run','report','logout','result-tag','status-text','edition-1','edition-2','edition-3','edition-4'])
    assert.match(h,new RegExp(`id="${id}"`),id)
  assert.match(h,/Премьера начинается/)
  assert.match(h,/ПУБЛИЧНЫЙ ПОКАЗ И ОПЛАТА ЗАПРЕЩЕНЫ/)
  assert.equal((h.match(/class="gate-row"/g)||[]).length,7)
  assert.equal((h.match(/class="edition"/g)||[]).length,4)
  assert.match(h,/id="report"[^>]+hidden/)
  assert.match(h,/id="editions" data-state="idle"/)
  assert.match(h,/id="audit-steps" data-state="idle"/)
  assert.doesNotMatch(h,banned)
  assert.doesNotMatch(h,/\/(?:home|tmp|Users|mnt)\//)
})

test('V41 interactive browser code parses and only uses the existing authenticated V39 endpoints',()=>{
  const h=render()
  const script=h.match(/<script nonce="[^\"]+">([\s\S]*?)<\/script>/)?.[1]
  assert.ok(script)
  assert.doesNotThrow(()=>new Script(script))
  assert.match(script,new RegExp(`const csrf='${csrf}'`))
  for(const endpoint of ['/api/status','/api/run','/api/logout'])assert.ok(script.includes(endpoint),endpoint)
  assert.match(h,/href="\/api\/report"/)
  assert.match(script,/textContent=/)
  assert.match(script,/credentials:'same-origin'/)
  assert.match(script,/get\('report'\)\.hidden=!ok/)
  assert.doesNotMatch(script,/innerHTML|outerHTML|eval\(|WebSocket|localStorage|sessionStorage|location\.assign/)
  assert.doesNotMatch(script,/https?:\/\//)
})

test('V41 accessible responsive layouts and reduced motion work without unsafe inline styles',()=>{
  const h=render()
  assert.match(h,/<nav class="side-nav" aria-label="Разделы кабинета">/)
  assert.match(h,/role="status" aria-live="polite"/)
  assert.match(h,/@media\(max-width:560px\)/)
  assert.match(h,/@media\(prefers-reduced-motion:reduce\)/)
  assert.match(h,/:focus-visible/)
  assert.match(h,/button:disabled/)
  assert.doesNotMatch(h,/ style="/)
  assert.match(h,/OWNER WORKSPACE|WORKSPACE/)
})
