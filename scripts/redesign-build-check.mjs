import assert from 'node:assert/strict'
import { readFileSync,existsSync,writeFileSync } from 'node:fs'
import { gzipSync } from 'node:zlib'
const manifest=JSON.parse(readFileSync('dist/.vite/manifest.json','utf8'))
const collect=(key,result=new Set())=>{if(result.has(key))return result;const item=manifest[key];assert.ok(item,'Missing manifest entry '+key);result.add(key);for(const child of item.imports||[])collect(child,result);return result}
// Rollup may combine a dynamic entry with helpers shared by its deferred child.
// Resolve that actual entry by its unique name and its edge from the main app;
// every static dependency and the same 95 KiB limit are still counted below.
const resolveRoute=route=>{
 if(manifest[route])return route
 const name=route.split('/').at(-1).replace(/\.tsx$/,'')
 const matches=(manifest['index.html'].dynamicImports||[]).filter(key=>manifest[key]?.isDynamicEntry&&manifest[key].name===name)
 assert.equal(matches.length,1,'Missing or ambiguous dynamic manifest entry '+route)
 return matches[0]
}
const reports=[]
for(const route of ['src/WorldHome.tsx','src/IntelligenceHome.tsx','src/PlayHome.tsx']){
 const keys=new Set([...collect('index.html'),...collect(resolveRoute(route))])
 const files=[...new Set([...keys].map(k=>manifest[k].file))]
 assert.ok(files.every(f=>!f.includes('/three-')&&!f.includes('LivingGlobe')&&!f.includes('TimePrototype')),'3D/game runtime leaked into '+route)
 assert.ok([...keys].every(k=>!k.includes('osaLessonGuides')&&!k.includes('osaLessonReading')),'Full lesson content leaked into '+route)
 if(route==='src/PlayHome.tsx')assert.ok([...keys].every(key=>!['PlayGameRoute','PlayExploreSections'].includes(manifest[key].name)),'Deferred PLAY sections or session controller leaked into catalogue entry')
 const jsGzipBytes=files.reduce((sum,file)=>sum+gzipSync(readFileSync('dist/'+file)).length,0)
 assert.ok(jsGzipBytes<=95*1024,'Landing JavaScript exceeds the 95 KiB gzip budget: '+route)
 const css=[...new Set([...keys].flatMap(k=>manifest[k].css||[]))]
 assert.ok(css.every(f=>!f.includes('legacyStyles')),'Legacy styles leaked into new landing')
 reports.push({route,jsFiles:files,jsGzipBytes,cssFiles:css,cssGzipBytes:css.reduce((sum,file)=>sum+gzipSync(readFileSync('dist/'+file)).length,0)})
}
for(const path of ['intelligence','play','development','games','entertainment','play/partners','play/world/vector-zero','learning/project','lectures/how-language-models-work']){
 const html=readFileSync('dist/'+path+'/index.html','utf8');assert.ok(html.includes('<title>'));assert.ok(html.includes('https://osgard.world/'+(['games','entertainment'].includes(path)?'play':path)));const preview=html.match(/property="og:image" content="https:\/\/osgard.world([^"<>]+)/);assert.ok(preview);assert.ok(existsSync('dist'+preview[1]),preview?.[1])
}
const luminance=h=>{const c=h.replace('#','').match(/../g).map(x=>parseInt(x,16)/255).map(v=>v<=.04045?v/12.92:((v+.055)/1.055)**2.4);return .2126*c[0]+.7152*c[1]+.0722*c[2]}
const contrasts=[]
for(const [fg,bg] of [['#172027','#F3F4F1'],['#59656B','#F3F4F1'],['#315A62','#FFFFFF'],['#F3F0E8','#101A27'],['#AAB4BC','#182330'],['#83B9AE','#101A27'],['#5CE1E6','#111926'],['#AAB6C7','#111926']]){const a=luminance(fg),b=luminance(bg),ratio=(Math.max(a,b)+.05)/(Math.min(a,b)+.05);assert.ok(ratio>=4.5,fg+' / '+bg);contrasts.push({foreground:fg,background:bg,ratio:Number(ratio.toFixed(2))})}
writeFileSync('docs/REDESIGN-BUILD-AUDIT.json',JSON.stringify({scope:'Build dependency and token checks; not browser QA or field Core Web Vitals',routes:reports,contrasts},null,2)+'\n')
console.log(JSON.stringify({status:'passed',routes:reports.map(({route,jsGzipBytes,cssGzipBytes})=>({route,jsGzipBytes,cssGzipBytes})),contrastPairs:contrasts.length,no3DInLandings:true},null,2))
