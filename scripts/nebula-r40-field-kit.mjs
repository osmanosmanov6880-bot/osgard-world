#!/usr/bin/env node
// Create an EMPTY private field-QA folder. No fabricated FPS, phones or images.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const TEMPLATE=path.join(ROOT,'docs/nebula/R40-DEVICE-FIELD-MANIFEST.example.json');
const R38='https://osgard.world/games/remix/arena-v2/nebula-3d/';
const R40='https://osgard.world/games/remix/nebula-r40-qa/';
const ORIENTATIONS=['portrait','landscape'];
const PROFILES=['MAX','HIGH','ECO'];
function assert(ok,reason){if(!ok)throw new Error(reason);}
function within(root,destination){
  const rel=path.relative(root,destination);
  return rel===''||(!rel.startsWith('..'+path.sep)&&rel!=='..'&&!path.isAbsolute(rel));
}
function plan(manifest){
  const lines=[];let reports=0,images=0;
  for(const d of manifest.devices){
    assert(/^[A-Za-z0-9_-]{3,48}$/.test(d.id||''),'Invalid anonymous phone label');
    for(const orientation of ORIENTATIONS){
      const v=d.visual?.[orientation];
      assert(v?.baseline_image&&v?.candidate_image,'Missing screenshot slot');
      images+=2;
      lines.push('- [ ] '+d.id+' / '+orientation+
        ': save original R38 and R40 screenshots to '+v.baseline_image+' and '+
        v.candidate_image+'; inspect bridge lights, collision, controls and HUD.');
      for(const profile of PROFILES){
        const matches=(d.runs||[]).filter(x=>x.orientation===orientation&&x.profile===profile);
        assert(matches.length===1,'Missing or duplicate group '+d.id+'/'+orientation+'/'+profile);
        for(const [build,files] of [['R38',matches[0].baseline],['R40',matches[0].candidate]]){
          assert(Array.isArray(files)&&files.length===3,'Exactly 3 expected files per build');
          assert(files.every(x=>typeof x==='string'&&x.startsWith('reports/')),
            'Unexpected report path');
          reports+=3;
          lines.push('- [ ] '+d.id+' / '+orientation+' / '+profile+' / '+build+
            ': three separate 20s tests -> '+files.join(', '));
        }
      }
    }
  }
  assert(reports>=108&&images>=12,'Minimum hardware matrix incomplete');
  return {lines,reports,images};
}
function init(folder){
  const out=path.resolve(folder);
  assert(!within(ROOT,out),'Private phone evidence must be outside the repository');
  assert(!within(out,ROOT),'Cannot initialize QA in an ancestor of the repository');
  if(fs.existsSync(out)){
    const info=fs.lstatSync(out);
    assert(info.isDirectory()&&!info.isSymbolicLink(),'Target is not an ordinary directory');
    assert(fs.readdirSync(out).length===0,'Target is not empty; refusing to overwrite evidence');
  }
  const template=fs.readFileSync(TEMPLATE,'utf8');
  const m=JSON.parse(template);
  assert(m.schema==='NEBULA_R40_PHYSICAL_FIELD_V1'&&
    m.field_work===false&&m.synthetic===false,'Template must be unapproved and empty');
  assert(Array.isArray(m.devices)&&m.devices.length>=3,'Three real phone slots required');
  const p=plan(m);
  fs.mkdirSync(out,{recursive:true,mode:0o700});
  for(const dir of ['reports','images'])fs.mkdirSync(path.join(out,dir),{mode:0o700});
  const readme=[
    '# NEBULA R40: private phone QA kit',
    '',
    'Production R38: '+R38,
    'Isolated QA R40: '+R40,
    '',
    'This kit has NO collected evidence on creation. Do not commit it to GitHub.',
    'Required: '+p.reports+' original 20s JSON reports and '+p.images+' real device screenshots.',
    'Use two real Androids and an iPhone Safari, portrait + landscape, MAX/HIGH/ECO, three repetitions per R38/R40 build.',
    'Export original JSON from each phone and use the exact filenames in CHECKLIST.md.',
    'Capture two real screenshots per orientation, record lighting/bridge/collision/touch/HUD/thermal results in FIELD_NOTES.md.',
    'Keep original files unchanged; never use AUTO, emulator, SwiftShader or fabricated GPU measurements.',
    'Only after authentic field work and independent review may the manifest reviewer, visual approval and field_work values be filled.',
    '',
    'From the repo root run:',
    '  node scripts/nebula-r40-device-progress.mjs <private-dir>/manifest.json',
    '  node scripts/nebula-r40-field-release-gate.mjs <private-dir>/manifest.json',
    '  node scripts/nebula-r40-production-preflight.mjs <private-dir>/manifest.json',
    '',
    'These checks never grant automatic production permission. Human approval and a separate reviewed promotion PR are required.',
    ''
  ].join('\n');
  const checklist=['# NEBULA R40: original source collection','',
    'Boxes deliberately unchecked; do not mark an unperformed device run as complete.','',
    ...p.lines,''].join('\n');
  const notes=['# Independent physical-device observations (private)','',
    'Record anonymous phone IDs, model class, browser/OS versions, battery/charging and thermal state; never IMEI or location.',''];
  for(const d of m.devices)notes.push('## '+d.id,'',
    'Portrait: bridge lamps/collision, touch/flight, HUD, glitches, heat and reviewer:',
    '',
    'Landscape: bridge lamps/collision, touch/flight, HUD, glitches, heat and reviewer:',
    '',
    'Any throttling or interrupted runs must be recorded, not concealed.','');
  for(const [name,data] of [['manifest.json',template],['README.md',readme],
                             ['CHECKLIST.md',checklist],['FIELD_NOTES.md',notes.join('\n')]]){
    fs.writeFileSync(path.join(out,name),data,{flag:'wx',mode:0o600});
  }
  return {schema:'NEBULA_R40_PRIVATE_FIELD_KIT_V1',status:'EMPTY_KIT_CREATED_NOT_APPROVED',
    directory:out,devices:m.devices.length,required_json:p.reports,
    required_screenshots:p.images,created_json:0,created_screenshots:0,
    production_approval:false};
}
try{
  assert(process.argv.length===4&&process.argv[2]==='init',
    'Usage: node scripts/nebula-r40-field-kit.mjs init /private/path/outside-repository');
  console.log(JSON.stringify(init(process.argv[3]),null,2));
}catch(e){
  console.error('NEBULA_R40_KIT_ERROR: '+String(e.message));
  process.exitCode=1;
}
