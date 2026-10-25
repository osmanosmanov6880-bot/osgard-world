#!/usr/bin/env node
/**
 * NEBULA R40: private read-only inventory, never a release approval.
 * Always counts the entire 108-JSON/12-image minimum even if manifest entries
 * are removed. Detects identical renamed files without claiming authenticity.
 */
import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const DEFAULT=path.join(ROOT,'docs/nebula/R40-DEVICE-FIELD-MANIFEST.example.json');
const ORIENTATIONS=['portrait','landscape'];
const PROFILES=['MAX','HIGH','ECO'];
const REPEATS=3;
function fingerprintFile(root,relative,kind){
  if(typeof relative!=='string'||!relative||relative.length>300||path.isAbsolute(relative))return null;
  const resolved=path.resolve(root,relative);
  if(!resolved.startsWith(root+path.sep))return null;
  try{
    const real=fs.realpathSync(resolved);
    if(!real.startsWith(root+path.sep)||!fs.statSync(real).isFile())return null;
    const size=fs.statSync(real).size;
    if(size<1||size>(kind==='json'?256000:12000000))return null;
    const bytes=fs.readFileSync(real);
    if(kind==='json')JSON.parse(bytes.toString('utf8'));
    else{
      if(size<12000)return null;
      const png=bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
      const jpg=bytes[0]===255&&bytes[1]===216&&bytes[2]===255;
      if(!png&&!jpg)return null;
    }
    return createHash('sha256').update(bytes).digest('hex');
  }catch{return null;}
}
function inventory(manifestPath){
  const absolute=path.resolve(manifestPath);
  const root=fs.realpathSync(path.dirname(absolute));
  const size=fs.statSync(absolute).size;
  if(!size||size>512000)throw new Error('Unsafe manifest file size');
  const source=JSON.parse(fs.readFileSync(absolute,'utf8'));
  if(source.schema!=='NEBULA_R40_PHYSICAL_FIELD_V1'||!Array.isArray(source.devices))
    throw new Error('Unknown R40 manifest schema');
  const expectedJson=Math.max(108,source.devices.length*ORIENTATIONS.length*PROFILES.length*2*REPEATS);
  const expectedImages=Math.max(12,source.devices.length*ORIENTATIONS.length*2);
  const seenPaths={json:new Set(),image:new Set()};
  const seenDigests={json:new Set(),image:new Set()};
  const missing=[],devices=[],deviceIDs=new Set();
  let foundJson=0,foundImages=0,duplicateFiles=0,invalidDevices=0;
  function missingSlot(device,kind,reason){
    if(missing.length<24)missing.push({device,kind,path:reason||'NOT_SET'});
  }
  function countFile(device,kind,relative){
    if(!relative){missingSlot(device,kind,'NOT_SET');return false;}
    const k=kind==='JSON'?'json':'image';
    const normalized=String(relative);
    if(seenPaths[k].has(normalized)){
      duplicateFiles++;missingSlot(device,'duplicate',normalized);return false;
    }
    seenPaths[k].add(normalized);
    const digest=fingerprintFile(root,relative,k);
    if(!digest){missingSlot(device,kind,normalized);return false;}
    if(seenDigests[k].has(digest)){
      duplicateFiles++;missingSlot(device,'duplicate content',normalized);return false;
    }
    seenDigests[k].add(digest);
    if(k==='json')foundJson++;else foundImages++;
    return true;
  }
  for(const device of source.devices){
    const id=String(device.id??'');
    const valid=/^[A-Za-z0-9_-]{3,48}$/.test(id)&&!deviceIDs.has(id)&&
      ['Android','iOS'].includes(device.platform);
    if(!valid){invalidDevices++;missingSlot(id,'device','INVALID_OR_DUPLICATE_PHONE');}
    deviceIDs.add(id);
    let found=0;
    for(const orientation of ORIENTATIONS){
      const visual=device.visual?.[orientation];
      for(const kind of ['baseline_image','candidate_image'])
        countFile(id,'image',visual?.[kind]);
      for(const profile of PROFILES){
        const entries=(device.runs||[]).filter(x=>x.orientation===orientation&&x.profile===profile);
        if(entries.length!==1)missingSlot(id,'group',orientation+'/'+profile);
        for(const label of ['baseline','candidate']){
          const names=entries.length===1&&Array.isArray(entries[0][label])?entries[0][label]:[];
          for(let i=0;i<REPEATS;i++){
            if(countFile(id,'JSON',names[i]))found++;
          }
        }
      }
    }
    devices.push({anonymous_id:id,platform:device.platform,
      required_reports:36,found_reports:found,
      human_visual_approved:!!(device.visual?.portrait?.approved&&
        device.visual?.landscape?.approved&&typeof device.reviewer==='string'&&
        device.reviewer.trim().length>=4)});
  }
  return {schema:'NEBULA_R40_EVIDENCE_PROGRESS_V2',
    status:'TRACKING_ONLY_NOT_A_RELEASE_APPROVAL',
    field_work_declared:source.field_work===true,
    devices_declared:source.devices.length,minimum_devices:3,
    expected_json:expectedJson,found_json:foundJson,
    remaining_json:expectedJson-foundJson,
    expected_screenshots:expectedImages,found_screenshots:foundImages,
    remaining_screenshots:expectedImages-foundImages,
    duplicate_files:duplicateFiles,invalid_device_labels:invalidDevices,
    devices,missing_examples:missing,
    production_approval:false,
    next_step:'Collect original evidence; use field-release-gate and production-preflight. This inventory is not a hardware attestation.'};
}
try{
  if(process.argv.length>3)throw new Error('Usage: node scripts/nebula-r40-device-progress.mjs [manifest.json]');
  console.log(JSON.stringify(inventory(process.argv[2]||DEFAULT),null,2));
}catch(e){
  console.error('NEBULA_R40_PROGRESS_ERROR: '+String(e.message));
  process.exitCode=1;
}
