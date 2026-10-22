import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
import path from 'node:path'
import {execFileSync} from 'node:child_process'

// Validate the actual SSH-release asset verifier before this branch can merge.
const verifier=path.resolve('scripts/zion-030-live-assets.mjs')
execFileSync(process.execPath,['--check',verifier],{stdio:'pipe'})
const verifierSource=fs.readFileSync(verifier,'utf8')
assert.ok(verifierSource.includes("'open-city-landmarks.js'"),'Deploy must verify the new landmark assets')
const base=path.resolve('public/games/zion-9/queue/ZION-030')
const js=fs.readFileSync(path.join(base,'open-city-landmarks.js'),'utf8')
const original=fs.readFileSync(path.join(base,'open-city.js'),'utf8')
const rulesJs=fs.readFileSync(path.join(base,'open-city-rules.js'),'utf8')
const html=fs.readFileSync(path.join(base,'index.html'),'utf8')
new vm.Script(js,{filename:'open-city-landmarks.js'})
assert.ok(html.includes('open-city-landmarks.js?v=32')&&html.includes('open-city.js?v=33'))
assert.ok(html.indexOf('open-city-landmarks.js?v=32')<html.indexOf('open-city.js?v=33'))
assert.ok(original.includes('landmarkKit?.detailCar(shellMesh)'))
assert.ok(original.includes('landmarkKit?.detailAvatar(avatar)'))
assert.ok(original.includes('landmarkKit?.syncEnvironment({ raining: world.raining, dayMode: world.dayMode })'))
assert.ok(original.includes('landmarkKit?.setQuality(world.quality)'))
assert.ok(original.includes('landmarks: landmarkKit?.stats ?? null'))
function mockThree(){
  class Vector{constructor(){this.x=this.y=this.z=0}set(x,y,z){this.x=x;this.y=y;this.z=z;return this}}
  class Matrix{constructor(owner){this.owner=owner}clone(){return{x:this.owner.position.x,y:this.owner.position.y,z:this.owner.position.z,
    w:this.owner.scale.x,h:this.owner.scale.y,d:this.owner.scale.z,
    ry:this.owner.rotation.y,rx:this.owner.rotation.x,rz:this.owner.rotation.z}}}
  class Object3D{constructor(){this.children=[];this.position=new Vector();this.rotation=new Vector();this.scale=new Vector().set(1,1,1);this.matrix=new Matrix(this);this.visible=true}
    add(...children){this.children.push(...children)}
    remove(...children){this.children=this.children.filter(x=>!children.includes(x))}
    updateMatrix(){}
  }
  class Geo{constructor(...args){this.parameters={radius:args[0]};this.type='Geometry'}dispose(){}}
  class Material{constructor(props){this.opacity=props.opacity??1;this.roughness=props.roughness;this.metalness=props.metalness;this.emissiveIntensity=props.emissiveIntensity??0}dispose(){}}
  class Mesh extends Object3D{constructor(g,m){super();this.geometry=g;this.material=m;this.isMesh=true}}
  class Instanced extends Mesh{constructor(g,m,count){super(g,m);this.count=count;this.matrices=[];this.instanceMatrix={needsUpdate:false};this.isInstancedMesh=true}
    setMatrixAt(i,m){this.matrices[i]=m}}
  return {Group:Object3D,Object3D,BoxGeometry:Geo,CylinderGeometry:Geo,ConeGeometry:Geo,SphereGeometry:Geo,
    TorusGeometry:Geo,Mesh,InstancedMesh:Instanced,MeshLambertMaterial:Material,MeshStandardMaterial:Material}
}
function run(settings){
  const ctx={window:{},console}
  vm.createContext(ctx)
  vm.runInContext(rulesJs,ctx)
  vm.runInContext(js,ctx)
  const T=mockThree(),scene=new T.Group()
  const kit=ctx.window.ZION030_LANDMARK_KIT.install({THREE:T,scene,rules:ctx.window.ZION030_CITY_RULES,...settings})
  const initial=kit.stats
  assert.equal(initial.version,'32.0')
  assert.equal(initial.tier,settings.softwareGL?'LITE':settings.mobile?'MOBILE':'ULTRA')
  assert.ok(initial.rooftopBuildings>=40)
  assert.ok(initial.heroLandmarks>=5)
  assert.ok(initial.columns>0)
  assert.ok(initial.roofFixtures>0)
  assert.ok(initial.solarArrays>0)
  assert.ok(initial.streetLamps>0)
  assert.ok(initial.instances>300&&initial.instances<12000)
  assert.ok(initial.drawCallBatches<=60)
  for(const layer of scene.children)for(const mesh of layer.children){
    assert.ok(mesh.isInstancedMesh)
    assert.equal(mesh.matrices.length,mesh.count)
    assert.ok(mesh.matrices.every(m=>[m.x,m.y,m.z,m.w,m.h,m.d,m.rx,m.ry,m.rz].every(Number.isFinite)&&m.w>0&&m.h>0&&m.d>0))
  }
  const car=new T.Group(),person=new T.Group()
  kit.detailCar(car);kit.detailAvatar(person)
  const latest=kit.stats
  assert.ok(latest.vehicleParts>=50)
  assert.ok(latest.vehicleBatches<=18)
  assert.equal(latest.vehicleCount,1)
  assert.ok(latest.maxVehicleBatches<=18)
  assert.ok(latest.characterParts>=5)
  assert.ok(car.children.some(g=>g.children.some(m=>m.isInstancedMesh)))
  kit.setQuality('eco')
  assert.equal(scene.children[1].visible,false)
  assert.equal(kit.stats.fineVisible,false)
  kit.setQuality('high')
  assert.equal(kit.stats.fineVisible,!settings.mobile&&!settings.softwareGL)
  kit.syncEnvironment({raining:true,dayMode:1})
  assert.equal(kit.stats.night,true)
  assert.equal(kit.stats.wetVisible,!settings.softwareGL)
  kit.syncEnvironment({raining:false,dayMode:2})
  assert.equal(kit.stats.wetVisible,false)
  kit.dispose()
  assert.equal(scene.children.length,0)
  return {...latest}
}
const desktop=run({mobile:false,softwareGL:false,reducedMotion:false})
const mobile=run({mobile:true,softwareGL:false,reducedMotion:false})
const lite=run({mobile:false,softwareGL:true,reducedMotion:true})
assert.ok(desktop.instances>mobile.instances&&mobile.instances>=lite.instances)
assert.equal(desktop.heroLandmarks,6)
assert.ok(desktop.planters>mobile.planters)
console.log('PASS ZION-030 v32 landmark studio, six architectural icons, real vehicle model, scene LOD & rain:',JSON.stringify({desktop,mobile,lite}))
