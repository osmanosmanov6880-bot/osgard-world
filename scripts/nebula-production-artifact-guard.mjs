#!/usr/bin/env node
// Blocks any unreviewed change to production Godot game bytes.
// The pins are Git object hashes (SHA-1 with Git's blob prefix), not raw file SHA-1.
// This is an asset identity gate, NOT a hardware FPS or user-signoff certificate.
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

export const GAME_DIR='public/games/remix/arena-v2/nebula-3d';
export const POLICY_FILE='.github/nebula-production-allowlist.json';
const required=['index.html','index.js','index.wasm','index.pck'];
const fail=(why)=>{ throw new Error('NEBULA_PRODUCTION_ASSET_HELD: '+why); };
function check(x,why){if(!x)fail(why);}
function validCommit(s){return typeof s==='string' && /^[a-f0-9]{40}$/.test(s);}
export async function gitBlobHash(filename){
  const info=fs.statSync(filename);
  check(info.isFile() && info.size>0,'missing or empty regular game file');
  const hash=createHash('sha1');
  hash.update('blob '+info.size+'\0');
  for await(const chunk of fs.createReadStream(filename))hash.update(chunk);
  return hash.digest('hex');
}
export async function inspectProductionArtifact(policy,dir=GAME_DIR){
  check(policy?.schema==='NEBULA_PRODUCTION_ASSET_ALLOWLIST_V1',
    'production allowlist missing or incorrect schema');
  check(policy.approved_variant==='R38'||policy.approved_variant==='R40',
    'unexpected approved build');
  if(policy.approved_variant==='R38'){
    check(policy.release_status==='R38_PINNED_PRODUCTION_BASELINE' &&
      policy.approval===null,'R38 stable baseline cannot claim R40 approval');
  }else{
    const a=policy.approval;
    check(policy.release_status==='R40_HARDWARE_QA_APPROVED'&&a &&
      a.human_visual_approved===true&&a.real_device_reviewed===true&&
      typeof a.reviewer==='string'&&a.reviewer.trim().length>=4&&
      validCommit(a.candidate_head_sha)&&
      /^[a-f0-9]{64}$/.test(a.private_evidence_sha256||'')&&
      Number.isInteger(a.original_json_count)&&a.original_json_count>=108&&
      Number.isInteger(a.screenshot_count)&&a.screenshot_count>=12&&
      Number.isInteger(a.actual_android_count)&&a.actual_android_count>=2&&
      Number.isInteger(a.actual_iphone_count)&&a.actual_iphone_count>=1&&
      /^\d{4}-\d{2}-\d{2}T/.test(a.reviewed_at_utc||''),
      'R40 requires explicit human-reviewed evidence, 108 original reports, 12 photos, 2 Android, 1 iPhone and reviewed candidate SHA');
  }
  check(policy.artifacts && Object.keys(policy.artifacts).sort().join(',')===
    [...required].sort().join(','),'exactly four hashed game assets required');
  const hashes={};
  for(const name of required){
    const expect=policy.artifacts[name];
    check(validCommit(expect),'missing exact Git blob hash for '+name);
    const original=path.join(dir,name);
    const actual=await gitBlobHash(original);
    check(actual===expect,'unapproved '+name+' bytes: expected '+expect+
      ', actual '+actual+'; preserve previous public R38 game');
    hashes[name]=actual;
  }
  return {status:'APPROVED_BYTES_ONLY',variant:policy.approved_variant,files:hashes,
    caution:'R40 human visual/device attestations must be independently reviewed; bytes match alone is not field approval'};
}
async function main(){
  const p=JSON.parse(fs.readFileSync(POLICY_FILE,'utf8'));
  const report=await inspectProductionArtifact(p);
  console.log('NEBULA_PRODUCTION_ASSET_GUARD=PASS '+report.variant);
}
if(process.argv[1]&&path.resolve(process.argv[1])===path.resolve(new URL(import.meta.url).pathname)){
  main().catch(e=>{console.error(String(e.message));process.exitCode=1;});
}
