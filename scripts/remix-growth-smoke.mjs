import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import vm from 'node:vm';
import { CORE_TOKEN, RULESET, challengeURL, compatibleService, dailyChallenge, resultCardLines, summarizeResult } from '../public/games/remix/remix-contract.mjs';

const read = path => readFileSync(path, 'utf8');
const html = read('public/games/remix/index.html');
const client = read('public/games/remix/remix-client.js');
const partners = read('public/games/partners/partners.js');
const manifest = read('src/core/manifest.ts');
const checks = [];
async function check(name, action) {
  try { await action(); checks.push({ name, pass: true }); console.log('PASS', name); }
  catch (error) { checks.push({ name, pass: false, error: error.message }); console.error('FAIL', name, error.message); }
}
const result = { schemaVersion: 1, ruleset: RULESET, won: true, score: 98100, steps: 19, timeMs: 1900, replayHash: 'a'.repeat(64) };

await check('browser module parses and is loaded as a module', () => {
  const parsed = spawnSync(process.execPath, ['--check', 'public/games/remix/remix-client.js'], { encoding: 'utf8' });
  assert.equal(parsed.status, 0, parsed.stderr); assert.match(html, /<script type="module" src="remix-client\.js"><\/script>/);
});
await check('daily seed uses the UTC calendar across time zones and midnight', () => {
  assert.deepEqual(dailyChallenge(new Date('2026-10-17T12:00:00Z')), { day: '2026-10-17', seed: 20261017 });
  assert.deepEqual(dailyChallenge(new Date('2026-10-18T01:00:00+03:00')), { day: '2026-10-17', seed: 20261017 });
  assert.equal(dailyChallenge(new Date('2026-10-18T00:00:00Z')).seed, 20261018);
});
await check('shared challenge URL preserves server identity and discards unrelated query state', () => {
  const url = new URL(challengeURL('https://example.test/games/remix/?temporary=secret#old', 'abc123', 42, 'ref-7'));
  assert.equal(url.origin, 'https://example.test'); assert.equal(url.pathname, '/games/remix/');
  assert.equal(url.searchParams.get('challenge'), 'abc123'); assert.equal(url.searchParams.get('seed'), '42');
  assert.equal(url.searchParams.get('ref'), 'ref-7'); assert.equal(url.searchParams.has('temporary'), false); assert.equal(url.hash, '');
  assert.throws(() => challengeURL(url, '', 42)); assert.throws(() => challengeURL(url, 'id', 1.5));
});
await check('share links contain the existing campaign attribution', () => {
  const params = new URL(challengeURL('https://example.test/games/remix/', 'id', 1)).searchParams;
  assert.equal(params.get('utm_source'), 'osgard_remix'); assert.equal(params.get('utm_medium'), 'friend_challenge');
  assert.equal(params.get('utm_campaign'), 'daily_challenge'); assert.equal(params.get('utm_content'), 'id');
});
await check('only the explicit authoritative capability is supported', () => {
  const valid = { schemaVersion: 1, service: 'osgard-remix-arena', ruleset: RULESET, auth: 'osgard-core-bearer-v1', playersPerMatch: 1, resultAuthority: 'server-input-journal' };
  assert.equal(compatibleService(valid), true);
  for (const changes of [{ ruleset: 'other' }, { auth: 'anonymous' }, { playersPerMatch: 2 }, { resultAuthority: 'client' }, { schemaVersion: 2 }]) assert.equal(compatibleService({ ...valid, ...changes }), false);
  assert.equal(compatibleService(null), false); assert.equal(CORE_TOKEN, 'osgard:core-session:v1');
});
await check('unsupported or incomplete results never manufacture a successful score', () => {
  assert.match(summarizeResult(result), /19 ходов · 98100 очков/);
  for (const changes of [{ score: '98100' }, { steps: 0 }, { steps: 257 }, { timeMs: NaN }, { replayHash: '' }, { ruleset: 'other' }, { won: false }]) assert.throws(() => summarizeResult({ ...result, ...changes }));
  assert.throws(() => summarizeResult({ scores: [{ score: 100 }] }));
  assert.match(summarizeResult({ ...result, won: false, score: 0, steps: 256 }), /Лимит ходов/);
});
await check('result-card copy derives from the confirmed summary, seed and challenge', () => {
  const summary = summarizeResult(result), lines = resultCardLines(summary, 'challenge-42', 42);
  assert.equal(lines[2], 'SEED 42'); assert.equal(lines[3], summary); assert.equal(lines[4], 'CHALLENGE challenge-42');
  assert.equal(resultCardLines('Лимит ходов', 'id', 42, false)[1], 'ЛИМИТ ХОДОВ');
  assert.throws(() => resultCardLines('', 'id', 42));
});
await check('native link sharing and selectable clipboard fallback remain available', () => {
  assert.ok(client.includes('await navigator.share({ title:')); assert.ok(client.includes('navigator.clipboard.writeText(link)'));
  assert.ok(client.includes("$('#challenge-link').select()"));
  assert.ok(html.includes('id="share-challenge"')); assert.ok(html.includes('id="copy-challenge"'));
});
await check('downloadable PNG and native file sharing use the result contract', () => {
  assert.ok(client.includes('canvas.width = 1200; canvas.height = 630'));
  assert.ok(client.includes("'image/png'")); assert.ok(client.includes('canvas.toBlob'));
  assert.ok(client.includes('navigator.canShare?.({ files: [file] })')); assert.ok(client.includes('downloadBlob(blob, filename)'));
  assert.ok(client.includes('resultCardLines(summary, challenge.id, challenge.seed, result.won)'));
});
await check('result and sponsor start hidden, with explicit inquiry wording', () => {
  for (const name of ['result-panel', 'sponsor-slot', 'growth-panel', 'result-card-actions']) assert.match(html, new RegExp('id="' + name + '"[^>]*hidden'));
  assert.ok(html.includes('PARTNER SLOT / INQUIRY ONLY')); assert.ok(html.includes('Активная рекламная кампания здесь не представлена'));
  assert.ok(html.includes('utm_medium=post_session')); assert.ok(html.includes('format=Спонсорское%20событие%20или%20уровень'));
});
await check('Core credentials stay on the same origin and are separate from optional analytics', async () => {
  const diagnostic = html.match(/<input\b[^>]*\bid="api-url"[^>]*>/g);
  assert.equal(diagnostic?.length, 1, 'There is one diagnostic endpoint field');
  assert.match(diagnostic[0], /\breadonly(?:\s|=|>)/, 'The endpoint is not user-editable');
  assert.match(diagnostic[0], /\bvalue="\/api\/remix\/v1\/"/);
  assert.ok(!client.includes('remix-api-url')); assert.ok(!client.includes('api-url'), 'The client must not obtain a request base from the diagnostic DOM');
  const requestBegin = client.indexOf('class RequestError extends Error {');
  const requestEnd = client.indexOf('\nfunction syncControls()', requestBegin);
  const analyticsBegin = client.indexOf('function reportEvent(');
  const analyticsEnd = client.indexOf('\nasync function copyChallengeLink(', analyticsBegin);
  assert.ok(requestBegin >= 0 && requestEnd > requestBegin && analyticsBegin >= 0 && analyticsEnd > analyticsBegin, 'Execute the actual request and analytics implementations');
  const calls = [], storageKeys = [], timers = [], origin = 'https://arena.example.test';
  const coreToken = 'vm-only-core-session', analyticsToken = 'vm-only-analytics-session';
  let storedAnalytics = '', diagnosticValue = '', diagnosticReads = 0, storageDenied = false;
  const endpointNode = { get value() { diagnosticReads++; return diagnosticValue; } };
  const context = {
    AbortController, Error, token: coreToken, location: { origin },
    document: { querySelector: () => endpointNode }, $: () => endpointNode,
    sessionStorage: { getItem() { throw Error('Neither request nor analytics may reread a Core credential from storage'); } },
    localStorage: { getItem(key) { storageKeys.push(key); if (storageDenied) throw Error('denied'); assert.equal(key, 'osgard.auth.accessToken'); return storedAnalytics; } },
    crypto: { randomUUID: () => 'vm-only-event-id' },
    setTimeout(fn) { timers.push(fn); return timers.length; }, clearTimeout() {},
    fetch: async (url, options) => { calls.push({ url: new URL(url, origin), options }); return { ok: true, status: 200, headers: { get: () => 'application/json' }, json: async () => ({ accepted: true }) }; },
  };
  vm.createContext(context);
  vm.runInContext(client.slice(requestBegin, requestEnd) + '\n' + client.slice(analyticsBegin, analyticsEnd), context);
  for (const value of ['https://other.invalid/api', '//other.invalid/api', '/api/v1/player/events', '']) {
    diagnosticValue = value;
    await vm.runInContext("request('matches', {body:{challengeId:'vm-challenge'},key:'vm-idempotency-key'})", context);
    const call = calls.at(-1);
    assert.equal(call.url.origin, origin); assert.equal(call.url.pathname, '/api/remix/v1/matches');
    assert.equal(call.options.method, 'POST'); assert.equal(call.options.credentials, 'omit');
    assert.equal(call.options.headers.Authorization, 'Bearer ' + coreToken);
    assert.equal(call.options.headers['Idempotency-Key'], 'vm-idempotency-key');
    assert.deepEqual(JSON.parse(call.options.body), { challengeId: 'vm-challenge' });
  }
  assert.equal(diagnosticReads, 0, 'Changing diagnostic values cannot affect request routing');
  await vm.runInContext("request('auth/me', {core:true})", context);
  assert.equal(calls.at(-1).url.origin, origin); assert.equal(calls.at(-1).url.pathname, '/api/core/auth/me');
  assert.equal(calls.at(-1).options.headers.Authorization, 'Bearer ' + coreToken);
  await vm.runInContext("request('capabilities', {anonymous:true})", context);
  assert.equal(calls.at(-1).url.pathname, '/api/remix/v1/capabilities'); assert.equal(calls.at(-1).options.credentials, 'omit');
  assert.equal(calls.at(-1).options.headers.Authorization, undefined, 'Anonymous capability checks must not carry a Core token');
  const beforeAnalytics = calls.length;
  vm.runInContext("reportEvent('challenge_created', {challengeId:'vm-challenge'})", context);
  assert.equal(calls.length, beforeAnalytics, 'A Core session alone cannot authorize analytics');
  storedAnalytics = analyticsToken;
  vm.runInContext("reportEvent('challenge_created', {challengeId:'vm-challenge'})", context);
  assert.equal(calls.length, beforeAnalytics + 1);
  const event = calls.at(-1);
  assert.equal(event.url.origin, origin); assert.equal(event.url.pathname, '/api/v1/player/events');
  assert.equal(event.options.headers.authorization, 'Bearer ' + analyticsToken); assert.equal(event.options.headers.Authorization, undefined);
  assert.ok(!JSON.stringify(event.options).includes(coreToken), 'No Core credential may reach analytics headers or payload');
  assert.equal(JSON.parse(event.options.body).event.name, 'challenge_created');
  storageDenied = true;
  vm.runInContext("reportEvent('challenge_created', {challengeId:'vm-challenge'})", context);
  assert.equal(calls.length, beforeAnalytics + 1, 'Unavailable analytics storage must not fall back to the Core session');
  assert.ok(storageKeys.length > 0 && storageKeys.every(key => key === 'osgard.auth.accessToken'));
});
await check('growth events retain shared types and partner preselection preserves attribution', () => {
  for (const name of ['challenge_created', 'challenge_invite_accepted', 'share_link_copied', 'share_dialog_opened', 'partner_cta_clicked', 'result_card_exported', 'result_card_shared']) { assert.ok(manifest.includes("'" + name + "'"), name); assert.ok(client.includes("'" + name + "'"), name); }
  for (const marker of ['campaignParams', 'formatParam', 'utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'attribution.join']) assert.ok(partners.includes(marker), marker);
});
await check('touch controls, readable replay and existing Unity route remain explicit', () => {
  for (const name of ['up', 'down', 'left', 'right']) assert.ok(html.includes('data-remix-move="' + name + '"'));
  assert.ok(html.includes('data-remix-jump')); assert.ok(html.includes('id="replay-step"')); assert.ok(html.includes('href="/games/remix/player/index.html"'));
  assert.ok(html.includes('пошаговая арена')); assert.ok(html.includes('сетевой сервис и результаты не объединены'));
});
await check('no third-party ad SDK or active pricing was introduced', () => {
  for (const forbidden of ['googletagmanager', 'doubleclick.net', 'adsbygoogle', 'checkout.stripe.com', 'Buy now for $']) assert.ok(!(html + client).toLowerCase().includes(forbidden.toLowerCase()), forbidden);
});
const report = { version: 'remix-growth-v2', scope: 'Contract, actual client-handler and static UI checks; real HTTP/browser acceptance are separate gates', passed: checks.filter(check => check.pass).length, failed: checks.filter(check => !check.pass).length, checks };
console.log('SUMMARY', report.passed, 'PASS /', report.failed, 'FAIL');
if (report.failed) process.exitCode = 1;
