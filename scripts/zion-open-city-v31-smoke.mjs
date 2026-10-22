import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
import path from 'node:path'

const base=path.resolve('public/games/zion-9/queue/ZION-030')
const source=fs.readFileSync(path.join(base,'open-city-cinematic.js'),'utf8')
const rulesSource=fs.readFileSync(path.join(base,'open-city-rules.js'),'utf8')
const game=fs.readFileSync(path.join(base,'open-city.js'),'utf8')
const html=fs.readFileSync(path.join(base,'index.html'),'utf8')
new vm.Script(source,{filename:'open-city-cinematic.js'})
assert.match(html,/open-city-cinematic\.js\?v=31/)
assert.ok(html.indexOf('open-city-details.js?v=30')<html.indexOf('open-city-cinematic.js?v=31'))
assert.ok(html.indexOf('open-city-cinematic.js?v=31')<html.indexOf('open-city.js?v=31'))
assert.ok(game.includes('cinematicKit?.detailCar(shellMesh)'))
assert.ok(game.includes('cinematicKit?.detailAvatar(avatar)'))
assert.ok(game.includes('cinematicKit?.syncEnvironment({ raining: world.raining, dayMode: world.dayMode })'))
assert.ok(game.includes('cinematicKit?.setQuality(world.quality)'))

function mockThree(){
  class Vec{constructor(){this.x=0;this.y=0;this.z=0}set(x,y,z){this.x=x;this.y=y;this.z=z;return this}}
  class Mat{constructor(o){this.o=o}clone(){return {x:this.o.position.x,y:this.o.position.y,z:this.o.position.z,w:this.o.scale.x,h:this.o.scale.y,d:this.o.scale.z}}}
  class Object3D{
    constructor(){this.children=[];this.position=new Vec;this.rotation=new Vec;this.scale=new Vec().set(1,1,1);this.matrix=new Mat(this);this.visible=true}
    add(...c){this.children.push(...c)}remove(...n){this.children=this.children.filter(x=>!n.includes(x))}
    updateMatrix(){}
  }
  class Geo{constructor(a=1,b=1,c=1){this.type='BoxGeometry';this.parameters={width:a,height:b,depth:c}}dispose(){}}
  class Material{
    constructor(props={}){this.roughness=props.roughness??1;this.metalness=props.metalness??0;this.emissive=props.emissive?{}:null;this.emissiveIntensity=props.emissiveIntensity??0;this.opacity=props.opacity??1;this.color={setHex:()=>{}}}
    dispose(){}
  }
  class Mesh extends Object3D{constructor(geo,mat){super();this.geometry=geo;this.material=mat;this.isMesh=true}}
  class Instances extends Mesh{
    constructor(geo,mat,count){super(geo,mat);this.isInstancedMesh=true;this.count=count;this.matrices=[];this.instanceMatrix={needsUpdate:false}}
    setMatrixAt(i,m){this.matrices[i]=m}
  }
  return {Group:Object3D,Object3D,BoxGeometry:Geo,CylinderGeometry:Geo,IcosahedronGeometry:Geo,Mesh,InstancedMesh:Instances,MeshLambertMaterial:Material,MeshStandardMaterial:Material}
}
function make(config){
  const context={window:{},console}
  vm.createContext(context)
  vm.runInContext(rulesSource,context)
  vm.runInContext(source,context)
  const T=mockThree(),scene=new T.Group()
  const kit=context.window.ZION030_CINEMATIC_KIT.install({THREE:T,scene,rules:context.window.ZION030_CITY_RULES,...config})
  const stats=kit.stats
  assert.equal(stats.version,'31.0')
  assert.equal(stats.tier,config.softwareGL?'LITE':config.mobile?'MOBILE':'ULTRA')
  assert.ok(stats.facades>40)
  assert.ok(stats.streetFixtures>100)
  assert.ok(stats.instances>200&&stats.instances<12000)
  assert.ok(stats.drawCallBatches<=44)
  assert.ok(stats.foliageAssets>0)
  assert.ok(stats.wetSurfaces>0)
  for(const layer of scene.children)for(const obj of layer.children){
    assert.ok(obj.isInstancedMesh)
    assert.equal(obj.count,obj.matrices.length)
    assert.ok(obj.matrices.every(m=>[m.x,m.y,m.z,m.w,m.h,m.d].every(Number.isFinite)&&m.w>0&&m.h>0&&m.d>0))
  }
  const car=new T.Group(),avatar=new T.Group()
  kit.detailCar(car);kit.detailAvatar(avatar)
  assert.ok(kit.stats.vehicleParts>15&&kit.stats.avatarParts>5)
  assert.ok(car.children.length>0&&avatar.children.length>0)
  assert.equal(scene.children[1].visible,config.softwareGL?false:!config.mobile)
  kit.setQuality('eco')
  assert.equal(scene.children[1].visible,false)
  kit.setQuality('high')
  assert.equal(scene.children[1].visible,!config.mobile&&!config.softwareGL)
  const puddles=scene.children[0].children.find(x=>x.name.includes('/ wet /'))
  assert.ok(puddles)
  kit.syncEnvironment({raining:true,dayMode:1})
  assert.equal(puddles.visible,true)
  kit.syncEnvironment({raining:false,dayMode:2})
  assert.equal(puddles.visible,false)
  assert.ok(car.children[0].children.length>=5,'Visible car uses batched material groups')
  assert.ok(kit.stats.vehicleBatches<=14,'Body and wheel detail must remain GPU-instanced')
  kit.dispose()
  assert.equal(scene.children.length,0)
  return {...stats}
}
const desktop=make({mobile:false,softwareGL:false,reducedMotion:false})
const mobile=make({mobile:true,softwareGL:false,reducedMotion:false})
const lite=make({mobile:false,softwareGL:true,reducedMotion:true})
assert.ok(desktop.instances>mobile.instances&&mobile.instances>=lite.instances)
assert.ok(desktop.balconyRails>0&&desktop.rooftopAssets>0)
console.log('PASS ZION v31 cinematic geometry, PBR budget, rain/lighting, vehicle + avatar, save-safe gameplay:')
console.log(JSON.stringify({desktop,mobile,lite}))
