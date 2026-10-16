import { parseProject, projectReadiness } from './osaProjects.ts'
import type { Project } from './osaProjects.ts'
export const WORKSPACE_KEY = 'osa:workspace:v1'
export type WorkspaceItem = { id: string; published: boolean; revisions: Project[] }
export type Workspace = { version: 1; items: WorkspaceItem[] }
export const emptyWorkspace = (): Workspace => ({version:1,items:[]})
export function parseWorkspace(raw: string): Workspace {
  if (raw.length > 4000000) throw new Error('size')
  const value = JSON.parse(raw)
  if (!value || value.version !== 1 || !Array.isArray(value.items) || value.items.length > 20) throw new Error('format')
  const ids = new Set<string>()
  const items = value.items.map((item: WorkspaceItem) => {
    if (!item || typeof item.id !== 'string' || !/^[a-zA-Z0-9-]{1,64}$/.test(item.id) || ids.has(item.id) || typeof item.published !== 'boolean' || !Array.isArray(item.revisions) || item.revisions.length < 1 || item.revisions.length > 10) throw new Error('item')
    ids.add(item.id)
    return {id:item.id,published:item.published,revisions:item.revisions.map(p => parseProject(JSON.stringify(p)))}
  })
  return {version:1,items}
}
export function addRevision(workspace: Workspace, project: Project, id: string): Workspace {
  const p = parseProject(JSON.stringify(project))
  const existing = workspace.items.find(item => item.id === id)
  if (!existing && workspace.items.length >= 20) throw new Error('limit')
  const item = existing ? {...existing,revisions:[p,...existing.revisions].slice(0,10)} : {id,published:false,revisions:[p]}
  return parseWorkspace(JSON.stringify({...workspace,items:[item,...workspace.items.filter(i => i.id !== id)]}))
}
export function portfolioItems(w: Workspace) { return w.items.filter(i => i.published && projectReadiness(i.revisions[0]).every(Boolean)) }
