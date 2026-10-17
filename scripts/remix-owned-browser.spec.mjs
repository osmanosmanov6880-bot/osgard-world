import { test, expect } from '@playwright/test'

// Browser behavior against explicit fixtures of the independently exercised
// Core/guard contract. These credentials only exist inside this test fixture.
// This is not evidence of Unity gameplay, engine recovery or live authentication.
const sessionKey = 'osgard:core-session:v1'
const fixtureTokens = { alice: 'fixture-only-core-session-alice', bob: 'fixture-only-core-session-bob' }

async function ownedFixture(page, info, { creationEnabled = true, signedIn = true, shared = null } = {}) {
  info.annotations.push({ type: 'evidence-scope', description: 'Real browser; explicit Core and REMIX HTTP fixtures; separate from live server and Unity verification.' })
  if (signedIn) await page.addInitScript(({ key, token, origin }) => {
    if (location.origin === origin) sessionStorage.setItem(key, token)
  }, { key: sessionKey, token: fixtureTokens.alice, origin: new URL(info.project.use.baseURL).origin })
  const calls = shared?.calls || [], errors = shared?.errors || [], matches = shared?.matches || new Map(), attempts = shared?.attempts || new Map()
  let releaseMetadata
  const service = shared || {
    calls, errors, matches, attempts, creationEnabled, revoked: false, loseCreateReply: false,
    attemptReady: true, rejectNextInput: false, count: 0,
    metadataGate: null,
    holdMetadata() { this.metadataGate = new Promise(resolve => { releaseMetadata = resolve }) },
    releaseMetadata() { this.metadataGate = null; releaseMetadata?.() },
    creates: () => calls.filter(call => call.method === 'POST' && call.path === '/api/remix/v2/matches'),
    inputs: () => calls.filter(call => call.method === 'POST' && call.path.endsWith('/input')),
  }
  page.on('pageerror', error => errors.push(error.message))
  await page.route('**/api/**', async route => {
    const request = route.request(), url = new URL(request.url()), path = url.pathname, method = request.method()
    const headers = request.headers(), body = request.postData() ? request.postDataJSON() : undefined
    const call = { path, method, body, authorization: headers.authorization || '', key: headers['idempotency-key'] || '', query: url.search }
    calls.push(call)
    const json = async (value, status = 200) => {
      try { await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(value) }) }
      catch (error) { if (!/Target .*closed|net::ERR_ABORTED/.test(String(error))) throw error }
    }
    if (path === '/api/remix/v2/capabilities') return json({ authPolicyVersion: 1, provider: 'core', ownershipPolicy: 'confirmed-durable-binding', creationEnabled: service.creationEnabled, legacyMatches: 'anonymous', activeMatchRecovery: false, replayVerification: false })
    const account = Object.keys(fixtureTokens).find(name => call.authorization === 'Bearer ' + fixtureTokens[name])
    if (path === '/api/core/auth/me') return account && !service.revoked ? json({ user: { id: 'user_' + account, username: account } }) : json({ error: 'authentication_required' }, 401)
    if (path === '/api/remix/v1/challenges' && method === 'POST') return json({ id: 'ch_owned_browser', seed: body.seed, creatorId: body.creatorId, visibility: 'public' }, 201)
    if (!path.startsWith('/api/remix/v2/')) return json({ error: 'fixture_route_not_found' }, 404)
    if (!account || service.revoked) return json({ error: 'authentication_required' }, 401)
    const metadata = match => ({ id: match.id, challengeId: match.challengeId, maxPlayers: 2, createdAt: '2026-10-17T12:00:00Z', accessMode: 'core-owned', playerId: match.playerId, highestSubmittedSequence: match.sequence })
    if (path === '/api/remix/v2/matches' && method === 'POST') {
      if (!service.creationEnabled) return json({ error: 'owned_creation_disabled' }, 403)
      if (!call.key) return json({ error: 'idempotency_key_required' }, 400)
      let match = attempts.get(account + ':' + call.key)
      if (!match) {
        const id = 'match_owned_browser.' + (++service.count)
        match = { id, challengeId: body.challengeId, account, playerId: 'corep_' + service.count.toString(16).padStart(32, '0'), sequence: 0, inputs: 0 }
        matches.set(id, match); attempts.set(account + ':' + call.key, match)
      }
      if (service.loseCreateReply) return json({ error: 'creation_uncertain' }, 503)
      return json(metadata(match), 201)
    }
    if (path === '/api/remix/v2/matches' && method === 'GET') return json({ matches: [...matches.values()].filter(match => match.account === account).map(metadata), nextCursor: null })
    if (path.startsWith('/api/remix/v2/creation-attempts/') && method === 'GET') {
      const key = path.split('/').at(-1), match = attempts.get(account + ':' + key)
      if (!match) return json({ error: 'creation_attempt_not_found' }, 404)
      return service.attemptReady ? json({ operationKey: key, status: 'ready', match: metadata(match) }) : json({ operationKey: key, status: 'uncertain' })
    }
    const routeMatch = path.match(/^\/api\/remix\/v2\/matches\/([^/]+)(?:\/(state|input|result))?$/)
    if (!routeMatch) return json({ error: 'fixture_route_not_found' }, 404)
    const match = matches.get(routeMatch[1]), action = routeMatch[2]
    if (!match) return json({ error: 'match_not_found' }, 404)
    if (match.account !== account) return json({ error: 'match_forbidden' }, 403)
    if (!action && method === 'GET') {
      if (service.metadataGate) await service.metadataGate
      return json(metadata(match))
    }
    if (action === 'state' && method === 'GET') return json({ id: match.id, phase: match.phase || 'PLAYING', players: match.inputs ? 1 : 0, remainingMs: match.phase === 'RESULTS' ? 0 : 30000, replayFrames: match.inputs, scores: match.inputs ? [{ playerId: match.playerId, score: match.inputs / 10 }] : [] })
    if (action === 'result' && method === 'GET' && match.phase === 'RESULTS') return json({ matchId: match.id, phase: 'RESULTS', replayFrames: match.inputs, scores: match.inputs ? [{ playerId: match.playerId, score: match.inputs / 10 }] : [] })
    if (action === 'input' && method === 'POST') {
      if (!Number.isSafeInteger(body.sequence) || body.sequence <= match.sequence) return json({ error: 'stale_input_sequence' }, 409)
      match.sequence = body.sequence
      if (service.rejectNextInput) { service.rejectNextInput = false; return json({ error: 'upstream_write_uncertain' }, 503) }
      match.inputs++
      return json({ playerId: match.playerId, lastSequence: match.sequence, position: [1, 2, 0], velocityY: 0, onGround: true, score: match.inputs / 10 })
    }
    return json({ error: 'match_not_finished' }, 409)
  })
  return service
}

async function openOwned(page, service) {
  await page.goto('/games/remix/?mode=account', { waitUntil: 'domcontentloaded' })
  await expect(page.locator('#live-growth-console')).toHaveAttribute('data-access-mode', 'core-owned')
  await expect(page.locator('#owned-status')).toContainText('alice')
  await expect(page.locator('#owned-signin')).toBeHidden()
  await expect(page.locator('#owned-verify')).toBeEnabled()
  await expect.poll(() => service.calls.filter(call => call.path === '/api/remix/v2/matches' && call.method === 'GET').length).toBeGreaterThan(0)
}

async function createOwned(page, service) {
  await openOwned(page, service)
  await expect(page.locator('#start-match')).toBeEnabled()
  await page.locator('#start-match').click()
  await expect(page.locator('[data-console-action="right"]')).toBeEnabled()
  expect(service.creates()).toHaveLength(1)
  expect(service.creates()[0].body).toEqual({ challengeId: 'ch_owned_browser', maxPlayers: 2 })
  expect(service.creates()[0].key).toMatch(/^[A-Za-z0-9_-]{16,100}$/)
}

async function inputRight(page, info, service) {
  const before = service.inputs().length
  if (info.project.name === 'mobile') await page.locator('[data-console-action="right"]').tap()
  else await page.locator('#arena').press('ArrowRight')
  await expect.poll(() => service.inputs().length).toBe(before + 1)
}

async function ownedRecords(page) {
  return page.evaluate(() => Object.keys(localStorage).filter(key => key.startsWith('osgard:remix-session:v2:')).map(key => ({ key, value: JSON.parse(localStorage.getItem(key)) })))
}

function assertCredentialBoundary(service) {
  for (const call of service.calls) if (call.authorization) {
    expect(call.path === '/api/core/auth/me' || call.path.startsWith('/api/remix/v2/')).toBe(true)
    expect(call.path).not.toBe('/api/remix/v2/capabilities')
  }
  expect(service.calls.filter(call => call.path.startsWith('/api/remix/v1/')).every(call => !call.authorization && !call.key)).toBe(true)
  expect(service.errors).toEqual([])
}

test('REMIX owned fixtures: disabled foundation and safe sign-in continuation', async ({ page }, info) => {
  const service = await ownedFixture(page, info, { creationEnabled: false, signedIn: false })
  await page.goto('/games/remix/?challenge=ch_invite&lang=en&mode=account&api=https://fixture.invalid/custom&token=discard&redirect=discard#discard')
  await expect(page.locator('#owned-signin')).toBeVisible()
  const signIn = new URL(await page.locator('#owned-signin').getAttribute('href'), page.url())
  expect(signIn.pathname).toBe('/workspace')
  expect(signIn.searchParams.get('returnTo')).toBe('/games/remix/?challenge=ch_invite&lang=en&mode=account')
  await page.evaluate(({ key, token }) => sessionStorage.setItem(key, token), { key: sessionKey, token: fixtureTokens.alice })
  await page.locator('#owned-verify').click()
  await expect(page.locator('#owned-status')).toContainText('alice')
  await expect(page.locator('#start-match')).toBeDisabled()
  await expect(page.locator('#api-url')).toBeDisabled()
  expect(service.creates()).toHaveLength(0)
  assertCredentialBoundary(service)
})

test('REMIX owned fixtures: keyboard and touch use assigned player, retain consumed sequence and recover the same match', async ({ page }, info) => {
  const service = await ownedFixture(page, info)
  await createOwned(page, service)
  const match = [...service.matches.values()][0]
  const metadataReads = () => service.calls.filter(call => call.method === 'GET' && call.path === '/api/remix/v2/matches/' + match.id).length
  const readsBeforeInput = metadataReads()
  service.rejectNextInput = true
  await inputRight(page, info, service)
  await expect.poll(metadataReads).toBeGreaterThan(readsBeforeInput)
  await expect(page.locator('[data-console-action="right"]')).toBeEnabled()
  await expect.poll(async () => (await ownedRecords(page))[0]?.value.sequence).toBe(1)
  expect(match.sequence).toBe(1); expect(match.inputs).toBe(0)
  await page.reload({ waitUntil: 'domcontentloaded' })
  await expect(page.locator('[data-console-action="right"]')).toBeEnabled()
  await inputRight(page, info, service)
  await expect(page.locator('#server-position')).toContainText('X 1.00 · Y 2.00')
  expect(service.inputs().map(call => call.body.sequence)).toEqual([1, 2])
  expect(service.inputs().every(call => !Object.hasOwn(call.body, 'playerId'))).toBe(true)
  expect(service.creates()).toHaveLength(1)
  const records = await ownedRecords(page)
  expect(records).toHaveLength(1)
  expect(records[0].value).toMatchObject({ accessMode: 'core-owned', accountId: 'user_alice', matchId: match.id, playerId: match.playerId, sequence: 2 })
  expect(JSON.stringify(records)).not.toContain(fixtureTokens.alice)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
  await page.locator('#live-growth-console').screenshot({ path: info.outputPath('fixture-remix-owned-ru.png') })
  await page.locator('[data-game-language="en"]').click()
  await expect(page.locator('#phase-state')).toHaveText('Match running')
  await expect(page.locator('#owned-panel')).toContainText('Other accounts cannot join')
  await page.locator('#live-growth-console').screenshot({ path: info.outputPath('fixture-remix-owned-en.png') })
  assertCredentialBoundary(service)
})

test('REMIX owned fixtures: ambiguous creation survives reload and recovers only with GET', async ({ page }, info) => {
  const service = await ownedFixture(page, info)
  service.loseCreateReply = true; service.attemptReady = false
  await openOwned(page, service)
  await page.locator('#start-match').click()
  await expect(page.locator('#live-growth-console')).toHaveAttribute('data-session-state', 'creation-uncertain')
  await expect(page.locator('#owned-recover-attempt')).toBeEnabled()
  await expect(page.locator('#start-match')).toBeDisabled()
  const first = service.creates()[0], record = (await ownedRecords(page))[0]
  expect(record.value.operationKey).toBe(first.key)
  expect(record.value.matchId).toBeNull()
  await page.locator('#owned-history-refresh').click()
  await expect(page.locator('[data-owned-match]')).toBeDisabled()
  service.attemptReady = true
  await page.reload({ waitUntil: 'domcontentloaded' })
  await expect(page.locator('[data-console-action="right"]')).toBeEnabled()
  expect(service.creates()).toHaveLength(1)
  expect(service.calls.filter(call => call.path.includes('/creation-attempts/')).every(call => call.method === 'GET' && call.path.endsWith('/' + first.key))).toBe(true)
  expect((await ownedRecords(page))[0].value.matchId).toBe([...service.matches.keys()][0])
  assertCredentialBoundary(service)
})

test('REMIX owned fixtures: leaving during metadata recovery preserves a valid record and reserved sequence', async ({ page }, info) => {
  const service = await ownedFixture(page, info)
  await createOwned(page, service)
  await inputRight(page, info, service)
  await expect(page.locator('#server-position')).toContainText('X 1.00 · Y 2.00')
  const original = (await ownedRecords(page))[0]
  // Model a newer reservation in another tab. It is intentionally above the
  // server high-water and must not be erased by an unverified UI placeholder.
  await page.evaluate(({ key, value }) => {
    value.sequence = 9
    localStorage.setItem(key, JSON.stringify(value))
    window.dispatchEvent(new StorageEvent('storage', { key, newValue: JSON.stringify(value) }))
  }, original)
  const metadataReads = () => service.calls.filter(call => call.method === 'GET' && call.path === '/api/remix/v2/matches/' + original.value.matchId).length
  const before = metadataReads()
  service.holdMetadata()
  try {
    await page.reload({ waitUntil: 'domcontentloaded' })
    await expect.poll(metadataReads).toBeGreaterThan(before)
    await expect(page.locator('[data-console-action="right"]')).toBeDisabled()
    await page.reload({ waitUntil: 'domcontentloaded' })
    expect((await ownedRecords(page))[0].value).toMatchObject({ matchId: original.value.matchId, playerId: original.value.playerId, sequence: 9 })
  } finally { service.releaseMetadata() }
  await expect(page.locator('[data-console-action="right"]')).toBeEnabled()
  await inputRight(page, info, service)
  expect(service.inputs().map(call => call.body.sequence)).toEqual([1, 10])
  expect(service.creates()).toHaveLength(1)
  assertCredentialBoundary(service)
})

test('REMIX owned fixtures: closing an older tab cannot lose a newer ambiguous creation', async ({ page, context }, info) => {
  const service = await ownedFixture(page, info)
  await createOwned(page, service)
  const first = [...service.matches.values()][0]
  first.phase = 'RESULTS'
  await expect(page.locator('#live-growth-console')).toHaveAttribute('data-session-state', 'completed')
  const newer = await context.newPage()
  await ownedFixture(newer, info, { shared: service })
  await openOwned(newer, service)
  await expect(newer.locator('#live-growth-console')).toHaveAttribute('data-session-state', 'completed')
  service.loseCreateReply = true; service.attemptReady = false
  await expect(newer.locator('#start-match')).toBeEnabled()
  await newer.locator('#start-match').click()
  await expect(newer.locator('#live-growth-console')).toHaveAttribute('data-session-state', 'creation-uncertain')
  expect(service.creates()).toHaveLength(2)
  const second = service.creates()[1]
  const journals = await newer.evaluate(() => Object.keys(localStorage).filter(key => key.startsWith('osgard:remix-creation:v2:')).map(key => JSON.parse(localStorage.getItem(key))))
  expect(journals).toHaveLength(1)
  expect(journals[0].operationKey).toBe(second.key)
  expect(JSON.stringify(journals)).not.toContain(fixtureTokens.alice)
  // Observe a real navigation's pagehide before closing the older page.
  await page.evaluate(() => window.addEventListener('pagehide', () => localStorage.setItem('fixture-owned-pagehide', 'observed'), { once: true }))
  await page.goto('about:blank')
  expect(await newer.evaluate(() => localStorage.getItem('fixture-owned-pagehide'))).toBe('observed')
  await page.close()
  const attemptReads = () => service.calls.filter(call => call.method === 'GET' && call.path.endsWith('/creation-attempts/' + second.key)).length
  const readsBeforeReload = attemptReads()
  service.attemptReady = true
  await newer.reload({ waitUntil: 'domcontentloaded' })
  await expect.poll(attemptReads).toBeGreaterThan(readsBeforeReload)
  await expect(newer.locator('[data-console-action="right"]')).toBeEnabled()
  expect(service.creates()).toHaveLength(2)
  expect((await ownedRecords(newer))[0].value.matchId).toBe([...service.matches.keys()][1])
  expect(await newer.evaluate(() => Object.keys(localStorage).filter(key => key.startsWith('osgard:remix-creation:v2:')).length)).toBe(0)
  assertCredentialBoundary(service)
})

test('REMIX owned fixtures: revocation pauses input and a different account cannot inherit the saved match', async ({ page }, info) => {
  const service = await ownedFixture(page, info)
  await createOwned(page, service)
  await inputRight(page, info, service)
  const original = (await ownedRecords(page))[0]
  service.revoked = true
  await expect(page.locator('#live-growth-console')).toHaveAttribute('data-session-state', 'auth-required')
  await expect(page.locator('[data-console-action="right"]')).toBeDisabled()
  await expect(page.locator('#result-card-actions')).toBeHidden()
  const inputs = service.inputs().length
  await page.locator('#arena').press('ArrowRight')
  expect(service.inputs()).toHaveLength(inputs)
  expect(service.calls.filter(call => call.path.includes('/v1/matches/'))).toHaveLength(0)
  service.revoked = false
  await page.evaluate(({ key, token }) => { sessionStorage.setItem(key, token); window.dispatchEvent(new Event('focus')) }, { key: sessionKey, token: fixtureTokens.bob })
  await page.locator('#owned-verify').click()
  await expect(page.locator('#owned-status')).toContainText('bob')
  await expect(page.locator('#owned-verify')).toBeEnabled()
  await expect(page.locator('#owned-history')).not.toContainText(original.value.matchId)
  expect((await ownedRecords(page)).find(record => record.key === original.key)?.value.matchId).toBe(original.value.matchId)
  expect(service.calls.filter(call => call.authorization === 'Bearer ' + fixtureTokens.bob && call.path.includes('/matches/' + original.value.matchId))).toHaveLength(0)
  assertCredentialBoundary(service)
})
