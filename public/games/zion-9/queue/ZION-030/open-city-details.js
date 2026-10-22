/* ZION-030 / Detail Engine v30.
 * Procedural high-detail asset kit for the live Three.js scene. No remote assets.
 * All facade/paving/vegetation geometry is instanced with bounded draw calls.
 */
(() => {
  'use strict';
  const VERSION = '30.0';
  const finite = value => Number.isFinite(value);

  function install({ THREE, scene, rules, mobile = false, reducedMotion = false, softwareGL = false }) {
    if (!THREE || !scene || !rules?.buildingAt || !rules?.rand) throw new Error('Detail kit dependencies unavailable');
    const lite = Boolean(reducedMotion || softwareGL);
    const medium = Boolean(mobile || lite);
    const ultra = !medium;
    const lowLayer = new THREE.Group();
    const highLayer = new THREE.Group();
    lowLayer.name = 'ZION30 / durable architecture';
    highLayer.name = 'ZION30 / ultra-detail near LOD';
    scene.add(lowLayer, highLayer);
    const cube = new THREE.BoxGeometry(1, 1, 1);
    const sphere = new THREE.IcosahedronGeometry(1, 1);
    const cone = new THREE.ConeGeometry(1, 1, 7);
    const cylinder = new THREE.CylinderGeometry(1, 1, 1, 10);
    const dummy = new THREE.Object3D();
    const buckets = new Map();
    const textures = [];
    const materials = [];
    const geometries = [cube, sphere, cone, cylinder];
    const stats = { version: VERSION, tier: lite ? 'LITE' : mobile ? 'MOBILE' : 'ULTRA', buildings: 0,
      outerBuildings: 0, windows: 0, balconies: 0, rooftopFixtures: 0,
      foliage: 0, streetObjects: 0, instances: 0, batchedDrawCalls: 0,
      carDetails: 0, characterDetails: 0, chargingPoints: 0, texturedRoad: false };
    const random = rules.rand;
    const material = (color, opt = {}) => {
      const opts = { color, roughness: opt.roughness ?? .74, metalness: opt.metalness ?? .1 };
      if (opt.emissive) { opts.emissive = opt.emissive; opts.emissiveIntensity = opt.intensity ?? .12; }
      const mat = lite ? new THREE.MeshLambertMaterial(opts) : new THREE.MeshStandardMaterial(opts);
      materials.push(mat); return mat;
    };
    const glassDark = material(0x174056, { roughness: .19, metalness: .55, emissive: 0x082331 });
    const glassLit = material(0xd8ae81, { roughness: .34, metalness: .24, emissive: 0xa06426, intensity: .38 });
    const stone = material(0x697888, { roughness: .78 });
    const sandstone = material(0xa69a86, { roughness: .85 });
    const iron = material(0x2c3e49, { roughness: .39, metalness: .74 });
    const bronze = material(0x936f58, { roughness: .45, metalness: .55 });
    const concrete = material(0x344a56, { roughness: .88 });
    const awning = material(0x186274, { roughness: .64 });
    const solar = material(0x154d6c, { roughness: .14, metalness: .65 });
    const roadPaint = material(0xb6cac8, { roughness: .83 });
    const roadDark = material(0x101e2a, { roughness: .93 });
    const leafA = material(0x276b51, { roughness: .95 });
    const leafB = material(0x397b56, { roughness: .91 });
    const leafC = material(0x63916a, { roughness: .91 });
    const bark = material(0x74563d, { roughness: .92 });
    const warmLED = material(0xf7dfb1, { roughness: .4, emissive: 0xe7ab61, intensity: .48 });
    const coolLED = material(0x81d6df, { roughness: .36, emissive: 0x30a1b3, intensity: .4 });
    const matByKey = { glassDark, glassLit, stone, sandstone, iron, bronze, concrete,
      awning, solar, roadPaint, roadDark, leafA, leafB, leafC, bark, warmLED, coolLED };
    const geomByKey = { cube, sphere, cone, cylinder };

    // World-coordinate matrix batches. A 3,000-instance facade can stay one draw call.
    function place(kind, name, x, y, z, w, h, d, yaw = 0, pitch = 0, roll = 0, geometry = 'cube') {
      if (![x,y,z,w,h,d,yaw,pitch,roll].every(finite) || Math.min(w,h,d) <= 0) throw new Error('Invalid detail instance');
      const key = kind + ':' + name + ':' + geometry;
      if (!buckets.has(key)) buckets.set(key, { kind, name, geometry, matrices: [] });
      dummy.position.set(x, y, z);
      dummy.scale.set(w, h, d);
      dummy.rotation.set(pitch, yaw, roll);
      dummy.updateMatrix();
      buckets.get(key).matrices.push(dummy.matrix.clone());
      stats.instances++;
    }
    const base = (...args) => place('base', ...args);
    const hi = (...args) => { if (ultra) place('hi', ...args); };
    const valid = (x,z) => !rules.blocked(x,z,.09);

    // Tileable deterministic asphalt noise. Applied to the existing road plane,
    // so road routing, physics and all original road markings remain authoritative.
    function upgradeRoadSurface() {
      if (lite || typeof document === 'undefined') return;
      const canvas=document.createElement('canvas');canvas.width=canvas.height=512;
      const ctx=canvas.getContext('2d');if(!ctx)return;
      const image=ctx.createImageData(512,512);
      let seed=0x1b765a21;
      for(let p=0;p<image.data.length;p+=4){
        seed=(1664525*seed+1013904223)>>>0;
        const grey=22+(seed&15), blue=grey+5;
        image.data[p]=grey;image.data[p+1]=grey+7;image.data[p+2]=blue+11;image.data[p+3]=255;
      }
      ctx.putImageData(image,0,0);
      ctx.globalAlpha=.22;ctx.strokeStyle='#76818a';ctx.lineWidth=1;
      for(let n=0;n<48;n++){
        const x=random(n,91)*512,z=random(n,92)*512;
        ctx.beginPath();ctx.moveTo(x,z);ctx.lineTo(x+random(n,93)*21-10,z+random(n,94)*8-4);ctx.stroke();
      }
      ctx.globalAlpha=1;
      const texture=new THREE.CanvasTexture(canvas);texture.wrapS=texture.wrapT=THREE.RepeatWrapping;
      texture.repeat.set(10,10);texture.colorSpace=THREE.SRGBColorSpace;
      textures.push(texture);
      const asphalt=scene.children.find(m=>m.isMesh && m.geometry?.type==='PlaneGeometry'
        && m.geometry.parameters?.width===41 && m.geometry.parameters?.height===41);
      if(asphalt?.material){asphalt.material.map=texture;asphalt.material.color.setHex(0xffffff);
        asphalt.material.needsUpdate=true;stats.texturedRoad=true;}
    }
    upgradeRoadSurface();

    // 01. Photographically readable facades: recessed panes, stone lintels,
    // mullions, aluminium frames, balconies, shop fronts and rooftop hardware.
    function windowPanel(x, y, z, horizontalFace, outward, illuminated, fine) {
      const glass = illuminated ? 'glassLit' : 'glassDark';
      const w = .18, h = .245, depth = .017;
      const xp = horizontalFace ? x : x + outward * .018;
      const zp = horizontalFace ? z + outward * .018 : z;
      if (horizontalFace) {
        base(glass, xp, y, zp, w, h, depth);
        base('iron', xp, y + h / 2 + .014, zp, w + .04, .028, .045);
        base('stone', xp, y - h / 2 - .028, zp, w + .085, .034, .055);
        if (fine) {
          hi('iron', xp - w/2 - .009, y, zp, .016, h + .025, .038);
          hi('iron', xp + w/2 + .009, y, zp, .016, h + .025, .038);
          hi('iron', xp, y, zp + outward * .012, .011, h, .015);
          hi('bronze', xp, y + h / 5, zp + outward * .014, w + .01, .011, .014);
        }
      } else {
        base(glass, xp, y, zp, depth, h, w);
        base('iron', xp, y + h / 2 + .014, zp, .045, .028, w + .04);
        base('stone', xp, y - h / 2 - .028, zp, .055, .034, w + .085);
        if (fine) {
          hi('iron', xp, y, zp - w/2 - .009, .038, h + .025, .016);
          hi('iron', xp, y, zp + w/2 + .009, .038, h + .025, .016);
          hi('iron', xp + outward * .012, y, zp, .015, h, .011);
          hi('bronze', xp + outward * .014, y + h/5, zp, .014, .011, w + .01);
        }
      }
      stats.windows++;
    }
    function buildingDetails(x, z, isOuter) {
      const h = isOuter ? 2.5 + random(x,z,4) * 7.1 : 2.6 + random(x,z) * 5.15;
      const w = isOuter ? .67 + random(z,x,5) * .15 : .68 + random(z,x) * .18;
      const d = isOuter ? .65 + random(x,z,7) * .20 : .68 + random(x+5,z-4) * .17;
      const seed = random(x,z,13);
      if (isOuter) stats.outerBuildings++; else stats.buildings++;
      // Roof perimeter, cornice and drainage downpipes on all featured facades.
      for (const sign of [-1,1]) {
        base('stone', x, h+.095, z+sign*(d/2+.018), w+.085, .10, .039);
        base('stone', x+sign*(w/2+.018), h+.095, z, .039, .10, d+.075);
      }
      base('concrete', x, h + .012, z, w*.8, .02, d*.8);
      const sparse = lite || isOuter;
      const floors = Math.max(2, Math.floor((h-.55)/.55));
      for (let floor=0;floor<floors;floor++) {
        const y=.62+floor*.55;
        if (y+.18>h-.06) continue;
        if (isOuter && floor % 3 !== 0) continue;
        if (lite && floor % 2) continue;
        for(const side of [-1,1]) {
          const fine = ultra && !isOuter && floor % 2 === 0;
          const lit = random(x+floor*3,z+side,17)>.61;
          const count=isOuter?1:2;
          for(let col=0;col<count;col++) {
            const xx=count===1?x:x+(col-.5)*w*.49;
            windowPanel(xx,y,z+side*(d/2+.016),true,side,lit && col===0,fine);
            if (ultra && !isOuter) {
              const zz=z+(col-.5)*d*.48;
              windowPanel(x+side*(w/2+.016),y,zz,false,side,
                random(x+floor,z+col,19)>.76,fine);
            }
          }
        }
        // Balcony slabs, transparent rail guards and drainage lips.
        if (ultra && !sparse && floor>0 && floor%3===1 && seed>.27) {
          const dir=floor%2===0?1:-1;
          const wall=z+dir*(d/2+.03),edge=wall+dir*.15;
          hi('stone',x,y-.175,wall+dir*.06,w*.76,.055,.24);
          hi('iron',x,y-.04,edge,w*.75,.028,.025);
          for(let i=-2;i<=2;i++)hi('iron',x+i*w*.14,y-.11,edge,.013,.21,.013);
          stats.balconies++;
        }
      }
      // Door recess, soffit, two steps and a lit shop lintel.
      const front=z + d/2+.032;
      base('glassDark',x,.32,front,.30,.53,.025);
      base('iron',x,.62,front,.36,.055,.07);
      base('stone',x,.04,front+.07,.45,.042,.18);
      hi('warmLED',x+.09,.32,front+.02,.015,.04,.012);
      if(seed>.66) {
        hi('awning',x,.76,front+.12,w*.83,.07,.32);
        hi('bronze',x,.71,front+.27,w*.82,.025,.024);
      }
      // Rooftop systems: photorealistic silhouette cues with minimal meshes.
      if(seed>.17) {
        base('iron',x-w*.15,h+.21,z-.08,.30,.20,.19);
        hi('roadDark',x-w*.15,h+.32,z-.08,.30,.02,.22);
        for(let i=-1;i<=1;i++)hi('iron',x-w*.15+i*.07,h+.34,z-.08,.015,.05,.22);
        stats.rooftopFixtures++;
      }
      if(seed>.47) {
        base('solar',x+w*.17,h+.17,z+.03,.27,.025,.28,0,-.27);
        hi('iron',x+w*.17,h+.09,z+.03,.24,.095,.015);
        stats.rooftopFixtures++;
      }
      if(ultra && seed>.87) {
        hi('bronze',x+w*.15,h+.34,z-.03,.11,.36,.11,0,0,0,'cylinder');
        hi('warmLED',x+w*.15,h+.56,z-.03,.12,.04,.12);
        stats.rooftopFixtures++;
      }
    }
    for(let x=-7;x<=7;x++)for(let z=-7;z<=7;z++)if(rules.buildingAt(x,z))buildingDetails(x,z,false);
    if(!lite) {
      for(let x=-19;x<=19;x++)for(let z=-19;z<=19;z++) {
        if(Math.abs(x)<=7&&Math.abs(z)<=7 || !rules.buildingAt(x,z))continue;
        // Urban vistas are strongest along arterial streets, not at the far edge.
        if(Math.min(Math.abs(x),Math.abs(z))>15)continue;
        if(random(x,z,31)<(ultra?.85:.93))continue;
        buildingDetails(x,z,true);
      }
    }

    // 02. Civil engineering street detailing with no expensive individual objects.
    // Intersections, dashed lines, storm drains, contrasting kerbs and tactile paving.
    for(const coord of [-15,-10,-5,5,10,15]) {
      for(let p=-18;p<=18;p+=2) {
        base('roadPaint',coord,p%2? .016:.011,p,.018,.008,.48);
        base('roadPaint',p,.012,coord,.48,.008,.018);
      }
    }
    for(const road of [-15,-10,-5,5,10,15]){
      for(const side of [-1,1]){
        const edge=road+side*.58;
        for(let s=-18;s<=18;s+=2) {
          base('stone',edge,.025,s,.025,.075,1.8);
          base('stone',s,.025,edge,1.8,.075,.025);
          stats.streetObjects+=2;
          if(ultra && s%4===0) {
            hi('roadDark',edge+side*.09,.026,s,.014,.008,1.55);
            hi('roadDark',s,.026,edge+side*.09,1.55,.008,.014);
          }
        }
      }
      for(const x of [-15,-10,-5,5,10,15]){
        for(let n=-2;n<=2;n++) {
          base('roadPaint',x+n*.16,.015,road,.09,.007,.71);
          hi('roadPaint',road,.015,x+n*.16,.71,.007,.09);
        }
        if(ultra) for(const sign of [-1,1]){
          const x0=x+sign*.78,z0=road+sign*.78;
          hi('roadDark',x0,.009,z0,.24,.008,.21);
          for(let d=-1;d<=1;d++)hi('iron',x0+d*.053,.018,z0,.012,.012,.18);
        }
      }
    }
    // Adjustable traffic furnishings: utility boxes, signal gantries and benches.
    for(let n=0;n<44;n++) {
      const x=-17+(n%11)*3.4, z=-16+Math.floor(n/11)*9.5;
      if(!valid(x,z)||Math.abs(x)>19||Math.abs(z)>19)continue;
      base('stone',x,.11,z,.31,.22,.27);
      base('iron',x,.23,z,.28,.035,.25);
      if(ultra){hi('bronze',x,.145,z+.14,.25,.12,.014);hi('coolLED',x,.21,z+.155,.14,.022,.014);}
      stats.streetObjects++;
    }
    for(const [x,z,rotation] of [[-9,5,0],[9,5,1.57],[-15,-5,0],[12,-10,1.57],[4,15,0]]) {
      if(!valid(x,z))continue;
      base('stone',x,.02,z,1.20,.08,.38,rotation);
      base('iron',x-.55,1.15,z,.065,2.25,.065,rotation);
      base('iron',x+.55,1.15,z,.065,2.25,.065,rotation);
      base('solar',x,2.28,z,1.33,.08,.72,rotation);
      if(ultra){hi('glassDark',x,1.1,z-.19,1.14,1.75,.032,rotation);hi('coolLED',x,2.18,z+.35,1.12,.06,.04,rotation);}
      stats.streetObjects++;
    }
    // Tree species, low shrubs, raised planters and groundcover: distinct canopies.
    for(let i=0;i<(ultra?100:lite?18:52);i++) {
      const x=-18+random(i,14)*36,z=-18+random(i,23)*36;
      if(!valid(x,z)||Math.hypot(x,z)<3||rules.HOTSPOTS?.some(h=>Math.hypot(h.x-x,h.z-z)<.8))continue;
      const s=.7+random(i,5)*.55;
      base('bark',x,.36*s,z,.11*s,.72*s,.11*s,0,0,0,'cylinder');
      base('leafA',x,.91*s,z,.34*s,.39*s,.34*s,0,0,0,'sphere');
      base('leafB',x+.19*s,1.05*s,z+.06*s,.27*s,.31*s,.27*s,0,0,0,'sphere');
      base('leafC',x-.14*s,1.02*s,z-.15*s,.32*s,.30*s,.30*s,0,0,0,'sphere');
      if(ultra) {
        for(let n=0;n<4;n++) {
          const a=n*1.6+random(i,n),b=.38+.22*random(n,i);
          hi(n%2?'leafA':'leafC',x+Math.cos(a)*b*s,.85*s+random(n,i)*.45*s,z+Math.sin(a)*b*s,.16*s,.22*s,.20*s,0,0,0,'sphere');
        }
        base('stone',x,.04,z,.56,.065,.56);
      }
      stats.foliage++;
    }
    // Charger pedestals are mission-aligned, not fake clickable points.
    for(const p of rules.CHARGERS||[]) {
      const x=p.x,z=p.z;
      base('stone',x,.04,z,.57,.08,.43);
      base('iron',x,.51,z,.32,.94,.25);
      base('coolLED',x,.74,z+.137,.17,.15,.015);
      base('warmLED',x,.98,z,.16,.05,.27);
      if(ultra) {
        hi('iron',x-.21,.42,z,.06,.64,.06);
        hi('iron',x-.21,.12,z+.21,.05,.05,.44);
        hi('glassDark',x,.44,z+.14,.22,.30,.014);
        hi('coolLED',x,.47,z+.152,.12,.085,.02);
      }
      stats.chargingPoints++;
    }

    function compile() {
      for(const collection of buckets.values()) {
        if(!collection.matrices.length)continue;
        const obj=new THREE.InstancedMesh(geomByKey[collection.geometry],matByKey[collection.name],collection.matrices.length);
        obj.name='ZION30 / '+collection.name+' / '+collection.kind;
        collection.matrices.forEach((m,i)=>obj.setMatrixAt(i,m));
        obj.instanceMatrix.needsUpdate=true;
        obj.castShadow=false;obj.receiveShadow=false;
        // Instanced world coordinates are absolute; retaining the conservative bound avoids pop-in.
        obj.frustumCulled=false;
        (collection.kind==='hi'?highLayer:lowLayer).add(obj);
        stats.batchedDrawCalls++;
      }
    }
    compile();

    // 03. Vehicle concept model, aligned with base CITY RUNNER collision footprint.
    const carMaterials = {
      black:material(0x12212e,{roughness:.73}),
      chrome:material(0x9aaebb,{roughness:.28,metalness:.82}),
      glass:material(0x193e54,{roughness:.12,metalness:.58}),
      red:material(0xde5f5a,{roughness:.32,emissive:0x8a211b,intensity:.35}),
      electric:material(0x5de5ee,{roughness:.25,emissive:0x239fb2,intensity:.5}),
      trim:material(0x345065,{roughness:.44,metalness:.55})
    };
    function detailCar(parent) {
      if(!parent?.add)return;
      const car = new THREE.Group();car.name='ZION30 / CITY RUNNER studio trim';
      const addCar = (x,y,z,w,h,d,m,rotation=0,shape='box')=>{
        const mesh=new THREE.Mesh(shape==='disc'?cylinder:cube,m);
        mesh.position.set(x,y,z);mesh.scale.set(w,h,d);
        if(rotation)mesh.rotation.z=rotation;
        mesh.castShadow=false;car.add(mesh);stats.carDetails++;
        return mesh;
      };
      // Body seams, windscreen, side glass and sculpted bumpers.
      addCar(0,.74,-.335,.63,.24,.014,carMaterials.glass);
      addCar(0,.69,.50,.60,.23,.018,carMaterials.glass);
      addCar(0,.24,-.79,.70,.13,.055,carMaterials.black);
      addCar(0,.23,.79,.72,.09,.05,carMaterials.chrome);
      addCar(0,.30,-.818,.28,.07,.014,carMaterials.chrome);
      addCar(0,.55,-.20,.74,.019,.015,carMaterials.chrome);
      addCar(0,.80,.10,.79,.018,.72,carMaterials.trim);
      if(!lite) {
        for(const side of [-1,1]) {
          addCar(side*.395,.56,.05,.028,.33,.76,carMaterials.glass);
          addCar(side*.415,.41,.05,.025,.012,.65,carMaterials.chrome);
          addCar(side*.42,.37,.25,.029,.016,.10,carMaterials.chrome);
          addCar(side*.46,.61,-.23,.13,.09,.15,carMaterials.black);
          for(const z of [-.49,.52]) {
            addCar(side*.478,.20,z,.018,.13,.13,carMaterials.chrome,Math.PI/2,'disc');
            addCar(side*.487,.20,z,.02,.046,.046,carMaterials.black,Math.PI/2,'disc');
          }
        }
        for(const x of [-.26,.26]) {
          addCar(x,.39,-.806,.17,.087,.021,carMaterials.electric);
          addCar(x,.39,.809,.16,.072,.018,carMaterials.red);
          addCar(x,.19,-.801,.16,.035,.028,carMaterials.black);
        }
      }
      if(ultra) {
        addCar(0,.27,-.823,.33,.035,.020,carMaterials.black);
        for(let n=-3;n<=3;n++)addCar(n*.037,.27,-.846,.012,.038,.012,carMaterials.chrome);
        addCar(0,.43,-.794,.09,.046,.018,carMaterials.chrome);
        addCar(0,.42,.825,.21,.07,.016,carMaterials.chrome);
      }
      parent.add(car);
    }

    function detailAvatar(avatar) {
      if(!avatar?.add)return;
      const make=(x,y,z,w,h,d,mat)=>{
        const mesh=new THREE.Mesh(cube,mat);mesh.position.set(x,y,z);mesh.scale.set(w,h,d);avatar.add(mesh);stats.characterDetails++;
      };
      const fabric=carMaterials.black,accent=carMaterials.electric,met=carMaterials.chrome;
      make(0,1.28,.275,.26,.028,.07,accent);
      make(-.15,1.17,-.208,.035,.49,.02,met);
      make(.15,1.17,-.208,.035,.49,.02,met);
      make(0,1.45,-.16,.23,.037,.038,accent);
      if(!lite) {
        make(-.18,.71,-.03,.14,.08,.18,fabric);
        make(.18,.71,-.03,.14,.08,.18,fabric);
        make(-.08,1.80,-.15,.11,.035,.03,fabric);
        make(.08,1.80,-.15,.11,.035,.03,fabric);
        make(0,1.18,.29,.21,.14,.04,met);
      }
    }

    function setQuality(mode) {
      highLayer.visible = ultra && mode !== 'eco' && mode !== 'adaptive';
      return highLayer.visible ? 'ULTRA' : lite ? 'LITE' : 'BALANCED';
    }
    setQuality(lite?'adaptive':'high');
    function dispose() {
      scene.remove(lowLayer,highLayer);
      // Geometry/material lifetime is owned by this module only.
      for(const geo of geometries)geo.dispose();
      for(const mat of materials)mat.dispose();
      for(const tex of textures)tex.dispose();
    }
    return Object.freeze({ get stats() { return Object.freeze({ ...stats }); }, detailCar, detailAvatar, setQuality, dispose });
  }
  window.ZION030_DETAIL_KIT = Object.freeze({ VERSION, install });
})();