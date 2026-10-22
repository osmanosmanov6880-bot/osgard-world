/* INHERIT R15 — World Alive Engine.
 * A pure, deterministic reading of genuine saved traces and existing gameplay
 * systems. Never writes a save, fabricates an achievement, or calls a server.
 */
(function(root){
'use strict';
const TYPES=new Set(['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']);
const SEASONS=new Set(['tide','sun','wind','mist']);
const STAGES=new Set(['untouched','growing','settlement','ancient']);
function positiveInt(n){return Number.isSafeInteger(n)&&n>=0?n:0}
function summarize(world,services){
  const w=world&&typeof world==='object'?world:{};
  const api=services||root;
  let chapter=null,cycle=null,legacy=null;
  try{chapter=api.InheritStoryEngine?.evaluate?.(w)||null}catch{}
  try{cycle=api.InheritWorldCycle?.evaluate?.(w)||null}catch{}
  try{legacy=api.InheritLegacyEngine?.derive?.(w)||null}catch{}
  const validWorld=Number.isSafeInteger(w.generation)&&w.generation>=0&&
    Number.isSafeInteger(w.budget)&&w.budget>=0&&
    Array.isArray(w.objects)&&w.objects.length<=10000;
  const objects=validWorld?w.objects:[];
  const generation=validWorld?w.generation:0;
  const current=objects.length;
  const connections=positiveInt(legacy?.total);
  const goals=Array.isArray(chapter?.objectives)?chapter.objectives.slice(0,3).map(o=>({
    id:String(o.id||''),kind:o.kind==='link'?'link':'place',done:o.done===true,
    tool:TYPES.has(o.tool)?o.tool:null
  })):[];
  const completed=goals.filter(o=>o.done).length;
  const readonly=!validWorld||chapter?.dataConsistent===false||!!legacy?.limited||!!cycle?.limited;
  return Object.freeze({
    generation,objects:current,connections,budget:validWorld?w.budget:0,
    pending:positiveInt(Array.isArray(w.pending)?w.pending.length:0),
    chapter:typeof chapter?.chapter==='string'?chapter.chapter:'shore',
    season:SEASONS.has(cycle?.season)?cycle.season:'tide',
    stage:STAGES.has(cycle?.stage)?cycle.stage:'untouched',
    mood:['nature','routes','memory','quiet'].includes(chapter?.mood)?chapter.mood:'quiet',
    goals,completed,goalCount:goals.length,readonly,validWorld,limited:!!(legacy?.limited||cycle?.limited),
    verifiedHistory:positiveInt(cycle?.history?.span),
    next:readonly?null:(goals.find(o=>!o.done&&o.tool)?.tool||null)
  });
}
const api=Object.freeze({summarize,types:[...TYPES],seasons:[...SEASONS]});
root.InheritWorldAliveEngine=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
