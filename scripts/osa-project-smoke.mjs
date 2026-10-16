import assert from 'node:assert/strict'
import { emptyProject, parseProject, projectReadiness, safeEvidence } from '../src/osaProjects.ts'
const draft = emptyProject()
assert.deepEqual(projectReadiness(draft), [false,false,false,false,false])
assert.deepEqual(parseProject(JSON.stringify(draft)), draft)
for (const evidence of ['javascript:alert(1)', 'data:text/html,test', 'https://user:password@example.com', '/relative']) {
  assert.equal(safeEvidence(evidence), false)
  assert.throws(() => parseProject(JSON.stringify({...draft,evidence})))
}
for (const patch of [{version:2}, {checks:[]}, {checks:[1,1,1]}, {title:123}, {updatedAt:'bad'}, {goal:'a'.repeat(10001)}]) assert.throws(() => parseProject(JSON.stringify({...draft,...patch})))
assert.throws(() => parseProject('{broken'))
assert.throws(() => parseProject(' '.repeat(100001)))
const complete = {...draft,title:'Guide',goal:'Verify three claims',audience:'Students',plan:'Compare sources',evidence:'https://example.com/work',reflection:'Corrected two mistakes',checks:[true,true,true]}
assert.equal(projectReadiness(complete).every(Boolean),true)
const parsed = parseProject(JSON.stringify({...complete,extra:'discard'}))
assert.equal('extra' in parsed,false)
console.log('OSA project validation: passed')
