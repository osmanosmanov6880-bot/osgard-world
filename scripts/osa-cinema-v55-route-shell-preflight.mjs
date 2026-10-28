import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import { build } from 'esbuild'

// Reads the canonical registry directly instead of relying on a copied list.
const entry=await build({entryPoints:['src/osaCinemaStudioRegistry.ts'],bundle:true,write:false,format:'esm',platform:'node'})
const {studioWorks}=await import('data:text/javascript;base64,'+Buffer.from(entry.outputFiles[0].text).toString('base64'))
const entries=[
  {path:'osa-cinema/studio',title:'OSA CINEMA STUDIO',art:null},
  ...studioWorks.map(work=>({path:'osa-cinema/studio/films/'+work.id,title:work.title,art:work.artwork}))
]
for(const {path,title,art} of entries) {
  const file=join('dist',path,'index.html')
  assert.ok(existsSync(file),'Missing deployable route shell: '+file)
  const html=readFileSync(file,'utf8')
  const canonical='https://osgard.world/'+path
  assert.ok(html.includes('<title>')&&html.includes(title),'Incorrect title: '+path)
  assert.ok(html.includes('<link rel="canonical" href="'+canonical+'"'),'Missing canonical: '+path)
  assert.ok(html.includes('property="og:url" content="'+canonical+'"'),'Missing OpenGraph URL: '+path)
  assert.ok(html.includes('name="description"'),'Missing description: '+path)
  assert.ok(html.includes('data-route-seo'),'Missing structured route data: '+path)
  assert.ok(!html.includes('"VideoObject"'),'Unverified film tagged as public VideoObject: '+path)
  if(art){
    const asset=join('dist','osa-cinema','reference',art)
    assert.ok(existsSync(asset),'Missing approved existing artwork '+asset)
    assert.equal(readFileSync(asset).subarray(0,4).toString('ascii'),'RIFF','Invalid WebP: '+art)
    assert.ok(html.includes('"CreativeWork"'),'Film is not represented as CreativeWork: '+path)
    assert.ok(html.includes('https://osgard.world/osa-cinema/reference/'+art),'Incorrect OG poster: '+path)
  }
}
console.log(JSON.stringify({status:'passed',routeShells:entries.length,filmDossiers:studioWorks.length,publicVideoObjects:0,scope:'built HTML shells and same-origin original art; no live HTTPS playback claim'}))
