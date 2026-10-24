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

export async function captureAnimatedWebGLViewport(page) {
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
    // Fallback is still a REAL Chromium screenshot; never substitute an HTML,
    // static asset, generated reference or pass without pixel coverage checks.
    try {
      const png=await page.screenshot({timeout:35000,animations:'disabled'})
      if(!Buffer.isBuffer(png) || png.length<9500 ||
         png.subarray(0,8).toString('hex')!=='89504e470d0a1a0a')
        throw new Error('Fallback did not capture a real PNG viewport')
      return {png,method:'playwright-viewport',fallback_reason:String(firstError?.message??firstError).slice(0,200)}
    } catch(secondError) {
      throw new Error(
        'Neither authentic WebGL screenshot method worked: CDP='+
        String(firstError?.message??firstError)+'; Playwright='+String(secondError?.message??secondError)
      )
    }
  } finally {
    if(session) await session.detach().catch(()=>{})
  }
}
