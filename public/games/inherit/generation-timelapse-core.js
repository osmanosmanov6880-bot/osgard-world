/* INHERIT R8 — deterministic, read-only replay of saved generation frames.
 * Frames must come from InheritGenerationAtlas.getFrames(world): no invented
 * intermediate generations, users, timestamps, server acknowledgments or data.
 * Only a bounded display sample is rendered; all counts are exact.
 */
(function(root){
'use strict';
const MAX_POINTS=180;
function validAtlas(atlas){
 return atlas&&typeof atlas.getFrames==='function'&&typeof atlas.compare==='function';
}
function metadata(frames){
 return frames.map((frame,index)=>({
   id:frame.id,generation:frame.generation,source:frame.source,
   total:frame.objects.length,index
 }));
}
function create(world,selectedIndex,atlas=root.InheritGenerationAtlas){
 if(!validAtlas(atlas)){
  return {status:'unavailable',frames:[],frameCount:0};
 }
 const result=atlas.getFrames(world);
 const frames=result.frames,frameCount=frames.length;
 if(frameCount===0){
  return {status:'empty',frames:[],frameCount:0,skipped:result.skipped,limited:result.limited};
 }
 const index=Number.isSafeInteger(selectedIndex)?
  Math.max(0,Math.min(selectedIndex,frameCount-1)):0;
 const current=frames[index],previous=index>0?frames[index-1]:null;
 let markers=[],truncated=false,changes=null;
 if(previous){
  const comparison=atlas.compare(world,previous.id,current.id);
  // If valid snapshots changed between reads, do not invent a transition.
  if(comparison.status!=='ok'){
   return {status:'unavailable',frames:metadata(frames),frameCount,index};
  }
  changes={
   added:comparison.totals.added,removed:comparison.totals.removed,
   unchanged:comparison.totals.unchanged,net:comparison.totals.net
  };
  markers=comparison.pins.slice(0,MAX_POINTS).map(point=>({
   kind:point.kind,x:point.x,y:point.y,type:point.type
  }));
  truncated=comparison.totals.added+comparison.totals.removed+
   comparison.totals.unchanged>markers.length;
 }else{
  markers=current.objects.slice(0,MAX_POINTS).map(point=>({
   kind:'baseline',x:point.x,y:point.y,type:point.type
  }));
  truncated=current.objects.length>markers.length;
 }
 const difference=previous?current.generation-previous.generation:null;
 return {
  status:'ok',index,frameCount,frames:metadata(frames),
  frame:{id:current.id,generation:current.generation,source:current.source,
   total:current.objects.length},
  previous:previous?{id:previous.id,generation:previous.generation,source:previous.source}:null,
  changes,markers,markersTruncated:truncated,
  source:'local-or-account-saved-frame',
  // Never describe missing snapshots as inactivity, and never call a live
  // current-state frame a confirmed generation handoff.
  transition:difference===null?'first-available':
   difference===0?'same-generation':
   difference===1?'adjacent-saved-frames':'archive-gap',
  missingGenerationCount:difference!==null&&difference>1?difference-1:0,
  unavailableRecords:result.skipped||0,archiveLimited:!!result.limited,
  caveat:'These are observed saved states. Intermediate actions, authors and real-world dates are not verified.'
 };
}
const api=Object.freeze({create,maxPoints:MAX_POINTS});
root.InheritTimeLapseCore=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
