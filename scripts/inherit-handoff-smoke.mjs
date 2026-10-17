import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

// Execute the shipped handlers with deferred transport/file reads, not a copy of their logic.
// This harness has no browser, server, persistent writes, or real network access.
const html = readFileSync('public/games/inherit/index.html', 'utf8');
const interfaceSource = readFileSync('public/games/inherit/interface.js', 'utf8');
const scripts = [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)].map(match => match[1]);
function sourceWith(token) {
  const matches = scripts.filter(source => source.includes(token));
  assert.equal(matches.length, 1, `one shipped script containing ${token}`);
  return matches[0];
}
const initialSource = sourceWith('const gameStorage=');
const sharedSource = sourceWith('async function loadSharedWorld()');
const handoffSource = sourceWith('function returnToToday()');
const importSource = sourceWith('const importButton=');
const undoSource = sourceWith('const removed=S.pending.pop()');
const analyticsSource = sourceWith('const passForAnalytics=');
const analyticsWrapper = analyticsSource.slice(analyticsSource.indexOf('const passForAnalytics='), analyticsSource.indexOf('const returnedEventKey='));

const seed = () => ({
  generation: 173, budget: 99, changes: ['planted a young tree'],
  objects: [{ tool: 'tree', x: 40, y: 30 }],
  pending: [{ type: 'tree', x: 40, y: 30 }], history: [], snapshots: [],
});
const emptySeed = () => ({ ...seed(), budget: 100, changes: [], objects: [], pending: [] });
const archive = () => ({
  world: 'The Quiet Reach', generation: 800,
  objects: [{ tool: 'light', x: 45, y: 35 }], snapshots: [],
  history: [{ generation: 799, by: '@Archive', action: 'A preserved trace.', when: 'Yesterday' }],
});
const sharedWorld = () => ({
  currentGeneration: 900, objects: [{ type: 'stone', x: 50, y: 40 }],
  generations: [{ number: 899, author: '@Remote', message: 'A shared trace.', createdAt: '2026-10-17T10:00:00Z' }],
});
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
async function flush() { for (let turn = 0; turn < 12; turn++) await Promise.resolve(); }
async function settle(promise) {
  let timer;
  try {
    return await Promise.race([promise, new Promise((_, reject) => {
      timer = setTimeout(() => reject(new Error('handler did not settle after its controlled response/deadline')), 1000);
    })]);
  } finally { clearTimeout(timer); }
}

class Element {
  constructor(nodes) {
    this.children = []; this.style = {}; this.dataset = {}; this.attributes = new Map();
    this.events = new Map(); this.disabled = false; this.textContent = ''; this.innerHTML = ''; this.value = '';
    const classes = new Set();
    this.classList = {
      add: value => classes.add(value), remove: value => classes.delete(value), contains: value => classes.has(value),
      toggle(value, force) { const on = force ?? !classes.has(value); if (on) classes.add(value); else classes.delete(value); return on; },
    };
    Object.defineProperty(this, 'id', { set: value => { nodes.set('#' + value, this); }, configurable: true });
  }
  appendChild(node) { this.children.push(node); return node; }
  setAttribute(name, value) { this.attributes.set(name, String(value)); }
  getAttribute(name) { return this.attributes.get(name) ?? null; }
  addEventListener(name, callback) { const events = this.events.get(name) || []; events.push(callback); this.events.set(name, events); }
  querySelectorAll() { return []; }
  matches() { return false; }
  closest() { return null; }
  getBoundingClientRect() { return { left: 0, top: 0, width: 100, height: 100 }; }
  click() { if (!this.disabled) return this.onclick?.({ target: this }); }
}

function harness({ state = seed(), language = 'en', quota = false, abortSupported = true } = {}) {
  const nodes = new Map(), events = new Map(), requests = [], readers = [], analytics = [], timers = new Map();
  const data = new Map([['inherit-world-v1', JSON.stringify(state)], ['inherit-author', '@Keeper']]);
  let now = Date.parse('2026-10-17T10:00:00Z'), timerId = 0, confirmations = 0, reloads = 0;
  const node = selector => { if (!nodes.has(selector)) nodes.set(selector, new Element(nodes)); return nodes.get(selector); };
  class ClockDate extends Date {
    constructor(...args) { super(...(args.length ? args : [now])); }
    static now() { return now; }
  }
  const context = {
    console, URL, URLSearchParams, Date: ClockDate,
    location: { search: '?lang=' + language, href: 'https://osgard.world/games/inherit/?lang=' + language, reload() { reloads++; } },
    history: { replaceState() {} }, confirm() { confirmations++; return true; },
    localStorage: {
      getItem: key => data.get(key) ?? null,
      setItem(key, value) { if (quota) throw new Error('quota'); data.set(key, String(value)); },
      removeItem: key => data.delete(key),
    },
    setTimeout(callback, delay) { const id = ++timerId; timers.set(id, { callback, at: now + delay }); return id; },
    clearTimeout: id => timers.delete(id),
    document: {
      readyState: 'loading', documentElement: {}, querySelector: node, querySelectorAll: () => [],
      createElement: () => new Element(nodes), head: { insertAdjacentHTML() {} }, body: new Element(nodes),
      addEventListener(name, callback) { const list = events.get(name) || []; list.push(callback); events.set(name, list); },
    },
    addEventListener() {}, chronicle: new Element(nodes), openChronicle() {},
    track: event => analytics.push(event),
    FileReader: class {
      constructor() { readers.push(this); }
      readAsText(file) { this.file = file; }
    },
    fetch(url, options = {}) {
      const pending = deferred();
      requests.push({ url, options, method: options.method || 'GET', ...pending });
      // Deliberately ignore abort here: the late-response tests must pass even when
      // a transport cannot be cancelled after the deadline.
      return pending.promise;
    },
  };
  if (abortSupported) context.AbortController = AbortController;
  context.window = context;
  vm.createContext(context);
  const run = source => vm.runInContext(source, context);
  for (const source of [initialSource, interfaceSource, sharedSource, handoffSource, importSource, undoSource, analyticsWrapper]) run(source);
  return {
    node, run, requests, readers, analytics, data, context,
    posts: () => requests.filter(request => request.method === 'POST'),
    state: () => JSON.parse(run('JSON.stringify(S)')),
    stored: () => JSON.parse(run("gameStorage.getItem('inherit-world-v1')")),
    pass: () => node('#pass').onclick(),
    message: () => context.InheritUI.t(node('#caption').textContent),
    place() { node('#world').onclick({ target: new Element(nodes), clientX: 60, clientY: 40 }); },
    undo() { for (const callback of events.get('keydown') || []) callback({ key: 'z', ctrlKey: true, target: new Element(nodes), preventDefault() {} }); },
    startImport() { const input = node('#inherit-import-file'); input.files = [{ name: 'lineage.json' }]; input.value = 'lineage.json'; input.onchange(); return readers.at(-1); },
    finishImport(reader, value = archive()) { reader.result = JSON.stringify(value); reader.onload(); },
    confirmations: () => confirmations, reloads: () => reloads,
    async advance(ms) {
      now += ms;
      for (const [id, timer] of [...timers].sort((a, b) => a[1].at - b[1].at)) {
        if (timer.at <= now && timers.delete(id)) timer.callback();
      }
      await flush();
    },
  };
}
function response(request, value, status = 200) {
  request.resolve({ ok: status >= 200 && status < 300, status, json: () => Promise.resolve(value) });
}
function accepted(request) {
  const payload = JSON.parse(request.options.body);
  return { currentGeneration: payload.expectedGeneration + 1, generation: { number: payload.expectedGeneration, author: payload.author, message: payload.message } };
}
function unlocked(h, disabledImport = false) {
  assert.equal(h.run('handoffPending'), false);
  for (const selector of ['#pass', '#reset', '#inherit-import-file']) assert.equal(h.node(selector).disabled, false, selector);
  assert.equal(h.node('#inherit-import').disabled, disabledImport);
  assert.equal(h.node('#world').getAttribute('aria-busy'), 'false');
  assert.equal(h.node('#pass').getAttribute('aria-busy'), 'false');
  assert.equal(h.node('#pass').textContent, 'Pass this world on →');
}
function localCommit(h, before = seed()) {
  const after = h.state();
  assert.equal(after.generation, before.generation + 1);
  assert.equal(after.snapshots.length, before.snapshots.length + 1);
  assert.equal(after.history.length, before.history.length + 1);
  assert.deepEqual(after.snapshots.at(-1), { generation: before.generation, objects: before.objects });
  assert.deepEqual(after.objects, before.objects);
  assert.deepEqual(after.pending, []); assert.deepEqual(after.changes, []); assert.equal(after.budget, 100);
  assert.equal(after.history.at(-1).action, before.pending.length + ' local traces preserved; server confirmation is unknown.');
  assert.match(h.message(), /server has not confirmed|Server confirmation is unknown|Подтверждения сервера нет/);
  assert.equal(h.data.get('inherit-last-passed'), undefined);
  assert.deepEqual(h.stored(), after);
  assert.equal(h.posts().length, 1, 'a failed POST is never retried automatically');
  assert.deepEqual(h.analytics, [], 'a local fallback does not claim a confirmed transfer');
  unlocked(h);
}

let passed = 0;
async function check(name, callback) { await callback(); passed++; console.log('PASS', name); }

await check('one pending POST freezes placement, undo, import, reset and repeat handoff; the next generation can add a new trace', async () => {
  const h = harness(), before = h.state(), first = h.pass();
  assert.equal(await settle(h.pass()), 'busy');
  assert.equal(h.posts().length, 1);
  assert.deepEqual(JSON.parse(h.posts()[0].options.body), { expectedGeneration: 173, author: '@Keeper', message: '1 new traces for the next person.', delta: before.pending });
  for (const selector of ['#pass', '#reset', '#inherit-import', '#inherit-import-file']) assert.equal(h.node(selector).disabled, true, selector);
  assert.equal(h.node('#world').getAttribute('aria-busy'), 'true');
  assert.match(h.message(), /Traces are paused/);
  h.place(); h.undo(); h.node('#inherit-import').onclick(); h.startImport(); h.node('#reset').onclick();
  assert.deepEqual(h.state(), before);
  assert.equal(h.readers.length, 0); assert.equal(h.confirmations(), 0); assert.equal(h.reloads(), 0);
  response(h.posts()[0], accepted(h.posts()[0]));
  assert.equal(await settle(first), 'confirmed');
  assert.equal(h.state().history.length, 1); assert.equal(h.state().snapshots.length, 1);
  assert.deepEqual(h.state().snapshots[0].objects, before.objects);
  assert.equal(h.data.get('inherit-last-passed'), '174');
  assert.deepEqual(h.analytics, ['generation_transferred']);
  unlocked(h);
  h.run("tool='stone'"); h.place();
  assert.equal(h.state().generation, 174); assert.equal(h.state().budget, 99); assert.equal(h.state().pending.length, 1);
  const second = h.pass(), request = h.posts()[1];
  assert.equal(JSON.parse(request.options.body).expectedGeneration, 174);
  assert.deepEqual(JSON.parse(request.options.body).delta, [{ type: 'stone', x: 60, y: 40 }]);
  response(request, accepted(request)); await settle(second);
  assert.equal(h.state().generation, 175); assert.equal(h.state().snapshots.length, 2); assert.equal(h.state().history.length, 2);
  assert.equal(h.state().snapshots[1].objects.length, 2);
  assert.deepEqual(h.analytics, ['generation_transferred', 'generation_transferred']);
});

await check('a doubled offline handoff preserves exactly one captured snapshot/history and leaves the next trace pending', async () => {
  const h = harness(), first = h.pass(); await settle(h.pass());
  h.place(); response(h.posts()[0], null, 503); assert.equal(await settle(first), 'local');
  localCommit(h);
  h.run("tool='stone'"); h.place(); await flush();
  assert.equal(h.state().generation, 174); assert.equal(h.state().budget, 99);
  assert.equal(h.state().objects.length, 2); assert.equal(h.state().pending.length, 1);
  assert.equal(h.state().snapshots.length, 1); assert.equal(h.state().snapshots[0].objects.length, 1);
});

const failures = [
  ['HTTP error', request => response(request, null, 503)],
  ['transport failure', request => request.reject(new Error('connection lost'))],
  ['aborted response', request => request.reject(Object.assign(new Error('aborted'), { name: 'AbortError' }))],
  ['invalid JSON', request => request.resolve({ ok: true, status: 200, json: async () => { throw new SyntaxError('bad JSON'); } })],
  ['null result', request => response(request, null)],
  ['missing generation', request => response(request, { currentGeneration: 174 })],
  ['unrelated generation', request => response(request, { ...accepted(request), generation: { number: 172, author: '@Other', message: 'Other generation' } })],
  ['unchanged generation', request => response(request, { ...accepted(request), currentGeneration: 173 })],
  ['missing history message', request => response(request, { ...accepted(request), generation: { number: 173, author: '@Keeper' } })],
];
for (const [name, fail] of failures) await check(name + ' commits one local generation and explicitly leaves server confirmation unknown', async () => {
  const h = harness(), pending = h.pass(); fail(h.posts()[0]);
  assert.equal(await settle(pending), 'local'); localCommit(h);
});

for (const stage of ['headers', 'body']) for (const abortSupported of [true, false]) {
  await check(`12 s deadline covers ${stage}, with${abortSupported ? '' : 'out'} AbortController; a late success cannot alter the next generation`, async () => {
    const h = harness({ abortSupported }), pending = h.pass(), request = h.posts()[0], body = deferred();
    if (stage === 'body') { request.resolve({ ok: true, status: 200, json: () => body.promise }); await flush(); }
    await h.advance(11999); assert.equal(h.run('handoffPending'), true); assert.deepEqual(h.state(), seed());
    await h.advance(1); assert.equal(await settle(pending), 'local'); localCommit(h);
    if (abortSupported) assert.equal(request.options.signal.aborted, true);
    h.run("tool='stone'"); h.place();
    const next = h.pass(), beforeLateResponse = h.state();
    if (stage === 'body') body.resolve(accepted(request)); else response(request, accepted(request));
    await flush();
    assert.deepEqual(h.state(), beforeLateResponse); assert.equal(h.run('handoffPending'), true);
    const nextRequest = h.posts()[1]; response(nextRequest, accepted(nextRequest)); await settle(next);
    assert.equal(h.state().generation, 175); assert.equal(h.state().history.length, 2); assert.equal(h.state().snapshots.length, 2);
    assert.equal(h.state().snapshots[1].objects.length, 2);
    assert.deepEqual(h.analytics, ['generation_transferred']);
  });
}

await check('409 preserves pending traces, budget, history and snapshots, unlocks controls and makes no retry/read', async () => {
  const h = harness(), before = h.state(), pending = h.pass(); response(h.posts()[0], null, 409);
  assert.equal(await settle(pending), 'conflict'); assert.deepEqual(h.state(), before);
  assert.match(h.message(), /pending traces are unchanged/); assert.equal(h.requests.length, 2);
  assert.deepEqual(h.analytics, []); unlocked(h); h.place(); assert.equal(h.state().pending.length, 2);
});

await check('a presentation exception after commit cannot append a second fallback and still releases the lock', async () => {
  const h = harness(); h.run("render=function(){throw new Error('render failed')}");
  const pending = h.pass(); response(h.posts()[0], null, 503);
  await assert.rejects(settle(pending), /render failed/);
  assert.equal(h.state().generation, 174); assert.equal(h.state().history.length, 1); assert.equal(h.state().snapshots.length, 1);
  assert.deepEqual(h.stored(), h.state()); unlocked(h);
});

await check('an unchanged initial world may load normally', async () => {
  const h = harness({ state: emptySeed() }); response(h.requests[0], sharedWorld()); await flush();
  assert.equal(h.state().generation, 900); assert.deepEqual(h.state().objects, [{ tool: 'stone', x: 50, y: 40 }]);
});
for (const mutation of ['placement and undo', 'handoff', 'import', 'reset']) {
  await check('an initial GET arriving after ' + mutation + ' cannot replace or recreate the local save', async () => {
    const h = harness({ state: emptySeed() });
    if (mutation === 'placement and undo') { h.place(); h.undo(); }
    if (mutation === 'handoff') { h.place(); const pending = h.pass(); response(h.posts()[0], null, 503); await settle(pending); }
    if (mutation === 'import') h.finishImport(h.startImport());
    if (mutation === 'reset') h.node('#reset').onclick();
    const before = h.state(), savedBefore = h.run("gameStorage.getItem('inherit-world-v1')");
    response(h.requests[0], sharedWorld()); await flush();
    assert.deepEqual(h.state(), before); assert.equal(h.run("gameStorage.getItem('inherit-world-v1')"), savedBefore);
    if (mutation === 'reset') { assert.equal(savedBefore, null); assert.equal(h.reloads(), 1); }
  });
}

for (const finishDuringHandoff of [true, false]) {
  await check('an archive read started before handoff cannot apply ' + (finishDuringHandoff ? 'during the request' : 'after its completion'), async () => {
    const h = harness(), reader = h.startImport(), pending = h.pass();
    if (finishDuringHandoff) { h.finishImport(reader); assert.deepEqual(h.state(), seed()); }
    response(h.posts()[0], null, 503); await settle(pending); const before = h.state();
    if (!finishDuringHandoff) { h.finishImport(reader); assert.match(h.node('#toast').textContent, /world changed while the archive was loading/); }
    assert.deepEqual(h.state(), before); assert.equal(h.node('#inherit-import-file').value, '');
    h.finishImport(h.startImport()); assert.equal(h.state().generation, 800, 'a newly selected archive still imports');
  });
}

await check('temporary storage and both languages disclose unconfirmed server status without promising durable storage', async () => {
  const h = harness({ quota: true, language: 'ru' }), pending = h.pass(); response(h.posts()[0], null, 503); await settle(pending);
  localCommit(h);
  assert.equal(h.run('gameStorage.ephemeral'), true); assert.match(h.message(), /только на открытой странице/);
  assert.match(h.context.InheritUI.t(h.state().history.at(-1).action), /Подтверждения сервера нет/);
  assert.equal(h.context.InheritUI.t('Passing generation…'), 'Сохраняем поколение…');
  h.context.InheritUI.setLanguage('en'); assert.match(h.message(), /open page only/); assert.match(h.message(), /Server confirmation is unknown/);
  assert.deepEqual(JSON.parse(h.data.get('inherit-world-v1')), seed(), 'quota failure cannot be mislabeled a durable disk write');
});

await check('existing disabled controls remain disabled after the transaction', async () => {
  const h = harness(); h.node('#inherit-import').disabled = true;
  const pending = h.pass(); response(h.posts()[0], null, 409); await settle(pending); unlocked(h, true);
});

console.log(`SUMMARY ${passed} PASS / 0 FAIL. Real INHERIT handlers; deferred fetch/body/file reads; virtual deadlines. Browser rendering and remote persistence are not asserted.`);
