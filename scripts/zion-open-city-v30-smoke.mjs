import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';

const directory = path.resolve('public/games/zion-9/queue/ZION-030');
const code = fs.readFileSync(path.join(directory, 'open-city-details.js'),'utf8');
const rulesCode = fs.readFileSync(path.join(directory, 'open-city-rules.js'),'utf8');
const game = fs.readFileSync(path.join(directory, 'open-city.js'),'utf8');
const html = fs.readFileSync(path.join(directory, 'index.html'),'utf8');
new vm.Script(code,{filename:'open-city-details.js'});
assert.match(html, /open-city-details\.js\?v=30/);
assert.ok(html.indexOf('open-city-details.js?v=30') < html.indexOf('open-city.js?v=31'),'Detail kit must be loaded before main game');
assert.ok(game.includes('ZION030_DETAIL_KIT') && game.includes('detailKit.detailCar('),'Live scene must use advanced car models');
assert.ok(game.includes('detailKit.detailAvatar('),'Character detail must be integrated');
assert.ok(game.includes('detailKit?.setQuality('),'Graphics menu must dynamically control expensive details');

// Scene-graph double tests actual transform/matrix batching without WebGL.
function createThreeDouble(){
  class Vec { constructor(){this.x=0;this.y=0;this.z=0;} set(x,y,z){this.x=x;this.y=y;this.z=z;return this;} }
  class Matrix { constructor(owner){this.owner=owner;} clone(){return {x:this.owner.position.x,y:this.owner.position.y,z:this.owner.position.z,w:this.owner.scale.x,h:this.owner.scale.y,d:this.owner.scale.z};} }
  class Object3D {
    constructor(){this.children=[];this.position=new Vec();this.scale=new Vec().set(1,1,1);this.rotation=new Vec();this.matrix=new Matrix(this);this.visible=true;}
    add(...nodes){this.children.push(...nodes);}
    updateMatrix(){}
  }
  class Group extends Object3D {}
  class Geometry {constructor(...args){this.parameters={width:args[0],height:args[1]};this.type='BoxGeometry';}dispose(){}}
  class BoxGeometry extends Geometry {}
  class PlaneGeometry extends Geometry {constructor(...args){super(...args);this.type='PlaneGeometry';}}
  class Material {constructor(options){this.options=options;this.color={setHex:()=>{}};}dispose(){}}
  class Mesh extends Object3D {constructor(geom,material){super();this.geometry=geom;this.material=material;this.isMesh=true;}}
  class InstancedMesh extends Mesh {constructor(geom,mat,count){super(geom,mat);this.count=count;this.matrices=[];this.instanceMatrix={needsUpdate:false};}setMatrixAt(index,matrix){this.matrices[index]=matrix;}}
  return {Group,BoxGeometry,PlaneGeometry,Object3D,Mesh,InstancedMesh,MeshLambertMaterial:Material,MeshStandardMaterial:Material,
    ConeGeometry:Geometry,CylinderGeometry:Geometry,IcosahedronGeometry:Geometry,SRGBColorSpace:'srgb',RepeatWrapping:'repeat',CanvasTexture:class{}};
}
function scenario(config){
  const ctx={window:{},console};
  vm.createContext(ctx);
  vm.runInContext(rulesCode,ctx);
  vm.runInContext(code,ctx);
  const T=createThreeDouble();
  const scene=new T.Group();
  const kit=ctx.window.ZION030_DETAIL_KIT.install({THREE:T,scene,rules:ctx.window.ZION030_CITY_RULES,...config});
  const first=kit.stats;
  assert.equal(first.version,'30.0');
  assert.ok(first.buildings>30,'Center should have detailed buildings');
  assert.ok(first.windows>100,'All modes need real recessed windows');
  assert.equal(first.chargingPoints,3);
  assert.ok(first.streetObjects>100,'Street furnishing should have geometry');
  assert.ok(first.foliage>0);
  assert.ok(first.batchedDrawCalls<=45,'Instancing must keep one draw call per geometry/material bucket');
  assert.ok(first.instances<40000,'Procedural geometry must have a strict memory budget');
  for(const group of scene.children)for(const mesh of group.children){
    assert.equal(mesh.count,mesh.matrices.length,'Instancing count must match matrix allocation');
    assert.ok(mesh.matrices.every(m=>[m.x,m.y,m.z,m.w,m.h,m.d].every(Number.isFinite)&&m.w>0&&m.h>0&&m.d>0),'No invalid transforms');
  }
  const car=new T.Group();kit.detailCar(car);
  const avatar=new T.Group();kit.detailAvatar(avatar);
  assert.ok(kit.stats.carDetails>6 && kit.stats.characterDetails>=4,'Details should extend live vehicles/characters');
  kit.setQuality('eco');
  assert.equal(scene.children[1].visible,false,'Eco must disable dense near-LOD geometry');
  kit.setQuality('high');
  assert.equal(scene.children[1].visible,first.tier==='ULTRA','Ultra must be enabled only on high-capability devices');
  return {...kit.stats, meshes:scene.children.reduce((n,g)=>n+g.children.length,0)};
}
const desktop=scenario({mobile:false,reducedMotion:false,softwareGL:false});
const mobile=scenario({mobile:true,reducedMotion:false,softwareGL:false});
const software=scenario({mobile:false,reducedMotion:true,softwareGL:true});
assert.ok(desktop.windows>mobile.windows && mobile.windows>=software.windows,'Visual LOD must scale with hardware');
assert.ok(desktop.instances>mobile.instances && mobile.instances>software.instances,'Mobile/software budgets must shrink');
assert.ok(desktop.balconies>0 && desktop.rooftopFixtures>0);
assert.ok(desktop.outerBuildings>0);
console.log('PASS ZION-030 v30 detail kit:',JSON.stringify({desktop,mobile,software}));