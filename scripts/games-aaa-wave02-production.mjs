// OSGARD WAVE 02 public HTTPS verification — no browser mock data.
const base=(process.env.OSGARD_BASE_URL||'https://osgard.world').replace(/\/$/,'')
const expected=22
function verify(test,message){if(!test)throw Error(message)}
async function get(path){
 const url=new URL(path,base)
 url.searchParams.set('osgard_wave02_release_probe',String(Date.now()))
 const response=await fetch(url,{headers:{'cache-control':'no-cache','user-agent':'OSGARD-WAVE02-22-world-live'},signal:AbortSignal.timeout(20000)})
 return response
}
const catalog=await get('/games/')
verify(catalog.status===200,'Catalog failed: HTTP '+catalog.status)
const catalogText=await catalog.text()
verify(catalogText.includes('href="./world-artwork.css"'),'Published catalogue missing WAVE 02 stylesheet')
verify(catalogText.includes('class="world-emblem"'),'Published catalogue missing world emblems')
const tracker=await get('/games/roadmap/')
verify(tracker.status===200,'Interactive tracker failed: HTTP '+tracker.status)
verify((await tracker.text()).includes('data-wave-filter="completed"'),'Interactive roadmap markup missing')
const manifestRes=await get('/games/aaa-roadmap.v1.json')
verify(manifestRes.status===200,'Roadmap manifest failed: HTTP '+manifestRes.status)
verify((manifestRes.headers.get('content-type')||'').includes('json'),'Roadmap served with invalid content type')
const manifest=await manifestRes.json()
verify(manifest.schemaVersion===1&&manifest.games.length===expected,'Expected exactly 22 registered games')
verify(manifest.waves.length===11,'Expected 11 evidence-gated implementation waves')
verify(manifest.waves.find(w=>w.id==='02').state!=='completed','Unverified WAVE 02 must not be marked complete')
const paths=[...new Set(manifest.games.flatMap(g=>[g.icon,g.coverSmall]))]
let next=0
const results=new Array(paths.length)
await Promise.all(Array.from({length:4},async()=>{
 while(next<paths.length){
  const index=next++,path=paths[index]
  try{
   verify(path.startsWith('/games/icons/')||path.startsWith('/brand/'),'Asset outside expected owned paths: '+path)
   const response=await get(path)
   const type=(response.headers.get('content-type')||'').toLowerCase()
   const ok=response.status===200&&(path.endsWith('.svg')?type.includes('svg'):type.includes('image/webp'))
   const body=await response.arrayBuffer()
   const enough=body.byteLength>(path.endsWith('.svg')?200:1000)
   results[index]={path,status:response.status,type,bytes:body.byteLength,ok:ok&&enough}
  }catch(error){results[index]={path,status:0,ok:false,error:String(error)}}
 }
}))
const failed=results.filter(r=>!r.ok)
const report={status:failed.length?'FAIL':'PASS',verifiedAt:new Date().toISOString(),base,worlds:manifest.games.length,assets:paths.length,passed:paths.length-failed.length,failed:failed.length,errors:failed}
console.log(JSON.stringify(report,null,2))
if(failed.length)process.exitCode=1
