/* ZION-030 v31 / ARCHVIZ & VEHICLE DETAIL PACK
 * Real playable Three.js geometry. Shader budgets and deterministic instancing.
 * No external texture downloads, no changes to mission/physics/save state.
 */
(function(host){
  'use strict';
  const VERSION='31.0';
  const number=v=>Number.isFinite(v);
  function install({THREE,scene,rules,detailKit,mobile=false,softwareGL=false,reducedMotion=false}){
    if(!THREE||!scene||!rules?.buildingAt||!rules?.rand)throw Error('ZION31 scene dependencies missing');
    const lite=Boolean(softwareGL||reducedMotion);
    const ultra=!lite&&!mobile;
    const random=rules.rand;
    const low=new THREE.Group(),high=new THREE.Group();
    low.name='ZION31 / cinematic street architecture';
    high.name='ZION31 / ultra fine masonry and vehicle trim';
    scene.add(low,high);
    const cube=new THREE.BoxGeometry(1,1,1);
    const cylinder=new THREE.CylinderGeometry(1,1,1,12);
    const sphere=new THREE.IcosahedronGeometry(1,1);
    const geometries=[cube,cylinder,sphere];
    const ownedTextures=[],ownedMats=[],ownedMeshes=[];
    const pick={cube,cylinder,sphere};
    const dummy=new THREE.Object3D();
    const bins=new Map();
    let currentRaining=false,currentNight=false;
    const stats={version:VERSION,tier:lite?'LITE':mobile?'MOBILE':'ULTRA',facades:0,balconyRails:0,
      rooftopAssets:0,streetFixtures:0,foliageAssets:0,vehicleParts:0,avatarParts:0,
      instances:0,drawCallBatches:0,vehicleBatches:0,textureMaps:0,wetSurfaces:0,signs:0,wetVisible:false,highDetailVisible:false};
    const texSize=ultra?256:128;
    function makeTexture(kind){
      if(lite||typeof document==='undefined'||!THREE.CanvasTexture)return null;
      const canvas=document.createElement('canvas');
      canvas.width=canvas.height=texSize;
      const ctx=canvas.getContext('2d');
      if(!ctx)return null;
      const img=ctx.createImageData(texSize,texSize);
      for(let y=0;y<texSize;y++)for(let x=0;x<texSize;x++){
        const p=(y*texSize+x)*4;
        const rand=((x*374761393+y*668265263+kind*2246822519)>>>0);
        const grain=(rand^(rand>>>13))&31;
        let color=0;
        if(kind===1)color=145+grain*.9-((y%24)<2?26:0)-((x%53)<2?12:0);
        else if(kind===2)color=77+grain*.85-((x%19)===0?23:0);
        else if(kind===3)color=65+grain*.9-((x+y*2)%89<2?20:0);
        else if(kind===4)color=98+grain*.85;
        img.data[p]=Math.max(0,Math.min(255,color+(kind===1?9:0)));
        img.data[p+1]=Math.max(0,Math.min(255,color+(kind===2?5:0)));
        img.data[p+2]=Math.max(0,Math.min(255,color+(kind===3?6:0)));
        img.data[p+3]=255;
      }
      ctx.putImageData(img,0,0);
      if(kind===1){
        ctx.lineWidth=1;ctx.strokeStyle='rgba(32,35,40,.32)';
        for(let y=0;y<texSize;y+=24){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(texSize,y);ctx.stroke();}
        for(let y=0;y<texSize;y+=24)for(let x=(y/24%2)*26;x<texSize;x+=52){
          ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x,y+24);ctx.stroke();
        }
      }
      if(kind===3){
        ctx.lineWidth=1;ctx.strokeStyle='rgba(12,20,24,.40)';
        for(let n=0;n<16;n++){
          const x=random(n,7)*texSize,y=random(n,9)*texSize;
          ctx.beginPath();ctx.moveTo(x,y);
          ctx.lineTo(x+random(n,12)*16-8,y+random(n,13)*12-6);ctx.stroke();
        }
      }
      const t=new THREE.CanvasTexture(canvas);
      t.wrapS=t.wrapT=THREE.RepeatWrapping;
      t.colorSpace=THREE.SRGBColorSpace;
      t.anisotropy=2;
      if(kind===3)t.repeat.set(12,12);
      ownedTextures.push(t);stats.textureMaps++;
      return t;
    }
    const masonryMap=makeTexture(1),metalMap=makeTexture(2),asphaltMap=makeTexture(3),woodMap=makeTexture(4);
    // Matching linear normal/roughness atlases supply real microrelief under
    // grazing sunrise lights and keep their memory bounded to the active tier.
    function microMap(kind,normal){
      if(lite||typeof document==='undefined'||!THREE.CanvasTexture)return null;
      const c=document.createElement('canvas');c.width=c.height=texSize;
      const g=c.getContext('2d');if(!g)return null;
      const pixels=g.createImageData(texSize,texSize);
      for(let y=0;y<texSize;y++)for(let x=0;x<texSize;x++){
        const p=(y*texSize+x)*4;
        const grain=((x*73856093)^(y*19349663)^(kind*83492791))>>>0;
        const cut=kind===1&&(y%24===0||(x%52===0&&Math.floor(y/24)%2===0));
        if(normal){
          pixels.data[p]=Math.max(0,Math.min(255,128+((grain&31)-15)-(cut?18:0)));
          pixels.data[p+1]=Math.max(0,Math.min(255,128+(((grain>>>7)&31)-15)-(cut?18:0)));
          pixels.data[p+2]=245;
        }else{
          const v=Math.max(40,Math.min(250,180+(grain&31)*1.7-(cut?50:0)));
          pixels.data[p]=pixels.data[p+1]=pixels.data[p+2]=v;
        }
        pixels.data[p+3]=255;
      }
      g.putImageData(pixels,0,0);
      const tex=new THREE.CanvasTexture(c);
      tex.colorSpace=THREE.NoColorSpace;
      tex.wrapS=tex.wrapT=THREE.RepeatWrapping;
      if(kind===3)tex.repeat.set(12,12);
      tex.anisotropy=2;
      ownedTextures.push(tex);stats.textureMaps++;
      return tex;
    }
    const masonryNormal=microMap(1,true),masonryRough=microMap(1,false);
    const asphaltNormal=microMap(3,true),asphaltRough=microMap(3,false);
    function mat(color,roughness=.72,metalness=.05,emissive=0,intensity=0,map=null,alpha=1){
      const opts={color,roughness,metalness,transparent:alpha<1,opacity:alpha};
      if(emissive){opts.emissive=emissive;opts.emissiveIntensity=intensity;}
      if(map)opts.map=map;
      if(map===masonryMap&&masonryNormal){opts.normalMap=masonryNormal;opts.roughnessMap=masonryRough;}
      if(map===asphaltMap&&asphaltNormal){opts.normalMap=asphaltNormal;opts.roughnessMap=asphaltRough;}
      const m=lite?new THREE.MeshLambertMaterial(opts):new THREE.MeshStandardMaterial(opts);
      ownedMats.push(m);return m;
    }
    const stone=mat(0xb4a898,.85,.05,0,0,masonryMap);
    const limestone=mat(0x8a969d,.89,.02,0,0,masonryMap);
    const blackMetal=mat(0x2e3d46,.43,.65,0,0,metalMap);
    const anodized=mat(0x7f9298,.33,.73,0,0,metalMap);
    const timber=mat(0x8f6653,.86,.03,0,0,woodMap);
    const ceramic=mat(0x287a8e,.24,.15);
    const roofTar=mat(0x333d42,.98,.0,0,0,asphaltMap);
    const copper=mat(0x967d5c,.37,.61);
    const amber=mat(0xffdfb3,.38,.04,0xffa14d,.73);
    const cyan=mat(0xa9faff,.31,.16,0x4bdcf0,.74);
    const leaf0=mat(0x47734f,.98,.0);
    const leaf1=mat(0x6c9059,.97,.0);
    const chrome=mat(0xc7d9e0,.23,.85);
    const glass=mat(0x285772,.16,.25,0x0f3246,.11);
    const rubber=mat(0x141d22,1,.03);
    const wet=mat(0x205169,.09,.5,0x153042,.03,null,.57);
    const palette={stone,limestone,blackMetal,anodized,timber,ceramic,roofTar,copper,amber,cyan,leaf0,leaf1,chrome,glass,rubber,wet};
    function put(tier,key,x,y,z,w,h,d,yaw=0,pitch=0,roll=0,shape='cube'){
      if(![x,y,z,w,h,d,yaw,pitch,roll].every(number)||Math.min(w,h,d)<=0)throw Error('ZION31 invalid mesh transform');
      const slot=tier+':'+key+':'+shape;
      if(!bins.has(slot))bins.set(slot,{tier,key,shape,m:[]});
      dummy.position.set(x,y,z);
      dummy.rotation.set(pitch,yaw,roll);
      dummy.scale.set(w,h,d);dummy.updateMatrix();
      bins.get(slot).m.push(dummy.matrix.clone());stats.instances++;
    }
    const base=(...args)=>put('base',...args);
    const hi=(...args)=>{if(ultra)put('hi',...args);};
    // Architectural pattern is physically aligned to the same deterministic
    // buildings used by the gameplay/collision layer.
    for(let x=-7;x<=7;x++)for(let z=-7;z<=7;z++){
      if(!rules.buildingAt(x,z))continue;
      const r=random(x,z),w=.68+random(z,x)*.18,d=.68+random(x+5,z-4)*.17;
      const h=2.6+r*5.15,front=z+d/2+.042;
      stats.facades++;
      // Neoclassical pilasters, etched stone basement, actual window reveals.
      for(const edge of [-1,1]){
        base('limestone',x+edge*(w/2+.02),h/2,z+d*.13,.035,h,.045);
        base('stone',x+edge*w*.25,h-.07,front,.115,.08,.038);
        if(ultra)for(let k=0;k<3;k++){
          hi('stone',x+edge*(w/2+.035),.22+k*.08,front+.018,.075,.023,.075);
        }
      }
      base('stone',x,.105,front,.34,.14,.12);
      base('blackMetal',x,.38,front+.028,.28,.43,.014);
      base('anodized',x-.094,.38,front+.04,.013,.39,.018);
      base('anodized',x+.094,.38,front+.04,.013,.39,.018);
      hi('chrome',x+.055,.38,front+.058,.017,.034,.011);
      // Rooftop engineering silhouettes: water tank, ducts and modular PV fields.
      if(r>.28){
        base('roofTar',x+w*.18,h+.065,z-d*.12,.30,.10,.25);
        base('blackMetal',x+w*.18,h+.23,z-d*.12,.14,.24,.14,0,0,0,'cylinder');
        base('chrome',x+w*.18,h+.37,z-d*.12,.17,.035,.17,0,0,0,'cylinder');
        stats.rooftopAssets+=3;
      }
      if(ultra){
        for(let row=0;row<2;row++)for(let col=0;col<2;col++){
          hi('glass',x-w*.15+col*.12,h+.13,z+d*.02+row*.14,.105,.018,.115,0,-.28);
          hi('anodized',x-w*.15+col*.12,h+.095,z+d*.02+row*.14,.009,.075,.10);
          stats.rooftopAssets+=2;
        }
        // External rain pipes, balconies and rail infill.
        hi('copper',x+w/2+.05,h*.50,front-.12,.027,h-.22,.025);
        for(let floor=1;floor<Math.min(9,Math.floor(h/.65));floor+=2){
          const y=.46+floor*.65,railZ=front+.18;
          hi('stone',x,y-.19,front+.10,w*.72,.056,.25);
          hi('blackMetal',x,y+.18,railZ,w*.7,.025,.025);
          for(let j=-3;j<=3;j++)hi('anodized',x+j*w*.095,y-.005,railZ,.014,.32,.016);
          stats.balconyRails++;
        }
      }
      // Small but visible commercial ground-floor canopy, carved cornice.
      if(r>.53){
        base('ceramic',x,.82,front+.13,w*.76,.075,.23);
        hi('copper',x,.81,front+.25,w*.73,.027,.024);
      }
      base('limestone',x,h+.082,front,w+.10,.055,.065);
    }
    // Deliberate readable intersection hardware: road arrows, textured sidewalk
    // slabs, retro-reflective bollards, street drains and solar light posts.
    for(const road of [-15,-10,-5,5,10,15]){
      for(const side of [-1,1]){
        const edge=road+side*.78;
        for(let q=-18;q<=18;q+=3){
          if(Math.abs(edge)>19||Math.abs(q)>19)continue;
          base('limestone',edge,.005,q,.12,.023,.88);
          base('limestone',q,.005,edge,.88,.023,.12);
          if(ultra){
            hi('roofTar',edge+side*.08,.009,q,.075,.014,.25);
            hi('roofTar',q,.009,edge+side*.08,.25,.014,.075);
          }
          stats.streetFixtures+=2;
        }
        for(let q=-17;q<=17;q+=6){
          if(rules.blocked(edge,q,.05))continue;
          base('blackMetal',edge,.49,q,.052,.98,.052,0,0,0,'cylinder');
          base('amber',edge,1.01,q,.13,.16,.13);
          hi('anodized',edge,.9,q,.075,.13,.075);
          stats.streetFixtures++;
        }
      }
    }
    const signals=[[-14,-15],[-9,-10],[-4,-5],[5,5],[10,10],[15,-15]];
    for(const [x,z] of signals){
      if(rules.blocked(x,z,.05))continue;
      base('anodized',x,1.35,z,.075,2.7,.075,0,0,0,'cylinder');
      base('blackMetal',x,2.56,z+.12,.24,.62,.19);
      for(let k=0;k<3;k++)base(k===0?'amber':k===2?'cyan':'copper',x,2.76-k*.18,z+.24,.10,.10,.022);
      stats.streetFixtures+=5;
    }
    // Bushes and small street trees, each tree has more than one real volume.
    const shrubCount=lite?16:mobile?34:90;
    for(let i=0;i<shrubCount;i++){
      const x=-19+random(i,220)*38,z=-19+random(i,240)*38;
      if(rules.blocked(x,z,.28)||Math.hypot(x,z)<3)continue;
      const s=.55+random(i,250)*.45;
      base('timber',x,.18*s,z,.075*s,.36*s,.075*s,0,0,0,'cylinder');
      for(let k=0;k<(ultra?5:3);k++){
        const a=k*2.399;
        const dx=Math.cos(a)*.14*s,dz=Math.sin(a)*.14*s;
        base(k%2?'leaf1':'leaf0',x+dx,.43*s+random(i+k,2)*.13*s,z+dz,.26*s,.22*s,.27*s,0,0,0,'sphere');
      }
      if(ultra)for(let k=0;k<4;k++){
        const a=k*1.57;
        hi('leaf1',x+Math.cos(a)*.22*s,.45*s,z+Math.sin(a)*.22*s,.16*s,.13*s,.17*s,0,0,0,'sphere');
      }
      stats.foliageAssets++;
    }
    // Small rain pool geometry reuses one reflective instanced material.
    for(let i=0;i<(lite?5:mobile?13:34);i++){
      const x=-18+random(i,320)*36,z=-18+random(i,340)*36;
      if(rules.blocked(x,z,.16)||Math.hypot(x,z)<2.5)continue;
      base('wet',x,-.007,z,.12+random(i,350)*.24,.002,.12+random(i,360)*.40);
      stats.wetSurfaces++;
    }
    let puddleBatch=null;
    for(const bin of bins.values()){
      const mesh=new THREE.InstancedMesh(pick[bin.shape],palette[bin.key],bin.m.length);
      mesh.name='ZION31 / '+bin.key+' / '+bin.tier;
      for(let i=0;i<bin.m.length;i++)mesh.setMatrixAt(i,bin.m[i]);
      mesh.instanceMatrix.needsUpdate=true;
      mesh.castShadow=false;mesh.receiveShadow=false;mesh.frustumCulled=false;
      (bin.tier==='hi'?high:low).add(mesh);
      ownedMeshes.push(mesh);stats.drawCallBatches++;
      if(bin.key==='wet')puddleBatch=mesh;
    }
    function detailCar(parent){
      if(!parent?.add)return;
      const group=new THREE.Group();
      group.name='ZION31 / City Runner handcrafted body';
      const highCar=new THREE.Group(); highCar.name='ZION31 / optional rims and cockpit';
      group.add(highCar);
      // One instanced draw call per body material / geometry instead of
      // a separate draw call for every wheel spoke on every moving car.
      const carBins=new Map(),carDummy=new THREE.Object3D();
      const add=(into,m,x,y,z,w,h,d,shape='cube')=>{
        const key=(into===highCar?'hi':'base')+':'+ownedMats.indexOf(m)+':'+shape;
        if(!carBins.has(key))carBins.set(key,{into,m,shape,matrices:[]});
        carDummy.position.set(x,y,z);carDummy.scale.set(w,h,d);
        carDummy.rotation.set(0,0,shape==='cylinder'?Math.PI/2:0);
        carDummy.updateMatrix();
        carBins.get(key).matrices.push(carDummy.matrix.clone());
        stats.vehicleParts++;
      };
      // Lower bumper, light guides, windscreen molding and sporty diffusers.
      add(group,blackMetal,0,.17,-.80,.72,.09,.095);
      add(group,anodized,0,.20,.81,.75,.09,.035);
      add(group,glass,0,.62,-.35,.59,.21,.019);
      for(const side of [-1,1]){
        add(group,chrome,side*.33,.31,-.83,.18,.036,.020);
        add(group,cyan,side*.31,.41,-.828,.14,.044,.016);
        add(group,amber,side*.29,.39,.828,.15,.04,.014);
        add(group,blackMetal,side*.413,.31,.02,.017,.20,.74);
        for(const z of [-.50,.53]){
          add(highCar,rubber,side*.47,.20,z,.018,.14,.14,'cylinder');
          add(highCar,chrome,side*.491,.20,z,.018,.095,.095,'cylinder');
          for(let k=0;k<6;k++){
            const a=k*Math.PI/3;
            add(highCar,anodized,side*.508,.20+Math.sin(a)*.062,z+Math.cos(a)*.062,
              .012,.020,.075);
          }
        }
      }
      for(let k=-3;k<=3;k++)add(highCar,blackMetal,k*.052,.235,-.857,.022,.068,.012);
      add(highCar,copper,0,.61,.54,.55,.016,.018);
      add(highCar,anodized,0,.82,.13,.64,.019,.13);
      add(highCar,glass,0,.84,.16,.34,.014,.36);
      for(const b of carBins.values()){
        const mesh=new THREE.InstancedMesh(pick[b.shape],b.m,b.matrices.length);
        b.matrices.forEach((matrix,i)=>mesh.setMatrixAt(i,matrix));
        mesh.instanceMatrix.needsUpdate=true;
        mesh.frustumCulled=false;mesh.castShadow=false;
        b.into.add(mesh);stats.vehicleBatches++;
      }
      parent.add(group);
      highCar.visible=high.visible;
      optionalCars.push(highCar);
    }
    const optionalCars=[];
    function detailAvatar(avatar){
      if(!avatar?.add)return;
      const group=new THREE.Group();
      group.name='ZION31 / character outfit detail';
      const make=(x,y,z,w,h,d,m)=>{
        const mesh=new THREE.Mesh(cube,m);
        mesh.position.set(x,y,z);mesh.scale.set(w,h,d);group.add(mesh);stats.avatarParts++;
      };
      make(0,1.23,-.228,.28,.32,.06,blackMetal);
      make(0,1.36,-.267,.22,.06,.028,cyan);
      for(const side of [-1,1]){
        make(side*.19,1.18,-.23,.025,.49,.025,anodized);
        make(side*.15,.75,.06,.14,.09,.16,rubber);
        if(ultra)make(side*.125,1.1,.27,.09,.15,.025,copper);
      }
      make(0,1.58,-.12,.19,.025,.04,chrome);
      avatar.add(group);
    }
    // Texture the actual old road and existing facades; preserve v30 window albedo.
    let asphalt=null;
    if(!lite){
      asphalt=scene.children.find(m=>m.isMesh&&m.geometry?.type==='PlaneGeometry'
        &&m.geometry.parameters?.width===41&&m.geometry.parameters?.height===41);
      if(asphalt?.material&&asphaltMap){
        asphalt.material.map=asphaltMap;
        asphalt.material.color.setHex(0x9ca9b3);
        asphalt.material.roughness=.96;
        asphalt.material.metalness=.04;
        if(asphaltNormal){asphalt.material.normalMap=asphaltNormal;asphalt.material.roughnessMap=asphaltRough;}
        asphalt.material.needsUpdate=true;
      }
      if(masonryMap){
        scene.traverse?.(o=>{
          if(!o.isInstancedMesh || !o.material || !o.name?.startsWith('ZION30 /'))return;
          if(o.name.includes('/ stone /')||o.name.includes('/ sandstone /')){
            o.material.map=masonryMap;
            if(masonryNormal){o.material.normalMap=masonryNormal;o.material.roughnessMap=masonryRough;}
            o.material.needsUpdate=true;
          }
        });
      }
    }
    function syncEnvironment({raining=false,dayMode=0}={}){
      currentRaining=Boolean(raining);
      currentNight=dayMode===1;
      if(puddleBatch)puddleBatch.visible=currentRaining;
      stats.wetVisible=Boolean(puddleBatch&&currentRaining);
      if(asphalt?.material){
        asphalt.material.roughness=currentRaining ? .23 : .96;
        asphalt.material.metalness=currentRaining ? .30 : .04;
      }
      amber.emissiveIntensity=currentNight ? 1.4 : .4;
      cyan.emissiveIntensity=currentNight ? 1.1 : .5;
      if(glass.emissive)glass.emissiveIntensity=currentNight ? .19 : .07;
    }
    function setQuality(q){
      high.visible=ultra&&q!=='eco'&&q!=='adaptive';
      stats.highDetailVisible=high.visible;
      for(const g of optionalCars)g.visible=high.visible;
      return high.visible?'CINEMATIC':'BALANCED';
    }
    setQuality(lite?'adaptive':'high');
    syncEnvironment();
    function dispose(){
      scene.remove(low,high);
      for(const texture of ownedTextures)texture.dispose();
      for(const mat of ownedMats)mat.dispose();
      for(const geometry of geometries)geometry.dispose();
    }
    return Object.freeze({get stats(){return Object.freeze({...stats});},
      setQuality,detailCar,detailAvatar,syncEnvironment,dispose});
  }
  host.ZION030_CINEMATIC_KIT=Object.freeze({VERSION,install});
})(window);
