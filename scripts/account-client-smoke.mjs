import {build} from 'esbuild'
import {mkdir,writeFile,unlink} from 'node:fs/promises'
import {createRequire} from 'node:module'
import assert from 'node:assert/strict'
const output='node_modules/.tmp/account-client.cjs'
const result=await build({stdin:{contents:"export {projectActionLink} from './src/OperationsPage';export * from './src/accountAccess';export {coreRequest,setCoreToken} from './src/coreClient'",resolveDir:process.cwd(),loader:'ts'},bundle:true,format:'cjs',platform:'node',write:false,loader:{'.css':'empty'}})
await mkdir('node_modules/.tmp',{recursive:true});await writeFile(output,result.outputFiles[0].text)
try{
 let stored='first',blocked=false,headers;const handlers=[]
 globalThis.sessionStorage={getItem:()=>{if(blocked)throw Error('blocked');return stored},setItem:(_,v)=>{if(blocked)throw Error('blocked');stored=v},removeItem:()=>{stored=''}}
 globalThis.window={addEventListener:(name,fn)=>{if(name==='pageshow')handlers.push(fn)}}
 globalThis.fetch=async(_,options)=>{headers=options.headers;return {ok:true,status:200,headers:{get:()=> 'application/json'},json:async()=>({ok:true})}}
 const require=createRequire(import.meta.url),{safeReturnTo,coreLoginLink,recoveryDocument,coreRequest,setCoreToken,projectActionLink,coreAuthReturn}=require('../'+output)
 const pid='a'.repeat(32),sid='b'.repeat(32),target='/learning/campus?project='+pid+'&submission='+sid+'&panel=final&intent=review'
 assert.equal(safeReturnTo(target),target);assert.equal(new URLSearchParams(coreLoginLink(target).split('?')[1]).get('returnTo'),target)
 for(const input of [null,'https://evil.test','//evil.test','/\\evil.test','/account#secret','/unknown','/account\n','/account?'+ 'a'.repeat(1001)])assert.equal(safeReturnTo(input),'/workspace',String(input))
 assert.equal(safeReturnTo('/account?token=secret&project=invalid'),'/account');assert.equal(safeReturnTo('/workspace?panel=external&intent=delete'),'/workspace')
 assert.equal(safeReturnTo('/workspace/overview'),'/workspace/overview');assert.equal(safeReturnTo('/workspace?project='+pid+'&tab=delivery&secret=drop'),'/workspace?project='+pid+'&tab=delivery');assert.equal(safeReturnTo('/workspace?tab=external'),'/workspace');
 assert.equal(safeReturnTo('/learning/organizer'),'/learning/organizer')
 assert.equal(projectActionLink({id:pid,nextAction:{stage:'delivery'}}),'/workspace?project='+pid+'&tab=delivery');assert.equal(projectActionLink({id:pid,nextAction:{stage:'campus'}}),'/learning/campus?project='+pid);assert.equal(projectActionLink({id:pid,nextAction:{stage:'//external'}}),'/workspace?project='+pid+'&tab=contract');assert.throws(()=>projectActionLink({id:'../external',nextAction:{stage:'studio'}}));
 assert.equal(coreAuthReturn('/workspace/','?project='+pid+'&tab=delivery'),'/workspace?project='+pid+'&tab=delivery');assert.equal(safeReturnTo('/workspace/overview/'),'/workspace/overview');
 assert.equal(coreAuthReturn('/workspace','?project='+pid+'&tab=delivery'),'/workspace?project='+pid+'&tab=delivery');assert.equal(coreAuthReturn('/workspace','?returnTo='+encodeURIComponent('/workspace/overview')),'/workspace/overview');assert.equal(coreAuthReturn('/workspace','?returnTo=https://external.test'),'/workspace');
 assert.equal(coreAuthReturn('/workspace/','?returnTo='+encodeURIComponent('/deliveries?delivery='+sid)),'/deliveries?delivery='+sid);assert.equal(safeReturnTo('/deliveries/?delivery='+sid+'&token=discard'),'/deliveries?delivery='+sid);
 assert.equal(safeReturnTo('/teams/?team='+sid+'&secret=drop'),'/teams?team='+sid);
 const txt=recoveryDocument('tester','batch',['one','two']);assert.ok(txt.includes('one\ntwo'));assert.ok(txt.includes('Активируйте этот набор'));assert.ok(txt.includes('аннулирует все старые коды и сессии'))
 await coreRequest('health');assert.equal(headers.Authorization,'Bearer first')
 stored='second';for(const fn of handlers)fn({persisted:true});await coreRequest('health');assert.equal(headers.Authorization,'Bearer second')
 stored='third';for(const fn of handlers)fn({persisted:false});await coreRequest('health');assert.equal(headers.Authorization,'Bearer second')
 blocked=true;setCoreToken('memory-only');for(const fn of handlers)fn({persisted:true});await coreRequest('health');assert.equal(headers.Authorization,'Bearer memory-only')
 blocked=false;stored='';for(const fn of handlers)fn({persisted:true});await coreRequest('health');assert.equal(headers.Authorization,undefined)
 console.log('ACCOUNT CLIENT PASS: scoped login return, rejected external URLs, recovery download text, BFCache token refresh and blocked-storage memory session; no browser automation')
}finally{await unlink(output)}
