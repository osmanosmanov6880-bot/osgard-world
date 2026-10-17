import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { mkdir, writeFile } from 'node:fs/promises';
import { chromium, devices } from 'playwright';

const bases = JSON.parse(process.env.OSGARD_REMIX_UI_BASES || '{}');
for (const name of ['normal', 'disabled', 'incompatible', 'lost-response', 'lost-create', 'lost-match', 'state-retry', 'state-reload', 'poll-touch', 'poll-rematch']) {
  const base = new URL(bases[name]);
  assert.equal(base.protocol, 'http:'); assert.equal(base.hostname, '127.0.0.1'); assert.ok(base.port);
}
const out = process.argv[process.argv.indexOf('--out') + 1];
assert.ok(out && out !== process.argv[0]); await mkdir(out, { recursive: true });
const browser = await chromium.launch({ headless: true });
const checks = [];
const only = process.argv.includes('--only') ? process.argv[process.argv.indexOf('--only') + 1] : null;
async function check(name, action) {
  if (only && !name.startsWith(only + '-')) return;
  const context = await browser.newContext({ ...devices['iPhone 13'] });
  const page = await context.newPage(); page.setDefaultTimeout(15000);
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  try { const details = await action(page, context); assert.deepEqual(errors, []); checks.push({ name, passed: true, ...details }); console.log('PASS', name); }
  catch (error) { checks.push({ name, passed: false, error: String(error.message) }); await page.screenshot({ path: out + '/' + name + '-failed.png', fullPage: true }).catch(() => {}); console.error('FAIL', name, error.message); }
  finally { await context.close(); }
}
async function createRun(page, base, credentials = { username: 'remix-poll-' + randomBytes(5).toString('hex'), password: randomBytes(24).toString('base64url') }) {
  await page.goto(base + '/games/remix/arena/'); await page.locator('#auth-panel').waitFor({ state: 'visible' });
  await page.locator('#remix-username').fill(credentials.username);
  await page.locator('#remix-password').fill(credentials.password); await page.locator('#register-player').tap();
  await page.waitForFunction(() => !document.querySelector('#start-match').disabled); await page.locator('#start-match').tap();
  await page.waitForFunction(() => Boolean(document.querySelector('#arena').dataset.state));
  return page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state));
}
function pathToGoal(level, start) {
  const blocks = new Set(level.objects.filter(item => item.kind !== 'goal').map(item => item.x + ',' + item.y));
  const goal = level.objects.find(item => item.kind === 'goal');
  const queue = [[start, []]], visited = new Set([start.join(',')]);
  for (const [[x, y], path] of queue) {
    if (x === goal.x && y === goal.y) return path;
    for (const [dx, dy, name] of [[1, 0, 'right'], [0, 1, 'down'], [0, -1, 'up'], [-1, 0, 'left']]) {
      const next = [x + dx, y + dy], key = next.join(',');
      if (next[0] >= 0 && next[0] < 12 && next[1] >= 0 && next[1] < 7 && !blocks.has(key) && !visited.has(key)) { visited.add(key); queue.push([next, [...path, name]]); }
    }
  }
  throw Error('The actual server arena has no safe walking route.');
}
try {
  await check('history-restores-after-browser-storage-loss-and-keeps-accounts-separate', async page => {
    const credentials = { username: 'remix-history-' + randomBytes(5).toString('hex'), password: randomBytes(24).toString('base64url') };
    const creations = [];
    page.on('request', request => { if (request.method() === 'POST' && new URL(request.url()).pathname === '/api/core/remix/v1/matches') creations.push(request.url()); });
    const original = await createRun(page, bases.normal, credentials);
    await page.waitForFunction(() => !document.querySelector('[data-remix-move="right"]').disabled);
    await page.locator('[data-remix-move="right"]').tap();
    await page.waitForFunction(() => JSON.parse(document.querySelector('#arena').dataset.state).sequence === 1);
    const saved = await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state));
    await page.evaluate(() => sessionStorage.clear()); await page.reload();
    await page.locator('#auth-panel').waitFor({ state: 'visible' });
    await page.locator('#remix-username').fill(credentials.username); await page.locator('#remix-password').fill(credentials.password);
    await page.locator('#auth-form button[type="submit"]').tap();
    const resume = page.locator('[data-history-match="' + original.id + '"]'); await resume.waitFor({ state: 'visible' });
    assert.equal(await page.locator('#arena').getAttribute('data-state'), null, 'History metadata cannot become an authoritative playing state');
    await resume.tap();
    await page.waitForFunction(id => JSON.parse(document.querySelector('#arena').dataset.state || 'null')?.id === id, original.id);
    assert.deepEqual(await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state)), saved);
    await page.waitForFunction(() => !document.querySelector('[data-remix-move="right"]').disabled);
    await page.locator('[data-remix-move="right"]').tap();
    await page.waitForFunction(() => JSON.parse(document.querySelector('#arena').dataset.state).sequence === 2);
    assert.equal(creations.length, 1, 'Opening history must not create a replacement run');
    const reference = await page.evaluate(() => JSON.parse(sessionStorage.getItem('osgard:remix-client:v1')));
    assert.equal(reference.matchId, original.id);
    await page.screenshot({ path: out + '/history-mobile-resumed.png', fullPage: true });
    await page.evaluate(() => sessionStorage.clear()); await page.reload();
    await page.locator('#auth-panel').waitFor({ state: 'visible' });
    await page.locator('#remix-username').fill('remix-other-' + randomBytes(5).toString('hex')); await page.locator('#remix-password').fill(randomBytes(24).toString('base64url'));
    await page.locator('#register-player').tap();
    await page.waitForFunction(() => document.querySelector('#history-status').textContent === 'Незавершённых заездов пока нет.');
    assert.equal(await page.locator('[data-history-match]').count(), 0);
    const denied = await page.evaluate(async matchId => {
      const response = await fetch('/api/core/remix/v1/matches/' + matchId + '/state', { headers: { Authorization: 'Bearer ' + sessionStorage.getItem('osgard:core-session:v1') } });
      return response.status;
    }, original.id);
    assert.equal(denied, 404);
    return { restoredSequence: saved.sequence, continuedSequence: 2, matchCreations: creations.length, otherAccountDenied: true };
  });
  await check('history-keyset-pagination-keeps-distinct-runs', async page => {
    const original = await createRun(page, bases.normal);
    const extra = await page.evaluate(async () => {
      const title = '🧭'.repeat(100);
      const headers = { Authorization: 'Bearer ' + sessionStorage.getItem('osgard:core-session:v1'), 'Content-Type': 'application/json' };
      const challengeResponse = await fetch('/api/core/remix/v1/challenges', { method: 'POST', headers: { ...headers, 'Idempotency-Key': crypto.randomUUID() }, body: JSON.stringify({ title, seed: 41723, mode: 'speed', visibility: 'public' }) });
      if (!challengeResponse.ok) throw Error('The maximum Unicode title must be accepted by the actual server');
      const challengeId = (await challengeResponse.json()).id;
      const ids = [];
      for (let i = 0; i < 20; i++) {
        const response = await fetch('/api/core/remix/v1/matches', { method: 'POST', headers: { Authorization: 'Bearer ' + sessionStorage.getItem('osgard:core-session:v1'), 'Content-Type': 'application/json', 'Idempotency-Key': crypto.randomUUID() }, body: JSON.stringify({ challengeId, maxPlayers: 1 }) });
        if (!response.ok) throw Error('Real fixture run was rejected'); ids.push((await response.json()).id);
      }
      return { ids, title };
    });
    await page.evaluate(() => sessionStorage.removeItem('osgard:remix-client:v1')); await page.reload();
    await page.locator('#history-next').waitFor({ state: 'visible' });
    assert.equal(await page.locator('[data-history-match]').count(), 20);
    await page.waitForFunction(() => !document.querySelector('#history-next').disabled); await page.locator('#history-next').tap();
    await page.waitForFunction(() => document.querySelectorAll('[data-history-match]').length === 21);
    const ids = await page.locator('[data-history-match]').evaluateAll(buttons => buttons.map(button => button.dataset.historyMatch));
    assert.deepEqual(ids.toSorted(), [original.id, ...extra.ids].toSorted());
    assert.equal(await page.locator('#history-list strong').evaluateAll((titles, expected) => titles.filter(node => node.textContent === expected).length, extra.title), 20, 'History accepts the same 100 Unicode code points as the server');
    assert.ok(await page.locator('#history-next').isHidden());
    const bounds = await page.locator('#history-list').evaluate(list => ({ height: list.getBoundingClientRect().height, scroll: list.scrollHeight }));
    assert.ok(bounds.height <= 361 && bounds.scroll > bounds.height, 'Long histories stay inside a scrollable panel');
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
    return { distinctRuns: ids.length, pageSize: 20, accountPaginationVerified: true, maximumUnicodeTitleVerified: true };
  });
  await check('history-completed-result-and-replay-open-without-new-run', async page => {
    const creations = [];
    page.on('request', request => { if (request.method() === 'POST' && new URL(request.url()).pathname === '/api/core/remix/v1/matches') creations.push(request.url()); });
    const original = await createRun(page, bases.normal);
    for (const direction of pathToGoal(original.arena, original.position)) {
      const sequence = await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state).sequence);
      await page.waitForFunction(() => !document.querySelector('[data-remix-move="right"]').disabled);
      await page.locator('[data-remix-move="' + direction + '"]').tap();
      await page.waitForFunction(previous => JSON.parse(document.querySelector('#arena').dataset.state).sequence === previous + 1, sequence);
    }
    await page.locator('#result-panel').waitFor({ state: 'visible' });
    const result = await page.locator('#result-panel').evaluate(panel => JSON.parse(panel.dataset.result));
    await page.evaluate(() => sessionStorage.removeItem('osgard:remix-client:v1')); await page.reload();
    await page.locator('#run-history').waitFor({ state: 'visible' });
    await page.waitForFunction(() => !document.querySelector('[data-history-status="complete"]').disabled);
    await page.locator('[data-history-status="complete"]').tap();
    await page.locator('[data-history-match="' + original.id + '"]').waitFor({ state: 'visible' });
    await page.locator('[data-history-match="' + original.id + '"]').tap();
    await page.locator('#result-panel').waitFor({ state: 'visible' });
    assert.deepEqual(await page.locator('#result-panel').evaluate(panel => JSON.parse(panel.dataset.result)), result);
    await page.waitForFunction(() => !document.querySelector('#show-replay').disabled); await page.locator('#show-replay').tap();
    await page.locator('#replay-panel').waitFor({ state: 'visible' });
    assert.equal(await page.locator('#replay-step').getAttribute('max'), String(result.steps));
    assert.equal(creations.length, 1);
    return { sameCompletedResult: true, replaySteps: result.steps, matchCreations: creations.length };
  });
  await check('history-expiry-waits-for-real-committed-input-acknowledgement', async page => {
    const credentials = { username: 'remix-history-race-' + randomBytes(5).toString('hex'), password: randomBytes(24).toString('base64url') };
    const mutations = [];
    page.on('request', request => { if (request.method() === 'POST' && new URL(request.url()).pathname.startsWith('/api/core/remix/v1/')) mutations.push(new URL(request.url()).pathname); });
    const original = await createRun(page, bases.normal, credentials);
    await page.locator('[data-history-match="' + original.id + '"]').waitFor({ state: 'visible' });
    await page.waitForFunction(() => !document.querySelector('#history-refresh').disabled);
    const historyGate = Promise.withResolvers(), inputGate = Promise.withResolvers(), committed = Promise.withResolvers();
    let deadline;
    const historyRoute = '**/api/core/remix/v1/matches?*', inputRoute = '**/api/core/remix/v1/matches/*/input';
    await page.route(historyRoute, async route => {
      await historyGate.promise;
      // Explicit negative fixture: the only fabricated response is a 401.
      await route.fulfill({ status: 401, contentType: 'application/json', body: JSON.stringify({ error: { code: 'session', message: 'Проверочная ошибка сессии истории.' } }) });
    });
    await page.route(inputRoute, async route => {
      try {
        const response = await route.fetch();
        committed.resolve({ status: response.status(), body: await response.json() });
        await inputGate.promise;
        // Deliver the real, already committed server response unchanged.
        await route.fulfill({ response });
      } catch (error) { committed.reject(error); await route.abort().catch(() => {}); }
    });
    try {
      const historyRequest = page.waitForRequest(request => request.method() === 'GET' && new URL(request.url()).pathname === '/api/core/remix/v1/matches');
      await page.locator('#history-refresh').tap(); await historyRequest;
      await page.waitForFunction(() => !document.querySelector('[data-remix-move="right"]').disabled);
      await page.locator('[data-remix-move="right"]').tap();
      const accepted = await Promise.race([committed.promise, new Promise((_, reject) => { deadline = setTimeout(() => reject(Error('Real input did not commit in time')), 15000); })]);
      clearTimeout(deadline); assert.equal(accepted.status, 200); assert.equal(accepted.body.state.sequence, 1);
      historyGate.resolve();
      await page.waitForFunction(() => document.querySelector('#history-status').textContent === 'Проверочная ошибка сессии истории.');
      assert.ok(await page.locator('#auth-panel').isHidden(), 'A background rejection waits for the foreground acknowledgement');
      assert.equal(await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state).sequence), 0);
      const pending = await page.evaluate(() => JSON.parse(sessionStorage.getItem('osgard:remix-pending:v1')));
      assert.equal(pending.kind, 'input'); assert.equal(pending.body.sequence, 1);
      inputGate.resolve();
      await page.waitForFunction(() => JSON.parse(document.querySelector('#arena').dataset.state).sequence === 1);
      await page.locator('#auth-panel').waitFor({ state: 'visible' });
      assert.deepEqual(await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state)), accepted.body.state);
      assert.equal(await page.evaluate(() => sessionStorage.getItem('osgard:remix-pending:v1')), null);
      assert.equal(await page.evaluate(() => JSON.parse(sessionStorage.getItem('osgard:remix-client:v1')).matchId), original.id);
      assert.equal(await page.evaluate(() => sessionStorage.getItem('osgard:core-session:v1')), null);
      await page.unroute(historyRoute); await page.unroute(inputRoute);
      await page.locator('#remix-username').fill(credentials.username); await page.locator('#remix-password').fill(credentials.password);
      await page.locator('#auth-form button[type="submit"]').tap();
      await page.waitForFunction(() => document.querySelector('#auth-panel').hidden && !document.querySelector('[data-remix-move="right"]').disabled);
      assert.deepEqual(await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state)), accepted.body.state);
      assert.equal(mutations.filter(path => path.endsWith('/matches')).length, 1);
      assert.equal(mutations.filter(path => path.endsWith('/input')).length, 1);
      return { historyRejection: 401, realCommittedSequence: 1, acknowledgementPreserved: true, matchCreations: 1, inputRequests: 1 };
    } finally { clearTimeout(deadline); historyGate.resolve(); inputGate.resolve(); }
  });
  await check('real-signup-login-session-expiry', async page => {
    const authStatuses = [];
    page.on('response', response => { if (new URL(response.url()).pathname.startsWith('/api/core/auth/')) authStatuses.push(response.status()); });
    await page.goto(bases.normal + '/games/remix/arena/');
    await page.locator('#auth-panel').waitFor({ state: 'visible' }); assert.ok(await page.locator('#start-match').isDisabled());
    const username = 'remix-ui-' + randomBytes(6).toString('hex'), password = randomBytes(24).toString('base64url');
    await page.locator('#remix-username').fill(username); await page.locator('#remix-password').fill(password);
    await page.locator('#register-player').tap();
    await page.waitForFunction(() => !document.querySelector('#start-match').disabled);
    assert.ok((await page.locator('#remix-password').inputValue()).length === 0, 'Successful auth must clear the password field');
    assert.ok(await page.evaluate(() => /^[A-Za-z0-9_-]{40,100}$/.test(sessionStorage.getItem('osgard:core-session:v1'))));
    await page.locator('#start-match').tap();
    await page.waitForFunction(() => Boolean(document.querySelector('#arena').dataset.state));
    await page.waitForFunction(() => !document.querySelector('[data-remix-move="right"]').disabled);
    await page.locator('[data-remix-move="right"]').tap();
    await page.waitForFunction(() => JSON.parse(document.querySelector('#arena').dataset.state).sequence === 1);
    const match = await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state));
    await page.reload();
    await page.waitForFunction(previous => JSON.parse(document.querySelector('#arena').dataset.state || 'null')?.id === previous, match.id);
    assert.deepEqual(await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state)), match);
    await page.evaluate(() => sessionStorage.setItem('osgard:core-session:v1', 'expired-local-test-session'));
    await page.reload(); await page.locator('#auth-panel').waitFor({ state: 'visible' });
    assert.ok(authStatuses.includes(401)); assert.ok(await page.locator('#start-match').isDisabled());
    assert.ok(await page.locator('#result-panel').isHidden()); assert.equal(await page.locator('#arena').getAttribute('data-state'), null);
    assert.equal(await page.evaluate(() => sessionStorage.getItem('osgard:core-session:v1')), null);
    await page.locator('#remix-username').fill(username); await page.locator('#remix-password').fill('deliberately-wrong-password');
    await page.locator('#auth-form button[type="submit"]').tap();
    await page.waitForFunction(() => document.querySelector('#auth-status').textContent !== 'Проверяем вход…' && document.querySelector('#auth-status').textContent.length > 0);
    assert.ok(await page.locator('#auth-panel').isVisible()); assert.ok(await page.locator('#start-match').isDisabled());
    await page.locator('#remix-password').fill(password);
    await page.locator('#auth-form button[type="submit"]').focus(); await page.locator('#auth-form button[type="submit"]').press('Enter');
    await page.waitForFunction(previous => JSON.parse(document.querySelector('#arena').dataset.state || 'null')?.id === previous, match.id);
    assert.ok((await page.locator('#remix-password').inputValue()).length === 0, 'Successful login must clear the password field');
    assert.ok(await page.locator('#auth-panel').isHidden());
  });
  for (const name of ['disabled', 'incompatible']) await check(name + '-service-fails-closed', async page => {
    const mutations = [], capabilities = [];
    page.on('request', request => { if (request.method() === 'POST') mutations.push(new URL(request.url()).pathname); });
    page.on('response', response => { if (new URL(response.url()).pathname === '/api/core/remix/v1/capabilities') capabilities.push(response.status()); });
    await page.goto(bases[name] + '/games/remix/arena/');
    await page.waitForFunction(() => document.querySelector('#service-state').dataset.status === 'unavailable');
    assert.ok(await page.locator('#start-match').isDisabled()); assert.ok(await page.locator('#growth-panel').isHidden()); assert.ok(await page.locator('#result-panel').isHidden());
    assert.equal(await page.locator('#arena').getAttribute('data-state'), null); assert.deepEqual(mutations, []);
    assert.ok(capabilities.includes(name === 'disabled' ? 404 : 200));
    assert.match(await page.locator('#match-status').innerText(), name === 'disabled' ? /не включён/ : /не объявляет совместимую/);
  });
  await check('lost-committed-response-retries-once', async (page, context) => {
    await context.addInitScript(({ origin, token }) => { if (location.origin === origin) sessionStorage.setItem('osgard:core-session:v1', token); }, { origin: bases['lost-response'], token: process.env.OSGARD_REMIX_UI_RETRY_TOKEN });
    await page.goto(bases['lost-response'] + '/games/remix/arena/');
    await page.waitForFunction(() => !document.querySelector('#start-match').disabled); await page.locator('#start-match').tap();
    await page.waitForFunction(() => !document.querySelector('[data-remix-move="right"]').disabled); await page.locator('[data-remix-move="right"]').tap();
    await page.locator('#retry-operation').waitFor({ state: 'visible' });
    await page.waitForFunction(() => !document.querySelector('#retry-operation').disabled);
    const pending = await page.evaluate(() => JSON.parse(sessionStorage.getItem('osgard:remix-pending:v1')));
    assert.equal(pending.kind, 'input'); assert.equal(pending.body.sequence, 1);
    const original = await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state));
    assert.equal(original.sequence, 0, 'A missing response must not cause optimistic movement');
    const stored = await page.evaluate(async match => {
      const response = await fetch('/api/core/remix/v1/matches/' + match + '/state', { headers: { Authorization: 'Bearer ' + sessionStorage.getItem('osgard:core-session:v1') }, credentials: 'omit' });
      return response.json();
    }, original.id);
    assert.equal(stored.sequence, 1, 'The fault occurred after the real server committed the input');
    await page.reload();
    await page.waitForFunction(() => JSON.parse(document.querySelector('#arena').dataset.state || 'null')?.sequence === 1);
    assert.deepEqual(await page.evaluate(() => JSON.parse(sessionStorage.getItem('osgard:remix-pending:v1'))), pending);
    assert.ok(await page.locator('[data-remix-move="right"]').isDisabled());
    const retryResponse = page.waitForResponse(response => new URL(response.url()).pathname.endsWith('/input') && response.request().method() === 'POST');
    await page.locator('#retry-operation').tap();
    const response = await retryResponse, repeated = await response.json();
    assert.equal(response.status(), 200); assert.equal(repeated.replayed, true); assert.equal(repeated.sequence, 1);
    assert.equal(response.request().headers()['idempotency-key'], pending.key);
    await page.locator('#retry-operation').waitFor({ state: 'hidden' });
    assert.equal(await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state).sequence), 1);
    assert.equal(await page.evaluate(() => sessionStorage.getItem('osgard:remix-pending:v1')), null);
    await page.screenshot({ path: out + '/committed-input-recovered.png', fullPage: true });
  });
  for (const name of ['lost-create', 'lost-match']) await check(name + '-reauth-preserves-operation', async page => {
    await page.goto(bases[name] + '/games/remix/arena/');
    await page.locator('#auth-panel').waitFor({ state: 'visible' });
    const username = 'remix-reauth-' + randomBytes(5).toString('hex'), password = randomBytes(24).toString('base64url');
    await page.locator('#remix-username').fill(username); await page.locator('#remix-password').fill(password);
    await page.locator('#register-player').tap();
    await page.waitForFunction(() => !document.querySelector('#start-match').disabled); await page.locator('#start-match').tap();
    await page.locator('#retry-operation').waitFor({ state: 'visible' });
    await page.waitForFunction(() => !document.querySelector('#retry-operation').disabled);
    const pending = await page.evaluate(() => JSON.parse(sessionStorage.getItem('osgard:remix-pending:v1')));
    assert.equal(pending.kind, name === 'lost-create' ? 'create' : 'match');
    const revoked = await page.evaluate(async () => {
      const headers = { Authorization: 'Bearer ' + sessionStorage.getItem('osgard:core-session:v1'), 'Content-Type': 'application/json' };
      const security = await fetch('/api/core/auth/security', { credentials: 'omit', headers }).then(response => response.json());
      const current = security.sessions.find(session => session.current);
      const response = await fetch('/api/core/auth/sessions/revoke', { method: 'POST', credentials: 'omit', headers, body: JSON.stringify({ sessionId: current.id }) });
      return { status: response.status, value: await response.json() };
    });
    assert.equal(revoked.status, 200); assert.equal(revoked.value.revoked, true); assert.equal(revoked.value.current, true);
    const rejectedRetry = page.waitForResponse(response => new URL(response.url()).pathname === '/api/core/remix/v1/' + pending.path && response.request().method() === 'POST');
    await page.locator('#retry-operation').tap();
    assert.equal((await rejectedRetry).status(), 401);
    await page.locator('#auth-panel').waitFor({ state: 'visible' });
    assert.deepEqual(await page.evaluate(() => JSON.parse(sessionStorage.getItem('osgard:remix-pending:v1'))), pending, 'A 401 cannot discard an operation whose first response was lost after commit');
    await page.reload(); await page.locator('#auth-panel').waitFor({ state: 'visible' });
    await page.locator('#remix-username').fill(username); await page.locator('#remix-password').fill(password);
    await page.locator('#auth-form button[type="submit"]').tap();
    await page.waitForFunction(() => document.querySelector('#auth-panel').hidden && !document.querySelector('#retry-operation').disabled);
    assert.ok(await page.locator('#start-match').isDisabled(), 'A new create must wait for the saved operation to be acknowledged');
    assert.deepEqual(await page.evaluate(() => JSON.parse(sessionStorage.getItem('osgard:remix-pending:v1'))), pending);
    const replayedResponse = page.waitForResponse(response => new URL(response.url()).pathname === '/api/core/remix/v1/' + pending.path && response.request().method() === 'POST');
    await page.locator('#retry-operation').tap();
    const response = await replayedResponse, recovered = await response.json();
    assert.equal(response.status(), 200); assert.equal(recovered.replayed, true);
    assert.equal(response.request().headers()['idempotency-key'], pending.key);
    await page.waitForFunction(() => JSON.parse(document.querySelector('#arena').dataset.state || 'null')?.phase === 'PLAYING');
    const current = await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state));
    assert.equal(name === 'lost-create' ? current.challengeId : current.id, recovered.id);
    assert.equal(current.sequence, 0); assert.equal(await page.evaluate(() => sessionStorage.getItem('osgard:remix-pending:v1')), null);
    return { recoveredEntityId: recovered.id, rejectedRetryStatus: 401, replayed: true };
  });
  for (const name of ['state-retry', 'state-reload']) await check(name + '-keeps-confirmed-run', async page => {
    await page.goto(bases[name] + '/games/remix/arena/'); await page.locator('#auth-panel').waitFor({ state: 'visible' });
    await page.locator('#remix-username').fill('remix-restore-' + randomBytes(5).toString('hex'));
    await page.locator('#remix-password').fill(randomBytes(24).toString('base64url')); await page.locator('#register-player').tap();
    await page.waitForFunction(() => !document.querySelector('#start-match').disabled); await page.locator('#start-match').tap();
    await page.waitForFunction(() => Boolean(document.querySelector('#arena').dataset.state));
    const original = await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state));
    const reference = await page.evaluate(() => JSON.parse(sessionStorage.getItem('osgard:remix-client:v1')));
    const unavailable = page.waitForResponse(response => new URL(response.url()).pathname.endsWith('/state') && response.status() === 503);
    const stateRequested = page.waitForRequest(request => new URL(request.url()).pathname.endsWith('/state'));
    const reload = page.reload(); await stateRequested;
    assert.ok(await page.locator('#start-match').isDisabled(), 'An in-flight restore must not enable match creation before its state arrives');
    await reload; await unavailable;
    await page.waitForFunction(() => document.querySelector('#match-status').textContent.includes('временное хранилище'));
    assert.deepEqual(await page.evaluate(() => JSON.parse(sessionStorage.getItem('osgard:remix-client:v1'))), reference, 'A failed restore read must not replace the saved matchId with null');
    assert.ok(await page.locator('#start-match').isDisabled(), 'An unresolved restore must block duplicate match creation');
    await page.locator('#retry-restore').waitFor({ state: 'visible' });
    if (name === 'state-retry') await page.locator('#retry-restore').tap(); else await page.reload();
    await page.waitForFunction(match => JSON.parse(document.querySelector('#arena').dataset.state || 'null')?.id === match, original.id);
    assert.deepEqual(await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state)), original);
    assert.deepEqual(await page.evaluate(() => JSON.parse(sessionStorage.getItem('osgard:remix-client:v1'))), reference);
    await page.locator('#retry-restore').waitFor({ state: 'hidden' });
    return { recoveredEntityId: original.id, failedReadStatus: 503 };
  });
  await check('poll-touch-keeps-one-input-and-newer-sequence', async (page, context) => {
    const initial = await createRun(page, bases['poll-touch']);
    const right = page.locator('[data-remix-move="right"]'); await right.scrollIntoViewIfNeeded();
    const first = await page.waitForRequest(request => new URL(request.url()).pathname.endsWith('/state'));
    const firstAt = Date.now(); await (await first.response()).finished();
    const nextRead = page.waitForRequest(request => new URL(request.url()).pathname.endsWith('/state'));
    // Span the known 2500ms polling boundary with one native touch gesture.
    // No second tap, response fulfilment, game-state write or clock mock is used.
    await new Promise(resolve => setTimeout(resolve, Math.max(0, firstAt + 2250 - Date.now())));
    const box = await right.boundingBox(), cdp = await context.newCDPSession(page);
    const postedInputs = [];
    page.on('request', request => { if (request.method() === 'POST' && new URL(request.url()).pathname.endsWith('/input')) postedInputs.push(request); });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: box.x + box.width / 2, y: box.y + box.height / 2 }] });
    const read = await nextRead;
    const disabledDuringRead = await right.isDisabled();
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    const response = await read.response(); await response.finished();
    const stale = await response.json(); assert.equal(stale.sequence, 0);
    await page.waitForTimeout(100);
    const current = await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state));
    assert.equal(current.sequence, 1, `One native touch across read polling must reach the server; disabledDuringRead=${disabledDuringRead}, inputRequests=${postedInputs.length}`);
    assert.equal(postedInputs.length, 1); assert.equal(disabledDuringRead, false, 'A read-only poll must not disable input controls');
    assert.equal(current.id, initial.id); assert.deepEqual(current.position, [1, 3]);
    return { snapshotSequence: stale.sequence, confirmedSequence: current.sequence, inputRequests: postedInputs.length, disabledDuringRead };
  });
  await check('poll-old-match-cannot-replace-rematch', async page => {
    const initial = await createRun(page, bases['poll-rematch']);
    const route = pathToGoal(initial.arena, initial.position);
    async function step(name) {
      const previous = await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state).sequence);
      await page.locator('[data-remix-move="' + name + '"]').tap();
      await page.waitForFunction(sequence => JSON.parse(document.querySelector('#arena').dataset.state).sequence === sequence + 1, previous);
    }
    for (const direction of route.slice(0, -1)) await step(direction);
    const oldRequest = await page.waitForRequest(request => new URL(request.url()).pathname.endsWith('/state'));
    let oldReturned = false;
    const oldResponse = oldRequest.response().then(response => { oldReturned = true; return response; });
    const currentBeforeWin = await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state));
    await step(route.at(-1)); await page.locator('#result-panel').waitFor({ state: 'visible' });
    await page.locator('#publish-challenge').tap(); await page.locator('#growth-panel').waitFor({ state: 'visible' });
    await page.locator('#rematch-challenge').tap();
    await page.waitForFunction(previous => JSON.parse(document.querySelector('#arena').dataset.state).id !== previous, initial.id);
    const restarted = await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state));
    assert.equal(restarted.phase, 'PLAYING'); assert.equal(restarted.sequence, 0);
    assert.equal(oldReturned, false, 'The fixture must deliver the old snapshot after the new match starts');
    const response = await oldResponse; await response.finished();
    const stale = await response.json(); assert.equal(stale.id, initial.id); assert.equal(stale.sequence, currentBeforeWin.sequence);
    await page.waitForTimeout(100);
    assert.deepEqual(await page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state)), restarted, 'A delayed snapshot of the previous match must not replace the new match');
    const reference = await page.evaluate(() => JSON.parse(sessionStorage.getItem('osgard:remix-client:v1')));
    assert.equal(reference.matchId, restarted.id);
    return { previousMatchId: stale.id, currentMatchId: restarted.id, previousSequence: stale.sequence, currentSequence: restarted.sequence };
  });
} finally { await browser.close(); }
const failed = checks.filter(check => !check.passed).length;
await writeFile(out + '/report.json', JSON.stringify({ schemaVersion: 1, status: failed ? 'failed' : 'passed', passed: checks.length - failed, failed, scope: 'Real Core/REMIX HTTP, plus explicit negative capability and lost-response fixtures; no successful responses are substituted', checks }, null, 2) + '\n');
if (failed) process.exitCode = 1;
