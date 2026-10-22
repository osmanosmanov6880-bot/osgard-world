/* ZION-030 v29 / Open City rules. Shared deterministic simulation, zero external dependencies. */
(function (host) {
  'use strict';
  const LIMIT = 20.15;
  const HOTSPOTS = Object.freeze([
    Object.freeze({ x: -4, z: -3, name: 'Жилой двор' }),
    Object.freeze({ x: 2, z: 2, name: 'Городская площадь' }),
    Object.freeze({ x: 4, z: -2, name: 'Школьный маршрут' })
  ]);
  const CONTRACTS = Object.freeze([
    Object.freeze({ id: 'solar', x: -15, z: -15, name: 'Запустить солнечную станцию', short: 'СОЛНЕЧНАЯ СТАНЦИЯ', reward: 120, icon: '☀' }),
    Object.freeze({ id: 'water', x: 15, z: -10, name: 'Починить уличный водосбор', short: 'ВОДОСБОР', reward: 150, icon: '◈' }),
    Object.freeze({ id: 'sensor', x: -10, z: 15, name: 'Проверить датчик микроклимата', short: 'ДАТЧИК КЛИМАТА', reward: 180, icon: '◉' })
  ]);
  const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));
  const rand = (x, z, salt = 0) => {
    const v = Math.sin((x + salt) * 127.1 + (z - salt) * 311.7 + 74.7) * 43758.5453;
    return v - Math.floor(v);
  };
  function buildingAt(x, z) {
    if (!Number.isInteger(x) || !Number.isInteger(z) || Math.abs(x) > 19 || Math.abs(z) > 19) return false;
    if (Math.abs(x) <= 7 && Math.abs(z) <= 7) {
      if (Math.abs(x) <= 2 && Math.abs(z) <= 2) return false;
      if (HOTSPOTS.some(h => Math.hypot(h.x - x, h.z - z) < 1.55)) return false;
      return rand(x, z) >= .49 && Math.abs(x) <= 6 && Math.abs(z) <= 6;
    }
    // Broad, connected streets lead out from the original playable block.
    if (x % 5 === 0 || z % 5 === 0) return false;
    if (Math.abs(x) >= 18 && Math.abs(z) >= 18) return false;
    return rand(x, z, 17) > .28;
  }
  function blocked(px, pz, radius = .25) {
    if (!Number.isFinite(px) || !Number.isFinite(pz)) return true;
    const r = clamp(radius, .1, .7);
    if (Math.abs(px) > LIMIT - r || Math.abs(pz) > LIMIT - r) return true;
    const cx = Math.round(px), cz = Math.round(pz);
    for (let x = cx - 2; x <= cx + 2; x++) for (let z = cz - 2; z <= cz + 2; z++) {
      if (buildingAt(x, z) && Math.abs(px - x) < .435 + r && Math.abs(pz - z) < .435 + r) return true;
    }
    return false;
  }
  function nearestFree(x, z, radius = .25) {
    x = clamp(Math.round(Number(x) || 0), -19, 19);
    z = clamp(Math.round(Number(z) || 0), -19, 19);
    if (!blocked(x, z, radius)) return { x, z };
    for (let d = 1; d < 8; d++) for (let dx = -d; dx <= d; dx++) for (let dz = -d; dz <= d; dz++) {
      if (Math.max(Math.abs(dx), Math.abs(dz)) === d && !blocked(x + dx, z + dz, radius)) return { x: x + dx, z: z + dz };
    }
    return { x: 0, z: 0 };
  }
  function route(start, goal) {
    const a = nearestFree(start.x, start.z), b = nearestFree(goal.x, goal.z);
    const key = (x, z) => x + ',' + z;
    const dest = key(b.x, b.z), queue = [a], prev = new Map([[key(a.x, a.z), null]]);
    let found = false;
    for (let index = 0; index < queue.length && index < 1800; index++) {
      const p = queue[index], origin = key(p.x, p.z);
      if (origin === dest) { found = true; break; }
      for (const [dx, dz] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const nx = p.x + dx, nz = p.z + dz, next = key(nx, nz);
        if (prev.has(next) || Math.abs(nx) > 19 || Math.abs(nz) > 19 || buildingAt(nx, nz)) continue;
        prev.set(next, origin); queue.push({ x: nx, z: nz });
      }
    }
    if (!found) return [];
    const path = [];
    for (let current = dest; current !== null; current = prev.get(current)) {
      const [x, z] = current.split(',').map(Number); path.push({ x, z });
    }
    return path.reverse();
  }
  function drivingStep(vehicle, input, dt, speedBoost = false, surface = {}) {
    const elapsed = clamp(Number(dt) || 0, 0, .06);
    const throttle = clamp(Number(input.throttle) || 0, -1, 1);
    const steer = clamp(Number(input.steer) || 0, -1, 1);
    const wet = surface.rain === true;
    const traction = wet ? (surface.grip === true ? .92 : .68) : 1;
    const maxForward = speedBoost ? 9.3 : 7.1;
    let speed = Number.isFinite(vehicle.speed) ? vehicle.speed : 0;
    speed = clamp(speed + throttle * (throttle > 0 ? 6.8 : 7.9) * elapsed * traction, -3.1, maxForward);
    if (Math.abs(throttle) < .08) speed *= Math.exp(-1.75 * elapsed);
    if (input.brake) speed *= Math.exp(-(wet ? 7 : 9) * elapsed * traction);
    if (Math.abs(speed) < .035) speed = 0;
    const heading = (Number(vehicle.heading) || 0) + steer * Math.min(Math.abs(speed) / 3, 1.5) * 1.22 * elapsed * traction * (speed >= 0 ? 1 : -1);
    const x = (Number(vehicle.x) || 0) - Math.sin(heading) * speed * elapsed;
    const z = (Number(vehicle.z) || 0) - Math.cos(heading) * speed * elapsed;
    // Stop on walls rather than tunnel through corners (continuous stepping capped by elapsed).
    if (blocked(x, z, .35)) return { ...vehicle, speed: 0, heading, collision: true };
    return { ...vehicle, x, z, speed, heading, collision: false };
  }
  // Five real multi-stage story assignments. All checkpoints lie on connected streets.
  const DISPATCHES = Object.freeze([
    { id: 'school', name: '\u0411\u0435\u0437\u043e\u043f\u0430\u0441\u043d\u044b\u0439 \u043c\u0430\u0440\u0448\u0440\u0443\u0442', reward: 160,
      steps: [{ x:-15, z:10, mode:'walk', text:'\u041e\u0441\u043c\u043e\u0442\u0440\u0438 \u0442\u0440\u043e\u0442\u0443\u0430\u0440' }, { x:10, z:15, mode:'walk', text:'\u041e\u0445\u043b\u0430\u0434\u0438 \u0448\u043a\u043e\u043b\u044c\u043d\u044b\u0439 \u0432\u0445\u043e\u0434' }] },
    { id: 'water', name:'\u0412\u043e\u0434\u0430 \u0434\u043b\u044f \u043a\u0432\u0430\u0440\u0442\u0430\u043b\u0430', reward:200,
      steps:[{ x:15, z:0, mode:'walk', text:'\u0417\u0430\u043f\u0443\u0441\u0442\u0438 \u043d\u0430\u0441\u043e\u0441' }, {x:15, z:-10, mode:'walk', text:'\u041f\u0440\u043e\u0432\u0435\u0440\u044c \u0432\u043e\u0434\u043e\u0441\u0431\u043e\u0440'}] },
    { id:'delivery', name:'\u042d\u043b\u0435\u043a\u0442\u0440\u0438\u0447\u0435\u0441\u043a\u0438\u0439 \u0440\u0435\u0439\u0441', reward:250,
      steps:[{x:0,z:-15,mode:'drive',text:'\u0417\u0430\u0431\u0435\u0440\u0438 \u0433\u0440\u0443\u0437 \u043d\u0430 \u0441\u0442\u0430\u043d\u0446\u0438\u0438'}, {x:-10,z:0,mode:'drive',text:'\u0414\u043e\u0441\u0442\u0430\u0432\u044c \u0433\u0440\u0443\u0437 \u043d\u0430 \u044d\u043b\u0435\u043a\u0442\u0440\u043e\u043a\u0430\u0440\u0435'}] },
    { id:'clinic', name:'\u0421\u0435\u0442\u044c \u043f\u043e\u043c\u043e\u0449\u0438', reward:190,
      steps:[{x:-15,z:10,mode:'walk',text:'\u041f\u0440\u043e\u0432\u0435\u0440\u044c \u043a\u043b\u0438\u043c\u0430\u0442 \u0432 \u043a\u043b\u0438\u043d\u0438\u043a\u0435'}, {x:-15,z:-15,mode:'walk',text:'\u0412\u043e\u0441\u0441\u0442\u0430\u043d\u043e\u0432\u0438 \u044d\u043d\u0435\u0440\u0433\u0438\u044e'}] },
    { id:'survey', name:'\u0410\u0442\u043b\u0430\u0441 \u043c\u0438\u043a\u0440\u043e\u043a\u043b\u0438\u043c\u0430\u0442\u0430', reward:300,
      steps:[{x:10,z:15,mode:'walk',text:'\u0418\u0437\u043c\u0435\u0440\u044c \u0432\u043e\u0437\u0434\u0443\u0445'}, {x:-10,z:15,mode:'walk',text:'\u0421\u0432\u0435\u0440\u044c \u0434\u0430\u0442\u0447\u0438\u043a\u0438'}, {x:0,z:10,mode:'walk',text:'\u041f\u0435\u0440\u0435\u0434\u0430\u0439 \u043e\u0442\u0447\u0451\u0442 \u0432 \u0448\u0442\u0430\u0431'}] }
  ].map(a => Object.freeze({ ...a, steps:Object.freeze(a.steps.map(s => Object.freeze(s))) })));
  const CHARGERS = Object.freeze([{x:0,z:-15},{x:-15,z:-5},{x:15,z:5}]);
  const dispatchIds = new Set(DISPATCHES.map(q=>q.id));
  const earnedFrom = (contracts,dispatch) =>
    CONTRACTS.filter(c=>contracts.includes(c.id)).reduce((sum,c)=>sum+c.reward,0) +
    DISPATCHES.filter(c=>dispatch.includes(c.id)).reduce((sum,c)=>sum+c.reward,0);
  const defaultProfile = () => ({ version:2, completed: [], credits: 0, reputation: 0, fastCar: false, grip:false, batteryUpgrade:false, runs:0, dispatchDone:[], dispatchSteps:{}, activeDispatch:'school' });
  function sanitizeProfile(profile) {
    const a = profile && typeof profile === 'object' ? profile : {};
    const ids = CONTRACTS.map(c=>c.id);
    const completed = [...new Set(Array.isArray(a.completed) ? a.completed.filter(s=>ids.includes(s)) : [])];
    const dispatchDone = [...new Set(Array.isArray(a.dispatchDone) ? a.dispatchDone.filter(s=>dispatchIds.has(s)) : [])];
    const rawSteps = a.dispatchSteps && typeof a.dispatchSteps === 'object' && !Array.isArray(a.dispatchSteps) ? a.dispatchSteps : {};
    const dispatchSteps = {};
    for (const d of DISPATCHES) {
      const value = Number(rawSteps[d.id]);
      dispatchSteps[d.id] = dispatchDone.includes(d.id) ? d.steps.length : Number.isInteger(value) ? clamp(value,0,d.steps.length - 1) : 0;
    }
    const activeDispatch = dispatchIds.has(a.activeDispatch) ? a.activeDispatch : DISPATCHES[0].id;
    return {
      version:2, completed, dispatchDone, dispatchSteps, activeDispatch,
      credits:clamp(Math.floor(Number(a.credits) || 0),0,earnedFrom(completed,dispatchDone)),
      reputation:completed.length*100 + dispatchDone.length*125,
      fastCar:a.fastCar===true, grip:a.grip===true, batteryUpgrade:a.batteryUpgrade===true,
      runs:clamp(Math.floor(Number(a.runs)||0),0,9999)
    };
  }
  function completeContract(profile,id) {
    const current=sanitizeProfile(profile), found=CONTRACTS.find(c=>c.id===id);
    if (!found || current.completed.includes(id)) return {changed:false,profile:current,contract:found||null};
    const next=sanitizeProfile({...current,completed:[...current.completed,id],credits:current.credits+found.reward});
    return {changed:true,profile:next,contract:found};
  }
  function purchaseUpgrade(profile,type='speed') {
    const current=sanitizeProfile(profile), price={speed:300,grip:260,battery:230}[type],field={speed:'fastCar',grip:'grip',battery:'batteryUpgrade'}[type];
    if (!price || current[field] || current.credits < price) return {changed:false,profile:current};
    return {changed:true,profile:{...current,credits:current.credits-price,[field]:true}};
  }
  function selectDispatch(profile,id) {
    const current=sanitizeProfile(profile);
    if (!dispatchIds.has(id)) return {changed:false,profile:current};
    return {changed:current.activeDispatch!==id,profile:{...current,activeDispatch:id}};
  }
  function nextDispatchStep(profile) {
    const current=sanitizeProfile(profile);
    const dispatch=DISPATCHES.find(d=>d.id===current.activeDispatch) || DISPATCHES[0];
    const index=current.dispatchSteps[dispatch.id]||0;
    return current.dispatchDone.includes(dispatch.id) ? null : {...dispatch.steps[index],index,total:dispatch.steps.length,missionId:dispatch.id,missionName:dispatch.name};
  }
  function advanceDispatch(profile,context) {
    const p=sanitizeProfile(profile), step=nextDispatchStep(p), where=context||{};
    if (!step) return {changed:false,reason:'complete',profile:p};
    const x=Number(where.x),z=Number(where.z),speed=Math.abs(Number(where.speed)||0);
    if (!Number.isFinite(x)||!Number.isFinite(z)||Math.hypot(x-step.x,z-step.z)>1.6) return {changed:false,reason:'distance',profile:p};
    if (step.mode==='drive' && (where.inCar!==true||speed>.45)) return {changed:false,reason:'park',profile:p};
    if (step.mode==='walk' && where.inCar===true) return {changed:false,reason:'onfoot',profile:p};
    const mission=DISPATCHES.find(d=>d.id===step.missionId), nextIndex=step.index+1;
    const done=nextIndex>=mission.steps.length;
    const next=sanitizeProfile({...p,dispatchSteps:{...p.dispatchSteps,[mission.id]:nextIndex},
      dispatchDone:done?[...p.dispatchDone,mission.id]:p.dispatchDone,
      credits:p.credits+(done?mission.reward:0)});
    return {changed:true,complete:done,step,mission,profile:next};
  }
  function vehicleEnergy(charge,vehicle,input,dt,upgraded=false,nearStation=false) {
    const seconds=clamp(Number(dt)||0,0,.2),now=clamp(Number(charge)||0,0,100);
    const moving=Math.abs(Number(vehicle.speed)||0),throttle=Math.abs(clamp(Number(input.throttle)||0,-1,1));
    const drain=(.095 + moving*.022 + throttle*.095) * seconds * (upgraded?.52:1);
    const regen=(input.brake?.11:0)*seconds;
    const recharge=nearStation&&moving<.3 ? 5.5*seconds : 0;
    return clamp(now - drain + regen + recharge,0,100);
  }
  function walkStep(player,input,dt,collision=blocked) {
    const t=clamp(Number(dt)||0,0,.06), old=player||{};
    let x=Number(old.x)||0,z=Number(old.z)||0,vx=Number(old.vx)||0,vz=Number(old.vz)||0;
    let stamina=clamp(Number.isFinite(old.stamina)?old.stamina:100,0,100);
    let ix=clamp(Number(input.x)||0,-1,1),iz=clamp(Number(input.z)||0,-1,1);
    const length=Math.hypot(ix,iz); if (length>1) {ix/=length;iz/=length;}
    const sprint=Boolean(input.sprint && length>.12 && stamina>3);
    stamina=clamp(stamina+(sprint?-21:14)*t,0,100);
    const cap=sprint?4.6:2.85, blend=1-Math.exp(-(length>.08?12:18)*t);
    vx+=(ix*cap-vx)*blend;vz+=(iz*cap-vz)*blend;
    const span=Math.max(1,Math.ceil(Math.hypot(vx,vz)*t/.1));
    for(let n=0;n<span;n++){const nx=x+vx*t/span,nz=z+vz*t/span;
      if(!collision(nx,z,.25))x=nx;else vx=0;
      if(!collision(x,nz,.25))z=nz;else vz=0;
    }
    let height=Math.max(0,Number(old.height)||0),vy=Number(old.vy)||0;
    if(input.jump&&height===0&&vy===0)vy=5.5;
    if(height>0||vy>0){height+=vy*t;vy-=17.2*t;if(height<=0){height=0;vy=0;}}
    return {x,z,vx,vz,stamina,height,vy,sprinting:sprint,speed:Math.hypot(vx,vz)};
  }
  function districtAt(x,z){
    if(Math.abs(x)<8&&Math.abs(z)<8)return '\u0426\u0415\u041d\u0422\u0420\u0410\u041b\u042c\u041d\u042b\u0419 \u041a\u0412\u0410\u0420\u0422\u0410\u041b';
    if(z < -8)return '\u0421\u041e\u041b\u041d\u0415\u0427\u041d\u042b\u0419 \u0420\u0410\u0419\u041e\u041d';
    if(z > 8)return '\u041f\u0410\u0420\u041a \u0418 \u041d\u0410\u0423\u041a\u0410';
    return x < 0 ? '\u041c\u0415\u0414\u0418\u0426\u0418\u041d\u0421\u041a\u0418\u0419 \u0420\u0410\u0419\u041e\u041d' : '\u0413\u041e\u0420\u041e\u0414\u0421\u041a\u041e\u0419 \u041c\u0410\u0420\u041a\u0415\u0422';
  }
  host.ZION030_CITY_RULES = Object.freeze({ LIMIT, HOTSPOTS, CONTRACTS, DISPATCHES, CHARGERS, rand, clamp, buildingAt, blocked, nearestFree, route, drivingStep, defaultProfile, sanitizeProfile, completeContract, purchaseUpgrade, selectDispatch, nextDispatchStep, advanceDispatch, vehicleEnergy, walkStep, districtAt });
})(typeof window !== 'undefined' ? window : globalThis);
