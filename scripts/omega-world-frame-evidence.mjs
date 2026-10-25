// Genuine WebGL canvas evidence must show the GAME, not the Godot splash.
// A flat #242424 startup background passes an obsolete >28 RGB coverage gate.
// This low-cost band test rejects that false green without inventing pixels.
import { PNG } from 'pngjs'

function bandLumaDeviation(png, start, stop) {
  if (!(png?.width > 0 && png?.height > 0 && png?.data)) {
    throw new Error('Original decoded game PNG is required')
  }
  const x0 = Math.floor(png.width * 0.05)
  const x1 = Math.max(x0 + 1, Math.ceil(png.width * 0.95))
  const y0 = Math.floor(png.height * start)
  const y1 = Math.max(y0 + 1, Math.ceil(png.height * stop))
  let count = 0, sum = 0, sumSq = 0
  for (let y = y0; y < y1; y += 4) {
    for (let x = x0; x < x1; x += 5) {
      const index = (y * png.width + x) * 4
      const luma = 0.2126 * png.data[index] +
                   0.7152 * png.data[index + 1] +
                   0.0722 * png.data[index + 2]
      sum += luma
      sumSq += luma * luma
      count += 1
    }
  }
  if (count < 8) throw new Error('Insufficient real rendered canvas samples')
  const mean = sum / count
  return Math.sqrt(Math.max(0, sumSq / count - mean * mean))
}

export function realGameFrameEvidence(rawPng) {
  if (!Buffer.isBuffer(rawPng) || rawPng.length < 100) {
    throw new Error('Original PNG bytes from active Godot canvas required')
  }
  const png = PNG.sync.read(rawPng)
  if (png.width < 160 || png.height < 160) {
    throw new Error('Authentic viewport smaller than expected')
  }
  // Real shipped HUD / street world has spatial detail near the top and
  // bottom of the viewport even when nighttime asphalt is very dark.
  // The Godot loader is flat here despite bright text/logo in the middle.
  const upperEdgeLumaStd = bandLumaDeviation(png, 0.00, 0.15)
  const lowerEdgeLumaStd = bandLumaDeviation(png, 0.90, 1.00)
  return {
    width: png.width,
    height: png.height,
    upperEdgeLumaStd,
    lowerEdgeLumaStd,
    realWorldEdges: upperEdgeLumaStd > 10 && lowerEdgeLumaStd > 10,
    method: 'original-rgba-upper-and-lower-viewport-spatial-deviation'
  }
}
