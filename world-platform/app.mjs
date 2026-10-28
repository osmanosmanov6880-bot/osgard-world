// W76 WORLD PLATFORM / real Godot, no mock game actions or remote analytics.
// All live numbers are read-only observations from the original Godot canvas.
import {
  SOURCE_SHA,STORAGE_KEY,WORDS,MISSIONS,t,formatClock,validateManifest,
  validGameState,readGameState,metricsFrom,missionState,appendObservedEvent,
  createPrivateSession,CI_RUN
} from "./core.mjs";

const $=(id)=>document.getElementById(id);
const node={
  frame:$("gameFrame"),poster:$("poster"),loader:$("loadingOverlay"),
  bootMessage:$("loadingMessage"),status:$("runtimeStatus"),statusDot:$("runtimeDot"),
  launch:$("launchButton"),focus:$("focusButton"),fullscreen:$("fullscreenButton"),
  routeName:$("routeName"),buildDot:$("buildDot"),buildStatus:$("buildStatus"),
  sourceShort:$("sourceShort"),sourceFull:$("sourceFull"),
  verify:$("verifyFiles"),offline:$("offlineButton"),integrity:$("integrityProgress"),
  wasmStatus:$("wasmFileStatus"),packStatus:$("packFileStatus"),
  timer:$("sessionTimer"),sessionStatus:$("sessionStatus"),
  consent:$("consentCheckbox"),sessionStart:$("sessionStart"),
  sessionStop:$("sessionStop"),export:$("exportSession"),
  confusion:$("confusionRange"),confusionOutput:$("confusionOutput"),
  feedback:$("feedbackNote"),eventCount:$("eventCount"),
  toast:$("toast")
};
let locale="ru";
try{locale=localStorage.getItem("lf-world-lang")==="en"?"en":"ru"}catch{ /* private mode */ }
let currentRoute="command";
let manifest=null;
let gameState=null;
let engineReady=false;
let engineStarting=false;
let frameChecks=0;
let integrityStatus="not_checked";
let activeSession=null;
let finalSession=null;
let pendingPoll=null;
let timerHandle=null;
let toastTimer=null;
let swRegistration=null;
let latestStateIdentity="";
const MAX_BOOT_POLLS=300;

function announce(message,kind="info"){
  node.toast.textContent=message;
  node.toast.hidden=false;
  node.toast.style.borderColor=kind==="error"?"#b36c67":"#6aa398";
  clearTimeout(toastTimer);
  toastTimer=setTimeout(()=>{node.toast.hidden=true},6000);
}
function accessibleLocale(){
  document.documentElement.lang=locale;
  document.title=(locale==="ru"?"ПОСЛЕДНИЙ РУБЕЖ":"LAST FRONTIER")+" / WORLD OPERATIONS";
  $("currentLocale").textContent=locale.toUpperCase();
  for(const el of document.querySelectorAll("[data-i18n]")){
    el.textContent=t(locale,el.dataset.i18n);
  }
  // Trusted static localization only, never raw HTML from game, localStorage or notes.
  for(const el of document.querySelectorAll("[data-i18n-html]")){
    el.innerHTML=t(locale,el.dataset.i18nHtml);
  }
  for(const el of document.querySelectorAll("[data-i18n-title]")){
    el.title=t(locale,el.dataset.i18nTitle);
    el.setAttribute("aria-label",el.title);
  }
  for(const el of document.querySelectorAll("[data-i18n-placeholder]")){
    el.placeholder=t(locale,el.dataset.i18nPlaceholder);
  }
  node.routeName.textContent=t(locale,"nav"+currentRoute[0].toUpperCase()+currentRoute.slice(1));
  node.status.textContent=t(locale,engineReady?"gameReady":engineStarting?"gameBoot":"gameIdle");
  node.buildStatus.textContent=t(locale,manifest?"verified":"unverified");
  if(manifest)node.integrity.textContent=t(locale,integrityStatus==="verified"?"verifiedAll":"manifestLoaded");
  if(activeSession)node.sessionStatus.textContent=t(locale,"sessionRunning");
  else node.sessionStatus.textContent=t(locale,finalSession?"sessionFinished":"sessionIdle");
  node.confusionOutput.textContent=node.confusion.value;
  renderMissions();
}
function go(route){
  if(!["command","missions","lab","system"].includes(route))return;
  currentRoute=route;
  for(const id of ["command","missions","lab","system"]){
    $("view-"+id).hidden=id!==route;
  }
  for(const el of document.querySelectorAll("[data-route]")){
    const current=el.dataset.route===route;
    el.classList.toggle("active",current);
    if(current)el.setAttribute("aria-current","page");
    else el.removeAttribute("aria-current");
  }
  node.routeName.textContent=t(locale,"nav"+route[0].toUpperCase()+route.slice(1));
  window.scrollTo({top:0,behavior:"instant"});
  if(route==="lab")updateResearchControls();
}
function setGamePhase(status){
  node.statusDot.classList.toggle("good",status==="ready");
  node.statusDot.classList.toggle("error",status==="error");
  node.status.textContent=t(locale,
    status==="ready"?"gameReady":status==="error"?"gameFail":
    status==="starting"?"gameBoot":"gameIdle");
}
function renderMissions(){
  const rows=missionState(gameState,locale);
  const parent=$("missionList");
  parent.replaceChildren();
  for(const item of rows){
    const entry=document.createElement("article");
    entry.className="mission-entry"+(item.status==="done"?" is-done":
      item.status==="active"?" is-active":"");
    const index=document.createElement("span");
    index.className="mission-number";
    index.textContent=String(item.index+1).padStart(2,"0");
    const copy=document.createElement("div");copy.className="mission-copy";
    const h=document.createElement("h3");h.textContent=item.name;
    const p=document.createElement("p");p.textContent=item.description;
    copy.append(h,p);
    const status=document.createElement("span");status.className="mission-state";
    const statusTranslation=item.status==="done"?"missionDone":item.status==="active"?
      "missionActive":item.status==="later"?"missionLater":"missionAwaiting";
    status.textContent=t(locale,statusTranslation);
    entry.append(index,copy,status);parent.appendChild(entry);
  }
}
function updateMetrics(){
  const m=metricsFrom(gameState);
  const set=(id,value)=>{$(id).textContent=value};
  const meter=(id,val)=>{$(id).style.width=val+"%"};
  if(!m){
    for(const id of ["heatValue","integrityValue","cycleValue","frameValue"])set(id,"—");
    for(const id of ["heatMeter","integrityMeter","cycleMeter","frameMeter"])meter(id,0);
    return;
  }
  set("heatValue",Math.round(m.heat)+"%");
  set("integrityValue",Math.round(m.integrity)+"%");
  set("cycleValue",String(m.cycle).padStart(2,"0")+" / 06");
  set("frameValue",m.p95.toFixed(1)+" ms");
  meter("heatMeter",m.heatPct);
  meter("integrityMeter",m.integrityPct);
  meter("cycleMeter",m.filledCycle);
  meter("frameMeter",m.framePct);
}
function observeGame(){
  if(!engineStarting&&!engineReady)return;
  const state=readGameState(node.frame);
  if(!state){
    if(!engineReady&&++frameChecks>MAX_BOOT_POLLS){
      clearInterval(pendingPoll);pendingPoll=null;engineStarting=false;
      node.loader.hidden=true;setGamePhase("error");
      announce(t(locale,"launchError"),"error");
      node.launch.disabled=false;
    }
    return;
  }
  const first=!engineReady;
  engineReady=true;engineStarting=false;gameState=state;
  if(first){
    node.loader.hidden=true;node.poster.hidden=true;node.frame.hidden=false;
    node.focus.disabled=false;node.fullscreen.disabled=false;
    setGamePhase("ready");node.frame.title="LAST FRONTIER / REAL GODOT";
    node.launch.disabled=true;
    node.frame.focus();
    updateResearchControls();
  }
  const identity=[state.shift,state.history_count,state.w71_mission_phase,
    state.w72_valve_index,state.w72_relay_mask,state.w72_sync_step,state.status,
    state.last_event,state.w73_real_raycast_uses].join(":");
  if(identity!==latestStateIdentity){
    latestStateIdentity=identity;
    renderMissions();
  }
  updateMetrics();
  if(activeSession){
    const elapsed=performance.now()-activeSession.startMono;
    activeSession.events=appendObservedEvent(activeSession.events,state,elapsed);
    node.eventCount.textContent=String(activeSession.events.length);
  }
}
function launchGame(){
  if(engineReady){go("command");focusGame();return}
  if(engineStarting)return;
  if(!manifest){
    announce(t(locale,"noGame"),"error");
    return;
  }
  engineStarting=true;frameChecks=0;
  node.launch.disabled=true;node.loader.hidden=false;
  node.poster.hidden=true;node.frame.hidden=false;
  node.bootMessage.textContent=t(locale,"loadingFiles");
  setGamePhase("starting");
  node.frame.src="./game/index.html";
  pendingPoll=setInterval(observeGame,350);
}
function focusGame(){
  if(!engineReady)return;
  go("command");
  try{
    node.frame.contentWindow.focus();
    const canvas=node.frame.contentDocument?.querySelector("canvas");
    if(canvas){canvas.setAttribute("tabindex","0");canvas.focus();}
    else node.frame.focus();
  }catch{node.frame.focus();}
}
async function fullscreenGame(){
  if(!engineReady)return;
  const stage=$("gameStage");
  try{
    if(document.fullscreenElement){await document.exitFullscreen();}
    else if(stage.requestFullscreen)await stage.requestFullscreen();
    else throw new Error("Fullscreen API unavailable");
    focusGame();
  }catch(e){announce(t(locale,"error")+": "+e.message,"error");}
}
function updateResearchControls(){
  node.sessionStart.disabled=!(engineReady&&!activeSession&&node.consent.checked);
  node.sessionStop.disabled=!activeSession;
  node.export.disabled=!finalSession||Boolean(activeSession);
}
function sessionTick(){
  if(!activeSession)return;
  node.timer.textContent=formatClock(performance.now()-activeSession.startMono);
}
function createRandomCode(){
  if(typeof crypto!=="undefined"&&crypto.randomUUID)return crypto.randomUUID();
  const bytes=new Uint8Array(16);crypto.getRandomValues(bytes);
  return Array.from(bytes,b=>b.toString(16).padStart(2,"0")).join("");
}
function startSession(){
  if(!engineReady||!gameState){announce(t(locale,"sessionNeedGame"),"error");return;}
  if(!node.consent.checked){announce(t(locale,"sessionNeedConsent"),"error");return;}
  activeSession={
    id:createRandomCode(),startMono:performance.now(),startIso:new Date().toISOString(),
    events:[],sourceSha:manifest.sourceSha
  };
  activeSession.events=appendObservedEvent([],gameState,0);
  finalSession=null;
  node.eventCount.textContent=String(activeSession.events.length);
  node.timer.textContent="00:00";
  node.sessionStatus.textContent=t(locale,"sessionRunning");
  clearInterval(timerHandle);timerHandle=setInterval(sessionTick,200);
  updateResearchControls();
}
function stopSession(){
  if(!activeSession)return;
  const elapsedMs=Math.max(0,performance.now()-activeSession.startMono);
  const actual=readGameState(node.frame);
  finalSession=createPrivateSession({
    id:activeSession.id,sourceSha:activeSession.sourceSha,
    startIso:activeSession.startIso,endIso:new Date().toISOString(),
    elapsedMs,events:activeSession.events,lastState:actual,
    confusion:node.confusion.value,note:node.feedback.value
  });
  activeSession=null;
  clearInterval(timerHandle);timerHandle=null;
  node.timer.textContent=formatClock(elapsedMs);
  node.sessionStatus.textContent=t(locale,"sessionFinished");
  updateResearchControls();
}
function downloadBlob(blob,name){
  const url=URL.createObjectURL(blob);
  const a=document.createElement("a");a.href=url;a.download=name;
  document.body.appendChild(a);a.click();a.remove();
  setTimeout(()=>URL.revokeObjectURL(url),1000);
}
function exportSession(){
  if(!finalSession)return;
  // Allow a note to be edited AFTER finishing but before explicit export.
  finalSession.player_note=String(node.feedback.value||"").slice(0,500);
  finalSession.confusion_events=Number(node.confusion.value);
  const json=JSON.stringify(finalSession,null,2)+"\n";
  downloadBlob(new Blob([json],{type:"application/json"}),
    "LAST_FRONTIER_REAL_SELF_OBSERVED_"+finalSession.session_code.slice(0,8)+".json");
  announce(t(locale,"sessionExported"));
}
function updateFileState(type,status){
  if(type==="wasm"){
    node.wasmStatus.textContent=t(locale,status==="valid"?"verifiedFile":"badFile");
    $("wasmDot").className="mini-dot "+(status==="valid"?"good":"stop");
  }else{
    node.packStatus.textContent=t(locale,status==="valid"?"verifiedFile":"badFile");
    $("packDot").className="mini-dot "+(status==="valid"?"good":"stop");
  }
}
async function sha256(bytes){
  const hash=await crypto.subtle.digest("SHA-256",bytes);
  return Array.from(new Uint8Array(hash),x=>x.toString(16).padStart(2,"0")).join("");
}
async function verifyFiles(){
  if(!manifest||!crypto?.subtle){announce(t(locale,"noGame"),"error");return false;}
  node.verify.disabled=true;integrityStatus="verifying";
  let good=true;
  for(let i=0;i<manifest.gameFiles.length;i++){
    const file=manifest.gameFiles[i];
    node.integrity.textContent=t(locale,"verifyingFile")+" "+(i+1)+"/"+
      manifest.gameFiles.length+" · "+file.path;
    try{
      const response=await fetch("./"+file.path,{cache:"no-store"});
      if(!response.ok)throw new Error("HTTP "+response.status);
      const bytes=await response.arrayBuffer();
      const actual=await sha256(bytes);
      if(bytes.byteLength!==file.bytes||actual!==file.sha256)
        throw new Error("SHA-256 does not match "+file.path);
      if(file.path==="game/index.wasm")updateFileState("wasm","valid");
      if(file.path==="game/index.pck")updateFileState("pck","valid");
    }catch(error){
      good=false;
      if(file.path==="game/index.wasm")updateFileState("wasm","bad");
      if(file.path==="game/index.pck")updateFileState("pck","bad");
      node.integrity.textContent=t(locale,"badFile")+": "+file.path+
        " · "+String(error.message||error);
      announce(node.integrity.textContent,"error");break;
    }
  }
  integrityStatus=good?"verified":"failed";
  node.integrity.textContent=good?t(locale,"verifiedAll"):node.integrity.textContent;
  node.verify.disabled=false;node.offline.disabled=!good||!swRegistration;
  return good;
}
async function offlineGame(){
  if(integrityStatus!=="verified"||!manifest||!swRegistration){
    announce(t(locale,"offlineUnavailable"),"error");return;
  }
  node.offline.disabled=true;
  node.integrity.textContent=t(locale,"offlinePreparing");
  const channel=new MessageChannel();
  const done=new Promise((resolve,reject)=>{
    const timeout=setTimeout(()=>reject(new Error("Offline cache exceeded timeout")),120_000);
    channel.port1.onmessage=(e)=>{
      const data=e.data;
      if(data?.type==="PROGRESS"){
        node.integrity.textContent=t(locale,"offlinePreparing")+" "+
          data.done+"/"+data.total;
      }else if(data?.type==="DONE"){
        clearTimeout(timeout);resolve();
      }else if(data?.type==="ERROR"){
        clearTimeout(timeout);reject(new Error(data.message||"Cache failure"));
      }
    };
  });
  try{
    const registration=await navigator.serviceWorker.ready;
    const worker=registration.active;
    if(!worker)throw new Error("Service worker unavailable");
    worker.postMessage({type:"CACHE_GAME",files:manifest.gameFiles},
      [channel.port2]);
    await done;
    node.integrity.textContent=t(locale,"offlineReady");
    announce(t(locale,"offlineReady"));
  }catch(e){
    node.integrity.textContent=t(locale,"error")+": "+e.message;
    announce(node.integrity.textContent,"error");
  }finally{node.offline.disabled=false;channel.port1.close();}
}
async function initServiceWorker(){
  if(!("serviceWorker" in navigator)||!isSecureContext)return;
  try{
    swRegistration=await navigator.serviceWorker.register("./sw.js",{scope:"./"});
    if(integrityStatus==="verified")node.offline.disabled=false;
  }catch{swRegistration=null;}
}
async function initManifest(){
  node.launch.disabled=true;
  node.verify.disabled=true;node.offline.disabled=true;
  try{
    const response=await fetch("./release-manifest.json",{cache:"no-store"});
    if(!response.ok)throw new Error("Manifest HTTP "+response.status);
    const candidate=await response.json();
    if(!validateManifest(candidate))throw new Error("Build source SHA or file list invalid");
    manifest=candidate;
    node.sourceShort.textContent=candidate.sourceSha.slice(0,9).toUpperCase();
    node.sourceFull.textContent=candidate.sourceSha;
    node.buildDot.className="indicator-led good";
    $("sourceVerifiedIcon").className="mini-dot good";
    node.buildStatus.textContent=t(locale,"verified");
    node.integrity.textContent=t(locale,"manifestLoaded");
    node.launch.disabled=false;node.verify.disabled=false;
  }catch(e){
    node.buildDot.className="indicator-led failed";
    node.buildStatus.textContent=t(locale,"unverified");
    node.integrity.textContent=t(locale,"error")+": "+e.message;
    node.launch.disabled=true;node.verify.disabled=true;
  }
}
function bind(){
  $("primaryNav").addEventListener("click",(event)=>{
    const button=event.target.closest("[data-route]");
    if(button)go(button.dataset.route);
  });
  $("localeButton").addEventListener("click",()=>{
    locale=locale==="ru"?"en":"ru";
    try{localStorage.setItem("lf-world-lang",locale)}catch{}
    accessibleLocale();
  });
  node.launch.addEventListener("click",launchGame);
  $("missionLaunch").addEventListener("click",()=>{go("command");if(engineReady)focusGame();});
  node.focus.addEventListener("click",focusGame);
  node.fullscreen.addEventListener("click",fullscreenGame);
  node.consent.addEventListener("change",updateResearchControls);
  node.sessionStart.addEventListener("click",startSession);
  node.sessionStop.addEventListener("click",stopSession);
  node.export.addEventListener("click",exportSession);
  node.confusion.addEventListener("input",()=>node.confusionOutput.textContent=node.confusion.value);
  node.verify.addEventListener("click",verifyFiles);
  node.offline.addEventListener("click",offlineGame);
  node.frame.addEventListener("error",()=>announce(t(locale,"launchError"),"error"));
  document.addEventListener("visibilitychange",()=>{
    if(activeSession)sessionTick();
  });
}
bind();
accessibleLocale();
updateMetrics();
updateResearchControls();
go("command");
Promise.all([initManifest(),initServiceWorker()]);
