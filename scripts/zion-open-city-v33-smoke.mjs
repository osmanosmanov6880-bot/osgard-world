import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const root='public/games/zion-9/queue/ZION-030/'
const source=fs.readFileSync(root+'open-city-streets.js','utf8')
const rules=fs.readFileSync(root+'open-city-rules.js','utf8')
const html=fs.readFileSync(root+'index.html','utf8')
const game=fs.readFileSync(root+'open-city.js','utf8')
const focusJs=fs.readFileSync(root+'open-city-focus.js','utf8')
const focusCss=fs.readFileSync(root+'open-city-focus.css','utf8')
new vm.Script(focusJs,{filename:'open-city-focus.js'})
assert.ok(html.includes('open-city-focus.css?v=33')&&html.includes('open-city-focus.js?v=33'))
assert.ok(html.indexOf('open-city.js?v=34')<html.indexOf('open-city-focus.js?v=33'))
assert.ok(focusJs.includes("event.code!=='KeyH'"))
assert.ok(focusJs.includes('aria-pressed'))
assert.ok(focusCss.includes('.oc-shell.oc-focus')&&focusCss.includes('.oc-joystick'))
new vm.Script(source,{filename:'open-city-streets.js'})
assert.ok(html.includes('open-city-streets.js?v=33')&&html.includes('open-city.js?v=34'))
assert.ok(html.indexOf('open-city-landmarks.js?v=32')<html.indexOf('open-city-streets.js?v=33'))
assert.ok(html.indexOf('open-city-streets.js?v=33')<html.indexOf('open-city.js?v=34'))
for(const check of ['streetKit?.detailCar(shellMesh)','streetKit?.detailAvatar(avatar)',
  'streetKit?.update(dt)','streetKit?.setQuality(world.quality)',
  'streetKit?.syncEnvironment({ raining: world.raining, dayMode: world.dayMode })',
  'street: streetKit?.stats ?? null'])assert.ok(game.includes(check),check)

function threeMock(){
  class V{constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}set(x,y,z){this.x=x;this.y=y;this.z=z;return this}}
  class M{constructor(obj){this.obj=obj}clone(){return {x:this.obj.position.x,y:this.obj.position.y,z:this.obj.position.z,
    w:this.obj.scale.x,h:this.obj.scale.y,d:this.obj.scale.z,rx:this.obj.rotation.x,ry:this.obj.rotation.y,rz:this.obj.rotation.z}}}
  class Obj{constructor(){this.children=[];this.position=new V;this.rotation=new V;this.scale=new V(1,1,1);this.matrix=new M(this);this.visible=true}
    updateMatrix(){}
    add(...c){this.children.push(...c)}
    remove(...c){this.children=this.children.filter(x=>!c.includes(x))}
  }
  class Geo{constructor(){this.type='geometry'}dispose(){}}
  class BG extends Geo{constructor(){super();this.attributes={};this.indices=[];this.type='BufferGeometry'}
    setAttribute(key,v){this.attributes[key]=v}setIndex(v){this.indices=v}computeVertexNormals(){this.hasNormals=true}}
  class UV{constructor(){this.count=4;this.data=[[0,0],[1,0],[0,1],[1,1]]}
    getX(i){return this.data[i][0]}getY(i){return this.data[i][1]}
    setXY(i,x,y){this.data[i]=[x,y]}}
  class Plane extends Geo{constructor(){super();this.attributes={uv:new UV()}}}
  class BufferAttr{constructor(data,itemSize){this.data=data;this.itemSize=itemSize;this.count=data.length/itemSize}}
  class Path{constructor(){this.holes=[]}moveTo(){}lineTo(){}absarc(){}closePath(){}}
  class Shape extends Path{}
  class Material{constructor(o){this.color=o.color||null;this.emissiveIntensity=o.emissiveIntensity||0;this.roughness=o.roughness;this.metalness=o.metalness}dispose(){}}
  class Mesh extends Obj{constructor(geo,mat){super();this.geometry=geo;this.material=mat;this.isMesh=true}}
  class Inst extends Mesh{constructor(geo,mat,count){super(geo,mat);this.count=count;this.matrices=[];this.instanceMatrix={needsUpdate:false};this.isInstancedMesh=true}
    setMatrixAt(i,v){this.matrices[i]=typeof v.clone==='function'?v.clone():v}}
  class Texture{constructor(){this.colorSpace=null}dispose(){}}
  return {Group:Obj,Object3D:Obj,Vector2:V,BoxGeometry:Geo,CylinderGeometry:Geo,TorusGeometry:Geo,
    Shape,Path,ExtrudeGeometry:Geo,LatheGeometry:Geo,BufferGeometry:BG,Float32BufferAttribute:BufferAttr,
    PlaneGeometry:Plane,Mesh,InstancedMesh:Inst,MeshLambertMaterial:Material,MeshStandardMaterial:Material,
    MeshBasicMaterial:Material,CanvasTexture:Texture,DoubleSide:2,SRGBColorSpace:'srgb'}
}
function canvasMock(){
  const labels=[]
  return {labels,createElement:(tag)=>({width:0,height:0,getContext:()=>({
    fillRect(){},strokeRect(){},fillText(v){labels.push(v)},set fillStyle(v){},set strokeStyle(v){},
    set lineWidth(v){},set font(v){},set textAlign(v){}
  })})}
}
function run(settings){
  const doc=canvasMock(),ctx={window:{},document:doc,console}
  vm.createContext(ctx);vm.runInContext(rules,ctx);vm.runInContext(source,ctx)
  const T=threeMock(),scene=new T.Group()
  const kit=ctx.window.ZION030_STREET_ATELIER.install({THREE:T,scene,rules:ctx.window.ZION030_CITY_RULES,...settings})
  const start=kit.stats
  assert.equal(start.version,'33.0')
  assert.equal(start.tier,settings.softwareGL?'LITE':settings.mobile?'MOBILE':'ULTRA')
  assert.ok(start.decoratedBuildings>=60)
  assert.equal(start.arches,start.decoratedBuildings)
  assert.ok(start.windowFrames>100)
  assert.ok(start.entryDetails>300)
  assert.ok(start.instanceCount>400&&start.instanceCount<13000)
  assert.ok(start.drawBatches<55)
  assert.ok(start.shopSigns>=0&&start.shopSigns<=8)
  if(!settings.softwareGL)assert.equal(start.shopSigns,8)
  if(settings.softwareGL)assert.equal(start.shopSigns,0)
  const batches=[...scene.children[0].children,...scene.children[1].children].filter(x=>x.isInstancedMesh)
  assert.ok(batches.length>10)
  assert.ok(batches.every(b=>b.count===b.matrices.length&&b.matrices.every(
    m=>[m.x,m.y,m.z,m.w,m.h,m.d].every(Number.isFinite)&&m.w>0&&m.h>0&&m.d>0)))
  const car=new T.Group()
  const basePaint=new T.Mesh(new T.BoxGeometry(),new T.MeshStandardMaterial({color:1}))
  car.add(basePaint)
  const avatar=new T.Group()
  kit.detailCar(car);kit.detailAvatar(avatar)
  assert.equal(kit.stats.vehicleCount,1)
  assert.equal(kit.stats.vehicleShells,1)
  assert.equal(kit.stats.animatedRims,4)
  assert.ok(kit.stats.vehicleAccentBatches<=8)
  assert.ok(kit.stats.characterParts>=5)
  const shell=car.children.find(x=>x.children?.some(c=>c.geometry?.type==='BufferGeometry'))
  assert.ok(shell)
  const body=shell.children.find(c=>c.geometry?.type==='BufferGeometry')
  assert.ok(body.geometry.attributes.position.count>=30)
  assert.ok(body.geometry.hasNormals)
  const rims=shell.children.find(c=>c.isInstancedMesh&&c.count===4)
  assert.ok(rims)
  const initial=[...rims.matrices.map(m=>m.rx)]
  car.position.set(2,0,-1)
  kit.update(.1)
  assert.ok(rims.matrices.some((m,i)=>m.rx!==initial[i]),'Vehicle wheel rims must rotate on movement')
  kit.setQuality('eco')
  assert.equal(kit.stats.fineVisible,false)
  kit.setQuality('high')
  assert.equal(kit.stats.fineVisible,!settings.mobile&&!settings.softwareGL)
  kit.syncEnvironment({raining:true,dayMode:1})
  assert.equal(kit.stats.raining,true)
  assert.equal(kit.stats.signLights,true)
  kit.syncEnvironment({raining:false,dayMode:0})
  assert.equal(kit.stats.raining,false)
  kit.dispose()
  assert.equal(scene.children.length,0)
  return {...start}
}
const ultra=run({mobile:false,softwareGL:false,reducedMotion:false})
const mobile=run({mobile:true,softwareGL:false,reducedMotion:false})
const lite=run({mobile:false,softwareGL:true,reducedMotion:true})
assert.ok(ultra.instanceCount>mobile.instanceCount&&mobile.instanceCount>=lite.instanceCount)
console.log('PASS ZION-030 v33: authentic street buildings, extruded arches, UV atlas, sculpted cars and animated wheels')
console.log(JSON.stringify({ultra,mobile,lite}))
