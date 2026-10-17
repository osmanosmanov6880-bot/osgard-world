import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import vm from 'node:vm';

// Explicit two-account HTTP fixtures. This is client/fixture evidence, not a
// production admission, Unity, replay or simulator-recovery certification.
export const coreKey = 'osgard:core-session:v1';
export const accounts = {
  alice: { id: 'a'.repeat(32), username: 'alice', token: 'fixture-core-alice-only' },
  bob: { id: 'b'.repeat(32), username: 'bob', token: 'fixture-core-bob-only' },
  carol: { id: 'c'.repeat(32), username: 'carol', token: 'fixture-core-carol-only' },
};
export const reply = (value, status = 200) => ({ value, status });
const validId = value => typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$/.test(value);
const clone = value => JSON.parse(JSON.stringify(value));

export function invitationService({ clock = () => Date.now(), enabled = true } = {}) {
  let matchNumber = 0, invitationNumber = 0;
  const service = {
    offset: 0, enabled, calls: [], matches: new Map(), invitations: new Map(), attempts: new Map(), revoked: new Set(),
    now: () => clock() + service.offset,
    advance(ms) { service.offset += ms; },
    capabilities: { authPolicyVersion: 1, creationEnabled: true, provider: 'core', ownershipPolicy: 'confirmed-durable-binding', participantPolicyVersion: 1, participantAdmissionEnabled: enabled, maxParticipants: 2, activeMatchRecovery: false, replayVerification: false, legacyMatches: 'anonymous' },
    create(owner = accounts.alice.id, challengeId = 'ch_invitation_fixture') {
      const id = 'match_invitation.' + (++matchNumber);
      const value = { id, challengeId, owner, created: service.now(), participants: new Map([[owner, { playerId: 'corep_' + matchNumber + '_' + owner, sequence: 0, frames: 0, x: 0 }]]), frozen: null };
      service.matches.set(id, value); return value;
    },
    metadata(match, account) {
      const self = match.participants.get(account);
      return { id: match.id, challengeId: match.challengeId, maxPlayers: 2, createdAt: new Date(match.created).toISOString(), accessMode: 'core-owned', playerId: self.playerId, highestSubmittedSequence: self.sequence, role: account === match.owner ? 'owner' : 'participant', participantCount: match.participants.size, maxParticipants: 2 };
    },
    state(match) {
      const elapsed = service.now() - match.created, phase = elapsed < 3000 ? 'COUNTDOWN' : elapsed < 33000 ? 'PLAYING' : 'RESULTS';
      const scores = [...match.participants.values()].filter(p => p.frames).map(p => ({ playerId: p.playerId, score: p.frames / 10 }));
      const current = { id: match.id, phase, remainingMs: phase === 'COUNTDOWN' ? 3000 - elapsed : phase === 'PLAYING' ? 33000 - elapsed : 0, players: scores.length, replayFrames: [...match.participants.values()].reduce((sum, p) => sum + p.frames, 0), scores };
      if (phase === 'RESULTS' && !match.frozen) match.frozen = clone(current);
      return clone(match.frozen || current);
    },
    invitationDTO(invitation, actor, engine = false) {
      const match = service.matches.get(invitation.matchId), state = service.state(match);
      if (invitation.status === 'pending') {
        if (state.phase === 'RESULTS') invitation.status = 'match_closed';
        else if (service.now() >= invitation.expires) invitation.status = 'expired';
      }
      const value = { id: invitation.id, matchId: match.id, challengeId: match.challengeId, recipientAccountId: invitation.recipientAccountId, status: invitation.status, createdAt: new Date(invitation.created).toISOString(), expiresAt: new Date(invitation.expires).toISOString(), role: actor === match.owner ? 'owner' : 'recipient' };
      return engine ? { ...value, engine: { phase: state.phase, remainingMs: state.remainingMs }, admissionAllowed: service.enabled && actor === invitation.recipientAccountId && invitation.status === 'pending' && state.remainingMs > 0 && match.participants.size < 2 } : value;
    },
    attemptDTO(attempt, actor) {
      if (attempt.result.status === 'rejected') return clone(attempt.result);
      const value = { ...attempt.result, invitation: service.invitationDTO(service.invitations.get(attempt.result.invitationId), actor) };
      delete value.invitationId;
      if (value.operation === 'accept') value.match = service.metadata(service.matches.get(value.invitation.matchId), actor);
      return value;
    },
    handle(call) {
      service.calls.push(call);
      const { path, method, body = {}, headers = {} } = call;
      const actor = Object.values(accounts).find(a => headers.authorization === 'Bearer ' + a.token && !service.revoked.has(a.id));
      if (path === '/api/remix/v2/capabilities' && method === 'GET') return reply({ ...service.capabilities, participantAdmissionEnabled: service.enabled });
      if (path === '/api/core/auth/me') return actor ? reply({ user: { id: actor.id, username: actor.username } }) : reply({ error: 'authentication_required' }, 401);
      if (path === '/api/remix/v1/challenges' && method === 'POST') return reply({ id: 'ch_invitation_fixture', seed: 20261017 }, 201);
      if (!path.startsWith('/api/remix/v2/')) return reply({ error: 'fixture_route_not_found' }, 404);
      if (!actor) return reply({ error: 'authentication_required' }, 401);
      if (path === '/api/remix/v2/matches' && method === 'POST') return reply(service.metadata(service.create(actor.id, body.challengeId), actor.id), 201);
      if (path === '/api/remix/v2/matches' && method === 'GET') return reply({ matches: [...service.matches.values()].filter(m => m.participants.has(actor.id)).map(m => service.metadata(m, actor.id)), nextCursor: null });
      const attemptRoute = path.match(/^\/api\/remix\/v2\/admission-attempts\/([A-Za-z0-9_-]+)$/);
      if (attemptRoute && method === 'GET') {
        const attempt = service.attempts.get(actor.id + ':' + attemptRoute[1]);
        return attempt ? reply(service.attemptDTO(attempt, actor.id)) : reply({ error: 'attempt_not_found' }, 404);
      }
      const createRoute = path.match(/^\/api\/remix\/v2\/matches\/([^/]+)\/invitations$/);
      const invitationRoute = path.match(/^\/api\/remix\/v2\/invitations\/([^/]+)(?:\/(accept|revoke))?$/);
      if (invitationRoute && !invitationRoute[2] && method === 'GET') {
        const invitation = service.invitations.get(invitationRoute[1]);
        if (!invitation) return reply({ error: 'invitation_not_found' }, 404);
        const match = service.matches.get(invitation.matchId);
        if (![match.owner, invitation.recipientAccountId].includes(actor.id)) return reply({ error: 'invitation_forbidden' }, 403);
        return reply(service.invitationDTO(invitation, actor.id, true));
      }
      if (method === 'POST' && (createRoute || invitationRoute?.[2])) {
        const operation = createRoute ? 'invite' : invitationRoute[2], key = headers['idempotency-key'];
        if (!/^[A-Za-z0-9_-]{16,100}$/.test(key || '')) return reply({ error: 'operation_key' }, 400);
        if (operation === 'invite' ? Object.keys(body).length !== 1 || !validId(body.recipientAccountId) : Object.keys(body).length !== 0) return reply({ error: 'invalid_request' }, 400);
        let invitation = invitationRoute ? service.invitations.get(invitationRoute[1]) : null;
        const match = service.matches.get(createRoute ? createRoute[1] : invitation?.matchId);
        if (!match || invitationRoute && !invitation) return reply({ error: 'invitation_not_found' }, 404);
        if (actor.id !== (operation === 'accept' ? invitation.recipientAccountId : match.owner)) return reply({ error: 'invitation_forbidden' }, 403);
        const fingerprint = JSON.stringify([method, path, body]), attemptKey = actor.id + ':' + key, old = service.attempts.get(attemptKey);
        if (old) return old.fingerprint === fingerprint ? reply(service.attemptDTO(old, actor.id), old.httpStatus) : reply({ error: 'operation_conflict' }, 409);
        if (!service.enabled && operation !== 'revoke') return reply({ error: 'participant_admission_disabled' }, 403);
        const reject = (error, httpStatus = 409, invitationId = invitationRoute?.[1]) => {
          const result = { operation, operationKey: key, status: 'rejected', error, message: error };
          if (invitationId) result.invitationId = invitationId;
          service.attempts.set(attemptKey, { fingerprint, result, httpStatus }); return reply(result, httpStatus);
        };
        if (operation === 'invite') {
          if (body.recipientAccountId === actor.id) return reject('recipient_is_owner', 400);
          if (service.state(match).phase === 'RESULTS') return reject('match_closed');
          if (match.participants.size >= 2) return reject('match_full');
          const pending = [...service.invitations.values()].find(i => i.matchId === match.id && service.invitationDTO(i, actor.id).status === 'pending');
          if (pending) return reject('invitation_pending', 409, pending.id);
          invitation = { id: 'inv_fixture_' + (++invitationNumber), matchId: match.id, recipientAccountId: body.recipientAccountId, status: 'pending', created: service.now(), expires: service.now() + 120000 };
          service.invitations.set(invitation.id, invitation);
        } else if (operation === 'accept') {
          service.invitationDTO(invitation, actor.id);
          if (invitation.status !== 'pending') return reject(invitation.status === 'revoked' ? 'invitation_revoked' : invitation.status === 'expired' ? 'invitation_expired' : 'match_closed');
          if (service.state(match).phase === 'RESULTS') return reject('match_closed');
          if (match.participants.size >= 2) return reject('match_full');
          match.participants.set(actor.id, { playerId: 'corep_second_' + actor.id + '_' + match.id, sequence: 0, frames: 0, x: 0 }); invitation.status = 'accepted';
        } else {
          if (invitation.status !== 'pending') return reject('invitation_not_pending');
          invitation.status = 'revoked';
        }
        const result = { operation, operationKey: key, status: 'ready', invitationId: invitation.id }, httpStatus = operation === 'revoke' ? 200 : 201;
        const attempt = { fingerprint, result, httpStatus }; service.attempts.set(attemptKey, attempt); return reply(service.attemptDTO(attempt, actor.id), httpStatus);
      }
      const matchRoute = path.match(/^\/api\/remix\/v2\/matches\/([^/]+)(?:\/(state|result|input))?$/);
      if (!matchRoute) return reply({ error: 'fixture_route_not_found' }, 404);
      const match = service.matches.get(matchRoute[1]), action = matchRoute[2];
      if (!match) return reply({ error: 'match_not_found' }, 404);
      if (!match.participants.has(actor.id)) return reply({ error: 'match_forbidden' }, 403);
      if (!action && method === 'GET') return reply(service.metadata(match, actor.id));
      if (action === 'state' && method === 'GET') return reply(service.state(match));
      if (action === 'result' && method === 'GET') {
        const state = service.state(match);
        return state.phase === 'RESULTS' ? reply({ matchId: match.id, phase: 'RESULTS', replayFrames: state.replayFrames, scores: state.scores }) : reply({ error: 'match_not_finished' }, 409);
      }
      if (action === 'input' && method === 'POST') {
        const self = match.participants.get(actor.id);
        if (service.state(match).phase !== 'PLAYING') return reply({ error: 'match_not_playing' }, 409);
        if ('playerId' in body && body.playerId !== self.playerId) return reply({ error: 'player_forbidden' }, 403);
        if (!Number.isSafeInteger(body.sequence) || body.sequence <= self.sequence) return reply({ error: 'stale_input_sequence' }, 409);
        self.sequence = body.sequence; self.frames++; self.x += body.moveX / 10;
        return reply({ playerId: self.playerId, lastSequence: self.sequence, position: [self.x, 0, 0], velocityY: 0, onGround: true, score: self.frames / 10 });
      }
      return reply({ error: 'fixture_route_not_found' }, 404);
    },
  };
  return service;
}

const origin = 'https://osgard.world', html = readFileSync('public/games/remix/index.html', 'utf8');
const source = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]).find(s => s.includes('async function restoreSession()'));
assert.ok(source);
const deferred = () => { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no; }); return { promise, resolve, reject }; };
let harnessNumber = 0;
function harness({ service = invitationService({ clock: () => Date.UTC(2026, 9, 17, 12) }), account = 'alice', data = new Map(), tab, href = origin + '/games/remix/?mode=account&lang=en', handler, after } = {}) {
  const nodes = new Map(), listeners = new Map(), timers = new Map(), calls = [], number = ++harnessNumber;
  let timerId = 0, uuid = 0;
  const context2d = { clearRect() {}, beginPath() {}, moveTo() {}, lineTo() {}, stroke() {}, fill() {}, arc() {} };
  class Element {
    constructor(key) { this.key = key; this.style = {}; this.dataset = {}; this.children = []; this.handlers = new Map(); this.attributes = new Map(); this.hidden = false; this.value = ''; this.textContent = ''; this.width = 340; this.height = 150; }
    set innerHTML(value) { this.html = value; this.children = []; } get innerHTML() { return this.html || ''; }
    appendChild(child) { this.children.push(child); return child; } insertBefore(child) { return this.appendChild(child); }
    querySelector(selector) { return node(selector); }
    querySelectorAll(selector) {
      if (selector === '[data-console-action]') return ['left', 'jump', 'right'].map(action => node('[data-console-action=' + action + ']'));
      if (selector === '[data-owned-match]') return node('#owned-history').children.flatMap(row => row.children);
      return [];
    }
    setAttribute(key, value) { this.attributes.set(key, String(value)); } getAttribute(key) { return this.attributes.get(key) ?? null; }
    addEventListener(name, fn) { this.handlers.set(name, fn); } getContext() { return context2d; } focus() {}
  }
  const node = key => { if (!nodes.has(key)) nodes.set(key, new Element(key)); return nodes.get(key); };
  tab ||= new Map(account ? [[coreKey, accounts[account].token]] : []);
  const storage = map => ({ get length() { return map.size; }, key(i) { return [...map.keys()][i] ?? null; }, getItem(key) { return map.get(key) ?? null; }, setItem(key, value) { map.set(key, String(value)); }, removeItem(key) { map.delete(key); } });
  const h = { service, data, tab, calls, node, handler, after };
  class TestDate extends Date { constructor(...args) { super(...(args.length ? args : [service.now()])); } static now() { return service.now(); } }
  const context = {
    console, URL, URLSearchParams, AbortController, Date: TestDate, localStorage: storage(data), sessionStorage: storage(tab),
    location: new URL(href), navigator: { onLine: true, clipboard: { async writeText(value) { h.copied = value; } } }, prompt(_label, value) { h.copied = value; },
    crypto: { randomUUID: () => 'admission-fixture-' + number + '-' + String(++uuid).padStart(8, '0') },
    document: { querySelector: node, createElement: key => new Element(key), documentElement: {}, readyState: 'loading', addEventListener() {} },
    setTimeout(fn, delay = 0) { const id = ++timerId; timers.set(id, { fn, at: service.now() + delay, delay }); return id; }, clearTimeout(id) { timers.delete(id); },
    addEventListener(name, fn) { listeners.set(name, [...(listeners.get(name) || []), fn]); },
    fetch: async (url, options = {}) => {
      const target = new URL(url, origin), call = { path: target.pathname, url: target.href, method: options.method || 'GET', body: options.body ? JSON.parse(options.body) : undefined, headers: Object.fromEntries(Object.entries(options.headers || {}).map(([k, v]) => [k.toLowerCase(), v])), credentials: options.credentials, redirect: options.redirect, signal: options.signal };
      calls.push(call);
      const perform = async () => {
        let result = h.handler ? await h.handler(call, h) : undefined;
        if (!result) result = service.handle(call);
        if (h.after) result = await h.after(call, result, h) || result;
        if (result.json) return result;
        return { ok: result.status >= 200 && result.status < 300, status: result.status, json: async () => clone(result.value) };
      };
      return Promise.race([perform(), new Promise((_, reject) => {
        const abort = () => reject(Object.assign(Error('aborted'), { name: 'AbortError' }));
        if (options.signal?.aborted) abort(); else options.signal?.addEventListener('abort', abort, { once: true });
      })]);
    },
  };
  context.window = context; context.parent = context; context.history = { replaceState(_state, _unused, value) { context.location = new URL(value, context.location.href); } };
  vm.createContext(context); vm.runInContext(source, context, { filename: 'remix-shipped-admission-controller.js' });
  h.context = context; h.run = code => vm.runInContext(code, context);
  h.flush = async () => { for (let i = 0; i < 200; i++) await Promise.resolve(); };
  h.emit = (name, event = {}) => { for (const fn of listeners.get(name) || []) fn(event); };
  h.advance = async ms => {
    const target = service.now() + ms;
    for (let i = 0; i < 500; i++) {
      const next = [...timers].filter(([, t]) => t.at <= target).sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) break;
      service.advance(Math.max(0, next[1].at - service.now())); timers.delete(next[0]); next[1].fn(); await h.flush();
      if (i === 499) throw Error('Unbounded timers');
    }
    service.advance(Math.max(0, target - service.now())); await h.flush();
  };
  h.recover = async id => { await h.run('recoverOwnedMatch(' + JSON.stringify(id) + ')'); await h.flush(); };
  h.invite = async (recipient = accounts.bob.id) => { node('#owned-invite-recipient').value = recipient; await h.run("mutateAdmission('invite')"); await h.flush(); };
  h.accept = async () => { await h.run('openOrAcceptInvitation()'); await h.flush(); };
  h.journals = () => [...data].filter(([key]) => key.startsWith('osgard:remix-admission:v1:')).map(([key, raw]) => ({ key, value: JSON.parse(raw) }));
  h.posts = operation => calls.filter(c => c.method === 'POST' && (operation === 'invite' ? /\/matches\/[^/]+\/invitations$/.test(c.path) : c.path.endsWith('/' + operation)));
  return h;
}

async function readyPair() {
  const service = invitationService({ clock: () => Date.UTC(2026, 9, 17, 12) }), match = service.create();
  const owner = harness({ service }); await owner.flush(); await owner.recover(match.id); await owner.invite();
  const invitation = [...service.invitations.values()][0]; assert.ok(invitation);
  const recipient = harness({ service, account: 'bob', href: origin + '/games/remix/?invitation=' + invitation.id + '&mode=account&lang=en' }); await recipient.flush();
  return { service, match, owner, recipient, invitation };
}

async function runChecks() {
  let passed = 0;
  const check = async (name, run) => { let timer; try { await Promise.race([run(), new Promise((_, reject) => { timer = setTimeout(() => reject(Error('Fixture deadline: ' + name)), 4000); })]); } finally { clearTimeout(timer); } passed++; console.log('PASS', name); };
  await check('an addressed invitation is explicit and two Core accounts retain separate players, sequences and scores', async () => {
    const { owner, recipient, service, match } = await readyPair();
    assert.equal(recipient.posts('accept').length, 0); assert.equal(recipient.run('match'), null); assert.equal(match.participants.size, 1);
    assert.equal(recipient.node('#owned-accept-invitation').disabled, false);
    await recipient.accept(); assert.equal(match.participants.size, 2); assert.equal(recipient.run('ownedRole'), 'participant');
    assert.equal(recipient.run('match.id'), match.id); assert.notEqual(recipient.run('playerId'), owner.run('playerId')); assert.equal(service.state(match).players, 0);
    await owner.advance(3001); await recipient.advance(0);
    owner.run('send(1,0,false)'); recipient.run('send(-1,0,false)'); await owner.flush(); await recipient.flush();
    assert.equal(match.participants.get(accounts.alice.id).sequence, 1); assert.equal(match.participants.get(accounts.bob.id).sequence, 1);
    assert.equal(service.state(match).players, 2); assert.equal(service.state(match).scores.length, 2);
    await owner.advance(30000); await recipient.advance(0);
    assert.equal(owner.run('sessionMode'), 'completed'); assert.equal(recipient.run('sessionMode'), 'completed');
    assert.match(recipient.run('lastResultSummary'), /You: 0.1/); assert.match(owner.run('lastResultSummary'), /You: 0.1/);
    assert.equal(recipient.calls.filter(c => c.path === '/api/remix/v2/matches' && c.method === 'POST').length, 0);
  });
  await check('sign-in destination preserves only the non-secret invitation ID and never accepts automatically', async () => {
    const { invitation, service } = await readyPair();
    const h = harness({ service, account: null, href: origin + '/games/remix/?invitation=' + invitation.id + '&mode=account&lang=en&token=discard&api=https://other.example&challenge=wrong#private' });
    await h.flush(); const back = new URL(h.node('#owned-signin').href, origin).searchParams.get('returnTo');
    assert.equal(back, '/games/remix/?invitation=' + invitation.id + '&lang=en&mode=account');
    const returned = harness({ service, account: 'bob', href: origin + back }); await returned.flush();
    assert.equal(returned.run('activeInvitation.id'), invitation.id); assert.equal(returned.posts('accept').length, 0);
    assert.equal(returned.calls.filter(c => c.method === 'POST').length, 0);
  });
  await check('copied invitation and challenge URLs cannot carry credentials, another API, or each other’s target', async () => {
    const { recipient, invitation } = await readyPair();
    recipient.context.location = new URL(origin + '/games/remix/?invitation=' + invitation.id + '&token=discard&api=https://other.example&mode=account#private');
    await recipient.run("copyAdmissionValue('invitation')");
    const url = new URL(recipient.copied); assert.deepEqual([...url.searchParams.keys()], ['invitation', 'lang', 'mode']); assert.equal(url.hash, '');
    const challenge = new URL(recipient.run('buildChallengeURL()'));
    for (const key of ['invitation', 'token', 'api', 'mode']) assert.equal(challenge.searchParams.has(key), false);
    for (const call of recipient.calls.filter(c => c.headers.authorization)) { assert.equal(new URL(call.url).origin, origin); assert.ok(call.path === '/api/core/auth/me' || call.path.startsWith('/api/remix/v2/')); assert.equal(call.redirect, 'error'); assert.equal(call.credentials, 'omit'); }
    assert.ok(![...recipient.data.values()].join('').includes(accounts.bob.token));
  });
  await check('a third account or forged player never gains membership or protected match access', async () => {
    const { service, match, invitation } = await readyPair();
    const other = harness({ service, account: 'carol', href: origin + '/games/remix/?invitation=' + invitation.id }); await other.flush(); await other.accept();
    assert.equal(other.run('activeInvitation'), null); assert.equal(other.posts('accept').length, 0); assert.equal(match.participants.size, 1);
    await other.recover(match.id); assert.equal(other.run('sessionMode'), 'access-denied'); assert.equal(other.run('canSubmitInput()'), false);
  });
  await check('double accept remains one in-flight POST and its durable journal precedes dispatch', async () => {
    const { recipient, match } = await readyPair(), wait = deferred(); let sawJournal = false;
    recipient.after = async (call, result) => { if (call.path.endsWith('/accept')) { sawJournal = recipient.journals().some(e => e.value.operationKey === call.headers['idempotency-key']); await wait.promise; } return result; };
    const first = recipient.run('openOrAcceptInvitation()'); await recipient.flush(); await recipient.run('openOrAcceptInvitation()');
    assert.equal(recipient.posts('accept').length, 1); assert.ok(sawJournal); assert.equal(match.participants.size, 2);
    wait.resolve(); await first; assert.equal(recipient.journals().length, 0);
  });
  await check('lost acceptance is recovered by GET of the same key and never by a second POST', async () => {
    const { recipient, match } = await readyPair();
    recipient.after = (call, result) => call.path.endsWith('/accept') ? reply({ error: 'upstream_unavailable' }, 503) : result;
    await recipient.accept(); assert.equal(match.participants.size, 2); assert.equal(recipient.run('match.id'), match.id);
    const post = recipient.posts('accept')[0]; assert.equal(recipient.posts('accept').length, 1);
    assert.equal(recipient.calls.filter(c => c.path.endsWith('/admission-attempts/' + post.headers['idempotency-key'])).length, 1);
    assert.equal(recipient.journals().length, 0);
  });
  await check('unknown acceptance remains durable across pagehide, scope changes and GET-only reload', async () => {
    const { recipient, service } = await readyPair();
    recipient.handler = call => call.path.endsWith('/accept') ? reply({ error: 'unconfirmed' }, 503) : undefined;
    await recipient.accept(); const journal = recipient.journals()[0]; assert.ok(journal);
    recipient.emit('pagehide');
    const restored = harness({ service, account: 'bob', data: recipient.data, href: origin + '/games/remix/?challenge=other&mode=account' }); await restored.flush();
    assert.equal(restored.journals()[0].key, journal.key); assert.equal(restored.posts('accept').length, 0);
    assert.ok(restored.calls.some(c => c.path.endsWith('/admission-attempts/' + journal.value.operationKey)));
    assert.equal(restored.run('canCreateOwned()'), false);
  });
  await check('pagehide after a committed held accept cannot adopt late output and restores the same operation', async () => {
    const { recipient, service, match } = await readyPair(), wait = deferred();
    recipient.after = async (call, result) => { if (call.path.endsWith('/accept')) await wait.promise; return result; };
    const accepting = recipient.run('openOrAcceptInvitation()'); await recipient.flush(); recipient.emit('pagehide'); wait.resolve(); await accepting;
    assert.equal(recipient.run('match'), null); assert.equal(recipient.journals().length, 1);
    const restored = harness({ service, account: 'bob', data: recipient.data, href: recipient.context.location.href }); await restored.flush();
    assert.equal(restored.run('match.id'), match.id); assert.equal(restored.posts('accept').length, 0); assert.equal(restored.journals().length, 0);
  });
  await check('an account switch during a held acceptance retains only the original actor’s recovery intent', async () => {
    const { recipient, service } = await readyPair(), wait = deferred();
    recipient.after = async (call, result) => { if (call.path.endsWith('/accept')) await wait.promise; return result; };
    const accepting = recipient.run('openOrAcceptInvitation()'); await recipient.flush(); const journal = recipient.journals()[0];
    recipient.tab.set(coreKey, accounts.carol.token); recipient.emit('focus'); wait.resolve(); await accepting;
    await recipient.run('verifyOwnedAccount()'); assert.equal(recipient.run('ownedAccountId'), accounts.carol.id); assert.equal(recipient.run('match'), null);
    assert.equal(recipient.data.get(journal.key), JSON.stringify(journal.value));
    assert.ok(!recipient.calls.filter(c => c.headers.authorization === 'Bearer ' + accounts.carol.token).some(c => c.path.includes('/admission-attempts/')));
  });
  await check('quota before journal dispatch prevents invite and accept POSTs', async () => {
    const { owner, recipient } = await readyPair();
    for (const h of [owner, recipient]) {
      const old = h.context.localStorage.setItem;
      h.context.localStorage.setItem = (key, value) => { if (key.startsWith('osgard:remix-admission:')) throw Error('quota'); old(key, value); };
    }
    await recipient.accept(); assert.equal(recipient.posts('accept').length, 0);
    await owner.run("mutateAdmission('revoke')"); assert.equal(owner.posts('revoke').length, 0);
    assert.equal(recipient.journals().length, 0); assert.equal(owner.journals().length, 0);
  });
  await check('ready acceptance survives an active-pointer-only quota failure and later recovers without POST', async () => {
    const { recipient, service, match } = await readyPair(), old = recipient.context.localStorage.setItem;
    recipient.context.localStorage.setItem = (key, value) => { if (key.startsWith('osgard:remix-session:v2:')) throw Error('pointer quota'); old(key, value); };
    await recipient.accept(); assert.equal(recipient.run('match.id'), match.id); assert.equal(recipient.journals().length, 1);
    const restored = harness({ service, account: 'bob', data: recipient.data, href: recipient.context.location.href }); await restored.flush();
    assert.equal(restored.run('match.id'), match.id); assert.equal(restored.journals().length, 0); assert.equal(restored.posts('accept').length, 0);
  });
  await check('an old tab’s pagehide cannot erase a newer accept journal or force a different invitation target', async () => {
    const { recipient, service, match } = await readyPair(), oldMatch = service.create(accounts.bob.id), data = recipient.data;
    const old = harness({ service, account: 'bob', data }); await old.flush(); await old.recover(oldMatch.id);
    recipient.handler = call => call.path.endsWith('/accept') ? reply({ error: 'unconfirmed' }, 503) : undefined;
    await recipient.accept(); const journal = recipient.journals()[0], saved = data.get(journal.key);
    old.emit('pagehide'); assert.equal(data.get(journal.key), saved);
    const restored = harness({ service, account: 'bob', data, href: recipient.context.location.href }); await restored.flush();
    assert.equal(restored.run('admissionIntent.matchId'), match.id); assert.equal(restored.posts('accept').length, 0);
  });
  await check('revocation wins before accept and definitively rejected action closes only its own journal', async () => {
    const { owner, recipient, invitation, match } = await readyPair();
    await owner.run("mutateAdmission('revoke')"); assert.equal(invitation.status, 'revoked');
    await recipient.accept(); assert.equal(recipient.posts('accept').length, 1); assert.equal(match.participants.size, 1); assert.equal(recipient.journals().length, 0);
    assert.equal(recipient.run('match'), null); assert.equal(recipient.node('#owned-accept-invitation').disabled, true);
  });
  await check('late join after the timer is definitively refused without extending or recreating the match', async () => {
    const { recipient, service, match } = await readyPair(); service.advance(34000);
    await recipient.accept(); assert.equal(match.participants.size, 1); assert.equal(service.matches.size, 1);
    assert.equal(recipient.posts('accept').length, 1); assert.equal(recipient.run('match'), null); assert.equal(recipient.journals().length, 0);
    assert.equal(service.state(match).phase, 'RESULTS'); assert.equal(service.state(match).remainingMs, 0);
  });
  await check('disabled or unknown participant capabilities never enable a join POST', async () => {
    for (const change of [s => { s.enabled = false; }, s => { s.capabilities.participantPolicyVersion = 99; }]) {
      const { service, invitation, match } = await readyPair(); change(service);
      const h = harness({ service, account: 'bob', href: origin + '/games/remix/?invitation=' + invitation.id }); await h.flush(); await h.accept();
      assert.equal(h.posts('accept').length, 0); assert.equal(match.participants.size, 1);
      assert.equal(h.node('#owned-accept-invitation').hidden, true); assert.equal(h.node('#owned-admission-capability').hidden, false);
    }
  });
  await check('malformed and wrong-match operation responses retain the journal and never assign a player', async () => {
    for (const mutation of [v => ({ ...v, operationKey: 'wrong-operation-key-1234' }), v => ({ ...v, match: { ...v.match, id: 'another-match' } }), v => ({ ...v, invitation: { ...v.invitation, recipientAccountId: accounts.carol.id } })]) {
      const { recipient } = await readyPair();
      recipient.after = (call, result) => call.path.endsWith('/accept') || call.path.includes('/admission-attempts/') ? reply(mutation(result.value), result.status) : result;
      await recipient.accept(); assert.equal(recipient.run('match'), null); assert.equal(recipient.journals().length, 1); assert.equal(recipient.posts('accept').length, 1);
    }
  });
  await check('malformed matching journals and storage scan failures stop new actions without eviction', async () => {
    for (const fail of ['malformed', 'read', 'key', 'length']) {
      const { recipient } = await readyPair(), key = recipient.run('admissionPrefix(ownedAccountId)') + 'test-journal-123456789';
      recipient.data.set(key, '{bad');
      if (fail !== 'malformed') { recipient.data.delete(key); recipient.data.set('fixture-unrelated', 'unrelated value'); }
      if (fail === 'read') recipient.context.localStorage.getItem = () => { throw Error('read denied'); };
      if (fail === 'key') recipient.context.localStorage.key = () => { throw Error('key denied'); };
      if (fail === 'length') Object.defineProperty(recipient.context.localStorage, 'length', { get() { throw Error('length denied'); } });
      await recipient.accept(); assert.equal(recipient.posts('accept').length, 0);
      if (fail === 'malformed') assert.equal(recipient.data.get(key), '{bad');
    }
  });
  await check('the admission journal limit never evicts unresolved operations', async () => {
    const { recipient, invitation } = await readyPair();
    for (let n = 0; n < 32; n++) {
      const value = { version: 1, apiBase: origin + '/api/remix', accountId: accounts.bob.id, operation: 'accept', operationKey: 'pending-fixture-key-' + String(n).padStart(4, '0'), matchId: invitation.matchId, invitationId: invitation.id, recipientAccountId: accounts.bob.id, savedAt: recipient.service.now() };
      recipient.data.set(recipient.run('admissionKey(' + JSON.stringify(value) + ')'), JSON.stringify(value));
    }
    const before = [...recipient.data]; await recipient.accept(); assert.equal(recipient.posts('accept').length, 0); assert.deepEqual([...recipient.data], before);
    const value = { ...recipient.journals()[0].value, operationKey: 'a-new-fixture-operation' };
    assert.throws(() => recipient.run('persistAdmission(' + JSON.stringify(value) + ')'), e => e.code === 'owned_recovery_full');
  });
  await check('ready attempt recovery uses fresh self highwater and retains a higher local reservation', async () => {
    const { recipient, service, match } = await readyPair();
    const original = recipient.context.localStorage.setItem;
    recipient.context.localStorage.setItem = (key, value) => { if (key.startsWith('osgard:remix-session:v2:')) throw Error('quota'); original(key, value); };
    await recipient.accept(); match.participants.get(accounts.bob.id).sequence = 8;
    const reserved = { version: 2, apiBase: origin + '/api/remix', accountId: accounts.bob.id, matchId: match.id, sequence: 11 };
    recipient.data.set(recipient.run('ownedReservationKey(' + JSON.stringify(reserved) + ')'), JSON.stringify(reserved));
    const restored = harness({ service, account: 'bob', data: recipient.data, href: recipient.context.location.href }); await restored.flush();
    assert.equal(restored.run('seq'), 11); assert.equal(restored.run('playerId'), match.participants.get(accounts.bob.id).playerId);
    assert.equal(restored.journals().length, 0); assert.equal(restored.posts('accept').length, 0);
  });
  await check('an owner can recover a lost invitation response and copy the same durable invitation after reload', async () => {
    const service = invitationService({ clock: () => Date.UTC(2026, 9, 17, 12) }), match = service.create(), owner = harness({ service });
    await owner.flush(); await owner.recover(match.id);
    owner.after = (call, result) => /\/matches\/[^/]+\/invitations$/.test(call.path) ? reply({ error: 'unconfirmed' }, 503) : result;
    await owner.invite(); assert.equal(owner.posts('invite').length, 1); assert.equal(service.invitations.size, 1); assert.equal(owner.journals().length, 0);
    const id = owner.run('activeInvitation.id'), restored = harness({ service, data: owner.data }); await restored.flush();
    assert.equal(restored.run('activeInvitation.id'), id); assert.equal(restored.posts('invite').length, 0);
    await restored.run("copyAdmissionValue('invitation')"); assert.equal(new URL(restored.copied).searchParams.get('invitation'), id);
  });
  await check('an existing pending invitation is recovered from a stored rejection with its actual recipient', async () => {
    const { service, match, invitation } = await readyPair(), secondOwner = harness({ service });
    await secondOwner.flush(); await secondOwner.recover(match.id); await secondOwner.invite(accounts.carol.id);
    assert.equal(secondOwner.posts('invite').length, 1); assert.equal(service.invitations.size, 1); assert.equal(secondOwner.journals().length, 0);
    assert.equal(secondOwner.run('activeInvitation.id'), invitation.id); assert.equal(secondOwner.run('activeInvitation.recipientAccountId'), accounts.bob.id);
    assert.match(secondOwner.node('#owned-invitation-target').textContent, new RegExp(accounts.bob.id));
    assert.equal(secondOwner.run('activeInvitation.admissionAllowed'), false); // This field is caller-relative: an owner cannot accept.
    assert.match(secondOwner.node('#owned-admission-status').textContent, /pending for its addressed recipient/);
    const restored = harness({ service, data: secondOwner.data }); await restored.flush();
    assert.equal(restored.run('activeInvitation.id'), invitation.id); assert.equal(restored.posts('invite').length, 0);
  });
  await check('a revoked invitation cannot hide a newer pending invitation returned after another tab creates it', async () => {
    const { service, match, owner, invitation } = await readyPair();
    await owner.run("mutateAdmission('revoke')"); assert.equal(owner.run('activeInvitation.id'), invitation.id); assert.equal(invitation.status, 'revoked');
    const otherTab = harness({ service, data: owner.data }); await otherTab.flush(); await otherTab.invite();
    const newer = otherTab.run('activeInvitation.id'); assert.notEqual(newer, invitation.id);
    await owner.invite(accounts.carol.id); assert.equal(owner.run('activeInvitation.id'), newer); assert.equal(owner.run('activeInvitation.recipientAccountId'), accounts.bob.id);
    assert.equal(owner.run('ownedInvitationId'), newer); assert.equal(owner.run('currentOwnedSession(ownedAccountId).invitationId'), newer); assert.equal(owner.journals().length, 0);
    assert.equal(service.invitations.size, 2); assert.equal(service.matches.size, 1); assert.equal(owner.run('match.id'), match.id);
  });
  await check('a pre-reservation denial and missing GET attempt never become a durable rejection', async () => {
    const { recipient, service, match } = await readyPair(); service.enabled = false;
    await recipient.accept(); assert.equal(recipient.posts('accept').length, 1); assert.equal(match.participants.size, 1);
    const saved = recipient.journals()[0]; assert.ok(saved); assert.equal(service.attempts.has(accounts.bob.id + ':' + saved.value.operationKey), false);
    await recipient.run('recoverAdmission()'); assert.equal(recipient.journals()[0].key, saved.key); assert.equal(recipient.posts('accept').length, 1);
    assert.equal(recipient.run('match'), null); assert.equal(recipient.run('canCreateOwned()'), false);
  });
  await check('history navigation cancels an in-flight invitation read without stranding its loading state', async () => {
    const { recipient, service } = await readyPair(), other = service.create(accounts.bob.id), wait = deferred();
    recipient.after = async (call, result) => { if (/\/invitations\/[^/]+$/.test(call.path)) await wait.promise; return result; };
    const reading = recipient.run('readInvitation()'); await recipient.flush(); assert.equal(recipient.run('invitationReading'), true);
    await recipient.recover(other.id); assert.equal(recipient.run('match.id'), other.id); assert.equal(recipient.run('invitationReading'), false);
    wait.resolve(); await reading; assert.equal(recipient.run('match.id'), other.id); assert.equal(recipient.run('invitationReading'), false);
    recipient.after = null; await recipient.run('readInvitation()'); assert.equal(recipient.run('invitationReading'), false);
  });
  await check('an account change while owner metadata is held cannot adopt or discard the old invitation action', async () => {
    const service = invitationService({ clock: () => Date.UTC(2026, 9, 17, 12) }), match = service.create(), owner = harness({ service }), wait = deferred();
    await owner.flush(); await owner.recover(match.id);
    owner.after = async (call, result) => { if (call.path === '/api/remix/v2/matches/' + match.id) await wait.promise; return result; };
    const pending = owner.invite(); await owner.flush(); const saved = owner.journals()[0]; assert.ok(saved); assert.equal(service.invitations.size, 1);
    owner.tab.set(coreKey, accounts.carol.token); owner.emit('focus'); wait.resolve(); await pending; await owner.run('verifyOwnedAccount()');
    assert.equal(owner.run('ownedAccountId'), accounts.carol.id); assert.equal(owner.run('match'), null); assert.equal(owner.data.get(saved.key), JSON.stringify(saved.value));
    const restored = harness({ service, data: owner.data }); await restored.flush(); assert.equal(restored.run('match.id'), match.id); assert.equal(restored.journals().length, 0); assert.equal(restored.posts('invite').length, 0);
  });
  await check('the actual RU and EN dictionary includes invitation controls and dynamic membership labels', async () => {
    const { recipient } = await readyPair(); recipient.run(readFileSync('public/games/remix/interface.js', 'utf8'));
    recipient.run("window.RemixUI.setLanguage('ru')");
    for (const text of ['Join this match', 'Invite this account', 'Copy my Core ID', 'Check saved invitation action', 'Open account matches', 'Assigned accounts · 2 / 2', 'Addressed Core ID · ' + accounts.bob.id, 'Invitation inv_fixture_1 · accepted · Match match_invitation.1']) assert.notEqual(recipient.run('window.RemixUI.t(' + JSON.stringify(text) + ')'), text);
    recipient.run("window.RemixUI.setLanguage('en')"); assert.equal(recipient.run("window.RemixUI.t('Join this match')"), 'Join this match');
  });
  console.log('REMIX invitation smoke: ' + passed + ' PASS, 0 FAIL');
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) await runChecks();
