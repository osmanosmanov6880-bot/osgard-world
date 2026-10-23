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
import {mountArtifactAtelier} from './artifact-atelier.mjs';
import {makeCinematicPipeline,detectAdapter} from './cinematic-postfx.mjs';
import {makeFrameBudget} from './frame-budget.mjs';
import {makeAdaptiveResolution} from './adaptive-resolution.mjs';
import {mountHardwareBenchmark} from './hardware-benchmark-ui.mjs';
(()=>{
'use strict';
const d=document,el=(s,root=d)=>root.querySelector(s),game=window.InheritGame;
if(!game||typeof game.snapshot!=='function')return;
const world=el('#world'),island=el('#island'),objects=el('#objects');
if(!world||!island||!objects)return;
// One on-demand close-up studio: detailed artifact inspection without
// consuming a move or creating another always-on render loop.
mountArtifactAtelier({dock:el('.dock.cine-dock')||el('.dock')});
const memory=(typeof navigator.deviceMemory==='number'?navigator.deviceMemory:8);
const lowPower=memory<=3||window.matchMedia('(max-width:700px)').matches;
const motion=window.matchMedia('(prefers-reduced-motion:reduce)');
const ELEVATION=.67,ORTHO_HEIGHT=29,MAX_SAVED=lowPower?150:420;
let quality=lowPower?'low':'high';
const strings={
 ru:{label:'РЕАЛЬНЫЙ 3D • ЖИВОЙ ОСТРОВ',mode3d:'3D включён',mode2d:'2D карта',orbit:'Кинооблёт',orbitBusy:'Камера в движении',qualityHigh:'Качество: максимум',qualityMedium:'Качество: баланс',qualityLow:'Качество: экономия',enabled:'Объёмный мир включён',disabled:'Двумерная карта включена',unavailable:'WebGL недоступен — оставлена обычная карта',flyby:'Камера показывает остров. Размещение временно приостановлено.',continue:'Можно снова строить мир',hint:'Все предметы и поколения — из вашей настоящей игры'},
 en:{label:'REAL 3D • LIVING ISLAND',mode3d:'3D enabled',mode2d:'2D map',orbit:'Cinematic flyover',orbitBusy:'Camera moving',qualityHigh:'Quality: high',qualityMedium:'Quality: balanced',qualityLow:'Quality: efficient',enabled:'3D world enabled',disabled:'2D map enabled',unavailable:'WebGL unavailable — native map retained',flyby:'Camera flyover. Placement pauses temporarily.',continue:'You can build again',hint:'Every object and generation comes from the real game'},
 zh:{label:'真实3D • 生机岛屿',mode3d:'3D已启用',mode2d:'2D地图',orbit:'电影环绕',orbitBusy:'镜头移动中',qualityHigh:'画质：高',qualityMedium:'画质：均衡',qualityLow:'画质：省电',enabled:'3D世界已启用',disabled:'2D地图已启用',unavailable:'不支持WebGL，保留原始地图',flyby:'镜头环绕期间暂停放置',continue:'可以继续建造',hint:'物件和世代均来自真实存档'}
};
function lang(){const v=window.InheritUI?.getLanguage?.()||d.documentElement.lang?.slice(0,2)||'ru';return strings[v]?v:'ru';}
function words(){return strings[lang()];}
function make(tag,cls){const node=d.createElement(tag);node.className=cls;return node;}
const controls=make('div','aaa3d-controls');controls.setAttribute('role','group');
controls.setAttribute('aria-label','3D world controls');
const heading=make('span','aaa3d-brand');
const switcher=make('button','aaa3d-switch'),orbit=make('button','aaa3d-orbit'),detail=make('button','aaa3d-quality'),effects=make('button','aaa3d-fx');
const monitor=make('button','aaa3d-monitor');
const metrics=make('output','aaa3d-metrics');metrics.hidden=true;
const live=make('span','aaa3d-live');live.setAttribute('role','status');live.setAttribute('aria-live','polite');
for(const btn of [switcher,orbit,detail,effects,monitor])btn.type='button';
controls.append(heading,switcher,orbit,detail,effects,monitor,live,metrics);
// Keep the 3D control rail OUTSIDE the island: a formerly absolute overlay
// intercepted genuine Legacy, research and Atlas buttons on both viewports.
world.parentElement.insertBefore(controls,world);
const canvas=make('canvas','aaa3d-canvas');canvas.setAttribute('aria-hidden','true');
canvas.setAttribute('tabindex','-1');canvas.style.pointerEvents='none';
island.prepend(canvas);
const status={available:false,active:false,postFX:'off',adapter:null,materials:null,ambientLife:null,performance:null,frames:0,traces:0,generation:null,quality,season:'',fallback:null,flyby:false,renderer:'WebGL Three.js',detailTiers:{high:0,medium:0,low:0},detailTriangles:0,detailDrawCalls:0,cachedTraces:0,createdTraces:0,heritageDetails:null,coastDetails:null,microclimate:null,surf:null,environmentTier:null,cameraFocus:'island'};
const frameBudget=makeFrameBudget();
const autoResolution=makeAdaptiveResolution();
window.InheritAAA3D=Object.freeze({
 getState:()=>({...status}),
 getHardwareBenchmark:()=>perfLab?.report()||null,
 startHardwareBenchmark:options=>perfLab?.start(options)||false,
 getPerformanceReport:()=>({...frameBudget.snapshot(),adapter:status.adapter,
  quality,statusPostFX:status.postFX,materials:status.materials,ambientLife:status.ambientLife,microclimate:status.microclimate,adaptiveResolution:autoResolution.snapshot()}),
 samplePerformance:async({minFrames=36,maxWaitMs=10000}={})=>{
  const start=performance.now(),frames=frameBudget.snapshot().samples;
  return new Promise(resolve=>{
   const poll=()=>{
    if(frameBudget.snapshot().samples-frames>=minFrames||performance.now()-start>=maxWaitMs||!status.active)
     return resolve(window.InheritAAA3D.getPerformanceReport());
    setTimeout(poll,110);
   };poll();
  });
 },
 toggle:()=>switcher.click()
});
let renderer,scene,camera,staticWorld,traceRoot,sun,hemi,cold,adapter=null,pipeline=null,postWanted=false,adaptivePixelScale=1,monitorOpen=false,lastMetricsUpdate=0,perfLab=null;
let waterUniforms,raf=0,lastFrame=0,sceneVisible=true,modeEnabled=true,flybyStart=0,flyby=false;
let signature='',lastSeason='',aspect=1.84,firstDraw=false;
const traceCache=new Map(); // Reuse unchanged sculpted meshes across generations and building moves.
const sceneryCache=new Map(); // Only two explicit quality tiers; no per-frame rebuilding.
const raycaster=new THREE.Raycaster(),pointer=new THREE.Vector2();
const preferences=()=>{try{return localStorage.getItem('inherit:3d:v1')}catch{return null}};
const savePreference=val=>{try{localStorage.setItem('inherit:3d:v1',val)}catch{}};
const fxLabels={
 ru:{on:'Киноэффекты: вкл',off:'Киноэффекты: выкл'},
 en:{on:'Cinematic FX: on',off:'Cinematic FX: off'},
 zh:{on:'电影特效：开',off:'电影特效：关'}
};
function configurePostFx(){
 if(!renderer||!scene||!camera)return;
 pipeline?.dispose?.();
 pipeline=makeCinematicPipeline({renderer,scene,camera,quality,adapter,wanted:postWanted});
 status.postFX=pipeline.mode;
 pipeline.setSeason?.(lastSeason||'tide');
 const width=Math.max(2,island.clientWidth),height=Math.max(2,island.clientHeight);
 pipeline.resize(width,height,renderer.getPixelRatio());
}
function notify(message){live.textContent=message;}
function updateLabels(){
 const t=words();
 heading.textContent=t.label;switcher.textContent=status.active?t.mode3d:t.mode2d;
 switcher.setAttribute('aria-pressed',String(status.active));
 switcher.setAttribute('aria-label',status.active?t.mode2d:t.mode3d);
 detail.textContent=quality==='high'?t.qualityHigh:quality==='medium'?t.qualityMedium:t.qualityLow;
 effects.textContent=postWanted?fxLabels[lang()].on:fxLabels[lang()].off;
 effects.disabled=!status.available;
 effects.setAttribute('aria-pressed',String(postWanted));
 monitor.textContent=monitorOpen?'FPS ✕':'FPS';
 monitor.setAttribute('aria-pressed',String(monitorOpen));
 monitor.setAttribute('aria-label',lang()==='ru'?'Показать замеры FPS':lang()==='zh'?'显示帧率测量':'Show measured FPS');
 detail.setAttribute('aria-pressed',String(quality==='high'));
 orbit.textContent=flyby?t.orbitBusy:t.orbit;
 orbit.disabled=!status.active||flyby||motion.matches;
 orbit.title=flyby?t.flyby:t.hint;
 perfLab?.update();
}
function setMode(enabled,reason){
 const next=!!enabled&&status.available;
 status.active=next;modeEnabled=next;status.fallback=reason||null;
 island.classList.toggle('aaa3d-active',next);
 world.classList.toggle('aaa3d-active',next);
 if(!next){perfLab?.finish('2d-switch');stop();}
 else{
  resize();syncState(true);renderOnce(performance.now());start();
 }
 updateLabels();
 notify(next?words().enabled:reason?words().unavailable:words().disabled);
}
function resize(){
 if(!renderer||!camera||!scene||!status.available)return;
 if(perfLab?.running())perfLab.finish('viewport-resized');
 const width=Math.max(2,Math.floor(island.clientWidth));
 const height=Math.max(2,Math.floor(island.clientHeight));
 aspect=width/height;
 camera.left=-ORTHO_HEIGHT*aspect/2;camera.right=ORTHO_HEIGHT*aspect/2;
 camera.top=ORTHO_HEIGHT/2;camera.bottom=-ORTHO_HEIGHT/2;
 camera.updateProjectionMatrix();
 const baseRatio=quality==='high'?Math.min(window.devicePixelRatio||1,1.6):quality==='medium'?Math.min(window.devicePixelRatio||1,1.25):Math.min(window.devicePixelRatio||1,1);
 renderer.setPixelRatio(Math.max(.7,baseRatio*adaptivePixelScale));
 renderer.setSize(width,height,false);
 pipeline?.resize(width,height,renderer.getPixelRatio());
 const previous=signature;signature='';if(previous)syncState(true);
 renderOnce(performance.now());
}
function seasonFromDOM(){return ['tide','sun','wind','mist'].includes(world.dataset.livingSeason)?world.dataset.livingSeason:'tide';}
function updateEnvironment(){
 if(!scene||!sun||!hemi||!renderer||!waterUniforms)return;
 const season=seasonFromDOM();if(season===lastSeason)return;
 lastSeason=season;status.season=season;
 const palettes={
  tide:{sky:0x739e9c,sun:0xffe4b7,water:.42,power:2.4,exposure:1.09},
  sun:{sky:0x9cbbb0,sun:0xffe0a2,water:.91,power:3.15,exposure:1.20},
  wind:{sky:0x7d9d9c,sun:0xece7ca,water:.45,power:2.15,exposure:1.06},
  mist:{sky:0x8caaa6,sun:0xdde6d7,water:.20,power:1.60,exposure:.94}
 };
 const p=palettes[season];pipeline?.setSeason?.(season);scene.background.setHex(p.sky);
 scene.fog.color.setHex(p.sky);sun.color.setHex(p.sun);sun.intensity=p.power;
 hemi.intensity=season==='mist'?1.7:2.2;
 renderer.toneMappingExposure=p.exposure;
 waterUniforms.uDawn.value=p.water;
 if(waterUniforms.uWind)waterUniforms.uWind.value=season==='wind'?1.28:season==='mist'?.17:.62;
 const seasonalScene=sceneryCache.get(status.environmentTier);
 seasonalScene?.setSeason?.(season);
 status.coastDetails=seasonalScene?.microBiomes?.stats?.()||status.coastDetails;
 status.microclimate=seasonalScene?.microclimate?.stats?.()||status.microclimate;
 status.surf=seasonalScene?.surf?.stats?.()||status.surf;
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
 const counts={high:0,medium:0,low:0};
 const visible=new Set(),occur=new Map();
 let triangles=0,drawCalls=0,activeLanterns=0,reused=0,created=0;
 function release(object){
  const orphan=new THREE.Group();orphan.add(object);
  disposeTraces(orphan); // Dispose merged GPU buffers, retain shared PBR maps.
 }
 for(let i=0;i<items.length;i++){
  const o=items[i],p=screenToTerrain(o.x,o.y,aspect,ORTHO_HEIGHT,ELEVATION);
  const tier=tiers.get(i)||'low';
  const lightAllowed=o.tool==='light'&&quality==='high'&&activeLanterns<2&&tier==='high';
  if(lightAllowed)activeLanterns++;
  const tuple=o.tool+'|'+o.x.toFixed(3)+'|'+o.y.toFixed(3);
  const ordinal=occur.get(tuple)||0;occur.set(tuple,ordinal+1);
  const cacheKey=tuple+'|'+ordinal;
  const shapeKey=tier+'|'+(quality==='high'?'shadows':'simple')+'|'+(lightAllowed?'lit':'unlit');
  visible.add(cacheKey);
  let value=traceCache.get(cacheKey);
  if(value?.userData.shapeKey!==shapeKey){
   if(value)release(value);
   value=makeTrace(o.tool,{
    size:o.tool==='tree'?.61:o.tool==='arch'?.72:.86,cast:quality==='high',
    quality:tier,seed:(173+Math.round(o.x*173+o.y*311)+i*19)>>>0,allowLight:lightAllowed
   });
   value.userData.shapeKey=shapeKey;
   traceCache.set(cacheKey,value);
   traceRoot.add(value);created++;
  }else reused++;
  value.position.set(p.x,p.y+.06,p.z);
  value.userData.nativeTrace={tool:o.tool,x:o.x,y:o.y};
  value.userData.detailTier=tier;
  value.rotation.y=((i*0.6180339887)%1)*Math.PI*2;
  counts[tier]++;
  triangles+=value.userData.detailTriangles||0;
  drawCalls+=value.userData.detailDrawCalls||value.children.filter(c=>c.isMesh).length;
 }
 for(const [cacheKey,node] of traceCache){
  if(!visible.has(cacheKey)){release(node);traceCache.delete(cacheKey);}
 }
 status.cachedTraces=reused;
 status.createdTraces=created;
 status.detailTiers=counts;
 status.detailTriangles=triangles;
 status.detailDrawCalls=drawCalls;
 status.traces=items.length;
 status.generation=current?.generation??null;
 updateEnvironment();
}
function activateScenery(tier){
 if(!scene)return;
 if(staticWorld)scene.remove(staticWorld);
 let built=sceneryCache.get(tier);
 if(!built){
  built=makeArchipelago({quality:tier});
  sceneryCache.set(tier,built);
 }
 staticWorld=built.root;waterUniforms=built.waterUniforms;
 scene.add(staticWorld);
 status.heritageDetails=built.heritage?.userData?.assetStats||null;
 status.coastDetails=built.microBiomes?.stats?.()||null;
 status.microclimate=built.microclimate?.stats?.()||null;
 status.surf=built.surf?.stats?.()||null;
 status.environmentTier=tier;
 status.materials=built.surfaceStats;
 status.ambientLife=built.life?.stats()||null;
 lastSeason='';updateEnvironment();
}
const FLYBY_VIEWS=[
 {t:0,eye:[0,39,50],focus:[0,0,0],name:'island'},
 {t:.26,eye:[-27,22,19],focus:[-14,2.9,-9],name:'sanctuary'},
 {t:.46,eye:[-17,14,8],focus:[-14,3.2,-9],name:'sanctuary'},
 {t:.73,eye:[27,20,29],focus:[18,-.5,10],name:'harbor'},
 {t:.88,eye:[34,13,20],focus:[26,-1.3,12],name:'skiff'},
 {t:1,eye:[0,39,50],focus:[0,0,0],name:'island'}
];
const flyEye=new THREE.Vector3(),flyFocus=new THREE.Vector3();
function applyFlyby(time){
 const t=Math.min((time-flybyStart)/9300,1);
 if(t>=1)return false;
 let i=0;while(i<FLYBY_VIEWS.length-2&&t>FLYBY_VIEWS[i+1].t)i++;
 const a=FLYBY_VIEWS[i],b=FLYBY_VIEWS[i+1];
 const raw=(t-a.t)/(b.t-a.t),ease=raw*raw*(3-2*raw);
 flyEye.set(...a.eye).lerp(new THREE.Vector3(...b.eye),ease);
 flyFocus.set(...a.focus).lerp(new THREE.Vector3(...b.focus),ease);
 camera.position.copy(flyEye);camera.lookAt(flyFocus);
 status.cameraFocus=ease<.5?a.name:b.name;
 return true;
}
function cameraAtDefault(){
 camera.position.set(0,Math.sin(ELEVATION)*63,Math.cos(ELEVATION)*63);
 camera.lookAt(0,0,0);camera.updateMatrixWorld();
}
function renderOnce(time){
 if(!renderer||!scene||!camera||!status.available||!status.active||!sceneVisible||d.hidden||d.body.classList.contains('aaa-atelier-open'))return;
 if(waterUniforms&&!motion.matches)waterUniforms.uTime.value=time*.001;
 updateEnvironment();
 const active=sceneryCache.get(status.environmentTier);
 active?.life?.update(motion.matches?0:time,lastSeason,renderer.getPixelRatio());
 active?.microBiomes?.update(motion.matches?0:time);
 active?.microclimate?.update(motion.matches?0:time,{pixelRatio:renderer.getPixelRatio(),reducedMotion:motion.matches});
 active?.surf?.update(time,{reducedMotion:motion.matches});
 renderer.info.reset();
 perfLab?.startFrame(time);
 const cpuStart=performance.now();
 if(pipeline)pipeline.render(time,Math.min(.08,Math.max(.008,(time-lastFrame)/1000||.033)),motion.matches);
 else renderer.render(scene,camera);
 const cpuSubmissionMs=performance.now()-cpuStart;
 perfLab?.endFrame(time,cpuSubmissionMs);
 frameBudget.record(time,cpuSubmissionMs,renderer,renderer.getPixelRatio());
 status.performance=frameBudget.snapshot();
 status.ambientLife=active?.life?.stats()||null;
 if(monitorOpen&&time-lastMetricsUpdate>1050){
  lastMetricsUpdate=time;
  const p=status.performance;
  const fmt=v=>Number.isFinite(v)?v.toFixed(1):'—';
  metrics.textContent='FPS '+fmt(p.fps)+
   ' · p95 '+fmt(p.frameIntervalP95Ms)+' мс'+
   ' · CPU '+fmt(p.cpuSubmissionP95Ms)+' мс'+
   ' · draw '+(p.renderer?.calls??'—')+
   ' · tris '+(p.renderer?.triangles??'—')+
   ' · '+(status.adapter?.isSoftware?'SwiftShader / software GPU':'GPU: '+(status.adapter?.model||'unknown'));
 }
 status.frames+=1;firstDraw=true;
 // R20 real-device adaptive pixel ratio: sustained measured frame pacing
 // with an eight-second cooldown. No changes to saved traces or quality tier.
 // Schedule resize after the GPU submission completes (never nested render).
 const step=autoResolution.observe({
  now:time,quality,metrics:status.performance,
  visible:sceneVisible&&!d.hidden,reducedMotion:motion.matches,
  benchmark:!!perfLab?.running()||flyby
 });
 if(step){
  adaptivePixelScale=step.scale;
  queueMicrotask(()=>{
   if(status.available&&status.active&&!d.hidden)resize();
  });
 }
}
function stop(){if(raf)cancelAnimationFrame(raf);raf=0;}
function shouldRun(){return status.active&&(sceneVisible||perfLab?.running())&&!d.hidden&&!d.body.classList.contains('aaa-atelier-open')&&(flyby||!motion.matches);}
window.addEventListener('aaa-atelier-open',stop);
window.addEventListener('aaa-atelier-close',()=>{renderOnce(performance.now());start();});
function nextFrame(time){
 raf=0;
 if(!shouldRun())return;
 const target=perfLab?.running()?0:flyby?33:quality==='high'?33:quality==='medium'?38:48;
 if(time-lastFrame>=target){
  lastFrame=time;
  if(perfLab?.running())perfLab.moveCamera(time);
  if(flyby){
   if(!applyFlyby(time)){
    flyby=false;status.flyby=false;status.cameraFocus='island';
    cameraAtDefault();notify(words().continue);updateLabels();
   }
  }
  syncState();renderOnce(time);
 }
 if(shouldRun())raf=requestAnimationFrame(nextFrame);
}
function start(){if(!raf&&shouldRun())raf=requestAnimationFrame(nextFrame);}
function doFlyby(){
 if(flyby||perfLab?.running()||motion.matches||!status.active)return;
 flyby=true;status.flyby=true;flybyStart=performance.now();
 notify(words().flyby);updateLabels();start();
}
switcher.addEventListener('click',()=>{
 if(!status.available)return;
 savePreference(status.active?'2d':'3d');setMode(!status.active);
});
detail.addEventListener('click',()=>{
 perfLab?.finish('quality-changed');
 quality=quality==='high'?'medium':quality==='medium'?'low':'high';status.quality=quality;
 adaptivePixelScale=1;frameBudget.reset();autoResolution.reset(performance.now());
 renderer.shadowMap.enabled=quality==='high'&&!lowPower;
 sun.castShadow=renderer.shadowMap.enabled;
 activateScenery(quality);configurePostFx();resize();syncState(true);
 renderOnce(performance.now());updateLabels();
});
orbit.addEventListener('click',doFlyby);
effects.addEventListener('click',()=>{
 if(!status.available)return;
 perfLab?.finish('effects-changed');
 postWanted=!postWanted;configurePostFx();renderOnce(performance.now());updateLabels();
});
monitor.addEventListener('click',()=>{
 monitorOpen=!monitorOpen;metrics.hidden=!monitorOpen;
 lastMetricsUpdate=0;renderOnce(performance.now());updateLabels();
});
// User-origin mouse clicks must not accidentally place traces during a camera tour.
world.addEventListener('click',event=>{
 if(!flyby&&!perfLab?.running())return;
 if(event.target instanceof Element&&event.target.closest('#island')){
  event.preventDefault();event.stopImmediatePropagation();
 }
},true);
// Select the REAL native trace inspector when the user directly clicks a
// rendered 3D object. The raycaster never writes the world or spends a move.
world.addEventListener('click',event=>{
 if(!status.active||flyby||perfLab?.running()||d.body.classList.contains('replay-mode')||!camera||!traceRoot||!(event.target instanceof Element)||
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
d.addEventListener('visibilitychange',()=>{if(d.hidden){perfLab?.finish('tab-hidden');stop();}else start();});
motion.addEventListener?.('change',()=>{updateLabels();if(motion.matches){perfLab?.finish('reduced-motion');stop();renderOnce(performance.now());}else start();});
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
 renderer.info.autoReset=false;
 adapter=detectAdapter(renderer);status.adapter=adapter;
 // Hosted Linux Chrome often runs SwiftShader; don't make its first scene
 // pay the cost of a hardware-tier diorama. User can opt into high details.
 if(adapter.isSoftware&&quality==='high'){
  quality='low';status.quality='low';
  renderer.shadowMap.enabled=false;
 }
 postWanted=quality==='high'&&!lowPower&&!adapter.isSoftware;
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
 activateScenery(quality);
 traceRoot=new THREE.Group();traceRoot.name='Actual saved traces';scene.add(traceRoot);
 status.available=true;
 configurePostFx();
 perfLab=mountHardwareBenchmark({
  controls,renderer,camera,
  quality:()=>quality,postFX:()=>status.postFX,
  viewport:()=>({width:island.clientWidth|0,height:island.clientHeight|0}),
  adapter,active:()=>status.active,reducedMotion:()=>motion.matches,
  busy:()=>flyby||d.body.classList.contains('replay-mode')||d.body.classList.contains('aaa-atelier-open'),
  requestFrame:()=>{renderOnce(performance.now());start();},notify,localize:lang
 });
 resize();
 setMode(preferences()!=='2d');
}catch(error){
 status.available=false;status.fallback='no-webgl';
 status.active=false;modeEnabled=false;
 try{perfLab?.dispose?.();pipeline?.dispose?.();renderer?.dispose?.();}catch{}
 renderer=null;camera=null;scene=null;traceRoot=null;waterUniforms=null;pipeline=null;
 island.classList.remove('aaa3d-active');world.classList.remove('aaa3d-active');
 canvas.remove();
 orbit.disabled=true;detail.disabled=true;switcher.disabled=true;
 updateLabels();notify(words().unavailable);
 console.warn('INHERIT: native 2D fallback, WebGL renderer unavailable',error?.message||error);
}
})();
