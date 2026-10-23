/* v39 regression: rain-only street reflections, authored lamp ground spill,
 * wear-aware road markings, 4 batch budget and preserved gameplay collisions.
 */
import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
import {execFileSync} from 'node:child_process'

const root='public/games/zion-9/queue/ZION-030/'
const art=fs.readFileSync(root+'open-city-optics39.js','utf8')
const rules=fs.readFileSync(root+'open-city-rules.js','utf8')
const html=fs.readFileSync(root+'index.html','utf8')
const core=fs.readFileSync(root+'open-city.js','utf8')
const deployment=fs.readFileSync('scripts/zion-030-live-assets.mjs','utf8')
new vm.Script(art,{filename:'open-city-optics39.js'})
execFileSync(process.execPath,['--check',root+'open-city-optics39.js'])
assert.ok(html.includes('open-city-optics39.js?v=39'))
assert.ok(html.indexOf('open-city-optics39.js?v=39')<html.indexOf('open-city.js?v=34'))
assert.ok(deployment.includes("'open-city-optics39.js'"))
for(const signature of ['ZION030_OPTICS39.install','opticsKit?.syncEnvironment(',
  "opticsKit?.setQuality(world.quality)",'optics:opticsKit?.stats ?? null',
  "opticsKit?.setQuality('adaptive')"])
  assert.ok(core.includes(signature),'v39 live integration missing '+signature)

class Vec{
  constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}
  set(x,y,z=0){this.x=x;this.y=y;this.z=z;return this}
}
class Node{
  constructor(){
    this.children=[];this.position=new Vec();this.rotation=new Vec();
    this.scale=new Vec(1,1,1);this.name='';this.visible=true;
    const self=this
    this.matrix={clone:()=>({pos:{...self.position},rot:{...self.rotation},
      scale:{...self.scale}})}
  }
  add(...nodes){this.children.push(...nodes)}
  remove(...nodes){this.children=this.children.filter(n=>!nodes.includes(n))}
  updateMatrix(){}
}
class Geometry{dispose(){this.disposed=true}}
class Material{
  constructor(opts={}){Object.assign(this,opts);this.color=opts.color||0}
  dispose(){this.disposed=true}
}
class Mesh extends Node{
  constructor(g,m){super();this.geometry=g;this.material=m}
}
class Inst extends Mesh{
  constructor(g,m,n){super(g,m);this.count=n;this.matrices=[];
    this.instanceMatrix={needsUpdate:false}}
  setMatrixAt(i,m){this.matrices[i]=m}
}
class Texture{
  constructor(canvas){this.canvas=canvas}
  dispose(){this.disposed=true}
}
const THREE={
  Group:Node,Object3D:Node,InstancedMesh:Inst,
  PlaneGeometry:Geometry,BoxGeometry:Geometry,
  CanvasTexture:Texture,MeshBasicMaterial:Material,
  MeshStandardMaterial:Material,
  DoubleSide:2,AdditiveBlending:3,SRGBColorSpace:'srgb'
}
const document={createElement:()=>{
  const canvas={width:0,height:0}
  canvas.getContext=()=>({
    createImageData:(w,h)=>({data:new Uint8ClampedArray(w*h*4)}),
    putImageData(){}
  })
  return canvas
}}
function run(options){
  const context={window:{},document,console}
  vm.createContext(context)
  vm.runInContext(rules,context);vm.runInContext(art,context)
  const scene=new Node()
  const lamps=Array.from({length:7},(_,i)=>{
    const p=new Node();p.position.set(-6+i*2,0,i%2?2.4:-3.1);return p
  })
  const kit=context.window.ZION030_OPTICS39.install({
    THREE,scene,rules:context.window.ZION030_CITY_RULES,
    lamps,...options
  })
  const state=kit.stats
  assert.equal(state.version,'39.0')
  assert.equal(state.authenticLampAnchors,7)
  assert.equal(state.source,'in-game authored lamp transforms')
  assert.equal(state.physicalLightsAdded,0)
  assert.equal(state.playerCollidersAdded,0)
  assert.equal(state.tier,options.softwareGL||options.reducedMotion?
    'LITE':options.mobile?'MOBILE':'ULTRA')
  assert.equal(state.spillInstances,7)
  assert.equal(state.reflectionInstances,7)
  assert.ok(state.drawCallBatches<=4)
  assert.ok(state.roadPaintStrips>0||state.tier==='LITE')
  assert.equal(state.scuffInstances>0,state.tier==='ULTRA')
  assert.equal(state.canvasTextures,state.tier==='LITE'?0:2)
  assert.equal(state.estimatedTextureBytes,state.tier==='LITE'?0:2*128*128*4)
  assert.equal(scene.children.length,1)
  const surfaces=scene.children[0].children
  for(const batch of surfaces.flatMap(x=>x.children)){
    assert.equal(batch.count,batch.matrices.length)
    assert.ok(batch.matrices.every(t=>[t.pos.x,t.pos.y,t.pos.z,
      t.scale.x,t.scale.y,t.scale.z].every(Number.isFinite)))
  }
  kit.syncEnvironment({raining:false,dayMode:0})
  assert.equal(kit.stats.nightPoolsVisible,false)
  assert.equal(kit.stats.wetReflectionsVisible,false)
  kit.syncEnvironment({raining:true,dayMode:1})
  assert.equal(kit.stats.rain,true)
  assert.equal(kit.stats.night,true)
  assert.equal(kit.stats.nightPoolsVisible,state.tier!=='LITE')
  assert.equal(kit.stats.wetReflectionsVisible,state.tier!=='LITE')
  kit.setQuality('eco')
  assert.equal(kit.stats.visible,false)
  assert.equal(kit.stats.wetReflectionsVisible,false)
  kit.setQuality('high')
  assert.equal(kit.stats.visible,state.tier!=='LITE')
  kit.syncEnvironment({raining:false,dayMode:1})
  assert.equal(kit.stats.wetReflectionsVisible,false)
  const report=kit.stats;kit.dispose()
  assert.equal(scene.children.length,0)
  return report
}
const ultra=run({mobile:false,softwareGL:false,reducedMotion:false})
const mobile=run({mobile:true,softwareGL:false,reducedMotion:false})
const lite=run({mobile:false,softwareGL:true,reducedMotion:true})
assert.equal(lite.drawCallBatches,0)
assert.ok(ultra.drawCallBatches>=mobile.drawCallBatches)
assert.ok(mobile.drawCallBatches>lite.drawCallBatches)
console.log('PASS ZION-030 v39: real lamp spill, rainy reflections, worn road paint, four draw batches and ECO cleanup')
console.log(JSON.stringify({ultra,mobile,lite}))
