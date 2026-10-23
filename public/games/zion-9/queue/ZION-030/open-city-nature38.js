/* ZION-030 v38 / Street Reality: natural foliage + urban weathering.
 * Exact playable street positions, physically interpretable details and bounded
 * InstancedMesh rendering. No new collisions, missions or persistent state.
 * Foliage blades deform at 12 Hz, not every rendered frame.
 */
(function(host){
 'use strict';
 const VERSION='38.0',TAU=Math.PI*2;
 const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
 const hash=(x,y,s)=>{
   let k=(Math.imul(x|0,374761393)^Math.imul(y|0,668265263)^Math.imul(s|0,2246822519))>>>0;
   k=Math.imul(k^(k>>>13),1274126177)>>>0;
   return ((k^(k>>>16))&65535)/65535;
 };
 function install({THREE,scene,rules,foliage=[],mobile=false,softwareGL=false,reducedMotion=false}){
   if(!THREE?.Group||!THREE?.InstancedMesh||!THREE?.BufferGeometry||
      !THREE?.Float32BufferAttribute||!scene||!rules?.buildingAt||!rules?.rand)
     throw Error('ZION38 requires the actual playable city and Three.js');
   const lite=Boolean(softwareGL||reducedMotion),ultra=!mobile&&!lite;
   const root=new THREE.Group();root.name='ZION38 / naturally aged living city';
   scene.add(root);
   const stats={version:VERSION,tier:lite?'LITE':mobile?'MOBILE':'ULTRA',
     authoredStreetTrees:0,leafBlades:0,branchInstances:0,fallenLeaves:0,
     facadeWaterStains:0,ventOxidationMarks:0,weatherAtlasBytes:0,
     instances:0,drawBatches:0,animatedUpdates:0,
     rain:false,night:false,highVisible:false,windStrength:0,
     reducedMotion:Boolean(reducedMotion)};
   const geometries=[],materials=[],textures=[];
   const addGeo=g=>(geometries.push(g),g);
   const addMat=m=>(materials.push(m),m);
   // Silhouette-shaped curved foliage is actual triangle geometry, NOT a
   // rectangular transparent billboard. The one blade mesh is instanced.
   const leafGeo=addGeo(new THREE.BufferGeometry());
   const points=[],uvs=[],indices=[];
   for(let i=0;i<=8;i++){
     const t=i/8,w=Math.pow(Math.max(0,Math.sin(Math.PI*t)),.80)*.225;
     const curvature=Math.sin(Math.PI*t)*.095;
     points.push(-w,t,curvature,w,t,curvature);
     uvs.push(0,t,1,t);
     if(i<8){
       const j=i*2;
       indices.push(j,j+1,j+2,j+1,j+3,j+2);
     }
   }
   leafGeo.setAttribute('position',new THREE.Float32BufferAttribute(points,3));
   leafGeo.setAttribute('uv',new THREE.Float32BufferAttribute(uvs,2));
   leafGeo.setIndex(indices);leafGeo.computeVertexNormals();
   const branchGeo=addGeo(new THREE.CylinderGeometry(.5,.5,1,6));
   const wallGeo=addGeo(new THREE.PlaneGeometry(1,1));
   const leafMat=addMat(new THREE.MeshStandardMaterial({
     color:0x619774,roughness:.92,metalness:0,
     side:THREE.DoubleSide,flatShading:false
   }));
   const litterMat=addMat(new THREE.MeshStandardMaterial({
     color:0x93815d,roughness:.98,metalness:0,side:THREE.DoubleSide
   }));
   const branchMat=addMat(new THREE.MeshStandardMaterial({
     color:0x544835,roughness:.94,metalness:0
   }));
   const trees=Array.isArray(foliage)?foliage.filter(t=>
     t?.position&&Number.isFinite(t.position.x)&&Number.isFinite(t.position.z)):[];
   stats.authoredStreetTrees=trees.length;
   const dummy=new THREE.Object3D(),leaves=[],branches=[],groundLeaves=[];
   let quality=lite?'adaptive':'high',raining=false,night=false,
     elapsed=0,lastFoliageUpdate=0,disposed=false;
   const leavesPerTree=lite?0:ultra?52:20;
   for(let n=0;n<trees.length;n++){
     const tree=trees[n],x=tree.position.x,z=tree.position.z;
     for(let k=0;k<leavesPerTree;k++){
       const a=k*2.3999632+hash(n,k,19)*.7;
       const r=.12+hash(k,n,27)*.52;
       const pos={x:x+Math.cos(a)*r,
         y:.82+hash(n,k,31)*.76,
         z:z+Math.sin(a)*r};
       const scale=.25+hash(n,k,37)*.20;
       leaves.push({pos,scale,ry:a+Math.PI*.40,
         rz:(hash(n,k,43)-.5)*1.3,
         phase:hash(n,k,47)*TAU});
     }
     if(!lite)for(let k=0;k<5;k++){
       const angle=(k/5)*TAU+hash(n,k,49)*.1;
       branches.push({x:x+Math.cos(angle)*.11,y:.91,z:z+Math.sin(angle)*.11,
         rx:Math.sin(angle)*.62,rz:-Math.cos(angle)*.62});
     }
     if(!lite)for(let k=0;k<(ultra?18:7);k++){
       const a=k*2.3999632;
       const r=.31+hash(k,n,53)*.66;
       groundLeaves.push({x:x+Math.cos(a)*r,z:z+Math.sin(a)*r,
         spin:hash(n,k,59)*TAU,scale:.12+hash(n,k,61)*.14});
     }
   }
   function buildInstanced(geo,material,entries,transform,name){
     if(!entries.length)return null;
     const mesh=new THREE.InstancedMesh(geo,material,entries.length);
     mesh.name='ZION38 / '+name;
     mesh.castShadow=false;mesh.receiveShadow=false;
     // Small decorative geometry is intentionally non-culling as one draw batch.
     mesh.frustumCulled=false;
     entries.forEach((entry,i)=>{transform(entry,i,0);mesh.setMatrixAt(i,dummy.matrix);});
     mesh.instanceMatrix.needsUpdate=true;root.add(mesh);
     stats.instances+=entries.length;stats.drawBatches++;
     return mesh;
   }
   function leafTransform(p,i,time){
     const sway=Math.sin(time*1.4+p.phase)*.076*(raining?1.46:1);
     dummy.position.set(p.pos.x,p.pos.y,p.pos.z);
     dummy.rotation.set(.17+Math.sin(time*1.15+p.phase)*.05,
       p.ry+sway,p.rz+Math.cos(time*.92+p.phase)*.052);
     dummy.scale.set(p.scale,p.scale,p.scale);
     dummy.updateMatrix();
   }
   const leafMesh=buildInstanced(leafGeo,leafMat,leaves,leafTransform,'living leaf canopies');
   stats.leafBlades=leaves.length;
   buildInstanced(branchGeo,branchMat,branches,p=>{
     dummy.position.set(p.x,p.y,p.z);dummy.rotation.set(p.rx,0,p.rz);
     dummy.scale.set(.033,.45,.033);dummy.updateMatrix();
   },'thin wood twigs');
   stats.branchInstances=branches.length;
   buildInstanced(leafGeo,litterMat,groundLeaves,p=>{
     dummy.position.set(p.x,.018,p.z);
     dummy.rotation.set(-Math.PI/2,0,p.spin);
     dummy.scale.set(p.scale,p.scale,p.scale);dummy.updateMatrix();
   },'windblown ground leaves');
   stats.fallenLeaves=groundLeaves.length;
   // One 96x192 worn facade/deposit texture, reused across all 68 buildings.
   // Grime follows material age rather than random, saturated colored noise.
   function makeStainAtlas(){
     if(lite||!THREE.CanvasTexture||typeof document==='undefined')return null;
     const width=96,height=192;
     const canvas=document.createElement('canvas');
     canvas.width=width;canvas.height=height;
     const g=canvas.getContext('2d');if(!g?.createImageData||!g.putImageData)return null;
     const image=g.createImageData(width,height),d=image.data;
     for(let y=0;y<height;y++)for(let x=0;x<width;x++){
       const u=x/width,v=y/height,k=(y*width+x)*4;
       const channel1=Math.exp(-Math.pow((u-.25-.025*Math.sin(v*15))/.076,2));
       const channel2=Math.exp(-Math.pow((u-.70+.036*Math.sin(v*10))/.048,2));
       const blotch=hash(x>>2,y>>3,107)*.28+hash(x,y,109)*.09;
       const fade=Math.pow(Math.max(0,Math.sin(Math.PI*v)),.68);
       const dirt=clamp((channel1*.58+channel2*.37)*(.72+blotch)*fade,0,.84);
       d[k]=63;d[k+1]=70;d[k+2]=59;
       d[k+3]=Math.round(dirt*255);
     }
     g.putImageData(image,0,0);
     const texture=new THREE.CanvasTexture(canvas);
     texture.colorSpace=THREE.SRGBColorSpace;
     texture.magFilter=THREE.LinearFilter;
     texture.minFilter=THREE.LinearMipmapLinearFilter;
     textures.push(texture);stats.weatherAtlasBytes=width*height*4;
     return texture;
   }
   const stainMap=makeStainAtlas();
   let stainMat=null,stainMesh=null;
   if(stainMap){
     stainMat=addMat(new THREE.MeshBasicMaterial({
       map:stainMap,color:0xdad4c2,transparent:true,opacity:.31,
       depthWrite:false,side:THREE.DoubleSide,polygonOffset:true,
       polygonOffsetFactor:-1,toneMapped:true
     }));
     const stains=[];
     for(let x=-6;x<=6;x++)for(let z=-6;z<=6;z++){
       if(!rules.buildingAt(x,z))continue;
       const r=rules.rand(x,z),h=2.6+r*5.15;
       const w=.68+rules.rand(z,x)*.18;
       const d=.68+rules.rand(x+5,z-4)*.17;
       const front=z+d/2+.106;
       for(let side of [-1,1]){
         const y=Math.min(h-.25,.30+rules.rand(x+side,z,139)*2);
         const sx=.16+rules.rand(x,z+side,151)*.15;
         stains.push({x:x+side*w*.27,y,z:front,sx,sy:.44+rules.rand(z,x+side,171)*.41});
       }
       if(ultra&&r>.68){
         stains.push({x,y:h-.68,z:front,sx:.19,sy:.72});
         stats.ventOxidationMarks++;
       }
     }
     stainMesh=buildInstanced(wallGeo,stainMat,stains,p=>{
       dummy.position.set(p.x,p.y,p.z);
       dummy.rotation.set(0,0,0);
       dummy.scale.set(p.sx,p.sy,1);dummy.updateMatrix();
     },'rain drips and ageing facades');
     stats.facadeWaterStains=stains.length;
   }
   function syncEnvironment({raining:rain=false,dayMode=0}={}){
     raining=Boolean(rain);night=dayMode===1;
     stats.rain=raining;stats.night=night;
     stats.windStrength=lite?0:raining?1.46:1;
     leafMat.color.setHex(night?0x497561:raining?0x537f65:0x619774);
     litterMat.color.setHex(raining?0x62563e:0x93815d);
     if(stainMat)stainMat.opacity=(raining?.53:.27)*(night?.78:1);
   }
   function setQuality(mode){
     quality=mode;
     stats.highVisible=!lite&&mode!=='eco'&&mode!=='adaptive';
     root.visible=stats.highVisible;
     return stats.highVisible;
   }
   function update(dt){
     if(disposed||lite||quality==='eco'||quality==='adaptive'||
        !Number.isFinite(dt)||dt<=0||!leafMesh)return;
     elapsed+=Math.min(dt,.05);
     if(elapsed-lastFoliageUpdate<.082)return;
     lastFoliageUpdate=elapsed;
     leaves.forEach((entry,i)=>{
       leafTransform(entry,i,elapsed);
       leafMesh.setMatrixAt(i,dummy.matrix);
     });
     leafMesh.instanceMatrix.needsUpdate=true;
     stats.animatedUpdates++;
   }
   function dispose(){
     if(disposed)return;disposed=true;
     scene.remove(root);
     geometries.forEach(g=>g.dispose());
     materials.forEach(m=>m.dispose());
     textures.forEach(t=>t.dispose());
   }
   setQuality(lite?'adaptive':'high');
   syncEnvironment();
   return Object.freeze({get stats(){return Object.freeze({...stats});},
     update,syncEnvironment,setQuality,dispose});
 }
 host.ZION030_NATURE38=Object.freeze({VERSION,install});
})(window);
