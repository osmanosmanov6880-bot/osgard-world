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

/**
 * R82: sample original SAME-SESSION WebGL frames while the real Godot
 * boot animation completes. A removed HTML #status does not imply that the
 * 3D world has painted. Never accept a logo, flat color, fake frame or a
 * second Playwright test attempt as gameplay.
 *
 * captureFrame MUST return the original Chromium compositor/canvas PNG
 * bytes, with the producing capture method. The caller applies its own
 * strict source-commit, viewport, controls and movement gates afterwards.
 */
export async function waitForRealGodotWorldFrame(captureFrame, {
  maxAttempts=24,
  maxWaitMs=80000,
  pauseMs=1800,
  now=()=>Date.now(),
  pause=ms=>new Promise(resolve=>setTimeout(resolve,ms))
}={}) {
  if(typeof captureFrame!=='function' || typeof now!=='function' || typeof pause!=='function' ||
     !Number.isSafeInteger(maxAttempts) || maxAttempts<1 || maxAttempts>30 ||
     !Number.isSafeInteger(maxWaitMs) || maxWaitMs<1000 || maxWaitMs>120000 ||
     !Number.isSafeInteger(pauseMs) || pauseMs<0 || pauseMs>10000)
    throw new Error('R82 requires finite original Godot startup capture bounds')
  const started=now()
  let last=null
  for(let attempt=1; attempt<=maxAttempts;attempt++) {
    const capture=await captureFrame()
    if(!Buffer.isBuffer(capture?.png) || typeof capture?.method!=='string' ||
       capture.method.length<3)
      throw new Error('Only original browser WebGL PNG bytes may count as game evidence')
    const worldProof=realGameFrameEvidence(capture.png)
    const elapsedMs=Math.max(0,now()-started)
    last={ready:worldProof.realWorldEdges, png:capture.png, worldProof,
      captureMethod:capture.method, attempts:attempt, elapsedMs}
    if(last.ready)return last
    if(attempt===maxAttempts || elapsedMs>=maxWaitMs)break
    const remainingMs=maxWaitMs-elapsedMs
    if(remainingMs>0)await pause(Math.min(pauseMs,remainingMs))
  }
  // The browser is still on loader/blank compositor after the finite budget.
  // Preserve the exact rejected bytes for QA diagnostics; fail at caller.
  return last
}
