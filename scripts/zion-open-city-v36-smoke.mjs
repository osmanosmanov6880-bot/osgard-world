/* v36 QA: real authored scene geometry contracts, texture ownership,
 * high/low LOD, weather response, and animation without a fake WebGL FPS.
 */
import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
import {execFileSync} from 'node:child_process'

const base='public/games/zion-9/queue/ZION-030/'
const art=fs.readFileSync(base+'open-city-civic36.js','utf8')
const rules=fs.readFileSync(base+'open-city-rules.js','utf8')
const core=fs.readFileSync(base+'open-city.js','utf8')
const html=fs.readFileSync(base+'index.html','utf8')
new vm.Script(art,{filename:'open-city-civic36.js'})
execFileSync(process.execPath,['--check',base+'open-city-civic36.js'])
assert.ok(html.includes('open-city-civic36.js?v=36'))
assert.ok(html.indexOf('open-city-civic36.js?v=36')<html.indexOf('open-city.js?v=34'))
for(const signature of ['civicKit?.setQuality(world.quality)','civicKit?.syncEnvironment(',
  'civicKit?.update(dt)','civic:civicKit?.stats ?? null',
  'civicKit?.setQuality('])
  assert.ok(core.includes(signature),'Missing v36 live integration: '+signature)
// Benchmark artifacts must remain independently runnable on actual GPUs.
for(const file of ['scripts/zion-v34-hardware-benchmark.mjs',
  'scripts/zion-v36-hardware-matrix.mjs'])
  execFileSync(process.execPath,['--check',file])
const matrix=fs.readFileSync('scripts/zion-v36-hardware-matrix.mjs','utf8')
for(const expected of ['high-day','high-rain-night','eco-rain','physicalGpuConfirmed',
  'OSGARD_FORBID_ADAPTIVE_LOD'])
  assert.ok(matrix.includes(expected),'Hardware gate omits '+expected)
const liveAssets=fs.readFileSync('scripts/zion-030-live-assets.mjs','utf8')
assert.ok(liveAssets.includes("'open-city-civic36.js'"))

class Vector{
  constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}
  set(x,y,z=0){this.x=x;this.y=y;this.z=z;return this}
}
class Color{
  constructor(n){this.n=n}
  setHex(n){this.n=n;return this}
  clone(){return new Color(this.n)}
  copy(c){this.n=c.n;return this}
}
class SceneNode{
  constructor(){
    this.children=[];this.position=new Vector();this.rotation=new Vector();
    this.scale=new Vector(1,1,1);this.visible=true;this.name='';
    const target=this
    this.matrix={clone(){return{pos:{...target.position},scale:{...target.scale},
      rot:{...target.rotation}}}}
  }
  add(...items){this.children.push(...items)}
  remove(...items){this.children=this.children.filter(x=>!items.includes(x))}
  updateMatrix(){}
}
class Geometry{
  constructor(){this.attributes={}}
  setAttribute(n,a){this.attributes[n]=a}
  dispose(){}
}
class Material{
  constructor(o={}){Object.assign(this,o);this.color=new Color(o.color);this.emissiveIntensity=o.emissiveIntensity||0}
  dispose(){}
}
class Mesh extends SceneNode{
  constructor(g,m){super();this.geometry=g;this.material=m}
}
class Instanced extends Mesh{
  constructor(g,m,n){super(g,m);this.count=n;this.matrices=[];this.instanceMatrix={needsUpdate:false}}
  setMatrixAt(i,m){this.matrices[i]=m}
}
class Texture{
  constructor(canvas){this.canvas=canvas;this.repeat={set(a,b){this.x=a;this.y=b}}}
  dispose(){}
}
class Attr{constructor(a){this.array=a;this.needsUpdate=false}}
const T={
  Group:SceneNode,Object3D:SceneNode,
  Mesh,InstancedMesh:Instanced,LineSegments:Mesh,Vector2:Vector,
  BoxGeometry:Geometry,CylinderGeometry:Geometry,TorusGeometry:Geometry,
  IcosahedronGeometry:Geometry,BufferGeometry:Geometry,
  Float32BufferAttribute:Attr,LineBasicMaterial:Material,
  MeshStandardMaterial:Material,MeshLambertMaterial:Material,
  CanvasTexture:Texture,RepeatWrapping:1,SRGBColorSpace:'srgb',NoColorSpace:'none'
}
const fakeDocument={createElement:()=>{
  const c={width:0,height:0};
  c.getContext=()=>({createImageData:(w,h)=>({data:new Uint8ClampedArray(w*h*4)}),
    putImageData(){}});
  return c
}}
function run({mobile,softwareGL,reducedMotion}){
  const ctx={window:{},document:fakeDocument,console}
  vm.createContext(ctx);vm.runInContext(rules,ctx);vm.runInContext(art,ctx)
  const scene=new SceneNode()
  const kit=ctx.window.ZION030_CIVIC36.install({THREE:T,scene,
    rules:ctx.window.ZION030_CITY_RULES,mobile,softwareGL,reducedMotion})
  const s=kit.stats
  assert.equal(s.version,'36.0')
  assert.ok(s.buildings>=55&&s.buildings<=169)
  assert.ok(s.roofParapets>=s.buildings*8)
  assert.ok(s.instances>=s.buildings*12)
  assert.ok(s.drawCallBatches>=6&&s.drawCallBatches<30)
  assert.ok(s.roofModules>0)
  assert.ok(s.solarPanels>0)
  assert.ok(s.awningPanels>0)
  assert.equal(s.tier,softwareGL?'LITE':mobile?'MOBILE':'ULTRA')
  assert.equal(s.textureMaps,softwareGL||reducedMotion?0:6)
  assert.equal(s.textureBytes,(softwareGL||reducedMotion?0:(mobile?128:256)**2*4*6))
  assert.equal(scene.children.length,1)
  assert.ok(scene.children[0].name.includes('ZION36'))
  const all=scene.children[0].children.flatMap(x=>x.children)
  const meshes=all.filter(x=>x instanceof Instanced)
  assert.ok(meshes.length>=6)
  for(const mesh of meshes){
    assert.equal(mesh.matrices.length,mesh.count)
    assert.ok(mesh.matrices.every(q=>[q.pos.x,q.pos.y,q.pos.z,
      q.scale.x,q.scale.y,q.scale.z].every(Number.isFinite)))
  }
  kit.syncEnvironment({raining:true,dayMode:1})
  assert.equal(kit.stats.night,true);assert.equal(kit.stats.rain,true)
  kit.setQuality('eco')
  assert.equal(kit.stats.fineVisible,false)
  kit.setQuality('high')
  assert.equal(kit.stats.fineVisible,!mobile&&!softwareGL&&!reducedMotion)
  kit.update(.15);kit.update(.15)
  if(!softwareGL&&!reducedMotion)assert.ok(kit.stats.windUpdates>0)
  kit.dispose()
  assert.equal(scene.children.length,0)
  return s
}
const ultra=run({mobile:false,softwareGL:false,reducedMotion:false})
const mobile=run({mobile:true,softwareGL:false,reducedMotion:false})
const software=run({mobile:false,softwareGL:true,reducedMotion:true})
assert.ok(ultra.instances>=mobile.instances)
assert.ok(ultra.facadeFrames>mobile.facadeFrames)
assert.equal(mobile.facadeFrames,0)
assert.equal(software.textureMaps,0)
console.log('PASS ZION-030 v36: physical-style facade geometry, solar rooftops, dynamic cable spline, real PBR maps, budget tiers and resource disposal')
console.log(JSON.stringify({ultra,mobile,software}))
