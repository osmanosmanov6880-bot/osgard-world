/* OSGARD EMPIRE Ω — CITY WORLD / interactive WebGL2 prototype v0.23.
 * All art is generated at runtime. No external game runtime, shaders or assets.
 * A real browser-playable city game; not a Godot export and not photorealistic AAA.
 */
(()=>{'use strict';
const $=id=>document.getElementById(id), canvas=$('world'), mapCanvas=$('minimap');
const gl=canvas.getContext('webgl2',{antialias:true,alpha:true,depth:true,premultipliedAlpha:false,powerPreference:'high-performance'});
const fallbackCtx=gl?null:canvas.getContext('2d');
const clamp=(v,l,h)=>Math.max(l,Math.min(h,v)), lerp=(a,b,t)=>a+(b-a)*t, hypot=Math.hypot;
const rad=Math.PI/180, TAU=Math.PI*2;
let paused=false,gameStarted=false,currentPanel='none', sound=false, lang='ru', quality='high';
const keys={};let lastFrame=0, elapsed=0,fps=60,fpsT=0,fpsCounter=0,qualityScale=1;
const routes=[
 {ru:'ПЕРВОЕ ДВИЖЕНИЕ',en:'FIRST DRIVE',zh:'首次驾驶',desc:'Освойте управление и доберитесь до центрального терминала.',at:[0,-95],reward:220,district:'ЦЕНТРАЛЬНЫЙ ПРОСПЕКТ'},
 {ru:'НЕОНОВЫЙ ПЕРЕКРЁСТОК',en:'NEON INTERSECTION',zh:'霓虹路口',desc:'Доставьте сообщение в деловой квартал.',at:[-100,-100],reward:310,district:'ДЕЛОВОЙ КВАРТАЛ'},
 {ru:'ЭНЕРГИЯ ГОРОДА',en:'CITY ENERGY',zh:'城市能源',desc:'Доберитесь до энергоузла восточного района.',at:[100,-100],reward:400,district:'ВОСТОЧНЫЙ РАЙОН'},
 {ru:'НОЧНОЙ КУРЬЕР',en:'NIGHT COURIER',zh:'夜间信使',desc:'Найдите северную башню и завершите доставку.',at:[150,-200],reward:480,district:'СЕВЕРНАЯ БАШНЯ'},
 {ru:'ЗА ПРЕДЕЛАМИ ЦЕНТРА',en:'BEYOND DOWNTOWN',zh:'超越市中心',desc:'Откройте южный транспортный узел.',at:[-150,100],reward:600,district:'ЮЖНЫЙ ТЕРМИНАЛ'},
 {ru:'СЕРДЦЕ ИМПЕРИИ',en:'HEART OF THE EMPIRE',zh:'帝国之心',desc:'Вернитесь к центральному маяку и завершите главу.',at:[0,0],reward:850,district:'ЦЕНТР ИМПЕРИИ'},
];
const discoveries=[[-150,-150],[-50,-150],[50,-150],[150,-150],[-150,-50],[-50,-50],[50,-50],[150,-50],[-150,50],[-50,50],[50,50],[150,50]];
const autoSpecs=[{name:'ATLAS GT',color:'#1ca8b4',speed:32,accel:13.8,price:0},{name:'VIPER R',color:'#d5a45e',speed:39,accel:16.4,price:720},{name:'PHANTOM X',color:'#6a79ac',speed:44,accel:17.5,price:1450},{name:'OBSIDIAN S',color:'#f0e3ce',speed:47,accel:20,price:2600}];
const initial=()=>({v:23,money:1450,reputation:12,mission:0,x:0,z:140,heading:0,speed:0,fuel:87,health:100,inCar:true,parkedX:0,parkedZ:140,carIndex:0,owned:[0],day:22.66,rain:false,discovered:[],distance:0,started:false,introSeen:false,language:'ru',kills:0});
const STORAGE='osgard-omega-v023-city';let state=initial();
function safeLoad(){try{const s=JSON.parse(localStorage.getItem(STORAGE));if(!s||s.v!==23)return;
 const good=Number.isFinite(s.x)&&Number.isFinite(s.z)&&Math.abs(s.x)<=213&&Math.abs(s.z)<=213&&Number.isFinite(s.money)&&Number.isInteger(s.mission)&&s.mission>=0&&s.mission<=6;
 if(!good)return;state={...initial(),...s};state.money=clamp(state.money,0,9999999);state.fuel=clamp(state.fuel,0,100);state.health=clamp(state.health,1,100);state.speed=clamp(state.speed,-12,49);state.heading=clamp(state.heading,-1e4,1e4);state.carIndex=clamp(state.carIndex|0,0,3);state.discovered=Array.isArray(state.discovered)?state.discovered.filter(v=>Number.isInteger(v)&&v>=0&&v<12).slice(0,12):[];state.owned=Array.isArray(state.owned)?state.owned.filter(v=>Number.isInteger(v)&&v>=0&&v<4):[0];if(!state.owned.includes(state.carIndex))state.carIndex=0;
 }catch(e){console.warn('OSGARD city save could not be loaded; clean campaign used',e.message)}}
function safeSave(){try{localStorage.setItem(STORAGE,JSON.stringify({...state,speed:state.speed*0.7}));return true}catch(e){notify('Автосохранение недоступно','Проверьте настройки хранилища браузера',true);return false}}
safeLoad();lang=['ru','en','zh'].includes(state.language)?state.language:'ru';gameStarted=Boolean(state.started);
const words={
 ru:{world3d:'ГОРОД 3D',strategy:'СТРАТЕГИЯ',online:'МИР АКТИВЕН',city:'ГОРОД',map:'КАРТА',tasks:'ЗАДАНИЯ',garage:'ГАРАЖ',atlas:'АТЛАС',help:'ПОМОЩЬ',credits:'КРЕДИТЫ',reputation:'РЕПУТАЦИЯ',progress:'ПРОГРЕСС',go:'НАЧАТЬ МАРШРУТ'},
 en:{world3d:'3D CITY',strategy:'STRATEGY',online:'WORLD LIVE',city:'CITY',map:'MAP',tasks:'MISSIONS',garage:'GARAGE',atlas:'ATLAS',help:'HELP',credits:'CREDITS',reputation:'REPUTATION',progress:'PROGRESS',go:'START ROUTE'},
 zh:{world3d:'3D城市',strategy:'策略',online:'世界运行中',city:'城市',map:'地图',tasks:'任务',garage:'车库',atlas:'图鉴',help:'帮助',credits:'积分',reputation:'声望',progress:'进度',go:'开始路线'}
};
function translateUI(){document.documentElement.lang=lang;document.querySelectorAll('[data-i18n]').forEach(el=>{const key=el.dataset.i18n;if(words[lang][key])el.textContent=words[lang][key]})}
translateUI();
function notify(title,description='',warn=false){const node=document.createElement('div');node.className='toast'+(warn?' warn':'');const bold=document.createElement('b');bold.textContent=title;node.appendChild(bold);if(description){const span=document.createElement('span');span.textContent=description;node.appendChild(span)}$('toasts').prepend(node);while($('toasts').children.length>3)$('toasts').lastElementChild.remove();setTimeout(()=>node.remove(),4700)}
const seed=(n)=>{let x=Math.sin(n*177.733+7.12)*13758.5453;return x-Math.floor(x)};
const colorCache=new Map();function rgb(hex){if(Array.isArray(hex))return hex;const key=hex;if(colorCache.has(key))return colorCache.get(key);let s=hex.replace('#','');if(s.length===3)s=s.split('').map(x=>x+x).join('');const c=[parseInt(s.slice(0,2),16)/255,parseInt(s.slice(2,4),16)/255,parseInt(s.slice(4,6),16)/255];colorCache.set(key,c);return c}
function mesh(){return []}
function vert(out,p,n,c,emit){out.push(p[0],p[1],p[2],n[0],n[1],n[2],c[0],c[1],c[2],emit)}
function quad(out,a,b,c,d,shade,emit=0,forcedNormal){const v1=[b[0]-a[0],b[1]-a[1],b[2]-a[2]],v2=[c[0]-a[0],c[1]-a[1],c[2]-a[2]];const cp=[v1[1]*v2[2]-v1[2]*v2[1],v1[2]*v2[0]-v1[0]*v2[2],v1[0]*v2[1]-v1[1]*v2[0]];const mag=Math.hypot(...cp)||1;const n=forcedNormal||cp.map(x=>x/mag);const color=rgb(shade);vert(out,a,n,color,emit);vert(out,b,n,color,emit);vert(out,c,n,color,emit);vert(out,a,n,color,emit);vert(out,c,n,color,emit);vert(out,d,n,color,emit)}
function box(out,x,y,z,w,h,d,c,emit=0,yaw=0){const a=w/2,b=h/2,k=d/2;const cos=Math.cos(yaw),sin=Math.sin(yaw);const p=[[-a,-b,-k],[a,-b,-k],[a,b,-k],[-a,b,-k],[-a,-b,k],[a,-b,k],[a,b,k],[-a,b,k]].map(v=>[x+v[0]*cos+v[2]*sin,y+v[1],z-v[0]*sin+v[2]*cos]);
 const fs=[[0,1,2,3],[5,4,7,6],[4,0,3,7],[1,5,6,2],[3,2,6,7],[4,5,1,0]];for(const f of fs)quad(out,p[f[0]],p[f[1]],p[f[2]],p[f[3]],c,emit)}
function face(out,x,y,z,w,h,dir,col,emit=1){const a=w/2,b=h/2,e=0.018;let p;if(dir===0)p=[[x-a,y-b,z-e],[x+a,y-b,z-e],[x+a,y+b,z-e],[x-a,y+b,z-e]];if(dir===1)p=[[x+a,y-b,z+e],[x-a,y-b,z+e],[x-a,y+b,z+e],[x+a,y+b,z+e]];if(dir===2)p=[[x+e,y-b,z-a],[x+e,y-b,z+a],[x+e,y+b,z+a],[x+e,y+b,z-a]];if(dir===3)p=[[x-e,y-b,z+a],[x-e,y-b,z-a],[x-e,y+b,z-a],[x-e,y+b,z+a]];quad(out,...p,col,emit)}
function cylinder(out,x,y,z,r,h,col,emit=0,sides=9){const c=rgb(col),y0=y-h/2,y1=y+h/2;for(let i=0;i<sides;i++){const a=i*TAU/sides,b=(i+1)*TAU/sides,p=[x+Math.cos(a)*r,y0,z+Math.sin(a)*r],q=[x+Math.cos(b)*r,y0,z+Math.sin(b)*r],u=[q[0],y1,q[2]],v=[p[0],y1,p[2]];quad(out,p,q,u,v,c,emit);quad(out,[x,y1,z],v,u,[x,y1,z],c,emit,[0,1,0])}}
function ring(out,x,y,z,r,thick,c,emit=1,segments=36){for(let i=0;i<segments;i++){const a=i*TAU/segments,b=(i+1)*TAU/segments;quad(out,[x+Math.cos(a)*(r-thick),y,z+Math.sin(a)*(r-thick)],[x+Math.cos(b)*(r-thick),y,z+Math.sin(b)*(r-thick)],[x+Math.cos(b)*r,y,z+Math.sin(b)*r],[x+Math.cos(a)*r,y,z+Math.sin(a)*r],c,emit,[0,1,0])}}
function tree(out,x,z,size=1){cylinder(out,x,1.4*size,z,.28*size,2.9*size,'#394a45');cylinder(out,x,3.1*size,z,1.7*size,2.5*size,'#174b4b');cylinder(out,x,4.5*size,z,1.28*size,2.0*size,'#236e66')}
let staticMesh=mesh(),buildings=[];
const grid=[-200,-150,-100,-50,0,50,100,150,200];
function building(x,z,w,d,height,id){const col=['#233b47','#344955','#243b49','#415361','#293c49','#304d58'][id%6];box(staticMesh,x,height/2+.12,z,w,height,d,col,0);
 box(staticMesh,x,height+.12,z,w+.5,.65,d+.5,'#122833');
 const stories=Math.floor(height/4.1);const litA=['#c6a76c','#7ccbbd','#789cae','#dac18f','#dcd8b3'];
 for(let lvl=1;lvl<stories;lvl++){
 const py=lvl*3.9+.65;
 for(let dx=-w/2+2.1;dx<w/2-1.1;dx+=3.1){if(seed(id*1000+lvl*73+dx*13)<.48)continue;const c=litA[Math.floor(seed(id*400+lvl*3+dx*7)*litA.length)];face(staticMesh,x+dx,py,z-d/2-.025,1.65,2.1,0,c,.80);face(staticMesh,x+dx,py,z+d/2+.025,1.65,2.1,1,c,.79)}
 for(let dz=-d/2+2;dz<d/2-1.1;dz+=3.1){if(seed(id*900+lvl*11+dz*23)<.50)continue;const c=litA[Math.floor(seed(id*1400+lvl*8+dz)*litA.length)];face(staticMesh,x+w/2+.025,py,z+dz,1.65,2.1,2,c,.7);face(staticMesh,x-w/2-.025,py,z+dz,1.65,2.1,3,c,.7)}
 }
 // Illuminated architectural strips, roof crown, and restrained corporate accents.
 if(id%6===0){box(staticMesh,x,height*.5,z-d/2-.07,w*.085,height*.94,.13,'#307e83',.6);box(staticMesh,x+w/2+.09,height*.5,z,.14,height*.94,d*.08,'#4e9b92',.45)}
 if(height>57){cylinder(staticMesh,x,height+3.5,z,.17,6.5,'#78c5c1',.9);box(staticMesh,x,height+7,z,.75,.45,.75,'#dfbd79',1)}
 if(id%9===0){box(staticMesh,x,1.35,z-d/2-.2,w*.65,2.4,.2,'#345965',.4);box(staticMesh,x,2.3,z-d/2-.36,w*.42,.19,.2,'#d1b774',1)}
 buildings.push({x,z,h:height,w,d});
}
function constructCity(){
 const p=staticMesh;
 // Deep-ground slabs, arterial roads, plazas, and illuminated lane paint.
 box(p,0,-.72,0,465,.9,465,'#0d2026');
 for(let i=0;i<grid.length;i++){
  const a=grid[i];box(p,a,-.16,0,14,.09,450,'#1a2a33');box(p,0,-.15,a,450,.09,14,'#1a2a33');
  for(let t=-210;t<=210;t+=19){box(p,a,-.05,t,0.12,.015,6,'#b3a071',.36);box(p,t,-.045,a,6,.015,.12,'#b3a071',.36)}
  // Edge lights make streets legible even at night.
  box(p,a-7,-.047,0,.1,.02,448,'#32636a',.55);box(p,a+7,-.047,0,.1,.02,448,'#32636a',.55);
  box(p,0,-.046,a-7,448,.02,.1,'#32636a',.55);box(p,0,-.046,a+7,448,.02,.1,'#32636a',.55)
 }
 let id=0;
 for(let ix=0;ix<8;ix++)for(let iz=0;iz<8;iz++){
  const x=-175+ix*50,z=-175+iz*50;
  box(p,x,-.1,z,35,.23,35,'#243a3d');
  for(let o of [[-11,-11],[11,-11],[-11,11],[11,11]]){
    id++;const bx=x+o[0],bz=z+o[1];
    const central=1-clamp(hypot(bx,bz)/270,0,1);
    const rand=seed(id*3.713);const height=13+rand*24+central*(16+seed(id*17.2)*43);
    if(id%11===0){tree(p,bx,bz,1.25+seed(id)*.5);continue}
    if(id%13===0){box(p,bx,1.1,bz,13,2,13,'#36505a');ring(p,bx,2.18,bz,3.5,.38,'#c4ad6d',1);continue}
    const w=clamp(10+seed(id*7.3)*7,10,18),d=clamp(10+seed(id*4.11)*7,10,18);
    building(bx,bz,w,d,height,id)
  }
  // Low landscape lighting and an occasional planted corner.
  if((ix+iz)%3===0)tree(p,x+18,z+17,1);
 }
 // Street lamps have warm lit heads, cobalt poles, and no costly shadow passes.
 for(let i=0;i<9;i++)for(let j=0;j<9;j++){
   if((i+j)%2)continue;
   const x=grid[i]+10,z=grid[j]+10;
   cylinder(p,x,3.05,z,.14,6.1,'#60757b');box(p,x,6.2,z,1.2,.2,.4,'#d8c898',1);
   box(p,x,6.01,z,2.5,.06,2.5,'#8e9e70',.12)
 }
 // Four skyline towers outside the playable road circuit.
 for(let i=0;i<21;i++){
   const x=-235+i*23,h=65+seed(i*23+8)*130,z=-268-(i%4)*9;
   box(p,x,h/2,z,17,h,18,'#172e39');
   for(let y=6;y<h-4;y+=7)for(let dx=-5;dx<=5;dx+=5){if(seed(y*9+i*3+dx)>.33)face(p,x+dx,y,z+9.05,2,1.6,1,'#779999',.75)}
 }
 // City gateways: gold arches and luminous bridge pylons.
 for(const z of [-200,0,200]){
   box(p,-8,8.5,z,1.0,17,1,'#78938b');box(p,8,8.5,z,1,17,1,'#78938b');box(p,0,17,z,17,1,1,'#c6b47e',.53);
   box(p,0,16.4,z,16,.19,1.2,'#5ad1ba',1)
 }
}
function makeShader(type,src){const sh=gl.createShader(type);gl.shaderSource(sh,src);gl.compileShader(sh);if(!gl.getShaderParameter(sh,gl.COMPILE_STATUS)){throw Error(gl.getShaderInfoLog(sh))}return sh}
const vertexShader=`#version 300 es
precision highp float;
layout(location=0) in vec3 aPos; layout(location=1) in vec3 aNormal; layout(location=2) in vec3 aColor;layout(location=3) in float aEmissive;
uniform mat4 uMVP; uniform vec3 uCamera;
out vec3 vCol; out float vEmit;out float vFog;
void main(){gl_Position=uMVP*vec4(aPos,1.);vCol=aColor;vEmit=aEmissive;
vec3 l=normalize(vec3(-.48,.77,.35));float light=.43+max(0.,dot(normalize(aNormal),l))*.57;
vCol*=mix(light,1.,aEmissive*.85);
float d=distance(aPos,uCamera);vFog=clamp((d-118.)/310.,0.,.94);
}`;
const fragmentShader=`#version 300 es
precision highp float;
in vec3 vCol;in float vEmit;in float vFog;uniform float uDay;out vec4 frag;
void main(){vec3 c=mix(vCol*(1.+uDay*.45),mix(vec3(.075,.14,.19),vec3(.38,.55,.63),uDay),vFog);c*=1.+vEmit*.34;c=pow(c,vec3(.90));frag=vec4(c,1.);}`;
let program,vaoStatic,vboStatic,vaoDyn,vboDyn,countStatic=0, countDyn=0,uMVP,uCamera,uDay;
function initializeGL(){if(!gl)return false;
 program=gl.createProgram();gl.attachShader(program,makeShader(gl.VERTEX_SHADER,vertexShader));gl.attachShader(program,makeShader(gl.FRAGMENT_SHADER,fragmentShader));gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(program));gl.useProgram(program);uMVP=gl.getUniformLocation(program,'uMVP');uCamera=gl.getUniformLocation(program,'uCamera');uDay=gl.getUniformLocation(program,'uDay');
 function prepare(dynamic){const vao=gl.createVertexArray(),buffer=gl.createBuffer();gl.bindVertexArray(vao);gl.bindBuffer(gl.ARRAY_BUFFER,buffer);for(let i=0;i<4;i++){gl.enableVertexAttribArray(i);gl.vertexAttribPointer(i,i===3?1:3,gl.FLOAT,false,40,[0,12,24,36][i])}return [vao,buffer]}
 [vaoStatic,vboStatic]=prepare(false);[vaoDyn,vboDyn]=prepare(true);
 gl.enable(gl.DEPTH_TEST);gl.depthFunc(gl.LEQUAL);gl.disable(gl.CULL_FACE);gl.clearColor(0,0,0,0);
 constructCity();gl.bindBuffer(gl.ARRAY_BUFFER,vboStatic);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(staticMesh),gl.STATIC_DRAW);countStatic=staticMesh.length/10;staticMesh=null;
 return true
}
function perspective(fov,aspect,near,far){const f=1/Math.tan(fov/2),nf=1/(near-far);return new Float32Array([f/aspect,0,0,0,0,f,0,0,0,0,(far+near)*nf,-1,0,0,2*far*near*nf,0])}
function lookAt(eye,target){let fx=target[0]-eye[0],fy=target[1]-eye[1],fz=target[2]-eye[2],n=Math.hypot(fx,fy,fz)||1;fx/=n;fy/=n;fz/=n;
 let sx=-fz,sy=0,sz=fx;n=Math.hypot(sx,sy,sz)||1;sx/=n;sy/=n;sz/=n;
 let ux=sy*fz-sz*fy,uy=sz*fx-sx*fz,uz=sx*fy-sy*fx;
 return new Float32Array([sx,ux,-fx,0,sy,uy,-fy,0,sz,uz,-fz,0,-(sx*eye[0]+sy*eye[1]+sz*eye[2]),-(ux*eye[0]+uy*eye[1]+uz*eye[2]),fx*eye[0]+fy*eye[1]+fz*eye[2],1])}
function multiply(a,b){const r=new Float32Array(16);for(let col=0;col<4;col++)for(let row=0;row<4;row++){r[row+4*col]=a[row+0]*b[0+4*col]+a[row+4]*b[1+4*col]+a[row+8]*b[2+4*col]+a[row+12]*b[3+4*col]}return r}
let camera=[0,9,162],eyeTarget=[0,2,118],lastVP=null;
function frameCamera(dt){const s=state,forward=[Math.sin(s.heading),-Math.cos(s.heading)];const tx=s.x-forward[0]*21, tz=s.z-forward[1]*21;
 const wanted=[tx,9.5, tz];const gaze=[s.x+forward[0]*18,3.5,s.z+forward[1]*18];const alpha=1-Math.exp(-dt*4.1);
 camera[0]=lerp(camera[0],wanted[0],alpha);camera[1]=lerp(camera[1],wanted[1],alpha);camera[2]=lerp(camera[2],wanted[2],alpha);
 for(let i=0;i<3;i++)eyeTarget[i]=lerp(eyeTarget[i],gaze[i],alpha);
 const p=perspective(63*rad,Math.max(.2,canvas.width/canvas.height),.12,750),v=lookAt(camera,eyeTarget);lastVP=multiply(p,v);return lastVP}
// Accessible Canvas2D renderer: the entire game remains playable on systems where
// WebGL2 is unavailable (software renderer, remote desktop or restrictive drivers).
// Uses the same world coordinates and route simulation, not a static screenshot.
function constructFallbackCity(){let id=0;for(let ix=0;ix<8;ix++)for(let iz=0;iz<8;iz++){
 const x=-175+ix*50,z=-175+iz*50;for(const [dx,dz] of [[-11,-11],[11,-11],[-11,11],[11,11]]){id++;
 if(id%11===0||id%13===0)continue;
 const bx=x+dx,bz=z+dz,central=1-clamp(hypot(bx,bz)/270,0,1);
 const h=13+seed(id*3.713)*24+central*(16+seed(id*17.2)*43);
 const w=clamp(10+seed(id*7.3)*7,10,18),d=clamp(10+seed(id*4.11)*7,10,18);
 buildings.push({x:bx,z:bz,h,w,d,color:['#203a48','#294657','#334f5b','#395464','#2b4354'][id%5]})
 }}}
function renderFallback(t,dt){const ctx=fallbackCtx,w=canvas.width,h=canvas.height,s=state,focal=h*.98,yH=h*.42;
 const bg=ctx.createLinearGradient(0,0,0,h);const day=s.day>6&&s.day<17;if(day){bg.addColorStop(0,'#537f94');bg.addColorStop(.43,'#638fa0');bg.addColorStop(.58,'#34586a');bg.addColorStop(1,'#172f3b')}else{bg.addColorStop(0,'#142a3c');bg.addColorStop(.43,'#102c3a');bg.addColorStop(.58,'#162e34');bg.addColorStop(1,'#081c24')};ctx.fillStyle=bg;ctx.fillRect(0,0,w,h);
 const yaw=s.heading,cos=Math.cos(yaw),sin=Math.sin(yaw),cx=s.x-sin*22,cz=s.z+cos*22;
 function project(x,y,z){const dx=x-cx,dz=z-cz,depth=dx*sin-dz*cos;if(depth<.9||depth>430)return null;return [w/2+(dx*cos+dz*sin)*focal/depth,yH+(8.1-y)*focal/depth,depth]}
 function poly(points,color,outline=''){const pts=points.map(p=>project(...p));if(pts.some(p=>!p))return;ctx.beginPath();ctx.moveTo(pts[0][0],pts[0][1]);for(let i=1;i<pts.length;i++)ctx.lineTo(pts[i][0],pts[i][1]);ctx.closePath();ctx.fillStyle=color;ctx.fill();if(outline){ctx.strokeStyle=outline;ctx.lineWidth=1;ctx.stroke()}}
 // Night sky. Atmospheric glow and street haze are intentionally inexpensive.
 const glow=ctx.createRadialGradient(w/2,yH-40,20,w/2,yH-40,w*.52);glow.addColorStop(0,'#527c8155');glow.addColorStop(1,'#12283500');ctx.fillStyle=glow;ctx.fillRect(0,0,w,h);
 for(let k=0;k<115;k++){const sx=seed(k*3.7)*w,sy=seed(k*5.6)*h*.45;ctx.fillStyle=k%5===0?'#c5c59a80':'#8cbdcb65';ctx.fillRect(sx,sy,1.2,1.2)}
 // Perspective road grid: roads have a true vanishing point and lighted lines.
 const roads=[];for(const g of grid){for(let i=-230;i<230;i+=23){roads.push({dist:Math.abs(i-s.z),a:[[g-6.2,.01,i],[g+6.2,.01,i],[g+6.2,.01,i+23],[g-6.2,.01,i+23]]});roads.push({dist:Math.abs(g-s.z),a:[[i,.012,g-6.2],[i+23,.012,g-6.2],[i+23,.012,g+6.2],[i,.012,g+6.2]]})}}roads.sort((a,b)=>b.dist-a.dist);for(const road of roads)poly(road.a,'#1c353f','#39606a25');
 // Dashed lane markers, lit on arterial intersections.
 for(const g of grid){for(let k=-220;k<220;k+=21){poly([[g-.08,.06,k],[g+.08,.06,k],[g+.08,.06,k+8],[g-.08,.06,k+8]],'#cdb57c');poly([[k,.07,g-.08],[k+8,.07,g-.08],[k+8,.07,g+.08],[k,.07,g+.08]],'#cdb57c')}}
 const ordered=buildings.map(b=>({...b,depth:(b.x-cx)*sin-(b.z-cz)*cos})).filter(b=>b.depth>2&&b.depth<330).sort((a,b)=>b.depth-a.depth);
 for(const b of ordered){const{x,z,w:wd,d,h:bh}=b,xx=cx>x?x+wd/2:x-wd/2,zz=cz>z?z+d/2:z-d/2;
 const zFace=[[x-wd/2,0,zz],[x+wd/2,0,zz],[x+wd/2,bh,zz],[x-wd/2,bh,zz]];
 const xFace=[[xx,0,z-d/2],[xx,0,z+d/2],[xx,bh,z+d/2],[xx,bh,z-d/2]];
 poly(zFace,b.color,'#65818d44');poly(xFace,'#1b3340','#405a6744');poly([[x-wd/2,bh,z-d/2],[x+wd/2,bh,z-d/2],[x+wd/2,bh,z+d/2],[x-wd/2,bh,z+d/2]],'#476374');
 if(b.depth>160)continue;
 for(let floor=5;floor<bh-2;floor+=5.1){for(let lx=x-wd/2+2;lx<x+wd/2-1.7;lx+=3.1){if(seed(floor*2.1+lx*.3+b.z)>.41)poly([[lx,floor,zz+(cz>z?.04:-.04)],[lx+1.65,floor,zz+(cz>z?.04:-.04)],[lx+1.65,floor+1.8,zz+(cz>z?.04:-.04)],[lx,floor+1.8,zz+(cz>z?.04:-.04)]],floor%3<1?'#bca774':'#79a4a3')}
 for(let lz=z-d/2+2;lz<z+d/2-1.7;lz+=3.1){if(seed(floor*3.2+lz*1.2+b.x)>.53)poly([[xx+(cx>x?.04:-.04),floor,lz],[xx+(cx>x?.04:-.04),floor,lz+1.65],[xx+(cx>x?.04:-.04),floor+1.8,lz+1.65],[xx+(cx>x?.04:-.04),floor+1.8,lz]],'#9db3a1')}
 }}
 // Traffic and glowing waypoint share the same live state as WebGL.
 for(const c of traffic){const x=c.axis?c.p:c.road+c.lane,z=c.axis?c.road+c.lane:c.p;const a=project(x,1.1,z);if(!a||a[2]>180)continue;const sc=clamp(1.4*focal/a[2],1,40);ctx.fillStyle=c.body;ctx.fillRect(a[0]-sc/2,a[1]-sc*.6,sc,sc*.85);ctx.fillStyle='#ffb676';ctx.fillRect(a[0]-sc*.4,a[1]+sc*.05,sc*.8,2)}
 const target=activeDestination();if(target){const bottom=project(target[0],0,target[1]),top=project(target[0],33,target[1]);if(bottom&&top){const pulse=.68+Math.sin(t*2.4)*.25;ctx.strokeStyle=`rgba(111,245,213,${pulse})`;ctx.lineWidth=3;ctx.beginPath();ctx.moveTo(...bottom.slice(0,2));ctx.lineTo(...top.slice(0,2));ctx.stroke();ctx.beginPath();ctx.ellipse(bottom[0],bottom[1],Math.max(8,9*focal/bottom[2]),Math.max(4,3*focal/bottom[2]),0,0,TAU);ctx.stroke();ctx.fillStyle='#ecd398';ctx.beginPath();ctx.arc(top[0],top[1],5,0,TAU);ctx.fill()}}
 const vehicle=project(s.inCar?s.x:s.parkedX,1.2,s.inCar?s.z:s.parkedZ);if(vehicle){const px=vehicle[0],py=vehicle[1],scale=clamp(focal/vehicle[2],.7,25);const size=clamp(scale*2.4,18,200);ctx.fillStyle='#08141dbb';ctx.beginPath();ctx.ellipse(px,py+size*.22,size*.76,size*.25,0,0,TAU);ctx.fill();ctx.fillStyle=autoSpecs[s.carIndex].color;ctx.beginPath();ctx.moveTo(px-size*.68,py+size*.13);ctx.lineTo(px-size*.53,py-size*.52);ctx.lineTo(px+size*.53,py-size*.52);ctx.lineTo(px+size*.68,py+size*.13);ctx.closePath();ctx.fill();ctx.fillStyle='#102b37';ctx.fillRect(px-size*.38,py-size*.37,size*.76,size*.22);ctx.fillStyle='#f36e6a';ctx.fillRect(px-size*.59,py+size*.08,size*.25,size*.1);ctx.fillRect(px+size*.34,py+size*.08,size*.25,size*.1)}
 if(!s.inCar){const a=project(s.x,1.4,s.z);if(a){ctx.fillStyle='#d9c690';ctx.beginPath();ctx.arc(a[0],a[1]-5,5,0,TAU);ctx.fill()}}
}
// In-world actors and navigation beacons are regenerated each frame. They do not
// share the collision model with the static architecture.
const traffic=Array.from({length:20},(_,i)=>({i,axis:i%2,road:grid[(i*7+3)%grid.length],lane:i%4<2?-3.1:3.1,p:-214+seed(i*11)*428,dir:i%4<2?1:-1,speed:5.8+seed(i*23)*7.4,body:['#517d85','#ad8b5c','#547682','#7c858d'][i%4]}));
const walkers=Array.from({length:25},(_,i)=>({axis:i%2,street:grid[(i*3+7)%9]+(i%3===0?10.2:-10.2),p:-208+seed(i*4.1)*416,dir:i%2?1:-1,speed:.6+seed(i*31)*.85,phase:seed(i*8)*TAU}));
const modelColor=()=>autoSpecs[state.carIndex].color;
function carMesh(out,x,z,heading,scale=1,color='#1ca8b4',police=false){
 const emit=0;const c=color;
 const bx=(dx,dy,dz,w,h,d,cl,em=0)=>{
 const xx=x+dx*Math.cos(heading)+dz*Math.sin(heading),zz=z-dx*Math.sin(heading)+dz*Math.cos(heading);
 box(out,xx,dy*scale,zz,w*scale,h*scale,d*scale,cl,em,heading)
 };
 bx(0,.75,0,2.12,.6,4.65,c);bx(0,1.25,.25,1.75,.65,2.45,'#152a36');
 bx(0,1.46,-.18,1.73,.08,1.95,'#286678');
 bx(0,1.33,-1.03,1.6,.19,.07,'#85b1be',.25);bx(0,1.33,1.43,1.6,.19,.07,'#44636e',.13);
 bx(0,.48,-2.29,1.9,.23,.18,'#152b32');bx(0,.48,2.30,1.9,.24,.18,'#152b32');
 for(const ix of [-1.01,1.01])for(const iz of [-1.35,1.38])bx(ix,.39,iz,.31,.66,.68,'#111e26');
 for(const ix of [-.68,.68]){
 bx(ix,.9,-2.34,.43,.20,.08,'#f1e4c2',1);bx(ix,.9,2.34,.37,.21,.085,state.speed<0?'#ef7558':'#b74e52',state.speed<0?1:.35);
 }
 if(police){bx(0,1.69,.12,.88,.19,.34,'#dcdacf');bx(-.28,1.79,.12,.27,.15,.25,'#df5955',1);bx(.28,1.79,.12,.27,.15,.25,'#478ad1',1)}
}
function citizen(out,x,z,phase){const bob=Math.sin(phase)*.055;box(out,x,1.25+bob,z,.54,1.02,.33,'#607b87');cylinder(out,x,2.03+bob,z,.28,.5,'#dabaa1');box(out,x-.15,.48+bob,z,.18,.77,.18,'#30404e');box(out,x+.15,.48+bob,z,.18,.77,.18,'#30404e')}
function missionBeacon(out,t){const target=activeDestination();if(!target)return;const [x,z]=target;const pulse=1+.11*Math.sin(t*2.6);ring(out,x,.09,z,8*pulse,.29,'#65e9ce',1.5,48);ring(out,x,.11,z,5*pulse,.14,'#efd18c',1.4,40);
 cylinder(out,x,12+Math.sin(t*1.4),z,.30,24,'#47c4c6',1.9,8);
 for(let a=0;a<4;a++){let ang=t*.65+a*Math.PI/2;const yy=6+a*4;box(out,x+Math.sin(ang)*2,yy,z+Math.cos(ang)*2,.5,.35,.5,'#e5cb80',1.5,ang)}
 box(out,x,25+Math.sin(t*2)*1.0,z,2.6,.5,2.6,'#edc98d',1.6,t*.5);
}
function discoveryBeacons(out,t){for(let i=0;i<discoveries.length;i++){
 const [x,z]=discoveries[i],found=state.discovered.includes(i),pulse=.1*Math.sin(t*2+i);
 cylinder(out,x,.53,z,1.4,.7,found?'#263b46':'#325763');
 cylinder(out,x,2.1,z,.38,2.6,found?'#455258':'#64d5bd',found?0:1.1);
 if(!found)ring(out,x,.22,z,2+pulse,.2,'#67d6bd',.75,18);
}}
function buildDynamic(t){const dyn=mesh();for(const c of traffic){const x=c.axis?c.p:c.road+c.lane,z=c.axis?c.road+c.lane:c.p;
 carMesh(dyn,x,z,c.axis?(c.dir>0?Math.PI/2:-Math.PI/2):(c.dir>0?Math.PI:0),.82,c.body,c.i%7===0)}
 for(let i=0;i<walkers.length;i++){const w=walkers[i];citizen(dyn,w.axis?w.p:w.street,w.axis?w.street:w.p,t*3.5+w.phase)}
 if(state.inCar)carMesh(dyn,state.x,state.z,state.heading,1,modelColor());else{
 carMesh(dyn,state.parkedX,state.parkedZ,state.heading,1,modelColor());citizen(dyn,state.x,state.z,t*7)}
 missionBeacon(dyn,t);discoveryBeacons(dyn,t);return dyn}
function resize(){const dpr=Math.min(window.devicePixelRatio||1,quality==='high'?1.4:1);const w=Math.round(canvas.clientWidth*dpr),h=Math.round(canvas.clientHeight*dpr);if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;if(gl)gl.viewport(0,0,w,h)}}
function render3D(t,dt){resize();if(!gl){renderFallback(t,dt);return}gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);gl.useProgram(program);const vp=frameCamera(dt);gl.uniformMatrix4fv(uMVP,false,vp);gl.uniform3fv(uCamera,new Float32Array(camera));gl.uniform1f(uDay,state.day>6&&state.day<17?1:0);gl.bindVertexArray(vaoStatic);gl.drawArrays(gl.TRIANGLES,0,countStatic);
 const dyn=buildDynamic(t);countDyn=dyn.length/10;gl.bindVertexArray(vaoDyn);gl.bindBuffer(gl.ARRAY_BUFFER,vboDyn);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(dyn),gl.DYNAMIC_DRAW);gl.drawArrays(gl.TRIANGLES,0,countDyn)}
// Physics: route completion and interaction happen in game state, never the UI.
function getForward(){return [Math.sin(state.heading),-Math.cos(state.heading)]}
function playerXY(){return [state.x,state.z]}
function activeDestination(){return routes[state.mission]?.at||[0,0]}
let objectiveStart=175;
function distanceTo(at){return hypot(state.x-at[0],state.z-at[1])}
function nearestDiscovery(radius=9.2){let index=-1,min=radius;discoveries.forEach((point,i)=>{if(state.discovered.includes(i))return;const d=distanceTo(point);if(d<min){min=d;index=i}});return index}
function groundCollision(x,z){if(Math.abs(x)>210||Math.abs(z)>210)return true;
 for(const b of buildings){if(Math.abs(x-b.x)<b.w/2+1.05&&Math.abs(z-b.z)<b.d/2+1.05)return true}
 return false}
let collisionCooldown=0,movingDistance=0;
function updateGame(dt){if(paused||document.hidden)return;const s=state;elapsed+=dt;s.day=(s.day+dt*.0024)%24;
 collisionCooldown=Math.max(0,collisionCooldown-dt);
 for(const c of traffic){c.p+=c.dir*c.speed*dt;if(c.p>215)c.p=-215;if(c.p< -215)c.p=215}
 for(const w of walkers){w.p+=w.dir*w.speed*dt;if(w.p>216)w.p=-216;if(w.p< -216)w.p=216}
 const forwardKey=keys.w||keys.arrowup,backwardKey=keys.s||keys.arrowdown,left=keys.a||keys.arrowleft,right=keys.d||keys.arrowright,handbrake=keys[' '],move=forwardKey||backwardKey;
 const friction=s.rain?.56:1;
 if(s.inCar){
  const accel=autoSpecs[s.carIndex].accel*(s.health/100*.42+.58)*friction,brake=18*friction;
  if(s.fuel<.1){if(move&&elapsed%6<dt)notify('Нет топлива','Откройте гараж и заправьте автомобиль',true)}
  if(handbrake){s.speed=Math.sign(s.speed)*Math.max(0,Math.abs(s.speed)-brake*1.2*dt)}
  else if(forwardKey&&!backwardKey&&s.fuel>.1){s.speed=s.speed<0?Math.min(0,s.speed+brake*dt):Math.min(autoSpecs[s.carIndex].speed,s.speed+accel*dt)}
  else if(backwardKey&&!forwardKey&&s.fuel>.1){s.speed=s.speed>0?Math.max(0,s.speed-brake*dt):Math.max(-11,s.speed-accel*.53*dt)}
  else{s.speed=Math.sign(s.speed)*Math.max(0,Math.abs(s.speed)-3*dt)}
  const steer=Number(right)-Number(left);if(Math.abs(s.speed)>.3&&steer){const angle=steer*.56/(1+Math.abs(s.speed)*.035);const maxSide=9.5*friction/Math.max(.5,Math.abs(s.speed));const yaw=clamp(s.speed/3.45*Math.tan(angle),-maxSide,maxSide);s.heading+=yaw*dt}
  const [fx,fz]=getForward();let oldX=s.x,oldZ=s.z;s.x+=fx*s.speed*dt;s.z+=fz*s.speed*dt;
  if(groundCollision(s.x,s.z)){s.x=oldX;s.z=oldZ;if(Math.abs(s.speed)>3&&collisionCooldown===0){s.health=Math.max(5,s.health-Math.ceil(Math.abs(s.speed)*.35));notify('Столкновение','Состояние машины ухудшилось',true);collisionCooldown=1.3}s.speed*=-.20}
  const driven=hypot(s.x-oldX,s.z-oldZ);s.distance+=driven;s.fuel=clamp(s.fuel-driven*.005,0,100);
  if(s.fuel<=0)s.speed*=.975;
 }else{
  s.speed=0;
  let x=Number(right)-Number(left),z=Number(backwardKey)-Number(forwardKey);const norm=Math.max(1,hypot(x,z));x/=norm;z/=norm;
  const nx=s.x+x*7.2*dt,nz=s.z+z*7.2*dt;if(!groundCollision(nx,nz)){s.x=nx;s.z=nz}
  if(x||z)s.heading=Math.atan2(x,-z)
 }
 if(Math.abs(s.x)>205||Math.abs(s.z)>205){s.x=clamp(s.x,-205,205);s.z=clamp(s.z,-205,205)}
}
function completeMission(){const m=routes[state.mission];if(!m)return;const dist=distanceTo(m.at);if(dist>15){notify('Сначала доберитесь до маяка',`До цели ещё ${Math.round(dist)} м`,true);return}
 state.money+=m.reward;state.reputation+=2;state.mission++;objectiveStart=distanceTo(activeDestination());safeSave();notify('МИССИЯ ВЫПОЛНЕНА',`+${m.reward} ₽ · Репутация +2`);refreshHUD();if(currentPanel==='missions')renderPanel('missions')}
function discoverSite(index){if(index<0||state.inCar)return;state.discovered.push(index);state.money+=60;state.reputation++;safeSave();notify('НАЙДЕНО МЕСТО ПАМЯТИ',`Открытие ${state.discovered.length}/12 · +60 ₽`);refreshHUD();if(currentPanel==='atlas')renderPanel('atlas')}
function interact(){if(currentPanel!=='none'){closePanel();return}const site=nearestDiscovery();if(site>=0&&!state.inCar){discoverSite(site);return}if(distanceTo(activeDestination())<=15){completeMission();return}notify('ДЕЙСТВИЕ НЕДОСТУПНО',state.inCar?'Доберитесь до маяка или выйдите из машины':'Подойдите к светящемуся монументу',true)}
function switchCar(){if(!state.inCar){if(hypot(state.x-state.parkedX,state.z-state.parkedZ)>5.7){notify('АВТОМОБИЛЬ ДАЛЕКО','Подойдите к оставленной машине',true);return}state.x=state.parkedX;state.z=state.parkedZ;state.inCar=true;notify('ВЫ В АВТОМОБИЛЕ','W — разгон · S — торможение · SPACE — ручник')}else if(Math.abs(state.speed)<1.5){state.parkedX=state.x;state.parkedZ=state.z;state.inCar=false;state.x=clamp(state.x+2.6,-205,205);notify('ПЕШИЙ РЕЖИМ','Подходите к монументам и нажимайте F')}else notify('СНАЧАЛА ОСТАНОВИТЕСЬ','Нельзя выйти из движущейся машины',true);safeSave();refreshHUD()}
function findDistrict(){const x=state.x,z=state.z;if(x>-52&&x<52&&z>-52&&z<52)return 'ЦЕНТР ИМПЕРИИ';if(z<-110)return 'СЕВЕРНЫЙ ПРОСПЕКТ';if(z>85)return 'ЮЖНЫЙ КВАРТАЛ';if(x< -55)return 'ДЕЛОВОЙ РАЙОН';if(x>55)return 'ВОСТОЧНЫЙ РАЙОН';return 'ЦЕНТРАЛЬНЫЙ ПРОСПЕКТ'}
function clockString(){const h=Math.floor(state.day),m=Math.floor((state.day-h)*60);return `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}`}
function gamePosition(){const s=state;return {x:s.x,z:s.z,angle:s.heading}}
function refreshHUD(){const s=state,m=routes[s.mission],dist=distanceTo(activeDestination());
 $('money').textContent=Math.floor(s.money).toLocaleString('ru-RU');$('reputation').textContent=String(s.reputation);$('mission-count').textContent=`${String(Math.min(6,s.mission+1)).padStart(2,'0')}/06`;
 $('chapter').textContent=m?`ГЛАВА ${String(s.mission+1).padStart(2,'0')} · ${m.ru}`:'КАМПАНИЯ / ЗАВЕРШЕНА';
 $('mission-title').innerHTML=m?'Город ждёт<br><em>своего правителя.</em>':'Империя<br><em>проснулась.</em>';
 if(s.mission>0&&m)$('mission-title').innerHTML=`${m.ru.split(' ').slice(0,2).join(' ')}<br><em>${m.ru.split(' ').slice(2).join(' ')||'НОВАЯ МИССИЯ'}.</em>`;
 $('mission-desc').textContent=m?m.desc:'Вы завершили главу. Продолжайте исследовать город, открывайте 12 мест памяти и улучшайте автомобиль.';
 $('obj-text').textContent=m?'ДОБЕРИТЕСЬ ДО ЦЕЛИ':'КАМПАНИЯ ЗАВЕРШЕНА';$('obj-hint').textContent=m?'У маяка нажмите F для завершения':'Свободное исследование города';
 $('distance').textContent=m?`${Math.round(dist)} М`:'ГОТОВО';
 $('district').textContent=findDistrict();$('time').textContent=clockString();$('weather-icon').textContent=s.rain?'☂':'☾';$('rain').classList.toggle('active',s.rain);$('app').classList.toggle('day',s.day>6&&s.day<17);
 $('car-name').textContent='OSGARD // '+autoSpecs[s.carIndex].name;$('speed').textContent=String(Math.round(Math.abs(s.speed)*3.6)).padStart(3,'0');
 $('gear').textContent=s.inCar?(s.speed<-.4?'R':s.speed>.4?'D':'N'):'P';
 $('fuel').textContent=`${Math.floor(s.fuel)}%`;$('health').textContent=`${Math.floor(s.health)}%`;$('fuel-bar').style.width=s.fuel+'%';$('health-bar').style.width=s.health+'%';
 $('speed-accent-inner').style.width=clamp(Math.abs(s.speed)/autoSpecs[s.carIndex].speed*100,0,100)+'%';$('handbrake-indicator').classList.toggle('on',Boolean(keys[' ']));
 $('compass-direction').textContent=`N · ${String(Math.round((s.heading*180/Math.PI+3600)%360)).padStart(3,'0')}°`;
 const prog=m?clamp((1-dist/Math.max(25,objectiveStart))*100,0,100):100;$('route-progress').style.width=prog+'%';$('route-percent').textContent=Math.round(prog)+'%';
 const canInteract=(nearestDiscovery(8.7)>=0&&!s.inCar)||dist<15;const inter=$('interaction');inter.hidden=!canInteract;$('interaction-title').textContent=dist<15?'ЗАВЕРШИТЬ МИССИЮ':'ИССЛЕДОВАТЬ МОНУМЕНТ';
 $('quick-info').innerHTML=s.inCar?'<span class="key">W</span> ГАЗ <span class="sep">/</span> <span class="key">S</span> ТОРМОЗ <span class="sep">/</span> <span class="key">A D</span> РУЛЬ <span class="sep">/</span> <span class="key">SPACE</span> РУЧНИК':'<span class="key">W A S D</span> ПЕРЕДВИЖЕНИЕ <span class="sep">/</span> <span class="key">F</span> ИССЛЕДОВАТЬ <span class="sep">/</span> <span class="key">E</span> СЕСТЬ В АВТО';
}
// Canvas road map (full-size and HUD) shares the same real coordinates as WebGL.
function drawMap(canvasEl,isFull=false){if(!canvasEl)return;const ctx=canvasEl.getContext('2d');if(!ctx)return;const w=canvasEl.width,h=canvasEl.height;ctx.clearRect(0,0,w,h);
 ctx.fillStyle='#091f28';ctx.fillRect(0,0,w,h);const zoom=isFull?Math.min((w-55)/440,(h-58)/440):Math.min(w/280,h/280);
 const ox=isFull?0:state.x,oz=isFull?0:state.z;const xy=(x,z)=>[w/2+(x-ox)*zoom,h/2+(z-oz)*zoom];
 ctx.save();ctx.strokeStyle='#21404a';ctx.lineWidth=1;for(let p=-240;p<=240;p+=25){const a=xy(p,-240),b=xy(p,240);ctx.beginPath();ctx.moveTo(...a);ctx.lineTo(...b);ctx.stroke();const c=xy(-240,p),d=xy(240,p);ctx.beginPath();ctx.moveTo(...c);ctx.lineTo(...d);ctx.stroke()}
 ctx.lineWidth=isFull?8:5;ctx.strokeStyle='#46616b';for(const p of grid){let a=xy(p,-235),b=xy(p,235);ctx.beginPath();ctx.moveTo(...a);ctx.lineTo(...b);ctx.stroke();a=xy(-235,p);b=xy(235,p);ctx.beginPath();ctx.moveTo(...a);ctx.lineTo(...b);ctx.stroke()}
 ctx.lineWidth=1;ctx.strokeStyle='#9a9770';ctx.setLineDash([2,6]);for(const p of grid){let a=xy(p,-235),b=xy(p,235);ctx.beginPath();ctx.moveTo(...a);ctx.lineTo(...b);ctx.stroke();a=xy(-235,p);b=xy(235,p);ctx.beginPath();ctx.moveTo(...a);ctx.lineTo(...b);ctx.stroke()}ctx.setLineDash([]);
 ctx.fillStyle='#29434c';for(let ix=0;ix<8;ix++)for(let iz=0;iz<8;iz++){const [x,y]=xy(-175+ix*50,-175+iz*50);ctx.fillRect(x-11*zoom,y-11*zoom,22*zoom,22*zoom)}
 for(let i=0;i<discoveries.length;i++){if(state.discovered.includes(i))continue;const [x,y]=xy(...discoveries[i]);if(x<0||x>w||y<0||y>h)continue;ctx.fillStyle='#7ce4cb';ctx.beginPath();ctx.arc(x,y,isFull?4:2.3,0,TAU);ctx.fill()}
 const target=routes[state.mission]?.at;if(target){const [x,y]=xy(...target),[px,py]=xy(state.x,state.z);ctx.lineWidth=1.7;ctx.strokeStyle='#d7bd7f';ctx.setLineDash([5,6]);ctx.beginPath();ctx.moveTo(px,py);ctx.lineTo(x,y);ctx.stroke();ctx.setLineDash([]);ctx.strokeStyle='#e2c17e';ctx.lineWidth=2;ctx.beginPath();ctx.arc(x,y,8+Math.sin(elapsed*3)*1.2,0,TAU);ctx.stroke();ctx.fillStyle='#f2d790';ctx.fillRect(x-2,y-2,4,4)}
 const [px,py]=xy(state.x,state.z);ctx.fillStyle='#79f8d9';ctx.shadowColor='#49f7cf';ctx.shadowBlur=14;ctx.save();ctx.translate(px,py);ctx.rotate(state.heading);ctx.beginPath();ctx.moveTo(0,-10);ctx.lineTo(-6,7);ctx.lineTo(0,4);ctx.lineTo(6,7);ctx.closePath();ctx.fill();ctx.restore();ctx.shadowBlur=0;
 ctx.strokeStyle='#3b6270';ctx.lineWidth=1;ctx.strokeRect(.5,.5,w-1,h-1);ctx.restore()}
const escaped=s=>String(s).replace(/[&<>"']/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
function panelButton(label,action,extra=''){return `<button class="panel-cta" data-action="${action}" ${extra}>${label}</button>`}
function renderPanel(kind){currentPanel=kind;const p=$('panel');if(kind==='none'){closePanel();return}p.classList.remove('hidden');p.setAttribute('aria-hidden','false');paused=true;
 document.querySelectorAll('.rail-button').forEach(b=>b.classList.toggle('selected',b.dataset.panel===kind));$('panel-overline').textContent='OSGARD // WORLD COMMAND';const body=$('panel-body');let html='';
 if(kind==='map'){
 $('panel-title').textContent='КАРТА ГОРОДА';html=`<p class="panel-lead">Живой город площадью более 170 000 м². Ваш автомобиль и цель связаны с настоящими игровыми координатами.</p><canvas class="map-full" id="bigmap" width="600" height="580" aria-label="Карта города с позицией игрока и целью"></canvas><div class="panel-row"><span>РАЙОН</span><strong>${escaped(findDistrict())}</strong></div><div class="panel-row"><span>До следующей цели</span><strong>${Math.round(distanceTo(activeDestination()))} м</strong></div>`
 }else if(kind==='missions'){
 $('panel-title').textContent='МИССИИ ГОРОДА';html=`<p class="panel-lead">Шесть настоящих маршрутов. Доезжайте до светового маяка и нажимайте <b>F</b>, чтобы получить награду. Прогресс сохраняется.</p>`;
 routes.forEach((m,i)=>{const done=i<state.mission,active=i===state.mission;html+=`<div class="panel-card ${active?'active':''}"><small>${String(i+1).padStart(2,'0')} / ${done?'ВЫПОЛНЕНО':active?'АКТИВНАЯ МИССИЯ':'НЕ ОТКРЫТА'}</small><h3>${escaped(m.ru)}</h3><p>${escaped(m.desc)}</p><footer><span>+ ${m.reward} ₽</span>${active?'<span>◉ АКТИВНО</span>':done?'<span>✓ ГОТОВО</span>':'<span>🔒</span>'}</footer></div>`})
 }else if(kind==='garage'){
 $('panel-title').textContent='ГАРАЖ И СЕРВИС';html=`<p class="panel-lead">Выбирайте машину, улучшайте скорость и ремонтируйте повреждения. Все изменения влияют на реальное управление в городе.</p>`;
 html+=`<div class="panel-card active"><small>ВАШ АВТОМОБИЛЬ</small><h3>${escaped(autoSpecs[state.carIndex].name)}</h3><p>Состояние ${Math.floor(state.health)}% · Топливо ${Math.floor(state.fuel)}%</p><footer><span>${Math.round(state.speed*3.6)} км/ч</span><span>${Math.floor(state.money)} ₽ на счету</span></footer></div><div class="panel-actions"><button data-action="repair">РЕМОНТ · 120 ₽</button><button data-action="refuel">ЗАПРАВИТЬ · 60 ₽</button></div><div class="panel-section">АВТОМОБИЛИ</div>`;
 autoSpecs.forEach((c,i)=>{const owned=state.owned.includes(i),selected=state.carIndex===i;html+=`<div class="panel-card ${selected?'active':''}"><small>${owned?'В ВАШЕМ ГАРАЖЕ':'ДОСТУПНА К ПОКУПКЕ'}</small><h3><span style="color:${c.color}">◆</span> OSGARD ${c.name}</h3><p>Макс. скорость ${Math.round(c.speed*3.6)} км/ч · Разгон ${c.accel.toFixed(1)} м/с²</p><footer><span>${i===0?'СТАРТОВАЯ':`${c.price} ₽`}</span>${selected?'<span>✓ ВЫБРАН</span>':panelButton(owned?'ВЫБРАТЬ':'КУПИТЬ','car-'+i)}</footer></div>`})
 }else if(kind==='atlas'){
 $('panel-title').textContent='АТЛАС ГОРОДА';html=`<p class="panel-lead">В городе спрятано 12 светящихся мест памяти. Найдите их на карте, <b>выйдите из автомобиля (E)</b> и нажмите <b>F</b> рядом с монументом. Первое открытие приносит 60 ₽.</p><div class="panel-card active"><small>ПРОГРЕСС ИССЛЕДОВАНИЙ</small><h3>${state.discovered.length} / 12 мест открыто</h3><p>Получено наград: ${state.discovered.length*60} ₽</p></div>`;
 discoveries.forEach((point,i)=>{const found=state.discovered.includes(i);html+=`<div class="panel-card"><small>МЕСТО ПАМЯТИ / ${String(i+1).padStart(2,'0')}</small><h3>${found?'✓':'✧'} ${found?'ОТКРЫТО':'НЕ ИССЛЕДОВАНО'} — УЗЕЛ ${i+1}</h3><p>Район ${Math.floor(i/4)+1} · ${point[0]} / ${point[1]}</p><footer><span>${found?'ДОСТИЖЕНИЕ':'+60 ₽'}</span><span>${found?'✓':`${Math.round(hypot(state.x-point[0],state.z-point[1]))} м`}</span></footer></div>`})
 }else if(kind==='help'){
 $('panel-title').textContent='УПРАВЛЕНИЕ';html=`<p class="panel-lead">Всё управление работает прямо в браузере. Играть можно бесплатно без регистрации. Прогресс сохраняется локально.</p>`;
 const list=[['W / ↑','ГАЗ / ВПЕРЁД'],['S / ↓','ТОРМОЗ / ЗАДНИЙ ХОД'],['A D / ← →','ПОВОРОТ / ХОДЬБА'],['SPACE','РУЧНИК (В МАШИНЕ)'],['E','СЕСТЬ / ВЫЙТИ'],['F','ДЕЙСТВИЕ / ЗАВЕРШИТЬ МИССИЮ'],['M','КАРТА'],['G','ГАРАЖ'],['J','ЗАДАНИЯ'],['N','СМЕНИТЬ ВРЕМЯ СУТОК'],['R','ДОЖДЬ / СУХО'],['ESC','ЗАКРЫТЬ МЕНЮ']];list.forEach(([a,b])=>{html+=`<div class="panel-row"><strong>${a}</strong><span>${b}</span></div>`});
 html+=`<div class="panel-section">НАСТРОЙКИ</div><div class="panel-actions"><button data-action="rain">${state.rain?'ВЫКЛЮЧИТЬ':'ВКЛЮЧИТЬ'} ДОЖДЬ</button><button data-action="day">ДЕНЬ / НОЧЬ</button><button data-action="sound">${sound?'ЗВУК ВЫКЛ':'ЗВУК ВКЛ'}</button></div><div class="panel-row"><span>Язык интерфейса</span><select id="language-select"><option value="ru" ${lang==='ru'?'selected':''}>Русский</option><option value="en" ${lang==='en'?'selected':''}>English</option><option value="zh" ${lang==='zh'?'selected':''}>中文</option></select></div><div class="panel-row"><span>Сохранение</span><strong>ЛОКАЛЬНО</strong></div><div class="panel-row"><span>Средний FPS</span><strong id="fps-value">${fps.toFixed(0)}</strong></div><div class="panel-actions"><button data-action="reset">НОВАЯ ИГРА / СБРОС</button></div>`;
 }else {renderPanel('help');return}
 body.innerHTML=html;
 if(kind==='map')drawMap($('bigmap'),true);
 body.querySelectorAll('[data-action]').forEach(btn=>btn.addEventListener('click',()=>handlePanelAction(btn.dataset.action)));
 const langSelect=body.querySelector('#language-select');if(langSelect)langSelect.addEventListener('change',e=>{lang=e.target.value;state.language=lang;translateUI();safeSave();notify('Язык интерфейса изменён')});
}
function handlePanelAction(action){if(action==='repair'){
 if(state.health>=99){notify('МАШИНА ИСПРАВНА','Ремонт не требуется');return}if(state.money<120){notify('НЕДОСТАТОЧНО СРЕДСТВ','Нужно 120 ₽',true);return}state.money-=120;state.health=100;notify('АВТОМОБИЛЬ ОТРЕМОНТИРОВАН','-120 ₽ · Состояние 100%');}
 else if(action==='refuel'){if(state.fuel>=99){notify('БАК ПОЛОН','Заправка не требуется');return}if(state.money<60){notify('НЕДОСТАТОЧНО СРЕДСТВ','Нужно 60 ₽',true);return}state.money-=60;state.fuel=100;notify('БАК ЗАПОЛНЕН','-60 ₽ · Топливо 100%')}
 else if(action.startsWith('car-')){const idx=Number(action.slice(4)),c=autoSpecs[idx];if(!c)return;if(!state.owned.includes(idx)){
 if(state.money<c.price){notify('НЕДОСТАТОЧНО СРЕДСТВ',`Нужно ${c.price} ₽`,true);return}state.money-=c.price;state.owned.push(idx);notify('НОВЫЙ АВТОМОБИЛЬ',`OSGARD ${c.name} приобретён`)}state.carIndex=idx;state.speed=0;notify('АВТОМОБИЛЬ ВЫБРАН',c.name)}
 else if(action==='rain'){state.rain=!state.rain;notify(state.rain?'НАЧАЛСЯ ДОЖДЬ':'ПОГОДА ЯСНА','Дорожное сцепление изменено')}
 else if(action==='day'){state.day=state.day>17||state.day<6?13.5:22.6;notify(state.day<17?'ДНЕВНОЙ РЕЖИМ':'НОЧНОЙ РЕЖИМ')}
 else if(action==='sound'){toggleSound()}
 else if(action==='reset'){if(!confirm('Удалить сохранённый прогресс 3D-города и начать заново? Стратегия останется без изменений.'))return;state=initial();objectiveStart=distanceTo(activeDestination());notify('НОВАЯ КАМПАНИЯ','Игровой прогресс сброшен')}
 safeSave();refreshHUD();renderPanel(currentPanel)
}
function closePanel(){currentPanel='none';paused=false;$('panel').classList.add('hidden');$('panel').setAttribute('aria-hidden','true');document.querySelectorAll('.rail-button').forEach(b=>b.classList.toggle('selected',b.dataset.panel==='none'))}
let audioCtx,osc,oscGain;
function toggleSound(){sound=!sound;try{if(sound){audioCtx ||= new (window.AudioContext||window.webkitAudioContext)();audioCtx.resume();if(!osc){osc=audioCtx.createOscillator();osc.type='sawtooth';oscGain=audioCtx.createGain();oscGain.gain.value=.0001;osc.connect(oscGain).connect(audioCtx.destination);osc.start()}oscGain.gain.setTargetAtTime(.008,audioCtx.currentTime,.08)}else if(oscGain)oscGain.gain.setTargetAtTime(.0001,audioCtx.currentTime,.1)}catch(e){sound=false;notify('Звук недоступен','Браузер ограничивает воспроизведение',true)}$('sound-btn').style.color=sound?'#e9ca80':''}
function interactAction(key){switch(key){case'e':switchCar();break;case'f':interact();break;case'm':currentPanel==='map'?closePanel():renderPanel('map');break;case'g':renderPanel('garage');break;case'j':renderPanel('missions');break;case'h':renderPanel('help');break;case'r':state.rain=!state.rain;notify(state.rain?'ДОЖДЬ':'ЯСНО','Сцепление с дорогой изменено');safeSave();break;case'n':state.day=state.day>17||state.day<6?13.5:22.6;notify('ВРЕМЯ СУТОК ИЗМЕНЕНО');safeSave();break;case'escape':closePanel();$('tutorial').hidden=true;break}}
window.addEventListener('keydown',e=>{if(e.repeat||['INPUT','SELECT','TEXTAREA'].includes(document.activeElement?.tagName))return;const key=e.key.toLowerCase();if([' ','arrowup','arrowdown','arrowleft','arrowright'].includes(key))e.preventDefault();keys[key]=true;if('efmgjhrn'.includes(key)&&key.length===1)interactAction(key);if(key==='escape')interactAction(key)});
window.addEventListener('keyup',e=>{keys[e.key.toLowerCase()]=false});window.addEventListener('blur',()=>{for(const k in keys)keys[k]=false});
document.querySelectorAll('.rail-button').forEach(b=>b.addEventListener('click',()=>b.dataset.panel==='none'?closePanel():currentPanel===b.dataset.panel?closePanel():renderPanel(b.dataset.panel)));
$('map-expand').addEventListener('click',()=>renderPanel('map'));$('panel-close').addEventListener('click',closePanel);
$('settings-btn').addEventListener('click',()=>renderPanel('help'));$('start-button').addEventListener('click',()=>{if(!state.introSeen){$('tutorial').hidden=false;paused=true}else{gameStarted=true;state.started=true;notify('МАРШРУТ АКТИВЕН','Двигайтесь в сторону бирюзового маяка. Нажмите F у цели.');safeSave()}});
$('tutorial-play').addEventListener('click',()=>{state.introSeen=true;state.started=true;gameStarted=true;paused=false;$('tutorial').hidden=true;safeSave();notify('ПОЕХАЛИ!','W — газ · S — тормоз · F — завершить миссию')});
$('full-btn').addEventListener('click',()=>{if(!document.fullscreenElement)document.documentElement.requestFullscreen?.().catch(()=>notify('Полный экран недоступен'));else document.exitFullscreen?.()});
$('sound-btn').addEventListener('click',toggleSound);
for(const btn of document.querySelectorAll('[data-touch]')){const key=btn.dataset.touch;btn.addEventListener('pointerdown',e=>{e.preventDefault();keys[key]=true;btn.setPointerCapture(e.pointerId);if(key==='e'||key==='f')interactAction(key)});for(const event of ['pointerup','pointercancel','lostpointercapture'])btn.addEventListener(event,()=>keys[key]=false)}
window.addEventListener('visibilitychange',()=>{if(document.hidden)safeSave()});window.addEventListener('beforeunload',safeSave);
window.addEventListener('resize',()=>{if(gl)resize()});
// The debug API is intentionally read-only by default and used by browser QA.
window.OSGARD_DEBUG={version:'v0.23-webgl-city',get state(){return JSON.parse(JSON.stringify(state))},get worldMeshes(){return buildings.length},get fps(){return fps},get renderAvailable(){return !!gl||!!fallbackCtx},get renderer(){return gl?'webgl2':'canvas2d'},missionDestination:()=>activeDestination().slice(),get completed(){return state.mission},reset:()=>{state=initial();safeSave();refreshHUD()},simulateInput:interactAction};
function onError(reason){console.error('OSGARD 3D engine:',reason);$('loading').classList.add('done');$('error').hidden=false;$('error-reason').textContent=String(reason?.message||reason||'Устройство не поддерживает WebGL2')}
let uiElapsed=0,mapElapsed=0;
function tickFrame(timestamp){const dt=clamp(lastFrame?(timestamp-lastFrame)/1000:1/60,0,.045);lastFrame=timestamp;
 try{
  updateGame(dt);render3D(elapsed,dt);uiElapsed+=dt;mapElapsed+=dt;
  if(uiElapsed>.09){refreshHUD();uiElapsed=0}
  if(mapElapsed>.14){drawMap(mapCanvas);if(currentPanel==='map')drawMap($('bigmap'),true);mapElapsed=0}
  fpsCounter++;fpsT+=dt;if(fpsT>.95){fps=fpsCounter/fpsT;fpsCounter=0;fpsT=0;const e=$('fps-value');if(e)e.textContent=String(Math.round(fps));if(sound&&osc&&audioCtx){osc.frequency.setTargetAtTime(62+Math.abs(state.speed)*4,audioCtx.currentTime,.12)}}
  requestAnimationFrame(tickFrame)
 }catch(err){onError(err)}
}
try{
 if(!gl&&!fallbackCtx)throw Error('Ваш браузер не поддерживает холст. Используйте современный Chrome, Edge или Firefox.');
 if(gl)initializeGL();else constructFallbackCity();resize();objectiveStart=Math.max(40,distanceTo(activeDestination()));refreshHUD();drawMap(mapCanvas);render3D(0,.016);
 setTimeout(()=>$('loading').classList.add('done'),450);
 requestAnimationFrame(tickFrame);
 console.info('OSGARD Ω CITY v0.23:',gl?'WebGL2':'Canvas 2.5D fallback','running',countStatic,'static vertices',buildings.length,'buildings');
}catch(err){onError(err)}
})();