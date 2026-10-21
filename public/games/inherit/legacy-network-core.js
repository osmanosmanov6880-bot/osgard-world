/* INHERIT R11 — deterministic network of rule-compatible *saved* traces.
   Pairs are geometric opportunities, not server events or the Legacy journal's
   nearest-neighbour discovery count. No IO, world writes or author claims. */
(function(root){
'use strict';
const TYPES=Object.freeze(['tree','stone','light','path','flower','arch','chime','moss','cairn','marker']);
const TYPE_SET=new Set(TYPES),MAX_OBJECTS=600,MAX_EDGES=12000,MAX_BRIDGE_ANCHORS=70;
const MIN_X=8,MAX_X=91,MIN_Y=12,MAX_Y=77;
const validGeneration=n=>Number.isSafeInteger(n)&&n>=0&&n<=10000000;
const validBudget=n=>Number.isSafeInteger(n)&&n>=0&&n<=100;
const rounded=n=>Number(n.toFixed(3));
function validObject(raw){
 if(!raw||typeof raw!=='object'||Array.isArray(raw))return null;
 const type=raw.tool||raw.type,x=raw.x,y=raw.y;
 if(!TYPE_SET.has(type)||typeof x!=='number'||typeof y!=='number'||
   !Number.isFinite(x)||!Number.isFinite(y)||x<0||x>100||y<0||y>100)return null;
 return {type,x,y};
}
function cleanRules(legacy){
 if(!Array.isArray(legacy?.rules)||!legacy.rules.length||legacy.rules.length>20)return null;
 const seen=new Set(),out=[];
 for(const rule of legacy.rules){
  if(!rule||typeof rule.id!=='string'||!TYPE_SET.has(rule.first)||
    !TYPE_SET.has(rule.second)||rule.first===rule.second||
    typeof rule.radius!=='number'||!Number.isFinite(rule.radius)||
    rule.radius<=0||rule.radius>30||seen.has(rule.id))return null;
  seen.add(rule.id);
  out.push({id:rule.id,first:rule.first,second:rule.second,radius:rule.radius});
 }
 return out;
}
function analyze(world,legacy=root.InheritLegacyEngine){
 if(!world||!validGeneration(world.generation)||!Array.isArray(world.objects)||
   !validBudget(world.budget)||!cleanRules(legacy))return {status:'unavailable'};
 if(world.objects.length>MAX_OBJECTS)return {status:'limited',maxObjects:MAX_OBJECTS};
 const nodes=world.objects.map(validObject);
 if(nodes.some(node=>!node))return {status:'unavailable'};
 const rules=cleanRules(legacy),adjacency=nodes.map(()=>[]),edges=[];
 const parent=nodes.map((_,i)=>i);
 function find(n){while(parent[n]!==n){parent[n]=parent[parent[n]];n=parent[n]}return n}
 function join(a,b){const ra=find(a),rb=find(b);if(ra!==rb)parent[rb]=ra}
 const byPair=new Map();
 for(const rule of rules){
  const pair=[rule.first,rule.second].sort().join(':');
  if(!byPair.has(pair))byPair.set(pair,[]);
  byPair.get(pair).push(rule);
 }
 for(let i=0;i<nodes.length;i++)for(let j=i+1;j<nodes.length;j++){
  const a=nodes[i],b=nodes[j],list=byPair.get([a.type,b.type].sort().join(':'));
  if(!list)continue;
  const d2=(a.x-b.x)**2+(a.y-b.y)**2;
  for(const rule of list){
   if(d2>rule.radius*rule.radius+1e-10)continue;
   if(edges.length>=MAX_EDGES)return {status:'limited',maxEdges:MAX_EDGES};
   const edge={a:i,b:j,rule:rule.id};
   edges.push(edge);adjacency[i].push({to:j,rule:rule.id});adjacency[j].push({to:i,rule:rule.id});
   join(i,j);
  }
 }
 const groups=new Map();
 for(let i=0;i<nodes.length;i++){
  const representative=find(i);
  if(!groups.has(representative))groups.set(representative,[]);
  groups.get(representative).push(i);
 }
 const components=[...groups.values()].sort((a,b)=>a[0]-b[0]).map((members,i)=>({
  id:i,size:members.length,members
 }));
 const componentByNode=new Array(nodes.length);
 for(const item of components)for(const index of item.members)componentByNode[index]=item.id;
 const enriched=nodes.map((node,index)=>({...node,index,component:componentByNode[index]}));
 return {
  status:nodes.length?'ok':'empty',source:'geometric-rule-compatible-pairs-only',
  generation:world.generation,budget:world.budget,
  nodes:enriched,edges,adjacency,components,rules,
  componentByNode,links:edges.length,isolated:components.filter(c=>c.size===1).length,
  largest:Math.max(0,...components.map(c=>c.size)),
  caveat:'links are local rule-compatible pairs, not saved discoveries, server events or verified player journeys'
 };
}
function route(graph,from,to){
 if(!graph||!['ok','empty'].includes(graph.status))return {status:'unavailable'};
 if(!Number.isSafeInteger(from)||!Number.isSafeInteger(to)||
   from<0||to<0||from>=graph.nodes.length||to>=graph.nodes.length)return {status:'invalid-selection'};
 if(from===to)return {status:'same',path:[from],edges:[],hops:0};
 if(graph.componentByNode[from]!==graph.componentByNode[to]){
  return {status:'disconnected',fromComponent:graph.componentByNode[from],toComponent:graph.componentByNode[to]};
 }
 const visited=new Set([from]),queue=[from],before=new Map();
 for(let k=0;k<queue.length;k++){
  const node=queue[k];if(node===to)break;
  for(const edge of graph.adjacency[node]){
   if(visited.has(edge.to))continue;
   visited.add(edge.to);before.set(edge.to,{from:node,rule:edge.rule});
   queue.push(edge.to);
  }
 }
 if(!visited.has(to))return {status:'unavailable'};
 const path=[to],edges=[];
 while(path[0]!==from){
  const next=path[0],prev=before.get(next);
  edges.unshift({a:prev.from,b:next,rule:prev.rule});
  path.unshift(prev.from);
 }
 return {status:'connected',path,edges,hops:edges.length,source:graph.source};
}
function inside(x,y){return x>MIN_X&&x<MAX_X&&y>MIN_Y&&y<MAX_Y}
function compatibleRules(nodeType,tool,rules){
 return rules.filter(r=>(r.first===nodeType&&r.second===tool)||
                       (r.first===tool&&r.second===nodeType));
}
function suggestBridge(graph,from,to){
 const result=route(graph,from,to);
 if(result.status!=='disconnected')return {status:result.status==='connected'?'already-connected':result.status};
 if(!validBudget(graph.budget))return {status:'unavailable'};
 if(graph.budget===0)return {status:'budget-exhausted'};
 const groupA=graph.components[result.fromComponent]?.members||[];
 const groupB=graph.components[result.toComponent]?.members||[];
 const limited=groupA.length>MAX_BRIDGE_ANCHORS||groupB.length>MAX_BRIDGE_ANCHORS;
 const aIds=groupA.slice(0,MAX_BRIDGE_ANCHORS),bIds=groupB.slice(0,MAX_BRIDGE_ANCHORS);
 let best=null;
 for(const i of aIds)for(const j of bIds){
  const a=graph.nodes[i],b=graph.nodes[j];
  const d=Math.hypot(a.x-b.x,a.y-b.y);
  for(const tool of TYPES){
   const ra=compatibleRules(a.type,tool,graph.rules);
   const rb=compatibleRules(b.type,tool,graph.rules);
   for(const ruleA of ra)for(const ruleB of rb){
    // Leave a margin so rounding and pointer positioning do not convert a
    // numerically exact tangent into a failed Legacy-rule interaction.
    if(d>ruleA.radius+ruleB.radius-0.4)continue;
    const t=ruleA.radius/(ruleA.radius+ruleB.radius);
    const x=rounded(a.x+(b.x-a.x)*t),y=rounded(a.y+(b.y-a.y)*t);
    if(!inside(x,y))continue;
    if(Math.hypot(x-a.x,y-a.y)>ruleA.radius-.1||
       Math.hypot(x-b.x,y-b.y)>ruleB.radius-.1)continue;
    const candidate={tool,x,y,a:i,b:j,via:[ruleA.id,ruleB.id],distance:rounded(d),
      fromComponent:result.fromComponent,toComponent:result.toComponent};
    if(!best||candidate.distance<best.distance||
       (candidate.distance===best.distance&&TYPES.indexOf(tool)<TYPES.indexOf(best.tool))){
      best=candidate;
    }
   }
  }
 }
 if(!best)return {status:'not-found',limited,inspected:[aIds.length,bIds.length]};
 // The suggestion is only a feasible point for two rule-compatible pairs.
 // Player still has to choose the tool and click the island. Budget, server
 // permissions and competing objects must be checked by the real game.
 return {status:'suggested',...best,source:'hypothetical-only',limited,
  caveat:'not a placed object, completed path, server action or paid entitlement'};
}
const api=Object.freeze({analyze,route,suggestBridge,validObject,
 types:TYPES,maxObjects:MAX_OBJECTS,maxEdges:MAX_EDGES,maxBridgeAnchors:MAX_BRIDGE_ANCHORS});
root.InheritLegacyNetwork=api;
if(typeof module!=='undefined'&&module.exports)module.exports=api;
})(typeof window==='object'?window:globalThis);
