import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const evidence=JSON.parse(readFileSync(new URL('../docs/OSA_CINEMA_V53_CONCEPT_EVIDENCE_20261028.json',import.meta.url),'utf8'));
const ledger=readFileSync(new URL('../docs/OSA_CINEMA_V53_MASTER_PRODUCTION_LEDGER_RU.md',import.meta.url),'utf8');
const expected={
  'RU/720P':['15453727','c2d78b3489fec79f2964b13c1bd275905398f5d3002630621cfc8a28e64e0c92'],
  'EN/720P':['41726289','d7796e077b111031ba33218e5574b4d2897364e4634e91f00d8655d96bad0a15'],
  'RU/1080P':['171783167','2ff1eaaf7613b33abf24fe1d30fcf14e6ca752dc55bcee27e7b2cdaf6e16a99b'],
  'EN/1080P':['172059646','8a2687ccfd1bc7f470cc2924bbe1ca0d5ab00212b66249cf571a4cb82ba2d321']
};

test('V53 evidence is not a fabricated public or finished theatrical premiere',()=>{
 assert.equal(evidence.schemaVersion,1);
 assert.equal(evidence.version,'V53');
 assert.equal(evidence.publicReleaseAuthorized,false);
 assert.equal(evidence.premiereUrl,null);
 assert.equal(evidence.shortFilmFinished,false);
 assert.equal(evidence.featureFilmFinished,false);
 assert.equal(evidence.actorSceneProduction.scenesFilmed,0);
 assert.equal(evidence.actorSceneProduction.shotsFilmed,0);
 assert.equal(evidence.actorSceneProduction.shotsProposed,78);
 assert.equal(evidence.actorSceneProduction.shortTargetSeconds,1080);
 assert.equal(evidence.historicalV50PublicationUnchanged,true);
 assert.match(evidence.goDecision,/NO_PUBLIC_MOVIE_RELEASE/);
 assert.match(ledger,/NO_GO/);
});
test('exact 4 160-second master files are pinned, not committed in this repo',()=>{
 assert.equal(evidence.media.conceptCutSeconds,160);
 assert.equal(evidence.media.framerate,24);
 assert.equal(evidence.media.framesPerMaster,3840);
 assert.equal(evidence.media.masters.length,4);
 for(const master of evidence.media.masters){
  const key=master.locale+'/'+master.quality;
  assert.deepEqual([String(master.bytes),master.sha256],expected[key]);
  assert.match(master.sha256,/^[0-9a-f]{64}$/);
 }
 assert.equal(new Set(evidence.media.masters.map(x=>x.locale+'/'+x.quality)).size,4);
 assert.equal(evidence.media.subtitleTrackCount,2);
 assert.equal(evidence.media.screenTitleCuesPerLanguage,16);
 assert.equal(evidence.media.integratedLUFS,-18.5);
 assert.equal(evidence.media.truePeakDbTP,-5.1);
});
test('three owner-only packages have full hashes and verified QA; no fake browser pass',()=>{
 const p=evidence.packages;
 assert.equal(p.length,3);
 const expectedZip={
   SCREENING:['62496319','2bbb5a0447225eb52a58c48781e2c54581d5a5917741bf31b38fb5b0d5b5b30d',38],
   FULLHD:['406339483','55b3a56ec825a5e6b79c5d47e6fed5096d8982fc56923db06ce366a0c819eb26',40],
   EDIT_SOURCE:['532650023','72fe02b9eb346ee7700183831b57c258cceef3eda4cde6a86f02f779f990d099',114]
 };
 for(const item of p){
  assert.deepEqual([String(item.bytes),item.sha256,item.files],expectedZip[item.type]);
  assert.equal(item.availableAs,'OWNER_LOCAL_DOWNLOAD_NOT_IN_GIT');
 }
 assert.equal(p[0].resolutionToggle1080Disabled,true);
 assert.equal(p[1].resolutionToggle1080Disabled,false);
 assert.equal(evidence.qa.fullMediaDecodes,'PASS_4_OF_4');
 assert.equal(evidence.qa.originalHttpChromiumUI,'PASS_12_OF_12');
 assert.equal(evidence.qa.extractedScreeningIntegration,'PASS_6_OF_6');
 assert.match(evidence.qa.chromiumActualPlayback,/NOT_VERIFIED/);
 assert.match(evidence.qa.publicHttps,/NOT_VERIFIED/);
 assert.match(evidence.qa.rights,/UNVERIFIED/);
});
test('creative roadmap does not collapse source filming, rights, and feature screenplay into video previews',()=>{
 assert.equal(evidence.nextGates.length,5);
 for(const gate of ['V54','V55','V56','V57','V58'])assert.ok(evidence.nextGates.some(x=>x.startsWith(gate)));
 assert.match(ledger,/13 сцен/);
 assert.match(ledger,/78/);
 assert.match(ledger,/102-минутная/);
 assert.match(ledger,/не независимо проверено/);
});
