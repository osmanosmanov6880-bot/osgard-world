import test from 'node:test'
import assert from 'node:assert/strict'
import { build } from 'esbuild'
const b=await build({entryPoints:['src/osaCinemaWatchlist.ts'],bundle:true,write:false,format:'esm',platform:'node'})
const store=await import('data:text/javascript;base64,'+Buffer.from(b.outputFiles[0].text).toString('base64'))
const {normalizeWatchlist,exportWatchlist,parseWatchlistBackup,OSA_STUDIO_BACKUP_SCHEMA}=store
const ids=['zero-window','the-next-human','threshold']
test('Watchlist filters invalid IDs, preserves order and prevents duplication',()=>{
 assert.deepEqual(normalizeWatchlist(['zero-window','zero-window','unknown','threshold','the-next-human']),ids.filter(x=>x!=='the-next-human').concat(['the-next-human']))
 assert.deepEqual(normalizeWatchlist('zero-window'),[])
 assert.deepEqual(normalizeWatchlist([null,0,{},'../secrets']),[])
})
test('Backup export and import are stable and preserve only canonical project IDs',()=>{
 const fixedDate='2026-10-28T19:00:00.000Z'
 const raw=exportWatchlist(['threshold','zero-window','threshold'],fixedDate)
 const data=JSON.parse(raw)
 assert.equal(data.schema,OSA_STUDIO_BACKUP_SCHEMA)
 assert.equal(data.version,1)
 assert.equal(data.storage,'local_device_only')
 assert.deepEqual(data.favorites,['threshold','zero-window'])
 assert.deepEqual(parseWatchlistBackup(raw),['threshold','zero-window'])
 assert.doesNotMatch(raw,/email|secret|accountId|password|access_token|\.mp4/i)
})
test('Import fails closed on malformed, huge, unknown, or manipulated local backups',()=>{
 const original=JSON.parse(exportWatchlist(ids,'2026-10-28T19:00:00.000Z'))
 const alter=changes=>JSON.stringify({...original,...changes})
 for(const invalid of ['','no json','{', 'x'.repeat(17000),
  alter({schema:'SOMETHING_ELSE'}),alter({version:2}),alter({storage:'cloud_sync'}),
  alter({generatedAt:'not a timestamp'}),alter({favorites:'zero-window'}),
  alter({favorites:['malicious-id']}),alter({favorites:['zero-window',123]}),
  alter({favorites:Array(65).fill('zero-window')})])assert.equal(parseWatchlistBackup(invalid),null)
 assert.deepEqual(parseWatchlistBackup(alter({favorites:[]})),[])
})
test('No browser storage is available in the Node process, and writes fail safely',()=>{
 assert.deepEqual(store.readWatchlist(),[])
 assert.equal(store.writeWatchlist(ids),false)
})
