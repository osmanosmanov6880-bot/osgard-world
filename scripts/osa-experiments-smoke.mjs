import assert from 'node:assert/strict'
import { parseExperiments, experimentDelta } from '../src/osaExperiments.ts'
const p={id:'sample-1',at:new Date().toISOString(),task:'Verify facts',baselineMinutes:30,assistedMinutes:20,baselineErrors:1,assistedErrors:2,notes:'Counted corrections'}
assert.deepEqual(parseExperiments(JSON.stringify([p])),[p])
assert.deepEqual(experimentDelta(p),{minutesSaved:10,timeRatio:1.5,errorDelta:1})
assert.equal(experimentDelta({...p,assistedMinutes:40}).minutesSaved,-10)
for(const patch of [{baselineMinutes:0},{assistedMinutes:-1},{baselineErrors:1.5},{assistedErrors:-1},{task:''},{task:'a'.repeat(1001)},{notes:'a'.repeat(5001)},{at:'invalid'},{id:'../file'}])assert.throws(()=>parseExperiments(JSON.stringify([{...p,...patch}])))
assert.throws(()=>parseExperiments(JSON.stringify([p,p])))
assert.throws(()=>parseExperiments(JSON.stringify(Array.from({length:101},(_,i)=>({...p,id:'item-'+i})))))
assert.throws(()=>parseExperiments(' '.repeat(1000001)))
console.log('OSA experiments: validation, limits, honest negative deltas passed')
