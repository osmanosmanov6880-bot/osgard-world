#!/usr/bin/env node
// Git-graph provenance gate for R58, R59 and R60. Read real Git objects, not PR prose.
// This is NOT a substitute for a successful public HTTPS 4/4 parity check.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync, spawnSync } from 'node:child_process';

const RELEASE_PATH='public/games/remix/arena-v2/nebula-3d';
const REQUIRED=['index.html','index.js','index.pck','index.wasm'];
const VALID_SHA=/^[a-f0-9]{40}$/;
const fail=(message)=>{throw new Error('NEBULA_TRUSTED_LINEAGE_HELD: '+message);};
const eq=(a,b)=>a===b;
export function validateTrustedLineage(policy,lookup) {
  const variant=policy?.approved_variant;
  if(!['R58','R59','R60'].includes(variant)) return {status:'NOT_TRUSTED_RELEASE'};
  const a=policy?.approval||{};
  if(policy?.schema!=='NEBULA_PRODUCTION_ASSET_ALLOWLIST_V1' ||
    policy.release_status!==variant+'_OWNER_DIRECTED_OVERRIDE' ||
    a.physical_device_qa!=='NOT_PERFORMED' ||
    a.hardware_qa_certified!==false ||
    !Number.isSafeInteger(a.verification_workflow_run_id) ||
    a.verification_workflow_run_id<=0)fail('bad release metadata / false phone QA');
  const source=a.native_source_commit_sha;
  const exportSha=a.web_export_commit_sha;
  const prHead=a.source_pr_head_sha;
  if(![source,exportSha,prHead].every(x=>VALID_SHA.test(x)) ||
    source===exportSha)fail('invalid source / export / source PR head SHA');
  const exportParents=lookup.parents(exportSha);
  if(exportParents.length!==1||exportParents[0]!==source)
    fail('export must be an exact sole-child of verified source merge');
  const sourceParents=lookup.parents(source);
  if(sourceParents.length!==2||!sourceParents.includes(prHead))
    fail('source must be a merge of the verified source PR head');
  if(!lookup.ancestor(exportSha))fail('export is not an ancestor of candidate HEAD');
  const pins=policy.artifacts||{};
  if(Object.keys(pins).sort().join(',')!==REQUIRED.slice().sort().join(','))
    fail('only four exact Web binary pins allowed');
  for(const name of REQUIRED){
    const expected=pins[name];
    if(!VALID_SHA.test(expected))fail('invalid blob SHA for '+name);
    const real=lookup.blob(exportSha,RELEASE_PATH+'/'+name);
    if(!eq(real,expected))fail('export Git object mismatch for '+name);
  }
  return {status:'VERIFIED_'+variant+'_EXACT_PARENT_AND_FOUR_GIT_BLOBS',
    variant,source,export_sha:exportSha,source_pr_head:prHead,run_id:a.verification_workflow_run_id};
}
const git=(...args)=>execFileSync('git',args,{encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
function realLookup(){
  return {
    parents(sha){
      const parts=git('rev-list','--parents','-n','1',sha).split(/\s+/);
      if(parts[0]!==sha)fail('unresolved commit '+sha);
      return parts.slice(1);
    },
    ancestor(sha){
      return spawnSync('git',['merge-base','--is-ancestor',sha,'HEAD'],
        {stdio:'ignore'}).status===0;
    },
    blob(sha,filename){
      const lines=git('ls-tree',sha,'--',filename).split('\n').filter(Boolean);
      if(lines.length!==1)fail('missing exact export file '+filename);
      const m=lines[0].match(/^100644 blob ([a-f0-9]{40})\t/);
      if(!m||!lines[0].endsWith('\t'+filename))fail('not a regular export blob '+filename);
      return m[1];
    }
  };
}
if(process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  try{
    const policy=JSON.parse(fs.readFileSync('.github/nebula-production-allowlist.json','utf8'));
    const r=validateTrustedLineage(policy,realLookup());
    console.log('NEBULA_RELEASE_LINEAGE_GATE '+JSON.stringify(r));
  }catch(e){console.error(String(e));process.exitCode=1;}
}

// Keep the R58 JS export for existing callers; the implementation is shared.
export const validateR58Lineage=validateTrustedLineage;
