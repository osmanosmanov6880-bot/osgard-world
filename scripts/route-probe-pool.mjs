// Preserve route/device order while bounding concurrent public-network probes.
export async function runProbes(jobs, maxParallel, probe) {
  if (!Array.isArray(jobs)) throw new TypeError('jobs must be an array')
  if (!Number.isInteger(maxParallel) || maxParallel < 1) throw new RangeError('maxParallel must be a positive integer')
  if (typeof probe !== 'function') throw new TypeError('probe must be a function')

  const results = new Array(jobs.length)
  let nextIndex = 0
  async function worker() {
    while (nextIndex < jobs.length) {
      const index = nextIndex++
      results[index] = await probe(jobs[index], index)
    }
  }
  await Promise.all(Array.from({ length: Math.min(maxParallel, jobs.length) }, worker))
  return results
}
