#!/usr/bin/env node
// Negative/unit tests exercise tampered ancestry, unknown blobs and fake phone QA.
// Real Git-object acceptance is separately executed by the lineage gate.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { validateR58Lineage } from './nebula-release-lineage-guard.mjs';
const original=JSON.parse(fs.readFileSync('.github/nebula-production-allowlist.json','utf8'));
assert.equal(original.approved_variant,'R58');
const source=original.approval.native_source_commit_sha;
const exported=original.approval.web_export_commit_sha;
const prHead=original.approval.source_pr_head_sha;
const pins={...original.artifacts};
const mock={
 parents(sha){return sha===exported?[source]:sha===source?['b'.repeat(40),prHead]:[];},
 ancestor(sha){return sha===exported;},
 blob(_sha,filename){return pins[filename.split('/').at(-1)]||'';}
};
assert.equal(validateR58Lineage(original,mock).status,
 'VERIFIED_R58_EXACT_PARENT_AND_FOUR_GIT_BLOBS');
const reject=(policy,lookup=mock,match=/NEBULA_R58_LINEAGE_HELD/)=>
 assert.throws(()=>validateR58Lineage(policy,lookup),match);
reject({...original,release_status:'R58_HARDWARE_QA_APPROVED'});
reject({...original,approval:{...original.approval,hardware_qa_certified:true}});
reject({...original,approval:{...original.approval,physical_device_qa:'PASSED'}});
reject({...original,approval:{...original.approval,source_pr_head_sha:'0'.repeat(40)}});
reject({...original,approval:{...original.approval,web_export_commit_sha:source}});
reject({...original,approval:{...original.approval,verification_workflow_run_id:0}});
reject({...original,artifacts:{...original.artifacts,'index.pck':'f'.repeat(40)}});
reject({...original,artifacts:{...original.artifacts,'index.extra':'f'.repeat(40)}});
reject(original,{...mock,parents(sha){return sha===exported?['c'.repeat(40)]:mock.parents(sha);}});
reject(original,{...mock,parents(sha){return sha===source?['b'.repeat(40),'c'.repeat(40)]:mock.parents(sha);}});
reject(original,{...mock,ancestor(){return false;}});
console.log('NEBULA_R58_LINEAGE_NEGATIVE_QA_SUCCESS actual_hardware_qa=NOT_PERFORMED');
