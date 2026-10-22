/* Browser-agnostic smoke with an instrumented WebGL2/DOM facade. Does not claim GPU quality. */
import assert from 'node:assert/strict';
import {readFileSync,existsSync} from 'node:fs';
import vm from 'node:vm';
import {resolve} from 'node:path';
const root=existsSync(resolve(import.meta.dirname,'omega-engine.js'))?resolve(import.meta.dirname):resolve(import.meta.dirname,'../public/games/time-omega-preview');
const script=readFileSync(resolve(root,'omega-engine.js'),'utf8');
const html=readFileSync(resolve(root,'index.html'),'utf8');
const css=readFileSync(resolve(root,'omega.css'),'utf8');
assert.ok(html.includes('Город ждёт')&&html.includes('ГОРОД 3D'));
assert.ok(html.includes('href="./strategy.html"'),'Old strategy must be preserved and linked');
assert.ok(html.includes('omega-engine.js')&&html.includes('omega.css'));
assert.ok(script.includes('constructFallbackCity()')&&script.includes('renderFallback('),'Canvas 2D fallback must actually render a city');
assert.ok(css.includes('.driving-hud')&&css.includes('@media(max-width:540px)'),'HUD and responsive mobile layout must exist');
assert.ok(readFileSync(resolve(root,'strategy.html'),'utf8').includes('Time Omega III'),'Original strategy must remain accessible');
assert.ok(!/https?:\/\/(?:cdn\.|unpkg\.)/.test(html+css+script),'No external game runtime allowed');
assert.ok(script.includes("getContext('webgl2'"));
assert.ok(script.includes('localStorage.setItem'));
assert.ok(script.includes('function groundCollision'));
assert.ok(script.includes('safeLoad()')&&script.includes('safeSave()'));
assert.ok(script.includes('function switchCar'));
assert.ok(script.includes('function completeMission'));
assert.ok(script.includes('function discoverSite'));
assert.ok(script.includes('function renderPanel'));
assert.ok(script.includes('function drawMap'));
assert.ok(script.includes('Math.abs(state.speed)<1.5'));
assert.ok(script.includes('state.owned.push(idx)'));
assert.ok(script.includes('function toggleSound'));
assert.ok(script.includes('function updateGame'));
assert.ok(script.includes('requestAnimationFrame(tickFrame)'));
let drawingCalls=0,staticUploaded=false,trace=[],raf;
const gl=new Proxy({
 VERTEX_SHADER:1,FRAGMENT_SHADER:2,COMPILE_STATUS:3,LINK_STATUS:4,ARRAY_BUFFER:5,STATIC_DRAW:6,DYNAMIC_DRAW:7,TRIANGLES:8,DEPTH_TEST:9,LEQUAL:10,CULL_FACE:11,COLOR_BUFFER_BIT:12,DEPTH_BUFFER_BIT:13,FLOAT:14,
 createShader:()=>({}),shaderSource(){},compileShader(){},getShaderParameter:()=>true,getShaderInfoLog:()=>'',createProgram:()=>({}),attachShader(){},linkProgram(){},getProgramParameter:()=>true,getProgramInfoLog:()=>'',useProgram(){},getUniformLocation:()=>({}),createVertexArray:()=>({}),createBuffer:()=>({}),bindVertexArray(){},bindBuffer(){},enableVertexAttribArray(){},vertexAttribPointer(){},enable(){},depthFunc(){},disable(){},clearColor(){},viewport(){},uniformMatrix4fv(_,__,mat){assert.ok(mat.every(Number.isFinite),'MVP should have no NaN')},uniform3fv(){},uniform1f(){},clear(){},bufferData(_,data){if(data instanceof Float32Array&&data.length>50000)staticUploaded=true},drawArrays(_,__,n){drawingCalls++;if(n<1)throw Error('Empty draw')}} ,{get(target,key){return target[key]??(()=>{})}});
class MockElement{
 constructor(tag='div'){this.tagName=tag.toUpperCase();this.style={};this.dataset={};this.children=[];this.events=new Map();this.attrs={};this.hidden=false;this.value='';this.textContent='';this.innerHTML='';this.classList={add(){},remove(){},toggle(){}};this.clientWidth=1600;this.clientHeight=900;this.width=1600;this.height=900}
 addEventListener(type,cb){this.events.set(type,cb)}
 getContext(type){return type==='webgl2'?gl:{clearRect(){},fillRect(){},beginPath(){},moveTo(){},lineTo(){},stroke(){},arc(){},fill(){},setLineDash(){},save(){},restore(){},translate(){},rotate(){},strokeRect(){},closePath(){},fillText(){}}}
 getAttribute(k){return this.attrs[k]||null}setAttribute(k,v){this.attrs[k]=v}
 appendChild(el){this.children.push(el);return el}prepend(el){this.children.unshift(el)}remove(){this.removed=true}
 querySelectorAll(){return []}get lastElementChild(){return this.children.at(-1)||null}
}
const cache=new Map();const byId=id=>{if(!cache.has(id))cache.set(id,new MockElement(id==='world'||id==='minimap'?'canvas':'div'));return cache.get(id)};
const document={documentElement:{lang:'ru'},hidden:false,getElementById:byId,createElement:tag=>new MockElement(tag),querySelectorAll:()=>[],addEventListener(){},activeElement:null};
const local=new Map();const localStorage={getItem:k=>local.get(k)||null,setItem:(k,v)=>local.set(k,v)};
const listeners={};const window={devicePixelRatio:1,addEventListener(type,cb){listeners[type]=cb},requestAnimationFrame(cb){raf=cb},AudioContext:null};
const context={window,document,localStorage,console,Math,Number,String,Map,Set,Array,Float32Array,performance:{now:()=>0},setTimeout:cb=>{cb();return 1},requestAnimationFrame:cb=>{raf=cb},alert(){},confirm:()=>true};
vm.runInNewContext(script,context,{filename:'omega-engine.js',timeout:30000});
assert.equal(window.OSGARD_DEBUG.version,'v0.23-webgl-city');
assert.ok(staticUploaded,'City mesh should actually upload to WebGL');
assert.ok(window.OSGARD_DEBUG.worldMeshes>100,'City should contain actual buildings');
assert.ok(drawingCalls>=2,'Static and dynamic meshes should both render');
assert.ok(window.OSGARD_DEBUG.missionDestination().length===2);
for(let i=1;i<=15;i++)raf(i*16.67);
assert.ok(drawingCalls>10,'requestAnimationFrame must sustain rendering');
listeners.keydown?.({key:'w',repeat:false,preventDefault(){}});
for(let i=16;i<65;i++)raf(i*16.67);
listeners.keyup?.({key:'w'});
assert.ok(window.OSGARD_DEBUG.state.speed>0,'W accelerates the actual car');
assert.ok(window.OSGARD_DEBUG.state.z<140,'Car moves north through the actual city');
console.log(`PASS: WebGL city generated ${window.OSGARD_DEBUG.worldMeshes} buildings; ${drawingCalls} draw calls; car speed ${window.OSGARD_DEBUG.state.speed.toFixed(1)}m/s; local save ${local.size}`);