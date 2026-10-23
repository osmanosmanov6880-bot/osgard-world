/* ZION-030 / v34 Civic Microclimate FX.
 * Visual transformation of the THREE actual cooling-zone positions. Geometry
 * and simulated vapour never alter walk/driving collisions or saved progress.
 */
(function(host){
  'use strict';
  const VERSION='34.1',TAU=Math.PI*2;
  const hotspots=[{x:-4,z:-3},{x:2,z:2},{x:4,z:-2}];
  function install({THREE,scene,mobile=false,softwareGL=false,reducedMotion=false}){
    if(!THREE||!scene||!THREE.Group||!THREE.Mesh||!THREE.InstancedMesh)
      throw Error('ZION34: actual Three.js scene required for thermal effect');
    const lite=Boolean(softwareGL||reducedMotion);
    const high=!mobile&&!lite;
    const root=new THREE.Group();root.name='ZION34 / district cooling transformation';
    scene.add(root);
    const geometries=[
      new THREE.TorusGeometry(1,.035,6,high?64:24),
      new THREE.BoxGeometry(1,1,1),
      new THREE.CylinderGeometry(.5,.5,1,high?12:8),
      new THREE.IcosahedronGeometry(.5,high?1:0)
    ];
    const [ringGeo,box,cylinder,gem]=geometries,materials=[];
    function material(color,roughness=.58,metalness=.12,emissive=0,power=0,opacity=1){
      const init={color,roughness,metalness,transparent:opacity<1,opacity,depthWrite:opacity>=1};
      if(emissive){init.emissive=emissive;init.emissiveIntensity=power;}
      const mat=new (lite?THREE.MeshLambertMaterial:THREE.MeshStandardMaterial)(init);
      materials.push(mat);return mat;
    }
    const marble=material(0xb3d5d8,.71,.12),
      blue=material(0x9ff8f6,.23,.17,0x2dcfe5,.85),
      edge=material(0x3d6977,.41,.55),
      copper=material(0xc1a27d,.44,.55),
      leaf=material(0x6cca9b,.84,.06),
      mist=material(0x9beaff,.4,.03,0x76e9ff,.20,.4),
      inner=material(0x8cd9e3,.24,.22,0x18bacc,.18,.32);
    const groups=[],particles=[];
    let active=0,clock=0,raining=false,night=false,quality='high',disposed=false;
    const stats={version:VERSION,hotspots:3,cooled:0,modulesVisible:0,drawGroups:0,
      tileSegments:0,pipeSegments:0,foliageVolumes:0,particleCount:0,activeParticles:0,
      energyRings:0,frameUpdates:0,rain:false,night:false,tier:lite?'LITE':mobile?'MOBILE':'ULTRA',
      highDetail:high,motionEnabled:!reducedMotion};
    const seed=(a,b,c=0)=>{
      const v=Math.sin((a+c)*129.13+(b-c)*731.57)*43829.54;
      return v-Math.floor(v);
    };
    function sharedInstances(parent,geometry,mat,transforms){
      if(!transforms.length)return null;
      const m=new THREE.InstancedMesh(geometry,mat,transforms.length);
      const dummy=new THREE.Object3D();
      transforms.forEach((p,i)=>{
        dummy.position.set(p.x,p.y,p.z);
        dummy.scale.set(p.sx,p.sy,p.sz);
        dummy.rotation.set(p.rx||0,p.ry||0,p.rz||0);
        dummy.updateMatrix();m.setMatrixAt(i,dummy.matrix);
      });
      m.instanceMatrix.needsUpdate=true;m.frustumCulled=false;m.castShadow=false;
      parent.add(m);stats.drawGroups++;
      return m;
    }
    for(let index=0;index<hotspots.length;index++){
      const {x,z}=hotspots[index],district=new THREE.Group();
      district.name='ZION34 / cooled district '+(index+1);
      district.position.set(x,0,z);
      district.visible=false;root.add(district);groups.push(district);
      // Two concentric embedded illuminated trails. The center remains open
      // for the original tree / shade / rain garden installed by the player.
      for(const [radius,y,key] of [[1.1,.019,blue],[1.40,.032,edge]]){
        const ring=new THREE.Mesh(ringGeo,key);
        ring.rotation.x=Math.PI/2;ring.position.y=y;
        ring.scale.set(radius,radius,1);ring.castShadow=false;district.add(ring);
        stats.energyRings++;
      }
      const tiles=[],pipes=[],gems=[];
      for(let a=0;a<12;a++){
        const angle=a*TAU/12,rad=1.28,r=Math.cos(angle),s=Math.sin(angle);
        tiles.push({x:r*rad,y:.027,z:s*rad,sx:.22,sy:.045,sz:.18,ry:angle});
        if(a%2===0){
          // Short non-colliding cooling ducts follow outer ring.
          pipes.push({x:r*1.38,y:.115,z:s*1.38,sx:.052,sy:.23,sz:.052});
          gems.push({x:r*1.38,y:.27,z:s*1.38,sx:.12,sy:.16,sz:.12});
        }
      }
      sharedInstances(district,box,marble,tiles);stats.tileSegments+=tiles.length;
      sharedInstances(district,cylinder,copper,pipes);stats.pipeSegments+=pipes.length;
      sharedInstances(district,gem,blue,gems);
      const leaves=[];
      for(let k=0;k<(high?22:mobile?10:6);k++){
        const a=k*2.39996,rad=.95+seed(k,index)*.42;
        leaves.push({x:Math.cos(a)*rad,y:.20+seed(index,k)*.22,
          z:Math.sin(a)*rad,sx:.11,sy:.18,sz:.12,rz:Math.sin(a)*.35});
      }
      sharedInstances(district,gem,leaf,leaves);stats.foliageVolumes+=leaves.length;
      if(!lite){
        const pulses=high?78:32,position=new Float32Array(pulses*3),velocity=new Float32Array(pulses);
        for(let k=0;k<pulses;k++){
          const a=k*2.39996,r=.18+seed(k,index)*.86;
          position[k*3]=Math.cos(a)*r;
          position[k*3+1]=.18+seed(index,k,71)*2.4;
          position[k*3+2]=Math.sin(a)*r;
          velocity[k]=.16+seed(k,index,23)*.25;
        }
        const geometry=new THREE.BufferGeometry();
        geometry.setAttribute('position',new THREE.BufferAttribute(position,3));
        const pointsMaterial=new THREE.PointsMaterial({
          color:0xaef4ff,size:high?.055:.079,opacity:high?.49:.30,
          transparent:true,depthWrite:false,blending:THREE.AdditiveBlending,
          sizeAttenuation:true
        });
        materials.push(pointsMaterial);
        const stream=new THREE.Points(geometry,pointsMaterial);
        stream.frustumCulled=false;district.add(stream);
        particles.push({points:stream,positions:position,velocity,
          attribute:geometry.getAttribute('position'),district});
        stats.particleCount+=pulses;
      }
      if(high){
        // Visible suspended climate canopy arcs, not physical obstacles.
        for(let a=0;a<4;a++){
          const angle=a*TAU/4,bar=new THREE.Mesh(box,inner);
          bar.position.set(Math.cos(angle)*.9,2.16,Math.sin(angle)*.9);
          bar.scale.set(.33,.045,.07);bar.rotation.y=angle;
          district.add(bar);stats.drawGroups++;
        }
      }
    }
    function syncProgress(placed=[]){
      if(!Array.isArray(placed))return stats.cooled;
      let count=0;
      groups.forEach((g,i)=>{
        const spot=hotspots[i];
        const done=placed.some(p=>p&&Number.isFinite(p.x)&&Number.isFinite(p.z)&&
          Math.hypot(p.x-spot.x,p.z-spot.z)<=1.35);
        g.visible=done;
        if(done)count++;
      });
      stats.cooled=count;stats.modulesVisible=count;
      stats.activeParticles=lite?0:particles.reduce((n,p)=>n+(p.district.visible?
        p.velocity.length:0),0);
      return count;
    }
    function setQuality(mode){
      quality=mode;
      root.visible=true;
      const detailed=high&&mode!=='eco'&&mode!=='adaptive';
      for(const p of particles)p.points.visible=mode!=='eco'&&mode!=='adaptive';
      stats.highDetail=detailed;
      stats.activeParticles=particles.reduce((n,p)=>
        n+(p.district.visible&&p.points.visible?p.velocity.length:0),0);
      return detailed?'COOLING ULTRA':'COOLING BALANCED';
    }
    function syncEnvironment({raining=false,dayMode=0}={}){
      stats.rain=Boolean(raining);stats.night=dayMode===1;
      blue.emissiveIntensity=stats.night?1.20:raining?.94:.75;
      mist.opacity=raining?.22:.36;
    }
    function update(dt){
      if(disposed||reducedMotion||!Number.isFinite(dt)||dt<=0)return;
      clock+=Math.min(dt,.05);
      if(lite)return;
      stats.frameUpdates++;
      // Throttle CPU particle updates to 20 Hz; leave the rest of the city
      // untouched. This is an atmospheric animation, not a game simulation.
      if(clock<.05)return;
      const step=clock;clock=0;
      for(const p of particles){
        if(!p.district.visible||!p.points.visible)continue;
        for(let k=0;k<p.velocity.length;k++){
          const j=k*3;
          p.positions[j+1]+=p.velocity[k]*step;
          p.positions[j]+=.004*Math.sin(k+stats.frameUpdates*.015)*step;
          if(p.positions[j+1]>2.6)p.positions[j+1]=.08;
        }
        p.attribute.needsUpdate=true;
      }
    }
    function dispose(){
      if(disposed)return;disposed=true;
      scene.remove(root);
      for(const p of particles){p.points.geometry.dispose();}
      for(const m of materials)m.dispose();
      for(const g of geometries)g.dispose();
    }
    syncProgress([]);setQuality('high');syncEnvironment();
    return Object.freeze({get stats(){return Object.freeze({...stats});},
      syncProgress,syncEnvironment,setQuality,update,dispose});
  }
  host.ZION030_COOLING_FX=Object.freeze({VERSION,install});
})(window);
