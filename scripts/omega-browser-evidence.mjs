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

// R53: ask Chromium for an actual asynchronously painted compositor frame
// BEFORE trying expensive synchronous screenshot commands that can freeze
// SwiftShader on a 1366x768 running WebGL2 scene. Unlike an HTML image
// mock this only accepts an original Page.screencastFrame PNG payload.
export async function captureRealChromiumScreencast(session, timeoutMs=11500) {
  if(typeof session?.on!=='function' || typeof session?.send!=='function')
    throw new Error('Real Chromium CDP screencast session unavailable')
  if(!Number.isSafeInteger(timeoutMs)||timeoutMs<100||timeoutMs>18000)
    throw new Error('Unbounded CDP screencast request')
  let handler=null,timer=null,started=false
  let resolveFrame,rejectFrame
  const framePromise=new Promise((resolve,reject)=>{resolveFrame=resolve;rejectFrame=reject})
  try {
    handler=async packet=>{
      // ACK real CDP frames to prevent the GPU queue from blocking.
      if(Number.isInteger(packet?.sessionId))
        session.send('Page.screencastFrameAck',{sessionId:packet.sessionId}).catch(()=>{})
      if(typeof packet?.data!=='string')return
      const pixels=Buffer.from(packet.data,'base64')
      if(pixels.length>9500 && pixels.subarray(0,8).toString('hex')==='89504e470d0a1a0a')
        resolveFrame({png:pixels,method:'chromium-cdp-screencast'})
    }
    session.on('Page.screencastFrame',handler)
    timer=setTimeout(()=>rejectFrame(new Error('Authentic CDP screencast frame timed out')),timeoutMs)
    // The server may emit Page.screencastFrame before this command resolves.
    // Bound both command and frame by the same timer.
    const startPromise=session.send('Page.startScreencast',{
      format:'png',everyNthFrame:1
    })
    const result=await Promise.race([
      framePromise,
      startPromise.then(()=>framePromise),
      startPromise.then(()=>null,err=>{throw err})
    ])
    started=true
    if(!result || result.method!=='chromium-cdp-screencast')
      throw new Error('No authentic live Chromium screenshot pixels')
    return result
  } finally {
    if(timer!==null)clearTimeout(timer)
    if(handler){
      if(typeof session.off==='function')session.off('Page.screencastFrame',handler)
      else if(typeof session.removeListener==='function')session.removeListener('Page.screencastFrame',handler)
    }
    // A failed start may still have turned the CDP stream on. This cleanup
    // never waits for a broken renderer and does not manufacture a frame.
    if(typeof session.send==='function' && typeof session.on==='function')
      session.send('Page.stopScreencast').catch(()=>{})
  }
}

export async function captureAnimatedWebGLViewport(page) {
  // Unlike locator screenshots, CDP does not wait for a continuously painted
  // WebGL canvas to reach the impossible "stable element" state.
  let session=null
  try {
    session=await page.context().newCDPSession(page)
    let screencastError=null
    try {
      // Prefer compositor's streamed real frames on slow software GPU.
      return await captureRealChromiumScreencast(session)
    } catch(error) {
      screencastError=error
    }
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
    // R51: On Linux SwiftShader, Chrome's GPU compositor sometimes never
    // finishes 'fromSurface:true'. Request the ACTUAL renderer's view via
    // CDP's distinct fromSurface:false path before expensive canvas readback.
    // This still photographs the active Chromium page, never HTML or a fake
    // asset; the calling game test verifies brightness and real car movement.
    let alternativeError=null
    try {
      let alternateTimer
      let image
      try {
        image=await Promise.race([
          session.send('Page.captureScreenshot',{
            format:'png',captureBeyondViewport:false,fromSurface:false
          }),
          new Promise((_,reject)=>{
            alternateTimer=setTimeout(()=>reject(new Error('CDP view screenshot timed out')),11000)
          })
        ])
      } finally {
        if(alternateTimer!==undefined)clearTimeout(alternateTimer)
      }
      const pixels=Buffer.from(image.data,'base64')
      if(pixels.length<9500 || pixels.subarray(0,8).toString('hex')!=='89504e470d0a1a0a')
        throw new Error('CDP view screenshot has no authentic PNG pixels')
      return {png:pixels,method:'chromium-cdp-view',
        fallback_reason:String(firstError?.message??firstError).slice(0,200)}
    } catch(error) {
      alternativeError=error
    }
    // Try real Godot canvas readback before Playwright screenshot. If the
    // framebuffer is blank/unreadable this fails, never inventing evidence.
    let canvasError
    try {
      const result=await captureLiveGodotCanvas(page)
      return {...result,fallback_reason:('CDP='+String(firstError?.message??firstError)+
        '; View='+String(alternativeError?.message??alternativeError)).slice(0,240)}
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
        'No authentic WebGL pixels could be captured: CDP='+
        String(firstError?.message??firstError)+'; CDP View='+
        String(alternativeError?.message??alternativeError)+'; Canvas='+
        String(canvasError?.message??canvasError)+'; Playwright='+
        String(secondError?.message??secondError)
      )
    }
  } finally {
    if(session) await session.detach().catch(()=>{})
  }
}
