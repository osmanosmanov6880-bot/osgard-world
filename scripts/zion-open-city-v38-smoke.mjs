/* ZION-030 v38 regression: actual foliage anchoring, weathered walls,
 * bounded instancing, 12Hz motion, reduced-motion/eco and GPU cleanup.
 */
import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
import {execFileSync} from 'node:child_process'

const root='public/games/zion-9/queue/ZION-030/'
const art=fs.readFileSync(root+'open-city-nature38.js','utf8')
const rules=fs.readFileSync(root+'open-city-rules.js','utf8')
const entry=fs.readFileSync(root+'index.html','utf8')
const core=fs.readFileSync(root+'open-city.js','utf8')
new vm.Script(art,{filename:'open-city-nature38.js'})
execFileSync(process.execPath,['--check',root+'open-city-nature38.js'])
assert.ok(entry.includes('open-city-nature38.js?v=38'))
assert.ok(entry.indexOf('open-city-nature38.js?v=38')<entry.indexOf('open-city.js?v=34'))
for(const signature of ["ZION030_NATURE38.install","natureKit?.setQuality(world.quality)",
  "natureKit?.syncEnvironment(","natureKit?.update(dt)",
  "nature:natureKit?.stats ?? null","natureKit?.setQuality('adaptive')"])
  assert.ok(core.includes(signature),'Missing v38 runtime binding: '+signature)
assert.ok(fs.readFileSync('scripts/zion-030-live-assets.mjs','utf8')
  .includes("'open-city-nature38.js'"))

class V{
  constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}
  set(x,y,z=0){this.x=x;this.y=y;this.z=z;return this}
}
class Color{
  constructor(v){this.v=v}
  setHex(v){this.v=v;return this}
}
class Obj{
  constructor(){
    this.children=[];this.name='';this.visible=true;
    this.position=new V();this.rotation=new V();this.scale=new V(1,1,1);
    const self=this
    this.matrix={clone:()=>({pos:{...self.position},scale:{...self.scale},
      rotation:{...self.rotation}})}
  }
  add(...xs){this.children.push(...xs)}
  remove(...xs){this.children=this.children.filter(x=>!xs.includes(x))}
  updateMatrix(){}
}
class G{
  setAttribute(n,a){this.attributes??={};this.attributes[n]=a}
  setIndex(a){this.index=a}
  computeVertexNormals(){this.normals=true}
  dispose(){this.disposed=true}
}
class Mat{
  constructor(o={}){Object.assign(this,o);this.color=new Color(o.color)}
  dispose(){this.disposed=true}
}
class Mesh extends Obj{
  constructor(geo,mat){super();this.geometry=geo;this.material=mat}
}
class Inst extends Mesh{
  constructor(geo,mat,count){super(geo,mat);this.count=count;
    this.matrices=[];this.instanceMatrix={needsUpdate:false};}
  setMatrixAt(i,m){this.matrices[i]=typeof m.clone==='function'?m.clone():m}
}
class Texture{
  constructor(canvas){this.canvas=canvas}
  dispose(){this.disposed=true}
}
class Attr{
  constructor(data,itemSize){this.data=data;this.itemSize=itemSize}
}
const T={
  Group:Obj,Object3D:Obj,InstancedMesh:Inst,BufferGeometry:G,
  Float32BufferAttribute:Attr,PlaneGeometry:G,CylinderGeometry:G,
  MeshStandardMaterial:Mat,MeshBasicMaterial:Mat,CanvasTexture:Texture,
  DoubleSide:2,SRGBColorSpace:'srgb',LinearFilter:1,
  LinearMipmapLinearFilter:2
}
const document={
  createElement(){
    const c={width:0,height:0}
    c.getContext=()=>({createImageData:(w,h)=>({data:new Uint8ClampedArray(w*h*4)}),
      putImageData(){}})
    return c
  }
}
function run(settings){
  const context={window:{},document,console}
  vm.createContext(context);vm.runInContext(rules,context);vm.runInContext(art,context)
  const scene=new Obj()
  const foliage=Array.from({length:6},(_,i)=>{
    const obj=new Obj();obj.position.set(-5+i*2,0,(i%2)*4-2);return obj
  })
  const kit=context.window.ZION030_NATURE38.install({
    THREE:T,scene,rules:context.window.ZION030_CITY_RULES,
    foliage,...settings
  })
  const initial=kit.stats
  assert.equal(initial.version,'38.0')
  assert.equal(initial.authoredStreetTrees,6)
  assert.equal(initial.tier,settings.softwareGL||settings.reducedMotion?
    'LITE':settings.mobile?'MOBILE':'ULTRA')
  assert.equal(initial.leafBlades,settings.softwareGL||settings.reducedMotion?
    0:settings.mobile?120:312)
  assert.equal(initial.fallenLeaves,settings.softwareGL||settings.reducedMotion?
    0:settings.mobile?42:108)
  assert.ok(initial.drawBatches<=4)
  assert.equal(initial.weatherAtlasBytes,settings.softwareGL||settings.reducedMotion?
    0:96*192*4)
  assert.ok(initial.facadeWaterStains===0||initial.facadeWaterStains>=136)
  assert.equal(scene.children.length,1)
  assert.ok(scene.children[0].name.includes('ZION38'))
  const instances=scene.children[0].children
  assert.equal(instances.length,initial.drawBatches)
  for(const mesh of instances){
    assert.equal(mesh.matrices.length,mesh.count)
    assert.ok(mesh.matrices.every(m=>[m.pos.x,m.pos.y,m.pos.z,
      m.scale.x,m.scale.y,m.scale.z].every(Number.isFinite)))
  }
  kit.syncEnvironment({raining:true,dayMode:1})
  assert.equal(kit.stats.rain,true);assert.equal(kit.stats.night,true)
  kit.setQuality('eco');assert.equal(kit.stats.highVisible,false)
  kit.update(.20);assert.equal(kit.stats.animatedUpdates,0)
  kit.setQuality('high')
  assert.equal(kit.stats.highVisible,!settings.softwareGL&&!settings.reducedMotion)
  kit.update(.20);kit.update(.20)
  if(!settings.softwareGL&&!settings.reducedMotion)
    assert.ok(kit.stats.animatedUpdates>=1)
  else assert.equal(kit.stats.animatedUpdates,0)
  const result=kit.stats
  kit.dispose()
  assert.equal(scene.children.length,0)
  return result
}
const ultra=run({mobile:false,softwareGL:false,reducedMotion:false})
const mobile=run({mobile:true,softwareGL:false,reducedMotion:false})
const lite=run({mobile:false,softwareGL:true,reducedMotion:true})
assert.ok(ultra.instances>mobile.instances)
assert.ok(mobile.instances>lite.instances)
console.log('PASS ZION-030 v38: bounded leaf silhouettes, live wind, facade grime, rain/night appearance, mobile/ECO and disposal')
console.log(JSON.stringify({ultra,mobile,lite}))
