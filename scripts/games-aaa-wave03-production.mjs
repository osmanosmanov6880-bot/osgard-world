// Live WAVE03 proof: the shared game session UX is actually published, not only compiled.
const base=(process.env.OSGARD_BASE_URL||'https://osgard.world').replace(/\/$/,'')
const expected=['/games/','/games/player-experience.mjs','/games/player-session-core.mjs','/games/player-experience.css','/games/aaa-roadmap.v1.json']
const results=[]
for(const path of expected){
 const url=new URL(path,base)
 url.searchParams.set('osgard_wave03_probe',Date.now().toString())
 let r,body=''
 try {
  r=await fetch(url,{headers:{'cache-control':'no-cache'},signal:AbortSignal.timeout(20000)})
  body=await r.text()
 } catch(error){results.push({path,status:0,ok:false,error:String(error)});continue}
 const valid=r.status===200&&body.length>100
 results.push({path,status:r.status,ok:valid,bytes:body.length})
 if(!valid)continue
 if(path==='/games/'){
  results.at(-1).ok=['player-experience.mjs','player-experience.css'].every(name=>body.includes(name))&&body.includes('id="last-session"')&&body.includes('id="player-help-toggle"')
 }else if(path.endsWith('aaa-roadmap.v1.json')){
  try{
   const manifest=JSON.parse(body)
   results.at(-1).ok=manifest.schemaVersion===1&&manifest.games.length===22&&
    manifest.games.every(g=>g.controls&&g.saveBehavior&&g.networkBehavior)&&
    ['in_review','completed'].includes(manifest.waves.find(w=>w.id==='03')?.state)
  }catch{results.at(-1).ok=false}
 }
}
const failed=results.filter(r=>!r.ok)
console.log(JSON.stringify({status:failed.length?'FAIL':'PASS',base,checkedAt:new Date().toISOString(),results},null,2))
if(failed.length)process.exitCode=1
