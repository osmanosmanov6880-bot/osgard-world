#!/usr/bin/env node
/**
 * NEBULA R40 — local-only evidence inventory, never a release approval.
 * Usage: node scripts/nebula-r40-device-progress.mjs /private/qa/manifest.json
 * The actual pass/fail release checker is nebula-r40-field-release-gate.mjs.
 */
import fs from 'node:fs';
import path from 'node:path';

const defaultManifest='docs/nebula/R40-DEVICE-FIELD-MANIFEST.example.json';
function safeFile(root, relative) {
  if (typeof relative !== 'string' || relative.length === 0 ||
      relative.length > 300 || path.isAbsolute(relative)) return false;
  const resolved=path.resolve(root, relative);
  if (!resolved.startsWith(root + path.sep)) return false;
  try {
    const real=fs.realpathSync(resolved);
    return real.startsWith(root + path.sep) && fs.statSync(real).isFile();
  } catch {
    return false;
  }
}
function inventory(manifestPath) {
  const resolved=path.resolve(manifestPath);
  const root=fs.realpathSync(path.dirname(resolved));
  const size=fs.statSync(resolved).size;
  if (!size || size > 512000) throw new Error('Unsafe manifest file size');
  const source=JSON.parse(fs.readFileSync(resolved,'utf8'));
  if (source.schema !== 'NEBULA_R40_PHYSICAL_FIELD_V1' ||
      !Array.isArray(source.devices)) {
    throw new Error('Unknown R40 field-manifest schema');
  }
  const devices=[];
  const uniqueFiles=new Set();
  const missing=[];
  let expectedJson=0,foundJson=0,expectedImages=0,foundImages=0;
  const orientations=['portrait','landscape'], profiles=['MAX','HIGH','ECO'];
  for(const device of source.devices) {
    if (typeof device.id !== 'string') throw new Error('Device ID must be specified');
    let deviceExpected=0,deviceFound=0;
    for(const orientation of orientations) {
      const visual=device.visual?.[orientation];
      for(const kind of ['baseline_image','candidate_image']) {
        expectedImages++;
        const f=visual?.[kind];
        if (safeFile(root,f)) foundImages++;
        else if (missing.length < 20) missing.push({device:device.id,kind:'image',path:f||'NOT_SET'});
      }
      for(const profile of profiles) {
        const record=(device.runs||[]).filter(x=>
          x.orientation===orientation && x.profile===profile);
        if(record.length!==1) {
          if(missing.length < 20) missing.push({device:device.id,kind:'group',
            path:orientation+'/'+profile});
          continue;
        }
        for(const label of ['baseline','candidate']) {
          const files=record[0][label];
          if(!Array.isArray(files)) continue;
          for(const f of files) {
            expectedJson++;
            deviceExpected++;
            const key=String(f);
            if(uniqueFiles.has(key)) {
              if(missing.length < 20) missing.push({device:device.id,kind:'duplicate',path:key});
              continue;
            }
            uniqueFiles.add(key);
            if(safeFile(root,f)) {foundJson++;deviceFound++;}
            else if(missing.length < 20) missing.push({device:device.id,kind:'JSON',path:f||'NOT_SET'});
          }
        }
      }
    }
    devices.push({anonymous_id:device.id,platform:device.platform,
      listed_reports:deviceExpected,found_reports:deviceFound,
      human_visual_approved:!!(device.visual?.portrait?.approved &&
        device.visual?.landscape?.approved && typeof device.reviewer==='string' &&
        device.reviewer.trim().length>=4)});
  }
  return {
    schema:'NEBULA_R40_EVIDENCE_PROGRESS_V1',
    status:'TRACKING_ONLY_NOT_A_RELEASE_APPROVAL',
    field_work_declared:source.field_work === true,
    expected_json:expectedJson,found_json:foundJson,remaining_json:expectedJson-foundJson,
    expected_screenshots:expectedImages,found_screenshots:foundImages,
    remaining_screenshots:expectedImages-foundImages,
    listed_unique_json:uniqueFiles.size,
    devices,missing_examples:missing,
    next_step:'Collect authentic source files, fill human review, then run scripts/nebula-r40-field-release-gate.mjs. A progress report never authorizes production.'
  };
}
try {
  if (process.argv.length > 3) throw new Error('Usage: node scripts/nebula-r40-device-progress.mjs [manifest.json]');
  const output=inventory(process.argv[2]||defaultManifest);
  console.log(JSON.stringify(output,null,2));
} catch(e) {
  console.error('NEBULA_R40_PROGRESS_ERROR: '+String(e.message));
  process.exitCode=1;
}
