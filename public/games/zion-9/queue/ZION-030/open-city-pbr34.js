/* ZION-030 v34 / Atelier PBR World
 * Live physical-ish surface response, close-range environmental geometry and
 * deterministic motion. No image downloads or new gameplay collisions.
 */
(function(host){
  'use strict';
  const VERSION='34.0',TAU=Math.PI*2,clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
  function install({THREE,scene,rules,mobile=false,softwareGL=false,reducedMotion=false}){
    if(!THREE||!scene||!rules?.buildingAt||!rules?.rand||!rules?.blocked)
      throw Error('ZION34 requires the actual playable city and canonical grid');
    const lite=!!(softwareGL||reducedMotion),ultra=!mobile&&!lite;
    const rand=rules.rand;
    const near=new THREE.Group(),fine=new THREE.Group(),kinetic=new THREE.Group();
    near.name='ZION34 / human-scale ground architecture';
    fine.name='ZION34 / fine mechanical detailing';
    kinetic.name='ZION34 / wind and industrial movement';
    scene.add(near,fine,kinetic);
    const stats={version:VERSION,tier:lite?'LITE':mobile?'MOBILE':'ULTRA',
      mappedMaterials:0,textureMaps:0,estimatedTextureBytes:0,surfaceFamilies:0,
      facadeDetails:0,roadDetails:0,drainageGrates:0,metalRailings:0,
      treeCrowns:0,windActors:0,rotatingFans:0,clothBanners:0,wetRipples:0,
      meshInstances:0,drawCallBatches:0,highVisible:false,
      rain:false,night:false,animationsEnabled:!reducedMotion,windRadians:0};
    const geo={
      box:new THREE.BoxGeometry(1,1,1),
      cyl:new THREE.CylinderGeometry(.5,.5,1,10),
      sphere:new THREE.IcosahedronGeometry(.5,1),
      ring:new THREE.TorusGeometry(.5,.025,6,20)
    };
    const geos=Object.values(geo),ownedMaterials=[],ownedTextures=[],patched=[];
    const mk=(hex,rough=.78,metal=.08,em=0,power=0,opacity=1)=>{
      const o={color:hex,roughness:rough,metalness:metal,opacity,transparent:opacity<1};
      if(em){o.emissive=em;o.emissiveIntensity=power;}
      const m=new (lite?THREE.MeshLambertMaterial:THREE.MeshStandardMaterial)(o);
      ownedMaterials.push(m);return m;
    };
    const mats={
      travertine:mk(0xd1c5aa,.88),pavement:mk(0x596976,.84),slate:mk(0x344a55,.94),
      steel:mk(0x839eaa,.36,.72),copper:mk(0xa98759,.42,.64),
      black:mk(0x1b2d39,.74,.33),glass:mk(0x2d8494,.18,.42),
      honey:mk(0xffcb8a,.35,.12,0xffa653,.70),
      blue:mk(0x65e2df,.26,.20,0x31a7c4,.68),
      clay:mk(0x92735a,.91),wood:mk(0x775844,.95),
      leaf:mk(0x4c9775,.94),leaf2:mk(0x82b88a,.94),soil:mk(0x243f34,.99),
      ripple:mk(0x7fbed3,.14,.35,0,0,.35)
    };
    // High-resolution deterministic texture authoring. Tangent-space normal
    // channels are derived from the SAME height field as the albedo/roughness
    // instead of random, unrelated RGB noise; brick grooves genuinely shade.
    function textures(kind){
      if(lite||!THREE.CanvasTexture||typeof document==='undefined')return null;
      const size=ultra?512:192;
      const names=['albedo','normal','roughness'],result={};
      const wrap=n=>(n%size+size)%size;
      const hash=(x,y,salt)=>{
        let v=(Math.imul(x|0,374761393)^Math.imul(y|0,668265263)^Math.imul(salt|0,2246822519))>>>0;
        v=Math.imul(v^(v>>>13),1274126177)>>>0;
        return ((v^(v>>>16))&1023)/1023;
      };
      const mix=(a,b,t)=>a+(b-a)*t;
      const valueNoise=(x,y,freq,salt)=>{
        const xx=wrap(x)*freq/size,yy=wrap(y)*freq/size,
          x0=Math.floor(xx),y0=Math.floor(yy);
        const u=(xx-x0)**2*(3-2*(xx-x0));
        const v=(yy-y0)**2*(3-2*(yy-y0));
        return mix(mix(hash(x0%freq,y0%freq,salt),hash((x0+1)%freq,y0%freq,salt),u),
          mix(hash(x0%freq,(y0+1)%freq,salt),hash((x0+1)%freq,(y0+1)%freq,salt),u),v);
      };
      const heightAt=(x,y)=>{
        const px=wrap(x),py=wrap(y);
        const grain=valueNoise(px,py,32,kind),bed=valueNoise(px,py,8,kind+5);
        if(kind===1){
          const row=Math.floor(py/(size/12));
          const localX=(px+(row%2)*(size/10))%(size/5);
          const localY=py%(size/12);
          const mortar=Math.min(localX,size/5-localX,localY,size/12-localY)<size/240?-.30:0;
          return .68+grain*.09+bed*.14+mortar;
        }
        if(kind===2)return .74+bed*.06+grain*.17;
        // Fine milled surface with continuous brushed lines.
        const groove=Math.sin(px*TAU*39/size)*.055;
        return .78+bed*.025+grain*.025+groove;
      };
      for(const channel of names){
        const canvas=document.createElement('canvas');canvas.width=canvas.height=size;
        const g=canvas.getContext('2d',{willReadFrequently:false});if(!g)return null;
        const im=g.createImageData(size,size),d=im.data;
        for(let y=0;y<size;y++)for(let x=0;x<size;x++){
          const idx=(y*size+x)*4,h=heightAt(x,y);
          if(channel==='normal'){
            const sx=(heightAt(x+1,y)-heightAt(x-1,y))*(kind===1?1.85:1.20);
            const sy=(heightAt(x,y+1)-heightAt(x,y-1))*(kind===1?1.85:1.20);
            const len=Math.hypot(sx,sy,1);
            d[idx]=clamp(128-sx/len*127,0,255);
            d[idx+1]=clamp(128-sy/len*127,0,255);
            d[idx+2]=clamp(128+127/len,0,255);
          }else if(channel==='roughness'){
            const base=kind===1?.81:kind===2?.87:.43;
            const rough=clamp(base+(h-.72)*.12, .12,.96)*255;
            d[idx]=d[idx+1]=d[idx+2]=rough;
          }else{
            const warm=kind===1?12:kind===2?5:16;
            const value=clamp(213+(h-.7)*55,132,241);
            d[idx]=clamp(value+warm,0,255);
            d[idx+1]=clamp(value,0,255);
            d[idx+2]=clamp(value-warm,0,255);
          }
          d[idx+3]=255;
        }
        g.putImageData(im,0,0);
        const texture=new THREE.CanvasTexture(canvas);
        texture.wrapS=texture.wrapT=THREE.RepeatWrapping;
        if(texture.repeat?.set)texture.repeat.set(kind===3?3:2,kind===3?3:3);
        texture.anisotropy=ultra?8:4;
        if(channel==='albedo')texture.colorSpace=THREE.SRGBColorSpace;
        else if(THREE.NoColorSpace)texture.colorSpace=THREE.NoColorSpace;
        ownedTextures.push(texture);result[channel]=texture;
        stats.textureMaps++;stats.estimatedTextureBytes+=size*size*4;
      }
      return result;
    }
    const atlases=lite?{}:{
      limestone:textures(1),plaster:textures(2),bronze:textures(3)
    };
    const street=scene.children.find(x=>x.name==='ZION33 street-level stone and storefronts');
    const familyMap={limestone:'limestone',white:'limestone',rose:'plaster',plaster:'plaster',
      bronze:'bronze',metal:'bronze',rim:'bronze'};
    const surfaces=[];
    if(street)for(const mesh of street.children||[]){
      if(!mesh.material||typeof mesh.name!=='string'||!mesh.name.startsWith('ZION33 / '))continue;
      const key=mesh.name.split(' / ')[1],fam=familyMap[key],atlas=atlases[fam];
      if(!atlas)continue;
      const m=mesh.material;
      if(surfaces.some(o=>o.material===m))continue;
      const saved={material:m,map:m.map,normalMap:m.normalMap,roughnessMap:m.roughnessMap,
        normalScale:m.normalScale,roughness:m.roughness};
      patched.push(saved);
      m.map=atlas.albedo;m.normalMap=atlas.normal;m.roughnessMap=atlas.roughness;
      if(THREE.Vector2)m.normalScale=new THREE.Vector2(fam==='bronze'?.25:.52,fam==='bronze'?.25:.52);
      m.needsUpdate=true;surfaces.push({material:m,atlas,family:fam});stats.mappedMaterials++;
    }
    stats.surfaceFamilies=Object.values(atlases).filter(Boolean).length;
    const bins={base:new Map(),high:new Map()},dummy=new THREE.Object3D();
    function put(which,key,x,y,z,w,h,d,shape='box',rx=0,ry=0,rz=0){
      if(![x,y,z,w,h,d,rx,ry,rz].every(Number.isFinite)||Math.min(w,h,d)<=0)
        throw Error('ZION34 invalid world geometry transform');
      const map=bins[which],name=key+'/'+shape;
      if(!map.has(name))map.set(name,{key,shape,matrices:[]});
      dummy.position.set(x,y,z);dummy.scale.set(w,h,d);dummy.rotation.set(rx,ry,rz);
      dummy.updateMatrix();map.get(name).matrices.push(dummy.matrix.clone());
      stats.meshInstances++;
    }
    const place=(...a)=>put('base',...a),micro=(...a)=>{if(ultra)put('high',...a)};
    const occupied=[];
    for(let x=-6;x<=6;x++)for(let z=-6;z<=6;z++)if(rules.buildingAt(x,z))
      occupied.push({x,z,h:2.6+rand(x,z)*5.15,
        w:.68+rand(z,x)*.18,d:.68+rand(x+5,z-4)*.17,s:rand(x,z,71)});
    for(const b of occupied){
      const {x,z,h,w,d,s}=b,front=z+d/2+.048;
      // Stone cornice, vertical rain leader and mechanically joined door
      // surround at actual human scale rather than decorative distant pixels.
      place('travertine',x,.032,front+.105,w*.84,.064,.23);
      place('slate',x,.080,front+.18,.50,.022,.20);
      place('steel',x+w*.40,h*.45,front-.030,.027,h*.8,.032,'cyl');
      place('steel',x-w*.40,h*.45,front-.030,.027,h*.8,.032,'cyl');
      place('copper',x,h-.18,front-.015,w*.93,.032,.07);
      stats.facadeDetails+=5;
      if(ultra){
        for(let row=0;row<Math.min(8,Math.floor(h/.65));row++){
          const y=.42+row*.65;
          for(const side of [-1,1]){
            micro('steel',x+side*.19,y,front+.02,.016,.37,.024);
            micro('travertine',x+side*.25,y-.175,front+.07,.12,.026,.09);
            stats.facadeDetails+=2;
          }
        }
        if(s>.38){
          const balconyHeight=Math.min(h-.40,1.95);
          micro('copper',x,balconyHeight,front+.23,w*.83,.045,.37);
          for(let i=-3;i<=3;i++){
            micro('steel',x+i*w*.11,balconyHeight+.25,front+.40,.013,.47,.018,'cyl');
            stats.metalRailings++;
          }
          micro('steel',x,balconyHeight+.50,front+.40,w*.84,.027,.025);
        }
      }
    }
    // Grates and paving patterns sit at -0.003m without gameplay collision.
    for(let x=-18;x<=18;x+=3)for(let z=-18;z<=18;z+=3){
      const cx=x+.46,cz=z+.45;
      if(rules.blocked(cx,cz,.15)||Math.hypot(cx,cz)<2.7)continue;
      const rnd=rand(x,z,244);
      if(rnd>.55){
        place('slate',cx,-.013,cz,.37,.009,.31);
        for(let n=-2;n<=2;n++)micro('steel',cx+n*.055,-.004,cz,.016,.012,.24);
        stats.drainageGrates++;
      }else if(rnd<.17){
        place('pavement',cx,-.018,cz,.58,.018,.58);
        for(const side of [-1,1]){
          micro('travertine',cx+side*.22,.026,cz,.06,.07,.5);
          micro('soil',cx+side*.16,.035,cz,.20,.08,.18);
        }
        stats.roadDetails++;
      }
    }
    const treeActors=[],rotors=[],bannerActors=[],wetMeshes=[];
    // Volumetric planters on legal sidewalk pockets. Only the crown moves:
    // anchored trunks remain stable as expected in windy streets.
    for(let x=-15;x<=15;x+=5)for(let z=-15;z<=15;z+=5){
      const px=x+1.15,pz=z+1.05;
      if(rules.blocked(px,pz,.27)||Math.hypot(px,pz)<3.8)continue;
      const height=.95+rand(x,z,91)*.38;
      place('clay',px,.12,pz,.36,.24,.34);
      place('soil',px,.255,pz,.29,.025,.27);
      place('wood',px,.50,pz,.12,height*.74,.12,'cyl');
      const canopy=new THREE.Group();canopy.position.set(px,height*.90,pz);
      for(let k=0;k<(ultra?7:mobile?4:3);k++){
        const a=k*2.39996,t=rand(x+k,z-k,80);
        const leaf=new THREE.Mesh(geo.sphere,k%3?mats.leaf:mats.leaf2);
        leaf.position.set(Math.cos(a)*(.14+.11*t),.06+(k%3)*.12,Math.sin(a)*(.14+.11*t));
        leaf.scale.set(.26,.25,.22);
        canopy.add(leaf);stats.treeCrowns++;
      }
      kinetic.add(canopy);treeActors.push({mesh:canopy,phase:rand(x,z,12)*TAU});stats.windActors++;
    }
    // A handful of rooftop fan props rotate in world space at a bounded
    // fixed timestep; geometry is shared and they never alter hitboxes.
    if(!lite)for(const b of occupied.filter(t=>t.s>.72).slice(0,6)){
      const fan=new THREE.Group();fan.position.set(b.x,b.h+.40,b.z);
      const rotor=new THREE.Group();fan.add(rotor);
      const hub=new THREE.Mesh(geo.cyl,mats.steel);
      hub.rotation.x=Math.PI/2;hub.scale.set(.10,.08,.10);
      rotor.add(hub);
      for(let k=0;k<4;k++){
        const angle=k*Math.PI/2;
        const blade=new THREE.Mesh(geo.box,mats.copper);
        blade.position.set(Math.cos(angle)*.19,Math.sin(angle)*.19,0);
        blade.rotation.z=angle;blade.scale.set(.31,.052,.026);
        rotor.add(blade);
      }
      const basePlate=new THREE.Mesh(geo.box,mats.slate);
      basePlate.position.y=-.18;basePlate.scale.set(.39,.14,.36);
      fan.add(basePlate);
      kinetic.add(fan);rotors.push({mesh:rotor,phase:rand(b.x,b.z,77)*TAU});
      stats.rotatingFans++;
    }
    // Suspended civic banners are deliberately small, avoiding mission markers.
    if(ultra)for(const b of occupied.filter(t=>t.s>.49).slice(0,12)){
      const group=new THREE.Group();
      group.position.set(b.x,b.h*.46,b.z+b.d*.50+.12);
      const hanger=new THREE.Mesh(geo.cyl,mats.steel);hanger.rotation.z=Math.PI/2;
      hanger.position.y=.20;hanger.scale.set(.025,.45,.025);group.add(hanger);
      const flag=new THREE.Mesh(geo.box,mats.glass);
      flag.position.y=-.08;flag.scale.set(.25,.36,.025);group.add(flag);
      const hem=new THREE.Mesh(geo.box,mats.copper);
      hem.position.y=-.245;hem.scale.set(.25,.022,.045);group.add(hem);
      kinetic.add(group);bannerActors.push({mesh:group,phase:rand(b.x,b.z,14)*TAU});
      stats.clothBanners++;
    }
    if(!lite){
      const wetRows=ultra?27:12;
      for(let n=0;n<wetRows;n++){
        const px=-17+rand(n,300)*34,pz=-17+rand(n,301)*34;
        if(rules.blocked(px,pz,.14))continue;
        put('base','ripple',px,-.003,pz,.17,.17,.07,'ring',Math.PI/2);
        stats.wetRipples++;
      }
    }
    function batch(dict,layer){
      for(const b of dict.values()){
        const mesh=new THREE.InstancedMesh(geo[b.shape],mats[b.key],b.matrices.length);
        b.matrices.forEach((mat,i)=>mesh.setMatrixAt(i,mat));
        mesh.instanceMatrix.needsUpdate=true;
        mesh.frustumCulled=false;mesh.castShadow=false;mesh.receiveShadow=false;
        mesh.name='ZION34 / '+b.key+' / '+b.shape;
        layer.add(mesh);stats.drawCallBatches++;
        if(b.key==='ripple')wetMeshes.push(mesh);
      }
    }
    batch(bins.base,near);batch(bins.high,fine);
    let elapsed=0;
    function update(dt){
      if(reducedMotion||!Number.isFinite(dt)||dt<=0)return;
      elapsed+=Math.min(.05,dt);
      if(lite)return;
      for(const r of rotors)r.mesh.rotation.z=elapsed*1.8+r.phase;
      // Plant and banner motion runs at 20Hz, while rotors smoothly rotate.
      if(elapsed-stats.windRadians<.048)return;
      stats.windRadians=elapsed;
      for(const a of treeActors){
        a.mesh.rotation.z=Math.sin(elapsed*1.17+a.phase)*.038;
        a.mesh.rotation.x=Math.cos(elapsed*.92+a.phase)*.031;
      }
      for(const a of bannerActors)a.mesh.rotation.y=Math.sin(elapsed*1.54+a.phase)*.09;
    }
    function setQuality(mode){
      const enabled=ultra&&mode!=='eco'&&mode!=='adaptive';
      fine.visible=enabled;
      stats.highVisible=enabled;
      // Keep texture memory allocated but disable expensive fragment samples
      // in ECO. No reload, no gameplay or mission state change.
      for(const p of patched){
        const m=p.material,s=surfaces.find(a=>a.material===m);
        if(!s)continue;
        const enabledMaps=!lite&&mode!=='eco'&&mode!=='adaptive';
        const next=enabledMaps?s.atlas:null;
        if(m.map!==(next?.albedo||null)){
          m.map=next?.albedo||null;
          m.normalMap=next?.normal||null;
          m.roughnessMap=next?.roughness||null;
          m.needsUpdate=true;
        }
      }
      return enabled?'MICRODETAIL ULTRA':'MATERIALS BALANCED';
    }
    function syncEnvironment({raining=false,dayMode=0}={}){
      stats.rain=Boolean(raining);stats.night=dayMode===1;
      wetMeshes.forEach(m=>m.visible=Boolean(raining));
      mats.honey.emissiveIntensity=stats.night?1.45:.55;
      mats.blue.emissiveIntensity=stats.night?1.12:.48;
      mats.ripple.opacity=raining?.41:.2;
    }
    setQuality(lite?'adaptive':'high');syncEnvironment();
    function dispose(){
      scene.remove(near,fine,kinetic);
      for(const p of patched){p.material.map=p.map;p.material.normalMap=p.normalMap;
        p.material.roughnessMap=p.roughnessMap;p.material.normalScale=p.normalScale;
        p.material.roughness=p.roughness;p.material.needsUpdate=true;}
      ownedMaterials.forEach(m=>m.dispose());
      ownedTextures.forEach(t=>t.dispose());
      geos.forEach(g=>g.dispose());
    }
    return Object.freeze({get stats(){return Object.freeze({...stats});},
      update,setQuality,syncEnvironment,dispose});
  }
  host.ZION030_ATELIER_PBR=Object.freeze({VERSION,install});
})(window);
