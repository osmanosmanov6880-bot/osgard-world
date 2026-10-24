import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const direct=readFileSync('.github/workflows/omega-web-direct-deploy.yml','utf8')
const exporter=readFileSync('.github/workflows/omega-godot-web.yml','utf8')
test('verified original Godot export triggers independent secure SSH activation',()=>{
 assert.match(exporter,/name: OSGARD Empire Omega native Godot Web/)
 assert.match(direct,/workflows: \["OSGARD frontend deploy", "OSGARD Empire Omega native Godot Web"\]/)
 assert.match(direct,/types: \[completed\]/)
 assert.match(direct,/branches: \[master\]/)
})
test('the deployment cannot run on failed or untrusted PR-borne exporter runs',()=>{
 assert.match(direct,/github\.event\.workflow_run\.conclusion == 'success'/)
 assert.match(direct,/github\.event\.workflow_run\.head_branch == 'master'/)
 assert.match(direct,/permissions:\s*\n\s*contents: read/)
})
test('the deployed binary is verified end to end and rollback remains mandatory',()=>{
 assert.match(direct,/omega-live-integrity\.py --self-test/)
 assert.match(direct,/release\.json/)
 assert.match(direct,/sha256sum -c SHA256SUMS\.txt/)
 assert.match(direct,/deploy-omega-native-remote\.sh/)
 assert.match(direct,/--base https:\/\/osgard\.world\/games\/omega-3d-preview/)
 assert.match(direct,/--expected public\/games\/omega-3d-preview\/release\.json/)
 assert.match(exporter,/gh workflow run deploy-frontend\.yml --ref master/)
})
