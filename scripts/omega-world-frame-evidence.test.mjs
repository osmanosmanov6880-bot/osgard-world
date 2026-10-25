import test from 'node:test'
import assert from 'node:assert/strict'
import { PNG } from 'pngjs'
import { realGameFrameEvidence } from './omega-world-frame-evidence.mjs'

function frame(fill = [36, 36, 36], width = 320, height = 240) {
  const png = new PNG({width, height})
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4
      png.data[i] = fill[0]
      png.data[i+1] = fill[1]
      png.data[i+2] = fill[2]
      png.data[i+3] = 255
    }
  }
  return png
}

function fillRect(png, x0, y0, x1, y1, color) {
  for (let y = y0; y < y1; y++) {
    for (let x = x0; x < x1; x++) {
      const i = (y * png.width + x) * 4
      for (let j = 0; j < 3; j++) png.data[i+j] = color[j]
    }
  }
}

test('regression: a flat Godot loader looks bright enough to an obsolete >28 coverage gate, but is NOT a rendered city', () => {
  const png = frame()
  // A centered logo and progress bar must not make the flat loading
  // background pass the authentic world view even on a desktop viewport.
  fillRect(png, 80, 60, 240, 165, [70, 145, 190])
  fillRect(png, 75, 195, 245, 198, [30, 130, 245])
  const proof = realGameFrameEvidence(PNG.sync.write(png))
  assert.equal(proof.width, 320)
  assert.equal(proof.upperEdgeLumaStd, 0)
  assert.equal(proof.lowerEdgeLumaStd, 0)
  assert.equal(proof.realWorldEdges, false)
})

test('authentic distributed world plus visible top/bottom Godot HUD supports genuine daytime or dim night scene', () => {
  const png = frame([8, 10, 14])
  fillRect(png, 0, 0, 115, 34, [190, 180, 130])
  fillRect(png, 210, 0, 319, 34, [60, 90, 140])
  fillRect(png, 0, 218, 105, 240, [190, 180, 120])
  fillRect(png, 190, 218, 319, 240, [70, 92, 140])
  const proof = realGameFrameEvidence(PNG.sync.write(png))
  assert.ok(proof.upperEdgeLumaStd > 10)
  assert.ok(proof.lowerEdgeLumaStd > 10)
  assert.equal(proof.realWorldEdges, true)
})

test('invalid, non-PNG and tiny canvases cannot fabricate world evidence', () => {
  assert.throws(() => realGameFrameEvidence(Buffer.from('fake')), /Original PNG/)
  assert.throws(() => realGameFrameEvidence(PNG.sync.write(frame([5, 5, 5], 80, 80))), /smaller/)
})
