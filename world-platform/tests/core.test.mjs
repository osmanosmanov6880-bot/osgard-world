import test from "node:test";
import assert from "node:assert/strict";
import {
  SOURCE_SHA,CI_RUN,MAX_EVENTS,WORDS,MISSIONS,t,formatClock,
  validateManifest,validGameState,readGameState,metricsFrom,missionState,
  captureEngineEvent,appendObservedEvent,completedFromEngine,createPrivateSession
} from "../core.mjs";

function realShapedFixture(overrides={}){
  return {
    real_native_3d:true,w73_real_native_world_raycast:true,
    status:"playing",metrics:{heat:61,integrity:82},shift:0,
    w74_real_frame_time_p95_ms:17.9,w71_mission_active:false,
    w71_mission_phase:0,w71_mission_complete:false,
    history_count:0,last_event:"",w72_valve_index:0,w72_relay_mask:0,
    w72_sync_step:0,w73_real_raycast_uses:0,...overrides
  };
}
const paths=[
  "index.html","index.js","index.wasm","index.pck","index.png",
  "index.icon.png","index.apple-touch-icon.png",
  "index.audio.worklet.js","index.audio.position.worklet.js"
];
function exactManifest(){
  return {
    schema:"LAST_FRONTIER_WORLD_PLATFORM_V1",sourceSha:SOURCE_SHA,
    softwareCiUrl:CI_RUN,gameEngine:"Godot 4.4.1",
    releaseStatus:"PRODUCTION_HOLD",
    gameFiles:paths.map(path=>({
      path:"game/"+path,bytes:1024,sha256:"a".repeat(64)
    }))
  };
}

test("RU and EN both have 5 original mission phases and complete translations",()=>{
  assert.equal(MISSIONS.ru.length,5);
  assert.equal(MISSIONS.en.length,5);
  for(const key of Object.keys(WORDS.ru)){
    assert.ok(WORDS.en[key],"missing EN: "+key);
    assert.ok(WORDS.ru[key],"missing RU: "+key);
  }
  assert.match(t("en","navMissions"),/Mission/);
  assert.match(t("ru","navMissions"),/миссии/);
  assert.equal(t("ru","missing_label"),"missing_label");
});
test("actual canonical SHA/CI manifests accepted, unsigned placeholder source rejected",()=>{
  assert.ok(validateManifest(exactManifest()));
  assert.equal(SOURCE_SHA.length,40);
  assert.ok(CI_RUN.includes("/actions/runs/40650956529"));
  for(const bad of [
    {...exactManifest(),sourceSha:"0".repeat(40)},
    {...exactManifest(),releaseStatus:"RELEASE_APPROVED"},
    {...exactManifest(),gameEngine:"Fake Engine"},
    {...exactManifest(),softwareCiUrl:"https://example.com/success"},
    {...exactManifest(),gameFiles:[]},
    {...exactManifest(),gameFiles:exactManifest().gameFiles.slice(1).filter(x=>x.path!=="game/index.wasm")},
    {...exactManifest(),gameFiles:exactManifest().gameFiles.map(x=>({...x,sha256:"0"}))},
    {...exactManifest(),gameFiles:exactManifest().gameFiles.map(x=>({...x,path:"../leak"}))},
  ])assert.equal(validateManifest(bad),false);
});
test("duplicate files, noninteger sizes and network URLs refused",()=>{
  const m=exactManifest();
  assert.equal(validateManifest({...m,gameFiles:m.gameFiles.concat(m.gameFiles[0])}),false);
  assert.equal(validateManifest({...m,gameFiles:m.gameFiles.map(x=>({...x,bytes:12.1}))}),false);
  assert.equal(validateManifest({...m,gameFiles:m.gameFiles.map(x=>({...x,path:"https://evil.com/index.wasm"}))}),false);
});
test("missing engine never invents reactor metrics or mission success",()=>{
  assert.equal(validGameState(null),false);
  assert.equal(validGameState({fake:true}),false);
  assert.equal(metricsFrom(null),null);
  assert.equal(readGameState({contentDocument:{getElementById:()=>null}}),null);
  assert.equal(missionState(null,"ru").every(s=>s.status==="awaiting"),true);
});
test("actual game state reader rejects malformed, oversized or fake state",()=>{
  const broken={contentDocument:{getElementById:()=>({getAttribute:()=>"{")})}};
  assert.equal(readGameState(broken),null);
  const dummy={contentDocument:{getElementById:()=>({getAttribute:()=>JSON.stringify(realShapedFixture())})}};
  assert.equal(readGameState(dummy).real_native_3d,true);
});
test("metrics and source-bound p95 never fabricated before valid engine",()=>{
  const m=metricsFrom(realShapedFixture());
  assert.equal(m.heat,61);
  assert.equal(m.integrity,82);
  assert.equal(m.cycle,1);
  assert.equal(m.p95,17.9);
  assert.equal(metricsFrom(realShapedFixture({metrics:{heat:999,integrity:-45}})).heat,100);
  assert.equal(metricsFrom(realShapedFixture({metrics:{heat:999,integrity:-45}})).integrity,0);
});
test("all five real objectives follow original state only, never web page choices",()=>{
  const waiting=missionState(realShapedFixture(),"en");
  assert.equal(waiting.every(x=>x.status==="awaiting"),true);
  const active=missionState(realShapedFixture({w71_mission_active:true,w71_mission_phase:2}),"ru");
  assert.deepEqual(active.map(x=>x.status),["done","done","active","later","later"]);
  const forged=missionState(realShapedFixture({w71_mission_active:true,w71_mission_phase:5,
    status:"failed",w71_mission_complete:false}),"en");
  assert.equal(forged[4].status,"active");
  assert.equal(forged.every(x=>x.status==="done"),false);
  const won=missionState(realShapedFixture({w71_mission_active:true,w71_mission_phase:5,
    status:"won",w71_mission_complete:true}),"en");
  assert.equal(won.every(x=>x.status==="done"),true);
});
test("self-reported session cannot assert AAA, 12 independent persons, hardware test or publication",()=>{
  const state=realShapedFixture({status:"won",w71_mission_complete:false});
  const report=createPrivateSession({
    id:"local-test",sourceSha:SOURCE_SHA,startIso:"2026-10-28T08:00:00Z",
    endIso:"2026-10-28T08:09:59Z",elapsedMs:600000,
    events:[captureEngineEvent(state,50000)],lastState:state,
    confusion:3,note:"Need clarity on relay puzzle"
  });
  assert.equal(report.completed_in_actual_engine,false);
  assert.equal(report.observed_by_independent_human,false);
  assert.equal(report.claimed_as_part_of_independent_12_player_study,false);
  assert.equal(report.verified_real_device_benchmark,false);
  assert.equal(report.no_automatic_network_transmission,true);
  assert.equal(report.commercial_release_approved,false);
  assert.equal(report.event_count,1);
  assert.equal(report.observed_elapsed_seconds,600);
});
test("real win requires both engine win AND original five-station completed field objective",()=>{
  assert.equal(completedFromEngine(realShapedFixture({status:"won",w71_mission_complete:false})),false);
  assert.equal(completedFromEngine(realShapedFixture({status:"playing",w71_mission_complete:true})),false);
  assert.equal(completedFromEngine(realShapedFixture({status:"won",w71_mission_complete:true})),true);
});
test("identical engine polls do not masquerade as repeated player decisions",()=>{
  let events=appendObservedEvent([],realShapedFixture(),200);
  events=appendObservedEvent(events,realShapedFixture(),450);
  assert.equal(events.length,1);
  events=appendObservedEvent(events,realShapedFixture({history_count:1,last_event:"PUMP"}),500);
  assert.equal(events.length,2);
  events=appendObservedEvent(events,realShapedFixture({history_count:2,last_event:"SCAN"}),600);
  assert.equal(events.length,3);
  assert.deepEqual(events.map(e=>e.history_count),[0,1,2]);
});
test("recording is bounded to 160 actual state transitions",()=>{
  let events=[];
  for(let i=0;i<190;i++){
    events=appendObservedEvent(events,realShapedFixture({w73_real_raycast_uses:i}),i*100);
  }
  assert.equal(events.length,MAX_EVENTS);
  assert.throws(()=>createPrivateSession({
    id:"test",sourceSha:SOURCE_SHA,events:new Array(MAX_EVENTS+1).fill({}),
    lastState:null,elapsedMs:0,confusion:0,note:""
  }),/Event count/);
});
test("session source sha and duration sanity",()=>{
  assert.throws(()=>createPrivateSession({
    sourceSha:"wrong",events:[],elapsedMs:0
  }),/does not match/);
  assert.equal(formatClock(0),"00:00");
  assert.equal(formatClock(90000),"01:30");
  assert.equal(formatClock(-1),"00:00");
  assert.equal(formatClock(Number.NaN),"00:00");
});
