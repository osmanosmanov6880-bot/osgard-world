/* ZION-030 v37 / physically grounded city materials and reflections.
 * Real photo-based CC0 textures are progressively streamed on accelerated desktop
 * browsers. A deterministic 3-channel fallback makes offline gameplay complete.
 * No gameplay collision, mission, save, navigation or UI state is changed.
 * Source: https://polyhaven.com/license (CC0). Individual texture URIs below.
 */
(function(host){
  'use strict';
  const VERSION='37.0', TAU=Math.PI*2;
  const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
  const families=['asphalt','limestone','plaster'];
  const photoBase='https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/';
  const photographs={
    asphalt:{asset:'asphalt_03',color:'asphalt_03_diff_1k.jpg',normal:'asphalt_03_nor_gl_1k.jpg'},
    limestone:{asset:'sandstone_blocks_04',color:'sandstone_blocks_04_diff_1k.jpg',normal:'sandstone_blocks_04_nor_gl_1k.jpg'},
    plaster:{asset:'plastered_wall_05',color:'plastered_wall_05_diff_1k.jpg',normal:'plastered_wall_05_nor_gl_1k.jpg'}
  };
  function install({THREE,scene,renderer,rules,car=null,avatar=null,keyLight=null,
    hemi=null,blueFill=null,mobile=false,softwareGL=false,reducedMotion=false}){
    if(!THREE?.Mesh||!THREE?.InstancedMesh||!THREE?.CanvasTexture||
      !scene||!renderer||!rules?.buildingAt||!rules?.rand)
      throw Error('ZION37 needs the real playable Three.js city');
    const lite=Boolean(softwareGL||reducedMotion);
    const ultra=!lite&&!mobile;
    const mapped=[],ownedTextures=[],ownedMaterials=[],ownedGeometry=[],photoLoaded=[],vehicleRestores=[];
    const originalEnv=scene.environment,originalExposure=renderer.toneMappingExposure;
    const oldLight={
      key:keyLight?{intensity:keyLight.intensity,color:keyLight.color.clone()}:null,
      hemi:hemi?hemi.intensity:null,
      fill:blueFill?blueFill.intensity:null,
      shadow:keyLight?.shadow?.mapSize?keyLight.shadow.mapSize.x:null
    };
    const root=new THREE.Group();root.name='ZION37 / PBR photorealism pipeline';
    scene.add(root);
    const stats={version:VERSION,tier:lite?'LITE':mobile?'MOBILE':'ULTRA',
      originalPhotoSources:3,photoTexturesLoaded:0,photoTextureErrors:0,
      materialFamilies:0,proceduralTextureMaps:0,estimatedTextureBytes:0,
      livePatchedMaterials:0,reflectionProbe:'none',reflectionReady:false,
      heroGlassPanels:0,contactShadows:0,streetGrime:0,drawBatches:0,
      vehicleClearcoatMeshes:0,vehicleGlassMeshes:0,
      shadowResolution:0,rain:false,night:false,environment:'dusk',
      quality:'high',highVisible:false,lightStyle:'neutral-filmic',
      animationTicks:0,sourceLicense:'Poly Haven CC0',
      usesExternalPhotoUrls:ultra};
    let quality=lite?'adaptive':'high',raining=false,dayMode=0,disposed=false,
      pmrem=null,reflectionTarget=null,skyTexture=null,shadowTexture=null,
      contact=null,carContact=null,avatarContact=null,grain=null,grainData=null,
      grainLast=0,clock=0;
    const mat=(type,params)=>{
      const C=type==='physical'&&THREE.MeshPhysicalMaterial?
        THREE.MeshPhysicalMaterial:THREE.MeshStandardMaterial;
      const result=new C(params);ownedMaterials.push(result);return result;
    };
    const geometry=g=>(ownedGeometry.push(g),g);
    const plane=geometry(new THREE.PlaneGeometry(1,1));
    const cube=geometry(new THREE.BoxGeometry(1,1,1));
    const beveled=geometry(new THREE.CylinderGeometry(.50,.50,1,12));
    const rand=rules.rand;
    const hash=(x,y,s)=>{
      let n=(Math.imul(x|0,374761393)^Math.imul(y|0,668265263)^
        Math.imul(s|0,2246822519))>>>0;
      n=Math.imul(n^(n>>>13),1274126177)>>>0;
      return ((n^(n>>>16))&65535)/65535;
    };
    const sample=(x,y,size,period,salt)=>{
      const xx=((x%size)+size)%size,yy=((y%size)+size)%size;
      const u=xx*period/size,v=yy*period/size;
      const ix=Math.floor(u),iy=Math.floor(v),a=u-ix,b=v-iy;
      const sx=a*a*(3-2*a),sy=b*b*(3-2*b);
      const h=(i,j)=>hash(i%period,j%period,salt);
      return (h(ix,iy)*(1-sx)+h((ix+1)%period,iy)*sx)*(1-sy)+
        (h(ix,(iy+1)%period)*(1-sx)+h((ix+1)%period,(iy+1)%period)*sx)*sy;
    };
    function author(family){
      if(lite||typeof document==='undefined')return null;
      const size=ultra?768:256;
      const height=new Float32Array(size*size),value=new Float32Array(size*size);
      const familyIndex=families.indexOf(family);
      for(let y=0;y<size;y++)for(let x=0;x<size;x++){
        const coarse=sample(x,y,size,8,5+familyIndex*11);
        const mid=sample(x,y,size,42,23+familyIndex*7);
        const fine=sample(x,y,size,128,37+familyIndex*7);
        const pebble=(hash(x,y,44+familyIndex*31)-.5)*.045;
        let seam=0;
        if(family==='limestone'){
          const r=Math.floor(y/(size/12));
          const u=(x/(size/8)+(r%2)*.5)%1,v=(y/(size/12))%1;
          seam=Math.min(u,1-u,v,1-v)<.035?-.27:0;
        }else if(family==='plaster'){
          seam=-Math.max(0,.18-Math.abs(mid-.33))* .38;
        }else{
          seam=hash(x>>4,y>>4,83)>.992?-.10:0;
        }
        const h=clamp(.59+(coarse-.5)*.22+(mid-.5)*.21+
          (fine-.5)*.11+pebble+seam,.05,.98);
        height[y*size+x]=h;value[y*size+x]=coarse*.50+mid*.33+fine*.17;
      }
      const result={};
      for(const channel of ['map','normalMap','roughnessMap']){
        const canvas=document.createElement('canvas');
        canvas.width=canvas.height=size;
        const ctx=canvas.getContext('2d');
        if(!ctx?.createImageData||!ctx.putImageData)continue;
        const image=ctx.createImageData(size,size),d=image.data;
        for(let y=0;y<size;y++)for(let x=0;x<size;x++){
          const p=y*size+x,k=p*4,h=height[p],v=value[p];
          if(channel==='normalMap'){
            const l=height[y*size+(x+size-1)%size],r=height[y*size+(x+1)%size];
            const t=height[((y+size-1)%size)*size+x];
            const b=height[((y+1)%size)*size+x];
            const slope=family==='asphalt'?1.6:2.5;
            const nx=(l-r)*slope,ny=(t-b)*slope,len=Math.hypot(nx,ny,1);
            d[k]=clamp(127.5+127.5*nx/len,0,255);
            d[k+1]=clamp(127.5+127.5*ny/len,0,255);
            d[k+2]=clamp(127.5+127.5/len,0,255);
          }else if(channel==='roughnessMap'){
            const base=family==='asphalt'?.92:family==='limestone'?.84:.91;
            const rough=clamp(base+(h-.6)*.21,.25,.98)*255;
            // Three.js samples the GREEN channel for roughness.
            d[k]=d[k+1]=d[k+2]=rough;
          }else{
            // Mineral variation is correlated with height and roughness;
            // neutral albedo preserves the authored city colour palette.
            const brightness=clamp((family==='asphalt'?180:211)+
              (v-.5)*60+(h-.6)*36,88,247);
            d[k]=clamp(brightness+(family==='limestone'?8:0),0,255);
            d[k+1]=clamp(brightness+(family==='plaster'?5:0),0,255);
            d[k+2]=clamp(brightness+(family==='asphalt'?9:-7),0,255);
          }
          d[k+3]=255;
        }
        ctx.putImageData(image,0,0);
        const t=new THREE.CanvasTexture(canvas);
        t.wrapS=t.wrapT=THREE.RepeatWrapping;
        if(t.repeat?.set)t.repeat.set(family==='asphalt'?18:family==='limestone'?3:4,
          family==='asphalt'?18:family==='limestone'?3:4);
        t.anisotropy=Math.min(ultra?8:2,renderer.capabilities?.getMaxAnisotropy?.()||8);
        t.colorSpace=channel==='map'?THREE.SRGBColorSpace:THREE.NoColorSpace;
        t.generateMipmaps=true;
        ownedTextures.push(t);result[channel]=t;
        stats.proceduralTextureMaps++;stats.estimatedTextureBytes+=size*size*4;
      }
      if(result.map&&result.normalMap&&result.roughnessMap)stats.materialFamilies++;
      return result;
    }
    const library=lite?{}:{
      asphalt:author('asphalt'),
      limestone:author('limestone'),
      plaster:author('plaster')
    };
    const materialByFamily=new Map();
    function patch(material,family){
      if(!material||!library[family]||mapped.some(x=>x.material===material))return;
      const original={map:material.map,normalMap:material.normalMap,
        roughnessMap:material.roughnessMap,normalScale:material.normalScale,
        roughness:material.roughness,metalness:material.metalness,
        color:material.color?.clone?.(),
        envMapIntensity:material.envMapIntensity};
      const item={material,family,original};mapped.push(item);
      if(!materialByFamily.has(family))materialByFamily.set(family,[]);
      materialByFamily.get(family).push(item);
      stats.livePatchedMaterials++;
    }
    // Actual city geometry, not a detached visual-only mock.
    for(const [name,family] of [
      ['ZION35 asphalt surface','asphalt'],
      ['ZION35 plaza surface','limestone']
    ]){
      const obj=scene.children.find(x=>x.name===name);
      patch(obj?.material,family);
    }
    const street=scene.children.find(x=>x.name==='ZION33 street-level stone and storefronts');
    for(const mesh of street?.children||[]){
      const key=String(mesh.name||'').split(' / ')[1];
      const family=key==='limestone'||key==='white'?'limestone':
        key==='plaster'||key==='rose'?'plaster':null;
      if(family)patch(mesh.material,family);
    }
    function assignMaterials(){
      for(const record of mapped){
        const m=record.material,src=library[record.family],old=record.original;
        const high=!lite&&quality!=='eco'&&quality!=='adaptive';
        const photo=src?.photo||{};
        const next=(key)=>high?(photo[key]||src[key]):old[key];
        const color=next('map'),normal=next('normalMap'),rough=next('roughnessMap');
        if(m.map!==color||m.normalMap!==normal||m.roughnessMap!==rough){
          m.map=color;m.normalMap=normal;m.roughnessMap=rough;
          m.needsUpdate=true;
        }
        m.normalScale=high?new THREE.Vector2(
          record.family==='asphalt'?.30:.42,
          record.family==='asphalt'?.30:.42):old.normalScale;
        m.roughness=high?(raining?(record.family==='asphalt'?.47:.65):.94):old.roughness;
        m.envMapIntensity=high?record.family==='asphalt'?.74:1.05:old.envMapIntensity;
        if(m.color&&old.color){
          if(high&&record.family==='asphalt')m.color.setHex(0x667077);
          else if(high&&record.family==='limestone'&&record.material===scene.children.find(x=>x.name==='ZION35 plaza surface')?.material)m.color.setHex(0xc7c0ac);
          else m.color.copy(old.color);
        }
      }
    }
    // Stream genuine photo-based CC0 material channels when available. These
    // URLs do not use the live metadata API; failed CORS or offline requests
    // leave the full deterministic PBR fallback in place.
    if(ultra&&THREE.TextureLoader){
      const loader=new THREE.TextureLoader();
      if(typeof loader.setCrossOrigin==='function')loader.setCrossOrigin('anonymous');
      for(const family of families)for(const [channel,file] of [
        ['map',photographs[family].color],
        ['normalMap',photographs[family].normal]
      ]){
        const url=photoBase+photographs[family].asset+'/'+file;
        try{
          const t=loader.load(url,()=>{
            if(disposed){t.dispose?.();return;}
            t.wrapS=t.wrapT=THREE.RepeatWrapping;
            if(t.repeat?.set)t.repeat.set(
              family==='asphalt'?18:family==='limestone'?3:4,
              family==='asphalt'?18:family==='limestone'?3:4);
            t.colorSpace=channel==='map'?THREE.SRGBColorSpace:THREE.NoColorSpace;
            t.anisotropy=Math.min(8,renderer.capabilities?.getMaxAnisotropy?.()||8);
            t.needsUpdate=true;
            library[family].photo??={};library[family].photo[channel]=t;
            photoLoaded.push(t);stats.photoTexturesLoaded++;
            assignMaterials();
          },undefined,()=>{if(!disposed)stats.photoTextureErrors++;});
        }catch(_){stats.photoTextureErrors++;}
      }
    }
    // One soft radial contact-shadow atlas. Multiple buildings share a single
    // InstancedMesh draw; these decals never act as collidable or interactive.
    const buildings=[];
    for(let x=-6;x<=6;x++)for(let z=-6;z<=6;z++)
      if(rules.buildingAt(x,z))buildings.push({x,z});
    if(!lite&&typeof document!=='undefined'){
      const c=document.createElement('canvas');c.width=c.height=128;
      const g=c.getContext('2d');
      if(g?.createRadialGradient){
        const grad=g.createRadialGradient(64,64,3,64,64,61);
        grad.addColorStop(0,'rgba(0,0,0,.55)');
        grad.addColorStop(.43,'rgba(0,0,0,.31)');
        grad.addColorStop(1,'rgba(0,0,0,0)');
        g.fillStyle=grad;g.fillRect(0,0,128,128);
        shadowTexture=new THREE.CanvasTexture(c);ownedTextures.push(shadowTexture);
        const shadowMaterial=new THREE.MeshBasicMaterial({
          map:shadowTexture,transparent:true,opacity:.42,
          depthWrite:false,polygonOffset:true,polygonOffsetFactor:-1,
          toneMapped:false,side:THREE.DoubleSide
        });
        ownedMaterials.push(shadowMaterial);
        const dummy=new THREE.Object3D();
        contact=new THREE.InstancedMesh(plane,shadowMaterial,buildings.length);
        contact.name='ZION37 / soft building contact shadow instances';
        buildings.forEach(({x,z},i)=>{
          dummy.position.set(x,-.019,z);
          dummy.rotation.set(-Math.PI/2,0,0);
          dummy.scale.set(1.1,.9,1);
          dummy.updateMatrix();contact.setMatrixAt(i,dummy.matrix);
        });
        contact.instanceMatrix.needsUpdate=true;contact.frustumCulled=false;
        root.add(contact);stats.contactShadows=buildings.length;stats.drawBatches++;
        function movingShadow(sizeX,sizeZ){
          const mesh=new THREE.Mesh(plane,shadowMaterial);
          mesh.rotation.x=-Math.PI/2;mesh.scale.set(sizeX,sizeZ,1);
          mesh.position.y=-.014;mesh.renderOrder=1;
          root.add(mesh);return mesh;
        }
        if(car?.mesh)carContact=movingShadow(.90,1.62);
        if(avatar)avatarContact=movingShadow(.38,.44);
      }
    }
    // Existing sculpted playable car: reuse its real meshes, changing only
    // the hero paint/glass BRDF (clearcoat) rather than adding fake proxy bodies.
    if(!lite&&car?.mesh&&THREE.MeshPhysicalMaterial){
      const allMeshes=[];
      const walk=node=>{
        if(node?.isMesh&&node.material)allMeshes.push(node);
        for(const child of node?.children||[])walk(child);
      };
      walk(car.mesh);
      const primary=allMeshes[0]?.material||null;
      const windshield=allMeshes[1]?.material||null;
      if(primary?.color){
        const paint=mat('physical',{
          color:primary.color.clone(),roughness:.22,metalness:.69,
          clearcoat:1.0,clearcoatRoughness:.11,
          envMapIntensity:1.4
        });
        for(const mesh of allMeshes)if(mesh.material===primary){
          vehicleRestores.push({mesh,material:primary});
          mesh.material=paint;stats.vehicleClearcoatMeshes++;
        }
      }
      if(windshield?.color&&windshield!==primary){
        const glazing=mat('physical',{
          color:windshield.color.clone(),roughness:.09,metalness:.08,
          transparent:true,opacity:.90,
          clearcoat:.95,clearcoatRoughness:.05,
          envMapIntensity:1.65
        });
        for(const mesh of allMeshes)if(mesh.material===windshield){
          vehicleRestores.push({mesh,material:windshield});
          mesh.material=glazing;stats.vehicleGlassMeshes++;
        }
      }
    }
        // Physically interpreted glazing with clearcoat and a shared geometry:
    // a finite number of accent windows, never opaque blocking props.
    if(!lite){
      const glass=mat('physical',{
        color:0x8bb6bc,metalness:.18,roughness:.17,
        clearcoat:.75,clearcoatRoughness:.13,
        transparent:true,opacity:.66,depthWrite:false,
        side:THREE.DoubleSide,envMapIntensity:1.45
      });
      const frame=mat('standard',{color:0x465965,roughness:.33,metalness:.69});
      const matrices=[],frames=[],dummy=new THREE.Object3D();
      const add=(items,x,y,z,w,h,d)=>{
        dummy.position.set(x,y,z);dummy.rotation.set(0,0,0);
        dummy.scale.set(w,h,d);dummy.updateMatrix();
        items.push(dummy.matrix.clone());
      };
      for(const {x,z} of buildings){
        if(rand(x,z,39)<.33)continue;
        const h=2.6+rand(x,z)*5.15,w=.68+rand(z,x)*.18,
          d=.68+rand(x+5,z-4)*.17,front=z+d/2+.083;
        for(let floor=0;floor<Math.min(6,Math.floor((h-.45)/.67));floor++){
          const y=.46+floor*.67;
          add(matrices,x,y,front,.36,.37,.014);
          add(frames,x,y+.194,front+.010,.41,.018,.028);
          add(frames,x,y-.194,front+.010,.41,.018,.028);
          for(const dx of [-.206,.206])
            add(frames,x+dx,y,front+.010,.018,.40,.026);
          stats.heroGlassPanels++;
        }
      }
      for(const [name,list,material] of [
        ['reflective glass',matrices,glass],
        ['metal window reveals',frames,frame]
      ]){
        if(!list.length)continue;
        const mesh=new THREE.InstancedMesh(cube,material,list.length);
        list.forEach((matrix,i)=>mesh.setMatrixAt(i,matrix));
        mesh.instanceMatrix.needsUpdate=true;mesh.frustumCulled=false;
        mesh.castShadow=false;mesh.receiveShadow=false;
        mesh.name='ZION37 / '+name;root.add(mesh);stats.drawBatches++;
      }
    }
    // One physically useful, inexpensive IBL environment for metallic
    // surfaces. The camera sky and fog are still governed by gameplay.
    function skyEnvironment(){
      if(!ultra||!THREE.PMREMGenerator||typeof document==='undefined')return;
      try{
        const canvas=document.createElement('canvas');canvas.width=512;canvas.height=256;
        const ctx=canvas.getContext('2d');
        if(!ctx)return;
        const gradient=ctx.createLinearGradient(0,0,0,256);
        for(const [y,color] of [[0,'#496d93'],[.24,'#83acc9'],
          [.47,'#b9cdd1'],[.57,'#bfa98d'],[.78,'#4b5360'],[1,'#181e2c']])
          gradient.addColorStop(y,color);
        ctx.fillStyle=gradient;ctx.fillRect(0,0,512,256);
        const sun=ctx.createRadialGradient(124,121,2,124,121,43);
        sun.addColorStop(0,'rgba(255,252,226,1)');
        sun.addColorStop(.2,'rgba(255,235,204,.85)');
        sun.addColorStop(1,'rgba(255,208,170,0)');
        ctx.fillStyle=sun;ctx.fillRect(60,57,128,128);
        skyTexture=new THREE.CanvasTexture(canvas);
        skyTexture.mapping=THREE.EquirectangularReflectionMapping;
        skyTexture.colorSpace=THREE.SRGBColorSpace;
        ownedTextures.push(skyTexture);
        pmrem=new THREE.PMREMGenerator(renderer);
        reflectionTarget=pmrem.fromEquirectangular(skyTexture);
        stats.reflectionProbe='procedural equirectangular PMREM';
        stats.reflectionReady=Boolean(reflectionTarget?.texture);
      }catch(_){
        stats.reflectionProbe='unavailable: preserve normal sky';
        reflectionTarget?.dispose?.();reflectionTarget=null;
      }
    }
    skyEnvironment();
    function syncEnvironment({raining:rain=false,dayMode=0}={}){
      raining=!!rain;stats.rain=raining;stats.night=dayMode===1;
      stats.environment=dayMode===1?'night':dayMode===2?'day':'dusk';
      assignMaterials();
      // Moderate the unrealistic previous HDR exposure without replacing
      // the game's weather and time-of-day controls.
      if(quality!=='eco'&&quality!=='adaptive'&&!lite){
        const exposure=dayMode===1?.90:dayMode===2?1.10:1.02;
        renderer.toneMappingExposure=raining?exposure*.87:exposure;
        if(keyLight){
          keyLight.intensity=dayMode===1?.48:dayMode===2?2.3:1.9;
          keyLight.color.set(dayMode===1?0xc1d8ff:dayMode===2?0xfff0db:0xffc99c);
        }
        if(hemi)hemi.intensity=dayMode===1?.78:dayMode===2?1.8:1.38;
        if(blueFill)blueFill.intensity=dayMode===1?.56:.35;
        if(scene.environment&&'environmentIntensity'in scene)
          scene.environmentIntensity=dayMode===1?.42:raining?.62:.88;
      }
    }
    function setQuality(mode){
      quality=mode;stats.quality=mode;
      const high=!lite&&mode!=='eco'&&mode!=='adaptive';
      root.visible=high;stats.highVisible=high;
      if(reflectionTarget){
        scene.environment=high?reflectionTarget.texture:originalEnv;
      }
      if(keyLight?.shadow?.mapSize&&ultra){
        const size=high?2048:512;
        if(keyLight.shadow.mapSize.x!==size){
          keyLight.shadow.mapSize.set(size,size);
          keyLight.shadow.map?.dispose?.();keyLight.shadow.map=null;
        }
        stats.shadowResolution=size;
      }
      assignMaterials();
      return high;
    }
    function update(dt){
      if(disposed||quality==='eco'||quality==='adaptive'||
        !Number.isFinite(dt)||dt<=0)return;
      clock+=Math.min(dt,.05);
      if(carContact&&car?.mesh){
        carContact.position.x=car.mesh.position.x;
        carContact.position.z=car.mesh.position.z;
        // Plane was tipped onto XZ; local-Z carries the vehicle heading.
        carContact.rotation.z=car.mesh.rotation.y;
        carContact.rotation.y=0;
      }
      if(avatarContact&&avatar){
        avatarContact.position.x=avatar.position.x;
        avatarContact.position.z=avatar.position.z;
      }
      stats.animationTicks++;
    }
    function dispose(){
      if(disposed)return;disposed=true;
      scene.environment=originalEnv;
      renderer.toneMappingExposure=originalExposure;
      scene.remove(root);
      for(const restored of vehicleRestores)restored.mesh.material=restored.material;
      for(const item of mapped){
        const m=item.material,o=item.original;
        m.map=o.map;m.normalMap=o.normalMap;m.roughnessMap=o.roughnessMap;
        m.normalScale=o.normalScale;m.roughness=o.roughness;
        m.metalness=o.metalness;m.envMapIntensity=o.envMapIntensity;
        if(o.color&&m.color)m.color.copy(o.color);
        m.needsUpdate=true;
      }
      if(keyLight&&oldLight.key){
        keyLight.intensity=oldLight.key.intensity;
        keyLight.color.copy(oldLight.key.color);
        if(oldLight.shadow!=null&&keyLight.shadow?.mapSize)
          keyLight.shadow.mapSize.set(oldLight.shadow,oldLight.shadow);
      }
      if(hemi&&oldLight.hemi!=null)hemi.intensity=oldLight.hemi;
      if(blueFill&&oldLight.fill!=null)blueFill.intensity=oldLight.fill;
      ownedGeometry.forEach(x=>x.dispose());
      ownedMaterials.forEach(x=>x.dispose());
      ownedTextures.concat(photoLoaded).forEach(x=>x.dispose?.());
      reflectionTarget?.dispose?.();pmrem?.dispose?.();
    }
    setQuality(lite?'adaptive':'high');syncEnvironment();
    return Object.freeze({get stats(){return Object.freeze({...stats});},
      setQuality,syncEnvironment,update,dispose});
  }
  host.ZION030_PHOTOREAL37=Object.freeze({VERSION,install,photographs});
})(window);
