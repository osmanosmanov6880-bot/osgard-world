import test from 'node:test'
import assert from 'node:assert/strict'
import {samplePanelPixels, PANEL_COLUMNS, PANEL_ROWS} from './omega-r33-panel-pixels.mjs'

// SYNTHETIC UNIT FIXTURES ONLY. These never qualify as gameplay/art evidence.
function generatedFrame(width, height, governorIsOpen) {
  const data = Buffer.alloc(width * height * 4)
  for (let y = 0; y < height; y++) {
    const py = (y + 0.5) / height
    for (let x = 0; x < width; x++) {
      const px = (x + 0.5) / width
      const at = (y * width + x) * 4
      let r = 112, g = 124, b = 145 // game world background fixture
      if (governorIsOpen && px >= 0.06 && px < 0.38 && py >= 0.23 && py < 0.78) {
        r = 15; g = 21; b = 30 // dark cabinet backdrop
      }
      if (governorIsOpen && px >= 0.10 && px < 0.21 &&
          py >= 0.27 && py < 0.29) {
        r = 220; g = 165; b = 72 // golden heading
      }
      data[at] = r; data[at + 1] = g; data[at + 2] = b; data[at + 3] = 255
    }
  }
  return {width, height, data}
}

test('same normalized rectangle gets exactly 11,000 samples from either genuine-size PNG', () => {
  const two = [[960, 540], [1366, 768]].map(([w,h]) =>
    samplePanelPixels(generatedFrame(w,h,true),0.06,0.38,0.23,0.78))
  assert.equal(PANEL_COLUMNS * PANEL_ROWS,11000)
  assert.equal(two[0].sampledPixels,two[1].sampledPixels)
  assert.ok(two[0].goldPixels > 50 && two[1].goldPixels > 50)
  assert.ok(Math.abs(two[0].goldPixels-two[1].goldPixels) < 25)
  assert.ok(Math.abs(two[0].darkRatio-two[1].darkRatio) < 0.02)
})

test('switching compositor size alone cannot invent panel gold or darkness', () => {
  for(const [w,h] of [[960,540],[1366,768]]) {
    const noPanel = samplePanelPixels(generatedFrame(w,h,false),0.06,0.38,0.23,0.78)
    assert.equal(noPanel.goldPixels,0)
    assert.equal(noPanel.sampledPixels,11000)
    assert.ok(noPanel.darkRatio < 0.05)
  }
})

test('a real panel change passes original golden-text and dark-backdrop thresholds', () => {
  const before = samplePanelPixels(generatedFrame(1366,768,false),0.06,0.38,0.23,0.78)
  const after = samplePanelPixels(generatedFrame(960,540,true),0.06,0.38,0.23,0.78)
  assert.ok(after.goldPixels > 50)
  assert.ok(after.goldPixels > before.goldPixels * 2 + 35)
  assert.ok(after.darkRatio > 0.35)
})

test('invalid screenshot bytes or sampling regions fail closed', () => {
  assert.throws(()=>samplePanelPixels({width:960,height:540,data:Buffer.alloc(8)},0.06,0.38,0.23,0.78),/Original RGBA/)
  assert.throws(()=>samplePanelPixels(generatedFrame(960,540,false),0.40,0.30,0.23,0.78),/Unsafe normalized/)
  assert.throws(()=>samplePanelPixels(generatedFrame(960,540,false),-0.1,0.30,0.23,0.78),/Unsafe normalized/)
})
