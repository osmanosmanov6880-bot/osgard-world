#!/usr/bin/env node
// Offline NEBULA R40 preflight: evidence integrity, NEVER automated production approval.
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const BASELINE='.github/nebula-production-allowlist.json';
const STAGING='.github/nebula-r40-qa-one-shot-source.json';
const TEMPLATE='docs/nebula/R40-DEVICE-FIELD-MANIFEST.example.json';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const json=rel=>JSON.parse(fs.readFileSync(path.join(ROOT,rel),'utf8'));
function assert(ok,reason){ if(!ok) throw new Error(reason); }
function status(){
  const p=json(BASELINE),q=json(STAGING);
  assert(p.schema==='NEBULA_PRODUCTION_ASSET_ALLOWLIST_V1','Unrecognized production policy');
  assert(q.schema==='NEBULA_R40_ONESHOT_QA_V1','Unrecognized staging input');
  assert(q.staging_only===true && q.approved_for_production===false,
    'QA staging must not claim production approval');
  assert(q.qa_path==='/games/remix/nebula-r40-qa/','Unexpected QA route');
  assert(q.candidate_pr===375 &&
    q.candidate_head_sha==='9efb03c246a28a168886e2aa494872e907ea78cd',
    'Candidate PR #375 head changed: independent reapproval required');
  assert(String(q.source_run_id)==='40173218842',
    'Source CI changed: independent reapproval required');
  return {schema:'NEBULA_R40_FINAL_PRODUCTION_PREFLIGHT_V1',
    production_variant:p.approved_variant,
    production_stable_r38:p.approved_variant==='R38' &&
      p.release_status==='R38_PINNED_PRODUCTION_BASELINE' && p.approval===null,
    isolated_qa_route:'https://osgard.world'+q.qa_path,
    qa_candidate_pr:q.candidate_pr,qa_candidate_head_sha:q.candidate_head_sha,
    source_run_id:String(q.source_run_id),
    reported_qa_deploy:'VERIFY_SEPARATELY_IN_GITHUB_ACTIONS',
    local_field_gate:'NOT_RUN',json_count:0,screenshot_count:0,
    evidence_content_sha256:null,
    independent_human_review:'NOT_VERIFIED',
    authorized_for_production:false,
    status:'BLOCKED_NO_REVIEWED_PHYSICAL_DEVICE_EVIDENCE'};
}
function localFile(root,relative){
  assert(typeof relative==='string' && relative.length>0 &&
    relative.length<300 && !path.isAbsolute(relative),'Unsafe evidence reference');
  const full=path.resolve(root,relative);
  assert(full.startsWith(root+path.sep),'Evidence escapes private folder');
  const real=fs.realpathSync(full);
  assert(real.startsWith(root+path.sep) && fs.statSync(real).isFile(),
    'Evidence is not a regular local file');
  return real;
}
async function hashFile(filename){
  const h=createHash('sha256');
  for await (const chunk of fs.createReadStream(filename))h.update(chunk);
  return h.digest('hex');
}
async function contentCommitment(manifestPath){
  const file=fs.realpathSync(path.resolve(manifestPath)),root=path.dirname(file);
  const bytes=fs.readFileSync(file),manifest=JSON.parse(bytes);
  const members=[];
  for(const device of manifest.devices||[]){
    assert(/^[A-Za-z0-9_-]{3,48}$/.test(device.id||''),'Unsafe device label');
    for(const orientation of ['portrait','landscape']){
      for(const build of ['baseline','candidate']){
        const name=device.visual?.[orientation]?.[build+'_image'];
        members.push({role:device.id+'/'+orientation+'/'+build+'/image',
          sha256:await hashFile(localFile(root,name))});
      }
      for(const profile of ['MAX','HIGH','ECO']){
        const one=(device.runs||[]).find(x=>x.orientation===orientation&&x.profile===profile);
        assert(one,'Missing physical benchmark group');
        for(const build of ['baseline','candidate']){
          for(const [index,name] of (one[build]||[]).entries()){
            members.push({role:[device.id,orientation,profile,build,index].join('/'),
              sha256:await hashFile(localFile(root,name))});
          }
        }
      }
    }
  }
  members.sort((a,b)=>a.role.localeCompare(b.role,'en'));
  return hash(Buffer.from(JSON.stringify({schema:'NEBULA_R40_PRIVATE_CONTENT_V1',
    manifest_sha256:hash(bytes),members})));
}
async function evaluate(manifestPath){
  const result=status();
  if(!result.production_stable_r38){
    result.status='BLOCKED_UNREVIEWED_PRODUCTION_POLICY';
    return result;
  }
  if(!manifestPath)return result;
  const r=spawnSync(process.execPath,
    [path.join(ROOT,'scripts/nebula-r40-field-release-gate.mjs'),
      path.resolve(manifestPath)],{cwd:ROOT,encoding:'utf8',timeout:120000,maxBuffer:1048576});
  if(r.status!==0){
    result.local_field_gate='FAILED';
    result.status='BLOCKED_INCOMPLETE_OR_INVALID_DEVICE_REPORTS';
    return result;
  }
  const verified=JSON.parse(r.stdout);
  assert(verified.schema==='NEBULA_R40_OFFLINE_EVIDENCE_V1' &&
    verified.local_evidence_structure==='PASS' &&
    verified.physical_jsons_read>=108 &&
    verified.checked_images>=12 &&
    verified.unique_original_jsons>=108 &&
    verified.unique_source_images>=12,'Field verifier reported insufficient evidence');
  result.local_field_gate='PASSED_STRUCTURE_ONLY';
  result.json_count=verified.physical_jsons_read;
  result.screenshot_count=verified.checked_images;
  result.evidence_content_sha256=await contentCommitment(manifestPath);
  result.status='STRUCTURAL_EVIDENCE_VALID_HUMAN_RELEASE_APPROVAL_REQUIRED';
  return result;
}
try{
  if(process.argv[2]==='--selftest'){
    const x=await evaluate();
    assert(x.production_stable_r38 && x.qa_candidate_pr===375 &&
      x.authorized_for_production===false && x.evidence_content_sha256===null,
      'Production/staging safety regression');
    const negative=await evaluate(path.join(ROOT,TEMPLATE));
    assert(negative.local_field_gate==='FAILED' &&
      negative.authorized_for_production===false &&
      negative.evidence_content_sha256===null,
      'Empty hardware template must be rejected');
    console.log('NEBULA_R40_FINAL_PREFLIGHT_SELFTEST_SUCCESS production=R38 field=empty approval=false');
  }else{
    assert(process.argv.length<=3,'Usage: node scripts/nebula-r40-production-preflight.mjs [private/manifest.json]');
    const report=await evaluate(process.argv[2]);
    console.log(JSON.stringify(report,null,2));
    // Even complete device structure is not a substitute for human release authorization.
    process.exitCode=2;
  }
}catch(e){
  console.error('NEBULA_R40_PRODUCTION_HELD: '+String(e.message));
  process.exitCode=2;
}
