import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { isNativeNebulaShell } from './native-nebula-shell-contract.mjs'

const html=readFileSync('public/games/remix/arena-v2/nebula-3d/index.html','utf8')
test('native Nebula shell including accessibility attributes passes',()=>{
  assert.match(html,/<canvas id="canvas" tabindex=/)
  assert.ok(isNativeNebulaShell(html))
  assert.ok(isNativeNebulaShell(html.replace('tabindex="0"','tabindex="0" role="application"')))
})
test('real Godot runtime and WebGL fallback must remain wired',()=>{
  for(const part of [
    '<title>REMIX ARENA - NEBULA 3D</title>',
    'new Engine(GODOT_CONFIG)',
    "document.documentElement.lang = 'ru'",
    'index.wasm', 'index.pck',
    "backLink.href = '/games/#catalog'",
    'Для запуска игры требуется WebGL 2.']){
    assert.equal(isNativeNebulaShell(html.replace(part,'intentionally missing')),false,'Missing essential part '+part)
  }
})
test('reject deceptive, disabled and missing canvas shells',()=>{
  assert.equal(isNativeNebulaShell('<canvas id="canvas"></canvas>'),false)
  assert.equal(isNativeNebulaShell(html.replace('id="canvas"','id="placeholder"')),false)
  assert.equal(isNativeNebulaShell(html.replace('<canvas id="canvas"','<canvas hidden id="canvas"')),false)
  assert.equal(isNativeNebulaShell(html.replace('<script src="index.js"></script>','')),false)
})
test('production route matrix actually calls the independent contract',()=>{
  const script=readFileSync('scripts/production-route-matrix.mjs','utf8')
  assert.ok(script.includes("import { isNativeNebulaShell } from './native-nebula-shell-contract.mjs'"))
  assert.ok(script.includes(": route.startsWith('/games/remix/arena-v2/nebula-3d/')\n          ? isNativeNebulaShell(text)"))
})
