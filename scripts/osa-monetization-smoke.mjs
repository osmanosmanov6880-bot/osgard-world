import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const page = readFileSync('src/OSAMonetizationPage.tsx', 'utf8')
const router = readFileSync('src/main.tsx', 'utf8')
const routeSeo = readFileSync('src/routeSeo.ts', 'utf8')
const dashboard = readFileSync('src/OSALearningDashboard.tsx', 'utf8')

assert.ok(router.includes("path === '/learning/pricing'"))
assert.ok(router.includes('<OSAMonetizationPage />'))
assert.ok(routeSeo.includes("'/learning/pricing':"), 'Pricing SEO metadata lives in the lazy registry, not the router')
assert.ok(dashboard.includes('href="/learning/pricing"'))

for (const phrase of [
  'Open learning path',
  'Practical program',
  'Practice cohort',
  'Team pilot',
  'Eight practices and a final project',
  '$79',
  '$499',
  'test price',
  'does not take orders or payments',
  'aria-live',
  'not automatically evaluated',
  'self-check',
]) assert.ok(page.toLowerCase().includes(phrase.toLowerCase()), 'Missing monetization content: ' + phrase)

assert.ok(page.includes('href="/learning"'), 'Free offer must lead to the existing learning route.')
assert.ok(page.includes('https://t.me/OSGARD_world_bot'), 'Team pilot must use the existing OSGARD contact bot.')
assert.ok(page.includes('href="#launch-status"'), 'Unavailable paid offers must disclose launch status.')
assert.ok(!page.includes('checkout.stripe.com'), 'Do not claim or fake a checkout integration.')
assert.ok(!page.includes('payment_intent'), 'Do not claim or fake a payment integration.')
assert.ok(!page.includes('type="email"'), 'Do not collect lead data without a reviewed collection flow.')

console.log('OSA_MONETIZATION_SMOKE_PASS: bilingual learning offer, verified course boundaries, free path, team contact, proposed prices, launch disclosure, and no fake checkout')
