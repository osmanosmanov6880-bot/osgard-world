/* ZION-030 v28 / Open City rules. Shared deterministic simulation, zero external dependencies. */
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
        if (prev.has(next) || blocked(nx, nz)) continue;
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
  function drivingStep(vehicle, input, dt, speedBoost = false) {
    const elapsed = clamp(Number(dt) || 0, 0, .06);
    const throttle = clamp(Number(input.throttle) || 0, -1, 1);
    const steer = clamp(Number(input.steer) || 0, -1, 1);
    const maxForward = speedBoost ? 9.3 : 7.1;
    let speed = Number.isFinite(vehicle.speed) ? vehicle.speed : 0;
    speed = clamp(speed + throttle * (throttle > 0 ? 6.8 : 7.9) * elapsed, -3.1, maxForward);
    if (Math.abs(throttle) < .08) speed *= Math.exp(-1.75 * elapsed);
    if (input.brake) speed *= Math.exp(-9 * elapsed);
    if (Math.abs(speed) < .035) speed = 0;
    const heading = (Number(vehicle.heading) || 0) + steer * Math.min(Math.abs(speed) / 3, 1.5) * 1.22 * elapsed * (speed >= 0 ? 1 : -1);
    const x = (Number(vehicle.x) || 0) - Math.sin(heading) * speed * elapsed;
    const z = (Number(vehicle.z) || 0) - Math.cos(heading) * speed * elapsed;
    // Stop on walls rather than tunnel through corners (continuous stepping capped by elapsed).
    if (blocked(x, z, .35)) return { ...vehicle, speed: 0, heading, collision: true };
    return { ...vehicle, x, z, speed, heading, collision: false };
  }
  const defaultProfile = () => ({ version: 1, completed: [], credits: 0, reputation: 0, fastCar: false, runs: 0 });
  function sanitizeProfile(profile) {
    const a = profile && typeof profile === 'object' ? profile : {};
    const ids = CONTRACTS.map(c => c.id);
    const completed = [...new Set(Array.isArray(a.completed) ? a.completed.filter(s => ids.includes(s)) : [])];
    const maxCredits = CONTRACTS.reduce((n, q) => n + q.reward, 0);
    return {
      version: 1,
      completed,
      credits: clamp(Math.floor(Number(a.credits) || 0), 0, maxCredits),
      reputation: completed.length * 100,
      fastCar: a.fastCar === true,
      runs: clamp(Math.floor(Number(a.runs) || 0), 0, 9999)
    };
  }
  function completeContract(profile, id) {
    const current = sanitizeProfile(profile), found = CONTRACTS.find(c => c.id === id);
    if (!found || current.completed.includes(id)) return { changed: false, profile: current, contract: found || null };
    const next = sanitizeProfile({ ...current, completed: [...current.completed, id], credits: current.credits + found.reward });
    return { changed: true, profile: next, contract: found };
  }
  function purchaseUpgrade(profile) {
    const current = sanitizeProfile(profile);
    if (current.fastCar || current.credits < 300) return { changed: false, profile: current };
    return { changed: true, profile: { ...current, credits: current.credits - 300, fastCar: true } };
  }
  host.ZION030_CITY_RULES = Object.freeze({ LIMIT, HOTSPOTS, CONTRACTS, rand, clamp, buildingAt, blocked, nearestFree, route, drivingStep, defaultProfile, sanitizeProfile, completeContract, purchaseUpgrade });
})(typeof window !== 'undefined' ? window : globalThis);