export const PROJECT_KEY = 'osa:project:v1'
export type Project = { version: 1; title: string; goal: string; audience: string; plan: string; evidence: string; reflection: string; checks: boolean[]; updatedAt: string }
export const emptyProject = (): Project => ({version:1,title:'',goal:'',audience:'',plan:'',evidence:'',reflection:'',checks:[false,false,false],updatedAt:new Date().toISOString()})
export function parseProject(raw: string): Project {
  if (raw.length > 100000) throw new Error('size')
  const p = JSON.parse(raw)
  if (!p || p.version !== 1 || !['title','goal','audience','plan','evidence','reflection'].every(k => typeof p[k] === 'string' && p[k].length <= 10000) || !Array.isArray(p.checks) || p.checks.length !== 3 || !p.checks.every((c: unknown) => typeof c === 'boolean') || typeof p.updatedAt !== 'string' || !Number.isFinite(Date.parse(p.updatedAt))) throw new Error('format')
  if (p.evidence && !safeEvidence(p.evidence)) throw new Error('url')
  return {version:1,title:p.title,goal:p.goal,audience:p.audience,plan:p.plan,evidence:p.evidence,reflection:p.reflection,checks:[...p.checks],updatedAt:p.updatedAt}
}
export function safeEvidence(value: string) { try { const u = new URL(value); return ['http:','https:'].includes(u.protocol) && !u.username && !u.password } catch { return false } }
export function projectReadiness(p: Project) {
  return [Boolean(p.title.trim() && p.goal.trim() && p.audience.trim()), Boolean(p.plan.trim()), safeEvidence(p.evidence), Boolean(p.reflection.trim()), p.checks.every(Boolean)]
}
