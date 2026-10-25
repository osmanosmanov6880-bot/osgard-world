#!/usr/bin/env node
// NEBULA R40 field evidence checker: offline, no uploads and no simulated sign-off.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
const deny = reason => { throw new Error(reason); };
const check = (condition, message) => { if (!condition) deny(message); };
const ORIENTATIONS = ['portrait','landscape'];
const PROFILES = ['MAX','HIGH','ECO'];
function viewer() {
  const html = fs.readFileSync('public/games/remix/arena-v2/nebula-3d/performance-report.html','utf8');
  const script = html.match(/<script id="nebula-r37-comparator">([\s\S]*?)<\/script>/);
  check(script, 'Original offline comparison script missing');
  const scope = {window:{},document:{getElementById:()=>null},console};
  vm.runInNewContext(script[1],scope,{timeout:5000});
  const api = scope.window.NebulaR37;
  check(api && api.r40CandidateBuildId==='NEBULA_R40_BRIDGE_BATCH_3X32',
    'R40 original build ID check is not available');
  return api;
}
function localFile(root,relative,kind) {
  check(typeof relative==='string' && relative.length>0 &&
    relative.length<300 && !path.isAbsolute(relative),
    'Invalid local '+kind+' path');
  const file=path.resolve(root,relative);
  check(file.startsWith(root+path.sep),'Path escapes local evidence folder');
  const real=fs.realpathSync(file);
  check(real.startsWith(root+path.sep),'Symlink escapes evidence folder');
  const size=fs.statSync(real).size;
  check(size>0 && size<=(kind==='JSON'?256000:12000000),
    'Unsafe '+kind+' file size');
  if (kind==='image') {
    check(size>=12000,'Image too small for real scene evidence');
    const b=fs.readFileSync(real).subarray(0,8);
    check((b[0]===255 && b[1]===216 && b[2]===255) ||
      b.equals(Buffer.from([137,80,78,71,13,10,26,10])),
      'Screenshot must be original PNG/JPEG data');
  }
  return real;
}
function readJson(root,relative) {
  return JSON.parse(fs.readFileSync(localFile(root,relative,'JSON'),'utf8'));
}
function inspect(filename) {
  const absolute=path.resolve(filename),root=fs.realpathSync(path.dirname(absolute));
  const input=readJson(root,path.basename(absolute));
  check(input.schema==='NEBULA_R40_PHYSICAL_FIELD_V1' &&
    input.synthetic===false && input.field_work===true,
    'Real device declaration is required; synthetic fixtures are rejected');
  check(Array.isArray(input.devices)&&input.devices.length>=3,'Need at least 3 physical phones');
  const api=viewer(),seen=new Set(),rows=[],summary=[],platforms={Android:0,iOS:0};
  let images=0;
  for(const device of input.devices) {
    const id=device.id;
    check(typeof id==='string'&&/^[A-Za-z0-9_-]{3,48}$/.test(id)&&!seen.has(id),
      'Invalid or duplicate anonymous phone label');
    seen.add(id);
    check(device.platform==='Android'||device.platform==='iOS','Only Android/iOS actual phones accepted');
    platforms[device.platform]++;
    check(typeof device.reviewer==='string'&&device.reviewer.trim().length>=4,
      'Missing human visual reviewer for '+id);
    for(const orientation of ORIENTATIONS) {
      const v=device.visual?.[orientation];
      check(v?.approved===true && typeof v.notes==='string'&&v.notes.trim().length>=20,
        'Human visual sign-off missing: '+id+'/'+orientation);
      localFile(root,v.baseline_image,'image');
      localFile(root,v.candidate_image,'image');
      images+=2;
      for(const profile of PROFILES) {
        const entry=(device.runs||[]).filter(x=>
          x.orientation===orientation && x.profile===profile);
        check(entry.length===1,'Missing or duplicate mode/orientation: '+id+'/'+orientation+'/'+profile);
        const sample=[];
        for(const variant of ['R38','R40']) {
          const filenames=entry[0][variant==='R38'?'baseline':'candidate'];
          check(Array.isArray(filenames)&&filenames.length>=3,
            'Need >=3 original independent JSONs from each game: '+id+'/'+profile);
          for(const name of filenames) {
            const record=api.parseReport(readJson(root,name),path.basename(name),id,variant);
            const xy=record.resolution.split('×').map(Number);
            check(record.profile===profile && xy.length===2 &&
              (orientation==='portrait'?xy[1]>xy[0]:xy[0]>xy[1]),
              'Profile, viewport or orientation mismatch: '+name);
            sample.push(record);
          }
        }
        const groups=api.summarizeRuns(sample);
        const compared=api.compareBuilds(groups);
        check(groups.length===2 && groups.every(g=>g.valid>=3 && g.spread<=20) &&
          compared.length===1 && compared[0].deltaFps!==null &&
          compared[0].status!=='ХУЖЕ' &&
          compared[0].status!=='ПОВТОРНЫЕ JSON',
          'Incomplete, noisy, mislabeled or regressing hardware data: '+id+'/'+orientation+'/'+profile);
        rows.push({device:id,orientation,profile,
          baseline_fps:compared[0].baselineFps,
          candidate_fps:compared[0].candidateFps,
          fps_delta_percent:Number(compared[0].deltaFps.toFixed(1)),
          p95_improvement_percent:Number(compared[0].deltaP95.toFixed(1)),
          verdict:compared[0].status});
        summary.push(...sample);
      }
    }
  }
  check(platforms.Android>=2 && platforms.iOS>=1,
    'Need at least two physical Android phones and one physical iPhone');
  return {schema:'NEBULA_R40_OFFLINE_EVIDENCE_V1',
    local_evidence_structure:'PASS',
    phones_declared:input.devices.length,physical_jsons_read:summary.length,
    checked_images:images,results:rows,
    caveat:'A script cannot independently authenticate physical devices or screenshot provenance. Actual human visual inspection and thermal/handling sign-off remain mandatory.'};
}
try {
  if (process.argv[2]==='--selftest') {
    const api=viewer();
    const fixture={schema:'NEBULA_R12_HARDWARE_BENCHMARK',
      build_variant:api.r40CandidateBuildId,quality:1,quality_changed:false,
      quality_gate:'MEETS_TARGET',sample_seconds:20,valid_frames:800,
      excluded_long_frames:0,adapter_reported:'SYNTHETIC TEST',runtime:'Web',
      resolution_width:390,resolution_height:844,avg_fps:50,
      one_percent_low_fps:35,p95_frame_ms:23,p99_frame_ms:29};
    check(api.parseReport(fixture,'fixture.json','CI','R40').reportedBuild===
      api.r40CandidateBuildId,'R40 provenance regression');
    console.log('NEBULA_R40_FIELD_GATE_SELFTEST_SUCCESS synthetic_only=true hardware=0');
  } else {
    check(process.argv.length===3,
      'Usage: node scripts/nebula-r40-field-release-gate.mjs /path/to/manifest.json');
    console.log(JSON.stringify(inspect(process.argv[2]),null,2));
  }
} catch(e) {
  console.error('NEBULA_R40_FIELD_NOT_APPROVED: '+String(e.message));
  process.exitCode=1;
}
