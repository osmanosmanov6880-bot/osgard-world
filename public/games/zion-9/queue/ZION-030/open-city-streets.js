/* ZION-030 / v33 STREET ATELIER
 * Authored procedural facades, arch geometry, sign atlas and vehicle surface.
 * Works only with the live game's authoritative building grid; no new collisions.
 */
(function(host){
  'use strict';
  const VERSION='33.0', TAU=Math.PI*2;
  const LABELS=['ГОРОДСКОЙ САД','АТЕЛЬЕ СВЕТА','ЭКО ЛАБ','НОВЫЕ АФИНЫ',
    'СТУДИЯ КЛИМАТА','ГАЛЕРЕЯ','ГОРОДСКОЙ ЦЕНТР','МАСТЕРСКАЯ'];
  function install({THREE,scene,rules,mobile=false,softwareGL=false,reducedMotion=false}){
    if(!THREE||!scene||!rules?.buildingAt||!rules?.rand||!rules?.blocked)
      throw Error('ZION v33: active Three.js and authoritative city grid required');
    const lite=Boolean(softwareGL||reducedMotion);
    const ultra=!mobile&&!lite;
    const random=rules.rand, base=new THREE.Group(),fine=new THREE.Group();
    base.name='ZION33 street-level stone and storefronts';
    fine.name='ZION33 microgeometry and artisan trim';
    scene.add(base,fine);
    const stats={version:VERSION,tier:lite?'LITE':mobile?'MOBILE':'ULTRA',
      decoratedBuildings:0,arches:0,entryDetails:0,balconies:0,shopSigns:0,
      atlasTextures:0,columns:0,streetPlanters:0,windowFrames:0,roadHardware:0,
      instanceCount:0,drawBatches:0,vehicleCount:0,vehicleShells:0,
      vehicleAccentBatches:0,animatedRims:0,characterParts:0,
      fineVisible:false,signLights:false,raining:false};
    const sceneMeshes=[],allGeos=[],allMats=[],allTextures=[];
    const box=new THREE.BoxGeometry(1,1,1),cyl=new THREE.CylinderGeometry(.5,.5,1,12);
    const torus=new THREE.TorusGeometry(.5,.065,7,18);
    allGeos.push(box,cyl,torus);
    const mk=(hex,rough=.72,metal=.08,em=0,emPower=0)=>{
      const p={color:hex,roughness:rough,metalness:metal};
      if(em){p.emissive=em;p.emissiveIntensity=emPower;}
      const m=new (lite?THREE.MeshLambertMaterial:THREE.MeshStandardMaterial)(p);
      allMats.push(m);return m;
    };
    const material={
      limestone:mk(0xbdb5a2,.85),plaster:mk(0x829aa4,.79),bronze:mk(0x94785b,.34,.68),
      metal:mk(0x394f59,.38,.74),white:mk(0xe4e1cb,.68,.10),
      glass:mk(0x315c71,.13,.43,0x1b4852,.17),rose:mk(0xa48374,.86),
      vine:mk(0x53866c,.97),leaf:mk(0x90a96e,.97),
      cloth:mk(0x125f74,.92,.02),charcoal:mk(0x192c38,.85,.04),
      lamp:mk(0xffd8a8,.30,.08,0xffb06e,.88),
      teal:mk(0x88e9f4,.24,.19,0x32c4db,.71),rim:mk(0xb5c9d2,.30,.83),
      rubber:mk(0x1a232b,.97,.04),darkGlass:mk(0x0d3044,.18,.37),
      paint:mk(0x96b8c1,.23,.61),trim:mk(0x293e4a,.42,.69)
    };
    function makeArchedGeometry(){
      const s=new THREE.Shape();
      s.moveTo(-.27,0);s.lineTo(-.27,.40);
      s.absarc(0,.40,.27,Math.PI,0,true);
      s.lineTo(.27,0);s.closePath();
      const cut=new THREE.Path();
      cut.moveTo(-.19,.045);cut.lineTo(.19,.045);cut.lineTo(.19,.40);
      cut.absarc(0,.40,.19,0,Math.PI,false);cut.closePath();
      s.holes.push(cut);
      return new THREE.ExtrudeGeometry(s,{depth:.035,steps:1,bevelEnabled:ultra,
        bevelThickness:.006,bevelSize:.006,bevelSegments:2,curveSegments:ultra?14:7});
    }
    const arch=makeArchedGeometry();
    const column= new THREE.LatheGeometry([
      new THREE.Vector2(.072,-.43),new THREE.Vector2(.084,-.38),
      new THREE.Vector2(.063,-.35),new THREE.Vector2(.052,0),
      new THREE.Vector2(.058,.32),new THREE.Vector2(.082,.39),
      new THREE.Vector2(.075,.43)],ultra?16:9);
    allGeos.push(arch,column);
    const geometry={box,cyl,torus,arch,column};
    const binBase=new Map(),binFine=new Map(),dummy=new THREE.Object3D();
    function put(tier,key,x,y,z,w,h,d,type='box',rotY=0,rotX=0,rotZ=0){
      if(![x,y,z,w,h,d,rotY,rotX,rotZ].every(Number.isFinite)||w<=0||h<=0||d<=0)
        throw Error('ZION v33: invalid facade geometry');
      const bins=tier==='fine'?binFine:binBase,k=key+'/'+type;
      if(!bins.has(k))bins.set(k,{key,type,matrix:[]});
      dummy.position.set(x,y,z);dummy.scale.set(w,h,d);
      dummy.rotation.set(rotX,rotY,rotZ);dummy.updateMatrix();
      bins.get(k).matrix.push(dummy.matrix.clone());
      stats.instanceCount++;
    }
    const front=(...args)=>put('base',...args);
    const micro=(...args)=>{if(ultra)put('fine',...args);};
    const facades=[];
    for(let x=-6;x<=6;x++)for(let z=-6;z<=6;z++){
      if(!rules.buildingAt(x,z))continue;
      const r=random(x,z),h=2.6+r*5.15;
      const w=.68+random(z,x)*.18,d=.68+random(x+5,z-4)*.17;
      facades.push({x,z,h,w,d,s:random(x,z,93)});
    }
    const hero=facades.filter(f=>Math.hypot(f.x,f.z)>=3.1).sort((a,b)=>{
      const da=Math.hypot(a.x,a.z),db=Math.hypot(b.x,b.z);
      return da-db;
    });
    // Two nearby storefronts in each compass quadrant, so players see details
    // while walking away from the central plaza.
    const heroSet=new Set(),quadCount=[0,0,0,0];
    for(const b of hero){
      const id=(b.x>=0?1:0)+(b.z>=0?2:0);
      if(quadCount[id]>=2)continue;
      quadCount[id]++;heroSet.add(b.x+','+b.z);
      if(heroSet.size>=8)break;
    }
    const chosen=[];
    for(const b of facades){
      const {x,z,w,d,h,s}=b,panelZ=z+d/2+.035;
      const color=s>.68?'rose':s>.34?'limestone':'plaster';
      stats.decoratedBuildings++;
      // Carved entrance with real open-hole extruded arch. Glass is behind the
      // arch, and all protrusions remain within the building collision envelope.
      front('darkGlass',x,.39,panelZ+.002,.43,.72,.024);
      front(color,x,.13,panelZ+.038,.28,.13,.13);
      front('white',x,.15,panelZ+.10,.46,.048,.11);
      front(color,x,.08,panelZ+.17,.44,.032,.13);
      front(color,x,.17,panelZ+.053,1,.99,1,'arch');
      front('metal',x,.32,panelZ+.077,.024,.50,.018);
      front('bronze',x+.12,.34,panelZ+.085,.022,.035,.018);
      front('white',x,.96,panelZ+.06,w*.86,.08,.14);
      stats.arches++;stats.entryDetails+=6;
      // Pilasters, friezes, and recessed glass panels are immediately visible
      // at eye level, even on the mobile LOD.
      for(const side of [-1,1]){
        front(color,x+side*w*.41,.53,panelZ+.055,.061,.96,.071);
        front('bronze',x+side*w*.41,1.04,panelZ+.078,.12,.047,.09);
        front('glass',x+side*w*.31,.68,panelZ+.009,.13,.33,.017);
        stats.windowFrames++;
      }
      front('limestone',x,1.18,panelZ+.015,w+.08,.070,.084);
      front('bronze',x,1.30,panelZ+.011,w+.02,.025,.055);
      const rows=Math.min(7,Math.floor((h-1.15)/.64));
      for(let row=0;row<rows;row++){
        const y=1.42+row*.65;
        front('glass',x,y,panelZ+.007,.38,.43,.016);
        front('metal',x,y,panelZ+.030,.018,.46,.021);
        front('limestone',x,y-.235,panelZ+.047,.46,.044,.075);
        stats.windowFrames++;
        if(ultra){
          micro('white',x-w*.27,y,panelZ+.054,.025,.45,.039);
          micro('white',x+w*.27,y,panelZ+.054,.025,.45,.039);
          for(const side of [-1,1]){
            micro('bronze',x+side*w*.32,y-.04,panelZ+.09,.018,.17,.029);
          }
          if(row%2===0&&s>.4){
            micro('charcoal',x,y-.25,panelZ+.14,w*.72,.041,.23);
            for(let p=-2;p<=2;p++)micro('metal',x+p*w*.12,y-.063,panelZ+.23,.015,.33,.024);
            stats.balconies++;
          }
        }
      }
      if(ultra){
        for(const side of [-1,1]){
          micro('metal',x+side*(w/2+.022),h*.49,panelZ-.038,.023,h-.35,.029,'cyl');
          micro('bronze',x+side*w*.40,.64,panelZ+.11,.024,.08,.19);
          micro('limestone',x+side*w*.42,1.40,panelZ+.030,.091,.025,.12);
        }
      }
      const heroHere=heroSet.has(x+','+z);
      if(heroHere){
        const type=chosen.length%4;
        chosen.push({x,y:1.12,z:panelZ+.18,type});
        // A pair of sculpted entasis-style columns flanking the storefront,
        // real lathe geometry rather than cylindrical boxes.
        for(const side of [-1,1]){
          front('white',x+side*w*.38,.57,panelZ+.115,1.05,1.03,1.05,'column');
          front('bronze',x+side*w*.38,1.12,panelZ+.12,.17,.07,.15);
          stats.columns++;
        }
        front('cloth',x,1.06,panelZ+.18,w*.91,.095,.29);
        front('metal',x,1.13,panelZ+.32,w*.91,.03,.024);
        micro('teal',x,.92,panelZ+.34,w*.77,.018,.023);
        for(const side of [-1,1]){
          micro('limestone',x+side*w*.32,.32,panelZ+.13,.12,.37,.055);
          micro('leaf',x+side*w*.32,.56,panelZ+.13,.16,.21,.17,'cyl');
          stats.streetPlanters++;
        }
        stats.entryDetails+=6;
      }
    }
    function makeSignAtlas(){
      if(lite||typeof document==='undefined'||!THREE.CanvasTexture)return null;
      const canvas=document.createElement('canvas');
      canvas.width=1024;canvas.height=512;
      const ctx=canvas.getContext('2d');
      if(!ctx)return null;
      for(let i=0;i<8;i++){
        const col=i%4,row=Math.floor(i/4),xx=col*256,yy=row*256;
        ctx.fillStyle=i%2?'#123547':'#092b3b';ctx.fillRect(xx,yy,256,256);
        ctx.strokeStyle=i%2?'#d8b58e':'#7adce2';ctx.lineWidth=5;ctx.strokeRect(xx+7,yy+7,242,242);
        ctx.fillStyle='#f4f2da';ctx.font='bold 24px sans-serif';ctx.textAlign='center';
        const parts=LABELS[i].split(' ');
        parts.forEach((part,n)=>ctx.fillText(part,xx+128,yy+107+n*32,235));
        ctx.fillStyle='#80cdd8';ctx.fillRect(xx+45,yy+191,166,4);
        ctx.font='14px sans-serif';ctx.fillText('ZION-030 · 2030',xx+128,yy+221);
      }
      const texture=new THREE.CanvasTexture(canvas);
      texture.colorSpace=THREE.SRGBColorSpace;
      allTextures.push(texture);stats.atlasTextures++;
      return texture;
    }
    const signAtlas=makeSignAtlas(),signMeshes=[];
    if(signAtlas){
      const materialSign=new THREE.MeshBasicMaterial({map:signAtlas,side:THREE.DoubleSide,toneMapped:false});
      allMats.push(materialSign);
      chosen.forEach(({x,y,z},i)=>{
        const g=new THREE.PlaneGeometry(.54,.145);
        const uv=g.attributes.uv;
        for(let j=0;j<uv.count;j++){
          uv.setXY(j,(i%4+uv.getX(j))/4,(1-Math.floor(i/4)+uv.getY(j))/2);
        }
        uv.needsUpdate=true;
        allGeos.push(g);
        const mesh=new THREE.Mesh(g,materialSign);
        mesh.position.set(x,y,z);mesh.name='ZION33 / authored Cyrillic storefront '+i;
        mesh.frustumCulled=false;
        base.add(mesh);sceneMeshes.push(mesh);
        signMeshes.push(mesh);stats.shopSigns++;
      });
    }
    function bake(bins,layer){
      for(const bin of bins.values()){
        const mesh=new THREE.InstancedMesh(geometry[bin.type],material[bin.key],bin.matrix.length);
        bin.matrix.forEach((m,i)=>mesh.setMatrixAt(i,m));
        mesh.instanceMatrix.needsUpdate=true;mesh.frustumCulled=false;
        mesh.castShadow=false;mesh.receiveShadow=false;
        mesh.name='ZION33 / '+bin.key+' / '+bin.type;
        layer.add(mesh);sceneMeshes.push(mesh);stats.drawBatches++;
      }
    }
    bake(binBase,base);bake(binFine,fine);
    function makeBodyGeo(){
      const sections=[
        {z:-.79,w:.27,low:.145,high:.33},
        {z:-.69,w:.37,low:.145,high:.41},
        {z:-.39,w:.425,low:.145,high:.43},
        {z:.35,w:.425,low:.145,high:.43},
        {z:.64,w:.38,low:.145,high:.36},
        {z:.79,w:.28,low:.145,high:.29}
      ];
      const pos=[],uv=[],idx=[];
      for(let i=0;i<sections.length;i++){
        const s=sections[i];
        const cross=[
          [-s.w,s.low],[-s.w,s.high*.83],[-s.w*.82,s.high],
          [s.w*.82,s.high],[s.w,s.high*.83],[s.w,s.low]
        ];
        for(const [x,y] of cross){pos.push(x,y,s.z);uv.push((x+.6)/1.2,(s.z+.9)/1.8);}
        if(i>0)for(let j=0;j<6;j++){
          const a=(i-1)*6+j,b=(i-1)*6+(j+1)%6,c=i*6+j,d=i*6+(j+1)%6;
          idx.push(a,c,b,b,c,d);
        }
      }
      for(let k=1;k<5;k++){idx.push(0,k,k+1);idx.push((sections.length-1)*6,(sections.length-1)*6+k+1,(sections.length-1)*6+k);}
      const geo=new THREE.BufferGeometry();
      geo.setAttribute('position',new THREE.Float32BufferAttribute(pos,3));
      geo.setAttribute('uv',new THREE.Float32BufferAttribute(uv,2));
      geo.setIndex(idx);geo.computeVertexNormals();
      return geo;
    }
    const shellGeo=makeBodyGeo(),rimGeo=new THREE.TorusGeometry(.115,.016,8,20);
    allGeos.push(shellGeo,rimGeo);
    const cars=[],rotorDummy=new THREE.Object3D();
    function detailCar(car){
      if(!car?.add)return;
      const group=new THREE.Group();group.name='ZION33 / modeled aerodynamic vehicle';
      const existing=car.children.find(c=>c.isMesh&&c.material&&c.material.color);
      const paintMat=existing?.material||material.paint;
      const shell=new THREE.Mesh(shellGeo,paintMat);
      shell.castShadow=false;group.add(shell);stats.vehicleShells++;
      const accentG=new THREE.Group();accentG.name='ZION33 / front and rear accents';
      const detailShapes=[
        ['rim',0,.38,-.802,.47,.022,.013],
        ['darkGlass',0,.745,-.30,.54,.023,.015],
        ['teal',0,.23,.806,.55,.030,.026],
        ['trim',0,.13,-.775,.47,.040,.04],
        ['metal',0,.14,.766,.42,.055,.06]
      ];
      const batches=new Map(),d=new THREE.Object3D();
      for(const [materialName,x,y,z,w,h,depth] of detailShapes){
        const key=materialName;
        if(!batches.has(key))batches.set(key,[]);
        d.position.set(x,y,z);d.scale.set(w,h,depth);d.rotation.set(0,0,0);d.updateMatrix();
        batches.get(key).push(d.matrix.clone());
      }
      for(const side of [-1,1]){
        for(const z of [-.50,.52]){
          const k='rim';
          for(let n=0;n<5;n++){
            const theta=n*TAU/5;
            d.position.set(side*.479,.20+Math.cos(theta)*.065,z+Math.sin(theta)*.065);
            d.scale.set(.015,.034,.015);d.rotation.set(0,0,0);d.updateMatrix();
            batches.get(k).push(d.matrix.clone());
          }
        }
      }
      for(const [key,instances] of batches){
        const mesh=new THREE.InstancedMesh(box,material[key],instances.length);
        instances.forEach((matrix,i)=>mesh.setMatrixAt(i,matrix));
        mesh.instanceMatrix.needsUpdate=true;mesh.frustumCulled=false;
        accentG.add(mesh);stats.vehicleAccentBatches++;
      }
      group.add(accentG);
      const rim=new THREE.InstancedMesh(rimGeo,material.rim,4);
      rim.instanceMatrix.needsUpdate=true;rim.frustumCulled=false;
      group.add(rim);stats.animatedRims+=4;
      car.add(group);cars.push({car,rim,spin:0,prevX:car.position.x,prevZ:car.position.z,detailGroup:group});
      stats.vehicleCount++;
      refreshRims(cars[cars.length-1]);
    }
    function refreshRims(entry){
      const {rim,spin}=entry;
      for(let i=0;i<4;i++){
        const side=i%2?-1:1,z=i<2?-.50:.52;
        rotorDummy.position.set(side*.497,.20,z);
        rotorDummy.rotation.set(spin,Math.PI/2,0);
        rotorDummy.scale.set(1,1,1);rotorDummy.updateMatrix();
        rim.setMatrixAt(i,rotorDummy.matrix);
      }
      rim.instanceMatrix.needsUpdate=true;
    }
    function update(dt){
      if(!Number.isFinite(dt)||dt<0)return;
      for(const entry of cars){
        const x=entry.car.position.x,z=entry.car.position.z;
        const moved=Math.hypot(x-entry.prevX,z-entry.prevZ);
        entry.spin+=Math.min(1,moved)/.18;
        entry.prevX=x;entry.prevZ=z;
        if(moved>.001)refreshRims(entry);
      }
    }
    const outfits=[];
    function detailAvatar(avatar){
      if(!avatar?.add)return;
      const g=new THREE.Group();g.name='ZION33 / premium utility suit';
      const add=(m,x,y,z,w,h,d)=>{
        const mesh=new THREE.Mesh(box,material[m]);
        mesh.position.set(x,y,z);mesh.scale.set(w,h,d);
        g.add(mesh);stats.characterParts++;
      };
      add('cloth',0,1.30,-.245,.31,.28,.045);
      add('teal',0,1.38,-.268,.16,.045,.018);
      add('metal',0,1.11,-.27,.085,.23,.07);
      for(const side of [-1,1]){
        add('bronze',side*.18,1.15,-.255,.038,.37,.018);
        add('charcoal',side*.22,.82,.03,.12,.08,.15);
        if(ultra)add('rim',side*.17,1.49,.0,.055,.08,.025);
      }
      avatar.add(g);outfits.push(g);
    }
    const syncEnvironment=({raining=false,dayMode=0}={})=>{
      stats.signLights=dayMode===1;
      stats.raining=Boolean(raining);
      material.lamp.emissiveIntensity=dayMode===1?1.4:.37;
      material.teal.emissiveIntensity=dayMode===1?1.1:.34;
      material.glass.roughness=raining?.095:.18;
      for(const sign of signMeshes)sign.material.opacity=1;
    };
    const setQuality=mode=>{
      fine.visible=ultra&&mode!=='eco'&&mode!=='adaptive';
      stats.fineVisible=fine.visible;
      return fine.visible?'STREET ULTRA':'CITY BALANCED';
    };
    setQuality(lite?'adaptive':'high');syncEnvironment();
    function dispose(){
      scene.remove(base,fine);
      for(const t of allTextures)t.dispose();
      for(const m of allMats)m.dispose();
      for(const g of allGeos)g.dispose();
    }
    return Object.freeze({get stats(){return Object.freeze({...stats});},
      detailCar,detailAvatar,setQuality,syncEnvironment,update,dispose});
  }
  host.ZION030_STREET_ATELIER=Object.freeze({VERSION,install});
})(window);
