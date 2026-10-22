/* ZION-030 v32 | Civic Landmarks & Vehicle Atelier
 * Modular meshes live inside the real Three.js city. No network resources.
 * Landmarks sit on the existing occupied rooftops; gameplay pathing stays untouched.
 */
(function(host){
  'use strict';
  const VERSION='32.0';
  const tau=Math.PI*2;
  function install({THREE,scene,rules,mobile=false,softwareGL=false,reducedMotion=false}){
    if(!THREE||!scene||!rules?.buildingAt||!rules?.blocked||!rules?.rand)throw Error('ZION32 requires the live city scene and authoritative grid');
    const lite=!!(softwareGL||reducedMotion);
    const ultra=!(lite||mobile);
    const random=rules.rand;
    const low=new THREE.Group(),high=new THREE.Group();
    low.name='ZION32 / civic landmarks - geometry';
    high.name='ZION32 / rooftop atelier - ultra detailing';
    scene.add(low,high);
    const cube=new THREE.BoxGeometry(1,1,1);
    const cyl=new THREE.CylinderGeometry(.5,.5,1,16);
    const cone=new THREE.ConeGeometry(.5,1,12);
    const sphere=new THREE.SphereGeometry(.5,18,12);
    const torus=new THREE.TorusGeometry(.5,.065,8,24);
    const geometry={cube,cyl,cone,sphere,torus};
    const geos=Object.values(geometry),ownedMats=[];
    const mat=(hex,roughness=.72,metalness=.07,emissive=0,intensity=0,opacity=1)=>{
      const opts={color:hex,roughness,metalness,opacity,transparent:opacity<1};
      if(emissive){opts.emissive=emissive;opts.emissiveIntensity=intensity;}
      const material=new (lite?THREE.MeshLambertMaterial:THREE.MeshStandardMaterial)(opts);
      ownedMats.push(material);return material;
    };
    const ivory=mat(0xc9bba3,.76),marble=mat(0xc3cfcc,.46,.12),
      sandstone=mat(0x95826f,.91),bronze=mat(0xa88456,.38,.62),
      iron=mat(0x293b4a,.42,.68),brushed=mat(0x9db2bb,.29,.72),
      solar=mat(0x143c59,.21,.67),glass=mat(0x4894a9,.19,.42),
      lime=mat(0x367c61,.95),foliage=mat(0x638c62,.93),bark=mat(0x816b50,.92),
      slate=mat(0x344957,.89),tarmac=mat(0x1a2d39,.98),
      red=mat(0xd77a63,.4,.22,0x8c3021,.27),stone=mat(0x768896,.86),
      cyan=mat(0x91f1e9,.29,.17,0x30bccc,.85),
      amber=mat(0xffdab0,.38,.1,0xc97c35,.74),
      tire=mat(0x17242a,.98),wet=mat(0x2a5c70,.11,.38,0,0,.56);
    const mats={ivory,marble,sandstone,bronze,iron,brushed,solar,glass,lime,foliage,bark,slate,tarmac,red,stone,cyan,amber,tire,wet};
    const lowBins=new Map(),highBins=new Map(),dummy=new THREE.Object3D();
    const stats={version:VERSION,tier:lite?'LITE':mobile?'MOBILE':'ULTRA',
      heroLandmarks:0,rooftopBuildings:0,roofFixtures:0,columns:0,
      greenhouseRibs:0,clockFaces:0,solarArrays:0,planters:0,
      streetLamps:0,drainageUnits:0,details:0,instances:0,
      drawCallBatches:0,vehicleParts:0,vehicleBatches:0,vehicleCount:0,maxVehicleBatches:0,characterParts:0,
      fineVisible:false,night:false,wetVisible:false};
    const finite=v=>Number.isFinite(v);
    function put(tier,key,x,y,z,w,h,d,shape='cube',yaw=0,pitch=0,roll=0){
      if(![x,y,z,w,h,d,yaw,pitch,roll].every(finite)||Math.min(w,h,d)<=0)throw Error('ZION32 invalid world transform');
      const dict=tier==='ultra'?highBins:lowBins, id=key+'|'+shape;
      if(!dict.has(id))dict.set(id,{key,shape,matrices:[]});
      dummy.position.set(x,y,z);
      dummy.scale.set(w,h,d);
      dummy.rotation.set(pitch,yaw,roll);
      dummy.updateMatrix();
      dict.get(id).matrices.push(dummy.matrix.clone());
      stats.instances++;
    }
    const base=(...args)=>put('base',...args);
    const hi=(...args)=>{if(ultra)put('ultra',...args);};
    const skyline=[];
    for(let x=-6;x<=6;x++)for(let z=-6;z<=6;z++){
      if(!rules.buildingAt(x,z))continue;
      skyline.push({x,z,height:2.6+random(x,z)*5.15,
        w:.68+random(z,x)*.18,d:.68+random(x+5,z-4)*.17,
        rank:random(x,z,21)*2+(Math.abs(x)+Math.abs(z))/28});
    }
    stats.rooftopBuildings=skyline.length;
    // True 3D rooftop architecture on the exact corresponding existing buildings.
    for(const b of skyline){
      const {x,z,w,d}=b,h=b.height,seed=random(x,z,41);
      const roof=h+.09;
      // Raised stone cornice, coping, vents and tiny drain runs.
      base('sandstone',x,roof,z,w+.055,.045,d+.055);
      base('slate',x,roof+.04,z,w*.82,.018,d*.79);
      if(seed>.14){
        base('iron',x+w*.24,roof+.14,z-d*.18,.14,.20,.14,'cube');
        base('brushed',x+w*.24,roof+.25,z-d*.18,.17,.025,.17);
        stats.roofFixtures+=2;
      }
      if(seed>.49){
        base('solar',x-w*.16,roof+.16,z+d*.09,.27,.021,.28,'cube',0,-.22);
        base('bronze',x-w*.16,roof+.075,z+d*.10,.22,.11,.025);
        stats.solarArrays++;
      }
      if(ultra){
        for(const sign of [-1,1]){
          hi('ivory',x+sign*(w/2+.035),h*.5,z,.026,h,.028);
          hi('bronze',x+sign*(w/2+.04),h-.17,z,.039,.042,d*.84);
          hi('iron',x+sign*(w/2+.033),.9,z-d*.34,.023,1.5,.025,'cyl');
        }
        if(seed>.22){
          for(let k=-1;k<=1;k++){
            hi('solar',x+k*.14,roof+.15,z+d*.26,.115,.012,.20,'cube',0,-.25);
            stats.solarArrays++;
          }
        }
        if(seed>.51){
          // Stone flower troughs and leaves on accessible-looking roof terraces.
          hi('stone',x-w*.16,roof+.09,z-d*.25,.21,.15,.13);
          for(let k=0;k<4;k++){
            hi(k%2?'foliage':'lime',x-w*.26+k*.064,roof+.20,z-d*.25,.065,.11,.075,'sphere');
          }
          stats.planters++;
        }
      }
    }
    // Six distinct hero prefabs selected from valid built rooftops,
    // spatially separated to remain legible from the player camera.
    const taken=[];
    for(const b of skyline.slice().sort((a,b)=>b.rank-a.rank)){
      if(taken.every(p=>Math.hypot(p.x-b.x,p.z-b.z)>3.1))taken.push(b);
      if(taken.length>=6)break;
    }
    taken.forEach((b,id)=>{
      const x=b.x,z=b.z,h=b.height+.13;
      stats.heroLandmarks++;
      if(id===0){
        // Civic observatory: stepped circular drum, metallic dome, viewing aperture.
        base('marble',x,h+.095,z,.69,.19,.65,'cyl');
        base('ivory',x,h+.245,z,.59,.20,.58,'cyl');
        base('glass',x,h+.44,z,.58,.36,.57,'sphere');
        base('bronze',x,h+.64,z,.22,.09,.22,'torus');
        base('brushed',x,h+.86,z,.040,.40,.040,'cyl');
        for(let k=0;k<8;k++){
          const a=k*tau/8;
          hi('brushed',x+Math.cos(a)*.27,h+.42,z+Math.sin(a)*.27,.028,.34,.028,'cyl');
          stats.columns++;
        }
      }else if(id===1){
        // Greenhouse studio: curved canopy, ribs, glazed roof, planting benches.
        base('ivory',x,h+.065,z,.72,.13,.71);
        base('glass',x,h+.43,z,.65,.58,.60);
        base('brushed',x,h+.73,z,.73,.045,.73);
        for(const t of [-.27,-.09,.09,.27]){
          hi('brushed',x+t,h+.48,z,.025,.55,.66);
          hi('brushed',x,h+.76,z+t,.70,.035,.024);
          stats.greenhouseRibs+=2;
        }
        for(const side of [-1,1]){
          base('sandstone',x+side*.24,h+.23,z,.16,.21,.48);
          for(let q=-1;q<=1;q++)hi('lime',x+side*.24,h+.38,z+q*.13,.11,.18,.11,'sphere');
          stats.planters++;
        }
      }else if(id===2){
        // Hellenic column hall: actual cylindrical colonnade, pediment, steps.
        base('ivory',x,h+.095,z,.76,.19,.73);
        base('marble',x,h+.61,z,.71,.11,.68);
        base('bronze',x,h+.71,z,.76,.13,.72,'cone',0,Math.PI/2);
        for(let k=-2;k<=2;k++){
          base('marble',x+k*.14,h+.36,z+.24,.068,.51,.068,'cyl');
          base('ivory',x+k*.14,h+.62,z+.24,.12,.055,.12,'cyl');
          stats.columns++;
        }
        hi('stone',x,h+.035,z+.40,.62,.06,.18);
        hi('stone',x,h+.075,z+.34,.66,.06,.14);
      }else if(id===3){
        // Solar observatory: tilted PBR panels, pylons and battery cabinets.
        base('slate',x,h+.08,z,.72,.16,.67);
        for(let row=-1;row<=1;row++)for(let col=-1;col<=1;col++){
          base('solar',x+col*.20,h+.28,z+row*.18,.18,.018,.15,'cube',0,-.30);
          hi('brushed',x+col*.20,h+.16,z+row*.18,.02,.19,.13);
          stats.solarArrays++;
        }
        base('iron',x,h+.34,z-.34,.38,.34,.20);
        base('cyan',x,h+.48,z-.455,.23,.055,.012);
      }else if(id===4){
        // Telecom landmark with analogue round faces, copper rings and spire.
        base('sandstone',x,h+.10,z,.67,.19,.66);
        base('marble',x,h+.42,z,.45,.53,.45);
        base('brushed',x,h+.86,z,.13,.61,.13,'cyl');
        for(const side of [-1,1]){
          base('ivory',x,h+.43,z+side*.255,.23,.23,.028,'cyl',0,0,Math.PI/2);
          base('bronze',x,h+.44,z+side*.276,.23,.025,.23,'torus');
          hi('iron',x,h+.46,z+side*.30,.018,.14,.018);
          stats.clockFaces++;
        }
        base('amber',x,h+1.19,z,.10,.07,.10,'sphere');
      }else{
        // Cooling turbine architecture, axial-ring ventilators and safety rail.
        base('slate',x,h+.10,z,.75,.18,.71);
        for(const xx of [-.19,.19]){
          base('iron',x+xx,h+.29,z,.29,.26,.30,'cyl');
          base('brushed',x+xx,h+.46,z,.26,.055,.27,'torus');
          for(let j=0;j<6;j++){
            const a=j*tau/6;
            hi('brushed',x+xx+Math.cos(a)*.08,h+.475,z+Math.sin(a)*.08,.11,.015,.035,'cube',a);
          }
          stats.roofFixtures++;
        }
        for(const edge of [-1,1]){
          base('amber',x+edge*.35,h+.31,z,.055,.12,.05);
        }
      }
    });
    // Grounded street furniture near mission districts; slim forms avoid masking
    // the walkable hot spots and mission marker centers.
    const hot=(rules.HOTSPOTS||[]).map(p=>({x:p.x,z:p.z}));
    const tooNearMission=(x,z)=>hot.some(p=>Math.hypot(x-p.x,z-p.z)<1.8);
    for(let x=-17;x<=17;x+=3.4)for(let z=-17;z<=17;z+=3.4){
      if(rules.blocked(x,z,.18)||tooNearMission(x,z)||Math.hypot(x,z)<3)continue;
      const r=random(x,z,63);
      if(r>.64){
        // A real lamp assembly: tapered pole, lens, louvres, and solar shade.
        base('iron',x,.95,z,.062,1.90,.062,'cyl');
        base('brushed',x,1.86,z,.12,.075,.12,'cyl');
        base('amber',x,2.01,z,.18,.17,.18,'sphere');
        base('solar',x,2.14,z,.34,.025,.28);
        hi('bronze',x,1.94,z,.21,.035,.22,'torus');
        hi('brushed',x,2.04,z,.19,.028,.23);
        stats.streetLamps++;
      }else if(r<.20 && !lite){
        // Low-profile traffic island: benches and rooted flower planters.
        base('stone',x,.07,z,.54,.14,.36);
        base('bark',x,.18,z,.41,.045,.23);
        for(const s of [-1,1]){
          base('iron',x+s*.14,.20,z,.022,.28,.18);
          hi('foliage',x+s*.14,.35,z,.13,.12,.14,'sphere');
        }
        stats.planters++;
      }
      if(ultra&&r>.30&&r<.48){
        hi('slate',x,-.004,z,.25,.014,.22);
        for(let d=-1;d<=1;d++)hi('iron',x+d*.065,.005,z,.014,.012,.19);
        stats.drainageUnits++;
      }
    }
    const wetMeshes=[];
    if(!lite)for(let i=0;i<(ultra?36:14);i++){
      const x=-18+random(i,191)*36,z=-18+random(i,197)*36;
      if(rules.blocked(x,z,.16)||tooNearMission(x,z))continue;
      base('wet',x,-.012,z,.11+random(i,199)*.23,.003,.11+random(i,201)*.31);
    }
    function compile(bins,layer){
      for(const bin of bins.values()){
        const mesh=new THREE.InstancedMesh(geometry[bin.shape],mats[bin.key],bin.matrices.length);
        mesh.name='ZION32 / '+bin.key+' / '+(layer===high?'ultra':'base');
        for(let n=0;n<bin.matrices.length;n++)mesh.setMatrixAt(n,bin.matrices[n]);
        mesh.instanceMatrix.needsUpdate=true;
        mesh.castShadow=false;
        mesh.receiveShadow=false;
        mesh.frustumCulled=false;
        layer.add(mesh);stats.drawCallBatches++;
        if(bin.key==='wet')wetMeshes.push(mesh);
      }
    }
    compile(lowBins,low);compile(highBins,high);
    const extraCarGroups=[],extraAvatarGroups=[];
    function detailCar(parent){
      if(!parent?.add)return;
      const baseCar=new THREE.Group(),fineCar=new THREE.Group();
      baseCar.name='ZION32 / road vehicle premium details';
      fineCar.name='ZION32 / detailed wheel/tread aerodynamics';
      baseCar.add(fineCar);
      const batches=new Map();
      const tmp=new THREE.Object3D();
      function piece(material,x,y,z,w,h,d,shape='cube',fine=false){
        const key=(fine?'fine':'base')+'|'+material+'|'+shape;
        if(!batches.has(key))batches.set(key,{fine,material,shape,m:[]});
        tmp.position.set(x,y,z);tmp.scale.set(w,h,d);
        tmp.rotation.set(0,0,shape==='cyl'?Math.PI/2:0);tmp.updateMatrix();
        batches.get(key).m.push(tmp.matrix.clone());
        stats.vehicleParts++;
      }
      for(const s of [-1,1]){
        piece('iron',s*.35,.34,-.785,.05,.18,.10);
        piece('cyan',s*.28,.40,-.82,.15,.055,.028);
        piece('red',s*.28,.39,.80,.15,.07,.019);
        piece('brushed',s*.40,.70,-.12,.11,.09,.09);
        piece('bronze',s*.42,.35,.16,.035,.018,.49);
        for(const z of [-.50,.52]){
          piece('tire',s*.465,.21,z,.022,.17,.17,'cyl',true);
          piece('brushed',s*.49,.21,z,.020,.11,.11,'cyl',true);
          for(let t=0;t<12;t++){
            const a=t*tau/12;
            piece('tire',s*.480,.21+Math.sin(a)*.158,z+Math.cos(a)*.158,
              .035,.020,.032,'cube',true);
          }
        }
      }
      piece('glass',0,.76,-.12,.61,.026,.56);
      piece('brushed',0,.82,-.10,.54,.020,.55);
      piece('iron',0,.22,-.82,.32,.075,.035);
      piece('bronze',0,.50,.775,.38,.020,.022,'cube',true);
      let batchCount=0;
      for(const slot of batches.values()){
        const mesh=new THREE.InstancedMesh(geometry[slot.shape],mats[slot.material],slot.m.length);
        slot.m.forEach((m,i)=>mesh.setMatrixAt(i,m));
        mesh.instanceMatrix.needsUpdate=true;mesh.frustumCulled=false;
        (slot.fine?fineCar:baseCar).add(mesh);
        stats.vehicleBatches++;
        batchCount++;
      }
      stats.vehicleCount++;
      stats.maxVehicleBatches=Math.max(stats.maxVehicleBatches,batchCount);
      parent.add(baseCar);
      fineCar.visible=high.visible;
      extraCarGroups.push(fineCar);
    }
    function detailAvatar(avatar){
      if(!avatar?.add)return;
      const baseAvatar=new THREE.Group(),fineAvatar=new THREE.Group();
      baseAvatar.name='ZION32 / urban field uniform';
      baseAvatar.add(fineAvatar);
      function part(into,m,x,y,z,w,h,d){
        const mesh=new THREE.Mesh(cube,mats[m]);
        mesh.position.set(x,y,z);mesh.scale.set(w,h,d);
        mesh.castShadow=false;into.add(mesh);stats.characterParts++;
      }
      part(baseAvatar,'iron',0,1.16,-.253,.25,.34,.12);
      part(baseAvatar,'cyan',0,1.28,-.325,.17,.055,.018);
      for(const sign of [-1,1]){
        part(baseAvatar,'brushed',sign*.16,1.25,-.275,.027,.49,.028);
        part(baseAvatar,'tire',sign*.16,.59,.06,.16,.10,.20);
        part(fineAvatar,'bronze',sign*.19,1.40,-.12,.09,.08,.015);
      }
      part(fineAvatar,'amber',0,1.63,-.20,.12,.024,.02);
      avatar.add(baseAvatar);
      fineAvatar.visible=high.visible;
      extraAvatarGroups.push(fineAvatar);
    }
    function setQuality(mode){
      const enabled=ultra&&mode!=='eco'&&mode!=='adaptive';
      high.visible=enabled;
      extraCarGroups.forEach(g=>g.visible=enabled);
      extraAvatarGroups.forEach(g=>g.visible=enabled);
      stats.fineVisible=enabled;
      return enabled?'ICONIC ULTRA':'BALANCED';
    }
    function syncEnvironment({raining=false,dayMode=0}={}){
      stats.night=dayMode===1;
      stats.wetVisible=Boolean(raining&&wetMeshes.length);
      wetMeshes.forEach(m=>m.visible=Boolean(raining));
      amber.emissiveIntensity=stats.night?1.6:.48;
      cyan.emissiveIntensity=stats.night?1.5:.55;
      wet.opacity=raining?.73:.22;
    }
    setQuality(lite?'adaptive':'high');
    syncEnvironment();
    function dispose(){
      scene.remove(low,high);
      geos.forEach(g=>g.dispose());
      ownedMats.forEach(m=>m.dispose());
    }
    return Object.freeze({
      get stats(){return Object.freeze({...stats});},
      detailCar,detailAvatar,setQuality,syncEnvironment,dispose
    });
  }
  host.ZION030_LANDMARK_KIT=Object.freeze({VERSION,install});
})(window);
