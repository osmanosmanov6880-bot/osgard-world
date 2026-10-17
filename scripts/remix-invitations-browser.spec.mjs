import { test, expect } from '@playwright/test'
import { invitationService, accounts, coreKey, reply } from './remix-invitations-smoke.mjs'

// Real browser interactions against the explicit, timed two-account HTTP
// fixture. They do not certify live Core admission, Unity or verified replay.
async function install(page, info, service, account = 'alice') {
  const origin = new URL(info.project.use.baseURL).origin
  if (account) await page.addInitScript(({ origin, key, token }) => {
    if (location.origin === origin) sessionStorage.setItem(key, token)
  }, { origin, key: coreKey, token: accounts[account].token })
  const errors = []
  page.on('pageerror', error => errors.push(error.message))
  await page.route('**/api/**', async route => {
    const request = route.request(), target = new URL(request.url())
    const call = { path: target.pathname, url: target.href, method: request.method(), headers: request.headers(), body: request.postData() ? request.postDataJSON() : undefined }
    if (service.before) await service.before(call, page)
    let result = service.handle(call)
    if (service.after) result = await service.after(call, result, page) || result
    try { await route.fulfill({ status: result.status, contentType: 'application/json', body: JSON.stringify(result.value) }) }
    catch (error) { if (!/Target .*closed|net::ERR_ABORTED/.test(String(error))) throw error }
  })
  info.annotations.push({ type: 'evidence-scope', description: 'Timed two-account Core/REMIX HTTP fixture; real browser handlers. Separate from live API or Unity evidence.' })
  return errors
}

const posts = (service, operation) => service.calls.filter(c => c.method === 'POST' && (operation === 'invite' ? /\/matches\/[^/]+\/invitations$/.test(c.path) : c.path.endsWith('/' + operation)))
const journal = page => page.evaluate(() => Object.keys(localStorage).filter(k => k.startsWith('osgard:remix-admission:v1:')).map(key => ({ key, value: JSON.parse(localStorage.getItem(key)) })))

async function pair(page, info) {
  const service = invitationService(), errors = await install(page, info, service)
  await page.goto('/games/remix/?mode=account&lang=en', { waitUntil: 'domcontentloaded' })
  await expect(page.locator('#owned-status')).toContainText('alice')
  await expect(page.locator('#start-match')).toBeEnabled()
  await page.locator('#start-match').click()
  await expect(page.locator('#owned-create-invite')).toBeEnabled()
  await page.locator('#owned-invite-recipient').fill(accounts.bob.id)
  await page.locator('#owned-create-invite').click()
  await expect(page.locator('#owned-invitation-link')).toHaveValue(/invitation=/)
  const invitation = [...service.invitations.values()][0], match = service.matches.get(invitation.matchId)
  const recipient = await page.context().newPage(), recipientErrors = await install(recipient, info, service, 'bob')
  await recipient.goto('/games/remix/?invitation=' + invitation.id + '&mode=account&lang=en', { waitUntil: 'domcontentloaded' })
  await expect(recipient.locator('#owned-status')).toContainText('bob')
  await expect(recipient.locator('#owned-accept-invitation')).toBeEnabled()
  expect(posts(service, 'accept')).toHaveLength(0)
  return { service, match, invitation, recipient, errors, recipientErrors }
}

async function input(page, info, direction = 'right') {
  const button = page.locator('[data-console-action="' + direction + '"]')
  await expect(button).toBeEnabled()
  if (info.project.name === 'mobile') await button.tap()
  else await page.locator('#arena').press(direction === 'right' ? 'ArrowRight' : 'ArrowLeft')
}

async function screenshot(page, info, name) {
  const path = info.outputPath(name + '-' + info.project.name + '.png')
  await page.locator('#live-growth-console').screenshot({ path })
  await info.attach(name, { path, contentType: 'image/png' })
}

function credentialBoundary(service, info) {
  const origin = new URL(info.project.use.baseURL).origin
  for (const call of service.calls.filter(c => c.headers.authorization)) {
    expect(new URL(call.url).origin).toBe(origin)
    expect(call.path === '/api/core/auth/me' || call.path.startsWith('/api/remix/v2/')).toBeTruthy()
    expect(new URL(call.url).search).not.toMatch(/token|authorization|recipientAccountId/i)
    expect(JSON.stringify(call.body || {})).not.toMatch(/fixture-core-/)
  }
}

test('REMIX invitation fixtures: explicit second account, independent inputs and shared terminal result', async ({ page }, info) => {
  const p = await pair(page, info)
  try {
    expect(p.match.participants.size).toBe(1)
    await p.recipient.locator('#owned-accept-invitation').click()
    await expect(p.recipient.locator('#owned-participants')).toHaveText('Assigned accounts · 2 / 2')
    expect(posts(p.service, 'accept')).toHaveLength(1)
    expect(p.match.participants.size).toBe(2)
    expect(p.service.state(p.match).players).toBe(0)
    await input(page, info); await input(p.recipient, info, 'left')
    await expect.poll(() => p.service.state(p.match).players).toBe(2)
    expect(p.match.participants.get(accounts.alice.id).sequence).toBe(1)
    expect(p.match.participants.get(accounts.bob.id).sequence).toBe(1)
    expect(p.match.participants.get(accounts.alice.id).playerId).not.toBe(p.match.participants.get(accounts.bob.id).playerId)
    expect(p.service.calls.filter(c => c.path.endsWith('/input')).every(c => !('playerId' in c.body))).toBeTruthy()
    await expect(p.recipient.locator('#server-position')).toContainText('X -0.10')
    p.service.advance(34000)
    await expect(page.locator('#result-summary')).toContainText('You: 0.1')
    await expect(p.recipient.locator('#result-summary')).toContainText('You: 0.1')
    expect(p.service.state(p.match).scores).toHaveLength(2)
    await page.locator('[data-game-language="ru"]').click()
    await expect(page.locator('#owned-participants')).toContainText('Назначенных аккаунтов')
    await screenshot(page, info, 'remix-invitation-owner-ru-results')
    await screenshot(p.recipient, info, 'remix-invitation-recipient-en-results')
    credentialBoundary(p.service, info)
    expect([...p.errors, ...p.recipientErrors]).toEqual([])
  } finally { await p.recipient.close() }
})

test('REMIX invitation fixtures: sign-in target, third-account denial and explicit disabled foundation', async ({ page }, info) => {
  const service = invitationService(), match = service.create()
  const created = service.handle({ path: '/api/remix/v2/matches/' + match.id + '/invitations', method: 'POST', headers: { authorization: 'Bearer ' + accounts.alice.token, 'idempotency-key': 'browser-setup-invite-12345' }, body: { recipientAccountId: accounts.bob.id } })
  const id = created.value.invitation.id
  service.calls.length = 0
  await install(page, info, service, null)
  await page.goto('/games/remix/?invitation=' + id + '&lang=en&token=do-not-copy&api=https://other.example&mode=account#private', { waitUntil: 'domcontentloaded' })
  await expect(page.locator('#owned-signin')).toBeVisible()
  const link = new URL(await page.locator('#owned-signin').getAttribute('href'), info.project.use.baseURL)
  expect(link.searchParams.get('returnTo')).toBe('/games/remix/?invitation=' + id + '&lang=en&mode=account')
  expect(posts(service, 'accept')).toHaveLength(0)
  await page.locator('#owned-signin').click()
  await expect(page).toHaveURL(/\/workspace\?returnTo=/)
  await page.evaluate(({ key, token }) => sessionStorage.setItem(key, token), { key: coreKey, token: accounts.carol.token })
  await page.goto(link.searchParams.get('returnTo'), { waitUntil: 'domcontentloaded' })
  await expect(page.locator('#owned-admission-status')).toContainText('Only its addressed recipient')
  expect(posts(service, 'accept')).toHaveLength(0)
  service.enabled = false
  await page.evaluate(({ key, token }) => sessionStorage.setItem(key, token), { key: coreKey, token: accounts.bob.token })
  await page.reload({ waitUntil: 'domcontentloaded' })
  await expect(page.locator('#owned-admission-capability')).toBeVisible()
  await expect(page.locator('#owned-admission-capability')).toContainText('disabled by this service')
  await expect(page.locator('#owned-accept-invitation')).toBeHidden()
  expect(posts(service, 'accept')).toHaveLength(0)
  await screenshot(page, info, 'remix-invitation-disabled-foundation')
})

test('REMIX invitation fixtures: ambiguous accept survives actual old-tab pagehide and reload with GET only', async ({ page }, info) => {
  const p = await pair(page, info)
  const old = await page.context().newPage()
  let ready = false
  try {
    const oldMatch = p.service.create(accounts.bob.id)
    await install(old, info, p.service, 'bob')
    await old.goto('/games/remix/?mode=account&lang=en', { waitUntil: 'domcontentloaded' })
    await old.locator('[data-owned-match="' + oldMatch.id + '"]').click()
    await expect(old.locator('#match-title')).toContainText(oldMatch.id)
    await old.evaluate(() => window.addEventListener('pagehide', () => localStorage.setItem('fixture:admission-pagehide', 'observed'), { once: true }))
    p.service.after = (call, result) => call.path.endsWith('/accept') || call.path.includes('/admission-attempts/') && !ready ? reply({ error: 'fixture_reply_unavailable' }, 503) : result
    await p.recipient.locator('#owned-accept-invitation').click()
    await expect(p.recipient.locator('#owned-admission-recover')).toBeVisible()
    const saved = (await journal(p.recipient)).find(e => e.value.operation === 'accept')
    expect(saved).toBeTruthy()
    await old.goto('about:blank')
    await expect.poll(() => p.recipient.evaluate(() => localStorage.getItem('fixture:admission-pagehide'))).toBe('observed')
    await old.close()
    expect((await journal(p.recipient)).find(e => e.key === saved.key)).toEqual(saved)
    const reads = () => p.service.calls.filter(c => c.path.endsWith('/admission-attempts/' + saved.value.operationKey)).length
    const before = reads(); ready = true
    await p.recipient.reload({ waitUntil: 'domcontentloaded' })
    await expect.poll(reads).toBeGreaterThan(before)
    await expect(p.recipient.locator('#match-title')).toContainText(p.match.id)
    expect(posts(p.service, 'accept')).toHaveLength(1)
    await expect.poll(() => journal(p.recipient)).toEqual([])
    await screenshot(p.recipient, info, 'remix-invitation-recovered-accept')
  } finally { if (!old.isClosed()) await old.close(); await p.recipient.close() }
})

test('REMIX invitation fixtures: denied journal storage prevents acceptance before any POST', async ({ page }, info) => {
  const p = await pair(page, info)
  try {
    const quotaCode = await p.recipient.evaluate(() => {
      const original = Storage.prototype.setItem
      const quota = new DOMException('Fixture quota', 'QuotaExceededError')
      Storage.prototype.setItem = function (key, value) {
        if (this === localStorage && key.startsWith('osgard:remix-admission:v1:')) throw quota
        return original.call(this, key, value)
      }
      return quota.code
    })
    expect(quotaCode).toBe(22)
    await p.recipient.locator('#owned-accept-invitation').click()
    await expect(p.recipient.locator('#owned-admission-status')).toContainText('recovery storage is unavailable')
    const reads = () => p.service.calls.filter(call => call.method === 'GET' && call.path.endsWith('/v2/invitations/' + p.invitation.id) && call.headers.authorization === 'Bearer ' + accounts.bob.token).length
    const before = reads()
    await expect.poll(reads).toBeGreaterThan(before + 1)
    await expect(p.recipient.locator('#owned-admission-status')).toContainText('recovery storage is unavailable')
    await p.recipient.locator('#owned-refresh-invitation').click()
    await expect.poll(reads).toBeGreaterThan(before + 2)
    await expect(p.recipient.locator('#owned-admission-status')).toContainText('recovery storage is unavailable')
    expect(posts(p.service, 'accept')).toHaveLength(0)
    expect(p.match.participants.size).toBe(1)
    expect(await journal(p.recipient)).toEqual([])
    await screenshot(p.recipient, info, 'remix-invitation-storage-unavailable')
  } finally { await p.recipient.close() }
})

test('REMIX invitation fixtures: confirmed accept retains recovery when only the active pointer is full', async ({ page }, info) => {
  const p = await pair(page, info)
  try {
    await p.recipient.evaluate(() => {
      const original = Storage.prototype.setItem
      Storage.prototype.setItem = function (key, value) {
        if (this === localStorage && key.startsWith('osgard:remix-session:v2:')) throw new DOMException('Fixture active-pointer quota', 'QuotaExceededError')
        return original.call(this, key, value)
      }
    })
    await p.recipient.locator('#owned-accept-invitation').click()
    await expect(p.recipient.locator('#match-title')).toContainText(p.match.id)
    await expect.poll(async () => (await journal(p.recipient)).length).toBe(1)
    expect(p.match.participants.size).toBe(2)
    await p.recipient.reload({ waitUntil: 'domcontentloaded' })
    await expect(p.recipient.locator('#match-title')).toContainText(p.match.id)
    await expect.poll(() => journal(p.recipient)).toEqual([])
    expect(posts(p.service, 'accept')).toHaveLength(1)
  } finally { await p.recipient.close() }
})

test('REMIX invitation fixtures: the match closes between preview and explicit join without a replacement', async ({ page }, info) => {
  const p = await pair(page, info)
  try {
    p.service.before = call => { if (call.path.endsWith('/accept')) p.service.advance(34000) }
    await p.recipient.locator('#owned-accept-invitation').click()
    await expect(p.recipient.locator('#owned-admission-status')).toContainText('invitation is closed')
    expect(posts(p.service, 'accept')).toHaveLength(1)
    expect(p.service.matches.size).toBe(1)
    expect(p.match.participants.size).toBe(1)
    expect(await journal(p.recipient)).toEqual([])
    await expect(p.recipient.locator('#owned-accept-invitation')).toBeDisabled()
    expect(p.service.state(p.match).phase).toBe('RESULTS')
  } finally { await p.recipient.close() }
})
