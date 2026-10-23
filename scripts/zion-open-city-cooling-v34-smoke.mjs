import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
import path from 'node:path'

const root=path.resolve('public/games/zion-9/queue/ZION-030')
const filename='open-city-cooling34.js'
const source=fs.readFileSync(path.join(root,filename),'utf8')
const html=fs.readFileSync(path.join(root,'index.html'),'utf8')
const game=fs.readFileSync(path.join(root,'open-city.js'),'utf8')
new vm.Script(source,{filename})
assert.ok(html.includes('open-city-cooling34.js?v=34'))
assert.ok(html.indexOf('open-city-cooling34.js?v=34')<html.indexOf('open-city.js?v=34'))
for(const anchor of ['coolingKit?.syncProgress(state.placed)',
  'coolingKit?.update(dt)', 'coolingKit?.setQuality(world.quality)',
  'coolingFx: coolingKit?.stats ?? null'])assert.ok(game.includes(anchor),anchor)

function mockThree(){
  class V{
    constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}
    set(x,y,z){this.x=x;this.y=y;this.z=z;return this}
  }
  class Matrix{
    constructor(owner){this.owner=owner}
    clone(){const o=this.owner;return{x:o.position.x,y:o.position.y,z:o.position.z,
      w:o.scale.x,h:o.scale.y,d:o.scale.z,rx:o.rotation.x,ry:o.rotation.y,rz:o.rotation.z}}
  }
  class Obj{
    constructor(){this.children=[];this.position=new V();this.rotation=new V();
      this.scale=new V(1,1,1);this.matrix=new Matrix(this);this.visible=true}
    updateMatrix(){}
    add(...xs){this.children.push(...xs)}
    remove(...xs){this.children=this.children.filter(x=>!xs.includes(x))}
  }
  class Geo{dispose(){}}
  class BufferGeo extends Geo{
    constructor(){super();this.attributes={}}
    setAttribute(key,attr){this.attributes[key]=attr}
    getAttribute(key){return this.attributes[key]}
  }
  class BufferAttr{constructor(data,n){this.array=data;this.itemSize=n;this.needsUpdate=false}}
  class Material{
    constructor(p){Object.assign(this,p);this.emissiveIntensity=p.emissiveIntensity??0}
    dispose(){}
  }
  class Mesh extends Obj{constructor(g,m){super();this.geometry=g;this.material=m}}
  class Inst extends Mesh{
    constructor(g,m,count){super(g,m);this.count=count;this.transforms=[];
      this.instanceMatrix={needsUpdate:false};this.isInstancedMesh=true}
    setMatrixAt(i,m){this.transforms[i]=typeof m.clone==='function'?m.clone():m}
  }
  return{Group:Obj,Object3D:Obj,Scene:Obj,Mesh,InstancedMesh:Inst,
    TorusGeometry:Geo,BoxGeometry:Geo,CylinderGeometry:Geo,IcosahedronGeometry:Geo,
    BufferGeometry:BufferGeo,BufferAttribute:BufferAttr,
    MeshLambertMaterial:Material,MeshStandardMaterial:Material,
    PointsMaterial:Material,Points:Mesh,AdditiveBlending:2}
}
function run(opts){
  const context={window:{},console};vm.createContext(context);
  vm.runInContext(source,context);
  const THREE=mockThree(),scene=new THREE.Group();
  const kit=context.window.ZION030_COOLING_FX.install({THREE,scene,...opts});
  const initial=kit.stats;
  assert.equal(initial.version,'34.1')
  assert.equal(initial.hotspots,3)
  assert.equal(initial.cooled,0)
  assert.equal(initial.tier,opts.softwareGL?'LITE':opts.mobile?'MOBILE':'ULTRA')
  assert.ok(initial.tileSegments===36&&initial.pipeSegments===18)
  assert.ok(initial.energyRings===6)
  assert.ok(initial.foliageVolumes>=18)
  assert.ok(initial.drawGroups>=12&&initial.drawGroups<=30)
  if(opts.softwareGL)assert.equal(initial.particleCount,0)
  else assert.equal(initial.particleCount,opts.mobile?96:234)
  const rootGroup=scene.children[0]
  assert.equal(rootGroup.children.length,3)
  assert.ok(rootGroup.children.every(g=>g.visible===false))
  const placed=[{x:-4,z:-3,type:'tree'}]
  assert.equal(kit.syncProgress(placed),1)
  assert.equal(rootGroup.children.filter(g=>g.visible).length,1)
  assert.equal(kit.stats.cooled,1)
  assert.equal(kit.syncProgress([{x:99,z:99}]),0)
  kit.syncProgress(placed)
  kit.setQuality('eco')
  kit.syncProgress(placed)
  assert.equal(kit.stats.activeParticles,0)
  kit.setQuality('high')
  kit.syncProgress([{x:-4,z:-3},{x:2,z:2},{x:4,z:-2}])
  assert.equal(kit.stats.cooled,3)
  assert.equal(kit.stats.modulesVisible,3)
  if(!opts.softwareGL)assert.equal(kit.stats.activeParticles,kit.stats.particleCount)
  kit.syncEnvironment({raining:true,dayMode:1})
  assert.equal(kit.stats.rain,true)
  assert.equal(kit.stats.night,true)
  kit.update(.09);kit.update(.09)
  assert.equal(kit.stats.motionEnabled,!opts.reducedMotion)
  if(!opts.reducedMotion)assert.ok(kit.stats.frameUpdates>0)
  assert.equal(scene.children.length,1)
  kit.dispose()
  assert.equal(scene.children.length,0)
  return {...kit.stats}
}
const ultra=run({mobile:false,softwareGL:false,reducedMotion:false})
const mobile=run({mobile:true,softwareGL:false,reducedMotion:false})
const lite=run({mobile:false,softwareGL:true,reducedMotion:true})
assert.ok(ultra.foliageVolumes>mobile.foliageVolumes&&mobile.foliageVolumes>lite.foliageVolumes)
console.log('PASS ZION v34.1: mission-linked modeled cooling, rings, pipes, foliage and low-cost animated mist')
console.log(JSON.stringify({ultra,mobile,lite}))
