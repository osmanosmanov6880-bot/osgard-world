/* INHERIT R16 — TRUE 3D WORLD (THREE.js/WebGL).
 * Original generation state is authoritative. This view never places objects,
 * changes currency, writes saves or sends requests. User clicks still flow
 * through the existing #world game handler and its account permission gates.
 * No CDN or runtime asset downloads. Graceful 2D fallback on GPU failure.
 */
import * as THREE from 'three';
import {screenToTerrain,stableObjects,worldStateSignature,ISLAND_SEED} from './terrain-core.mjs';
import {makeArchipelago} from './world-geometry.mjs';
import {makeTrace,disposeTraces} from './trace-models.mjs';
(()=>{
'use strict';
const d=document,el=(s,root=d)=>root.querySelector(s),game=window.InheritGame;
if(!game||typeof game.snapshot!=='function')return;
const world=el('#world'),island=el('#island'),objects=el('#objects');
if(!world||!island||!objects)return;
const memory=(typeof navigator.deviceMemory==='number'?navigator.deviceMemory:8);
const lowPower=memory<=3||window.matchMedia('(max-width:700px)').matches;
const motion=window.matchMedia('(prefers-reduced-motion:reduce)');
const ELEVATION=.67,ORTHO_HEIGHT=29,MAX_SAVED=lowPower?150:420;
let quality=lowPower?'low':'high';
const strings={
 ru:{label:'РЕАЛЬНЫЙ 3D • ЖИВОЙ ОСТРОВ',mode3d:'3D включён',mode2d:'2D карта',orbit:'Кинооблёт',orbitBusy:'Камера в движении',qualityHigh:'Качество: максимум',qualityLow:'Качество: экономия',enabled:'Объёмный мир включён',disabled:'Двумерная карта включена',unavailable:'WebGL недоступен — оставлена обычная карта',flyby:'Камера показывает остров. Размещение временно приостановлено.',continue:'Можно снова строить мир',hint:'Все предметы и поколения — из вашей настоящей игры'},
 en:{label:'REAL 3D • LIVING ISLAND',mode3d:'3D enabled',mode2d:'2D map',orbit:'Cinematic flyover',orbitBusy:'Camera moving',qualityHigh:'Quality: high',qualityLow:'Quality: efficient',enabled:'3D world enabled',disabled:'2D map enabled',unavailable:'WebGL unavailable — native map retained',flyby:'Camera flyover. Placement pauses temporarily.',continue:'You can build again',hint:'Every object and generation comes from the real game'},
 zh:{label:'真实3D • 生机岛屿',mode3d:'3D已启用',mode2d:'2D地图',orbit:'电影环绕',orbitBusy:'镜头移动中',qualityHigh:'画质：高',qualityLow:'画质：省电',enabled:'3D世界已启用',disabled:'2D地图已启用',unavailable:'不支持WebGL，保留原始地图',flyby:'镜头环绕期间暂停放置',continue:'可以继续建造',hint:'物件和世代均来自真实存档'}
};
function lang(){const v=window.InheritUI?.getLanguage?.()||d.documentElement.lang?.slice(0,2)||'ru';return strings[v]?v:'ru';}
function words(){return strings[lang()];}
function make(tag,cls){const node=d.createElement(tag);node.className=cls;return node;}
const controls=make('div','aaa3d-controls');controls.setAttribute('role','group');
controls.setAttribute('aria-label','3D world controls');
const heading=make('span','aaa3d-brand');
const switcher=make('button','aaa3d-switch'),orbit=make('button','aaa3d-orbit'),detail=make('button','aaa3d-quality');
const live=make('span','aaa3d-live');live.setAttribute('role','status');live.setAttribute('aria-live','polite');
for(const btn of [switcher,orbit,detail])btn.type='button';
controls.append(heading,switcher,orbit,detail,live);world.append(controls);
const canvas=make('canvas','aaa3d-canvas');canvas.setAttribute('aria-hidden','true');
canvas.setAttribute('tabindex','-1');canvas.style.pointerEvents='none';
island.prepend(canvas);
const status={available:false,active:false,frames:0,traces:0,generation:null,quality,season:'',fallback:null,flyby:false,renderer:'WebGL Three.js',detailTiers:{high:0,medium:0,low:0},detailTriangles:0,detailDrawCalls:0};
window.InheritAAA3D=Object.freeze({getState:()=>({...status}),toggle:()=>switcher.click()});
let renderer,scene,camera,staticWorld,traceRoot,sun,hemi,cold;
let waterUniforms,raf=0,lastFrame=0,sceneVisible=true,modeEnabled=true,flybyStart=0,flyby=false;
let signature='',lastSeason='',aspect=1.84,firstDraw=false;
const raycaster=new THREE.Raycaster(),pointer=new THREE.Vector2();
const preferences=()=>{try{return localStorage.getItem('inherit:3d:v1')}catch{return null}};
const savePreference=val=>{try{localStorage.setItem('inherit:3d:v1',val)}catch{}};
function notify(message){live.textContent=message;}
function updateLabels(){
 const t=words();
 heading.textContent=t.label;switcher.textContent=status.active?t.mode3d:t.mode2d;
 switcher.setAttribute('aria-pressed',String(status.active));
 switcher.setAttribute('aria-label',status.active?t.mode2d:t.mode3d);
 detail.textContent=quality==='high'?t.qualityHigh:t.qualityLow;
 detail.setAttribute('aria-pressed',String(quality==='high'));
 orbit.textContent=flyby?t.orbitBusy:t.orbit;
 orbit.disabled=!status.active||flyby||motion.matches;
 orbit.title=flyby?t.flyby:t.hint;
}
function setMode(enabled,reason){
 const next=!!enabled&&status.available;
 status.active=next;modeEnabled=next;status.fallback=reason||null;
 island.classList.toggle('aaa3d-active',next);
 world.classList.toggle('aaa3d-active',next);
 if(!next)stop();
 else{
  resize();syncState(true);renderOnce(performance.now());start();
 }
 updateLabels();
 notify(next?words().enabled:reason?words().unavailable:words().disabled);
}
function resize(){
 if(!renderer||!camera)return;
 const width=Math.max(2,Math.floor(island.clientWidth));
 const height=Math.max(2,Math.floor(island.clientHeight));
 aspect=width/height;
 camera.left=-ORTHO_HEIGHT*aspect/2;camera.right=ORTHO_HEIGHT*aspect/2;
 camera.top=ORTHO_HEIGHT/2;camera.bottom=-ORTHO_HEIGHT/2;
 camera.updateProjectionMatrix();
 renderer.setPixelRatio(quality==='high'?Math.min(window.devicePixelRatio||1,1.6):Math.min(window.devicePixelRatio||1,1));
 renderer.setSize(width,height,false);
 const previous=signature;signature='';if(previous)syncState(true);
 renderOnce(performance.now());
}
function seasonFromDOM(){return ['tide','sun','wind','mist'].includes(world.dataset.livingSeason)?world.dataset.livingSeason:'tide';}
function updateEnvironment(){
 const season=seasonFromDOM();if(season===lastSeason)return;
 lastSeason=season;status.season=season;
 const palettes={
  tide:{sky:0x739e9c,sun:0xffe4b7,water:.42,power:2.4,exposure:1.09},
  sun:{sky:0x9cbbb0,sun:0xffe0a2,water:.91,power:3.15,exposure:1.20},
  wind:{sky:0x7d9d9c,sun:0xece7ca,water:.45,power:2.15,exposure:1.06},
  mist:{sky:0x8caaa6,sun:0xdde6d7,water:.20,power:1.60,exposure:.94}
 };
 const p=palettes[season];scene.background.setHex(p.sky);
 scene.fog.color.setHex(p.sky);sun.color.setHex(p.sun);sun.intensity=p.power;
 hemi.intensity=season==='mist'?1.7:2.2;
 renderer.toneMappingExposure=p.exposure;
 waterUniforms.uDawn.value=p.water;
}
function syncState(force=false){
 if(!game.snapshot)return;
 let current;try{current=game.snapshot()}catch{return}
 // The history Atlas renders past traces inside the native #objects element
 // without changing the authoritative current save. Mirror *that* read-only
 // historical display while replay is active instead of showing today's 3D.
 const replay=d.body.classList.contains('replay-mode');
 if(replay){
  const shown=[...objects.querySelectorAll('.placed')].map(btn=>{
   const tool=['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']
    .find(type=>btn.classList.contains(type));
   return {tool,x:Number.parseFloat(btn.style.left),y:Number.parseFloat(btn.style.top)};
  });
  const replayInfo=el('#replay-copy')?.textContent||'';
  const number=replayInfo.match(/\d+/)?.[0];
  current={...current,
    generation:number!==undefined?Number(number):current.generation,
    objects:shown
  };
 }
 const next=worldStateSignature(current)+(replay?'|history':'|present');
 if(!force&&next===signature)return;
 signature=next;
 const items=stableObjects(current,MAX_SAVED);
 // Prioritize the objects closest to the visible center, not the oldest save.
 // GPU draw calls are bounded: deep sculpting near camera, medium detail behind
 // it, lightweight legacy meshes in dense worlds and on lower-power devices.
 const detailBudget=quality==='high'
  ?(lowPower?{high:7,medium:19}:{high:30,medium:70})
  :(lowPower?{high:0,medium:0}:{high:0,medium:14});
 const sorted=items.map((o,i)=>({i,dist:Math.hypot((o.x-50)*1.0,(o.y-46)*1.12)}))
  .sort((a,b)=>a.dist-b.dist||a.i-b.i);
 const tiers=new Map();
 sorted.forEach((item,rank)=>{
  tiers.set(item.i,rank<detailBudget.high?'high':rank<detailBudget.high+detailBudget.medium?'medium':'low');
 });
 disposeTraces(traceRoot);
 const counts={high:0,medium:0,low:0};
 let triangles=0,drawCalls=0,activeLanterns=0;
 for(let i=0;i<items.length;i++){
  const o=items[i],p=screenToTerrain(o.x,o.y,aspect,ORTHO_HEIGHT,ELEVATION);
  const tier=tiers.get(i)||'low';
  const lightAllowed=o.tool==='light'&&quality==='high'&&activeLanterns<2&&tier==='high';
  if(lightAllowed)activeLanterns++;
  const value=makeTrace(o.tool,{
   size:o.tool==='tree'?.61:o.tool==='arch'?.72:.86,cast:quality==='high',
   quality:tier,seed:(173+Math.round(o.x*173+o.y*311)+i*19)>>>0,allowLight:lightAllowed
  });
  value.position.set(p.x,p.y+.06,p.z);
  value.userData.nativeTrace={tool:o.tool,x:o.x,y:o.y};
  value.userData.detailTier=tier;
  value.rotation.y=((i*0.6180339887)%1)*Math.PI*2;
  traceRoot.add(value);
  counts[tier]++;
  triangles+=value.userData.detailTriangles||0;
  drawCalls+=value.userData.detailDrawCalls||value.children.filter(c=>c.isMesh).length;
 }
 status.detailTiers=counts;
 status.detailTriangles=triangles;
 status.detailDrawCalls=drawCalls;
 status.traces=items.length;
 status.generation=current?.generation??null;
 updateEnvironment();
}
function cameraAtDefault(){
 camera.position.set(0,Math.sin(ELEVATION)*63,Math.cos(ELEVATION)*63);
 camera.lookAt(0,0,0);camera.updateMatrixWorld();
}
function renderOnce(time){
 if(!renderer||!status.active||!sceneVisible||d.hidden)return;
 if(waterUniforms&&!motion.matches)waterUniforms.uTime.value=time*.001;
 updateEnvironment();
 renderer.render(scene,camera);
 status.frames+=1;firstDraw=true;
}
function stop(){if(raf)cancelAnimationFrame(raf);raf=0;}
function shouldRun(){return status.active&&sceneVisible&&!d.hidden&&(flyby||!motion.matches);}
function nextFrame(time){
 raf=0;
 if(!shouldRun())return;
 const target=flyby?33:quality==='high'?33:48;
 if(time-lastFrame>=target){
  lastFrame=time;
  if(flyby){
   const t=Math.min((time-flybyStart)/6500,1);
   if(t>=1){flyby=false;status.flyby=false;cameraAtDefault();notify(words().continue);updateLabels();}
   else{
    const ease=t*t*(3-2*t),angle=ease*Math.PI*2;
    camera.position.set(Math.sin(angle)*47,34+8*Math.sin(Math.PI*t),Math.cos(angle)*47);
    camera.lookAt(0,0,0);
   }
  }
  syncState();renderOnce(time);
 }
 if(shouldRun())raf=requestAnimationFrame(nextFrame);
}
function start(){if(!raf&&shouldRun())raf=requestAnimationFrame(nextFrame);}
function doFlyby(){
 if(flyby||motion.matches||!status.active)return;
 flyby=true;status.flyby=true;flybyStart=performance.now();
 notify(words().flyby);updateLabels();start();
}
switcher.addEventListener('click',()=>{
 if(!status.available)return;
 savePreference(status.active?'2d':'3d');setMode(!status.active);
});
detail.addEventListener('click',()=>{
 quality=quality==='high'?'low':'high';status.quality=quality;
 renderer.shadowMap.enabled=quality==='high'&&!lowPower;
 sun.castShadow=renderer.shadowMap.enabled;
 resize();syncState(true);renderOnce(performance.now());updateLabels();
});
orbit.addEventListener('click',doFlyby);
// User-origin mouse clicks must not accidentally place traces during a camera tour.
world.addEventListener('click',event=>{
 if(!flyby)return;
 if(event.target instanceof Element&&event.target.closest('#island')){
  event.preventDefault();event.stopImmediatePropagation();
 }
},true);
// Select the REAL native trace inspector when the user directly clicks a
// rendered 3D object. The raycaster never writes the world or spends a move.
world.addEventListener('click',event=>{
 if(!status.active||flyby||d.body.classList.contains('replay-mode')||!camera||!traceRoot||!(event.target instanceof Element)||
    !event.target.closest('#island')||event.target.closest('button,[data-memory]'))return;
 const rect=canvas.getBoundingClientRect();
 if(!rect.width||!rect.height)return;
 pointer.set((event.clientX-rect.left)/rect.width*2-1,1-(event.clientY-rect.top)/rect.height*2);
 if(Math.abs(pointer.x)>1||Math.abs(pointer.y)>1)return;
 raycaster.setFromCamera(pointer,camera);
 const hit=raycaster.intersectObjects(traceRoot.children,true)[0];
 if(!hit)return;
 let node=hit.object;
 while(node&&node.parent!==traceRoot)node=node.parent;
 const saved=node?.userData.nativeTrace;
 if(!saved)return;
 const target=[...objects.querySelectorAll('.placed')].find(btn=>{
  const x=Number.parseFloat(btn.style.left),y=Number.parseFloat(btn.style.top);
  return btn.classList.contains(saved.tool)&&Math.abs(x-saved.x)<.001&&Math.abs(y-saved.y)<.001;
 });
 if(target){
  event.preventDefault();event.stopImmediatePropagation();
  target.click(); // original owned game's non-mutating memory display
 }
},true);
d.addEventListener('visibilitychange',()=>{if(d.hidden)stop();else start();});
motion.addEventListener?.('change',()=>{updateLabels();if(motion.matches){stop();renderOnce(performance.now());}else start();});
new MutationObserver(()=>{syncState();if(status.active&&motion.matches)renderOnce(performance.now());})
 .observe(objects,{childList:true});
new MutationObserver(()=>{updateEnvironment();if(status.active&&motion.matches)renderOnce(performance.now());})
 .observe(world,{attributes:true,attributeFilter:['data-living-season']});
new MutationObserver(updateLabels).observe(d.documentElement,{attributes:true,attributeFilter:['lang']});
if('ResizeObserver'in window)new ResizeObserver(resize).observe(island);
else window.addEventListener('resize',resize,{passive:true});
if('IntersectionObserver'in window)new IntersectionObserver(entries=>{
 sceneVisible=!!entries[0]?.isIntersecting;
 if(sceneVisible){renderOnce(performance.now());start();}else stop();
},{threshold:0}).observe(island);
window.addEventListener('pagehide',stop);
window.addEventListener('pageshow',()=>{renderOnce(performance.now());start()});
canvas.addEventListener('webglcontextlost',event=>{
 event.preventDefault();status.available=false;setMode(false,'gpu-lost');
});
canvas.addEventListener('webglcontextrestored',()=>{status.available=true;setMode(preferences()!=='2d')});
try{
 renderer=new THREE.WebGLRenderer({canvas,alpha:true,antialias:quality==='high',powerPreference:quality==='high'?'high-performance':'low-power',preserveDrawingBuffer:false});
 renderer.outputColorSpace=THREE.SRGBColorSpace;
 renderer.toneMapping=THREE.ACESFilmicToneMapping;
 renderer.toneMappingExposure=1.1;
 renderer.shadowMap.enabled=quality==='high'&&!lowPower;
 renderer.shadowMap.type=THREE.PCFSoftShadowMap;
 scene=new THREE.Scene();scene.background=new THREE.Color(0x789f9f);
 scene.fog=new THREE.FogExp2(0x789f9f,.009);
 camera=new THREE.OrthographicCamera(-25,25,15,-15,.1,270);cameraAtDefault();
 hemi=new THREE.HemisphereLight(0xf1f5dd,0x2f514c,2.15);scene.add(hemi);
 sun=new THREE.DirectionalLight(0xffe2b0,2.7);
 sun.position.set(-25,48,-30);sun.castShadow=renderer.shadowMap.enabled;
 sun.shadow.mapSize.set(quality==='high'?1024:512,quality==='high'?1024:512);
 sun.shadow.camera.left=-30;sun.shadow.camera.right=30;sun.shadow.camera.top=31;sun.shadow.camera.bottom=-31;
 sun.shadow.camera.near=.1;sun.shadow.camera.far=125;
 sun.shadow.bias=-.00045;
 scene.add(sun);
 cold=new THREE.DirectionalLight(0xa2ccd0,.86);cold.position.set(25,12,12);scene.add(cold);
 const built=makeArchipelago({quality:lowPower?'low':quality});
 staticWorld=built.root;waterUniforms=built.waterUniforms;
 scene.add(staticWorld);
 traceRoot=new THREE.Group();traceRoot.name='Actual saved traces';scene.add(traceRoot);
 status.available=true;
 resize();
 setMode(preferences()!=='2d');
}catch(error){
 status.available=false;status.fallback='no-webgl';
 status.active=false;modeEnabled=false;
 island.classList.remove('aaa3d-active');world.classList.remove('aaa3d-active');
 canvas.remove();
 orbit.disabled=true;detail.disabled=true;switcher.disabled=true;
 updateLabels();notify(words().unavailable);
 console.warn('INHERIT: native 2D fallback, WebGL renderer unavailable',error?.message||error);
}
})();
