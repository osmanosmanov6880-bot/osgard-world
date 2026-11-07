#!/usr/bin/env node
// Synthetic negative cases for R58/R59 lineage and hardware evidence.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { validateTrustedLineage,validateR58Lineage } from './nebula-release-lineage-guard.mjs';
const base=JSON.parse(fs.readFileSync('.github/nebula-production-allowlist.json','utf8'));
assert.equal(base.approved_variant,'R61');
for(const variant of ['R58','R59','R60','R61']){
 const policy={...base,approved_variant:variant,
   release_status:variant+'_OWNER_DIRECTED_OVERRIDE'};
 const source=policy.approval.native_source_commit_sha;
 const exported=policy.approval.web_export_commit_sha;
 const prHead=policy.approval.source_pr_head_sha;
 const pins=policy.artifacts;
 const mock={
  parents(sha){return sha===exported?[source]:sha===source?['b'.repeat(40),prHead]:[];},
  ancestor(sha){return sha===exported;},
  blob(_sha,filename){return pins[filename.split('/').at(-1)]||'';}
 };
 const good='VERIFIED_'+variant+'_EXACT_PARENT_AND_FOUR_GIT_BLOBS';
 assert.equal(validateTrustedLineage(policy,mock).status,good);
 if(variant==='R58') assert.equal(validateR58Lineage(policy,mock).status,good);
 const reject=(candidate,lookup=mock)=>
   assert.throws(()=>validateTrustedLineage(candidate,lookup),/NEBULA_TRUSTED_LINEAGE_HELD/);
 reject({...policy,schema:'MADE_UP_SCHEMA'});
 reject({...policy,release_status:variant+'_HARDWARE_QA_APPROVED'});
 reject({...policy,approval:{...policy.approval,hardware_qa_certified:true}});
 reject({...policy,approval:{...policy.approval,physical_device_qa:'PASSED'}});
 reject({...policy,approval:{...policy.approval,source_pr_head_sha:'0'.repeat(40)}});
 reject({...policy,approval:{...policy.approval,web_export_commit_sha:source}});
 reject({...policy,approval:{...policy.approval,verification_workflow_run_id:0}});
 reject({...policy,artifacts:{...policy.artifacts,'index.pck':'f'.repeat(40)}});
 reject({...policy,artifacts:{...policy.artifacts,'index.extra':'f'.repeat(40)}});
 reject(policy,{...mock,parents(sha){return sha===exported?['c'.repeat(40)]:mock.parents(sha);}});
 reject(policy,{...mock,parents(sha){return sha===source?['b'.repeat(40),'c'.repeat(40)]:mock.parents(sha);}});
 reject(policy,{...mock,ancestor(){return false;}});
 reject(policy,{...mock,blob(sha,name){return name.endsWith('index.pck')?'f'.repeat(40):mock.blob(sha,name);}});
}
assert.equal(validateTrustedLineage({...base,approved_variant:'R62'},{ }).status,'NOT_TRUSTED_RELEASE');
console.log('NEBULA_TRUSTED_LINEAGE_NEGATIVE_QA_SUCCESS variants=R58,R59,R60,R61 bad_provenance_rejected=true physical_devices=0');
