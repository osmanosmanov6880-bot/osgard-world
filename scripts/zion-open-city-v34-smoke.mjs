import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import vm from 'node:vm'
import {execFileSync} from 'node:child_process'

const root=path.resolve('public/games/zion-9/queue/ZION-030')
const read=name=>fs.readFileSync(path.join(root,name),'utf8')
const art=read('open-city-pbr34.js'),post=read('open-city-postfx34.js'),perf=read('open-city-perf34.js')
const rules=read('open-city-rules.js'),entry=read('index.html'),core=read('open-city.js')
for(const filename of ['open-city-pbr34.js','open-city-postfx34.js','open-city-perf34.js']){
  new vm.Script(read(filename),{filename})
  execFileSync(process.execPath,['--check',path.join(root,filename)],{stdio:'pipe'})
  assert.ok(entry.includes(filename+'?v=34'),filename+' must be loaded by the actual game')
  assert.ok(entry.indexOf(filename+'?v=34')<entry.indexOf('open-city.js?v=34'))
}
assert.ok(entry.includes('open-city-v34.css?v=34'))
for(const anchor of ['atelierKit?.update(dt)','postFxKit.render(time*.001)',
  'perfKit?.beginRender()','perfKit?.endRender(frameMark)',
  'atelier: atelierKit?.stats ?? null','postfx: postFxKit?.stats ?? null',
  'perf: perfKit?.snapshot() ?? null','window.__ZION030_PERFORMANCE__=perfKit||null']){
  assert.ok(core.includes(anchor),'Missing integrated game feature: '+anchor)
}
for(const anchor of ['gpuRenderMsP95','hardwareClassification','WEBGL_debug_renderer_info',
  'EXT_disjoint_timer_query_webgl2','renderFPS','benchmarkValid']){
  assert.ok(perf.includes(anchor),'Missing evidence field: '+anchor)
}
for(const anchor of ['uInvRes','vignette','bloom','setRenderTarget','WebGLRenderTarget']){
  assert.ok(post.includes(anchor),'Missing postprocess feature: '+anchor)
}
execFileSync(process.execPath,['--check',path.resolve('scripts/zion-030-live-assets.mjs')],{stdio:'pipe'})
assert.ok(fs.readFileSync('scripts/zion-030-live-assets.mjs','utf8').includes("'open-city-postfx34.js'"))

class V {
  constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}
  set(x,y,z){this.x=x;this.y=y;this.z=z;return this}
}
class Matrix {
  constructor(o){this.o=o}
  clone(){const t=this.o;return{x:t.position.x,y:t.position.y,z:t.position.z,
    w:t.scale.x,h:t.scale.y,d:t.scale.z,rx:t.rotation.x,ry:t.rotation.y,rz:t.rotation.z}}
}
class Obj {
  constructor(){this.children=[];this.position=new V();this.rotation=new V();this.scale=new V(1,1,1);this.matrix=new Matrix(this);this.visible=true;this.name=''}
  add(...args){this.children.push(...args)}
  remove(...args){this.children=this.children.filter(x=>!args.includes(x))}
  updateMatrix(){}
}
class Geo{dispose(){}}
class Material{constructor(opts){Object.assign(this,opts);this.needsUpdate=false}dispose(){}}
class Mesh extends Obj{constructor(g,m){super();this.geometry=g;this.material=m;this.isMesh=true}}
class Inst extends Mesh{
  constructor(g,m,count){super(g,m);this.count=count;this.matrices=[];this.instanceMatrix={needsUpdate:false};this.isInstancedMesh=true}
  setMatrixAt(i,m){this.matrices[i]=typeof m.clone==='function'?m.clone():m}
}
class CanvasTex {
  constructor(canvas){this.canvas=canvas;this.repeat={set(x,y){this.x=x;this.y=y}};this.colorSpace=null;this.anisotropy=1}
  dispose(){}
}
const Three={Scene:Obj,Group:Obj,Object3D:Obj,Vector2:V,BoxGeometry:Geo,CylinderGeometry:Geo,
  IcosahedronGeometry:Geo,TorusGeometry:Geo,Mesh,InstancedMesh:Inst,
  MeshStandardMaterial:Material,MeshLambertMaterial:Material,CanvasTexture:CanvasTex,
  RepeatWrapping:'repeat',SRGBColorSpace:'srgb',NoColorSpace:'none'};
const documentMock={createElement:()=>{
  const canvas={width:0,height:0};
  canvas.getContext=()=>({createImageData:(w,h)=>({data:new Uint8ClampedArray(w*h*4)}),putImageData(){}});
  return canvas;
}};
function runArt(opts){
  const ctx={window:{},document:documentMock,console};vm.createContext(ctx);
  vm.runInContext(rules,ctx);vm.runInContext(art,ctx);
  const street=new Obj;street.name='ZION33 street-level stone and storefronts';
  for(const key of ['limestone','plaster','bronze','metal']){
    const mesh=new Mesh(new Geo(),new Material({roughness:.7}));
    mesh.name='ZION33 / '+key+' / box';street.add(mesh);
  }
  const scene=new Obj();scene.add(street);
  const kit=ctx.window.ZION030_ATELIER_PBR.install({THREE:Three,scene,
    rules:ctx.window.ZION030_CITY_RULES,...opts});
  const metrics=kit.stats;
  assert.equal(metrics.version,'34.0')
  assert.ok(metrics.facadeDetails>300)
  assert.ok(metrics.roadDetails>=0)
  assert.ok(metrics.windActors>=1)
  assert.ok(metrics.meshInstances>200)
  assert.ok(metrics.drawCallBatches>5&&metrics.drawCallBatches<55)
  assert.equal(metrics.litFixtures,metrics.facadeDetails>200?136:0,'Two luminous strips for each of the 68 facades')
  assert.ok(metrics.kineticDrawCallBatches<=105,'GPU batching required for moving foliage, turbines and banners')
  assert.ok(metrics.treeCrowns>50,'Volumetric animated canopy assets exist')
  assert.ok(scene.children.some(c=>c.name==='ZION34 / human-scale ground architecture'))
  if(opts.softwareGL){
    assert.equal(metrics.tier,'LITE')
    assert.equal(metrics.textureMaps,0)
    assert.equal(metrics.mappedMaterials,0)
  }else{
    assert.equal(metrics.textureMaps,9)
    assert.equal(metrics.surfaceFamilies,3)
    assert.ok(metrics.mappedMaterials>=3)
    assert.ok(metrics.estimatedTextureBytes>=96*96*4*9)
  }
  assert.ok(metrics.rotatingFans>=0)
  if(!opts.softwareGL)assert.ok(metrics.wetRipples>0)
  kit.setQuality('eco')
  assert.equal(kit.stats.highVisible,false)
  for(const mesh of street.children)assert.equal(mesh.material.map??null,null)
  kit.setQuality('high')
  assert.equal(kit.stats.highVisible,!opts.mobile&&!opts.softwareGL)
  if(!opts.softwareGL)assert.ok(street.children[0].material.map)
  kit.syncEnvironment({raining:true,dayMode:1})
  assert.equal(kit.stats.rain,true)
  assert.equal(kit.stats.night,true)
  kit.update(.07);kit.update(.08)
  if(!opts.reducedMotion)assert.ok(kit.stats.windRadians>0)
  kit.dispose()
  assert.equal(scene.children.length,1)
  for(const mesh of street.children)assert.equal(mesh.material.map??null,null)
  return metrics
}
const ultra=runArt({mobile:false,softwareGL:false,reducedMotion:false})
const mobile=runArt({mobile:true,softwareGL:false,reducedMotion:false})
const lite=runArt({mobile:false,softwareGL:true,reducedMotion:true})
assert.ok(ultra.meshInstances>mobile.meshInstances)
assert.ok(mobile.meshInstances>=lite.meshInstances)

class Target{constructor(){this.texture={};this.width=2;this.height=2}setSize(w,h){this.width=w;this.height=h}dispose(){}}
class Shader extends Material{}
class Camera extends Obj{}
const FxThree={...Three,WebGLRenderTarget:Target,ShaderMaterial:Shader,
  OrthographicCamera:Camera,PlaneGeometry:Geo,LinearFilter:1,LinearSRGBColorSpace:'linear'};
function runPost(opts){
  const context={window:{},console};vm.createContext(context);vm.runInContext(post,context);
  const renderer={
    renders:[],target:null,
    setRenderTarget(t){this.target=t},getRenderTarget(){return this.target},
    getDrawingBufferSize(v){return v.set(3800,2100)},
    render(scene,camera){this.renders.push({scene,camera,target:this.target})}
  };
  const kit=context.window.ZION030_POSTFX.create({THREE:FxThree,
    scene:new Obj,camera:new Obj,renderer,...opts});
  const enabled=!opts.softwareGL&&!opts.mobile&&!opts.reducedMotion;
  assert.equal(kit.stats.enabled,enabled)
  const result=kit.render(1)
  assert.equal(result,enabled)
  assert.equal(renderer.renders.length,enabled?2:1)
  if(enabled){
    assert.ok(kit.stats.width<=2048&&kit.stats.height<=1536)
    assert.equal(kit.stats.postFrames,1)
  }
  kit.setQuality('eco')
  assert.equal(kit.stats.enabled,false)
  kit.render(2);assert.equal(kit.stats.renderedFrames,2)
  kit.syncEnvironment({raining:true,dayMode:1})
  kit.dispose()
  return kit.stats
}
const postUltra=runPost({mobile:false,softwareGL:false,reducedMotion:false})
const postMobile=runPost({mobile:true,softwareGL:false,reducedMotion:false})
const postLite=runPost({mobile:false,softwareGL:true,reducedMotion:true})
console.log('PASS ZION-030 v34: procedural PBR atlases, moving props, bounded postFX, hardware profiling contracts and LOD')
console.log(JSON.stringify({ultra,mobile,lite,postUltra,postMobile,postLite}))
