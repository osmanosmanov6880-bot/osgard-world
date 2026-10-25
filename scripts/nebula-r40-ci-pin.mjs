#!/usr/bin/env node
// Permanent *source identity* pin for the original R40 QA CI artifact.
// This is not a signature of physical phones or approval for production.
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';

const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const PIN='.github/nebula-r40-qa-ci-artifact-pin.json';
const QA='.github/nebula-r40-qa-one-shot-source.json';
const REQUIRED=['index.html','index.js','index.wasm','index.pck'];
const SHA256=/^[0-9a-f]{64}$/;
function check(value,reason){if(!value)throw new Error('NEBULA_R40_PIN_INVALID: '+reason);}
export function validate(pin,qa){
  check(pin?.schema==='NEBULA_R40_QA_CI_ARTIFACT_PIN_V1','schema');
  check(pin.staging_only===true && pin.production_approved===false,'cannot grant production');
  check(pin.candidate_pr===375 && pin.candidate_pr===qa.candidate_pr,'candidate PR');
  check(pin.candidate_head_sha===qa.candidate_head_sha &&
    /^[0-9a-f]{40}$/.test(pin.candidate_head_sha),'candidate commit');
  check(String(pin.ci_run_id)===String(qa.source_run_id)&&
    /^[0-9]+$/.test(String(pin.ci_run_id)),'CI run');
  check(/^[0-9a-f]{40}$/.test(pin.ci_checkout_sha),'checkout SHA');
  check(SHA256.test(pin.ci_archive_sha256),'original artifact ZIP SHA');
  check(qa.staging_only===true&&qa.approved_for_production===false&&
    qa.qa_path==='/games/remix/nebula-r40-qa/','isolated QA route');
  check(pin.files&&typeof pin.files==='object'&&!Array.isArray(pin.files)&&
    Object.keys(pin.files).sort().join(',')===REQUIRED.slice().sort().join(','),
    'exactly four file records');
  for(const name of REQUIRED){
    const record=pin.files[name];
    check(record&&SHA256.test(record.sha256)&&
      Number.isSafeInteger(record.bytes)&&record.bytes>0,'hash or byte size for '+name);
  }
  return pin;
}
export function loadPin(){
  return validate(
    JSON.parse(fs.readFileSync(path.join(ROOT,PIN),'utf8')),
    JSON.parse(fs.readFileSync(path.join(ROOT,QA),'utf8')));
}
export function inspectFiles(directory,pin){
  const root=path.resolve(directory);
  const verified=[];
  for(const name of REQUIRED){
    const filename=path.join(root,name);
    const stat=fs.lstatSync(filename);
    check(stat.isFile()&&!stat.isSymbolicLink(),'unsafe or missing file '+name);
    check(stat.size===pin.files[name].bytes,'byte count mismatch '+name);
    const digest=createHash('sha256').update(fs.readFileSync(filename)).digest('hex');
    check(digest===pin.files[name].sha256,'SHA-256 mismatch '+name);
    verified.push(name);
  }
  return {status:'PINNED_CI_ARTIFACT_BYTES_MATCH',verified,
    note:'Original CI bytes verified, NOT physical hardware approval'};
}
const direct=process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url);
if(direct){
  try{
    const pin=loadPin();
    if(process.argv[2]==='--validate'&&process.argv.length===3){
      console.log('NEBULA_R40_QA_IMMUTABLE_HASH_PIN=VALID source='+pin.candidate_head_sha+
        ' ci_run='+pin.ci_run_id+' production_approved=false');
    }else if(process.argv[2]==='--checksums'&&process.argv.length===3){
      for(const name of REQUIRED)console.log(pin.files[name].sha256+'  '+name);
    }else if(process.argv[2]==='--check-dir'&&process.argv.length===4){
      console.log(JSON.stringify(inspectFiles(process.argv[3],pin)));
    }else{
      throw new Error('Usage: node scripts/nebula-r40-ci-pin.mjs --validate|--checksums|--check-dir DIR');
    }
  }catch(e){console.error(String(e.message));process.exitCode=1;}
}
