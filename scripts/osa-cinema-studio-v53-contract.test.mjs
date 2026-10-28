import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import vm from 'node:vm';

const html=readFileSync(new URL('../public/osa-cinema-studio/index.html',import.meta.url),'utf8');
const digest=createHash('sha256').update(html).digest('hex');

test('standalone V53 production HTML is exact reviewed source, no remote dependencies',()=>{
  assert.equal(digest,'6f2628b8921e6b850c8984d365cbf61c76cfd778e3d9a25aaf1a77035583d958');
  assert.match(html,/OSA CINEMA STUDIO/);
  assert.match(html,/const __SEED_JSON=/);
  assert.doesNotMatch(html,/<script[^>]+src=/i);
  assert.doesNotMatch(html,/<link[^>]+stylesheet/i);
  assert.doesNotMatch(html,/https:\/\/fonts\.googleapis\.com/);
});

test('inline JS is parseable and source contains exact 13 scenes and 78 camera setups',()=>{
  const script=html.match(/<script>([\s\S]*?)<\/script>/i)?.[1];
  assert.ok(script,'inline browser app missing');
  new vm.Script(script,{filename:'osa-cinema-studio-v53.js'});
  const raw=script.match(/const __SEED_JSON=("(?:\\.|[^"\\])*");/)?.[1];
  assert.ok(raw,'inline project JSON missing');
  const project=JSON.parse(JSON.parse(raw));
  assert.equal(project.schemaVersion,3);
  assert.equal(project.scenes.length,13);
  assert.equal(project.shots.length,78);
  assert.equal(project.shots.reduce((sum,s)=>sum+s.durationSec,0),1080);
  assert.equal(project.source.shortFilmShot,false);
  assert.equal(project.source.featureFilmProduced,false);
  assert.ok(project.scenes.every(s=>s.referenceFrame.startsWith('data:image/jpeg;base64,')));
  assert.equal(project.media.length,2);
  assert.ok(project.media.every(m=>m.path.startsWith('media-not-uploaded/')));
});

test('no cinema release gate or commerce is implicitly switched to public',()=>{
  assert.match(html,/NOT FILMED/);
  assert.match(html,/NO CLOUD/);
  assert.match(html,/localStorage/);
  assert.doesNotMatch(html,/stripe\.com|api\.openai\.com|service_role/i);
  const conf=readFileSync(new URL('../nginx.conf',import.meta.url),'utf8');
  assert.match(conf,/location \^~ \/osa-cinema-studio\//);
  assert.match(conf,/try_files \$uri =404;/);
  assert.match(conf,/alias \/var\/lib\/osgard-cinema-media\/current\//);
});
