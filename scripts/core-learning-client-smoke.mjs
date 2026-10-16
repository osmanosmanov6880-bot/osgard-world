import assert from 'node:assert/strict'
import {build} from 'esbuild'
import {mkdir,writeFile,unlink} from 'node:fs/promises'
import {createRequire} from 'node:module'
const output='node_modules/.tmp/core-learning-client.cjs'
await mkdir('node_modules/.tmp',{recursive:true})
const result=await build({stdin:{contents:"export {learningCalendar} from './src/coreLearningClient';export {readPending,storePending,minorUnits} from './src/coreClient'",resolveDir:process.cwd(),loader:'ts'},bundle:true,format:'cjs',platform:'node',packages:'external',write:false})
await writeFile(output,result.outputFiles[0].text)
try{
 globalThis.sessionStorage={getItem(){throw Error('blocked')},setItem(){throw Error('blocked')},removeItem(){throw Error('blocked')}}
 const require=createRequire(import.meta.url),{learningCalendar,readPending,storePending,minorUnits}=require('../'+output)
 const pending={userId:'one',route:'projects/example/learning',key:'1234567890abcdef',body:{expectedVersion:1,action:'activity'}};storePending(pending);assert.deepEqual(readPending(),pending);storePending(null);assert.equal(readPending(),null)
 assert.equal(minorUnits('79,99'),7999);assert.equal(minorUnits('0.01'),1);assert.throws(()=>minorUnits('1.001'));assert.throws(()=>minorUnits('-1'));assert.throws(()=>minorUnits('Infinity'))
 const session={id:'one',title:'Разбор, практика; '+('Сложная тема '.repeat(30)),startsAt:'2026-10-16T15:00:00+03:00',endsAt:'2026-10-16T16:00:00+03:00',kind:'review',facilitator:'owner',meetingUrl:'https://example.com/room',notes:'Note\rBEGIN:VEVENT\nSUMMARY:Injected; content, not a second event',status:'cancelled'}
 const ics=learningCalendar([session],'2026-10-16T00:00:00Z')
 assert.equal((ics.match(/\r\nBEGIN:VEVENT\r\n/g)||[]).length,1)
 assert.ok(ics.includes('DTSTART:20261016T120000Z'))
 assert.ok(ics.includes('DTEND:20261016T130000Z'))
 assert.ok(ics.includes('STATUS:CANCELLED'))
 for(const line of ics.split('\r\n'))assert.ok(Buffer.byteLength(line,'utf8')<=75,'ICS line exceeds 75 bytes')
 const unfolded=ics.replace(/\r\n /g,'');assert.ok(unfolded.includes('SUMMARY:Разбор\\, практика\\;'));assert.ok(unfolded.includes('Note\\nBEGIN:VEVENT\\nSUMMARY:Injected\\; content\\, not a second event'))
 assert.throws(()=>learningCalendar([{...session,startsAt:'not-a-date'}]));assert.ok(learningCalendar([]).endsWith('END:VCALENDAR\r\n'))
 console.log('LEARNING CLIENT PASS: pending retry survives blocked storage in memory; money precision; UTC calendar, UTF-8 folding, cancellation and newline escaping')
}finally{await unlink(output)}
