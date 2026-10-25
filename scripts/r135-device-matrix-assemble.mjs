#!/usr/bin/env node
// W16 evidence assembler: joins ONLY already captured original user-owned files.
// NEVER fabricates hardware frames, touch reviews or thermal results.
import { readdir, readFile, lstat, writeFile } from 'node:fs/promises'
import { resolve, basename, dirname, join } from 'node:path'
import { createHash } from 'node:crypto'
import { reviewEvidenceMatrix } from './r135-hardware-matrix.mjs'

export async function collectSessions(folder) {
  const directory = resolve(folder)
  const children = (await readdir(directory)).filter(
    name => name.startsWith('r135-w16-') && name.endsWith('.json')).sort()
  if (!children.length || children.length > 24)
    throw new Error('Expected one to 24 genuine exported r135-w16-*.json files')
  const result = []
  const images = new Set()
  const ids = new Set()
  for (const name of children) {
    if (name !== basename(name) || (await lstat(join(directory,name))).isSymbolicLink())
      throw new Error('Unsafe W16 evidence path')
    const parsed = JSON.parse(await readFile(join(directory,name),'utf8'))
    if (!parsed || !Array.isArray(parsed.sessions) || parsed.sessions.length !== 1)
      throw new Error('Each original export must contain exactly one capture: '+name)
    const record=parsed.sessions[0]
    if (!record || !record.capture || !record.original_screenshot)
      throw new Error('Missing original capture or screenshot: '+name)
    const filename=record.original_screenshot
    if (typeof filename!=='string' || filename!==basename(filename) ||
        !filename.toLowerCase().endsWith('.png') ||
        images.has(filename) || ids.has(record.session_id))
      throw new Error('Unsafe, duplicate or missing original PNG/session: '+name)
    const image=join(directory,filename)
    if ((await lstat(image)).isSymbolicLink())
      throw new Error('Symbolic-link screenshots cannot certify original pixels: '+filename)
    const data=await readFile(image)
    if (data.length<20000 || data.length>8000000 ||
        !data.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))
      throw new Error('Not a genuine-sized PNG file: '+filename)
    const hash=createHash('sha256').update(data).digest('hex')
    if (hash!==record.capture.screenshot_sha256)
      throw new Error('Screenshot was changed after original capture: '+filename)
    images.add(filename)
    ids.add(record.session_id)
    result.push(record)
  }
  return result
}

async function main() {
  const [pinFile, folder, outFlag, outPath] = process.argv.slice(2)
  if (!pinFile || !folder || outFlag!=='--out' || !outPath) {
    console.error('Usage: node scripts/r135-device-matrix-assemble.mjs scripts/r135-w18-release-pin.json path/to/physical-captures --out path/to/w16-sessions.json')
    process.exitCode=2
    return
  }
  const pin=JSON.parse(await readFile(resolve(pinFile),'utf8'))
  const sessions=await collectSessions(folder)
  const raw={schema:'R135_W16_ORIGINAL_DEVICE_SESSIONS_V1',source:pin.source_commit,
    status:'PENDING_INDEPENDENT_PHYSICAL_REVIEW',sessions}
  // Do not silently overwrite any previously collected human review document.
  await writeFile(resolve(outPath),JSON.stringify(raw,null,2)+'\n',{flag:'wx'})
  console.log('W16 original sessions assembled:',sessions.length,
    'No reviewer flags were changed. Keep original PNG files in the SAME directory as final JSON.')
  try {
    const review=reviewEvidenceMatrix(sessions,pin)
    console.log(JSON.stringify(review,null,2))
    if (review.missing.length) process.exitCode=3
  } catch(error) {
    // Expected before independent review: two flags are deliberately FALSE.
    console.warn('W16 independent physical review still required:',String(error))
    process.exitCode=3
  }
}
if (process.argv[1] && import.meta.url ===
    (await import('node:url')).pathToFileURL(resolve(process.argv[1])).href) {
  await main()
}
