import assert from 'node:assert/strict'
import { newCreateDraft, parseCreateDrafts, createProjectPayload, validateCreateDraft, PROJECT_KINDS } from '../src/projectCreation.ts'
const d = newCreateDraft('testproject00001','2026-10-23T00:00:00Z')
assert.equal(validateCreateDraft(d),'Введите название проекта от 2 символов.')
d.title='Клиентский портал'
d.goal='Создать рабочий портал для управления заказами'
d.audience='Команда и клиенты'
d.kind='software'
d.tasks=[...PROJECT_KINDS.software.tasks]
assert.equal(validateCreateDraft(d),null)
const request=createProjectPayload(d)
assert.equal(request.title,d.title)
assert.equal(request.audience,d.audience)
assert.equal(request.tasks.length,6)
assert.equal(request.projectKind,'software')
assert.equal(parseCreateDrafts(JSON.stringify([d])).length,1)
assert.equal(parseCreateDrafts(JSON.stringify([d,d])).length,1)
assert.deepEqual(parseCreateDrafts('not-json'),[])
assert.deepEqual(parseCreateDrafts(' '.repeat(150001)),[])
assert.deepEqual(parseCreateDrafts(JSON.stringify([{...d,serverProjectId:'wrong'}])),[])
assert.deepEqual(parseCreateDrafts(JSON.stringify([{...d,goal:'x'.repeat(5000)}])),[])
d.acceptance=['']
assert.ok(validateCreateDraft(d))
assert.throws(()=>createProjectPayload(d))
console.log('Create Studio draft validation and server payload smoke passed')
