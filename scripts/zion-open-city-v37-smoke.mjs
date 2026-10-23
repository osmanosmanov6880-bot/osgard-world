/* ZION-030 v37 executable tests:
 * Triple-scale mineral PBR, real-city material patching, quality restoration,
 * instanced contact shadows, glazing and fail-closed CC0 photo fallback.
 * Graphics measured in a real browser by separate Playwright/GPU tests.
 */
import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
import {execFileSync} from 'node:child_process'

const root='public/games/zion-9/queue/ZION-030/'
const art=fs.readFileSync(root+'open-city-photoreal37.js','utf8')
const rules=fs.readFileSync(root+'open-city-rules.js','utf8')
const core=fs.readFileSync(root+'open-city.js','utf8')
const html=fs.readFileSync(root+'index.html','utf8')
const manifest=fs.readFileSync('scripts/zion-030-live-assets.mjs','utf8')
new vm.Script(art,{filename:'open-city-photoreal37.js'})
execFileSync(process.execPath,['--check',root+'open-city-photoreal37.js'])
assert.ok(html.includes('open-city-photoreal37.js?v=37'))
assert.ok(html.indexOf('open-city-photoreal37.js?v=37')<html.indexOf('open-city.js?v=34'))
assert.ok(manifest.includes("'open-city-photoreal37.js'"))
for(const contract of [
  'ZION030_PHOTOREAL37.install','photorealKit?.activate?.()','photorealKit?.setQuality(world.quality)',
  'photorealKit?.syncEnvironment(','photorealKit?.update(dt)',
  'photoreal:photorealKit?.stats ?? null',
  "photorealKit?.setQuality('adaptive')"
])assert.ok(core.includes(contract),'Missing playable scene binding '+contract)
assert.ok(art.includes('https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/'))
assert.ok(art.includes('photoTextureErrors')||art.includes('photoTexturesLoaded'))
assert.ok(art.includes('disposed')&&art.includes('dispose()'))

class V {
  constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}
  set(x,y,z=0){this.x=x;this.y=y;this.z=z;return this}
}
class Color {
  constructor(value=0){this.value=value}
  clone(){return new Color(this.value)}
  copy(other){this.value=other.value;return this}
  set(hex){this.value=hex;return this}
  setHex(hex){this.value=hex;return this}
}
class Object3D {
  constructor(){
    this.children=[];this.name='';this.visible=true;this.position=new V();
    this.rotation=new V();this.scale=new V(1,1,1);this.material=null;
    const self=this
    this.matrix={clone:()=>({position:{...self.position},
      rotation:{...self.rotation},scale:{...self.scale}})}
  }
  add(...x){this.children.push(...x)}
  remove(...x){this.children=this.children.filter(c=>!x.includes(c))}
  updateMatrix(){}
}
class G {dispose(){this.disposed=true}}
class M {
  constructor(o={}){
    Object.assign(this,o)
    this.color=new Color(o.color)
    this.normalMap=o.normalMap??null
    this.roughnessMap=o.roughnessMap??null
    this.map=o.map??null
    this.roughness=o.roughness??.8
    this.metalness=o.metalness??.1
    this.envMapIntensity=o.envMapIntensity??1
  }
  dispose(){this.disposed=true}
}
class Mesh extends Object3D{
  constructor(geo,material){super();this.geometry=geo;this.material=material;this.isMesh=true}
}
class Inst extends Mesh{
  constructor(geo,material,n){
    super(geo,material);this.count=n;this.matrices=[]
    this.instanceMatrix={needsUpdate:false}
  }
  setMatrixAt(index,matrix){this.matrices[index]=matrix}
}
class Texture{
  constructor(c){this.canvas=c;this.repeat={set(a,b){this.x=a;this.y=b}}}
  dispose(){this.disposed=true}
}
const THREE={
  Group:Object3D,Object3D,Mesh,InstancedMesh:Inst,CanvasTexture:Texture,
  MeshStandardMaterial:M,MeshPhysicalMaterial:M,MeshBasicMaterial:M,
  PlaneGeometry:G,BoxGeometry:G,CylinderGeometry:G,Vector2:V,
  SRGBColorSpace:'srgb',NoColorSpace:'none',RepeatWrapping:'repeat',
  DoubleSide:2
}
const document={
  createElement(){
    const c={width:0,height:0}
    c.getContext=()=>({
      createImageData:(w,h)=>({data:new Uint8ClampedArray(w*h*4)}),
      putImageData(){},fillRect(){},
      createRadialGradient(){return{addColorStop(){}}}
    })
    return c
  }
}
function run(options){
  const context={window:{},document,console}
  vm.createContext(context)
  vm.runInContext(rules,context)
  vm.runInContext(art,context)
  const scene=new Object3D()
  const originalMats=[
    new M({color:0x223344,map:'road old'}),
    new M({color:0xeeeecc,map:'plaza old'}),
    new M({color:0xaabbcc,map:'facade old'}),
    new M({color:0x556677,map:'stucco old'})
  ]
  const add=(name,material,parent=scene)=>{
    const mesh=new Mesh(new G(),material);mesh.name=name;parent.add(mesh)
    return mesh
  }
  add('ZION35 asphalt surface',originalMats[0])
  add('ZION35 plaza surface',originalMats[1])
  const street=new Object3D();street.name='ZION33 street-level stone and storefronts'
  scene.add(street)
  add('ZION33 / limestone / arch',originalMats[2],street)
  add('ZION33 / plaster / box',originalMats[3],street)
  const vehicleMesh=new Object3D()
  const carBody=new M({color:0x1a9cba,roughness:.3,metalness:.68})
  const carGlass=new M({color:0x091b25,roughness:.12,metalness:.08})
  const heroBody=new Mesh(new G(),carBody),heroGlass=new Mesh(new G(),carGlass)
  const sculptedShell=new Mesh(new G(),carBody)
  vehicleMesh.add(heroBody,heroGlass,sculptedShell)
  const car={mesh:vehicleMesh}
  const renderer={capabilities:{getMaxAnisotropy:()=>8},toneMappingExposure:1.42}
  const keyLight={intensity:2.45,color:new Color(0xffd4a4)}
  const hemi={intensity:2.25},blueFill={intensity:.9}
  const kit=context.window.ZION030_PHOTOREAL37.install({
    THREE,scene,renderer,rules:context.window.ZION030_CITY_RULES,
    car,keyLight,hemi,blueFill,...options
  })
  assert.equal(kit.stats.version,'37.0')
  assert.equal(kit.stats.photoLoadingStarted,false)
  assert.equal(kit.activate(),false)
  assert.equal(kit.stats.sourceLicense,'Poly Haven CC0')
  assert.equal(kit.stats.originalPhotoSources,3)
  assert.equal(kit.stats.photoTexturesLoaded,0)
  assert.equal(kit.stats.livePatchedMaterials,options.softwareGL||options.reducedMotion?0:4)
  assert.equal(kit.stats.proceduralTextureMaps,options.softwareGL||options.reducedMotion?0:9)
  assert.equal(kit.stats.materialFamilies,options.softwareGL||options.reducedMotion?0:3)
  assert.equal(kit.stats.tier,options.softwareGL||options.reducedMotion?'LITE':options.mobile?'MOBILE':'ULTRA')
  if(!options.softwareGL&&!options.reducedMotion){
    assert.equal(kit.stats.vehicleClearcoatMeshes,2)
    assert.equal(kit.stats.vehicleGlassMeshes,1)
    assert.notEqual(heroBody.material,carBody)
    assert.notEqual(heroGlass.material,carGlass)
    assert.equal(sculptedShell.material,heroBody.material)
    assert.equal(kit.stats.contactShadows,68)
    assert.ok(kit.stats.heroGlassPanels>150)
    assert.ok(kit.stats.drawBatches>=2&&kit.stats.drawBatches<=5)
    assert.ok(originalMats[0].map instanceof Texture)
    kit.syncEnvironment({raining:true,dayMode:1})
    assert.equal(kit.stats.rain,true)
    assert.equal(kit.stats.night,true)
    assert.ok(renderer.toneMappingExposure<1.1)
    kit.setQuality('eco')
    assert.equal(kit.stats.highVisible,false)
    assert.equal(originalMats[0].map,'road old')
    kit.setQuality('high')
    assert.equal(kit.stats.highVisible,true)
    assert.ok(originalMats[0].map instanceof Texture)
    kit.update(.08)
    assert.ok(kit.stats.animationTicks>0)
  }else{
    assert.equal(kit.stats.highVisible,false)
    assert.equal(kit.stats.photoTexturesLoaded,0)
  }
  const metrics={...kit.stats}
  kit.dispose()
  assert.equal(renderer.toneMappingExposure,1.42)
  assert.equal(heroBody.material,carBody)
  assert.equal(heroGlass.material,carGlass)
  assert.equal(sculptedShell.material,carBody)
  assert.equal(scene.children.length,3)
  assert.equal(originalMats[0].map,'road old')
  assert.equal(originalMats[1].map,'plaza old')
  assert.equal(originalMats[2].map,'facade old')
  assert.equal(originalMats[3].map,'stucco old')
  return metrics
}
const ultra=run({mobile:false,softwareGL:false,reducedMotion:false})
const mobile=run({mobile:true,softwareGL:false,reducedMotion:false})
const lite=run({mobile:false,softwareGL:true,reducedMotion:true})
assert.equal(ultra.estimatedTextureBytes,512*512*4*9)
assert.equal(mobile.estimatedTextureBytes,256*256*4*9)
assert.equal(lite.estimatedTextureBytes,0)
assert.equal(lite.proceduralTextureMaps,0)
console.log('PASS ZION-030 v37: physically based materials, 3 families, layered normals, glazing, contact shadows, ECO/mobile fallback and original-state cleanup')
console.log(JSON.stringify({ultra,mobile,lite}))
