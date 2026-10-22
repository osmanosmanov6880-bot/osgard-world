import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const page = readFileSync('src/OSAMonetizationPage.tsx', 'utf8')
const router = readFileSync('src/main.tsx', 'utf8')
const seo = readFileSync('src/routeSeo.ts', 'utf8')
const dashboard = readFileSync('src/OSALearningDashboard.tsx', 'utf8')

assert.ok(router.includes("path === '/learning/pricing'"))
assert.ok(router.includes('<OSAMonetizationPage />'))
// Route metadata moved out of main.tsx for lazy loading; verify the real SEO registry.
assert.ok(router.includes("import('./routeSeo')"))
assert.ok(seo.includes("'/learning/pricing': { title:"))
assert.ok(dashboard.includes('href="/learning/pricing"'))

for (const phrase of [
  'Open access',
  'Practical course',
  'Practice cohort',
  'Team pilot',
  '$79',
  '$499',
  'test price',
  'does not currently take orders',
  'accept payments',
  'aria-live',
]) assert.ok(page.includes(phrase), 'Missing monetization content: ' + phrase)

assert.ok(page.includes('href="/learning"'), 'The free offer must lead to the existing learning route.')
assert.ok(page.includes('href="#pilot-status"'), 'Paid offer CTAs must disclose the pilot state.')
assert.ok(!page.includes('checkout.stripe.com'), 'Do not claim or fake a checkout integration.')
assert.ok(!page.includes('payment_intent'), 'Do not claim or fake a payment integration.')

console.log('OSA_MONETIZATION_SMOKE_PASS: pricing route, four offers, free path, proposed prices, bilingual launch disclosure, and no fake checkout')
