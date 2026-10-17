import { test, expect } from '@playwright/test'
import { readFile } from 'node:fs/promises'

// These tests exercise the actual browser UI with an explicit fake transport.
// Payment authorization, persistence and replay rules have separate HTTP/SQLite
// integration tests; no payment provider or production account is contacted.
const curriculum = JSON.parse(await readFile(new URL('../server/curriculum.json', import.meta.url), 'utf8'))
const orderId = 'a'.repeat(32)
const projectId = 'b'.repeat(32)
const routePath = '/learning/enrollment?order=' + orderId
const ownWork = {
  result: 'Создана инструкция для повторяемой учебной задачи.',
  verification: 'Три утверждения проверены по первоисточникам; ограничения записаны.',
  newTask: 'Новый пример задачи с другими исходными учебными данными.',
  transferResult: 'На новом примере проверены результат, время и исправления человека.',
}

function fixture(status = 'payment_required') {
  const program = {
    programId: 'osa-practical-ai', version: 'c'.repeat(64), policyVersion: 'osa-private-practice-v1',
    title: 'OSA — учебная программа для браузерной проверки',
    scope: 'Версия программы и личная практика. Бесплатные лекции остаются доступны.',
    mentorIncluded: false, lessonCount: curriculum.lessons.length, freeModule: '/learning/program',
  }
  return {
    order: {
      id: orderId, version: 1, title: program.title, scope: program.scope,
      amountMinor: 1000, currency: 'USD', status: 'prepared', mode: 'test',
      paidMinor: 0, refundedMinor: 0, checkoutConfirmed: false, accessGranted: false,
      checkoutState: null, refundState: null, refundTargetMinor: null,
      kind: 'learning_program', program, enrollmentActivated: false,
      createdAt: '2026-10-16T12:00:00Z', updatedAt: '2026-10-16T12:00:00Z',
    },
    program, status, version: 0, projectId: null, exportAvailable: false,
  }
}

async function installTransport(page, initialStatus = 'payment_required') {
  const state = fixture(initialStatus)
  const requests = [], mutations = [], unexpected = []
  let getError = null, postError = null
  let practice = { work: { result: '', verification: '', newTask: '', transferResult: '' }, activities: [], submissions: [] }
  const view = () => {
    const result = structuredClone(state)
    if (state.status === 'active') {
      result.curriculum = structuredClone(curriculum)
      result.practice = structuredClone(practice)
      result.completed = curriculum.lessons.filter(lesson => practice.activities.some(item => item.slug === lesson.slug && item.passed)).map(lesson => lesson.slug)
      result.nextLesson = curriculum.lessons.find(lesson => !result.completed.includes(lesson.slug))?.slug || null
    }
    return result
  }
  const activate = () => {
    state.status = 'active'; state.version = 1; state.projectId = projectId; state.exportAvailable = true
    state.order.enrollmentActivated = true
  }
  const reply = (request, status, value) => request.fulfill({ status, contentType: 'application/json', body: JSON.stringify(value) })
  await page.route('**/api/core/**', async request => {
    const url = new URL(request.request().url()), method = request.request().method()
    requests.push({ path: url.pathname, method })
    if (url.pathname === '/api/core/learning/enrollments/' + orderId + '/export' && method === 'GET') {
      if (!state.exportAvailable) return reply(request, 404, { error: 'not_found', message: 'Личная программа не найдена.' })
      return reply(request, 200, { format: 'osgard-program-own-work-v1', orderId, projectId, work: practice.work, activities: practice.activities, submissions: practice.submissions })
    }
    if (url.pathname !== '/api/core/learning/enrollments/' + orderId) {
      unexpected.push(url.pathname); return reply(request, 500, { error: 'unexpected_fixture_route' })
    }
    if (method === 'GET') return getError ? reply(request, getError.status, getError.body) : reply(request, 200, view())
    const body = request.request().postDataJSON()
    mutations.push(body)
    if (postError) { const failure = postError; postError = null; return reply(request, failure.status, failure.body) }
    if (body.action === 'activate') {
      activate()
      return reply(request, 200, { orderId, projectId, version: state.version, alreadyActivated: false })
    }
    state.version++
    if (body.action === 'activity') {
      practice.activities.push({ id: 'activity-' + state.version, slug: body.slug, practice: body.practice, passed: true, createdAt: '2026-10-16T12:15:00Z' })
      return reply(request, 200, { feedback: { passed: true, explanation: 'Ответ соответствует учебному примеру.' } })
    }
    if (body.action === 'save_work') practice.work = structuredClone(body.work)
    if (body.action === 'submit') practice.submissions.push({ id: 'submission-' + state.version, sourceVersion: state.version - 1, createdAt: '2026-10-16T12:20:00Z' })
    return reply(request, 200, { orderId, version: state.version })
  })
  return {
    state, requests, mutations, unexpected, activate,
    failGet(status, message) { getError = { status, body: { error: 'fixture_access', message } } },
    restoreGet() { getError = null },
    failNextPost(status, message) { postError = { status, body: { error: 'version_conflict', message } } },
    practice() { return practice },
  }
}

const goalLabel = 'Какой полезный результат вы хотите получить'
const practiceLabel = 'Результат вашей практики и доказательства'
const workLabels = {
  result: 'Итоговый результат: текст, ссылка или описание созданного проекта',
  verification: 'Как вы проверили результат и что остаётся ограничением',
  newTask: 'Новая задача для проверки навыка',
  transferResult: 'Результат на новой задаче, доказательства и помощь человека',
}
const notice = page => page.locator('.program-enrollment [role="status"]')

test('program entry preserves login return and does not promise uncreated work after refund', async ({ page }) => {
  const transport = await installTransport(page)
  await page.goto('/learning/enrollment')
  await expect(page.getByRole('heading', { name: 'Выберите учебный заказ' })).toBeVisible()
  await expect(page.locator('meta[name="robots"]')).toHaveAttribute('content', 'noindex,follow')
  expect(transport.requests).toHaveLength(0)
  transport.failGet(401, 'Нужен вход в аккаунт покупателя.')
  await page.goto(routePath)
  const login = page.getByRole('link', { name: 'Войти и продолжить' })
  await expect(login).toBeVisible()
  expect(new URLSearchParams((await login.getAttribute('href')).split('?')[1]).get('returnTo')).toBe(routePath)
  transport.restoreGet(); transport.state.status = 'refunded'
  await page.goto(routePath)
  await expect(page.getByText('Оплаченный доступ отозван после полного возврата', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Создать личную практику' })).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Экспортировать мои работы' })).toHaveCount(0)
  await expect(page.getByText('Созданный проект и экспорт ваших работ сохранены', { exact: false })).toHaveCount(0)
  expect(transport.mutations).toEqual([])
  expect(transport.unexpected).toEqual([])
})

test('program purchase UI requires consent, persists work and keeps owner export after refund', async ({ page }, info) => {
  const transport = await installTransport(page), failures = []
  page.on('pageerror', error => failures.push(error.message))
  await page.goto(routePath)
  await expect(page.getByText('Ожидаем подтверждённую оплату', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Создать личную практику' })).toHaveCount(0)
  transport.state.status = 'activation_required'
  transport.state.order = { ...transport.state.order, paidMinor: 1000, checkoutConfirmed: true, accessGranted: true, status: 'paid' }
  await page.getByRole('button', { name: 'Обновить доступ и программу' }).click()
  const start = page.getByRole('button', { name: 'Создать личную практику' })
  await expect(start).toBeDisabled()
  await page.getByLabel(goalLabel, { exact: true }).fill('Создать проверенную инструкцию для учебной задачи.')
  await expect(start).toBeDisabled()
  await page.getByRole('checkbox', { name: 'Разрешаю Learning', exact: false }).check()
  await start.click()
  await expect(page.getByText('Личная программа активна', { exact: true })).toBeVisible()
  expect(transport.mutations[0]).toMatchObject({ action: 'activate', learningConsent: true, expectedVersion: 0 })
  const lesson = curriculum.lessons[0]
  await page.getByLabel(lesson.ru.check.question, { exact: false }).selectOption(String(lesson.ru.check.correctIndex))
  await page.getByLabel(practiceLabel, { exact: true }).fill('Проверены источники и записан собственный результат учебной практики.')
  await page.getByRole('button', { name: 'Сохранить практику', exact: true }).click()
  await expect(notice(page)).toContainText('Практический текст сохранён')
  await expect(page.getByText('Сохранено с верной самопроверкой: 1 из ' + curriculum.lessons.length + '.', { exact: true })).toBeVisible()
  for (const [key, label] of Object.entries(workLabels)) await page.getByRole('textbox', { name: label, exact: true }).fill(ownWork[key])
  await page.getByRole('button', { name: 'Сохранить итоговую работу', exact: true }).click()
  await expect(notice(page)).toContainText('Черновик итоговой работы сохранён')
  await expect(page.getByRole('button', { name: 'Зафиксировать итоговую версию' })).toBeDisabled()
  await page.reload()
  await expect(page.getByRole('textbox', { name: workLabels.result, exact: true })).toHaveValue(ownWork.result)
  await expect(page.locator('html')).toHaveAttribute('data-product', 'intelligence')
  await expect(page.locator('h1')).toHaveCount(1)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1)).toBe(true)
  const colors = await page.locator('.program-enrollment .core-panel').first().evaluate(panel => ({ background: getComputedStyle(panel).backgroundColor, heading: getComputedStyle(panel.querySelector('h2')).color }))
  const luminance = color => {
    const parts = color.match(/[\d.]+/g)?.slice(0, 3).map(Number)
    expect(parts).toHaveLength(3)
    return parts.map(value => { const c = value / 255; return c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4 }).reduce((sum, value, index) => sum + value * [0.2126, 0.7152, 0.0722][index], 0)
  }
  const l1 = luminance(colors.background), l2 = luminance(colors.heading)
  expect((Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05)).toBeGreaterThanOrEqual(4.5)
  await page.evaluate(() => document.fonts.ready)
  await page.screenshot({ path: info.outputPath('program-active.png'), fullPage: true })
  transport.state.status = 'refunded'; transport.state.order.accessGranted = false; transport.state.order.refundedMinor = 1000
  await page.getByRole('button', { name: 'Обновить доступ и программу' }).click()
  await expect(page.getByRole('button', { name: 'Сохранить практику', exact: true })).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Сохранить итоговую работу', exact: true })).toHaveCount(0)
  const downloaded = page.waitForEvent('download')
  await page.getByRole('button', { name: 'Экспортировать мои работы', exact: true }).click()
  const file = await downloaded
  expect(file.suggestedFilename()).toBe('osa-program-own-work-' + orderId + '.json')
  const exported = JSON.parse(await readFile(await file.path(), 'utf8'))
  expect(exported.work).toEqual(ownWork)
  expect(exported.activities).toHaveLength(1)
  await page.screenshot({ path: info.outputPath('program-refunded.png'), fullPage: true })
  expect(transport.unexpected).toEqual([])
  expect(failures).toEqual([])
})

test('program refresh discards a confirmed draft and version conflicts preserve unsaved text', async ({ page }) => {
  const transport = await installTransport(page)
  transport.activate()
  await page.goto(routePath)
  const lesson = curriculum.lessons[0]
  await page.getByLabel(lesson.ru.check.question, { exact: false }).selectOption('0')
  await page.getByLabel(practiceLabel, { exact: true }).fill('Несохранённая попытка, которую пользователь согласен удалить.')
  let confirmations = 0
  page.once('dialog', async dialog => { confirmations++; expect(dialog.type()).toBe('confirm'); await dialog.accept() })
  await page.getByRole('button', { name: 'Обновить доступ и программу' }).click()
  await expect(page.getByLabel(practiceLabel, { exact: true })).toHaveValue('')
  await expect(page.getByLabel(lesson.ru.check.question, { exact: false })).toHaveValue('')
  expect(confirmations).toBe(1)
  const unsaved = 'Несохранённый новый результат должен остаться после конфликта версий.'
  await page.getByRole('textbox', { name: workLabels.result, exact: true }).fill(unsaved)
  transport.failNextPost(409, 'Практика изменена в другой вкладке. Загрузите последнюю версию.')
  await page.getByRole('button', { name: 'Сохранить итоговую работу', exact: true }).click()
  const alert = page.locator('.program-enrollment [role="alert"]')
  await expect(alert).toContainText('другой вкладке')
  await expect(alert).toBeFocused()
  await expect(page.getByRole('textbox', { name: workLabels.result, exact: true })).toHaveValue(unsaved)
  transport.state.status = 'consent_required'
  page.once('dialog', dialog => dialog.accept())
  await page.getByRole('button', { name: 'Обновить доступ и программу' }).click()
  await expect(page.getByText('Нужно согласие на использование Learning', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Сохранить практику', exact: true })).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Экспортировать мои работы', exact: true })).toBeEnabled()
  expect(transport.unexpected).toEqual([])
})
