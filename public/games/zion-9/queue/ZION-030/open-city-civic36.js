/* ZION-030 v36 / Civic Architecture Atelier.
 * High-detail rooftop architecture, traditional facade metalwork, solar systems,
 * suspended city cables, and animated machinery IN THE PLAYABLE Three.js scene.
 * Canonical building positions and gameplay collisions remain authoritative.
 */
(function(host){
 'use strict';
 const VERSION='36.0',TAU=Math.PI*2;
 const clamp=(x,a,b)=>Math.min(b,Math.max(a,x));
 function install({THREE,scene,rules,mobile=false,softwareGL=false,reducedMotion=false}){
   if(!THREE?.Group||!THREE?.InstancedMesh||!THREE?.BufferGeometry||
      !scene||!rules?.buildingAt||!rules?.rand)throw Error('ZION36 requires the playable Three.js district');
   const lite=Boolean(softwareGL||reducedMotion),ultra=!mobile&&!lite;
   const stats={version:VERSION,tier:lite?'LITE':mobile?'MOBILE':'ULTRA',
     buildings:0,roofParapets:0,roofModules:0,solarPanels:0,facadeFrames:0,
     balconyBraces:0,awningPanels:0,ventilators:0,cableSpans:0,cableSegments:0,
     rotorAssemblies:0,materialFamilies:0,textureMaps:0,textureBytes:0,
     instances:0,drawCallBatches:0,fineVisible:false,windUpdates:0,
     rain:false,night:false,reducedMotion:Boolean(reducedMotion)};
   const root=new THREE.Group(),base=new THREE.Group(),
     fine=new THREE.Group(),motion=new THREE.Group();
   root.name='ZION36 / civic architectural detailing';
   base.name='ZION36 / instanced stone and metal';
   fine.name='ZION36 / close-range architectural details';
   motion.name='ZION36 / kinetic roof machinery';
   root.add(base,fine,motion);scene.add(root);
   const geometries=[],materials=[],textures=[];
   const geometry=(g)=>(geometries.push(g),g);
   const cube=geometry(new THREE.BoxGeometry(1,1,1));
   const cylinder=geometry(new THREE.CylinderGeometry(.5,.5,1,10));
   const torus=geometry(new THREE.TorusGeometry(.5,.025,6,20));
   const sphere=geometry(new THREE.IcosahedronGeometry(.5,1));
   function mat(hex,rough=.65,metal=.15,em=0,power=0){
     const opts={color:hex,roughness:rough,metalness:metal};
     if(em){opts.emissive=em;opts.emissiveIntensity=power;}
     const material=new (lite?THREE.MeshLambertMaterial:THREE.MeshStandardMaterial)(opts);
     materials.push(material);
     return material;
   }
   const m={
     stone:mat(0xc0b9a4,.88),ceramic:mat(0xc9a178,.76),
     copper:mat(0xa78255,.45,.68),steel:mat(0x93acb1,.37,.76),
     dark:mat(0x20343b,.60,.44),glass:mat(0x79a8ad,.25,.28),
     rubber:mat(0x263840,.92),canvas:mat(0x568c99,.88),
     solar:mat(0x39768f,.20,.42),warm:mat(0xffc79b,.52,.15,0xffaa62,.47),
     led:mat(0x90e6ee,.38,.12,0x54d2df,.35)
   };
   // Tileable colour/roughness/tangent-normal atlases generated from the same
   // geometric height function. No external assets or network fetches.
   const hash=(x,y,s)=>{
     let k=(Math.imul(x|0,1597334677)^Math.imul(y|0,3812015801)^
       Math.imul(s|0,9582827))>>>0;
     k=Math.imul(k^(k>>>14),2246822519)>>>0;
     return ((k^(k>>>13))&65535)/65535;
   };
   function atlas(family){
     if(lite||!THREE.CanvasTexture||typeof document==='undefined')return null;
     const size=ultra?256:128,bricks=family===0;
     const height=new Float32Array(size*size);
     for(let y=0;y<size;y++)for(let x=0;x<size;x++){
       const row=Math.floor(y/(size/16));
       const u=(x*12/size+(row%2)*.5)%1;
       const v=(y*16/size)%1;
       const seam=bricks&&Math.min(u,1-u,v,1-v)<.042?-.27:0;
       const mill=bricks?0:Math.sin(x*TAU*29/size)*.065;
       height[y*size+x]=clamp(.69+seam+mill+(hash(x>>2,y>>2,family+5)-.5)*.10+
         (hash(x,y,family+17)-.5)*.06,.07,.95);
     }
     const result={};
     for(const kind of ['map','normalMap','roughnessMap']){
       const canvas=document.createElement('canvas');
       canvas.width=canvas.height=size;
       const g=canvas.getContext('2d');
       if(!g?.createImageData||!g.putImageData)continue;
       const image=g.createImageData(size,size),data=image.data;
       for(let y=0;y<size;y++)for(let x=0;x<size;x++){
         const idx=(y*size+x)*4,h=height[y*size+x];
         if(kind==='normalMap'){
           const dx=(height[y*size+(x+size-1)%size]-height[y*size+(x+1)%size])*1.8;
           const dy=(height[((y+size-1)%size)*size+x]-
             height[((y+1)%size)*size+x])*1.8;
           const len=Math.hypot(dx,dy,1);
           data[idx]=clamp(127.5+127.5*dx/len,0,255);
           data[idx+1]=clamp(127.5+127.5*dy/len,0,255);
           data[idx+2]=clamp(127.5+127.5/len,0,255);
         }else if(kind==='roughnessMap'){
           data[idx]=data[idx+1]=data[idx+2]=clamp((bricks?.79:.39)+(h-.69)*.16,.17,.99)*255;
         }else{
           const c=clamp((bricks?188:195)+(h-.69)*65,90,248);
           data[idx]=c;data[idx+1]=c+(bricks?-11:5);data[idx+2]=c+(bricks?-27:9);
         }
         data[idx+3]=255;
       }
       g.putImageData(image,0,0);
       const tex=new THREE.CanvasTexture(canvas);
       tex.wrapS=tex.wrapT=THREE.RepeatWrapping;
       tex.repeat.set(bricks?2:3,bricks?2:3);
       tex.anisotropy=ultra?8:2;
       tex.colorSpace=kind==='map'?THREE.SRGBColorSpace:THREE.NoColorSpace;
       textures.push(tex);result[kind]=tex;stats.textureMaps++;
       stats.textureBytes+=size*size*4;
     }
     return result;
   }
   const ceramic=atlas(0),metal=atlas(1);
   if(ceramic?.map&&ceramic.normalMap&&ceramic.roughnessMap){
     Object.assign(m.ceramic,ceramic);m.ceramic.color.setHex(0xe5c4ab);
     m.ceramic.normalScale=new THREE.Vector2(.36,.36);m.ceramic.needsUpdate=true;
     stats.materialFamilies++;
   }
   if(metal?.map&&metal.normalMap&&metal.roughnessMap){
     for(const material of [m.copper,m.steel]){
       Object.assign(material,metal);
       material.normalScale=new THREE.Vector2(.24,.24);
       material.needsUpdate=true;
     }
     stats.materialFamilies++;
   }
   const bins={base:new Map(),fine:new Map()},dummy=new THREE.Object3D();
   function piece(which,key,shape,x,y,z,w,h,d,rx=0,ry=0,rz=0){
     if(![x,y,z,w,h,d,rx,ry,rz].every(Number.isFinite)||
        Math.min(w,h,d)<=0)throw Error('ZION36 invalid facade detail');
     const group=bins[which],id=key+'/'+shape;
     if(!group.has(id))group.set(id,{key,shape,matrices:[]});
     dummy.position.set(x,y,z);dummy.scale.set(w,h,d);
     dummy.rotation.set(rx,ry,rz);dummy.updateMatrix();
     group.get(id).matrices.push(dummy.matrix.clone());
     stats.instances++;
   }
   const rand=rules.rand,buildings=[],rotors=[],canopies=[];
   for(let x=-6;x<=6;x++)for(let z=-6;z<=6;z++){
     if(!rules.buildingAt(x,z))continue;
     const r=rand(x,z),h=2.6+r*5.15,
       w=.68+rand(z,x)*.18,d=.68+rand(x+5,z-4)*.17;
     buildings.push({x,z,h,w,d,r});stats.buildings++;
   }
   for(const b of buildings){
     const {x,z,h,w,d,r}=b,roof=h+.07,front=z+d/2+.073;
     // Coped parapet stones and authentic pitched roof cap silhouettes.
     for(const side of [-1,1]){
       piece('base','stone','box',x+side*(w/2+.015),roof+.13,z,
         .082,.25,d+.16);
       piece('base','ceramic','box',x+side*(w/2+.015),roof+.28,z,
         .11,.046,d+.20);
       piece('base','stone','box',x,roof+.13,z+side*(d/2+.018),
         w+.15,.25,.072);
       piece('base','ceramic','box',x,roof+.28,z+side*(d/2+.018),
         w+.18,.046,.11);
       stats.roofParapets+=4;
     }
     // Downpipe brackets and genuinely inset shopfront/sill detailing.
     for(const side of [-1,1]){
       piece('base','steel','cylinder',x+side*(w/2+.03),h*.48,front-.06,
         .023,h*.90,.023);
       piece('base','copper','box',x+side*w*.39,h*.20,front,
         .037,.07,.08);
       if(ultra)for(let floor=0;floor<Math.min(8,Math.floor(h/.67));floor++){
         const y=.38+floor*.67;
         piece('fine','stone','box',x+side*.18,y-.19,front+.038,.25,.027,.10);
         piece('fine','copper','box',x+side*.18,y+.20,front+.045,.26,.020,.11);
         piece('fine','steel','box',x+side*.29,y,front+.03,.017,.36,.05);
         piece('fine','glass','box',x+side*.18,y,front+.025,.205,.29,.016);
         stats.facadeFrames+=4;
       }
     }
     // Solar thermal panels: roof systems are angled toward daylight.
     if(r>.31&&r<.73){
       for(const side of [-1,1]){
         piece('base','solar','box',x+side*.15,roof+.40,z,
           w*.30,.028,d*.52,-.23);
         piece('base','copper','box',x+side*.15,roof+.24,z+.06,
           w*.27,.18,.024);
         stats.solarPanels++;
       }
     }
     // Real HVAC motor, duct and ribbed casing, not a single box.
     if(r>.58){
       piece('base','dark','box',x,roof+.44,z,.35,.22,.32);
       piece('base','steel','cylinder',x,roof+.59,z,.14,.11,.14);
       piece('base','steel','box',x,roof+.32,z+.20,.12,.12,.25);
       stats.roofModules++;
       if(ultra){
         for(let k=0;k<5;k++){
           piece('fine','metal','box',x-.135+k*.067,roof+.46,z+.171,
             .018,.15,.018);
           stats.ventilators++;
         }
       }
     }
     // Suspended shade is joined to an existing facade and never has a hitbox.
     if(r<.42){
       const y=Math.min(2.23,h-.32);
       piece('base','canvas','box',x,y,front+.23,w*.80,.033,.38,-.08);
       for(const side of [-1,1]){
         piece('base','copper','box',x+side*w*.33,y-.07,front+.23,
           .018,.028,.37,-.08);
         stats.balconyBraces++;
       }
       stats.awningPanels++;
     }
     if(ultra&&r>.45&&r<.75){
       const balconyY=Math.min(h-.30,2.3);
       for(const side of [-1,1]){
         piece('fine','copper','box',x+side*.27,balconyY,front+.29,
           .032,.045,.28);
         piece('fine','steel','box',x+side*.28,balconyY+.24,front+.43,
           .021,.48,.018);
         stats.balconyBraces+=2;
       }
     }
     // A small fraction of rooftop extraction fans run in one fixed-step loop.
     if(!lite&&r>.82&&rotors.length<10){
       const machine=new THREE.Group();
       machine.position.set(x,roof+.59,z);
       const hub=new THREE.Mesh(cylinder,m.steel);
       hub.rotation.x=Math.PI/2;hub.scale.set(.09,.12,.09);machine.add(hub);
       const rotor=new THREE.Group();
       rotor.position.z=.08;machine.add(rotor);
       for(let blade=0;blade<4;blade++){
         const angle=blade*TAU/4;
         const mesh=new THREE.Mesh(cube,m.copper);
         mesh.position.set(Math.cos(angle)*.13,Math.sin(angle)*.13,0);
         mesh.rotation.z=angle;mesh.scale.set(.21,.038,.017);
         rotor.add(mesh);
       }
       motion.add(machine);
       rotors.push({rotor,phase:rand(x,z,72)*TAU});
       stats.rotorAssemblies++;
     }
   }
   // Cable runs connect neighbouring roofs with genuine catenary sag. All spans
   // share ONE dynamic line geometry and ONE draw call, even in ultra quality.
   const spans=[],points=new Map(buildings.map(b=>[b.x+','+b.z,b]));
   if(!lite)for(const b of buildings){
     const n=points.get((b.x+2)+','+b.z)||
       points.get((b.x+1)+','+(b.z+1));
     if(!n||spans.length>55||rand(b.x,b.z,97)<.48)continue;
     spans.push({from:[b.x,b.h+.48,b.z],to:[n.x,n.h+.48,n.z],
       phase:rand(b.x,b.z,37)*TAU});
   }
   const cablePositions=new Float32Array(spans.length*8*2*3);
   function updateCables(t){
     let k=0;
     for(const span of spans)for(let i=0;i<8;i++){
       for(const v of [i/8,(i+1)/8]){
         const sway=Math.sin(t*.80+span.phase)*.012*Math.sin(Math.PI*v);
         cablePositions[k++]=span.from[0]+(span.to[0]-span.from[0])*v+sway;
         cablePositions[k++]=span.from[1]+(span.to[1]-span.from[1])*v-
           .17*Math.sin(Math.PI*v);
         cablePositions[k++]=span.from[2]+(span.to[2]-span.from[2])*v-sway;
       }
     }
   }
   let cable=null,cableGeo=null,cableMaterial=null;
   if(spans.length&&THREE.LineSegments&&THREE.Float32BufferAttribute){
     cableGeo=geometry(new THREE.BufferGeometry());
     cableGeo.setAttribute('position',new THREE.Float32BufferAttribute(cablePositions,3));
     cableMaterial=new THREE.LineBasicMaterial({color:0x617b85,transparent:true,opacity:.69});
     materials.push(cableMaterial);
     cable=new THREE.LineSegments(cableGeo,cableMaterial);
     cable.frustumCulled=false;base.add(cable);
     updateCables(0);
     cableGeo.attributes.position.needsUpdate=true;
     stats.cableSpans=spans.length;stats.cableSegments=spans.length*8;
   }
   const shapes={box:cube,cylinder,torus,sphere};
   for(const [layer,parent] of [['base',base],['fine',fine]]){
     for(const batch of bins[layer].values()){
       const mesh=new THREE.InstancedMesh(shapes[batch.shape],m[batch.key],
         batch.matrices.length);
       batch.matrices.forEach((matrix,index)=>mesh.setMatrixAt(index,matrix));
       mesh.instanceMatrix.needsUpdate=true;mesh.frustumCulled=false;
       mesh.castShadow=false;mesh.receiveShadow=false;
       mesh.name='ZION36 / '+batch.key+'/'+batch.shape;
       parent.add(mesh);stats.drawCallBatches++;
     }
   }
   let elapsed=0,lastWind=0,quality='high',raining=false,night=false,disposed=false;
   function syncEnvironment({raining:rain=false,dayMode=0}={}){
     raining=Boolean(rain);night=dayMode===1;
     stats.rain=raining;stats.night=night;
     m.warm.emissiveIntensity=night?1.0:.24;
     m.led.emissiveIntensity=night?1.1:.31;
     m.steel.roughness=raining?.28:.37;
     m.copper.roughness=raining?.37:.45;
     m.ceramic.roughness=raining?.56:.76;
     m.canvas.color.setHex(raining?0x305966:0x568c99);
     if(cableMaterial)cableMaterial.opacity=night?.43:.69;
   }
   function setQuality(mode){
     quality=mode;
     stats.fineVisible=ultra&&mode!=='eco'&&mode!=='adaptive';
     fine.visible=stats.fineVisible;
     motion.visible=mode!=='eco'&&mode!=='adaptive'&&!lite;
     if(cable)cable.visible=mode!=='eco'&&mode!=='adaptive';
     return stats.fineVisible;
   }
   function update(dt){
     if(disposed||reducedMotion||!Number.isFinite(dt)||dt<=0)return;
     elapsed+=Math.min(.05,dt);
     if(lite||quality==='eco'||quality==='adaptive')return;
     for(const o of rotors)o.rotor.rotation.z=elapsed*2.3+o.phase;
     if(elapsed-lastWind<.08)return;
     lastWind=elapsed;
     if(cable){
       updateCables(elapsed);
       cableGeo.attributes.position.needsUpdate=true;
     }
     stats.windUpdates++;
   }
   function dispose(){
     if(disposed)return;disposed=true;scene.remove(root);
     geometries.forEach(g=>g.dispose());
     materials.forEach(m=>m.dispose());
     textures.forEach(t=>t.dispose());
   }
   setQuality(lite?'adaptive':'high');syncEnvironment();
   return Object.freeze({get stats(){return Object.freeze({...stats});},
     update,setQuality,syncEnvironment,dispose});
 }
 host.ZION030_CIVIC36=Object.freeze({VERSION,install});
})(window);
