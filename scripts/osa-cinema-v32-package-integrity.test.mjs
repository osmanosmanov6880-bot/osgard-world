import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp,writeFile,readFile,rm,symlink,mkdir } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createHash } from 'node:crypto'
import { verifyPackage } from './osa-cinema-v32-package-integrity.mjs'
const sha=bytes=>createHash('sha256').update(bytes).digest('hex')
test('V32 offline checksum verification safely rejects tampering, missing files and symlinks',async t=>{
  const folder=await mkdtemp(join(tmpdir(),'osa-v32-check-'))
  const filename='scripts/owner-safe.mjs',dir=join(folder,'scripts'),source=join(dir,'owner-safe.mjs')
  await mkdir(dir)
  await writeFile(source,'export const NO_GO = true;\n')
  const body=await readFile(source)
  const line=sha(body)+'  '+filename+'\n'
  const checksum=join(folder,'CHECKSUMS.sha256')
  await writeFile(checksum,line)
  try{
    await t.test('real verification of file bytes returns integrity only, never legal GO',async()=>{
      const r=await verifyPackage({root:folder,minFiles:1})
      assert.equal(r.integrityVerified,true)
      assert.equal(r.verifiedFiles,1)
      assert.equal(r.publicationAuthorized,false)
    })
    await t.test('edited bytes trigger strong SHA256 failure',async()=>{
      await writeFile(source,'export const NO_GO = false;\n')
      try{await assert.rejects(verifyPackage({root:folder,minFiles:1}),/SHA256 mismatch/)}
      finally{await writeFile(source,body)}
    })
    await t.test('refuses dangerous ../ traversal in altered manifest',async()=>{
      await writeFile(checksum,sha(body)+'  ../secret.mjs\n')
      try{await assert.rejects(verifyPackage({root:folder,minFiles:1}),/Unsafe, repeated/)}
      finally{await writeFile(checksum,line)}
    })
    await t.test('refuses duplicate entries',async()=>{
      await writeFile(checksum,line+line)
      try{await assert.rejects(verifyPackage({root:folder,minFiles:1}),/Unsafe, repeated/)}
      finally{await writeFile(checksum,line)}
    })
    await t.test('refuses symlink-swapped source files',async()=>{
      await rm(source)
      await symlink(checksum,source)
      try{await assert.rejects(verifyPackage({root:folder,minFiles:1}),/Unsafe package file/)}
      finally{await rm(source);await writeFile(source,body)}
    })
    await t.test('rejects an injected unlisted JS file while listed checksums still match',async()=>{
      const extra=join(dir,'surprise.mjs')
      await writeFile(extra,'console.log("unauthorized")')
      try{await assert.rejects(verifyPackage({root:folder,minFiles:1}),/Unlisted package entry/)}
      finally{await rm(extra)}
    })
    await t.test('rejects a symlink in the PARENT of an otherwise real package root',async()=>{
      const parent=join(tmpdir(),'osa-v32-redirect-test-'+Date.now())
      await symlink(folder,parent,'dir')
      try{await assert.rejects(verifyPackage({root:parent,minFiles:1}),/Symlinked or unsafe package ancestor/)}
      finally{await rm(parent)}
    })
    await t.test('rejects an unlisted empty directory as a closed-inventory violation',async()=>{
      const extra=join(folder,'not-expected-empty-directory')
      await mkdir(extra)
      try{await assert.rejects(verifyPackage({root:folder,minFiles:1}),/Unlisted package directory/)}
      finally{await rm(extra,{recursive:true})}
    })
    await t.test('rejects a substituted intermediate directory symlink',async()=>{
      const genuine=join(folder,'real-scripts')
      await renameForTest()
      async function renameForTest(){
        const { rename }=await import('node:fs/promises')
        await rename(dir,genuine)
        await symlink(genuine,dir,'dir')
        try{await assert.rejects(verifyPackage({root:folder,minFiles:1}),/Unsafe package directory/)}
        finally{await rm(dir);await rename(genuine,dir)}
      }
    })
    await t.test('rejects injected symlink not listed in manifest',async()=>{
      const extra=join(folder,'not-listed-link')
      await symlink(source,extra)
      try{await assert.rejects(verifyPackage({root:folder,minFiles:1}),/Unsafe or unlisted/)}
      finally{await rm(extra)}
    })
    await t.test('rejects short/empty package inventories',async()=>{
      await assert.rejects(verifyPackage({root:folder,minFiles:3}),/Incomplete/)
      await writeFile(checksum,'')
      try{await assert.rejects(verifyPackage({root:folder,minFiles:1}),/Unsafe SHA256 manifest/)}
      finally{await writeFile(checksum,line)}
    })
    await t.test('missing payload does not pass',async()=>{
      await rm(source)
      try{await assert.rejects(verifyPackage({root:folder,minFiles:1}),/ENOENT/)}
      finally{await writeFile(source,body)}
    })
  }finally{await rm(folder,{recursive:true,force:true})}
})
