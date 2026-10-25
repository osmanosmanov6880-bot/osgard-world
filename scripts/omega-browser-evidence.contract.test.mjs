import test from 'node:test'
import assert from 'node:assert/strict'
import {
  releaseMatches,
  waitForExactPublishedRelease,
  captureAnimatedWebGLViewport,
  captureRealChromiumScreencast
} from './omega-browser-evidence.mjs'

const expected={
  engine:'Godot 4.4.1',native_tests:'passed',artifact_kind:'native-Godot-HTML5-export',
  source_path:'godot/empire-omega',source_commit:'a'.repeat(40),
  files:{'index.html':'1'.repeat(64),'index.wasm':'2'.repeat(64),'index.pck':'3'.repeat(64)}
}
const stale={...expected,source_commit:'b'.repeat(40)}
const corrupted={...expected,files:{...expected.files,'index.wasm':'f'.repeat(64)}}

function requestStub(sequence){
  let index=0
  const seen=[]
  return {
    seen,
    async get(url,options) {
      seen.push({url,options})
      const next=sequence[Math.min(index++,sequence.length-1)]
      if(next instanceof Error) throw next
      return {status:()=>next.status??200,json:async()=>next.manifest??next}
    }
  }
}

test('never accept source SHA mismatch, tampered binary or missing manifest',()=>{
  assert.equal(releaseMatches(expected,expected),true)
  assert.equal(releaseMatches(expected,stale),false)
  assert.equal(releaseMatches(expected,corrupted),false)
  assert.equal(releaseMatches(expected,undefined),false)
  assert.equal(releaseMatches(expected,{...expected,files:{'index.html':'1'.repeat(64)}}),false)
})

test('a temporarily stale public CDN becomes valid only after byte-exact manifest',async()=>{
  const request=requestStub([stale,corrupted,expected])
  const r=await waitForExactPublishedRelease(request,'https://osgard.world/games/omega-3d-preview/release.json',expected,'test',{attempts:3,delayMs:0})
  assert.equal(r.manifest.source_commit,expected.source_commit)
  assert.equal(r.observations.length,3)
  assert.deepEqual(r.observations.map(x=>x.matched),[false,false,true])
  assert.equal(request.seen.length,3)
  assert.ok(request.seen.every(x=>x.options.headers['Cache-Control']==='no-cache'))
  assert.notEqual(request.seen[0].url,request.seen[1].url)
})

test('all mismatched public versions still fail closed after bounded retries',async()=>{
  const request=requestStub([stale,{status:503},new Error('network'),corrupted])
  await assert.rejects(
    waitForExactPublishedRelease(request,'https://osgard.world/games/omega-3d-preview/release.json',expected,'test',{attempts:4,delayMs:0}),
    /never treating a stale build as success/
  )
  assert.equal(request.seen.length,4)
})

test('invalid/unbounded publication wait configuration rejected',async()=>{
  const request=requestStub([expected])
  await assert.rejects(waitForExactPublishedRelease(request,'url',expected,'q',{attempts:0}),/Invalid bounded/)
  await assert.rejects(waitForExactPublishedRelease(request,'url',expected,'q',{attempts:100}),/Invalid bounded/)
  await assert.rejects(waitForExactPublishedRelease(request,'url',expected,'q',{delayMs:-1}),/Invalid bounded/)
})

const pixel=Buffer.alloc(10000)
Buffer.from('89504e470d0a1a0a','hex').copy(pixel)

test('R53 authentic CDP screencast resolves only on real PNG frame event and ACKs it',async()=>{
  const events=new Map()
  const seen=[]
  let detached=0
  const session={
    on(name,callback){events.set(name,callback)},
    off(name,callback){assert.equal(events.get(name),callback);events.delete(name)},
    async send(method,args){
      seen.push(method)
      if(method==='Page.startScreencast'){
        assert.deepEqual(args,{format:'png',everyNthFrame:1})
        queueMicrotask(()=>events.get('Page.screencastFrame')?.({
          data:pixel.toString('base64'),sessionId:42
        }))
      }
      if(method==='Page.screencastFrameAck')assert.equal(args.sessionId,42)
      return {}
    },
    async detach(){detached++}
  }
  const actual=await captureRealChromiumScreencast(session,450)
  assert.equal(actual.method,'chromium-cdp-screencast')
  assert.deepEqual(actual.png,pixel)
  assert.ok(seen.includes('Page.screencastFrameAck'))
  assert.ok(seen.includes('Page.stopScreencast'))
  assert.equal(events.size,0)
  const page={context:()=>({newCDPSession:async()=>session})}
  const main=await captureAnimatedWebGLViewport(page)
  assert.equal(main.method,'chromium-cdp-screencast')
  assert.equal(detached,1)
  assert.equal(seen.filter(x=>x==='Page.captureScreenshot').length,0)
})

test('R53 rejects bogus CDP screencast, cannot mark a missing scene PASS',async()=>{
  const events=new Map()
  const send=[]
  const session={
    on(name,callback){events.set(name,callback)},
    off(name,callback){events.delete(name)},
    async send(method){
      send.push(method)
      if(method==='Page.startScreencast')
        queueMicrotask(()=>events.get('Page.screencastFrame')?.({
          sessionId:7,data:Buffer.from('not a real render').toString('base64')
        }))
      return {}
    }
  }
  await assert.rejects(captureRealChromiumScreencast(session,150),/timed out/)
  assert.ok(send.includes('Page.stopScreencast'))
  assert.equal(events.size,0)
})

test('R53 refuses CDP sessions without a real streaming event API',async()=>{
  await assert.rejects(captureRealChromiumScreencast({send:async()=>({})},150),/unavailable/)
  await assert.rejects(captureRealChromiumScreencast({on:()=>{},send:async()=>({})},20000),/Unbounded/)
})

test('CDP capture is preferred for actual animated Chromium viewport',async()=>{
  let detached=0,sent=''
  const page={context:()=>({newCDPSession:async()=>({
    send:async(name)=>{sent=name;return {data:pixel.toString('base64')}},
    detach:async()=>{detached++}
  })})}
  const r=await captureAnimatedWebGLViewport(page)
  assert.equal(r.method,'chromium-cdp')
  assert.equal(sent,'Page.captureScreenshot')
  assert.equal(r.png.length,10000)
  assert.equal(detached,1)
})

test('R51 selects genuine non-surface CDP viewport after SwiftShader GPU surface stalls',async()=>{
  let first=0,second=0,detached=0
  const page={context:()=>({newCDPSession:async()=>({
    send:async(method,options)=>{
      assert.equal(method,'Page.captureScreenshot')
      if(options.fromSurface===true){first++;throw new Error('GPU compositor stall')}
      assert.equal(options.fromSurface,false)
      second++
      return {data:pixel.toString('base64')}
    },
    detach:async()=>{detached++}
  })})}
  const result=await captureAnimatedWebGLViewport(page)
  assert.equal(result.method,'chromium-cdp-view')
  assert.match(result.fallback_reason,/GPU compositor stall/)
  assert.equal(first,1)
  assert.equal(second,1)
  assert.equal(detached,1)
  assert.deepEqual(result.png,pixel)
})

test('R51 rejects fake CDP viewport instead of passing a failed WebGL game',async()=>{
  let second=0
  const page={
    context:()=>({newCDPSession:async()=>({
      send:async(method,opts)=>{
        if(opts.fromSurface===false){second++;return {data:Buffer.from('fake HTML').toString('base64')}}
        throw new Error('GPU surface blocked')
      },
      detach:async()=>{}
    })}),
    screenshot:async()=>Buffer.from('DOM mock, not a PNG')
  }
  await assert.rejects(captureAnimatedWebGLViewport(page),/No authentic WebGL pixels could be captured/)
  assert.equal(second,1)
})

test('only a genuine Playwright PNG is an allowed CDP fallback',async()=>{
  let detached=0
  const page={
    context:()=>({newCDPSession:async()=>({
      send:async()=>{throw new Error('SwiftShader CDP capture unavailable')},
      detach:async()=>{detached++}
    })}),
    screenshot:async()=>Buffer.from(pixel)
  }
  const r=await captureAnimatedWebGLViewport(page)
  assert.equal(r.method,'playwright-viewport')
  assert.match(r.fallback_reason,/CDP capture unavailable/)
  assert.equal(detached,1)
})

test('failed CDP and invalid fallback fail, never create fake screenshot',async()=>{
  const page={
    context:()=>({newCDPSession:async()=>({
      send:async()=>{throw new Error('No image')},
      detach:async()=>{}
    })}),
    screenshot:async()=>Buffer.from('not a png')
  }
  await assert.rejects(captureAnimatedWebGLViewport(page),/No authentic WebGL pixels could be captured/)
})

test('canvas readback captures actual animated Godot pixels if CDP freezes',async()=>{
  const page={
    context:()=>({newCDPSession:async()=>({
      send:async()=>{throw new Error('GPU screenshot blocked')},
      detach:async()=>{}
    })}),
    evaluate:async(callback)=>{
      assert.equal(typeof callback,'function')
      return 'data:image/png;base64,'+pixel.toString('base64')
    },
    screenshot:async()=>{throw new Error('Playwright screenshot should not be used')}
  }
  const result=await captureAnimatedWebGLViewport(page)
  assert.equal(result.method,'chromium-canvas-readback')
  assert.match(result.fallback_reason,/GPU screenshot blocked/)
  assert.deepEqual(result.png,pixel)
})

test('black/invalid canvas readback never counts as verified image',async()=>{
  const page={
    context:()=>({newCDPSession:async()=>({
      send:async()=>{throw new Error('CDP not responding')},
      detach:async()=>{}
    })}),
    evaluate:async()=>{throw new Error('Actual WebGL readback stayed dark')},
    screenshot:async()=>Buffer.from('placeholder HTML, not pixels')
  }
  await assert.rejects(captureAnimatedWebGLViewport(page),/No authentic WebGL pixels could be captured.*readback stayed dark/)
})

test('R74 large desktop uses bounded ORIGINAL CDP compositor pixels, never scales the live Godot page',async()=>{
  const events=new Map(),methods=[]
  const session={
    on(name,callback){events.set(name,callback)},
    off(name){events.delete(name)},
    async send(name,args){
      methods.push({name,args})
      if(name==='Page.startScreencast'){
        assert.deepEqual(args,{format:'png',everyNthFrame:1,maxWidth:960,maxHeight:540})
        queueMicrotask(()=>events.get('Page.screencastFrame')?.({
          sessionId:5,data:pixel.toString('base64')
        }))
      }
      return {}
    },
    async detach(){}
  }
  const page={viewportSize:()=>({width:1366,height:768}),
    context:()=>({newCDPSession:async()=>session})}
  const proof=await captureAnimatedWebGLViewport(page)
  assert.equal(proof.method,'chromium-cdp-screencast')
  assert.deepEqual(proof.png,pixel)
  assert.equal(methods.some(x=>x.name==='Page.captureScreenshot'),false)
  assert.equal(events.size,0)
  assert.deepEqual(page.viewportSize(),{width:1366,height:768})
})

test('R74 mobile portrait screenshot remains full resolution without hidden resampling',async()=>{
  const events=new Map()
  const session={
    on(name,fn){events.set(name,fn)},
    off(name){events.delete(name)},
    async send(name,args){
      if(name==='Page.startScreencast'){
        assert.deepEqual(args,{format:'png',everyNthFrame:1})
        queueMicrotask(()=>events.get('Page.screencastFrame')?.({
          sessionId:8,data:pixel.toString('base64')
        }))
      }
      return {}
    },
    async detach(){}
  }
  const page={viewportSize:()=>({width:390,height:844}),
    context:()=>({newCDPSession:async()=>session})}
  assert.equal((await captureAnimatedWebGLViewport(page)).method,'chromium-cdp-screencast')
})

test('R74 rejects unsafe compositor dimension arguments',async()=>{
  const bogus={on(){},send:async()=>({})}
  await assert.rejects(captureRealChromiumScreencast(bogus,150,{maxWidth:99999}),/Invalid bounded/)
  await assert.rejects(captureRealChromiumScreencast(bogus,150,{maxHeight:0}),/Invalid bounded/)
  await assert.rejects(captureRealChromiumScreencast(bogus,150,{badKey:5}),/Invalid bounded/)
})
