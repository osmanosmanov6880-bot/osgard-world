import { test, expect } from '@playwright/test'
import { readFileSync } from 'node:fs'

// Real Chromium UI, keyboard, touch, canvas, storage and reload behavior against
// explicit fixtures matching the audited REMIX HTTP DTOs. These tests do not
// certify the live backend, immutable replay storage, or the separate Unity build.
async function fixtureService(page, info) {
  info.annotations.push({ type: 'evidence-scope', description: 'Real browser with explicit REMIX HTTP fixtures; no live service or Unity certification.' })
  const failures = [], calls = [], matches = new Map()
  let counter = 0, releaseStateGate
  const service = {
    phase: 'COUNTDOWN', calls, matches, failures, resultFailures: 0,
    position: [1, 2, 0], stateGate: null,
    holdStates() { this.stateGate = new Promise(resolve => { releaseStateGate = resolve }) },
    releaseStates() { this.stateGate = null; releaseStateGate?.() },
    posts(suffix) { return calls.filter(call => call.method === 'POST' && call.path.endsWith(suffix)) },
    inputs() { return this.posts('/input') },
  }
  page.on('pageerror', error => failures.push(error.message))
  await page.route('**/api/remix/**', async route => {
    const request = route.request(), path = new URL(request.url()).pathname, method = request.method()
    const body = method === 'POST' ? request.postDataJSON() : undefined
    calls.push({ path, method, body })
    const json = async (value, status = 200) => {
      try { await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(value) }) }
      catch (error) {
        // A held state request from the old document may be cancelled by reload.
        if (!/Target .*closed|net::ERR_ABORTED/.test(String(error))) throw error
      }
    }
    if (path.endsWith('/v1/challenges') && method === 'POST') {
      await json({ id: 'ch_browser_fixture', seed: body.seed, creatorId: body.creatorId, visibility: body.visibility }, 201)
      return
    }
    if (path.endsWith('/v1/matches') && method === 'POST') {
      const id = 'match_browser_fixture.' + (++counter)
      matches.set(id, { id, challengeId: body.challengeId, inputs: 0, players: new Map() })
      await json({ id, challengeId: body.challengeId, maxPlayers: 2, createdAt: new Date().toISOString() }, 201)
      return
    }
    const id = path.split('/').at(-2), match = matches.get(id)
    if (!match) { await json({ error: 'fixture match not found' }, 404); return }
    const scores = () => [...match.players].map(([playerId, player]) => ({ playerId, score: player.score }))
    if (path.endsWith('/state') && method === 'GET') {
      if (service.stateGate) await service.stateGate
      await json({ id, phase: service.phase, players: match.players.size, remainingMs: service.phase === 'COUNTDOWN' ? 3000 : service.phase === 'RESULTS' ? 0 : 30000, replayFrames: match.inputs, scores: scores() })
      return
    }
    if (path.endsWith('/input') && method === 'POST') {
      const previous = match.players.get(body.playerId)
      if (previous && body.sequence <= previous.lastSequence) {
        await route.fulfill({ status: 409, contentType: 'text/plain', body: 'stale input sequence' })
        return
      }
      // The legacy service accepted late inputs. Reproduce that behavior here so
      // the test proves the client never sends one after observing RESULTS.
      const player = { lastSequence: body.sequence, score: (previous?.score || 0) + 0.05 }
      match.players.set(body.playerId, player); match.inputs++
      await json({ playerId: body.playerId, lastSequence: player.lastSequence, position: service.position, velocityY: 0, onGround: true, score: player.score })
      return
    }
    if (path.endsWith('/result') && method === 'GET') {
      if (service.resultFailures > 0) { service.resultFailures--; await json({ error: 'fixture transient outage' }, 503); return }
      if (service.phase !== 'RESULTS') { await route.fulfill({ status: 409, contentType: 'text/plain', body: 'match has not reached results' }); return }
      await json({ matchId: id, phase: 'RESULTS', replayFrames: match.inputs, scores: scores() })
      return
    }
    failures.push('Unexpected fixture request: ' + method + ' ' + path)
    await json({ error: 'unsupported fixture request' }, 405)
  })
  return service
}

async function enterPlaying(page, service) {
  await page.goto('/games/remix/', { waitUntil: 'domcontentloaded' })
  await expect(page.locator('#start-match')).toContainText('Создать испытание дня')
  await page.locator('#start-match').click()
  await expect(page.locator('#phase-state')).toHaveText('Обратный отсчёт')
  await expect(page.locator('[data-console-action="right"]')).toBeDisabled()
  await expect(page.locator('#rematch-challenge')).toBeDisabled()
  service.phase = 'PLAYING'
  await expect(page.locator('[data-console-action="right"]')).toBeEnabled()
  await expect(page.locator('#phase-state')).toHaveText('Матч идёт')
}

async function submitRight(page, info, service) {
  const before = service.inputs().length
  if (info.project.name === 'mobile') await page.locator('[data-console-action="right"]').tap()
  else await page.locator('#arena').press('ArrowRight')
  await expect.poll(() => service.inputs().length).toBe(before + 1)
  await expect(page.locator('#server-position')).toContainText('X 1.00 · Y 2.00')
}

async function savedSession(page) {
  return page.evaluate(() => {
    const key = Object.keys(localStorage).find(key => key.startsWith('osgard:remix-session:v1:'))
    return key ? JSON.parse(localStorage.getItem(key)) : null
  })
}

test('REMIX HTTP fixtures: legacy invitation redirects to the canonical console without publishing a session', async ({ page }, info) => {
  const service = await fixtureService(page, info), unexpectedSessionWrites = []
  await page.route('**/api/v1/player/**', async route => {
    if (route.request().method() === 'POST') unexpectedSessionWrites.push(route.request().url())
    await route.fulfill({ status: 401, contentType: 'application/json', body: '{"error":"fixture: no authenticated player"}' })
  })
  await page.goto('/play/remix?challenge=ch_browser_fixture&seed=42&lang=en&utm_source=legacy#live-growth-console')
  await page.waitForURL(url => url.pathname === '/games/remix/')
  const url = new URL(page.url())
  expect(url.searchParams.get('challenge')).toBe('ch_browser_fixture')
  expect(url.searchParams.get('seed')).toBe('42')
  expect(url.searchParams.get('lang')).toBe('en')
  expect(url.searchParams.get('utm_source')).toBe('legacy')
  expect(url.hash).toBe('#live-growth-console')
  await expect(page.locator('html')).toHaveAttribute('lang', 'en')
  await expect(page.locator('#start-match')).toContainText('Start this challenge')
  await expect(page.locator('.remix-entry-actions a').first()).toHaveAttribute('href', '#live-growth-console')
  await expect(page.locator('.remix-guide')).toContainText('The Unity build is currently unavailable')
  expect(service.calls).toHaveLength(0)
  expect(unexpectedSessionWrites).toEqual([])
  expect(service.failures).toEqual([])
})

test('REMIX HTTP fixtures: keyboard/touch, projected server position, and RU/EN layout', async ({ page }, info) => {
  const service = await fixtureService(page, info)
  await enterPlaying(page, service)
  await expect(page.locator('.remix-guide')).toContainText('Unity-сборка сейчас недоступна')
  await expect(page.locator('.remix-entry-actions a').first()).toContainText('Открыть консоль испытаний')
  await submitRight(page, info, service)
  expect(service.inputs()[0].body).toMatchObject({ sequence: 1, moveX: 1, moveY: 0, jump: false })
  expect(await page.locator('#arena').evaluate(canvas => [...canvas.getContext('2d').getImageData(204, 66, 1, 1).data])).toEqual([231, 199, 120, 255])
  await expect(page.locator('#arena')).toHaveAttribute('aria-disabled', 'false')
  await expect(page.locator('#phase-time')).toContainText('30 с')
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
  await page.locator('#live-growth-console').screenshot({ path: info.outputPath('fixture-remix-playing-ru.png') })
  await page.locator('[data-game-language="en"]').click()
  await expect(page.locator('.remix-guide')).toContainText('The Unity build is currently unavailable')
  await expect(page.locator('#phase-state')).toHaveText('Match running')
  await expect(page.locator('#server-position')).toHaveText('Server position · X 1.00 · Y 2.00')
  await expect(page.locator('#phase-time')).toHaveText('30 s left in this phase')
  await page.locator('#live-growth-console').screenshot({ path: info.outputPath('fixture-remix-playing-en.png') })
  expect(service.posts('/v1/challenges')).toHaveLength(1)
  expect(service.posts('/v1/matches')).toHaveLength(1)
  expect(service.failures).toEqual([])
})

test('REMIX HTTP fixtures: reload verifies the same match before input and retains player and sequence', async ({ page }, info) => {
  const service = await fixtureService(page, info)
  await enterPlaying(page, service)
  await submitRight(page, info, service)
  const saved = await savedSession(page), firstInput = service.inputs()[0].body
  expect(saved).toMatchObject({ matchId: 'match_browser_fixture.1', sequence: 1, playerId: firstInput.playerId })
  expect(saved).not.toHaveProperty('scores')
  expect(saved).not.toHaveProperty('summary')
  service.holdStates()
  try {
    await page.reload({ waitUntil: 'domcontentloaded' })
    await expect(page.locator('#live-growth-console')).toHaveAttribute('data-session-state', 'restoring')
    await expect(page.locator('#arena')).toHaveAttribute('aria-disabled', 'true')
    await expect(page.locator('#result-card-actions')).toBeHidden()
    expect(service.posts('/v1/matches')).toHaveLength(1)
  } finally { service.releaseStates() }
  await expect(page.locator('[data-console-action="right"]')).toBeEnabled()
  await expect(page.locator('#challenge-copy')).toContainText('Код из приглашения')
  await submitRight(page, info, service)
  expect(service.inputs().at(-1).body).toMatchObject({ playerId: firstInput.playerId, sequence: 2 })
  expect(service.inputs().at(-1).path).toContain('/match_browser_fixture.1/input')
  expect(service.posts('/v1/matches')).toHaveLength(1)
  expect(service.posts('/v1/challenges')).toHaveLength(1)
  expect(service.failures).toEqual([])
})

test('REMIX HTTP fixtures: failed result fetch retries the same match and rematch clears old proof', async ({ page }, info) => {
  const service = await fixtureService(page, info)
  await enterPlaying(page, service)
  await submitRight(page, info, service)
  service.resultFailures = 1; service.phase = 'RESULTS'
  await expect(page.locator('#live-growth-console')).toHaveAttribute('data-session-state', 'result-pending')
  await expect(page.locator('#match-status')).toContainText('Результат пока не загрузился')
  await expect(page.locator('#result-card-actions')).toBeHidden()
  await expect(page.locator('[data-console-action="right"]')).toBeDisabled()
  await expect(page.locator('#rematch-challenge')).toBeDisabled()
  await expect(page.locator('#live-growth-console')).toHaveAttribute('data-session-state', 'completed')
  await expect(page.locator('#result-summary')).toContainText('Вы: 0.05')
  await expect(page.locator('#result-proof-note')).toContainText('Неизменяемый архив повторов пока не проверен')
  await expect(page.locator('#result-card-actions')).toBeVisible()
  await expect(page.locator('#sponsor-slot')).toBeVisible()
  expect(service.calls.filter(call => call.path.endsWith('/result'))).toHaveLength(2)
  expect(service.posts('/v1/matches')).toHaveLength(1)
  await page.locator('#arena').press('ArrowRight')
  expect(service.inputs()).toHaveLength(1)
  await page.locator('#live-growth-console').screenshot({ path: info.outputPath('fixture-remix-complete-ru.png') })
  const downloaded = page.waitForEvent('download')
  await page.locator('#download-result-card').click()
  const card = await downloaded
  expect(card.suggestedFilename()).toBe('osgard-remix-challenge-match_browser_fixture.1.png')
  const cardPath = info.outputPath('fixture-remix-result-card-ru.png')
  await card.saveAs(cardPath)
  const png = readFileSync(cardPath)
  expect(png.subarray(0, 8).toString('hex')).toBe('89504e470d0a1a0a')
  expect([png.readUInt32BE(16), png.readUInt32BE(20)]).toEqual([1200, 630])
  await page.locator('[data-game-language="en"]').click()
  await expect(page.locator('#result-summary')).toHaveText('Server result · You: 0.05')
  await expect(page.locator('#result-proof-note')).toContainText('An immutable replay archive has not been verified')
  await page.locator('#live-growth-console').screenshot({ path: info.outputPath('fixture-remix-complete-en.png') })
  service.phase = 'COUNTDOWN'
  await page.locator('#rematch-challenge').click()
  await expect(page.locator('#phase-state')).toHaveText('Countdown')
  for (const selector of ['#result-summary', '#result-card-actions', '#sponsor-slot']) await expect(page.locator(selector)).toBeHidden()
  await expect(page.locator('#server-position')).toHaveText('Position appears after the service accepts an input.')
  await expect(page.locator('#rematch-challenge')).toBeDisabled()
  expect((await savedSession(page)).sequence).toBe(0)
  expect(service.posts('/v1/matches')).toHaveLength(2)
  expect(service.posts('/v1/challenges')).toHaveLength(1)
  expect(service.failures).toEqual([])
})

test('REMIX HTTP fixtures: denied storage discloses recovery limits and keeps this page playable', async ({ page }, info) => {
  await page.addInitScript(() => {
    for (const method of ['getItem', 'setItem', 'removeItem']) Object.defineProperty(Storage.prototype, method, { value: () => { throw new DOMException('Fixture: storage unavailable', 'SecurityError') } })
  })
  const service = await fixtureService(page, info)
  await enterPlaying(page, service)
  await expect(page.locator('#remix-storage-state')).toBeVisible()
  await expect(page.locator('#remix-storage-state')).toContainText('Оставьте страницу открытой')
  await submitRight(page, info, service)
  expect(service.inputs()[0].body.sequence).toBe(1)
  await page.locator('[data-game-language="en"]').click()
  await expect(page.locator('#remix-storage-state')).toContainText('reloading may lose access')
  expect(service.failures).toEqual([])
})

test('REMIX HTTP fixtures: offline disables input and reconnects to the existing match', async ({ page, context }, info) => {
  const service = await fixtureService(page, info)
  await enterPlaying(page, service)
  await submitRight(page, info, service)
  await context.setOffline(true)
  await expect(page.locator('#match-status')).toContainText('Нет подключения к сети')
  await expect(page.locator('[data-console-action="right"]')).toBeDisabled()
  await page.locator('#arena').press('ArrowRight')
  expect(service.inputs()).toHaveLength(1)
  await context.setOffline(false)
  await expect(page.locator('[data-console-action="right"]')).toBeEnabled()
  await submitRight(page, info, service)
  expect(service.inputs().at(-1).body.sequence).toBe(2)
  expect(service.inputs().at(-1).path).toContain('/match_browser_fixture.1/input')
  expect(service.posts('/v1/matches')).toHaveLength(1)
  expect(service.failures).toEqual([])
})
