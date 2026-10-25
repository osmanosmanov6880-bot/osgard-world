// Release-synchronised Chromium checks without accepting an older WASM/PCK.
// The public CDN can swap manifests while Actions jobs start. Wait only for
// the EXACT release this test was built from, with a finite deadline.
const MAX_ATTEMPTS = 10

export function releaseMatches(expected, live) {
  if (!expected || !live || typeof live !== 'object') return false
  for (const key of ['engine','native_tests','artifact_kind','source_path','source_commit']) {
    if (live[key] !== expected[key]) return false
  }
  const a=expected.files, b=live.files
  if (!a || !b || typeof a !== 'object' || typeof b !== 'object') return false
  const keys=Object.keys(a).sort()
  return keys.length===Object.keys(b).length && keys.every(key=>b[key]===a[key])
}

export async function waitForExactPublishedRelease(request, url, expected, nonce, options={}) {
  const attempts=options.attempts??MAX_ATTEMPTS
  const delayMs=options.delayMs??3000
  if (!Number.isSafeInteger(attempts) || attempts<1 || attempts>20 ||
      !Number.isSafeInteger(delayMs) || delayMs<0 || delayMs>10000)
    throw new Error('Invalid bounded CDN publication wait')
  const observations=[]
  for (let attempt=1;attempt<=attempts;attempt++) {
    let live=null, error=null, status=null
    try {
      const separator=url.includes('?')?'&':'?'
      const response=await request.get(url+separator+'omega_verify='+encodeURIComponent(nonce+'_'+attempt),{
        timeout:12000,
        headers:{'Cache-Control':'no-cache','Pragma':'no-cache'}
      })
      status=response.status()
      if(status===200)live=await response.json()
      else error='HTTP '+status
    } catch(e) {
      error=String(e?.message??e).slice(0,150)
    }
    observations.push({attempt,status,source_commit:live?.source_commit??null,matched:releaseMatches(expected,live),error})
    if (releaseMatches(expected,live)) return {manifest:live,observations}
    if (attempt<attempts && delayMs) await new Promise(resolve=>setTimeout(resolve,delayMs))
  }
  throw new Error(
    'Exact Godot public release unavailable (never treating a stale build as success). '+
    'expected='+expected.source_commit+'; observed='+JSON.stringify(observations)
  )
}

// Last-resort, renderer-independent collection of pixels from the ACTUAL live
// Godot WebGL canvas. Never use DOM screenshots, snapshots or synthetic media.
async function captureLiveGodotCanvas(page) {
  if (typeof page.evaluate !== 'function') throw new Error('Canvas readback unavailable')
  let timeoutId
  try {
    const dataUrl=await Promise.race([
      page.evaluate(async()=>{
        const source=document.querySelector('#canvas')
        if (!(source instanceof HTMLCanvasElement) || source.width<160 || source.height<160)
          throw new Error('Real Godot canvas unavailable')
        const copy=document.createElement('canvas')
        copy.width=source.width
        copy.height=source.height
        const ctx=copy.getContext('2d',{willReadFrequently:true})
        if (!ctx) throw new Error('Canvas 2D readback unsupported')
        // Chromium SwiftShader may not have finished the current compositor
        // frame, so inspect at most four real animation frames.
        for (let trial=0;trial<4;trial++) {
          await new Promise(resolve=>requestAnimationFrame(resolve))
          ctx.clearRect(0,0,copy.width,copy.height)
          ctx.drawImage(source,0,0)
          const data=ctx.getImageData(0,0,copy.width,copy.height).data
          let bright=0,samples=0
          const yStep=Math.max(4,Math.floor(copy.height/36))
          const xStep=Math.max(4,Math.floor(copy.width/36))
          for(let y=Math.floor(copy.height*0.10);y<Math.floor(copy.height*0.90);y+=yStep) {
            for(let x=Math.floor(copy.width*0.25);x<Math.floor(copy.width*0.75);x+=xStep) {
              const pos=(y*copy.width+x)*4
              samples++
              if(Math.max(data[pos],data[pos+1],data[pos+2])>28)bright++
            }
          }
          if(bright>=Math.max(12,Math.ceil(samples*0.10))) return copy.toDataURL('image/png')
        }
        throw new Error('Actual WebGL readback stayed dark; no valid pixels')
      }),
      new Promise((_,reject)=>{
        timeoutId=setTimeout(()=>reject(new Error('Canvas readback timed out')),12000)
      })
    ])
    if(typeof dataUrl!=='string' || !dataUrl.startsWith('data:image/png;base64,'))
      throw new Error('Browser did not return PNG from real WebGL canvas')
    const png=Buffer.from(dataUrl.slice('data:image/png;base64,'.length),'base64')
    if(png.length<9500 || png.subarray(0,8).toString('hex')!=='89504e470d0a1a0a')
      throw new Error('Real WebGL canvas capture is not a valid PNG')
    return {png,method:'chromium-canvas-readback'}
  } finally {
    if(timeoutId!==undefined)clearTimeout(timeoutId)
  }
}

// Chromium's compositor screenshot and canvas readback can BOTH stall under
// heavy software WebGL on CI desktop. An actual CDP screencast supplies
// asynchronously painted compositor PNG frames, without DOM mocks, black
// placeholder images or a pass-on-timeout. The caller still validates pixels,
// viewport coverage and real keyboard/touch-driven scene motion.
async function boundedCapture(promise, milliseconds, label) {
  let timer=null
  try {
    return await Promise.race([
      promise,
      new Promise((_,reject)=>{
        timer=setTimeout(()=>reject(new Error(label+' timed out')),milliseconds)
      })
    ])
  } finally {
    if(timer!==null)clearTimeout(timer)
  }
}

export async function captureAuthenticCDPScreencast(page) {
  const session=await boundedCapture(
    page.context().newCDPSession(page),8000,'CDP screencast connection'
  )
  let done=false
  try {
    const result=new Promise(resolve=>{
      session.on('Page.screencastFrame',frame=>{
        // Explicit acknowledgement keeps the live compositor sending frames;
        // these bytes are from the running browser renderer, never generated.
        session.send('Page.screencastFrameAck',{sessionId:frame.sessionId}).catch(()=>{})
        if(done)return
        const png=Buffer.from(frame.data||'','base64')
        if(png.length<9500||png.subarray(0,8).toString('hex')!=='89504e470d0a1a0a')
          return
        done=true
        resolve({png,method:'chromium-cdp-screencast'})
      })
    })
    await boundedCapture(
      session.send('Page.startScreencast',{format:'png',everyNthFrame:1}),
      8000,'CDP startScreencast'
    )
    return await boundedCapture(result,12000,'real Godot compositor frame')
  } finally {
    done=true
    // A wedged GPU process must not stall job cleanup indefinitely.
    await boundedCapture(session.send('Page.stopScreencast').catch(()=>{}),1500,
      'CDP stopScreencast').catch(()=>{})
    await boundedCapture(session.detach().catch(()=>{}),1500,
      'CDP screencast detach').catch(()=>{})
  }
}

export async function captureAnimatedWebGLViewport(page) {
  // Prefer a real asynchronous compositor frame. Unlike a synchronous
  // screenshot, this does not block on a continuously repainting Godot canvas.
  // If no authentic PNG arrives, do NOT pass: retain all original strict
  // screenshot/readback fallbacks and fail closed.
  let screencastError
  try {
    return await captureAuthenticCDPScreencast(page)
  } catch(e) {
    screencastError=e
  }
  // Unlike locator screenshots, CDP does not wait for a continuously painted
  // WebGL canvas to reach the impossible "stable element" state.
  let session=null
  try {
    session=await page.context().newCDPSession(page)
    let timeoutId=null
    let encoded
    try {
      encoded=await Promise.race([
        session.send('Page.captureScreenshot',{
          format:'png',
          captureBeyondViewport:false,
          fromSurface:true
        }),
        new Promise((_,reject)=>{
          timeoutId=setTimeout(()=>reject(new Error('CDP screenshot timed out')),20000)
        })
      ])
    } finally {
      if(timeoutId!==null)clearTimeout(timeoutId)
    }
    const bytes=Buffer.from(encoded.data,'base64')
    if(bytes.length<9500 || bytes.subarray(0,8).toString('hex')!=='89504e470d0a1a0a') {
      throw new Error('CDP did not capture a real PNG viewport')
    }
    return {png:bytes,method:'chromium-cdp'}
  } catch(firstError) {
    // Try real Godot canvas readback before Playwright screenshot. If the
    // framebuffer is blank/unreadable this fails, never inventing evidence.
    let canvasError
    try {
      const result=await captureLiveGodotCanvas(page)
      return {...result,fallback_reason:String(firstError?.message??firstError).slice(0,200)}
    } catch(e) {canvasError=e}
    try {
      const png=await page.screenshot({timeout:35000,animations:'disabled'})
      if(!Buffer.isBuffer(png) || png.length<9500 ||
         png.subarray(0,8).toString('hex')!=='89504e470d0a1a0a')
        throw new Error('Fallback did not capture a real PNG viewport')
      return {png,method:'playwright-viewport',
        fallback_reason:('CDP='+String(firstError?.message??firstError)+
          '; Canvas='+String(canvasError?.message??canvasError)).slice(0,250)}
    } catch(secondError) {
      throw new Error(
        'No authentic WebGL pixels could be captured: Screencast='+
        String(screencastError?.message??screencastError)+'; CDP='+
        String(firstError?.message??firstError)+'; Canvas='+
        String(canvasError?.message??canvasError)+'; Playwright='+
        String(secondError?.message??secondError)
      )
    }
  } finally {
    if(session) await session.detach().catch(()=>{})
  }
}
