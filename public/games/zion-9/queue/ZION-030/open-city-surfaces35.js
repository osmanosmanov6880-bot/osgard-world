/* ZION-030 v35: physically shaded streets, civic micro-detail, real rain response.
 * Runs inside the live Three.js game. No new colliders or save-data changes.
 * Deterministic albedo/height-derived normal/roughness maps; capped instances.
 */
(function(host){
  'use strict';
  const VERSION='35.0',TAU=Math.PI*2;
  const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
  const hash=(x,y,s)=>{
    let z=(Math.imul(x|0,374761393)^Math.imul(y|0,668265263)^Math.imul(s|0,2246822519))>>>0;
    z=Math.imul(z^(z>>>13),1274126177)>>>0;
    return ((z^(z>>>16))&65535)/65535;
  };
  function install({THREE,scene,rules,mobile=false,softwareGL=false,reducedMotion=false}){
    if(!THREE?.Group||!THREE?.InstancedMesh||!scene||!rules?.blocked)
      throw Error('ZION35 surface kit requires the playable Three.js city');
    const lite=Boolean(softwareGL||reducedMotion),ultra=!mobile&&!lite;
    const root=new THREE.Group(),base=new THREE.Group(),fine=new THREE.Group(),wet=new THREE.Group();
    root.name='ZION35 / detailed street surfaces';
    base.name='ZION35 / instanced civil engineering';
    fine.name='ZION35 / close-up details';
    wet.name='ZION35 / weather-responsive puddles';
    root.add(base,fine,wet);scene.add(root);
    const ownedMaterials=[],ownedGeometries=[],ownedTextures=[],patched=[];
    const stats={version:VERSION,tier:lite?'LITE':mobile?'MOBILE':'ULTRA',
      mappedSurfaces:0,textureMaps:0,textureBytes:0,instances:0,batches:0,
      pavementBlocks:0,roadCracks:0,manholeCovers:0,drainBolts:0,puddles:0,
      activeRipples:0,animationFrames:0,rain:false,night:false,fineVisible:false};
    const geo=g=>(ownedGeometries.push(g),g);
    const box=geo(new THREE.BoxGeometry(1,1,1));
    const cylinder=geo(new THREE.CylinderGeometry(.5,.5,1,16));
    const circle=geo(new THREE.CircleGeometry(1,24));
    const ring=geo(new THREE.TorusGeometry(1,.012,4,28));
    const material=(color,roughness=.82,metalness=.1,transparent=false,opacity=1)=>{
      const m=new (lite?THREE.MeshLambertMaterial:THREE.MeshStandardMaterial)(
        {color,roughness,metalness,transparent,opacity,depthWrite:!transparent});
      ownedMaterials.push(m);return m;
    };
    const mats={
      curb:material(0x8196a0,.83),tar:material(0x1e2c32,.93),
      metal:material(0x576c74,.46,.64),bolt:material(0x879ba4,.40,.70),
      water:material(0x7baebd,.14,.47,true,.27),
      ripple:material(0xc7f5ff,.19,.28,true,.44)
    };
    // Height drives BOTH bump shading and roughness. The resulting channels
    // are correlated rather than unrelated random-colour textures.
    function surfaceAtlas(family){
      if(lite||!THREE.CanvasTexture||typeof document==='undefined')return null;
      const size=ultra?384:192,brick=family===1;
      const heights=new Float32Array(size*size);
      for(let y=0;y<size;y++)for(let x=0;x<size;x++){
        const row=Math.floor(y/(size/(brick?12:32)));
        const u=(x/(size/(brick?9:32))+(brick&&row%2?.5:0))%1;
        const v=(y/(size/(brick?12:32)))%1;
        const seam=Math.min(u,1-u,v,1-v)<(brick?.035:.014)?-.27:0;
        heights[y*size+x]=clamp(.65+seam+(hash(x>>3,y>>3,family+11)-.5)*.15+
          (hash(x,y,family+22)-.5)*.11,.04,.96);
      }
      const atlas={};
      for(const name of ['map','normalMap','roughnessMap']){
        const canvas=document.createElement('canvas');canvas.width=canvas.height=size;
        const ctx=canvas.getContext('2d');
        if(!ctx?.createImageData||!ctx.putImageData)return null;
        const image=ctx.createImageData(size,size),data=image.data;
        for(let y=0;y<size;y++)for(let x=0;x<size;x++){
          const j=y*size+x,k=j*4,h=heights[j];
          if(name==='normalMap'){
            const lx=heights[y*size+(x+size-1)%size],rx=heights[y*size+(x+1)%size];
            const uy=heights[((y+size-1)%size)*size+x],dy=heights[((y+1)%size)*size+x];
            const nx=(lx-rx)*2.3,ny=(uy-dy)*2.3,len=Math.hypot(nx,ny,1);
            data[k]=clamp(127.5+127.5*nx/len,0,255);
            data[k+1]=clamp(127.5+127.5*ny/len,0,255);
            data[k+2]=clamp(127.5+127.5/len,0,255);
          }else if(name==='roughnessMap'){
            data[k]=data[k+1]=data[k+2]=clamp((brick?.81:.91)+(h-.65)*.11,.4,.99)*255;
          }else{
            const shade=clamp((brick?165:105)+(h-.65)*70,32,224);
            data[k]=shade+(brick?10:0);data[k+1]=shade+(brick?6:3);
            data[k+2]=shade+(brick?0:9);
          }
          data[k+3]=255;
        }
        ctx.putImageData(image,0,0);
        const t=new THREE.CanvasTexture(canvas);
        t.wrapS=t.wrapT=THREE.RepeatWrapping;
        t.repeat.set(brick?4:16,brick?4:16);
        t.anisotropy=ultra?8:2;
        t.colorSpace=name==='map'?THREE.SRGBColorSpace:THREE.NoColorSpace;
        atlas[name]=t;ownedTextures.push(t);stats.textureMaps++;
        stats.textureBytes+=size*size*4;
      }
      return atlas;
    }
    const atlases=lite?[]:[surfaceAtlas(0),surfaceAtlas(1)];
    ['ZION35 asphalt surface','ZION35 plaza surface'].forEach((name,index)=>{
      const object=scene.children.find(c=>c.name===name);
      const a=atlases[index];
      if(!object?.material||!a?.map||!a.normalMap||!a.roughnessMap)return;
      const m=object.material;
      patched.push({material:m,atlas:a,index,original:{map:m.map,normalMap:m.normalMap,
        roughnessMap:m.roughnessMap,normalScale:m.normalScale,
        roughness:m.roughness,color:m.color.clone()}});
      m.map=a.map;m.normalMap=a.normalMap;m.roughnessMap=a.roughnessMap;
      m.normalScale=new THREE.Vector2(index===0?.33:.52,index===0?.33:.52);
      m.needsUpdate=true;stats.mappedSurfaces++;
    });
    // Geometry costs are bounded and InstancedMesh keeps draw calls stable.
    const bins={base:new Map(),fine:new Map(),wet:new Map()},dummy=new THREE.Object3D();
    function add(bucket,key,shape,x,y,z,sx,sy,sz,rx=0,ry=0,rz=0){
      if(![x,y,z,sx,sy,sz,rx,ry,rz].every(Number.isFinite)||
        Math.min(sx,sy,sz)<=0)throw Error('ZION35: invalid geometry transform');
      const map=bins[bucket],id=key+'/'+shape;
      if(!map.has(id))map.set(id,{key,shape,transforms:[]});
      dummy.position.set(x,y,z);dummy.rotation.set(rx,ry,rz);
      dummy.scale.set(sx,sy,sz);dummy.updateMatrix();
      map.get(id).transforms.push(dummy.matrix.clone());
      stats.instances++;
    }
    const clear=(x,z)=>!rules.blocked(x,z,.18);
    for(const edge of [-7.5,7.5,-12.5,12.5]){
      for(let n=-18;n<=18;n+=.9){
        if(clear(edge,n)){
          add('base','curb','box',edge,.013,n,.13,.055,.78);
          stats.pavementBlocks++;
        }
        if(clear(n,edge)){
          add('base','curb','box',n,.013,edge,.78,.055,.13);
          stats.pavementBlocks++;
        }
      }
    }
    for(let i=0;i<(ultra?150:mobile?65:24);i++){
      const x=-18+hash(i,70,1)*36,z=-18+hash(90,i,7)*36;
      if(!clear(x,z)||Math.hypot(x,z)<2.5)continue;
      add('fine','tar','box',x,-.009,z,.12+hash(i,83,3)*.39,.006,.009,
        0,hash(i,14,5)*TAU);
      stats.roadCracks++;
    }
    const covers=[];
    for(let i=0;i<29;i++){
      const x=-18+hash(i,41,19)*36,z=-18+hash(81,i,31)*36;
      if(!clear(x,z)||Math.hypot(x,z)<3.0||
         covers.some(c=>Math.hypot(x-c.x,z-c.z)<1.5))continue;
      covers.push({x,z});
      add('base','metal','cylinder',x,-.008,z,.49,.018,.49);
      stats.manholeCovers++;
      if(ultra)for(let k=0;k<8;k++){
        const angle=k*TAU/8;
        add('fine','bolt','cylinder',x+Math.cos(angle)*.18,.003,
          z+Math.sin(angle)*.18,.025,.008,.025);
        stats.drainBolts++;
      }
    }
    const pools=[];
    for(let i=0;i<(ultra?27:mobile?12:8);i++){
      const x=-18+hash(i,101,15)*36,z=-18+hash(203,i,27)*36;
      if(!clear(x,z)||Math.hypot(x,z)<2.3)continue;
      const radius=.17+hash(i,17,45)*.33;
      pools.push({x,z,radius,phase:hash(i,88,91)});
      add('wet','water','circle',x,-.004,z,radius,radius*1.7,1,-Math.PI/2);
    }
    stats.puddles=pools.length;
    const shapes={box,cylinder,circle};
    for(const [bucket,parent] of [['base',base],['fine',fine],['wet',wet]]){
      for(const b of bins[bucket].values()){
        const mesh=new THREE.InstancedMesh(shapes[b.shape],mats[b.key],b.transforms.length);
        b.transforms.forEach((m,i)=>mesh.setMatrixAt(i,m));
        mesh.instanceMatrix.needsUpdate=true;mesh.frustumCulled=false;
        mesh.castShadow=false;mesh.receiveShadow=false;
        mesh.name='ZION35 / '+b.key+'/'+b.shape;parent.add(mesh);
        stats.batches++;
      }
    }
    const rippleCount=ultra?Math.min(14,pools.length):0;
    const ripples=new THREE.InstancedMesh(ring,mats.ripple,rippleCount);
    ripples.frustumCulled=false;wet.add(ripples);
    let elapsed=0,lastUpdate=0,quality='high',raining=false,night=false,disposed=false;
    function refresh(){
      const mapsEnabled=!lite&&quality!=='eco'&&quality!=='adaptive';
      for(const p of patched){
        const m=p.material,a=p.atlas;
        m.map=mapsEnabled?a.map:p.original.map;
        m.normalMap=mapsEnabled?a.normalMap:p.original.normalMap;
        m.roughnessMap=mapsEnabled?a.roughnessMap:p.original.roughnessMap;
        m.roughness=raining?(p.index===0?.29:.39):(p.index===0?.87:.84);
        // Albedo base is neutral when the atlas is active; fallback uses
        // the original authored material colours, avoiding double-darkening.
        if(mapsEnabled)m.color.setHex(raining?0xa1b0bc:0xe1e7ea);
        else m.color.copy(p.original.color);
        m.needsUpdate=true;
      }
      mats.water.opacity=raining?(night?.39:.28):0;
      mats.ripple.opacity=night?.57:.39;
    }
    function setQuality(mode){
      quality=mode;
      stats.fineVisible=ultra&&mode!=='eco'&&mode!=='adaptive';
      fine.visible=stats.fineVisible;
      ripples.visible=raining&&stats.fineVisible&&!reducedMotion;
      stats.activeRipples=ripples.visible?rippleCount:0;
      refresh();return stats.fineVisible;
    }
    function syncEnvironment({raining:rain=false,dayMode=0}={}){
      raining=!!rain;night=dayMode===1;
      stats.rain=raining;stats.night=night;wet.visible=raining;
      ripples.visible=raining&&stats.fineVisible&&!reducedMotion;
      stats.activeRipples=ripples.visible?rippleCount:0;
      refresh();
    }
    function update(dt){
      if(disposed||!raining||!ripples.visible||reducedMotion||
        !Number.isFinite(dt)||dt<=0)return;
      elapsed+=Math.min(dt,.05);
      if(elapsed-lastUpdate<.05)return;
      lastUpdate=elapsed;
      for(let i=0;i<rippleCount;i++){
        const p=pools[i],phase=(elapsed*.58+p.phase)%1;
        dummy.position.set(p.x,.007,p.z);
        dummy.rotation.set(Math.PI/2,0,0);
        dummy.scale.set(.03+phase*p.radius,.03+phase*p.radius,1);
        dummy.updateMatrix();ripples.setMatrixAt(i,dummy.matrix);
      }
      ripples.instanceMatrix.needsUpdate=true;stats.animationFrames++;
    }
    function dispose(){
      if(disposed)return;disposed=true;scene.remove(root);
      for(const p of patched){
        const m=p.material,o=p.original;
        m.map=o.map;m.normalMap=o.normalMap;m.roughnessMap=o.roughnessMap;
        m.normalScale=o.normalScale;m.roughness=o.roughness;
        m.color.copy(o.color);m.needsUpdate=true;
      }
      ownedTextures.forEach(t=>t.dispose());
      ownedMaterials.forEach(m=>m.dispose());
      ownedGeometries.forEach(g=>g.dispose());
    }
    setQuality(lite?'adaptive':'high');syncEnvironment();
    return Object.freeze({get stats(){return Object.freeze({...stats});},
      update,setQuality,syncEnvironment,dispose});
  }
  host.ZION030_SURFACES35=Object.freeze({VERSION,install});
})(window);
