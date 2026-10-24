import test from 'node:test'
import assert from 'node:assert/strict'
import { runProbes } from './route-probe-pool.mjs'

test('probes preserve stable route order and do not exceed the parallel request budget', async () => {
  const jobs = Array.from({ length: 17 }, (_, index) => ({ route: `/probe-${index}` }))
  let active = 0
  let peak = 0
  const completed = await runProbes(jobs, 3, async (job, index) => {
    active++
    peak = Math.max(peak, active)
    await new Promise(resolve => setTimeout(resolve, 2 + (index % 4) * 2))
    active--
    return `${index}:${job.route}`
  })
  assert.deepEqual(completed, jobs.map((job, index) => `${index}:${job.route}`))
  assert.equal(peak, 3)
  assert.equal(active, 0)
})

test('empty probe matrix has no effects', async () => {
  let called = false
  const results = await runProbes([], 3, async () => { called = true })
  assert.deepEqual(results, [])
  assert.equal(called, false)
})

test('invalid pool settings fail instead of silently skipping routes', async () => {
  await assert.rejects(runProbes([], 0, async () => {}), /maxParallel/)
  await assert.rejects(runProbes([], 1.5, async () => {}), /maxParallel/)
  await assert.rejects(runProbes(null, 3, async () => {}), /jobs must/)
  await assert.rejects(runProbes([], 3, null), /probe must/)
})
