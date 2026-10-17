import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

// Run the shipped controller against bounded HTTP fixtures. These tests establish
// client behavior for the v2 contract; they do not prove a live account match,
// multiplayer admission, Unity gameplay, or simulator restart recovery.
const html = readFileSync('public/games/remix/index.html', 'utf8');
const source = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(match => match[1]).find(code => code.includes('async function restoreSession()'));
assert.ok(source, 'REMIX session controller is missing');
const interfaceSource = readFileSync('public/games/remix/interface.js', 'utf8');
const origin = 'https://osgard.world', coreKey = 'osgard:core-session:v1';
const response = (value, status = 200) => ({ ok: status >= 200 && status < 300, status, json: async () => value });
const deferred = () => { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no; }); return { promise, resolve, reject }; };
const capabilities = { authPolicyVersion: 1, creationEnabled: false, provider: 'core', ownershipPolicy: 'confirmed-durable-binding', legacyMatches: 'anonymous', activeMatchRecovery: false, replayVerification: false };
const metadata = (id = 'owned-A', owner = 'account-A', sequence = 0) => ({ id, challengeId: 'ch_public', maxPlayers: 2, createdAt: '2026-10-17T12:00:00Z', playerId: 'bound-' + owner, highestSubmittedSequence: sequence, accessMode: 'core-owned' });
let passed = 0, nextHarnessId = 0;
async function check(name, run) {
  let timer;
  try { await Promise.race([run(), new Promise((_, reject) => { timer = setTimeout(() => reject(Error('Fixture exceeded its 4 s wall-clock deadline: ' + name)), 4000); })]); }
  finally { clearTimeout(timer); }
  passed++; console.log('PASS', name);
}

function harness({ data = new Map(), tab = new Map([[coreKey, 'fixture-token-A']]), href = origin + '/games/remix/', enabled = false, handler, quota = false } = {}) {
  const harnessId = ++nextHarnessId;
  const nodes = new Map(), events = new Map(), timers = new Map(), calls = [];
  let nextTimer = 0, nextUUID = 0, nextMatch = 0, now = Date.UTC(2026, 9, 17, 12);
  const drawing = { clearRect() {}, beginPath() {}, moveTo() {}, lineTo() {}, stroke() {}, fill() {}, arc() {} };
  class Element {
    constructor(key) { this.key = key; this.style = {}; this.dataset = {}; this.attributes = new Map(); this.handlers = new Map(); this.children = []; this.hidden = ['#growth-panel', '#sponsor-slot', '#result-summary', '#result-card-actions', '#retry-match'].includes(key); this.value = ''; this.textContent = ''; this.width = 340; this.height = 150; }
    set innerHTML(value) { this.html = value; this.children = []; }
    get innerHTML() { return this.html || ''; }
    appendChild(child) { this.children.push(child); child.parentElement = this; return child; }
    insertBefore(child) { return this.appendChild(child); }
    querySelector(selector) { return node(selector); }
    querySelectorAll(selector) {
      if (selector === '[data-console-action]') return ['left', 'jump', 'right'].map(action => node('[data-console-action=' + action + ']'));
      if (selector === '[data-owned-match]') { const walk = value => value.children.flatMap(child => [child, ...walk(child)]); return walk(node('#owned-history')).filter(child => child.dataset.ownedMatch); }
      return [];
    }
    setAttribute(key, value) { this.attributes.set(key, String(value)); }
    getAttribute(key) { return this.attributes.get(key) ?? null; }
    addEventListener(name, fn) { this.handlers.set(name, fn); }
    getContext() { return drawing; }
    focus() { this.focused = true; }
  }
  const node = key => { if (!nodes.has(key)) nodes.set(key, new Element(key)); return nodes.get(key); };
  const h = {
    data, tab, node, calls, handler, quota,
    capabilities: { ...capabilities, creationEnabled: enabled },
    accounts: new Map([['fixture-token-A', { id: 'account-A', username: 'alice' }], ['fixture-token-B', { id: 'account-B', username: 'bob' }]]),
    matches: new Map([['owned-A', { ...metadata(), owner: 'account-A' }], ['owned-B', { ...metadata('owned-B', 'account-B'), owner: 'account-B' }]]),
    attempts: new Map(), state: { phase: 'COUNTDOWN', players: 1, remainingMs: 3000, replayFrames: 0 }
  };
  const storage = (map, persistent) => ({ get length() { return map.size; }, key(index) { return [...map.keys()][index] ?? null; }, getItem(key) { return map.get(key) ?? null; }, setItem(key, value) { if (persistent && h.quota) throw Error('quota'); map.set(key, String(value)); }, removeItem(key) { if (persistent && h.quota) throw Error('quota'); map.delete(key); } });
  class TestDate extends Date { constructor(...args) { super(...(args.length ? args : [now])); } static now() { return now; } }
  const publicMetadata = value => { const { owner, ...dto } = value; return dto; };
  const context = {
    console, URL, URLSearchParams, AbortController, Date: TestDate,
    localStorage: storage(data, true), sessionStorage: storage(tab, false),
    location: new URL(href), navigator: { onLine: true }, crypto: { randomUUID: () => 'fixture-' + harnessId + '-operation-' + String(++nextUUID).padStart(8, '0') },
    document: { createElement: key => new Element(key), querySelector: node, documentElement: {}, readyState: 'loading', addEventListener() {} },
    setTimeout(fn, delay = 0) { const id = ++nextTimer; timers.set(id, { fn, delay, at: now + delay }); return id; },
    clearTimeout(id) { timers.delete(id); },
    addEventListener(name, fn) { events.set(name, [...(events.get(name) || []), fn]); },
    fetch: async (url, options = {}) => {
      const parsed = new URL(url, origin);
      const call = { url: parsed.href, path: parsed.pathname, search: parsed.search, method: options.method || 'GET', headers: Object.fromEntries(Object.entries(options.headers || {}).map(([key, value]) => [key.toLowerCase(), value])), body: options.body ? JSON.parse(options.body) : undefined, signal: options.signal, credentials: options.credentials, redirect: options.redirect };
      calls.push(call);
      const perform = async () => {
        if (h.handler) { const result = await h.handler(call, h); if (result !== undefined) return result; }
        if (call.path === '/api/remix/v2/capabilities') return response(h.capabilities);
        const bearer = call.headers.authorization?.replace(/^Bearer /, ''), account = h.accounts.get(bearer);
        if (call.path === '/api/core/auth/me') return account ? response({ user: account }) : response({ error: 'authentication_required' }, 401);
        if (call.path.endsWith('/v1/challenges')) return response({ id: 'ch_public', seed: 20261017 }, 201);
        if (call.path.endsWith('/v1/matches')) return response({ id: 'guest-' + (++nextMatch), challengeId: call.body.challengeId }, 201);
        if (call.path === '/api/v1/player/events') return response({ ok: true }, 201);
        if (call.path.startsWith('/api/remix/v2/')) {
          if (!account) return response({ error: 'authentication_required' }, 401);
          if (call.path === '/api/remix/v2/matches' && call.method === 'POST') {
            if (!h.capabilities.creationEnabled) return response({ error: 'owned_creation_disabled' }, 403);
            const record = { ...metadata('created-' + (++nextMatch), account.id), challengeId: call.body.challengeId, owner: account.id };
            h.matches.set(record.id, record); h.attempts.set(call.headers['idempotency-key'], { status: 'ready', match: publicMetadata(record) });
            return response(publicMetadata(record), 201);
          }
          if (call.path === '/api/remix/v2/matches') return response({ matches: [...h.matches.values()].filter(value => value.owner === account.id).map(publicMetadata), nextCursor: null });
          if (call.path.startsWith('/api/remix/v2/creation-attempts/')) return h.attempts.has(call.path.split('/').at(-1)) ? response(h.attempts.get(call.path.split('/').at(-1))) : response({ error: 'not_found' }, 404);
          const id = call.path.split('/')[5], record = h.matches.get(id);
          if (!record) return response({ error: 'match_unavailable' }, 404);
          if (record.owner !== account.id) return response({ error: 'match_forbidden' }, 403);
          if (call.path === '/api/remix/v2/matches/' + id) return response(publicMetadata(record));
          if (call.path.endsWith('/state')) return response({ id, ...h.state });
          if (call.path.endsWith('/result')) return response({ matchId: id, phase: 'RESULTS', replayFrames: h.state.replayFrames, scores: [{ playerId: record.playerId, score: 1 }] });
          if (call.path.endsWith('/input')) { record.highestSubmittedSequence = Math.max(record.highestSubmittedSequence, call.body.sequence); return response({ playerId: record.playerId, lastSequence: call.body.sequence, position: [1, 0, 0], velocityY: 0, onGround: true, score: 0 }); }
        }
        if (call.path.endsWith('/state')) return response({ id: call.path.split('/').at(-2), ...h.state });
        if (call.path.endsWith('/input')) return response({ playerId: call.body.playerId, lastSequence: call.body.sequence, position: [1, 0, 0] });
        throw Error('Unexpected fixture route: ' + call.method + ' ' + call.path);
      };
      if (!call.signal) return perform();
      return Promise.race([perform(), new Promise((_, reject) => {
        const abort = () => { const error = Error('request aborted'); error.name = 'AbortError'; reject(error); };
        if (call.signal.aborted) abort(); else call.signal.addEventListener('abort', abort, { once: true });
      })]);
    }
  };
  context.history = { replaceState(_state, _unused, url) { context.location = new URL(url, context.location.href); } };
  context.window = context; context.parent = context;
  vm.createContext(context); vm.runInContext(source, context, { filename: 'remix-owned-shipped-controller.js' });
  h.run = code => vm.runInContext(code, context); h.context = context;
  h.flush = async () => { for (let i = 0; i < 100; i++) await Promise.resolve(); };
  h.emit = (name, event = {}) => { for (const fn of events.get(name) || []) fn(event); };
  h.advance = async duration => {
    const target = now + duration;
    for (let guard = 0; guard < 200; guard++) {
      const next = [...timers].filter(([, timer]) => timer.at <= target).sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) break;
      timers.delete(next[0]); now = next[1].at; next[1].fn(); await h.flush();
      if (guard === 199) throw Error('Unbounded fixture timers');
    }
    now = target; await h.flush();
  };
  h.select = async () => { await h.run("selectAccess('core-owned')"); await h.flush(); };
  h.recover = async (id = 'owned-A') => { await h.run('recoverOwnedMatch(' + JSON.stringify(id) + ')'); await h.flush(); };
  h.play = async () => { h.state = { phase: 'PLAYING', players: 1, remainingMs: 30000, replayFrames: 0 }; await h.run('refresh()'); await h.flush(); };
  h.inputs = () => calls.filter(call => call.path.endsWith('/input'));
  h.creates = () => calls.filter(call => call.path === '/api/remix/v2/matches' && call.method === 'POST');
  h.record = () => JSON.parse(data.get(h.run('sessionKey')));
  h.journal = kind => [...data].filter(([key]) => key.startsWith('osgard:remix-' + kind + ':v2:')).map(([key, raw]) => ({ key, value: JSON.parse(raw) }));
  h.seedReservation = (matchId, sequence, accountId = 'account-A') => {
    const value = { version: 2, apiBase: origin + '/api/remix', accountId, matchId, sequence };
    const key = h.run('ownedReservationKey(' + JSON.stringify(value) + ')'); data.set(key, JSON.stringify(value)); return key;
  };
  return h;
}

await check('a Core tab token does not opt a guest or a shared invitation into account access', async () => {
  const h = harness({ data: new Map([['remix-api-url', 'https://custom.example/remix']]), href: origin + '/games/remix/?challenge=ch_invited&lang=en' });
  await h.flush(); assert.equal(h.calls.length, 0); assert.equal(h.run('selectedAccess'), 'guest');
  await h.run('start()'); await h.play(); h.run('send(1,0,false)'); await h.flush();
  assert.ok(h.calls.length >= 3); assert.ok(h.calls.every(call => call.url.startsWith('https://custom.example/remix/v1/')));
  assert.ok(h.calls.every(call => !call.headers.authorization));
  assert.equal(h.record().version, 1); assert.equal(h.record().challengeId, 'ch_invited');
  const id = h.run('match.id'); await h.select(); assert.equal(h.run('match.id'), id); assert.equal(h.run('selectedAccess'), 'guest');
});

await check('foundation capabilities allow read-only account history but disable creation in the actual handler', async () => {
  const h = harness(); await h.select();
  assert.equal(h.run('ownedAccountId'), 'account-A'); assert.equal(h.node('#owned-panel').hidden, false);
  assert.equal(h.node('#start-match').disabled, true); assert.equal(h.node('#api-url').disabled, true);
  assert.equal(h.node('#access-account').getAttribute('aria-pressed'), 'true');
  await h.run('start()'); assert.equal(h.calls.filter(call => call.method === 'POST').length, 0);
  assert.deepEqual(h.calls.map(call => call.path), ['/api/remix/v2/capabilities', '/api/core/auth/me', '/api/remix/v2/matches']);
  assert.equal(h.node('#owned-history').children.length, 1);
});

await check('Core authorization is limited to the fixed auth and v2 service, including an anonymous challenge create', async () => {
  const h = harness({ enabled: true, data: new Map([['remix-api-url', 'https://custom.example/remix'], ['osgard.auth.accessToken', 'fixture-legacy-event-token']]) });
  await h.select(); h.node('#api-url').value = 'https://other.example/'; h.node('#api-url').handlers.get('change')();
  assert.equal(h.node('#api-url').value, '/api/remix'); await h.run('start()'); await h.play();
  h.run("reportEvent('fixture_event',{challengeId:activeChallengeId})"); h.run('send(1,0,false)'); await h.flush();
  assert.equal(h.calls.find(call => call.path.endsWith('/v1/challenges')).headers.authorization, undefined);
  assert.equal(h.calls.find(call => call.path.endsWith('/v2/capabilities')).headers.authorization, undefined);
  for (const call of h.calls.filter(call => call.headers.authorization === 'Bearer fixture-token-A')) {
    assert.equal(new URL(call.url).origin, origin);
    assert.ok(call.path === '/api/core/auth/me' || call.path.startsWith('/api/remix/v2/'));
    assert.equal(call.credentials, 'omit'); assert.equal(call.redirect, 'error');
  }
  assert.equal(h.calls.find(call => call.path === '/api/v1/player/events').headers.authorization, 'Bearer fixture-legacy-event-token');
  assert.ok(![...h.data.values()].join('\n').includes('fixture-token-A'));
  assert.ok(!h.calls.some(call => JSON.stringify(call.body ?? null).includes('fixture-token-A')));
  const before = h.calls.length;
  for (const path of ['/v1/matches/owned-A/input', '/v2/matches/../../other', '//other.example/v2/matches', '/v2/matches?after=x&token=y']) await assert.rejects(h.run('ownedApi(' + JSON.stringify(path) + ')'));
  for (const url of ['https://other.example/api/remix/v2/matches', 'https://user:pass@osgard.world/api/remix/v2/matches', '/api/remix/v1/matches', '/api/v1/player/events', '/api/core/auth/me?token=bad']) await assert.rejects(h.run('ownedJSON(' + JSON.stringify(url) + ",{},ownedIdentity.credential)"));
  assert.equal(h.calls.length, before);
});

await check('sign-in continuation is canonical, whitelisted and performs no automatic POST after return', async () => {
  const h = harness({ tab: new Map(), href: origin + '/games/remix/?challenge=ch_invited&lang=en&api=https://other.example&token=do-not-copy&redirect=//other.example#private' });
  await h.select();
  const login = new URL(h.node('#owned-signin').href, origin), back = login.searchParams.get('returnTo');
  assert.equal(login.pathname, '/workspace'); assert.equal(back, '/games/remix/?challenge=ch_invited&lang=en&mode=account');
  assert.equal(h.run('sessionMode'), 'auth-required'); assert.equal(h.node('#owned-signin').hidden, false);
  const returned = harness({ href: origin + back }); await returned.flush();
  assert.equal(returned.run('selectedAccess'), 'core-owned'); assert.equal(returned.run('ownedAccountId'), 'account-A');
  assert.equal(returned.calls.filter(call => call.method === 'POST').length, 0);
});

await check('unverified, revoked and incompatible accounts cannot create or adopt an owned match', async () => {
  const cases = [
    call => call.path.endsWith('/capabilities') ? response({ ...capabilities, authPolicyVersion: 2, creationEnabled: true }) : undefined,
    call => call.path === '/api/core/auth/me' ? response({ error: 'authentication_required' }, 401) : undefined,
    call => call.path === '/api/core/auth/me' ? response({ user: { id: '../unsafe', username: 'bad' } }) : undefined,
    call => call.path === '/api/core/auth/me' ? response({ error: 'authentication_unavailable' }, 503) : undefined
  ];
  for (const handler of cases) {
    const h = harness({ enabled: true, handler }); await h.select(); await h.run('start()');
    assert.equal(h.run('ownedAuthCurrent()'), false); assert.equal(h.run('match'), null);
    assert.equal(h.calls.filter(call => call.method === 'POST').length, 0); assert.equal(h.node('#start-match').disabled, true);
  }
});

await check('server metadata replaces a forged saved player and restores the highest submitted or locally reserved sequence', async () => {
  const h = harness(); await h.select(); await h.recover();
  const key = h.run('sessionKey'), record = h.record(); h.data.set(key, JSON.stringify({ ...record, playerId: 'forged-player', sequence: 12 }));
  const resumed = harness({ data: h.data, href: origin + '/games/remix/?mode=account' }); resumed.matches.get('owned-A').highestSubmittedSequence = 9; await resumed.flush();
  assert.equal(resumed.run('playerId'), 'bound-account-A'); assert.equal(resumed.run('seq'), 12);
  assert.equal(resumed.run('match.accessMode'), 'core-owned'); assert.ok(resumed.calls.every(call => call.method === 'GET'));
  await resumed.play(); resumed.run('send(1,0,false)'); await resumed.flush();
  assert.deepEqual(resumed.inputs()[0].body, { sequence: 13, moveX: 1, moveY: 0, jump: false });
  assert.equal(resumed.record().sequence, 13); assert.equal(resumed.record().playerId, 'bound-account-A');
  const raised = harness({ data: h.data, href: origin + '/games/remix/?mode=account' }); raised.matches.get('owned-A').highestSubmittedSequence = 20; await raised.flush();
  assert.equal(raised.run('seq'), 20); assert.equal(raised.run('playerId'), 'bound-account-A');
});

await check('changing the actual verified account never reads or rewrites the previous account recovery record', async () => {
  const h = harness(); await h.select(); await h.recover(); await h.play();
  const oldKey = h.run('sessionKey'), oldRecord = h.data.get(oldKey); h.tab.set(coreKey, 'fixture-token-B');
  h.emit('focus'); h.run('send(1,0,false)'); await h.flush();
  assert.equal(h.run('canSubmitInput()'), false); assert.equal(h.run('match.accessMode'), 'core-owned'); assert.equal(h.inputs().length, 0);
  const first = h.calls.length; await h.run('verifyOwnedAccount()');
  assert.equal(h.run('ownedAccountId'), 'account-B'); assert.equal(h.run('match'), null); assert.equal(h.data.get(oldKey), oldRecord);
  assert.ok(!h.calls.slice(first).some(call => call.path.includes('/matches/owned-A')));
  assert.equal(h.node('#owned-history').children[0].children[0].dataset.ownedMatch, 'owned-B');
  await h.recover('owned-B'); assert.notEqual(h.run('sessionKey'), oldKey); assert.equal(h.record().accountId, 'account-B');
  assert.equal(h.data.get(oldKey), oldRecord); assert.ok(!h.calls.some(call => call.path.includes('/v1/matches/owned-')));
});

await check('logout during a late input clears protected output and cannot repaint or downgrade the match', async () => {
  const body = deferred(), h = harness(); await h.select(); await h.recover(); await h.play();
  h.handler = call => call.path.endsWith('/input') ? { ok: true, status: 200, json: () => body.promise } : undefined;
  h.run('send(1,0,false)'); await h.flush(); assert.equal(h.record().sequence, 1);
  h.tab.delete(coreKey); h.emit('storage', { key: coreKey, newValue: null });
  assert.equal(h.inputs()[0].signal.aborted, true); assert.equal(h.run('match.accessMode'), 'core-owned'); assert.equal(h.run('canSubmitInput()'), false);
  body.resolve({ playerId: 'bound-account-A', lastSequence: 1, position: [99, 99, 0] }); await h.flush();
  assert.equal(h.run('serverPosition'), null); assert.equal(h.run('sessionMode'), 'auth-required');
  assert.equal(h.record().accessMode, 'core-owned'); assert.equal(h.record().sequence, 1);
  assert.equal(h.journal('input').length, 1); assert.equal(h.journal('input')[0].value.sequence, 1);
  await h.run('refresh()'); assert.ok(!h.calls.some(call => call.path.includes('/v1/matches/')));
});

await check('401 and Core-unavailable responses pause protected work and clear a previously displayed result', async () => {
  for (const [status, error, mode] of [[401, 'authentication_required', 'auth-required'], [503, 'authentication_unavailable', 'auth-unavailable']]) {
    const h = harness(); await h.select(); await h.recover(); await h.play();
    h.handler = call => call.path.endsWith('/input') ? response({ error }, status) : undefined;
    h.run('send(1,0,false)'); await h.flush();
    assert.equal(h.run('sessionMode'), mode); assert.equal(h.run('ownedAuthCurrent()'), false);
    assert.equal(h.run('match.accessMode'), 'core-owned'); assert.equal(h.run('canSubmitInput()'), false);
    assert.equal(h.record().sequence, 1); await h.advance(60000); assert.equal(h.inputs().length, 1);
  }
  const h = harness(); await h.select(); await h.recover(); h.state.phase = 'RESULTS'; h.state.remainingMs = 0; await h.run('refresh()');
  assert.equal(h.node('#result-card-actions').hidden, false);
  h.handler = call => call.path === '/api/core/auth/me' ? response({ error: 'authentication_unavailable' }, 503) : undefined;
  await h.run('verifyOwnedAccount()'); assert.equal(h.node('#result-card-actions').hidden, true); assert.equal(h.run('lastResultSummary'), '');
  assert.equal(h.run('match.accessMode'), 'core-owned');
});

await check('an uncertain input is consumed before POST, never replayed and resynchronizes from submitted high-water', async () => {
  const h = harness(); await h.select(); await h.recover(); await h.play();
  h.handler = call => { if (call.path.endsWith('/input')) { assert.equal(h.record().sequence, 1); h.matches.get('owned-A').highestSubmittedSequence = 7; return response({ error: 'upstream_write_uncertain' }, 503); } };
  h.run('send(1,0,false)'); await h.flush(); assert.equal(h.run('ownedMetadataRequired'), true); assert.equal(h.run('sessionMode'), 'reconnecting');
  const before = h.calls.length; await h.advance(250);
  assert.deepEqual(h.calls.slice(before).map(call => call.path), ['/api/remix/v2/matches/owned-A', '/api/remix/v2/matches/owned-A/state']);
  assert.equal(h.run('seq'), 7); assert.equal(h.inputs().length, 1); assert.equal(h.run('serverPosition'), null);
  h.handler = undefined; h.run('send(-1,0,false)'); await h.flush();
  assert.deepEqual(h.inputs().map(call => call.body.sequence), [1, 8]);
});

await check('held input remains one in-flight request and one new coalesced intent in account mode', async () => {
  const wait = deferred(), h = harness(); await h.select(); await h.recover(); await h.play();
  h.handler = call => call.path.endsWith('/input') ? wait.promise : undefined;
  h.run('send(1,0,false)'); await h.flush(); for (let i = 0; i < 100; i++) h.run('send(-1,0,false)');
  assert.equal(h.inputs().length, 1); assert.equal(h.record().sequence, 1);
  wait.resolve(response({ playerId: 'bound-account-A', lastSequence: 1, position: [1, 0, 0] })); await h.flush();
  h.handler = undefined; await h.advance(100); assert.equal(h.inputs().length, 2);
  assert.deepEqual(h.inputs().map(call => call.body.sequence), [1, 2]); assert.equal(h.inputs()[1].body.moveX, -1);
});

await check('creation writes its exact idempotency intent before the single POST and ignores double start', async () => {
  const wait = deferred(), h = harness({ enabled: true }); let journalAtPost; await h.select();
  h.handler = call => { if (call.path === '/api/remix/v2/matches' && call.method === 'POST') {
    journalAtPost = h.journal('creation');
    const stored = h.record(); assert.equal(stored.stage, 'creating'); assert.equal(stored.operationKey, call.headers['idempotency-key']);
    assert.equal(stored.accountId, 'account-A'); assert.equal(stored.matchId, null); assert.equal(stored.challengeId, call.body.challengeId);
    assert.deepEqual(call.body, { challengeId: 'ch_public', maxPlayers: 2 }); return wait.promise;
  } };
  const first = h.run('start()'); await h.flush(); await h.run('start()'); assert.equal(h.creates().length, 1);
  assert.equal(journalAtPost.length, 1); assert.equal(journalAtPost[0].value.operationKey, h.creates()[0].headers['idempotency-key']);
  assert.equal(journalAtPost[0].value.stage, 'creating'); assert.equal(journalAtPost[0].value.scope, 'daily:2026-10-17');
  wait.resolve(response(metadata(), 201)); await first;
  assert.equal(h.record().stage, 'active'); assert.equal(h.run('playerId'), 'bound-account-A');
  assert.equal(h.journal('creation').length, 0);
  await h.run('start()'); assert.equal(h.creates().length, 1);
});

await check('lost creation is recovered with a GET of the same operation, never a repeated POST', async () => {
  const h = harness({ enabled: true }); await h.select();
  h.handler = call => { if (call.path === '/api/remix/v2/matches' && call.method === 'POST') { h.attempts.set(call.headers['idempotency-key'], { status: 'ready', match: metadata() }); throw TypeError('response lost'); } };
  await h.run('start()'); assert.equal(h.creates().length, 1); assert.equal(h.run('match.id'), 'owned-A');
  assert.equal(h.calls.filter(call => call.path.endsWith('/creation-attempts/' + h.record().operationKey)).length, 1);
  assert.ok(h.calls.filter(call => call.path.includes('/creation-attempts/')).every(call => call.method === 'GET'));
  assert.match(h.node('#match-status').textContent, /preparing|running/); assert.equal(h.record().accessMode, 'core-owned');
});

await check('malformed, lost or unknown creation stays on one key across reload and explicit checks', async () => {
  for (const failure of ['malformed', 'lost']) {
    const h = harness({ enabled: true }); await h.select();
    h.handler = call => { if (call.path === '/api/remix/v2/matches' && call.method === 'POST') { if (failure === 'lost') throw TypeError('lost'); return response({ id: 'unbound-orphan' }, 201); } };
    await h.run('start()'); const record = h.record(), key = record.operationKey;
    assert.equal(record.stage, 'uncertain'); assert.equal(h.run('match'), null); assert.equal(h.node('#start-match').disabled, true);
    await h.run('start()'); await h.advance(60000); assert.equal(h.creates().length, 1);
    const resumed = harness({ data: h.data, enabled: true, href: origin + '/games/remix/?mode=account' }); await resumed.flush();
    assert.equal(resumed.creates().length, 0); assert.equal(resumed.record().operationKey, key); assert.equal(resumed.run('match'), null);
    await resumed.run('recoverOwnedCreation()'); await resumed.run('start()');
    assert.equal(resumed.creates().length, 0); assert.equal(resumed.record().operationKey, key);
    assert.ok(resumed.calls.filter(call => call.path.includes('/creation-attempts/')).every(call => call.path.endsWith('/' + key) && call.method === 'GET'));
  }
});

await check('a completed creation remains recoverable after reload when its original operation key is retained', async () => {
  const h = harness({ enabled: true }); await h.select(); await h.run('start()');
  const record = h.record(); assert.ok(record.operationKey); assert.equal(record.stage, 'active');
  const resumed = harness({ data: h.data, href: origin + '/games/remix/?mode=account' });
  resumed.matches.set(record.matchId, { ...metadata(record.matchId), owner: 'account-A' }); await resumed.flush();
  assert.equal(resumed.run('match.id'), record.matchId); assert.equal(resumed.run('playerId'), 'bound-account-A');
  assert.equal(resumed.record().operationKey, record.operationKey); assert.equal(resumed.creates().length, 0);
  assert.equal(resumed.calls.filter(call => call.path.includes('/creation-attempts/')).length, 0);
});

await check('a fetch or JSON-body deadline preserves pending creation and rejects any late completion', async () => {
  for (const stage of ['fetch', 'body']) {
    const late = deferred(), h = harness({ enabled: true }); await h.select();
    h.handler = call => call.path === '/api/remix/v2/matches' && call.method === 'POST' ? stage === 'fetch' ? late.promise : { ok: true, status: 201, json: () => late.promise } : undefined;
    const start = h.run('start()'); await h.flush(); await h.advance(11999);
    assert.equal(h.run('opening'), true); assert.equal(h.creates().length, 1);
    await h.advance(1); await start; assert.equal(h.run('opening'), false); assert.equal(h.run('sessionMode'), 'creation-uncertain');
    const key = h.record().operationKey; late.resolve(stage === 'fetch' ? response(metadata(), 201) : metadata()); await h.flush();
    assert.equal(h.run('match'), null); assert.equal(h.record().operationKey, key); assert.equal(h.creates().length, 1);
    assert.equal(h.creates()[0].signal.aborted, true);
  }
});

await check('an offline edge cancels creation and the next connection performs GET-only recovery', async () => {
  const late = deferred(), h = harness({ enabled: true }); await h.select();
  h.handler = call => call.path === '/api/remix/v2/matches' && call.method === 'POST' ? { ok: true, status: 201, json: () => late.promise } : undefined;
  const start = h.run('start()'); await h.flush(); const key = h.record().operationKey;
  h.context.navigator.onLine = false; h.emit('offline'); assert.equal(h.record().stage, 'uncertain');
  late.resolve(metadata()); await start; assert.equal(h.run('match'), null);
  h.handler = undefined; h.attempts.set(key, { status: 'ready', match: metadata() }); h.context.navigator.onLine = true; h.emit('online'); await h.flush();
  assert.equal(h.run('match.id'), 'owned-A'); assert.equal(h.creates().length, 1); assert.equal(h.record().operationKey, key);
});

await check('persistent-storage failure stops account creation before any owned POST', async () => {
  for (const href of [origin + '/games/remix/', origin + '/games/remix/?challenge=ch_public']) {
    const h = harness({ enabled: true, quota: true, href }); await h.select(); await h.run('start()');
    assert.equal(h.creates().length, 0); assert.equal(h.run('match'), null); assert.equal(h.run('sessionMode'), 'creation-rejected');
    assert.match(h.node('#match-status').textContent, /saved recovery metadata|recovery storage is unavailable/); assert.equal(h.run('remixStore.ephemeral'), true);
  }
});

await check('owned history is bounded to a single page per action and does not admit cross-account IDs', async () => {
  const page = Array.from({ length: 50 }, (_, i) => metadata('owned-page-' + String(i).padStart(2, '0'))), next = deferred();
  const h = harness({ handler: call => call.path === '/api/remix/v2/matches' && call.method === 'GET' ? call.search ? next.promise : response({ matches: page, nextCursor: 'owned-page-49' }) : undefined });
  await h.select(); assert.equal(h.node('#owned-history').children.length, 50); assert.equal(h.calls.filter(call => call.path === '/api/remix/v2/matches').length, 1);
  const first = h.run('loadOwnedHistory(true)'); await h.flush(); await h.run('loadOwnedHistory(true)');
  assert.equal(h.calls.filter(call => call.path === '/api/remix/v2/matches').length, 2); assert.equal(h.calls.at(-1).search, '?after=owned-page-49');
  next.resolve(response({ matches: [metadata('owned-last')], nextCursor: null })); await first;
  assert.equal(h.node('#owned-history').children.length, 1); assert.equal(h.node('#owned-history-next').hidden, true);
  h.handler = undefined; await h.recover('owned-B'); assert.equal(h.run('sessionMode'), 'access-denied');
  assert.equal(h.run('match.accessMode'), 'core-owned'); assert.equal(h.run('canSubmitInput()'), false);
  assert.ok(!h.calls.some(call => call.path.includes('/v1/matches/')));
});

await check('missing simulation retains its protected record without polling forever or offering guest fallback', async () => {
  const h = harness(); await h.select();
  h.handler = call => call.path.endsWith('/state') ? response({ error: 'match_unavailable' }, 404) : undefined;
  await h.recover(); assert.equal(h.run('sessionMode'), 'unavailable'); assert.equal(h.run('match.accessMode'), 'core-owned');
  assert.equal(h.record().matchId, 'owned-A'); assert.match(h.node('#match-status').textContent, /cannot recover a lost simulation/);
  const count = h.calls.length; await h.advance(60000); assert.equal(h.calls.length, count); assert.equal(h.run('canSubmitInput()'), false);
});

await check('an explicit guest switch preserves the owned record and restores only a separate guest session', async () => {
  const h = harness(); await h.select(); await h.recover(); const key = h.run('sessionKey'), saved = h.data.get(key);
  h.tab.delete(coreKey); h.emit('focus'); await h.run("selectAccess('guest')");
  assert.equal(h.run('selectedAccess'), 'guest'); assert.equal(h.run('match'), null); assert.equal(h.data.get(key), saved);
  await h.run('start()'); assert.equal(h.record().version, 1); assert.equal(h.data.get(key), saved);
  assert.ok(h.calls.filter(call => call.path.includes('/v1/matches')).every(call => !call.headers.authorization && !call.path.includes('owned-A')));
});

await check('an unresolved creation cannot be overwritten by choosing another historical match', async () => {
  const h = harness({ enabled: true }); await h.select();
  h.handler = call => call.path === '/api/remix/v2/matches' && call.method === 'POST' ? response({ error: 'creation_uncertain' }, 503) : undefined;
  await h.run('start()'); const key = h.record().operationKey, stored = h.data.get(h.run('sessionKey')), count = h.calls.length;
  assert.equal(h.node('#owned-history').children[0].children[0].disabled, true);
  await h.recover(); assert.equal(h.calls.length, count); assert.equal(h.run('match'), null); assert.equal(h.record().operationKey, key);
  assert.equal(h.data.get(h.run('sessionKey')), stored);
  h.handler = undefined; await h.run("selectAccess('guest')"); assert.equal(h.run('selectedAccess'), 'guest');
  await h.select(); assert.equal(h.run('match'), null); assert.equal(h.record().operationKey, key); assert.equal(h.creates().length, 1);
});

await check('a confirmed rejected attempt permits only an explicit new action with a fresh key', async () => {
  const h = harness({ enabled: true }); await h.select();
  h.handler = call => { if (call.path === '/api/remix/v2/matches' && call.method === 'POST') { h.attempts.set(call.headers['idempotency-key'], { status: 'rejected', operationKey: call.headers['idempotency-key'] }); return response({ error: 'creation_uncertain' }, 503); } };
  await h.run('start()'); const firstKey = h.record().operationKey;
  assert.equal(h.record().stage, 'rejected'); assert.equal(h.creates().length, 1); assert.equal(h.node('#start-match').disabled, false);
  h.context.navigator.onLine = false; h.emit('offline'); assert.equal(h.record().stage, 'rejected'); assert.equal(h.run('ownedAttemptStatus'), 'rejected');
  h.context.navigator.onLine = true; h.emit('online'); await h.flush(); assert.equal(h.record().stage, 'rejected'); assert.equal(h.creates().length, 1);
  h.handler = undefined; await h.run('start()'); assert.equal(h.creates().length, 2); assert.notEqual(h.creates()[1].headers['idempotency-key'], firstKey);
});

await check('a server-disabled create cannot be retried or converted into a permanently uncertain attempt by going offline', async () => {
  const h = harness({ enabled: true }); await h.select();
  h.handler = call => call.path === '/api/remix/v2/matches' && call.method === 'POST' ? response({ error: 'owned_creation_disabled' }, 403) : undefined;
  await h.run('start()'); assert.equal(h.record().stage, 'rejected'); assert.equal(h.node('#start-match').disabled, true);
  h.context.navigator.onLine = false; h.emit('offline'); assert.equal(h.run('ownedAttemptStatus'), 'rejected'); assert.equal(h.record().stage, 'rejected');
  assert.equal(h.run('sessionMode'), 'creation-rejected'); await h.run('start()'); assert.equal(h.creates().length, 1);
  const resumed = harness({ data: h.data, enabled: true, href: origin + '/games/remix/?mode=account' }); await resumed.flush();
  assert.equal(resumed.run('ownedAttemptStatus'), 'rejected'); assert.equal(resumed.record().stage, 'rejected');
  assert.equal(resumed.creates().length, 0); assert.equal(resumed.calls.filter(call => call.path.includes('/creation-attempts/')).length, 0);
  assert.equal(resumed.node('#owned-recover-attempt').hidden, true); assert.equal(resumed.node('#start-match').disabled, false);
});

await check('another tab reservation survives account reverification instead of being replaced by a stale memory record', async () => {
  const h = harness(); await h.select(); await h.recover();
  const key = h.run('sessionKey'), advanced = { ...h.record(), sequence: 32 };
  h.data.set(key, JSON.stringify(advanced)); h.emit('storage', { key, newValue: JSON.stringify(advanced) });
  assert.equal(h.run('seq'), 32); await h.run('verifyOwnedAccount()');
  assert.equal(h.run('seq'), 32); assert.equal(h.record().sequence, 32);
  await h.play(); h.run('send(1,0,false)'); await h.flush(); assert.equal(h.inputs()[0].body.sequence, 33);
});

await check('leaving during a held metadata lookup preserves the last valid owned match and reserved sequence', async () => {
  const first = harness(); await first.select(); await first.recover(); first.run('seq=9;rememberSession()');
  const key = first.run('sessionKey'), saved = first.data.get(key), pending = deferred();
  const resumed = harness({ data: first.data, href: origin + '/games/remix/?mode=account', handler: call => call.path === '/api/remix/v2/matches/owned-A' ? pending.promise : undefined });
  await resumed.flush(); assert.equal(resumed.run('playerId'), ''); assert.equal(resumed.run('seq'), 0);
  resumed.emit('pagehide'); await resumed.flush(); assert.equal(first.data.get(key), saved);
  pending.resolve(response(metadata())); await resumed.flush(); assert.equal(first.data.get(key), saved);
  const restored = harness({ data: first.data, href: origin + '/games/remix/?mode=account' }); await restored.flush();
  assert.equal(restored.run('match.id'), 'owned-A'); assert.equal(restored.run('playerId'), 'bound-account-A'); assert.equal(restored.run('seq'), 9);
  assert.equal(restored.creates().length, 0);
});

await check('failed metadata followed by an explicit guest switch cannot persist an unresolved owned placeholder', async () => {
  const first = harness(); await first.select(); await first.recover(); first.run('seq=11;rememberSession()');
  const key = first.run('sessionKey'), saved = first.data.get(key);
  const resumed = harness({ data: first.data, href: origin + '/games/remix/?mode=account', handler: call => call.path === '/api/remix/v2/matches/owned-A' ? response({ error: 'match_unavailable' }, 404) : undefined });
  await resumed.flush(); assert.equal(resumed.run('sessionMode'), 'unavailable'); assert.equal(resumed.run('playerId'), '');
  await resumed.run("selectAccess('guest')"); assert.equal(resumed.run('selectedAccess'), 'guest'); assert.equal(first.data.get(key), saved);
  const restored = harness({ data: first.data, href: origin + '/games/remix/?mode=account' }); await restored.flush();
  assert.equal(restored.run('match.id'), 'owned-A'); assert.equal(restored.run('seq'), 11); assert.equal(restored.record().playerId, 'bound-account-A');
});

await check('an account change during creation preserves the original pending intent for its actual owner', async () => {
  const body = deferred(), h = harness({ enabled: true }); await h.select();
  h.handler = call => call.path === '/api/remix/v2/matches' && call.method === 'POST' ? { ok: true, status: 201, json: () => body.promise } : undefined;
  const create = h.run('start()'); await h.flush(); const key = h.run('sessionKey'), record = h.record();
  const journal = h.journal('creation')[0];
  h.tab.set(coreKey, 'fixture-token-B'); h.emit('storage', { key: coreKey, newValue: 'fixture-token-B' });
  body.resolve(metadata()); await create; assert.equal(h.run('match'), null);
  h.handler = undefined; await h.run('verifyOwnedAccount()'); assert.equal(h.run('ownedAccountId'), 'account-B'); assert.equal(h.run('match'), null);
  assert.equal(h.data.get(key), JSON.stringify(record)); assert.equal(h.creates().length, 1);
  assert.equal(h.data.get(journal.key), JSON.stringify(journal.value));
  h.attempts.set(record.operationKey, { status: 'ready', match: metadata() }); h.tab.set(coreKey, 'fixture-token-A'); h.emit('focus');
  await h.run('verifyOwnedAccount()'); assert.equal(h.run('match.id'), 'owned-A'); assert.equal(h.run('ownedAccountId'), 'account-A');
  assert.equal(h.creates().length, 1); assert.equal(h.record().operationKey, record.operationKey);
  assert.equal(h.data.has(journal.key), false);
});

await check('blocked Core tab storage fails closed while keeping the independent guest mode usable', async () => {
  const h = harness({ enabled: true }); h.context.sessionStorage.getItem = () => { throw Error('storage denied'); };
  await h.select(); assert.equal(h.run('sessionMode'), 'auth-required'); assert.equal(h.run('ownedAuthCurrent()'), false);
  await h.run('start()'); assert.equal(h.creates().length, 0); assert.equal(h.calls.filter(call => call.headers.authorization).length, 0);
  await h.run("selectAccess('guest')"); await h.run('start()'); assert.ok(h.run('match.id').startsWith('guest-')); assert.equal(h.record().version, 1);
});

await check('wrong-account, wrong-API, malformed and expired records never authorize a recovery request', async () => {
  const first = harness(); await first.select(); await first.recover(); const key = first.run('sessionKey'), record = first.record();
  const invalid = ['{bad', JSON.stringify({ ...record, version: 1 }), JSON.stringify({ ...record, accountId: 'account-B' }), JSON.stringify({ ...record, apiBase: 'https://other.example/api/remix' }), JSON.stringify({ ...record, scope: 'challenge:other' }), JSON.stringify({ ...record, sequence: -1 }), JSON.stringify({ ...record, savedAt: 0 }), JSON.stringify({ ...record, matchId: '../../other' })];
  for (const raw of invalid) {
    const h = harness({ data: new Map([[key, raw]]), href: origin + '/games/remix/?mode=account' }); await h.flush();
    assert.equal(h.run('ownedAccountId'), 'account-A'); assert.equal(h.run('match'), null);
    assert.ok(!h.calls.some(call => call.path.includes('/matches/') || call.method === 'POST'));
  }
});

await check('a stale account lookup and a tab-storage clear cannot authorize later protected input', async () => {
  const body = deferred(), h = harness({ handler: call => call.path === '/api/core/auth/me' ? { ok: true, status: 200, json: () => body.promise } : undefined });
  const selecting = h.select(); await h.flush(); h.tab.set(coreKey, 'fixture-token-B');
  body.resolve({ user: { id: 'account-A', username: 'alice' } }); await selecting;
  assert.equal(h.run('ownedAuthCurrent()'), false); assert.equal(h.run('ownedAccountId'), '');
  assert.ok(!h.calls.some(call => call.path === '/api/remix/v2/matches'));
  h.handler = undefined; await h.run('verifyOwnedAccount()'); await h.recover('owned-B'); await h.play();
  h.tab.clear(); h.emit('storage', { key: null, newValue: null }); assert.equal(h.run('sessionMode'), 'auth-required');
  h.run('send(1,0,false)'); await h.flush(); assert.equal(h.inputs().length, 0); assert.equal(h.run('match.accessMode'), 'core-owned');
});

await check('malformed or oversized history pages are rejected without creating recovery controls', async () => {
  for (const page of [{ matches: Array.from({ length: 51 }, (_, i) => metadata('row-' + i)), nextCursor: null }, { matches: [metadata(), metadata()], nextCursor: null }, { matches: [metadata()], nextCursor: '../../other' }]) {
    const h = harness({ handler: call => call.path === '/api/remix/v2/matches' ? response(page) : undefined }); await h.select();
    assert.equal(h.node('#owned-history').children.length, 0); assert.equal(h.node('#owned-history-next').hidden, true); assert.equal(h.run('match'), null);
    assert.equal(h.calls.filter(call => call.path === '/api/remix/v2/matches').length, 1);
  }
});

await check('a normal background refresh reads a newer same-match reservation even before any storage event', async () => {
  const h = harness(); await h.select(); await h.recover();
  const key = h.run('sessionKey'); h.data.set(key, JSON.stringify({ ...h.record(), sequence: 32 }));
  assert.equal(h.run('seq'), 0); await h.run('refresh()');
  assert.equal(h.record().sequence, 32); assert.equal(h.run('seq'), 32);
  await h.play(); h.run('send(1,0,false)'); await h.flush(); assert.equal(h.inputs()[0].body.sequence, 33);
});

await check('an old tab cannot erase a pending creation, and its journal survives a stale non-atomic pointer write', async () => {
  const old = harness({ enabled: true }); await old.select(); old.state.phase = 'RESULTS'; await old.recover();
  assert.equal(old.run('sessionMode'), 'completed'); const primaryKey = old.run('sessionKey'), previous = old.data.get(primaryKey);
  const wait = deferred(), next = harness({ data: old.data, enabled: true, href: origin + '/games/remix/?mode=account' });
  next.state.phase = 'RESULTS'; await next.flush();
  next.handler = call => call.path === '/api/remix/v2/matches' && call.method === 'POST' ? wait.promise : undefined;
  const creating = next.run('start()'); await next.flush();
  const operationKey = next.record().operationKey, intent = next.data.get(primaryKey), journal = next.journal('creation')[0];
  assert.equal(next.creates().length, 1); old.emit('pagehide'); assert.equal(next.data.get(primaryKey), intent);
  // localStorage has no compare-and-swap: model an already-read stale value
  // winning the convenience-pointer write. The immutable intent must still win recovery.
  next.data.set(primaryKey, previous); next.emit('pagehide'); await creating;
  assert.equal(next.data.get(journal.key), JSON.stringify(journal.value));
  const restored = harness({ data: next.data, enabled: true, href: origin + '/games/remix/?mode=account' }); await restored.flush();
  assert.equal(restored.run('match'), null); assert.equal(restored.run('ownedOperationKey'), operationKey);
  assert.equal(restored.calls.filter(call => call.path.endsWith('/creation-attempts/' + operationKey)).length, 1);
  await restored.run('start()'); await restored.recover();
  assert.equal(restored.creates().length, 0); assert.equal(restored.run('match'), null);
  assert.equal(restored.data.get(journal.key), JSON.stringify(journal.value));
});

await check('an uncertain input survives a stale pointer and only authoritative acknowledgement removes its reservation', async () => {
  const h = harness(); await h.select(); await h.recover(); await h.play();
  h.handler = call => call.path.endsWith('/input') ? response({ error: 'upstream_write_uncertain' }, 503) : undefined;
  h.run('send(1,0,false)'); await h.flush(); assert.equal(h.journal('input')[0].value.sequence, 1);
  const primaryKey = h.run('sessionKey'), stale = { ...h.record(), sequence: 0 }; h.emit('pagehide'); h.data.set(primaryKey, JSON.stringify(stale));
  const restored = harness({ data: h.data, href: origin + '/games/remix/?mode=account' }); await restored.flush();
  assert.equal(restored.run('seq'), 1); assert.equal(restored.journal('input').length, 1);
  await restored.play(); restored.run('send(1,0,false)'); await restored.flush();
  assert.equal(restored.inputs()[0].body.sequence, 2); assert.equal(restored.record().sequence, 2);
  assert.equal(restored.journal('input').length, 0);
});

await check('a ready creation keeps its journal when only the durable active pointer fails and reload recovers by GET', async () => {
  const h = harness({ enabled: true }); await h.select();
  const setItem = h.context.localStorage.setItem;
  h.handler = call => { if (call.path === '/api/remix/v2/matches' && call.method === 'POST') {
    h.attempts.set(call.headers['idempotency-key'], { status: 'ready', match: metadata() });
    h.context.localStorage.setItem = (key, value) => { if (key.startsWith('osgard:remix-session:v2:')) throw Error('active pointer quota'); setItem(key, value); };
    return response(metadata(), 201);
  } };
  await h.run('start()'); assert.equal(h.run('match.id'), 'owned-A');
  const journal = h.journal('creation')[0]; assert.ok(journal); assert.equal(h.record().stage, 'creating');
  assert.equal(h.data.get(journal.key), JSON.stringify(journal.value)); h.emit('pagehide');
  const restored = harness({ data: h.data, href: origin + '/games/remix/?challenge=another-public&mode=account' }); restored.attempts = h.attempts; await restored.flush();
  assert.equal(restored.run('match.id'), 'owned-A'); assert.equal(restored.record().stage, 'active');
  assert.equal(restored.record().scope, 'challenge:another-public'); assert.equal(restored.journal('creation').length, 0);
  assert.equal(restored.calls.filter(call => call.path.endsWith('/creation-attempts/' + journal.value.operationKey)).length, 1);
  assert.equal(restored.creates().length, 0);
});

await check('unresolved creation journals retain their original scope and age and are discovered only for their actual account and API', async () => {
  const first = harness({ enabled: true }); await first.select();
  first.handler = call => call.path === '/api/remix/v2/matches' && call.method === 'POST' ? response({ error: 'creation_uncertain' }, 503) : undefined;
  await first.run('start()'); const journal = first.journal('creation')[0]; first.emit('pagehide');
  const aged = { ...journal.value, savedAt: Date.UTC(2026, 8, 1) }; first.data.set(journal.key, JSON.stringify(aged)); first.data.delete(first.run('sessionKey'));
  const otherApiKey = journal.key.replace(encodeURIComponent(origin + '/api/remix'), encodeURIComponent('https://other.example/api/remix'));
  first.data.set(otherApiKey, 'unrelated storage is not parsed');
  const other = harness({ data: first.data, tab: new Map([[coreKey, 'fixture-token-B']]), href: origin + '/games/remix/?mode=account' }); await other.flush();
  assert.equal(other.run('ownedAccountId'), 'account-B'); assert.equal(other.run('match'), null);
  assert.equal(other.calls.filter(call => call.path.includes('/creation-attempts/')).length, 0);
  const restored = harness({ data: first.data, enabled: true, href: origin + '/games/remix/?challenge=invited-later&mode=account' }); await restored.flush();
  assert.equal(restored.run('ownedOperationKey'), aged.operationKey); assert.equal(restored.run('activeChallengeId'), 'ch_public');
  assert.equal(restored.data.get(journal.key), JSON.stringify(aged)); assert.equal(restored.data.get(otherApiKey), 'unrelated storage is not parsed');
  assert.equal(restored.creates().length, 0); assert.equal(restored.calls.filter(call => call.path.endsWith('/creation-attempts/' + aged.operationKey)).length, 1);
});

await check('input reservations follow the actual match across route scopes and ACK or metadata never prunes another match or account', async () => {
  const first = harness(); await first.select(); await first.recover(); await first.play();
  first.handler = call => call.path.endsWith('/input') ? response({ error: 'upstream_write_uncertain' }, 503) : undefined;
  first.run('send(1,0,false)'); await first.flush(); first.emit('pagehide');
  const otherMatchKey = first.seedReservation('other-match', 1), otherAccountKey = first.seedReservation('owned-B', 1, 'account-B');
  const protectedRecords = [otherMatchKey, otherAccountKey].map(key => first.data.get(key));
  const restored = harness({ data: first.data, href: origin + '/games/remix/?challenge=invited-later&mode=account' }); await restored.flush(); await restored.recover();
  assert.equal(restored.run('seq'), 1); await restored.play(); restored.run('send(1,0,false)'); await restored.flush();
  assert.equal(restored.inputs()[0].body.sequence, 2);
  assert.deepEqual([otherMatchKey, otherAccountKey].map(key => restored.data.get(key)), protectedRecords);
  const low = restored.seedReservation('owned-A', 5), high = restored.seedReservation('owned-A', 9);
  restored.matches.get('owned-A').highestSubmittedSequence = 5; await restored.run('verifyOwnedAccount()');
  assert.equal(restored.data.has(low), false); assert.equal(restored.data.has(high), true); assert.equal(restored.run('seq'), 9);
  assert.deepEqual([otherMatchKey, otherAccountKey].map(key => restored.data.get(key)), protectedRecords);
});

await check('journal scanning, matching-record reads and malformed entries fail closed without erasing recovery data', async () => {
  for (const failure of ['length', 'key', 'journal-read', 'primary-read', 'malformed']) {
    const h = harness({ enabled: true, href: origin + '/games/remix/?challenge=ch_public' }); await h.select();
    const reservation = h.seedReservation('owned-A', 7), primaryKey = h.run('sessionKey'), getItem = h.context.localStorage.getItem;
    if (failure === 'length') Object.defineProperty(h.context.localStorage, 'length', { get() { throw Error('scan denied'); } });
    if (failure === 'key') h.context.localStorage.key = () => { throw Error('scan denied'); };
    if (failure === 'journal-read' || failure === 'primary-read') h.context.localStorage.getItem = key => { if (key === (failure === 'journal-read' ? reservation : primaryKey)) throw Error('read denied'); return getItem(key); };
    if (failure === 'malformed') h.data.set(reservation, '{invalid-json');
    const before = [...h.data]; h.run('syncControls()'); await h.run('start()');
    assert.equal(h.node('#start-match').disabled, true, failure); assert.equal(h.creates().length, 0, failure);
    assert.deepEqual([...h.data], before, failure); assert.equal(h.run('match'), null, failure);
  }
  const active = harness(); await active.select(); await active.recover(); await active.play();
  const key = active.run('sessionKey'), getItem = active.context.localStorage.getItem;
  active.context.localStorage.getItem = name => { if (name === key) throw Error('saved highwater unreadable'); return getItem(name); };
  active.run('send(1,0,false)'); await active.flush();
  assert.equal(active.inputs().length, 0); assert.equal(active.run('canSubmitInput()'), false);
  assert.match(active.node('#match-status').textContent, /recovery storage is unavailable/);
});

await check('journal write failure never posts a creation or input and never exposes the server-rejected challenge action', async () => {
  const creation = harness({ enabled: true, href: origin + '/games/remix/?challenge=ch_public' }); await creation.select();
  const createSet = creation.context.localStorage.setItem;
  creation.context.localStorage.setItem = (key, value) => { if (key.startsWith('osgard:remix-creation:v2:')) throw Error('journal quota'); createSet(key, value); };
  await creation.run('start()'); assert.equal(creation.creates().length, 0); assert.equal(creation.journal('creation').length, 0);
  assert.equal(creation.run('ownedOperationKey'), ''); assert.equal(creation.node('#owned-new-challenge').hidden, true);
  const input = harness(); await input.select(); await input.recover(); await input.play();
  const inputSet = input.context.localStorage.setItem;
  input.context.localStorage.setItem = (key, value) => { if (key.startsWith('osgard:remix-input:v2:')) throw Error('journal quota'); inputSet(key, value); };
  input.run('send(1,0,false)'); await input.flush(); assert.equal(input.inputs().length, 0);
  assert.equal(input.run('canSubmitInput()'), false); assert.equal(input.journal('input').length, 0);
  assert.match(input.node('#match-status').textContent, /recovery storage is unavailable/);
});

await check('the 32-entry limits pause new writes without eviction and free only server-covered or rejected entries', async () => {
  const h = harness({ enabled: true }); await h.select(); await h.recover(); await h.play();
  for (let sequence = 1; sequence <= 32; sequence++) h.seedReservation('owned-A', sequence);
  const entries = h.journal('input').map(entry => [entry.key, h.data.get(entry.key)]);
  h.run('send(1,0,false)'); await h.flush(); assert.equal(h.inputs().length, 0); assert.equal(h.run('canSubmitInput()'), false);
  assert.deepEqual(h.journal('input').map(entry => [entry.key, h.data.get(entry.key)]), entries);
  assert.match(h.node('#match-status').textContent, /recovery is full/); assert.equal(h.run('canCreateOwned()'), false);
  h.matches.get('owned-A').highestSubmittedSequence = 32; await h.run('refresh()');
  assert.equal(h.journal('input').length, 0); assert.equal(h.run('canSubmitInput()'), true);
  h.run('send(1,0,false)'); await h.flush(); assert.ok(h.inputs()[0].body.sequence > 32);
  const creation = harness({ enabled: true }); await creation.select();
  creation.handler = call => call.path === '/api/remix/v2/matches' && call.method === 'POST' ? response({ error: 'creation_uncertain' }, 503) : undefined;
  await creation.run('start()'); const original = creation.journal('creation')[0];
  for (let index = 1; index < 32; index++) {
    const value = { ...original.value, operationKey: 'fixture-pending-' + String(index).padStart(8, '0') };
    creation.data.set(creation.run('ownedCreationKey(' + JSON.stringify(value) + ')'), JSON.stringify(value));
  }
  const before = creation.journal('creation').map(entry => [entry.key, creation.data.get(entry.key)]);
  await creation.run('start()'); assert.equal(creation.creates().length, 1); assert.equal(creation.journal('creation').length, 32);
  assert.throws(() => creation.run('persistOwnedCreation()'), error => error.code === 'owned_recovery_full');
  assert.deepEqual(creation.journal('creation').map(entry => [entry.key, creation.data.get(entry.key)]), before);
  creation.attempts.set(original.value.operationKey, { status: 'rejected', operationKey: original.value.operationKey });
  await creation.run('recoverOwnedCreation()'); assert.equal(creation.journal('creation').length, 31);
  assert.equal(creation.data.has(original.key), false); assert.equal(creation.run('canCreateOwned()'), false);
  await creation.recover(); assert.equal(creation.run('match'), null);
});

await check('a journal reservation at the sequence ceiling pauses input without writing an invalid successor', async () => {
  const h = harness(); await h.select(); await h.recover(); await h.play();
  const key = h.seedReservation('owned-A', Number.MAX_SAFE_INTEGER - 1), stored = h.data.get(key);
  h.run('send(1,0,false)'); await h.flush();
  assert.equal(h.inputs().length, 0); assert.equal(h.journal('input').length, 1); assert.equal(h.data.get(key), stored);
  assert.equal(h.run('canSubmitInput()'), false);
});

await check('only a confirmed rejected creation offers one explicit new public challenge with a fresh durable operation', async () => {
  const h = harness({ enabled: true, href: origin + '/games/remix/?challenge=dead-challenge' }); await h.select();
  h.handler = call => call.path === '/api/remix/v2/matches' && call.method === 'POST' ? response({ error: 'creation_rejected' }, 409) : undefined;
  await h.run('start()'); const oldKey = h.creates()[0].headers['idempotency-key'];
  assert.equal(h.run('sessionMode'), 'creation-rejected'); assert.equal(h.journal('creation').length, 0);
  assert.equal(h.node('#owned-new-challenge').hidden, false); assert.equal(h.node('#owned-new-challenge').disabled, false);
  const challenge = deferred(); h.handler = call => call.path.endsWith('/v1/challenges') ? challenge.promise : undefined;
  const creating = h.node('#owned-new-challenge').onclick(); await h.flush(); await h.node('#owned-new-challenge').onclick();
  assert.equal(h.calls.filter(call => call.path.endsWith('/v1/challenges')).length, 1);
  challenge.resolve(response({ id: 'fresh-public-challenge', seed: 20261017 }, 201)); await creating;
  assert.equal(h.run('selectedAccess'), 'core-owned'); assert.equal(h.creates().length, 2);
  assert.equal(h.creates()[1].body.challengeId, 'fresh-public-challenge'); assert.notEqual(h.creates()[1].headers['idempotency-key'], oldKey);
  assert.equal(h.calls.find(call => call.path.endsWith('/v1/challenges')).headers.authorization, undefined);
  const uncertain = harness({ enabled: true }); await uncertain.select();
  uncertain.handler = call => call.path === '/api/remix/v2/matches' && call.method === 'POST' ? response({ error: 'creation_uncertain' }, 503) : undefined;
  await uncertain.run('start()'); const pending = uncertain.data.get(uncertain.journal('creation')[0].key), calls = uncertain.calls.length;
  assert.equal(uncertain.node('#owned-new-challenge').hidden, true); await uncertain.node('#owned-new-challenge').onclick();
  assert.equal(uncertain.calls.length, calls); assert.equal(uncertain.data.get(uncertain.journal('creation')[0].key), pending);
});

await check('the actual RU/EN translator covers account controls, limitations and dynamic recovery labels', async () => {
  const h = harness(); vm.runInContext(interfaceSource, h.context, { filename: 'remix-shipped-interface.js' });
  const labels = ['SESSION ACCESS', 'Guest / invite mode', 'Account-owned matches', 'Sign in and return to REMIX', 'Verify account again', 'Refresh account matches', 'Next page of account matches', 'Check pending creation', 'Create a new public challenge', 'Account creation unavailable', 'Saved account recovery is full. Check pending creations or restore existing matches before submitting more.', 'Another creation is pending for this account. Check its recovery before starting another run.', 'Account recovery storage is unavailable. Existing recovery records are retained; new commands and creations are paused.', 'Creation remains unconfirmed. Check this same attempt again; no POST will be repeated.', 'The owned record remains saved, but its active simulation is unavailable. This release cannot recover a lost simulation.', 'One account controls its assigned player. Other accounts cannot join this owned match. Guest matches remain anonymous. Active simulation recovery and replay verification are not available.', 'Verified account: alice', 'Recover match owned-A'];
  for (const label of labels) assert.notEqual(h.run('RemixUI.t(' + JSON.stringify(label) + ')'), label, label);
  h.run("RemixUI.setLanguage('en')"); for (const label of labels) assert.equal(h.run('RemixUI.t(' + JSON.stringify(label) + ')'), label);
  assert.match(h.run('ownedSignInURL()'), /lang%3Den/);
});

console.log(`REMIX owned session smoke: ${passed} PASS, 0 FAIL`);
