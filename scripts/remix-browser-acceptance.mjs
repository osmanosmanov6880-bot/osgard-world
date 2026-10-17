import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { compatibleService } from '../public/games/remix/arena/remix-contract.mjs';

const RULESET = 'remix-arena-v1';
const canonical = value => Array.isArray(value) ? '[' + value.map(canonical).join(',') + ']' : value && typeof value === 'object' ? '{' + Object.keys(value).sort().map(key => JSON.stringify(key) + ':' + canonical(value[key])).join(',') + '}' : JSON.stringify(value);
const hash = value => createHash('sha256').update(canonical(value)).digest('hex');
const moveNames = { '1,0': ['right', 'ArrowRight'], '-1,0': ['left', 'ArrowLeft'], '0,1': ['down', 'ArrowDown'], '0,-1': ['up', 'ArrowUp'] };

function safePath(level, start) {
  const blocked = new Set(level.objects.filter(object => object.kind !== 'goal').map(object => `${object.x},${object.y}`));
  const goal = level.objects.find(object => object.kind === 'goal');
  const queue = [{ point: start, path: [] }], seen = new Set([start.join(',')]);
  for (let index = 0; index < queue.length; index++) {
    const { point: [x, y], path } = queue[index];
    if (x === goal.x && y === goal.y) return path;
    for (const [dx, dy] of [[1, 0], [0, 1], [0, -1], [-1, 0]]) {
      const next = [x + dx, y + dy], key = next.join(',');
      if (next[0] >= 0 && next[0] < level.width && next[1] >= 0 && next[1] < level.height && !blocked.has(key) && !seen.has(key)) { seen.add(key); queue.push({ point: next, path: [...path, [dx, dy]] }); }
    }
  }
  throw Error('The published arena has no safe route to its goal.');
}

/** Independently recalculate the exported journal in JavaScript, across the HTTP boundary. */
export function verifyBrowserReplay(replay, result) {
  assert.equal(replay.schemaVersion, 1); assert.equal(replay.gameVersion, RULESET);
  assert.equal(replay.matchId, result.matchId); assert.equal(replay.playerId, result.playerId);
  assert.equal(replay.challengeId, result.challengeId); assert.equal(replay.purpose, result.purpose);
  assert.equal(replay.hash, result.replayHash);
  assert.equal(hash(Object.fromEntries(Object.entries(replay).filter(([key]) => key !== 'hash'))), replay.hash, 'Replay hash must cover the complete envelope');
  assert.deepEqual(replay.initialState, { position: [0, 3], sequence: 0, steps: 0, falls: 0, jumps: 0, blocked: 0, timeMs: 0, finished: false, won: false });
  assert.equal(replay.inputs.length, result.steps); assert.equal(replay.checkpoints.length, result.steps);
  let current = structuredClone(replay.initialState);
  const wall = new Set(replay.arena.objects.filter(object => object.kind === 'platform').map(object => `${object.x},${object.y}`));
  for (let index = 0; index < replay.inputs.length; index++) {
    const input = replay.inputs[index];
    assert.equal(input.sequence, index + 1); assert.equal(Math.abs(input.moveX) + Math.abs(input.moveY), 1);
    assert.equal(typeof input.jump, 'boolean'); assert.equal(current.finished, false);
    const distance = input.jump ? 2 : 1;
    const destination = [current.position[0] + input.moveX * distance, current.position[1] + input.moveY * distance];
    const crossed = Array.from({ length: distance }, (_, step) => [current.position[0] + input.moveX * (step + 1), current.position[1] + input.moveY * (step + 1)]);
    current.sequence++; current.steps++; current.jumps += Number(input.jump);
    if (destination[0] < 0 || destination[0] >= 12 || destination[1] < 0 || destination[1] >= 7 || crossed.some(point => wall.has(point.join(',')))) current.blocked++;
    else {
      current.position = destination;
      const object = replay.arena.objects.find(item => item.x === destination[0] && item.y === destination[1]);
      if (object?.kind === 'hazard') { current.falls++; current.position = [0, 3]; }
      if (object?.kind === 'goal') current.won = true;
    }
    current.timeMs = current.steps * 100 + current.jumps * 100 + current.falls * 1500;
    current.finished = current.won || current.steps === 256;
    assert.deepEqual(replay.checkpoints[index], { sequence: index + 1, state: current, hash: hash(current) }, `Server checkpoint ${index + 1} must reproduce from its input`);
  }
  assert.equal(current.finished, true);
  const expected = { won: current.won, outcome: current.won ? 'finished' : 'input-limit', steps: current.steps, falls: current.falls, jumps: current.jumps, timeMs: current.timeMs, score: current.won ? Math.max(0, 100000 - current.timeMs) : 0 };
  assert.deepEqual(replay.result, expected);
  for (const [key, value] of Object.entries(expected)) assert.equal(result[key], value, `Result ${key} must derive from the journal`);
  assert.deepEqual(result.scores, [{ playerId: result.playerId, score: expected.score, timeMs: expected.timeMs }]);
  return current;
}

/** User controls and real API responses only; no route fulfilment or game-state writes. */
export async function acceptRemix(page, result, { timeout = 15000, screenshot, Blocked = Error, safeApiActions = false } = {}) {
  const mobile = result.device === 'mobile';
  const observedResponses = [];
  const observer = async response => {
    if (!new URL(response.url()).pathname.startsWith('/api/core/remix/v1/') || !response.ok()) return;
    try { observedResponses.push({ path: new URL(response.url()).pathname, value: await response.json() }); } catch {}
  };
  page.on('response', observer);
  const readState = () => page.locator('#arena').evaluate(canvas => JSON.parse(canvas.dataset.state || 'null'));
  const readResult = () => page.locator('#result-panel').evaluate(element => JSON.parse(element.dataset.result || 'null'));
  const activate = async selector => {
    const control = page.locator(selector);
    await control.waitFor({ state: 'visible' }); await control.scrollIntoViewIfNeeded();
    await page.waitForFunction(query => !document.querySelector(query)?.disabled, selector, { timeout });
    const box = await control.boundingBox(); assert.ok(box && box.width >= 44 && box.height >= 44, `${selector} needs a usable touch/keyboard target`);
    if (mobile) await control.tap(); else { await control.focus(); await control.press('Enter'); }
  };
  const step = async (dx, dy, jump = false) => {
    const before = await readState();
    const [name, key] = moveNames[`${dx},${dy}`];
    const selector = jump ? '[data-remix-jump]' : `[data-remix-move="${name}"]`;
    await page.waitForFunction(query => !document.querySelector(query)?.disabled, selector, { timeout });
    if (mobile) await activate(selector);
    else { await page.locator('#arena').focus(); await page.keyboard.press(jump ? 'Space' : key); }
    await page.waitForFunction(sequence => JSON.parse(document.querySelector('#arena').dataset.state || 'null')?.sequence === sequence + 1, before.sequence, { timeout });
    const after = await readState();
    assert.equal(after.id, before.id); assert.equal(after.sequence, before.sequence + 1);
    return after;
  };
  const complete = async () => {
    let current = await readState();
    for (const [dx, dy] of safePath(current.arena, current.position)) current = await step(dx, dy);
    assert.equal(current.phase, 'RESULTS'); assert.equal(current.won, true);
    await page.waitForFunction(() => Boolean(document.querySelector('#result-panel').dataset.result), null, { timeout });
    const finished = await readResult();
    assert.equal(finished.matchId, current.id); assert.equal(finished.steps, current.sequence);
    const response = observedResponses.findLast(item => item.path.endsWith(`/matches/${current.id}/result`));
    assert.ok(response, 'The visible result must follow a real successful result request');
    assert.deepEqual(finished, response.value);
    assert.ok(await page.locator('#sponsor-slot').isVisible(), 'The inquiry belongs after the server result');
    return finished;
  };
  try {
    await page.waitForFunction(() => ['ready', 'unavailable'].includes(document.querySelector('#service-state')?.dataset.status), null, { timeout });
    assert.ok(await page.locator('a[href="/games/remix/player/index.html"]').isVisible(), 'Existing Unity route must remain available');
    if (await page.locator('#service-state').getAttribute('data-status') !== 'ready') {
      assert.equal(await readState(), null); assert.ok(await page.locator('#start-match').isDisabled()); assert.ok(await page.locator('#growth-panel').isHidden());
      // The initial capability request can precede this handler. Independently
      // read it again, so a client exception cannot masquerade as a dependency.
      const capability = await page.evaluate(async () => {
        try {
          const response = await fetch('/api/core/remix/v1/capabilities', { credentials: 'omit' });
          let value = null;
          try { value = await response.json(); } catch {}
          return { status: response.status, value };
        } catch { return { status: 0, networkFailure: true }; }
      });
      assert.ok(capability.status !== 200 || !compatibleService(capability.value), 'A compatible capability response exists: the unavailable UI is a client failure, not a backend blocker');
      result.observed = { serviceStatus: await page.locator('#match-status').innerText(), capabilityStatus: capability.status, capabilityCompatible: compatibleService(capability.value) };
      throw new Blocked('REMIX compatible arena service is unavailable; no match or result was fabricated.');
    }
    if (!safeApiActions) throw new Blocked('REMIX match creation requires explicit authorization for this base origin.');
    await page.waitForFunction(() => !document.querySelector('#start-match').disabled || !document.querySelector('#auth-panel').hidden, null, { timeout });
    if (await page.locator('#auth-panel').isVisible()) throw new Blocked('REMIX requires an authenticated Core actor; the acceptance launcher did not provide a usable session.');
    assert.ok(await page.locator('#result-panel').isHidden()); assert.ok(await page.locator('#sponsor-slot').isHidden());
    await activate('#start-match');
    await page.waitForFunction(() => JSON.parse(document.querySelector('#arena').dataset.state || 'null')?.phase === 'PLAYING', null, { timeout });
    const proofStart = await readState();
    assert.equal(proofStart.sequence, 0); assert.equal(proofStart.purpose, 'creator-proof');
    let current = await step(1, 0);
    assert.deepEqual(current.position, [1, 3]);
    current = await step(1, 0, true);
    assert.equal(current.jumps, 1); assert.equal(current.timeMs, 300 + current.falls * 1500);
    await page.reload({ waitUntil: 'domcontentloaded' });
    await page.waitForFunction(match => JSON.parse(document.querySelector('#arena').dataset.state || 'null')?.id === match, current.id, { timeout });
    assert.deepEqual(await readState(), current, 'Reload must restore the real match and its accepted sequence');
    result.checks.push('Core session starts a real creator-proof match; keyboard/touch movement and jump are server-confirmed and survive reload');
    const proofResult = await complete();
    assert.equal(proofResult.purpose, 'creator-proof'); assert.ok(await page.locator('#growth-panel').isHidden());
    await activate('#publish-challenge');
    await page.locator('#growth-panel').waitFor({ state: 'visible' });
    const invitation = new URL(await page.locator('#challenge-link').inputValue());
    assert.equal(invitation.searchParams.get('challenge'), proofStart.challengeId); assert.equal(Number(invitation.searchParams.get('seed')), proofStart.seed);
    assert.ok(observedResponses.some(item => item.path.endsWith('/validate') && item.value.status === 'VALIDATED'));
    assert.ok(observedResponses.some(item => item.path.endsWith('/publish') && item.value.status === 'PUBLISHED'));
    assert.equal(await page.locator('#leaderboard li').count(), 0, 'Creator proof must not enter the leaderboard');
    result.checks.push('A completed creator proof validates and publishes the real challenge; its share link preserves ID/seed and proof stays out of rankings');
    await activate('#rematch-challenge');
    await page.waitForFunction(previous => { const value = JSON.parse(document.querySelector('#arena').dataset.state || 'null'); return value?.id !== previous && value?.phase === 'PLAYING'; }, proofStart.id, { timeout });
    const runStart = await readState();
    assert.equal(runStart.purpose, 'challenge'); assert.deepEqual(runStart.arena, proofStart.arena);
    assert.ok(await page.locator('#sponsor-slot').isHidden(), 'Starting another run hides the prior result/inquiry');
    const finalResult = await complete();
    await page.waitForFunction(() => document.querySelectorAll('#leaderboard li').length === 1, null, { timeout });
    await activate('#show-replay'); await page.locator('#replay-panel').waitFor({ state: 'visible' });
    const envelope = observedResponses.findLast(item => item.path.endsWith(`/matches/${finalResult.matchId}/replay`))?.value;
    assert.ok(envelope, 'Replay viewer must receive a real server journal');
    const finalState = verifyBrowserReplay(envelope, finalResult);
    assert.deepEqual(await page.locator('#replay-panel').evaluate(element => JSON.parse(element.dataset.frame)), envelope.initialState);
    await page.locator('#replay-step').focus(); await page.locator('#replay-step').press('End');
    await page.waitForFunction(sequence => JSON.parse(document.querySelector('#replay-panel').dataset.frame).sequence === sequence, finalState.sequence);
    assert.deepEqual(await page.locator('#replay-panel').evaluate(element => JSON.parse(element.dataset.frame)), finalState);
    assert.equal((await readState()).sequence, finalResult.steps, 'Scrubbing replay must not mutate the match');
    await activate('#close-replay');
    result.checks.push('A published challenge produces a separate ranked run; the full server replay/hash and score reproduce independently in JavaScript, and replay controls preserve the match');
    const downloadPromise = page.waitForEvent('download', { timeout });
    await activate('#download-result-card');
    const download = await downloadPromise;
    const bytes = await readFile(await download.path());
    assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a'); assert.equal(bytes.readUInt32BE(16), 1200); assert.equal(bytes.readUInt32BE(20), 630);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    assert.ok(overflow <= 1, `REMIX page overflowed viewport by ${overflow}px`);
    result.checks.push('Confirmed results export a real 1200×630 PNG; the responsive controls stay inside the viewport');
    result.remix = { schemaVersion: 1, ruleset: RULESET, challengeId: proofStart.challengeId, proofMatchId: proofStart.id, rankedMatchId: finalResult.matchId, inputCount: finalResult.steps, replayHash: finalResult.replayHash, score: finalResult.score, authority: 'real-core-http-and-sqlite', proofValidated: true, published: true, replayReproduced: true };
    result.scope = 'Real authenticated arena: creator proof, publication, ranked run, server input/result/replay, keyboard/touch, reload and result export; separate Unity backend is outside this contract';
    if (screenshot) await screenshot('remix-confirmed-result');
  } finally { page.off('response', observer); }
}
