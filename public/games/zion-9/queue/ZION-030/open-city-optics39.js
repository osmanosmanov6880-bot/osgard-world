/* ZION-030 v39 / The Urban Optics Lab.
 * Grounded nighttime lamp spill, rain-only road reflections and worn paint.
 * Derived from real lamps in the playable city; no shadowless point-light spam.
 * <= 4 draw batches. Quality tiers preserve navigation, input and saved worlds.
 */
(function(host){
  'use strict';
  const VERSION='39.0',TAU=Math.PI*2;
  const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
  function install({THREE,scene,rules,lamps=[],mobile=false,softwareGL=false,reducedMotion=false}){
    if(!THREE?.Group||!THREE?.InstancedMesh||!THREE?.PlaneGeometry||
      !THREE?.CanvasTexture||!scene||!rules?.blocked)
      throw Error('ZION39 requires a live playable Three.js scene');
    const lite=Boolean(softwareGL||reducedMotion),ultra=!lite&&!mobile;
    const stats={version:VERSION,tier:lite?'LITE':mobile?'MOBILE':'ULTRA',
      authenticLampAnchors:0,spillInstances:0,reflectionInstances:0,
      roadPaintStrips:0,scuffInstances:0,drawCallBatches:0,
      canvasTextures:0,estimatedTextureBytes:0,
      night:false,rain:false,quality:'high',visible:false,
      nightPoolsVisible:false,wetReflectionsVisible:false,
      paintVisible:false,physicalLightsAdded:0,playerCollidersAdded:0,
      source:'in-game authored lamp transforms'};
    const root=new THREE.Group();root.name='ZION39 / street optics and painted roads';
    const base=new THREE.Group(),wet=new THREE.Group(),night=new THREE.Group();
    root.add(base,wet,night);scene.add(root);
    const geometries=[],materials=[],textures=[];
    const ownGeometry=g=>(geometries.push(g),g);
    const ownMaterial=m=>(materials.push(m),m);
    const ownTexture=t=>(textures.push(t),t);
    const plane=ownGeometry(new THREE.PlaneGeometry(1,1));
    const paintGeo=ownGeometry(new THREE.BoxGeometry(1,1,1));
    const spots=(Array.isArray(lamps)?lamps:[])
      .filter(x=>x?.position&&Number.isFinite(x.position.x)&&
        Number.isFinite(x.position.z))
      .map(x=>({x:x.position.x,z:x.position.z}));
    stats.authenticLampAnchors=spots.length;
    function radialAtlas(density=128,streak=false){
      if(lite||typeof document==='undefined')return null;
      const canvas=document.createElement('canvas');canvas.width=canvas.height=density;
      const g=canvas.getContext('2d');
      if(!g?.createImageData||!g.putImageData)return null;
      const im=g.createImageData(density,density),data=im.data;
      // One premultiplied-looking soft halo avoids hard edges and fake
      // geometric light cones. Its alpha fades to precisely zero on bounds.
      for(let y=0;y<density;y++)for(let x=0;x<density;x++){
        const u=(x+.5)/density-.5,v=(y+.5)/density-.5;
        const d=Math.sqrt(u*u+v*v);
        const falloff=Math.pow(clamp(1-d*2,0,1),streak?2.5:1.8);
        const grain=((x*127+y*131)%47)/47;
        const alpha=streak?falloff*(.53+.47*grain):falloff;
        const i=(y*density+x)*4;
        data[i]=streak?186:255;
        data[i+1]=streak?205:201;
        data[i+2]=streak?223:139;
        data[i+3]=Math.round(alpha*255);
      }
      g.putImageData(im,0,0);
      const tex=ownTexture(new THREE.CanvasTexture(canvas));
      tex.colorSpace=THREE.SRGBColorSpace;
      tex.generateMipmaps=true;
      stats.canvasTextures++;stats.estimatedTextureBytes+=density*density*4;
      return tex;
    }
    const spillMap=radialAtlas(128),reflectionMap=radialAtlas(128,true);
    const makeMat=(opts)=>ownMaterial(
      new (lite?THREE.MeshBasicMaterial:THREE.MeshStandardMaterial)(opts));
    let spillMat=null,reflectionMat=null;
    if(spillMap){
      spillMat=ownMaterial(new THREE.MeshBasicMaterial({
        map:spillMap,transparent:true,opacity:.35,side:THREE.DoubleSide,
        depthWrite:false,polygonOffset:true,polygonOffsetFactor:-1,
        toneMapped:false,blending:THREE.AdditiveBlending
      }));
      reflectionMat=ownMaterial(new THREE.MeshBasicMaterial({
        map:reflectionMap,transparent:true,opacity:.24,side:THREE.DoubleSide,
        depthWrite:false,polygonOffset:true,polygonOffsetFactor:-1,
        toneMapped:false,blending:THREE.AdditiveBlending
      }));
    }
    const paint=makeMat({color:0xc4c0aa,roughness:.86,metalness:.025,
      polygonOffset:true,polygonOffsetFactor:-1});
    const abrasion=makeMat({color:0x666d70,roughness:.97,metalness:0,
      polygonOffset:true,polygonOffsetFactor:-1});
    const dummy=new THREE.Object3D(),matrices={pool:[],reflect:[],paint:[],scuff:[]};
    const push=(arr,x,y,z,w,h,d,rotX=0,rotY=0,rotZ=0)=>{
      if(![x,y,z,w,h,d,rotX,rotY,rotZ].every(Number.isFinite)||
        Math.min(w,h,d)<=0)throw Error('ZION39 invalid transform');
      dummy.position.set(x,y,z);dummy.rotation.set(rotX,rotY,rotZ);
      dummy.scale.set(w,h,d);dummy.updateMatrix();
      arr.push(dummy.matrix.clone());
    };
    for(const {x,z} of spots){
      // The original in-game lamp still provides its actual light sprite.
      // A cheap grounded footprint implies bounce, without extra PointLights.
      push(matrices.pool,x+.28,.027,z,2.65,2.15,1,-Math.PI/2);
      push(matrices.reflect,x+.24,.035,z+.32,.71,2.9,1,-Math.PI/2);
    }
    stats.spillInstances=matrices.pool.length;
    stats.reflectionInstances=matrices.reflect.length;
    // Worn lane / pedestrian marks are individual shallow 3D paint strips,
    // placed only on genuinely walkable collision-authoritative streets.
    // All share ONE paint batch and ONE scuff batch.
    const routes=[[-7.62,0,0],[7.62,0,0],[0,-7.62,1],[0,7.62,1]];
    const seen=new Set();
    const addPaint=(x,z,w,l,rotation=0)=>{
      const id=Math.round(x*20)+'/'+Math.round(z*20);
      if(seen.has(id)||rules.blocked(x,z,.16))return;
      seen.add(id);
      push(matrices.paint,x,.012,z,w,.008,l,0,rotation);
      if(ultra&&matrices.scuff.length<80){
        // Dirt at the long edge gives a subtle broken/eroded paint effect.
        push(matrices.scuff,x+.015,.017,z,w*.24,.004,l*.72,0,rotation);
      }
    };
    if(!lite){
      for(const [cx,cz,axis] of routes){
        for(let i=-4;i<=4;i++){
          const offset=i*.51;
          if(axis===0)addPaint(cx+offset,cz,.26,.86);
          else addPaint(cx,cz+offset,.26,.86,Math.PI/2);
        }
      }
    }
    stats.roadPaintStrips=matrices.paint.length;
    stats.scuffInstances=matrices.scuff.length;
    function batch(group,geo,material,array,name){
      if(!material||!array.length)return null;
      const mesh=new THREE.InstancedMesh(geo,material,array.length);
      array.forEach((matrix,i)=>mesh.setMatrixAt(i,matrix));
      mesh.instanceMatrix.needsUpdate=true;mesh.frustumCulled=false;
      mesh.castShadow=false;mesh.receiveShadow=false;
      mesh.name='ZION39 / '+name;
      group.add(mesh);stats.drawCallBatches++;return mesh;
    }
    const spillMesh=batch(night,plane,spillMat,matrices.pool,'warm lamp bounce');
    const reflectMesh=batch(wet,plane,reflectionMat,matrices.reflect,'wet street elongated highlights');
    const paintMesh=batch(base,paintGeo,paint,matrices.paint,'worn pedestrian road paint');
    const scuffMesh=batch(base,paintGeo,abrasion,matrices.scuff,'abraded paint edges');
    let quality=lite?'adaptive':'high',isNight=false,isRain=false,disposed=false;
    function reflect(){
      const high=!lite&&quality!=='eco'&&quality!=='adaptive';
      root.visible=high;
      base.visible=high;
      night.visible=high&&isNight;
      wet.visible=high&&isRain&&isNight;
      stats.visible=high;
      stats.nightPoolsVisible=Boolean(spillMesh&&night.visible);
      stats.wetReflectionsVisible=Boolean(reflectMesh&&wet.visible);
      stats.paintVisible=Boolean(paintMesh&&base.visible);
      paint.roughness=isRain?.50:.86;
      abrasion.roughness=isRain?.80:.97;
      if(spillMat)spillMat.opacity=isRain?.39:.27;
      if(reflectionMat)reflectionMat.opacity=isRain?.29:0;
    }
    function setQuality(mode){
      quality=mode;stats.quality=mode;reflect();return stats.visible;
    }
    function syncEnvironment({raining=false,dayMode=0}={}){
      isRain=Boolean(raining);isNight=dayMode===1;
      stats.rain=isRain;stats.night=isNight;
      reflect();
    }
    function dispose(){
      if(disposed)return;disposed=true;scene.remove(root);
      geometries.forEach(x=>x.dispose());materials.forEach(x=>x.dispose());
      textures.forEach(x=>x.dispose());
    }
    setQuality(lite?'adaptive':'high');syncEnvironment();
    return Object.freeze({
      get stats(){return Object.freeze({...stats});},
      setQuality,syncEnvironment,dispose
    });
  }
  host.ZION030_OPTICS39=Object.freeze({VERSION,install});
})(window);
