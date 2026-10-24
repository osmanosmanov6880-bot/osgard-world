import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { mobileTouchCenters, browserTouchPoint } from './omega-mobile-touch-geometry.mjs'

const godot=readFileSync('godot/empire-omega/scripts/horizon_touch_controls.gd','utf8')
const browser=readFileSync('scripts/omega-live-webgl.spec.mjs','utf8')

test('actual R12 screenshot 390x844 targets CAR 259,702 rather than empty 304,750',()=>{
  const c=mobileTouchCenters(390,844)
  assert.deepEqual(c.enter_vehicle,{x:259,y:702})
  assert.deepEqual(c.move_forward,{x:337,y:786})
  assert.deepEqual(c.move_left,{x:53,y:786})
  assert.deepEqual(browserTouchPoint({x:0,y:0,width:390,height:844},'enter_vehicle'),{x:259,y:702})
  assert.ok(Math.hypot(304-c.enter_vehicle.x,750-c.enter_vehicle.y)>34,'former tap was outside the physical button')
})
test('all eight controls remain inside portrait viewport and non-overlapping',()=>{
  for(const [w,h] of [[290,410],[320,568],[360,740],[390,844],[430,932],[768,1024]]){
    const c=mobileTouchCenters(w,h)
    const scale=Math.max(.72,Math.min(1.12,Math.min(w/390,h/760)))
    const radius=44*scale*.74
    for(const [action,point] of Object.entries(c)){
      assert.ok(point.x>radius&&point.x<w-radius,action+' horizontal touch bounds')
      assert.ok(point.y>radius&&point.y<h-radius,action+' vertical touch bounds')
    }
    const entries=Object.entries(c)
    for(let i=0;i<entries.length;i++)for(let j=i+1;j<entries.length;j++)
      assert.ok(Math.hypot(entries[i][1].x-entries[j][1].x,entries[i][1].y-entries[j][1].y)>2*radius,
        'overlapping '+entries[i][0]+' and '+entries[j][0]+' at '+w+'x'+h)
  }
})
test('game itself retains same authoritative geometry and delivers discrete actions',()=>{
  for(const snippet of [
    'viewport_size.x/390.0','viewport_size.y/760.0','0.72,1.12',
    '53.0*scale_factor','78.0*scale_factor',
    'viewport_size.y-58.0*scale_factor','viewport_size.y-142.0*scale_factor',
    'var button: TouchScreenButton', 'const DISCRETE_ACTIONS = ["enter_vehicle","interact","pause_game"]',
    'button.pressed.connect(_relay_discrete_action.bind(action,true))',
    'Input.parse_input_event(event)'
  ])assert.ok(godot.includes(snippet),'Godot/browser contract drift: '+snippet)
  assert.ok(browser.includes('browserTouchPoint(bounds,\'enter_vehicle\')'))
  assert.ok(browser.includes('browserTouchPoint(bounds,\'move_forward\')'))
  assert.ok(browser.includes('browserTouchPoint(bounds,\'move_left\')'))
  assert.ok(!browser.includes('tap(304,750)'),'the old empty-space tap cannot return')
})
test('browser touch points track canvas offset and scale without fixed screen pixels',()=>{
  assert.deepEqual(browserTouchPoint({x:10,y:24,width:390,height:844},'enter_vehicle'),{x:269,y:726})
  assert.throws(()=>browserTouchPoint({x:0,y:0,width:390,height:844},'undefined'))
  assert.throws(()=>mobileTouchCenters(0,0))
})
