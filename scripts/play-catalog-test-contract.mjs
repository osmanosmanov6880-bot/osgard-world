import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const source = readFileSync(new URL('../src/redesignCatalog.ts', import.meta.url), 'utf8')
const matches = [...source.matchAll(/^\s*"id":\s*"([^"]+)"/gm)]
export const expectedPlayCatalogIds = matches.map(match => match[1])
assert.ok(expectedPlayCatalogIds.length >= 22, 'PLAY catalogue unexpectedly lost released game worlds')
assert.equal(new Set(expectedPlayCatalogIds).size, expectedPlayCatalogIds.length, 'PLAY catalogue contains duplicate game IDs')
export const expectedPlayCatalogCount = expectedPlayCatalogIds.length
