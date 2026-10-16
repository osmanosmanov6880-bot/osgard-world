import { readFileSync,writeFileSync,readdirSync,statSync,existsSync } from 'node:fs'
import { join,relative } from 'node:path'
import { createHash } from 'node:crypto'
import assert from 'node:assert/strict'
const root='dist',files=[]
function walk(path){for(const name of readdirSync(path)){const full=join(path,name);statSync(full).isDirectory()?walk(full):files.push(full)}}walk(root)
assert.ok(files.length<=20000,'Static profile exceeds the configured 20,000-file ceiling')
for(const file of files)assert.ok(statSync(file).size<=25*1024*1024,'File exceeds the configured Pages asset ceiling: '+file)
for(const required of ['index.html','404.html','_headers','_redirects','data/index.html','workspace/index.html','workspace/overview/index.html','deliveries/index.html','teams/index.html','account/index.html','learning/campus/index.html','learning/organizer/index.html','play/index.html','intelligence/index.html','learning/project/index.html','games/time/index.html','brand/favicon.svg'])assert.ok(existsSync(join(root,required)),required)
assert.ok(readFileSync(root+'/_redirects','utf8').includes('/r/* /index.html 200'))
assert.ok(!/^\/\*\s+\/index\.html/m.test(readFileSync(root+'/_redirects','utf8')),'Catch-all rewrite would hide real 404 responses')
assert.ok(readFileSync(root+'/404.html','utf8').includes('content="noindex"'))
const catalogue=readFileSync('src/redesignCatalog.ts','utf8');assert.ok(catalogue.includes("launchable:false"),'Missing game export must remain disabled')
const sitemap=readFileSync(root+'/sitemap.xml','utf8')
const routes=[...sitemap.matchAll(/<loc>https:\/\/osgard\.world([^<]*)<\/loc>/g)].map(m=>m[1]||'/')
for(const route of routes){const file=join(root,route);assert.ok((existsSync(file)&&statSync(file).isFile())||existsSync(join(file,'index.html')),'Sitemap route lacks a built page: '+route)}
const hashes=files.filter(f=>!['release-manifest.json','RELEASE-REPORT.json'].includes(relative(root,f))).map(path=>({path:relative(root,path).replaceAll('\\','/'),bytes:statSync(path).size,sha256:createHash('sha256').update(readFileSync(path)).digest('hex')}))
const report={profile:'static-redesign-preview',status:'static-package-checks-passed',fullProductionApproval:false,fileCount:hashes.length+2,maximumFileBytes:Math.max(...files.map(f=>statSync(f).size)),sitemapRoutesChecked:routes.length,limitsChecked:{files:20000,assetBytes:25*1024*1024},browserQA:'pending',fieldCoreWebVitals:'not-collected',cloudAccounts:false,optionalCoreServer:'included-in-full-source-archive-not-static-hosting',payments:false,formDelivery:'download-only',unavailableGames:['null-shift'],externalGameServices:'not-verified',notes:['This profile is for the static preview with unavailable functionality disclosed.','It does not satisfy the existing full-game release gate requiring a Godot WASM export.'],references:['https://developers.cloudflare.com/pages/configuration/serving-pages/','https://developers.cloudflare.com/pages/platform/limits/']}
writeFileSync(root+'/release-manifest.json',JSON.stringify({algorithm:'sha256',files:hashes},null,2)+'\n')
writeFileSync(root+'/RELEASE-REPORT.json',JSON.stringify(report,null,2)+'\n')
writeFileSync('docs/STATIC-PREVIEW-REPORT.json',JSON.stringify(report,null,2)+'\n')
console.log(JSON.stringify(report,null,2))
