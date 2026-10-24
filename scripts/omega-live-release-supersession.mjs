// EMPIRE Omega — safe live E2E release supersession check.
//
// A previous workflow may still be running when a *newer, verified* game
// becomes live. The older run is superseded, not evidence of an old-version
// rollback. Only GitHub-confirmed strict descendants are allowed to skip;
// unknown, older, divergent, malformed, or unavailable sources MUST fail.
const SHA = /^[0-9a-f]{40}$/i
const REPO = /^[\w.-]+\/[\w.-]+$/

export function isStrictlyNewerCompare(expected, observed, result) {
  return SHA.test(expected) && SHA.test(observed)
    && expected !== observed
    && result?.status === 'ahead'
    && Number.isInteger(result?.ahead_by)
    && result.ahead_by > 0
    && result.behind_by === 0
}

export async function checkNewerLiveRelease(expected, observed, {
  repository = process.env.GITHUB_REPOSITORY,
  token = process.env.GITHUB_TOKEN,
  fetchImpl = fetch
} = {}) {
  if (expected === observed) return {superseded: false, reason: 'exact_match'}
  if (!SHA.test(expected ?? '') || !SHA.test(observed ?? ''))
    return {superseded: false, reason: 'invalid_source_sha'}
  if (!REPO.test(repository ?? '') || !token)
    return {superseded: false, reason: 'unavailable_github_proof'}
  const url = `https://api.github.com/repos/${repository}/compare/${expected}...${observed}`
  try {
    const response = await fetchImpl(url, {
      method: 'GET',
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': `Bearer ${token}`,
        'X-GitHub-Api-Version': '2022-11-28'
      },
      signal: AbortSignal.timeout(15_000)
    })
    if (!response.ok)
      return {superseded: false, reason: `github_compare_http_${response.status}`}
    const result = await response.json()
    if (!isStrictlyNewerCompare(expected, observed, result))
      return {superseded: false, reason: 'source_not_strictly_newer'}
    return {superseded: true, reason: 'verified_newer_deployed_source',
      commits_ahead: result.ahead_by}
  } catch {
    return {superseded: false, reason: 'github_compare_unavailable'}
  }
}
