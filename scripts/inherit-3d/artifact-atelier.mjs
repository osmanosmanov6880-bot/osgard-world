/* INHERIT R16.3 / ARTIFACT ATELIER
 * A true, on-demand lit 3D inspection room for all ten saved prop types.
 * This is an optional read-only viewer. It never changes generations,
 * budgets, positions, permissions or the world save.
 */
import * as THREE from 'three';
import {makeTrace,disposeTraces} from './trace-models.mjs';

const TYPES=['tree','stone','light','path','flower','arch','chime','moss','cairn','marker'];
const GLYPHS=['♧','◆','✺','⌁','✿','⌂','♫','❧','▲','➤'];
const LOCALES={
 ru:{
  launch:'◈ Рассмотреть в 3D',eyebrow:'АРТ-МАСТЕРСКАЯ · РЕАЛЬНЫЙ WEBGL',
  title:'Каждая вещь хранит историю',
  subtitle:'Вращай настоящую объёмную модель, изучай материал и детали. Просмотр ничего не меняет в мире.',
  close:'Закрыть',rotate:'Перетащи для вращения · Колесо для масштаба',
  select:'Выбрать для острова',notReady:'Этот предмет доступен для просмотра; выбери его в каталоге игры',
  stamp:'ОРИГИНАЛЬНАЯ 3D-СКУЛЬПТУРА',material:'МАТЕРИАЛ',detail:'ГЕОМЕТРИЯ',
  geo:'треугольников',notWebGL:'Видеоустройство не поддерживает дополнительный 3D-просмотр. Играть в 2D можно как обычно.',
  selected:'Выбран предмет',items:{
   tree:['Древнее дерево','Многослойная крона, узлы коры, переплетённые корни и природный силуэт','Дерево · лиственная крона'],
   stone:['Камень берега','Минеральные прожилки, неровные сколы, лишайник и включения','Камень · лишайник'],
   light:['Фонарь памяти','Латунные соединения, стеклянные панели, пламенное свечение и защитная решётка','Латунь · стекло'],
   path:['Мощёная тропа','Отдельные плиты с потёртыми рёбрами, швами и моховой крошкой','Плиты · мох'],
   flower:['Цветущая поляна','Изогнутые стебли, прожилки листьев, отдельные лепестки и сердцевины','Лепестки · листва'],
   arch:['Древняя арка','Кладка из отдельных камней, замковый камень, трещины, мох и резьба','Известняк · бронза'],
   chime:['Колокольчики ветра','Подвесные цилиндры, шнуры, бронзовый отлив и деревянная траверса','Бронза · дерево'],
   moss:['Лесной мох','Влажные кочки, грибницы, лишайники и разноуровневый зелёный ковёр','Мох · грибницы'],
   cairn:['Каменная насыпь','Сложенные вручную глыбы, минералы и памятный обруч','Гранит · бронза'],
   marker:['Деревянный указатель','Резное дерево, кованые крепления, сколы краёв и символ наследия','Дерево · латунь']
  }
 },
 en:{
  launch:'◈ Inspect in 3D',eyebrow:'ARTIFACT ATELIER · REAL WEBGL',
  title:'Every object holds a story',
  subtitle:'Rotate real 3D geometry and examine material details. Inspection never modifies your world.',
  close:'Close',rotate:'Drag to rotate · Scroll to zoom',
  select:'Select for island',notReady:'Preview only; choose this item in the game catalog',
  stamp:'ORIGINAL 3D SCULPTURE',material:'MATERIAL',detail:'GEOMETRY',geo:'triangles',
  notWebGL:'An extra 3D preview cannot run on this device. The normal game remains available.',
  selected:'Selected',items:{
   tree:['Ancient tree','Layered canopy, textured bark and branching roots','Wood · foliage'],
   stone:['Coastal stone','Mineral veins, irregular chips and lichen','Stone · lichen'],
   light:['Legacy lantern','Brass joints, glass, a warm flame and a protective cage','Brass · glass'],
   path:['Stone pathway','Individual weathered paving stones, joints and moss','Stone · moss'],
   flower:['Flower meadow','Curved stalks, leaves, separate petals and floral centers','Flowers · foliage'],
   arch:['Ancient arch','Individual carved blocks, keystone and moss','Limestone · bronze'],
   chime:['Wind chimes','Suspended resonators, ropes, bronze and carved timber','Bronze · timber'],
   moss:['Woodland moss','Moist hummocks, fungi, lichen and a layered green carpet','Moss · fungi'],
   cairn:['Stone cairn','Hand-stacked rocks, mineral inclusions and a memorial ring','Granite · bronze'],
   marker:['Carved sign','Wood carving, fasteners, weathered edges and legacy marks','Timber · brass']
  }
 },
 zh:{
  launch:'◈ 3D检视',eyebrow:'遗产工坊 · 真实WEBGL',title:'每件物品都记录历史',
  subtitle:'旋转真实3D模型，观察材质和细节。预览不会改变你的世界。',
  close:'关闭',rotate:'拖动旋转 · 滚轮缩放',select:'选用于岛屿',
  notReady:'仅预览；请在游戏目录中选择物件',stamp:'原创3D模型',
  material:'材质',detail:'模型几何',geo:'三角形',
  notWebGL:'此设备不支持独立3D预览。原版游戏仍然可玩。',
  selected:'已选',items:{
   tree:['古树','层叠树冠、树皮纹理和根系','木材 · 树叶'],
   stone:['海岸石','矿物纹理、碎裂边缘与地衣','石头 · 地衣'],
   light:['传承灯笼','黄铜结构、玻璃和温暖火焰','黄铜 · 玻璃'],
   path:['石头小径','风化石板、缝隙和苔藓','石板 · 苔藓'],
   flower:['花田','弯曲茎叶和独立花瓣','花朵 · 绿叶'],
   arch:['古代拱门','雕刻石砖、拱顶石与苔藓','石灰岩 · 青铜'],
   chime:['风铃','铜铃、绳结和木梁','青铜 · 木材'],
   moss:['林间苔藓','苔藓丘、菌类和层叠绿色地毯','苔藓 · 菌类'],
   cairn:['石堆','层叠石块、矿物纹理与纪念圆环','花岗岩 · 青铜'],
   marker:['木制路牌','木雕、金属扣件和岁月痕迹','木材 · 黄铜']
  }
 }
};
function language(){
 const code=window.InheritUI?.getLanguage?.()||document.documentElement.lang?.slice(0,2)||'ru';
 return LOCALES[code]||LOCALES.ru;
}
function el(tag,cls,content){
 const node=document.createElement(tag);node.className=cls;
 if(content!==undefined)node.textContent=content;
 return node;
}
function safeSelected(){
 const active=document.querySelector('.tool[data-tool].active, [data-tool].tool[aria-pressed="true"]');
 const kind=active?.getAttribute('data-tool');
 return TYPES.includes(kind)?kind:'tree';
}
function makeStudio(){
 const scene=new THREE.Scene();scene.background=new THREE.Color(0x102b32);
 scene.fog=new THREE.FogExp2(0x102b32,.031);
 const camera=new THREE.PerspectiveCamera(42,1,.1,100);
 camera.position.set(6.7,4.6,7.4);camera.lookAt(0,1.8,0);
 const hemisphere=new THREE.HemisphereLight(0xf9efd8,0x32464b,2.1);
 const key=new THREE.DirectionalLight(0xffe3b1,3.65);
 key.position.set(-7,12,9);key.castShadow=true;
 key.shadow.mapSize.set(1024,1024);
 key.shadow.camera.left=-7;key.shadow.camera.right=7;
 key.shadow.camera.top=7;key.shadow.camera.bottom=-7;
 key.shadow.bias=-.0009;
 const fill=new THREE.DirectionalLight(0xb0d9e1,1.8);fill.position.set(6,6,-7);
 const rim=new THREE.DirectionalLight(0xf7d3a1,1.25);rim.position.set(0,8,-9);
 scene.add(hemisphere,key,fill,rim);
 const plinthMaterial=new THREE.MeshStandardMaterial({
  color:0x19383e,metalness:.57,roughness:.28
 });
 const edgeMaterial=new THREE.MeshStandardMaterial({
  color:0xe7bc79,metalness:.78,roughness:.24
 });
 const floorMaterial=new THREE.MeshStandardMaterial({
  color:0x163039,metalness:.18,roughness:.77
 });
 const floor=new THREE.Mesh(new THREE.PlaneGeometry(40,40),floorMaterial);
 floor.rotation.x=-Math.PI/2;floor.position.y=-.42;
 floor.receiveShadow=true;scene.add(floor);
 const plinth=new THREE.Mesh(new THREE.CylinderGeometry(2.16,2.2,.32,72),plinthMaterial);
 plinth.position.y=-.19;plinth.receiveShadow=true;scene.add(plinth);
 const trim=new THREE.Mesh(new THREE.TorusGeometry(2.12,.026,10,96),edgeMaterial);
 trim.rotation.x=Math.PI/2;trim.position.y=-.014;scene.add(trim);
 const innerTrim=new THREE.Mesh(new THREE.TorusGeometry(1.75,.012,8,96),edgeMaterial);
 innerTrim.rotation.x=Math.PI/2;innerTrim.position.y=-.016;scene.add(innerTrim);
 const podium=new THREE.Group();scene.add(podium);
 return {scene,camera,podium,target:new THREE.Vector3(0,1.65,0)};
}
export function mountArtifactAtelier({dock}={}){
 if(!dock||document.querySelector('.aaa-artifact-action'))return null;
 const tools=dock.querySelector('.tools')||dock;
 const launch=el('button','aaa-artifact-action');
 launch.type='button';launch.title=language().launch;launch.textContent=language().launch;
 launch.setAttribute('aria-haspopup','dialog');
 tools.append(launch);
 const dialog=el('dialog','aaa-atelier-dialog');
 dialog.setAttribute('aria-label',language().title);
 const shell=el('div','aaa-atelier-shell');
 const header=el('header','aaa-atelier-header');
 const heading=el('div','aaa-atelier-heading');
 const eyebrow=el('span','aaa-atelier-eyebrow');
 const title=el('h2','aaa-atelier-title');
 const subtitle=el('p','aaa-atelier-subtitle');
 heading.append(eyebrow,title,subtitle);
 const close=el('button','aaa-atelier-close','×');close.type='button';close.setAttribute('aria-label',language().close);
 header.append(heading,close);
 const content=el('div','aaa-atelier-content');
 const stage=el('div','aaa-atelier-stage');
 const canvas=el('canvas','aaa-atelier-canvas');canvas.setAttribute('aria-label','Interactive sculpted 3D artifact preview');
 const hint=el('div','aaa-atelier-hint');
 const fallback=el('p','aaa-atelier-fallback');fallback.hidden=true;
 stage.append(canvas,hint,fallback);
 const aside=el('aside','aaa-atelier-aside');
 const stamp=el('span','aaa-atelier-stamp');
 const itemTitle=el('h3','aaa-atelier-item-title');
 const description=el('p','aaa-atelier-description');
 const grid=el('div','aaa-atelier-grid');
 grid.setAttribute('role','group');grid.setAttribute('aria-label','Select item to inspect');
 const buttons=new Map();
 for(let i=0;i<TYPES.length;i++){
  const type=TYPES[i],btn=el('button','aaa-atelier-pick');
  btn.type='button';btn.dataset.tool=type;btn.setAttribute('aria-pressed','false');
  const symbol=el('b','aaa-atelier-symbol',GLYPHS[i]);
  const text=el('span','aaa-atelier-pick-name');
  btn.append(symbol,text);grid.append(btn);buttons.set(type,btn);
 }
 const stats=el('div','aaa-atelier-stats');
 const material=el('p','aaa-atelier-material');
 const triangles=el('p','aaa-atelier-triangles');
 stats.append(material,triangles);
 const commit=el('button','aaa-atelier-select');
 commit.type='button';
 const notice=el('div','aaa-atelier-notice');
 notice.setAttribute('role','status');notice.setAttribute('aria-live','polite');
 aside.append(stamp,itemTitle,description,grid,stats,commit,notice);
 content.append(stage,aside);shell.append(header,content);dialog.append(shell);document.body.append(dialog);
 const reduce=window.matchMedia('(prefers-reduced-motion: reduce)');
 const state={open:false,available:false,tool:'tree',frames:0,triangles:0,meshes:0,dragged:0};
 window.InheritArtifactAtelier=Object.freeze({getState:()=>({...state})});
 let renderer=null,room=null,current=null,raf=0,drag=null,lastFrame=0,automatic=0,aspect=1;
 function labels(){
  const t=language();launch.textContent=t.launch;launch.title=t.launch;
  eyebrow.textContent=t.eyebrow;title.textContent=t.title;subtitle.textContent=t.subtitle;
  close.setAttribute('aria-label',t.close);dialog.setAttribute('aria-label',t.title);
  stamp.textContent=t.stamp;hint.textContent=t.rotate;commit.textContent=t.select;
  fallback.textContent=t.notWebGL;
  for(const type of TYPES)buttons.get(type).querySelector('span').textContent=t.items[type][0];
  drawInfo();
 }
 function drawInfo(){
  const t=language(),info=t.items[state.tool];
  if(!info)return;
  itemTitle.textContent=info[0];description.textContent=info[1];
  material.textContent=t.material+'  ·  '+info[2];
  triangles.textContent=t.detail+'  ·  '+state.triangles.toLocaleString()+' '+t.geo;
  for(const [type,btn] of buttons)btn.setAttribute('aria-pressed',String(type===state.tool));
 }
 function resize(){
  if(!room||!renderer||!dialog.open)return;
  const width=Math.max(200,Math.floor(stage.clientWidth)),height=Math.max(210,Math.floor(stage.clientHeight));
  aspect=width/height;room.camera.aspect=aspect;room.camera.updateProjectionMatrix();
  renderer.setPixelRatio(Math.min(window.devicePixelRatio||1,1.5));
  renderer.setSize(width,height,false);
  drawOnce();
 }
 function drawOnce(){
  if(!renderer||!room||!dialog.open)return;
  renderer.render(room.scene,room.camera);state.frames++;
 }
 function loop(t){
  raf=0;if(!dialog.open||!renderer||!room||document.hidden)return;
  if(t-lastFrame>=34){
   lastFrame=t;
   if(!reduce.matches&&!drag&&current)current.rotation.y+=.006;
   drawOnce();
  }
  raf=requestAnimationFrame(loop);
 }
 function start(){
  if(!dialog.open||!renderer||document.hidden)return;
  // Reduced motion renders a still studio until the user explicitly drags,
  // picks a model or zooms. Do not waste a constant GPU animation loop.
  if(reduce.matches){drawOnce();return;}
  if(!raf)raf=requestAnimationFrame(loop);
 }
 function stop(){if(raf)cancelAnimationFrame(raf);raf=0;}
 function selectType(type){
  if(!TYPES.includes(type))return;
  state.tool=type;
  if(room){
   if(current){
    const old=new THREE.Group();old.add(current);disposeTraces(old);
    room.podium.remove(current);
   }
   // Detail is always HIGH here, regardless of mobile island quality, because
   // only one item is drawn. Batching retains ~5-14 PBR draw calls.
   const next=makeTrace(type,{quality:'high',cast:true,seed:173+TYPES.indexOf(type)*317,allowLight:type==='light'});
   const bounds=new THREE.Box3().setFromObject(next),box=new THREE.Vector3();
   bounds.getSize(box);
   const span=Math.max(box.x,box.y,box.z,.1);
   const magnification=THREE.MathUtils.clamp(4.6/span,.85,2.9);
   next.scale.multiplyScalar(magnification);
   const boxAfter=new THREE.Box3().setFromObject(next);
   next.position.y=-boxAfter.min.y+.02;
   room.podium.add(next);current=next;
   state.triangles=next.userData.detailTriangles||0;
   state.meshes=next.children.filter(c=>c.isMesh).length;
   room.camera.position.set(6.7,4.6,7.4);
   room.camera.lookAt(room.target);
   drawOnce();
  }else{
   state.triangles=0;state.meshes=0;
  }
  notice.textContent='';
  drawInfo();
 }
 function initRenderer(){
  if(renderer)return true;
  try{
   renderer=new THREE.WebGLRenderer({canvas,alpha:false,antialias:true,
      powerPreference:'high-performance',preserveDrawingBuffer:false});
   renderer.outputColorSpace=THREE.SRGBColorSpace;
   renderer.toneMapping=THREE.ACESFilmicToneMapping;
   renderer.toneMappingExposure=1.2;
   renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;
   room=makeStudio();state.available=true;
   fallback.hidden=true;canvas.hidden=false;return true;
  }catch(err){
   state.available=false;canvas.hidden=true;fallback.hidden=false;
   console.warn('INHERIT Artifact Atelier: 2D game remains available',err?.message||err);
   return false;
  }
 }
 function open(){
  labels();
  if(typeof dialog.showModal==='function')dialog.showModal();else dialog.setAttribute('open','');
  state.open=true;document.body.classList.add('aaa-atelier-open');
  window.dispatchEvent(new Event('aaa-atelier-open'));
  if(initRenderer()){selectType(safeSelected());resize();start();}
  else selectType(safeSelected());
  close.focus();
 }
 launch.addEventListener('click',open);
 close.addEventListener('click',()=>dialog.close());
 dialog.addEventListener('close',()=>{
  state.open=false;stop();document.body.classList.remove('aaa-atelier-open');
  window.dispatchEvent(new Event('aaa-atelier-close'));
  launch.focus();
 });
 dialog.addEventListener('click',event=>{if(event.target===dialog)dialog.close();});
 for(const [type,btn] of buttons)btn.addEventListener('click',()=>selectType(type));
 commit.addEventListener('click',()=>{
  const selector='.tool[data-tool="'+state.tool+'"]';
  const native=document.querySelector(selector);
  if(!native){notice.textContent=language().notReady;return;}
  native.click();notice.textContent=language().selected+' '+language().items[state.tool][0];
  dialog.close();
 });
 let ro=null;
 if('ResizeObserver' in window){ro=new ResizeObserver(()=>resize());ro.observe(stage);}
 else window.addEventListener('resize',resize,{passive:true});
 canvas.addEventListener('pointerdown',e=>{
  if(!state.available)return;
  drag={x:e.clientX,y:e.clientY};
  canvas.setPointerCapture?.(e.pointerId);
 });
 canvas.addEventListener('pointermove',e=>{
  if(!drag||!current)return;
  const delta=e.clientX-drag.x,dy=e.clientY-drag.y;
  current.rotation.y+=delta*.012;
  current.rotation.x=THREE.MathUtils.clamp(current.rotation.x+dy*.004,-.35,.35);
  drag={x:e.clientX,y:e.clientY};state.dragged++;drawOnce();
 });
 const pointerEnd=()=>{drag=null;};
 canvas.addEventListener('pointerup',pointerEnd);
 canvas.addEventListener('pointercancel',pointerEnd);
 canvas.addEventListener('wheel',e=>{
  if(!room||!dialog.open)return;
  e.preventDefault();
  const distance=room.camera.position.distanceTo(room.target);
  const next=THREE.MathUtils.clamp(distance*(e.deltaY>0?1.075:.925),5.5,18);
  room.camera.position.sub(room.target).multiplyScalar(next/distance).add(room.target);
  room.camera.lookAt(room.target);drawOnce();
 },{passive:false});
 canvas.addEventListener('webglcontextlost',e=>{
  e.preventDefault();stop();state.available=false;fallback.hidden=false;
  fallback.textContent=language().notWebGL;canvas.hidden=true;
 });
 canvas.addEventListener('webglcontextrestored',()=>{
  state.available=true;fallback.hidden=true;canvas.hidden=false;resize();start();
 });
 document.addEventListener('visibilitychange',()=>{if(document.hidden)stop();else start();});
 labels();return {button:launch,dialog};
}
