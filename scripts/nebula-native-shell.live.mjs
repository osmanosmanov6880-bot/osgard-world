import { isNativeNebulaShell } from './native-nebula-shell-contract.mjs'
const base=(process.env.OSGARD_BASE_URL||'https://osgard.world').replace(/\/$/,'')
const routes=['/games/remix/arena-v2/nebula-3d/','/games/remix/arena-v2/nebula-3d/index.html']
const devices={'desktop':'OSGARD-Native-Nebula/2 Desktop','mobile':'OSGARD-Native-Nebula/2 Mobile'}
const results=[]
for(const [device,userAgent] of Object.entries(devices)) {
  for(const path of routes) {
    const u=new URL(path,base)
    u.searchParams.set('nebula_shell_check',device+'-'+Date.now())
    try{
      const response=await fetch(u,{headers:{'user-agent':userAgent,'cache-control':'no-cache'},signal:AbortSignal.timeout(15000)})
      const text=await response.text()
      results.push({device,path,status:response.status,bytes:text.length,
        ok:response.status===200&&isNativeNebulaShell(text),
        title:text.match(/<title>([^<]*)<\/title>/)?.[1]||null})
    }catch(error){results.push({device,path,status:0,ok:false,error:String(error)})}
  }
}
const failures=results.filter(x=>!x.ok)
console.log(JSON.stringify({status:failures.length?'FAIL':'PASS',base,checkedAt:new Date().toISOString(),results},null,2))
if(failures.length)process.exitCode=1
