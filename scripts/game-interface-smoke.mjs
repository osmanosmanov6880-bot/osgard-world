import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import vm from 'node:vm';

const read = path => readFileSync(path, 'utf8');
const inherit = read('public/games/inherit/index.html');
const remix = read('public/games/remix/index.html');
const unity = read('public/games/remix/player/index.html');
const scripts = html => [...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/g)].map(m => m[1]).filter(s => s.trim());
let passed = 0;
async function check(name, run) { await run(); passed++; console.log('PASS', name); }

class Element {
  constructor() { this.children = []; this.style = {}; this.dataset = {}; this.textContent = ''; this.innerHTML = ''; this.handlers = new Map(); const classes = new Set(); this.classList = { add: v => classes.add(v), remove: v => classes.delete(v), contains: v => classes.has(v), toggle(v, force) { const on = force ?? !classes.has(v); if (on) classes.add(v); else classes.delete(v); return on; } }; }
  appendChild(node) { this.children.push(node); return node; }
  setAttribute(name, value) { this[name] = String(value); }
  addEventListener(name, callback) { this.handlers.set(name, callback); }
  matches() { return false; }
  closest() { return null; }
  querySelectorAll() { return []; }
}
const initial = () => ({ generation: 173, budget: 99, changes: ['planted a young tree'], objects: [{ tool: 'tree', x: 60, y: 40 }], history: [], snapshots: [{ generation: 172, objects: [{ tool: 'stone', x: 20, y: 35 }] }] });
function inheritHarness({ raw, denied = false, quota = false } = {}) {
  const data = new Map(raw === undefined ? [] : [['inherit-world-v1', raw]]), nodes = new Map(), events = new Map();
  const node = selector => { if (!nodes.has(selector)) nodes.set(selector, new Element()); return nodes.get(selector); };
  const localStorage = { getItem(key) { if (denied) throw Error('denied'); return data.get(key) ?? null; }, setItem(key, value) { if (denied || quota) throw Error('quota'); data.set(key, String(value)); }, removeItem(key) { if (denied) throw Error('denied'); data.delete(key); } };
  const context = { localStorage, console, URLSearchParams, URL, setTimeout() {}, clearTimeout() {}, location: { search: '', reload() {} }, document: { querySelector: node, querySelectorAll: () => [], createElement: () => new Element(), head: { insertAdjacentHTML() {} }, body: new Element(), addEventListener: (name, fn) => { const list = events.get(name) || []; list.push(fn); events.set(name, list); } }, addEventListener() {}, fetch: async () => ({ ok: false, status: 503 }) };
  context.window = context; vm.createContext(context); vm.runInContext(scripts(inherit)[0], context);
  return { context, node, data, events, run: code => vm.runInContext(code, context) };
}

await check('every game and launcher script parses', () => {
  for (const html of [inherit, remix, unity]) for (const source of scripts(html)) new vm.Script(source);
  for (const game of ['inherit', 'remix']) new vm.Script(read(`public/games/${game}/interface.js`));
});
await check('INHERIT restores a valid world without changing it', () => {
  const raw = JSON.stringify(initial()), h = inheritHarness({ raw });
  assert.equal(h.run('JSON.stringify(S)'), raw); assert.equal(h.data.get('inherit-world-v1'), raw);
  assert.equal(h.run('gameStorage.recovered'), false); assert.equal(h.run('gameStorage.ephemeral'), false);
});
await check('malformed JSON, null, and invalid world shapes recover with original data retained', () => {
  for (const raw of ['{broken', 'null', '[]', JSON.stringify({ ...initial(), objects: null }), JSON.stringify({ ...initial(), snapshots: [null] })]) {
    const h = inheritHarness({ raw }); assert.equal(h.run('S.generation'), 173); assert.equal(h.run('gameStorage.recovered'), true);
    assert.equal(h.data.get('inherit-world-recovery-v1'), raw); assert.equal(h.run('S.history.length'), 4);
  }
});
await check('denied storage still boots and preserves changes during the open session', () => {
  const h = inheritHarness({ denied: true }); assert.equal(h.run('gameStorage.ephemeral'), true);
  h.run('S.budget=77;persist()'); assert.equal(h.run("JSON.parse(gameStorage.getItem('inherit-world-v1')).budget"), 77);
  h.run("gameStorage.removeItem('inherit-world-v1')"); assert.equal(h.run("gameStorage.getItem('inherit-world-v1')"), null);
});
await check('quota failure cannot roll back the in-memory save; optional null records recover', () => {
  const h = inheritHarness({ raw: JSON.stringify(initial()), quota: true });
  h.run('S.budget=82;persist()'); assert.equal(h.run("JSON.parse(gameStorage.getItem('inherit-world-v1')).budget"), 82);
  assert.equal(h.run('gameStorage.ephemeral'), true);
  for (const value of ['null', '[]', '3', '{bad']) { h.run(`gameStorage.setItem('inherit-journey',${JSON.stringify(value)})`); assert.equal(h.run("JSON.stringify(gameStorage.readObject('inherit-journey'))"), '{}'); }
});
await check('Tab, Escape, arrows, and shortcuts cannot change the selected trace', () => {
  const h = inheritHarness(), hotkeys = scripts(inherit).find(s => s.includes('const traceHotkeys=')); h.run(hotkeys);
  for (const key of ['Tab', 'Escape', 'Enter', 'ArrowLeft', 'h', 'z']) { for (const fn of h.events.get('keydown')) fn({ key, target: new Element() }); assert.equal(h.run('tool'), 'tree', key); }
  for (const fn of h.events.get('keydown')) fn({ key: '6', target: new Element() }); assert.equal(h.run('tool'), 'arch');
  for (const fn of h.events.get('keydown')) fn({ key: '3', ctrlKey: true, target: new Element() }); assert.equal(h.run('tool'), 'arch');
});
await check('offline handoff still advances exactly one generation and retains its objects', async () => {
  const h = inheritHarness({ denied: true });
  h.run(scripts(inherit).find(s => s.includes('function returnToToday()')));
  h.run("S.objects=[{tool:'tree',x:55,y:30}];S.pending=[{type:'tree',x:55,y:30}];S.changes=['planted a young tree'];S.budget=99");
  await h.node('#pass').onclick();
  assert.equal(h.run('S.generation'), 174); assert.equal(h.run('S.pending.length'), 0); assert.equal(h.run('S.budget'), 100);
  assert.equal(h.run('S.objects.length'), 1); assert.equal(h.run('S.snapshots.at(-1).generation'), 173);
  assert.equal(h.run("JSON.parse(gameStorage.getItem('inherit-world-v1')).generation"), 174);
});

function languageHarness(game, search = '', stored) {
  const data = new Map(stored ? [['osgard:game-language', stored]] : []);
  const context = { URLSearchParams, URL, console, location: { search, href: `https://osgard.world/games/${game}/${search}` }, history: { replaceState() {} }, document: { readyState: 'loading', addEventListener() {}, documentElement: {} } };
  context.window = context; context[game === 'inherit' ? 'InheritPersistence' : 'RemixPersistence'] = { getItem: key => data.get(key), setItem: (key, value) => data.set(key, value) };
  vm.createContext(context);
  // Expose only in this VM the actual private node translator for reversible-language testing.
  const source = read(`public/games/${game}/interface.js`).replace('getLanguage:()=>locale,updateStorage}', 'getLanguage:()=>locale,updateStorage,testTextNode:textNode}');
  vm.runInContext(source, context); return { ui: context[game === 'inherit' ? 'InheritUI' : 'RemixUI'], context, data };
}
await check('RU is the default; explicit and saved EN remain selectable without a reload', () => {
  for (const game of ['inherit', 'remix']) {
    assert.equal(languageHarness(game).ui.getLanguage(), 'ru'); assert.equal(languageHarness(game, '?lang=en').ui.getLanguage(), 'en');
    assert.equal(languageHarness(game, '', 'en').ui.getLanguage(), 'en'); assert.equal(languageHarness(game, '?lang=ru', 'en').ui.getLanguage(), 'ru');
    const h = languageHarness(game), source = game === 'inherit' ? 'Pass this world on →' : 'Create daily challenge';
    const node = { nodeValue: source, parentElement: { closest: () => null } }; h.ui.testTextNode(node); assert.notEqual(node.nodeValue, source);
    h.ui.setLanguage('en'); h.ui.testTextNode(node); assert.equal(node.nodeValue, source); assert.equal(h.data.get('osgard:game-language'), 'en');
    node.nodeValue = game === 'inherit' ? 'World passed on — a new generation begins' : 'Match active'; h.ui.testTextNode(node);
    h.ui.setLanguage('ru'); h.ui.testTextNode(node); assert.match(node.nodeValue, /[А-Яа-я]/);
  }
});
await check('dynamic milestones, errors, and temporary-storage disclosures translate correctly', () => {
  const i = languageHarness('inherit'), r = languageHarness('remix');
  assert.equal(i.ui.t('Generation 173 carries 4 recorded traces.'), 'Поколение 173 · записей в истории: 4');
  assert.equal(i.ui.t('Leave 2 more kinds of trace'), 'Добавьте ещё видов следов: 2');
  i.context.InheritPersistence.ephemeral = true; assert.match(i.ui.t('Your offline lineage is safe on this device.'), /открытой странице/);
  assert.match(r.ui.t('Connection error: The match service is unavailable. Try again later.'), /Игровой сервис недоступен/);
  assert.equal(r.ui.t('RUNNING · 2 player(s) · 12 replay frames'), 'Матч идёт · игроков: 2 · кадров повтора: 12');
  assert.ok(!r.ui.t('UNRECOGNIZED · 2 player(s) · 12 replay frames').includes('undefined'));
  assert.equal(r.ui.t('2 player(s) · 12 accepted input frames'), 'Игроков: 2 · принятых команд: 12');
  assert.equal(r.ui.t('28 s left in this phase'), 'Осталось в этой фазе: 28 с');
  assert.equal(r.ui.t('Server position · X -0.25 · Y 1.50'), 'Позиция на сервере · X -0.25 · Y 1.50');
  assert.match(r.ui.t('The result has not loaded yet. Your match is retained; reconnecting…'), /Результат пока не загрузился/);
  assert.match(r.ui.t('This browser cannot save session recovery. Keep this page open; reloading may lose access to this match.'), /восстановления сессии/);
});
await check('REMIX API preserves routes and rejects HTML errors with readable messages', async () => {
  const source = remix.slice(remix.indexOf('async function api(path, options){'), remix.indexOf('\nasync function start('));
  const calls = [], timers = [];
  const context = { AbortController, Error, connectionBase: '/api/remix', requests: new Set(), apiInput: { value: '/api/remix' }, setTimeout(fn) { timers.push(fn); return timers.length; }, clearTimeout() {}, fetch: async (url, options) => { calls.push([url, options]); return { ok: true, json: async () => ({ id: 'sample' }) }; } };
  vm.createContext(context); vm.runInContext(source, context);
  assert.equal((await vm.runInContext("api('/v1/matches', {method:'POST'})", context)).id, 'sample'); assert.equal(calls[0][0], '/api/remix/v1/matches'); assert.equal(calls[0][1].method, 'POST');
  context.fetch = async () => ({ ok: false, status: 503, text() { throw Error('raw body must not be rendered'); } });
  await assert.rejects(vm.runInContext("api('/v1/matches')", context), /match service is unavailable/);
  context.fetch = async () => ({ ok: true, json: async () => { throw Error('HTML received'); } });
  await assert.rejects(vm.runInContext("api('/v1/matches')", context), /invalid response/);
  context.fetch = (_url, { signal }) => new Promise((_resolve, reject) => signal.addEventListener('abort', () => { const e = Error('aborted'); e.name = 'AbortError'; reject(e); }));
  const pending = vm.runInContext("api('/v1/matches')", context); timers.at(-1)(); await assert.rejects(pending, /too long/);
});
await check('REMIX input listens on its field and respects modifier shortcuts', () => {
  const source = scripts(remix).find(s => s.includes("arena.addEventListener('keydown'")); const line = source.split('\n').find(s => s.startsWith("arena.addEventListener('keydown'"));
  const arena = new Element(), sent = []; const context = { arena, match: null, canSubmitInput: () => Boolean(context.match), send: (...args) => sent.push(args) }; vm.createContext(context); vm.runInContext(line, context);
  const keydown = arena.handlers.get('keydown'); let prevented = 0;
  keydown({ key: 'ArrowLeft', preventDefault() { prevented++; } }); assert.equal(sent.length, 0);
  context.match = {}; keydown({ key: 'ArrowRight', preventDefault() { prevented++; } }); assert.deepEqual(sent[0], [1, 0, false]); assert.equal(prevented, 1);
  keydown({ key: 'a', ctrlKey: true, preventDefault() { throw Error('must not swallow select-all'); } }); assert.equal(sent.length, 1);
  assert.ok(!remix.includes("window.addEventListener('keydown'"));
});
await check('Unity launcher keeps export URLs, accessible controls, and error recovery', () => {
  assert.ok(!unity.includes('user-scalable=no')); assert.match(unity, /<button id="unity-fullscreen-button"[^>]*aria-label=/); assert.match(unity, /<canvas[^>]*tabindex="0"/);
  assert.ok(unity.includes('script.onerror')); assert.ok(unity.includes('id="player-retry"')); assert.ok(unity.includes('aria-valuenow'));
  for (const ext of ['data', 'framework.js', 'wasm']) {
    assert.ok(unity.includes(`"/REMIX-webgl3.${ext}"`)); const file = `public/games/remix/player/Build/REMIX-webgl3.${ext}.gz`; assert.ok(existsSync(file)); assert.equal(readFileSync(file).subarray(0, 2).toString('hex'), '1f8b');
  }
});
await check('INHERIT offline shell includes the interface and preserves unrelated product caches', () => {
  const sw = read('public/games/inherit/sw.js');
  assert.ok(sw.includes("key.startsWith('inherit-shell-')")); assert.ok(sw.includes("request.mode === 'navigate'"));
  for (const asset of ['interface.js', 'interface.css']) assert.ok(sw.includes('/games/inherit/' + asset));
});
console.log(`SUMMARY ${passed} PASS / 0 FAIL. These checks execute game storage, handoff, input and request handlers. WebGL and visual layout require browser/device verification.`);
