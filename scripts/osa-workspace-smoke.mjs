import assert from 'node:assert/strict'
import { emptyProject } from '../src/osaProjects.ts'
import { emptyWorkspace, parseWorkspace, addRevision, portfolioItems } from '../src/osaWorkspace.ts'
const p={...emptyProject(),title:'First'}
let w=addRevision(emptyWorkspace(),p,'project-1')
assert.equal(w.items.length,1)
for(let i=0;i<14;i++) w=addRevision(w,{...p,title:'Revision '+i},'project-1')
assert.equal(w.items.length,1)
assert.equal(w.items[0].revisions.length,10)
assert.equal(w.items[0].revisions[0].title,'Revision 13')
assert.equal(portfolioItems({...w,items:w.items.map(i=>({...i,published:true}))}).length,0)
const complete={...p,goal:'Goal',audience:'Students',plan:'Plan',evidence:'https://example.com',reflection:'Reflection',checks:[true,true,true]}
w=addRevision(w,complete,'project-1');w.items[0].published=true
assert.equal(portfolioItems(w).length,1)
assert.deepEqual(parseWorkspace(JSON.stringify(w)),w)
assert.throws(()=>parseWorkspace(JSON.stringify({...w,items:[w.items[0],w.items[0]]})))
assert.throws(()=>parseWorkspace(JSON.stringify({...w,items:[{...w.items[0],id:'<script>'}]})))
assert.throws(()=>parseWorkspace(JSON.stringify({...w,items:[{...w.items[0],revisions:[]}]})))
assert.throws(()=>parseWorkspace(JSON.stringify({...w,items:[{...w.items[0],revisions:[{...p,evidence:'javascript:alert(1)'}]}]})))
assert.throws(()=>parseWorkspace(' '.repeat(4000001)))
for(let i=2;i<=20;i++)w=addRevision(w,p,'project-'+i)
assert.equal(w.items.length,20)
assert.throws(()=>addRevision(w,p,'project-21'))
assert.equal(addRevision(w,complete,'project-1').items.length,20)
console.log('OSA workspace: revisions, cap, portfolio eligibility, import validation passed')
