import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { CORE_TOKEN, RULESET, challengeURL, compatibleService, dailyChallenge, resultCardLines, summarizeResult } from '../public/games/remix/remix-contract.mjs';

const read = path => readFileSync(path, 'utf8');
const html = read('public/games/remix/index.html');
const client = read('public/games/remix/remix-client.js');
const partners = read('public/games/partners/partners.js');
const manifest = read('src/core/manifest.ts');
const checks = [];
function check(name, action) {
  try { action(); checks.push({ name, pass: true }); console.log('PASS', name); }
  catch (error) { checks.push({ name, pass: false, error: error.message }); console.error('FAIL', name, error.message); }
}
const result = { schemaVersion: 1, ruleset: RULESET, won: true, score: 98100, steps: 19, timeMs: 1900, replayHash: 'a'.repeat(64) };

check('browser module parses and is loaded as a module', () => {
  const parsed = spawnSync(process.execPath, ['--check', 'public/games/remix/remix-client.js'], { encoding: 'utf8' });
  assert.equal(parsed.status, 0, parsed.stderr); assert.match(html, /<script type="module" src="remix-client\.js"><\/script>/);
});
check('daily seed uses the UTC calendar across time zones and midnight', () => {
  assert.deepEqual(dailyChallenge(new Date('2026-10-17T12:00:00Z')), { day: '2026-10-17', seed: 20261017 });
  assert.deepEqual(dailyChallenge(new Date('2026-10-18T01:00:00+03:00')), { day: '2026-10-17', seed: 20261017 });
  assert.equal(dailyChallenge(new Date('2026-10-18T00:00:00Z')).seed, 20261018);
});
check('shared challenge URL preserves server identity and discards unrelated query state', () => {
  const url = new URL(challengeURL('https://example.test/games/remix/?temporary=secret#old', 'abc123', 42, 'ref-7'));
  assert.equal(url.origin, 'https://example.test'); assert.equal(url.pathname, '/games/remix/');
  assert.equal(url.searchParams.get('challenge'), 'abc123'); assert.equal(url.searchParams.get('seed'), '42');
  assert.equal(url.searchParams.get('ref'), 'ref-7'); assert.equal(url.searchParams.has('temporary'), false); assert.equal(url.hash, '');
  assert.throws(() => challengeURL(url, '', 42)); assert.throws(() => challengeURL(url, 'id', 1.5));
});
check('share links contain the existing campaign attribution', () => {
  const params = new URL(challengeURL('https://example.test/games/remix/', 'id', 1)).searchParams;
  assert.equal(params.get('utm_source'), 'osgard_remix'); assert.equal(params.get('utm_medium'), 'friend_challenge');
  assert.equal(params.get('utm_campaign'), 'daily_challenge'); assert.equal(params.get('utm_content'), 'id');
});
check('only the explicit authoritative capability is supported', () => {
  const valid = { schemaVersion: 1, service: 'osgard-remix-arena', ruleset: RULESET, auth: 'osgard-core-bearer-v1', playersPerMatch: 1, resultAuthority: 'server-input-journal' };
  assert.equal(compatibleService(valid), true);
  for (const changes of [{ ruleset: 'other' }, { auth: 'anonymous' }, { playersPerMatch: 2 }, { resultAuthority: 'client' }, { schemaVersion: 2 }]) assert.equal(compatibleService({ ...valid, ...changes }), false);
  assert.equal(compatibleService(null), false); assert.equal(CORE_TOKEN, 'osgard:core-session:v1');
});
check('unsupported or incomplete results never manufacture a successful score', () => {
  assert.match(summarizeResult(result), /19 ходов · 98100 очков/);
  for (const changes of [{ score: '98100' }, { steps: 0 }, { steps: 257 }, { timeMs: NaN }, { replayHash: '' }, { ruleset: 'other' }, { won: false }]) assert.throws(() => summarizeResult({ ...result, ...changes }));
  assert.throws(() => summarizeResult({ scores: [{ score: 100 }] }));
  assert.match(summarizeResult({ ...result, won: false, score: 0, steps: 256 }), /Лимит ходов/);
});
check('result-card copy derives from the confirmed summary, seed and challenge', () => {
  const summary = summarizeResult(result), lines = resultCardLines(summary, 'challenge-42', 42);
  assert.equal(lines[2], 'SEED 42'); assert.equal(lines[3], summary); assert.equal(lines[4], 'CHALLENGE challenge-42');
  assert.equal(resultCardLines('Лимит ходов', 'id', 42, false)[1], 'ЛИМИТ ХОДОВ');
  assert.throws(() => resultCardLines('', 'id', 42));
});
check('native link sharing and selectable clipboard fallback remain available', () => {
  assert.ok(client.includes('await navigator.share({ title:')); assert.ok(client.includes('navigator.clipboard.writeText(link)'));
  assert.ok(client.includes("$('#challenge-link').select()"));
  assert.ok(html.includes('id="share-challenge"')); assert.ok(html.includes('id="copy-challenge"'));
});
check('downloadable PNG and native file sharing use the result contract', () => {
  assert.ok(client.includes('canvas.width = 1200; canvas.height = 630'));
  assert.ok(client.includes("'image/png'")); assert.ok(client.includes('canvas.toBlob'));
  assert.ok(client.includes('navigator.canShare?.({ files: [file] })')); assert.ok(client.includes('downloadBlob(blob, filename)'));
  assert.ok(client.includes('resultCardLines(summary, challenge.id, challenge.seed, result.won)'));
});
check('result and sponsor start hidden, with explicit inquiry wording', () => {
  for (const name of ['result-panel', 'sponsor-slot', 'growth-panel', 'result-card-actions']) assert.match(html, new RegExp('id="' + name + '"[^>]*hidden'));
  assert.ok(html.includes('PARTNER SLOT / INQUIRY ONLY')); assert.ok(html.includes('Активная рекламная кампания здесь не представлена'));
  assert.ok(html.includes('utm_medium=post_session')); assert.ok(html.includes('format=Спонсорское%20событие%20или%20уровень'));
});
check('Core credentials stay on the same origin and are separate from optional analytics', () => {
  assert.ok(client.includes("'/api/core/' : '/api/remix/v1/'")); assert.ok(client.includes("credentials: 'omit'"));
  assert.ok(!client.includes('remix-api-url')); assert.ok(!html.includes('id="api-url"'));
  const analytics = client.slice(client.indexOf('function reportEvent('), client.indexOf('async function copyChallengeLink('));
  assert.ok(analytics.includes("localStorage.getItem('osgard.auth.accessToken')")); assert.ok(analytics.includes('if (!analyticsToken) return'));
  assert.ok(analytics.includes("fetch('/api/v1/player/events'")); assert.ok(!analytics.includes('CORE_TOKEN'));
});
check('growth events retain shared types and partner preselection preserves attribution', () => {
  for (const name of ['challenge_created', 'challenge_invite_accepted', 'share_link_copied', 'share_dialog_opened', 'partner_cta_clicked', 'result_card_exported', 'result_card_shared']) { assert.ok(manifest.includes("'" + name + "'"), name); assert.ok(client.includes("'" + name + "'"), name); }
  for (const marker of ['campaignParams', 'formatParam', 'utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'attribution.join']) assert.ok(partners.includes(marker), marker);
});
check('touch controls, readable replay and existing Unity route remain explicit', () => {
  for (const name of ['up', 'down', 'left', 'right']) assert.ok(html.includes('data-remix-move="' + name + '"'));
  assert.ok(html.includes('data-remix-jump')); assert.ok(html.includes('id="replay-step"')); assert.ok(html.includes('href="/games/remix/player/index.html"'));
  assert.ok(html.includes('пошаговая арена')); assert.ok(html.includes('сетевой сервис и результаты не объединены'));
});
check('no third-party ad SDK or active pricing was introduced', () => {
  for (const forbidden of ['googletagmanager', 'doubleclick.net', 'adsbygoogle', 'checkout.stripe.com', 'Buy now for $']) assert.ok(!(html + client).toLowerCase().includes(forbidden.toLowerCase()), forbidden);
});
const report = { version: 'remix-growth-v2', scope: 'Pure contract and static UI checks; real HTTP/browser acceptance are separate gates', passed: checks.filter(check => check.pass).length, failed: checks.filter(check => !check.pass).length, checks };
console.log('SUMMARY', report.passed, 'PASS /', report.failed, 'FAIL');
if (report.failed) process.exitCode = 1;
