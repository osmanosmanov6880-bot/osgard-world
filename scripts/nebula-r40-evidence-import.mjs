#!/usr/bin/env node
/**
 * Local-only byte-preserving importer for ORIGINAL R38/R40 device evidence.
 *
 * NEVER collects benchmarks, invents data, authenticates devices, toggles a
 * manifest approval, connects to the network, or promotes a game release.
 * The existing native-report inventory must accept every imported file.
 */
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const REPO=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const INVENTORY=path.join(REPO,'scripts/nebula-r40-device-progress.mjs');
const ORIENTATIONS=new Set(['portrait','landscape']);
const PROFILES=new Set(['MAX','HIGH','ECO']);
const VARIANTS=new Map([['R38','baseline'],['R40','candidate']]);
const digest=b=>createHash('sha256').update(b).digest('hex');

function assert(ok,message){if(!ok)throw new Error(message);}
function within(parent,child){
  const rel=path.relative(parent,child);
  return rel===''||(!rel.startsWith('..'+path.sep)&&rel!=='..'&&!path.isAbsolute(rel));
}
function regular(pathname){
  const s=fs.statSync(pathname);
  assert(s.isFile(),'Source must be an ordinary file');
  return s;
}
function sourceBytes(filename,kind){
  const real=fs.realpathSync(path.resolve(filename));
  const size=regular(real).size;
  const limit=kind==='json'?256000:12000000;
  assert(size>0&&size<=limit,'Source file size out of safe limits');
  const bytes=fs.readFileSync(real);
  if(kind==='json'){
    const report=JSON.parse(bytes.toString('utf8'));
    assert(report&&report.schema==='NEBULA_R12_HARDWARE_BENCHMARK',
      'Source must be a native NEBULA game performance JSON');
  }else{
    const png=bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
    const jpeg=bytes[0]===255&&bytes[1]===216&&bytes[2]===255;
    assert(size>=12000&&(png||jpeg),'Screenshot must have PNG/JPEG signature and enough bytes');
  }
  return {real,sha:digest(bytes)};
}
function inventory(manifest){
  const child=spawnSync(process.execPath,[INVENTORY,manifest],{
    cwd:REPO,encoding:'utf8',timeout:20000,maxBuffer:1048576
  });
  assert(child.status===0,'Local progress check failed: '+String(child.stderr).slice(0,500));
  const result=JSON.parse(child.stdout);
  assert(result.schema==='NEBULA_R40_EVIDENCE_PROGRESS_V2'&&
    result.production_approval===false&&result.invalid_device_labels===0,
    'Unexpected progress report or invalid phone labels');
  return result;
}
function target(root,relative,folder){
  assert(typeof relative==='string'&&relative.length<300&&
    relative.startsWith(folder+'/'),'Manifest points outside expected evidence folder');
  const absolute=path.resolve(root,relative);
  assert(within(root,absolute)&&absolute!==root,'Unsafe target path');
  const actualParent=fs.realpathSync(path.dirname(absolute));
  assert(actualParent===path.join(root,folder),'Target parent must be the kit directory, not a symlink');
  // lstat also detects dangling symlinks; never overwrite anything, even
  // an incomplete or manually edited piece of evidence.
  try{fs.lstatSync(absolute);throw new Error('Refusing to overwrite existing evidence: '+relative);}
  catch(e){if(e.code!=='ENOENT')throw e;}
  return {relative,absolute};
}
function eligibleTargets(root,manifest,args){
  const kind=args[3];
  const deviceId=args[4],orientation=args[5];
  assert(ORIENTATIONS.has(orientation),'Invalid orientation');
  const phone=manifest.devices.find(x=>x.id===deviceId);
  assert(phone&&['Android','iOS'].includes(phone.platform),
    'Phone label must already exist in unchanged field kit manifest');
  if(kind==='json'){
    assert(args.length===11,'Usage: <manifest> json <device> <portrait|landscape> <MAX|HIGH|ECO> <R38|R40> <file1> <file2> <file3>');
    const profile=args[6],role=VARIANTS.get(args[7]);
    assert(PROFILES.has(profile)&&role,'Invalid manual graphics profile or build');
    const groups=phone.runs.filter(g=>g.orientation===orientation&&g.profile===profile);
    assert(groups.length===1,'Manifest group absent or ambiguous');
    const slots=groups[0][role];
    assert(Array.isArray(slots)&&slots.length===3,'Exactly three source JSON slots required');
    return {kind,files:slots.map(x=>target(root,x,'reports')),sources:args.slice(8)};
  }
  assert(kind==='image'&&args.length===8,
    'Usage: <manifest> image <device> <portrait|landscape> <R38|R40> <screenshot>');
  const role=VARIANTS.get(args[6]);
  assert(role,'Invalid screenshot build');
  const relative=phone.visual?.[orientation]?.[role+'_image'];
  return {kind,files:[target(root,relative,'images')],sources:[args[7]]};
}
function importOriginals(argv){
  assert(argv.length>=8,'Usage: <manifest> json|image <device> <orientation> [profile] <variant> <source files>');
  const manifestPath=fs.realpathSync(path.resolve(argv[2]));
  assert(regular(manifestPath).size<=512000,'Unsafe manifest size');
  const root=fs.realpathSync(path.dirname(manifestPath));
  assert(!within(REPO,root)&&!within(root,REPO),
    'Physical evidence must live outside the public repository');
  const manifest=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
  assert(manifest.schema==='NEBULA_R40_PHYSICAL_FIELD_V1'&&
    manifest.synthetic===false&&Array.isArray(manifest.devices),
    'Not an original private NEBULA R40 kit');
  const job=eligibleTargets(root,manifest,argv);
  const sources=job.sources.map(x=>sourceBytes(x,job.kind));
  assert(sources.length===job.files.length,'Wrong number of original sources');
  const unique=new Set(sources.map(x=>x.sha));
  assert(unique.size===sources.length,'Duplicate source file contents');
  const before=inventory(manifestPath);
  assert(before.duplicate_files===0,
    'Fix any existing duplicate evidence before importing');
  const created=[];
  try{
    for(let i=0;i<sources.length;i++){
      const dest=job.files[i].absolute;
      fs.copyFileSync(sources[i].real,dest,fs.constants.COPYFILE_EXCL);
      created.push({file:dest,sha:sources[i].sha});
      fs.chmodSync(dest,0o600);
      assert(digest(fs.readFileSync(dest))===sources[i].sha,
        'Copied original file does not match SHA-256 source');
    }
    const after=inventory(manifestPath);
    const key=job.kind==='json'?'found_json':'found_screenshots';
    assert(after[key]===before[key]+sources.length &&
      after.duplicate_files===before.duplicate_files &&
      after.invalid_device_labels===0,
      'Imported files did not pass the ORIGINAL game-report progress contract');
    return {
      schema:'NEBULA_R40_PRIVATE_EVIDENCE_IMPORT_V1',
      status:'BYTE_IDENTICAL_LOCAL_IMPORT_NOT_DEVICE_AUTHENTICATION',
      imported:job.files.map((x,i)=>({slot:x.relative,sha256:sources[i].sha})),
      remaining_json:after.remaining_json,
      remaining_screenshots:after.remaining_screenshots,
      field_work_approved:false,
      production_approved:false,
      warning:'Originals copied byte-identically. Physical authenticity, visual review and 108/12 release gate remain separate.'
    };
  }catch(e){
    // Roll back only copies we made, and never touch an externally changed
    // file or a previously accepted source/target.
    for(const x of created.reverse()){
      try{if(digest(fs.readFileSync(x.file))===x.sha)fs.unlinkSync(x.file);}
      catch{/* retain unknown file for independent inspection */}
    }
    throw e;
  }
}
try{
  console.log(JSON.stringify(importOriginals(process.argv),null,2));
}catch(e){
  console.error('NEBULA_R40_PRIVATE_IMPORT_REJECTED: '+String(e.message));
  process.exitCode=1;
}
