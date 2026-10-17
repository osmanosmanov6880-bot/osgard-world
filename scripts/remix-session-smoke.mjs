import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

// Execute the shipped browser controller. The fixtures represent observed HTTP shapes;
// they do not pretend to execute Unity or prove the production match service.
const html = readFileSync('public/games/remix/index.html', 'utf8');
const source = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(match => match[1]).find(code => code.includes('async function restoreSession()'));
assert.ok(source, 'REMIX session controller is missing');
let passed = 0;
async function check(name, run) { await run(); passed++; console.log('PASS', name); }
const response = (value, status = 200) => ({ ok: status >= 200 && status < 300, status, json: async () => value });
const deferred = () => { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no; }); return { promise, resolve, reject }; };

function harness({ data = new Map(), denied = false, quota = false, href = 'https://osgard.world/games/remix/', handler } = {}) {
  const nodes = new Map(), events = new Map(), timers = new Map(), calls = [], arcs = [];
  let timerId = 0, now = Date.UTC(2026, 9, 17, 12), matchCount = 0;
  const ctx = { clearRect() {}, beginPath() {}, moveTo() {}, lineTo() {}, stroke() {}, fill() {}, arc(...args) { arcs.push(args); } };
  class Element {
    constructor(key) { this.key = key; this.style = {}; this.dataset = {}; this.handlers = new Map(); this.hidden = ['#growth-panel', '#sponsor-slot', '#result-summary', '#result-card-actions', '#retry-match'].includes(key); this.value = ''; this.textContent = ''; this.width = 340; this.height = 150; }
    querySelector(selector) { return node(selector); }
    querySelectorAll(selector) { return selector === '[data-console-action]' ? ['left', 'jump', 'right'].map(action => node('[data-console-action=' + action + ']')) : []; }
    setAttribute(name, value) { this[name] = String(value); }
    addEventListener(name, callback) { this.handlers.set(name, callback); }
    insertBefore() {}
    appendChild(child) { return child; }
    getContext() { return ctx; }
    focus() { this.focused = true; }
  }
  const node = key => { if (!nodes.has(key)) nodes.set(key, new Element(key)); return nodes.get(key); };
  const localStorage = { getItem(key) { if (denied) throw Error('denied'); return data.get(key) ?? null; }, setItem(key, value) { if (denied || quota) throw Error('quota'); data.set(key, String(value)); }, removeItem(key) { if (denied || quota) throw Error('quota'); data.delete(key); } };
  class TestDate extends Date { constructor(...args) { super(...(args.length ? args : [now])); } static now() { return now; } }
  const h = { data, calls, arcs, node, state: { phase: 'COUNTDOWN', players: 0, remainingMs: 3000, replayFrames: 0 }, result: null, handler };
  const context = {
    console, URL, URLSearchParams, AbortController, Date: TestDate, localStorage,
    location: new URL(href), navigator: { onLine: true }, crypto: { randomUUID: () => 'test-player' },
    document: { createElement: key => new Element(key), querySelector: node },
    setTimeout(fn, delay = 0) { const id = ++timerId; timers.set(id, { fn, delay, at: now + delay }); return id; },
    clearTimeout(id) { timers.delete(id); },
    addEventListener(name, callback) { events.set(name, [...(events.get(name) || []), callback]); },
    fetch: async (url, options = {}) => {
      const call = { url: String(url), path: new URL(url).pathname, method: options.method || 'GET', body: options.body ? JSON.parse(options.body) : undefined, signal: options.signal };
      calls.push(call);
      const perform = async () => {
        if (h.handler) { const custom = await h.handler(call, h); if (custom !== undefined) return custom; }
        if (call.path.endsWith('/v1/challenges')) return response({ id: 'ch_test', seed: 20261017 }, 201);
        if (call.path.endsWith('/v1/matches')) return response({ id: 'match_test.' + (++matchCount), challengeId: call.body.challengeId }, 201);
        if (call.path.endsWith('/state')) return response({ id: call.path.split('/').at(-2), ...h.state });
        if (call.path.endsWith('/result')) return response(h.result || { matchId: call.path.split('/').at(-2), phase: 'RESULTS', replayFrames: h.state.replayFrames, scores: [{ playerId: 'web-test-player', score: 0.05 }] });
        if (call.path.endsWith('/input')) return response({ playerId: call.body.playerId, lastSequence: call.body.sequence, position: [1, 0, 0] });
        throw Error('Unexpected fixture route: ' + call.path);
      };
      if (!call.signal) return perform();
      return Promise.race([perform(), new Promise((_resolve, reject) => {
        call.signal.addEventListener('abort', () => { const error = Error('request aborted'); error.name = 'AbortError'; reject(error); }, { once: true });
      })]);
    }
  };
  context.window = context; context.parent = context;
  vm.createContext(context); vm.runInContext(source, context, { filename: 'remix-shipped-controller.js' });
  h.context = context; h.run = code => vm.runInContext(code, context);
  h.flush = async () => { for (let i = 0; i < 30; i++) await Promise.resolve(); };
  h.emit = (name, event = {}) => { for (const fn of events.get(name) || []) fn(event); };
  h.pending = delay => [...timers.values()].filter(timer => timer.delay === delay).length;
  h.advance = async duration => {
    const target = now + duration;
    for (let guard = 0; guard < 100; guard++) {
      const next = [...timers].filter(([, timer]) => timer.at <= target).sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) break;
      timers.delete(next[0]); now = next[1].at; next[1].fn(); await h.flush();
      if (guard === 99) throw Error('Unbounded fixture timers');
    }
    now = target; await h.flush();
  };
  h.start = async () => { await h.run('start()'); await h.flush(); };
  h.play = async () => { h.state = { phase: 'PLAYING', players: 1, remainingMs: 30000, replayFrames: 0 }; await h.run('refresh()'); await h.flush(); };
  return h;
}

await check('boot is read-only and keeps controls unavailable until a verified playing state', async () => {
  const h = harness(); await h.flush(); assert.equal(h.calls.length, 0); assert.equal(h.run('canSubmitInput()'), false);
  assert.equal(h.node('[data-console-action=left]').disabled, true);
  await h.start(); h.run('send(1,0,false)'); await h.flush(); assert.equal(h.calls.filter(call => call.path.endsWith('/input')).length, 0);
  assert.equal(h.node('#phase-time').textContent, '3 s left in this phase');
  assert.equal(h.node('#rematch-challenge').disabled, true);
});

await check('double start and active rematch cannot create duplicate challenges or matches', async () => {
  const waiting = deferred();
  const h = harness({ handler: call => call.path.endsWith('/v1/challenges') ? waiting.promise : undefined });
  const first = h.run('start()'); await h.flush(); await h.run('start()'); h.run('resetForRematch()');
  assert.equal(h.calls.length, 1); waiting.resolve(response({ id: 'ch_test', seed: 20261017 }, 201)); await first;
  await h.run('start()'); h.run('resetForRematch()'); await h.flush();
  assert.equal(h.calls.filter(call => call.path.endsWith('/v1/challenges')).length, 1);
  assert.equal(h.calls.filter(call => call.path.endsWith('/v1/matches')).length, 1);
});

await check('polling stays serial across slow responses and schedules only after completion', async () => {
  const h = harness(); await h.start(); const waiting = deferred();
  h.handler = call => call.path.endsWith('/state') ? waiting.promise : undefined;
  const first = h.run('refresh()'); await h.flush(); const count = h.calls.length;
  await h.run('refresh()'); await h.advance(4000); assert.equal(h.calls.length, count); assert.equal(h.pending(1000), 0);
  waiting.resolve(response({ id: h.run('match.id'), ...h.state })); await first; assert.equal(h.pending(1000), 1);
});

await check('server world coordinates are projected and bounded; no optimistic position is drawn', async () => {
  const h = harness(); await h.start(); await h.play(); const waiting = deferred();
  h.handler = call => call.path.endsWith('/input') ? waiting.promise : undefined;
  h.run('send(1,0,false)'); await h.flush(); assert.equal(h.run('serverPosition'), null); assert.equal(h.arcs.length, 0);
  waiting.resolve(response({ playerId: h.run('playerId'), lastSequence: 1, position: [1, 2, 0] })); await h.flush();
  assert.deepEqual(h.arcs.at(-1).slice(0, 2), [204, 66]); assert.match(h.node('#server-position').textContent, /X 1.00 · Y 2.00/);
  h.handler = call => call.path.endsWith('/input') ? response({ playerId: h.run('playerId'), lastSequence: 2, position: [-1000, 1000, 0] }) : undefined;
  await h.advance(100); h.run('send(-1,0,false)'); await h.flush(); assert.deepEqual(h.arcs.at(-1).slice(0, 2), [10, 10]);
});

await check('keyboard repeat has at most one input in flight and one coalesced intent', async () => {
  const h = harness(); await h.start(); await h.play(); const waiting = deferred();
  h.handler = call => call.path.endsWith('/input') ? waiting.promise : undefined;
  h.run('send(1,0,false)'); await h.flush(); for (let i = 0; i < 100; i++) h.run('send(-1,0,false)');
  assert.equal(h.calls.filter(call => call.path.endsWith('/input')).length, 1); assert.equal(h.run('pendingInput.moveX'), -1);
  waiting.resolve(response({ playerId: h.run('playerId'), lastSequence: 1, position: [0, 0, 0] })); await h.flush();
  assert.equal(h.calls.filter(call => call.path.endsWith('/input')).length, 1);
  h.handler = undefined; await h.advance(100); assert.equal(h.calls.filter(call => call.path.endsWith('/input')).length, 2);
});

await check('an unconfirmed input is never resent; its sequence is retained before POST and after reload', async () => {
  const h = harness(); await h.start(); await h.play();
  h.handler = call => { if (call.path.endsWith('/input')) { assert.equal(JSON.parse(h.data.get(h.run('sessionKey'))).sequence, 1); throw TypeError('network lost'); } };
  h.run('send(1,0,false)'); await h.flush(); assert.equal(h.run('sessionMode'), 'reconnecting');
  await h.advance(1000); assert.equal(h.calls.filter(call => call.path.endsWith('/input')).length, 1);
  const resumed = harness({ data: h.data }); resumed.state = { ...h.state }; await resumed.flush(); await resumed.play();
  assert.equal(resumed.calls.filter(call => call.method === 'POST').length, 0);
  resumed.run('send(1,0,false)'); await resumed.flush();
  assert.equal(resumed.calls.find(call => call.path.endsWith('/input')).body.sequence, 2);
});

await check('a failed result fetch retains the match and retries until a matching server result arrives', async () => {
  const h = harness(); await h.start(); h.state = { phase: 'RESULTS', players: 1, remainingMs: 0, replayFrames: 3 };
  let attempts = 0; h.handler = call => call.path.endsWith('/result') && ++attempts === 1 ? response({}, 503) : undefined;
  await h.run('refresh()'); assert.equal(h.run('sessionMode'), 'result-pending'); assert.equal(h.node('#result-card-actions').hidden, true);
  h.run('send(1,0,false)'); await h.flush(); assert.equal(h.calls.filter(call => call.path.endsWith('/input')).length, 0);
  assert.equal(h.pending(2000), 1); await h.advance(2000);
  assert.equal(attempts, 2); assert.equal(h.run('sessionMode'), 'completed'); assert.equal(h.node('#result-card-actions').hidden, false);
  assert.equal(h.node('#sponsor-slot').hidden, false); assert.equal(h.node('#rematch-challenge').disabled, false); assert.equal(h.pending(1000), 0);
});

await check('reload never presents locally stored scores as a verified result', async () => {
  const h = harness(); await h.start(); const key = h.run('sessionKey');
  const raw = JSON.parse(h.data.get(key)); raw.scores = [{ playerId: 'forged', score: 999999 }]; raw.summary = 'forged'; h.data.set(key, JSON.stringify(raw));
  const waiting = deferred(), resumed = harness({ data: h.data, handler: call => call.path.endsWith('/state') ? waiting.promise : undefined });
  await resumed.flush(); assert.equal(resumed.run('lastResultSummary'), ''); assert.equal(resumed.node('#result-card-actions').hidden, true); assert.equal(resumed.run('canSubmitInput()'), false);
  assert.ok(resumed.calls.every(call => call.method === 'GET'));
  waiting.resolve(response({ id: resumed.run('match.id'), phase: 'RESULTS', players: 1, remainingMs: 0, replayFrames: 1 })); await resumed.flush();
  assert.equal(resumed.run('sessionMode'), 'completed'); assert.ok(!resumed.node('#result-summary').textContent.includes('forged'));
});

await check('a result for a different match or malformed scores never unlocks export', async () => {
  for (const result of [{ matchId: 'other', phase: 'RESULTS', replayFrames: 1, scores: [] }, { matchId: 'match_test.1', phase: 'RESULTS', replayFrames: 1, scores: [{ playerId: 'web-test-player', score: null }] }]) {
    const h = harness(); await h.start(); h.state = { phase: 'RESULTS', players: 1, remainingMs: 0, replayFrames: 1 }; h.result = result;
    await h.run('refresh()'); assert.equal(h.run('sessionMode'), 'result-pending'); assert.equal(h.run('lastResultSummary'), ''); assert.equal(h.node('#result-card-actions').hidden, true);
  }
});

await check('a state for a different match cannot unlock input or replace the saved match', async () => {
  const h = harness(); await h.start(); const id = h.run('match.id');
  h.state = { id: 'match_other', phase: 'PLAYING', players: 1, remainingMs: 30000, replayFrames: 1 };
  await h.run('refresh()'); assert.equal(h.run('canSubmitInput()'), false); assert.equal(h.run('match.id'), id);
  h.run('send(1,0,false)'); await h.flush(); assert.equal(h.calls.filter(call => call.path.endsWith('/input')).length, 0);
});

await check('rematch clears every result surface and begins with a fresh input sequence', async () => {
  const h = harness(); await h.start(); await h.play(); h.run('send(1,0,false)'); await h.flush();
  h.state = { phase: 'RESULTS', players: 1, remainingMs: 0, replayFrames: 1 }; await h.run('refresh()');
  const waiting = deferred(); h.handler = call => call.path.endsWith('/v1/matches') ? waiting.promise : undefined;
  h.run('resetForRematch()'); await h.flush();
  for (const key of ['#result-summary', '#result-card-actions', '#sponsor-slot']) assert.equal(h.node(key).hidden, true, key);
  assert.equal(h.run('lastResultSummary'), ''); assert.equal(h.run('serverPosition'), null); assert.equal(h.run('seq'), 0);
  waiting.resolve(response({ id: 'match_test.2', challengeId: 'ch_test' }, 201)); h.state = { phase: 'PLAYING', players: 0, remainingMs: 30000, replayFrames: 0 }; await h.flush();
  h.handler = undefined; h.run('send(1,0,false)'); await h.flush();
  const last = h.calls.filter(call => call.path.endsWith('/input')).at(-1); assert.match(last.path, /match_test\.2\/input$/); assert.equal(last.body.sequence, 1);
  assert.equal(h.calls.filter(call => call.path.endsWith('/v1/challenges')).length, 1);
});

await check('a stale input reply cannot repaint a completed or replacement match', async () => {
  const h = harness(); await h.start(); await h.play(); const waiting = deferred(); h.handler = call => call.path.endsWith('/input') ? waiting.promise : undefined;
  h.run('send(1,0,false)'); await h.flush(); h.state = { phase: 'RESULTS', players: 1, remainingMs: 0, replayFrames: 0 }; await h.run('refresh()');
  waiting.resolve(response({ playerId: h.run('playerId'), lastSequence: 1, position: [50, 50, 0] })); await h.flush();
  assert.equal(h.run('serverPosition'), null); assert.equal(h.run('sessionMode'), 'completed'); assert.equal(h.run('inputBusy'), false);
});

await check('session recovery is scoped to the exact API and incoming challenge', async () => {
  const original = harness(); await original.start();
  const changedApi = new Map(original.data); changedApi.set('remix-api-url', 'https://example.test/remix');
  const other = harness({ data: changedApi }); await other.flush(); assert.equal(other.calls.length, 0); assert.equal(other.run('match'), null);
  const invited = harness({ data: original.data, href: 'https://osgard.world/games/remix/?challenge=ch_different&seed=20261017' }); await invited.flush(); assert.equal(invited.calls.length, 0); assert.equal(invited.run('match'), null);
  const poisoned = new Map(original.data); const key = original.run('sessionKey'), raw = JSON.parse(poisoned.get(key)); raw.apiBase = 'https://example.test/remix'; poisoned.set(key, JSON.stringify(raw));
  const invalid = harness({ data: poisoned }); await invalid.flush(); assert.equal(invalid.calls.length, 0); assert.equal(invalid.run('match'), null);
});

await check('malformed, expired and invalid session shapes are ignored without network mutation', async () => {
  const sample = harness(); await sample.start(); const key = sample.run('sessionKey'), valid = JSON.parse(sample.data.get(key));
  for (const raw of ['{bad', 'null', '[]', JSON.stringify({ ...valid, sequence: -1 }), JSON.stringify({ ...valid, savedAt: 0 }), JSON.stringify({ ...valid, matchId: '.' }), JSON.stringify({ ...valid, matchId: '..' }), JSON.stringify({ ...valid, matchId: '../../other' }), JSON.stringify({ ...valid, completionReported: 'yes' })]) {
    const h = harness({ data: new Map([[key, raw]]) }); await h.flush(); assert.equal(h.run('match'), null); assert.equal(h.calls.length, 0); assert.match(h.node('#match-status').textContent, /invalid or expired/);
  }
});

await check('denied and quota-limited storage keep the current session usable without rolling back its sequence', async () => {
  for (const options of [{ denied: true }, { quota: true }]) {
    const h = harness(options); await h.start(); await h.play(); h.run('send(1,0,false)'); await h.flush();
    assert.equal(h.run('remixStore.ephemeral'), true); assert.equal(h.run('seq'), 1);
    assert.equal(h.run('JSON.parse(remixStore.getItem(sessionKey)).sequence'), 1); assert.equal(h.run('canSubmitInput()'), true);
  }
});

await check('creation with a lost response is explicit and is never automatically retried on reload', async () => {
  const h = harness({ handler: call => { if (call.path.endsWith('/v1/matches')) throw TypeError('response lost'); } });
  await h.start(); assert.equal(h.run('sessionMode'), 'uncertain'); assert.match(h.node('#match-status').textContent, /separate action/);
  await h.advance(60000); assert.equal(h.calls.filter(call => call.path.endsWith('/v1/matches')).length, 1);
  const resumed = harness({ data: h.data }); await resumed.flush(); assert.equal(resumed.calls.length, 0); assert.equal(resumed.run('sessionMode'), 'uncertain');
  assert.equal(resumed.node('#start-match').disabled, false); assert.equal(resumed.node('#start-match').textContent, 'Start a new match');
});

await check('a missing saved match allows read-only retry and requires an explicit new start', async () => {
  const h = harness(); await h.start(); const resumed = harness({ data: h.data, handler: call => call.path.endsWith('/state') ? response({}, 404) : undefined });
  await resumed.flush(); assert.equal(resumed.run('sessionMode'), 'missing'); assert.equal(resumed.calls.length, 1); assert.equal(resumed.node('#retry-match').hidden, false);
  await resumed.advance(60000); assert.equal(resumed.calls.length, 1); await resumed.run('refresh()'); assert.equal(resumed.calls.length, 2);
  assert.ok(resumed.calls.every(call => call.method === 'GET'));
});

await check('a lost challenge has a working fresh-daily path; an invalid shared invite has an explicit exit', async () => {
  const h = harness(); await h.start(); h.handler = call => call.path.endsWith('/state') || call.path.endsWith('/v1/matches') ? response({}, 404) : undefined;
  await h.run('refresh()'); await h.run('start()');
  assert.equal(h.run('activeChallengeId'), ''); assert.equal(h.node('#start-match').textContent, 'Create daily challenge');
  h.handler = undefined; await h.start(); assert.equal(h.calls.filter(call => call.path.endsWith('/v1/challenges')).length, 2); assert.ok(h.run('match.id'));
  const invited = harness({ href: 'https://osgard.world/games/remix/?challenge=ch_missing&seed=42', handler: call => call.path.endsWith('/v1/matches') ? response({}, 404) : undefined });
  await invited.start(); assert.equal(invited.run('sessionMode'), 'invalid-invite'); assert.equal(invited.node('#new-daily-challenge').hidden, false);
  assert.equal(invited.calls.filter(call => call.path.endsWith('/v1/challenges')).length, 0);
});

await check('shared and restored seed metadata is labelled separately from server result proof', async () => {
  const shared = harness({ href: 'https://osgard.world/games/remix/?challenge=ch_test&seed=42' }); await shared.flush();
  assert.match(shared.node('#challenge-copy').textContent, /Invitation seed 42/); assert.equal(shared.run('challengeSeedVerified'), false);
  const created = harness(); await created.start(); assert.equal(created.run('challengeSeedVerified'), true);
  const resumed = harness({ data: created.data }); await resumed.flush(); assert.equal(resumed.run('challengeSeedVerified'), false);
  assert.match(resumed.node('#challenge-copy').textContent, /Invitation seed/);
  const cardSource = source.slice(source.indexOf('function createResultCardBlob('), source.indexOf('function downloadBlob('));
  assert.ok(cardSource.includes('card.matchId')); assert.ok(!cardSource.includes('card.seed'));
});

await check('offline suspends input and polling; coming online resumes the same match without POST', async () => {
  const h = harness(); await h.start(); await h.play(); const id = h.run('match.id'), count = h.calls.length;
  h.context.navigator.onLine = false; h.emit('offline'); h.run('send(1,0,false)'); await h.advance(20000);
  assert.equal(h.calls.length, count); assert.equal(h.run('canSubmitInput()'), false);
  h.context.navigator.onLine = true; h.emit('online'); await h.flush(); assert.equal(h.run('match.id'), id); assert.equal(h.run('canSubmitInput()'), true);
  assert.ok(h.calls.slice(count).every(call => call.method === 'GET'));
});

await check('a state body received after disconnect cannot overwrite offline status or restart polling', async () => {
  const h = harness(); await h.start(); await h.play(); h.run('send(1,0,false)'); await h.flush();
  const id = h.run('match.id'), player = h.run('playerId'), waiting = deferred();
  // The response headers have arrived; its body deliberately ignores abort so
  // this exercises the operation guard as well as transport cancellation.
  h.handler = call => call.path.endsWith('/state') ? { ...response(null), json: () => waiting.promise } : undefined;
  const pending = h.run('refresh()'); await h.flush();
  const oldRead = h.calls.at(-1);
  h.context.navigator.onLine = false; h.emit('offline');
  waiting.resolve({ id, ...h.state }); await pending;
  assert.equal(h.run('sessionMode'), 'reconnecting'); assert.equal(h.run('verifiedState'), false);
  assert.match(h.node('#match-status').textContent, /You are offline/);
  assert.equal(h.run('polling'), false); assert.equal(h.pending(1000), 0); assert.equal(oldRead.signal.aborted, true);
  assert.equal(h.run('seq'), 1); assert.equal(h.run('playerId'), player); assert.equal(h.run('match.id'), id);
  h.run('send(1,0,false)'); await h.flush(); assert.equal(h.calls.filter(call => call.path.endsWith('/input')).length, 1);
  h.handler = undefined; h.context.navigator.onLine = true; h.emit('online'); await h.flush();
  assert.equal(h.run('canSubmitInput()'), true); assert.equal(h.run('match.id'), id);
  await h.advance(100); h.run('send(1,0,false)'); await h.flush();
  assert.equal(h.calls.filter(call => call.path.endsWith('/input')).at(-1).body.sequence, 2);
  assert.equal(h.calls.filter(call => call.path.endsWith('/v1/matches')).length, 1);
});

await check('a pre-disconnect result cannot unlock export or finish a fresh reconnect read', async () => {
  const h = harness(); await h.start();
  h.state = { phase: 'RESULTS', players: 1, remainingMs: 0, replayFrames: 1 };
  const id = h.run('match.id'), oldResult = deferred(), newState = deferred();
  h.handler = call => call.path.endsWith('/result') ? { ...response(null), json: () => oldResult.promise } : undefined;
  const pending = h.run('refresh()'); await h.flush(); assert.equal(h.run('sessionMode'), 'result-pending');
  const oldRead = h.calls.at(-1);
  h.context.navigator.onLine = false; h.emit('offline');
  h.handler = call => call.path.endsWith('/state') ? { ...response(null), json: () => newState.promise } : undefined;
  h.context.navigator.onLine = true; h.emit('online'); await h.flush();
  assert.equal(h.run('polling'), true);
  oldResult.resolve({ matchId: id, phase: 'RESULTS', replayFrames: 1, scores: [{ playerId: 'web-test-player', score: 0.05 }] });
  await pending;
  assert.equal(h.run('sessionMode'), 'reconnecting'); assert.equal(h.run('polling'), true);
  assert.equal(h.run('lastResultSummary'), ''); assert.equal(h.node('#result-card-actions').hidden, true);
  assert.equal(oldRead.signal.aborted, true);
  newState.resolve({ id, ...h.state }); await h.flush();
  assert.equal(h.run('sessionMode'), 'completed'); assert.equal(h.run('match.id'), id);
  assert.equal(h.node('#result-card-actions').hidden, false);
  assert.equal(h.calls.filter(call => call.path.endsWith('/v1/matches')).length, 1);
});

await check('an API text edit cannot redirect an active match request', async () => {
  const h = harness(); await h.start(); h.node('#api-url').value = 'https://other.example/match'; await h.play();
  assert.ok(h.calls.every(call => call.url.startsWith('https://osgard.world/api/remix/'))); assert.equal(h.node('#api-url').disabled, true);
});

await check('an invalid API edit and failed start cannot overwrite completed-session recovery', async () => {
  const h = harness(); await h.start(); h.state = { phase: 'RESULTS', players: 1, remainingMs: 0, replayFrames: 0 }; await h.run('refresh()');
  const key = h.run('sessionKey'), original = h.data.get(key), id = h.run('match.id');
  h.node('#api-url').value = 'https://osgard.world/api/remix?invalid=1'; h.node('#api-url').handlers.get('change')(); await h.run('start()');
  assert.equal(h.data.get(key), original); assert.equal(h.run('match.id'), id);
  h.node('#api-url').value = '/api/remix'; h.node('#api-url').handlers.get('change')(); await h.flush();
  assert.equal(h.run('match.id'), id); assert.equal(h.run('sessionMode'), 'completed'); assert.equal(h.node('#result-card-actions').hidden, false);
});

console.log(`SUMMARY ${passed} PASS / 0 FAIL. Controller recovery and concurrency verified with HTTP fixtures; live service and Unity checks remain separate.`);
