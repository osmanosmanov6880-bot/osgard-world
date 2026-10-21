/* INHERIT R11 — a read-only network of real island traces and optional bridge preview.
   Only the original game buttons and a later player click may mutate the world. */
(()=>{
'use strict';
const d=document,core=window.InheritLegacyNetwork,legacy=window.InheritLegacyEngine,
 game=window.InheritGame,island=d.querySelector('#island'),tools=d.querySelector('.tools');
if(!core||!legacy||!game?.snapshot||!island||!tools)return;
const translations={
 ru:{
 trigger:'✧ Сеть наследия',title:'Сеть наследия',eyebrow:'КАК СЛЕДЫ СОЕДИНЯЮТСЯ',
 intro:'Исследуй цепочки из настоящих предметов острова. Линии показывают пары, подходящие под правила сочетаний, а не подтверждённые сервером события или путешествия.',
 statsObjects:'Следов',statsPairs:'Совместимых пар',statsGroups:'Раздельных групп',statsLargest:'Крупнейшая группа',
 from:'От следа',to:'К следу',select:'Выбери два разных следа',empty:'На острове пока нет следов. Сделай обычный ход, чтобы построить первую связь.',
 one:'Нужно хотя бы два настоящих следа.',limited:'Слишком много совместимых пар или предметов для надёжного быстрого расчёта. Мир и сохранения не менялись.',
 unavailable:'Некорректные данные острова или правила. Схема не строится.',same:'Выбери второй след, отличный от первого.',
 connected:'Эти следы соединены цепочкой из {n} совместимых пар.',disconnected:'Между выбранными группами нет цепочки из совместимых пар.',
 nodes:'Узлы цепочки',open:'Просмотр цепочки',suggest:'Попробуй соединить группы одним новым следом',
 bridge:'Один возможный мостик: {tool} в точке {x} / {y}. Для проверки потребуется настоящий игровой ход.',
 noBridge:'В проверенных местах мостик за один ход не найден. Понадобится больше шагов или другой выбор.',
 budget:'Бюджет текущего поколения исчерпан. Передай поколение, чтобы продолжить.',replay:'Открыто прошлое поколение. Сначала вернись к текущему миру.',
 choose:'Выбрать инструмент и показать точку',updated:'Мир изменился. Расчёт обновлён — проверь предложенный мостик.',
 unavailableTool:'Этот инструмент сейчас недоступен. Сохранение не изменено.',
 armed:'Инструмент выбран. Нажми на остров возле золотой отметки для настоящего хода.',
 preview:'Золотая отметка — лишь прогноз. Нажатие здесь не делает ход автоматически; права сервера в аккаунтном режиме сохраняются.',
 source:'Схема строится из сохранённых координат и правил сочетаемости. Она может показывать больше совместимых пар, чем «Наследие» с его выбором ближайших соседей. Данные игрока, авторы и перемещения не выводятся.',
 hide:'На схеме показана часть объектов, но счётчики вычислены по всем проверенным предметам.',close:'Закрыть сеть',
 types:{tree:'Дерево',stone:'Камень',light:'Фонарь',path:'Тропа',flower:'Цветы',arch:'Арка',chime:'Колокольчик',moss:'Мох',cairn:'Насыпь',marker:'Указатель'},
 rules:{grove:'Тихая роща',waylight:'Освещённая тропа',garden:'Сад ветра',monument:'Арка памяти',waymark:'Дорога открытий',landmark:'Береговой маяк'}
 },
 en:{
 trigger:'✧ Legacy network',title:'Legacy network',eyebrow:'HOW REAL TRACES CONNECT',
 intro:'Explore chains among real saved objects. Lines represent geometrically rule-compatible pairs, not confirmed server events or player journeys.',
 statsObjects:'Traces',statsPairs:'Compatible pairs',statsGroups:'Separate groups',statsLargest:'Largest group',
 from:'From trace',to:'To trace',select:'Choose two different saved traces',empty:'There are no traces yet. Make a real move to start a connection.',
 one:'At least two real traces are required.',limited:'Too many objects or compatible pairs for a reliable quick calculation. No saves were changed.',
 unavailable:'World objects or rules could not be validated. No network is displayed.',same:'Choose a different second trace.',
 connected:'These traces share a chain of {n} compatible pairs.',disconnected:'There is no compatible chain between these two groups.',
 nodes:'Nodes in the chain',open:'View chain',suggest:'Try joining groups with one new trace',
 bridge:'One possible bridge: {tool} near {x} / {y}. A real game move is still required.',
 noBridge:'No one-move bridge found in the inspected area. More steps or a different choice may help.',
 budget:'Generation budget exhausted. Pass the generation before placing another trace.',replay:'You are viewing past history. Return to the current world to place a new trace.',
 choose:'Choose tool and mark a location',updated:'World changed. The preview was recalculated; please check the new bridge.',
 unavailableTool:'The required tool is not available. No save changed.',
 armed:'Tool selected. Click the island near the golden marker to make a real move.',
 preview:'The golden marker is a hypothetical preview, not a placed trace. Account-world rights and server validation still apply.',
 source:'The graph uses saved coordinates and compatibility rules. It can show more candidate pairs than the Legacy journal, which chooses nearest neighbours. No verified authors or actual journeys are inferred.',
 hide:'Only some nodes are drawn; totals include all validated traces.',close:'Close network',
 types:{tree:'Tree',stone:'Stone',light:'Lantern',path:'Path',flower:'Flowers',arch:'Arch',chime:'Chime',moss:'Moss',cairn:'Cairn',marker:'Marker'},
 rules:{grove:'Quiet grove',waylight:'Lantern path',garden:'Wind garden',monument:'Memory arch',waymark:'Discovery trail',landmark:'Shore beacon'}
 },
 zh:{
 trigger:'✧ 传承网络',title:'传承网络',eyebrow:'真实痕迹如何相连',
 intro:'探索真实保存的物件之间的链条。连线只代表符合规则的几何配对，不是服务器事件或玩家旅行的证明。',
 statsObjects:'痕迹',statsPairs:'兼容组合',statsGroups:'独立组',statsLargest:'最大组',
 from:'起点痕迹',to:'终点痕迹',select:'请选择两个不同的痕迹',empty:'岛上还没有痕迹。先完成真实游戏操作。',
 one:'需要至少两个真实痕迹。',limited:'物件或相容组合太多，无法准确快速计算。存档没有修改。',
 unavailable:'岛屿数据或规则无效，无法绘制网络。',same:'请选择另一道终点痕迹。',
 connected:'这两道痕迹通过 {n} 个兼容组合相连。',disconnected:'所选两组之间没有兼容的连接。',
 nodes:'链条节点',open:'查看链条',suggest:'试着用一道新痕迹连接两组',
 bridge:'一种可能的连接方式：在 {x} / {y} 放置{tool}。仍需执行真正的游戏操作。',
 noBridge:'在已检查区域没有找到一步连接方案。可能需要多步或其他选择。',
 budget:'本代行动额度已用完。请先传承世代。',replay:'正在查看过去。请先返回当前世界。',
 choose:'选择工具并标记位置',updated:'世界已改变。已经重新计算建议位置。',
 unavailableTool:'当前没有相应工具。存档未改变。',
 armed:'工具已选择。点击岛屿上金色标记附近进行真正的放置。',
 preview:'金色标记只是预测，并未放置物件。账号世界仍受服务器权限控制。',
 source:'网络来自保存的坐标与组合规则，可能比只选择最近邻的「传承」日志显示更多兼容配对。不会推断玩家身份或真实旅行。',
 hide:'示意图只显示部分节点，统计仍覆盖所有验证过的痕迹。',close:'关闭网络',
 types:{tree:'树木',stone:'石头',light:'灯笼',path:'道路',flower:'花朵',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'},
 rules:{grove:'宁静树林',waylight:'灯光小径',garden:'风之花园',monument:'记忆拱门',waymark:'发现之路',landmark:'海岸灯标'}
 }
};
const lang=()=>{const code=window.InheritUI?.getLanguage?.();return translations[code]?code:'ru'};
const tr=()=>translations[lang()];
const format=(source,values={})=>String(source).replace(/\{(\w+)\}/g,(_,k)=>String(values[k]??''));
const el=(tag,cls,value)=>{const n=d.createElement(tag);if(cls)n.className=cls;if(value!==undefined)n.textContent=String(value);return n};
const NS='http://www.w3.org/2000/svg';
function shape(tag,attrs={}){
 const n=d.createElementNS(NS,tag);for(const [k,v] of Object.entries(attrs))n.setAttribute(k,String(v));return n;
}
const trigger=el('button','inherit-network-trigger');trigger.type='button';trigger.dataset.noTranslate='';
tools.appendChild(trigger);
const dialog=el('dialog','inherit-network-dialog');dialog.dataset.noTranslate='';dialog.setAttribute('aria-labelledby','inherit-network-title');
const heading=el('div','inherit-network-heading'),words=el('div');
const eyebrow=el('p','inherit-network-eyebrow'),title=el('h2','inherit-network-title');title.id='inherit-network-title';
const close=el('button','inherit-network-close','×');close.type='button';
words.append(eyebrow,title);heading.append(words,close);
const intro=el('p','inherit-network-intro'),stats=el('div','inherit-network-stats');
const controls=el('div','inherit-network-controls'),fromLabel=el('label'),toLabel=el('label');
const fromCaption=el('span'),toCaption=el('span'),from=el('select'),to=el('select');
from.name='inherit-network-start';to.name='inherit-network-end';
fromLabel.append(fromCaption,from);toLabel.append(toCaption,to);controls.append(fromLabel,toLabel);
const status=el('p','inherit-network-status');status.setAttribute('role','status');
const content=el('div','inherit-network-content'),visual=el('div','inherit-network-visual');
const svg=shape('svg',{viewBox:'0 0 100 100',preserveAspectRatio:'none',role:'img'});
svg.classList.add('inherit-network-svg');
visual.append(svg);
const mapNote=el('p','inherit-network-map-note'),chain=el('ol','inherit-network-chain');
const explanation=el('div','inherit-network-explanation'),routeLabel=el('h3','inherit-network-route-title');
explanation.append(routeLabel,status,chain);
content.append(visual,explanation);
const bridge=el('div','inherit-network-bridge'),bridgeTitle=el('h3'),bridgeText=el('p'),choose=el('button','inherit-network-choose');
choose.type='button';bridge.append(bridgeTitle,bridgeText,choose);
const source=el('p','inherit-network-source');
dialog.append(heading,intro,stats,controls,content,mapNote,bridge,source);
d.body.appendChild(dialog);
const ghost=el('span','inherit-network-ghost');ghost.hidden=true;ghost.setAttribute('aria-hidden','true');island.appendChild(ghost);
let graph=null,selectedA=0,selectedB=1,route=null,suggestion=null,worldSignature='',armed=false;
const snapshot=()=>game.snapshot();
const signature=world=>JSON.stringify({generation:world.generation,budget:world.budget,objects:world.objects});
function clearGhost(){armed=false;ghost.hidden=true;d.body.classList.remove('inherit-network-armed')}
function stat(value,label){
 const card=el('div','inherit-network-stat');
 card.append(el('strong','',value),el('small','',label));stats.appendChild(card);
}
function listOptions(){
 const c=tr(),items=graph.nodes.map(item=>{
  const option=el('option','',('#'+(item.index+1))+' · '+(c.types[item.type]||item.type)+' · '+item.x.toFixed(1)+' / '+item.y.toFixed(1));
  option.value=String(item.index);return option;
 });
 from.replaceChildren(...items.map(o=>o.cloneNode(true)));
 to.replaceChildren(...items);
 from.disabled=to.disabled=graph.nodes.length<2;
 if(graph.nodes.length){
  selectedA=Math.min(Math.max(0,selectedA),graph.nodes.length-1);
  selectedB=Math.min(Math.max(0,selectedB),graph.nodes.length-1);
  from.value=String(selectedA);to.value=String(selectedB);
 }
}
function drawNetwork(){
 svg.replaceChildren();if(!graph?.nodes?.length)return;
 const highlight=new Set(route?.status==='connected'?route.path:[selectedA,selectedB]);
 const pathEdges=new Set((route?.edges||[]).map(e=>Math.min(e.a,e.b)+':'+Math.max(e.a,e.b)));
 const selectedComp=new Set([graph.componentByNode[selectedA],graph.componentByNode[selectedB]]);
 const available=[...highlight,...graph.nodes.map(n=>n.index)].filter((id,i,a)=>a.indexOf(id)===i);
 const visible=new Set(available.slice(0,160));
 const edges=graph.edges.filter(e=>visible.has(e.a)&&visible.has(e.b));
 const prioritized=[...edges.filter(e=>pathEdges.has(e.a+':'+e.b)),
  ...edges.filter(e=>!pathEdges.has(e.a+':'+e.b))].slice(0,220);
 for(const edge of prioritized){
  const a=graph.nodes[edge.a],b=graph.nodes[edge.b];
  const line=shape('line',{x1:a.x,y1:a.y,x2:b.x,y2:b.y});
  line.setAttribute('class','inherit-network-edge'+(pathEdges.has(edge.a+':'+edge.b)?' inherit-network-edge--route':''));
  svg.append(line);
 }
 for(const id of visible){
  const n=graph.nodes[id],focus=highlight.has(id);
  const linked=selectedComp.has(n.component);
  const dot=shape('circle',{cx:n.x,cy:n.y,r:focus?1.7:1.05});
  dot.setAttribute('class','inherit-network-node'+(focus?' inherit-network-node--focus':linked?' inherit-network-node--group':''));
  dot.setAttribute('data-network-index',String(id));svg.append(dot);
 }
 mapNote.textContent=graph.nodes.length>visible.size||graph.edges.length>prioritized.length?tr().hide:'';
 svg.setAttribute('aria-label',tr().statsObjects+': '+graph.nodes.length+', '+tr().statsPairs+': '+graph.links+'. '+status.textContent);
}
function showRoute(){
 const c=tr();chain.replaceChildren();
 if(!graph||!['ok','empty'].includes(graph.status))return;
 route=core.route(graph,selectedA,selectedB);
 suggestion=null;choose.disabled=true;bridge.hidden=true;
 if(graph.nodes.length<2){
  status.textContent=graph.nodes.length?c.one:c.empty;drawNetwork();return;
 }
 if(route.status==='same'){status.textContent=c.same;drawNetwork();return}
 if(route.status==='connected'){
  status.textContent=format(c.connected,{n:route.hops});
  const shown=route.path.slice(0,16);
  for(const index of shown){
   const n=graph.nodes[index],text=(c.types[n.type]||n.type)+' · '+n.x.toFixed(1)+' / '+n.y.toFixed(1);
   chain.append(el('li','',text));
  }
  if(route.path.length>shown.length)chain.append(el('li','',c.hide));
 }else if(route.status==='disconnected'){
  status.textContent=c.disconnected;
  suggestion=core.suggestBridge(graph,selectedA,selectedB);
  bridge.hidden=false;bridgeTitle.textContent=c.suggest;
  if(d.body.classList.contains('replay-mode')){
   bridgeText.textContent=c.replay;choose.disabled=true;
  }else if(suggestion.status==='suggested'){
   bridgeText.textContent=format(c.bridge,{tool:c.types[suggestion.tool],x:suggestion.x.toFixed(1),y:suggestion.y.toFixed(1)});
   choose.disabled=false;choose.textContent=c.choose;
   ghost.hidden=false;ghost.style.left=suggestion.x+'%';ghost.style.top=suggestion.y+'%';
  }else{
   bridgeText.textContent=suggestion.status==='budget-exhausted'?c.budget:c.noBridge;
   choose.disabled=true;
  }
 }else status.textContent=c.select;
 drawNetwork();
}
function render(){
 const c=tr();trigger.textContent=c.trigger;title.textContent=c.title;eyebrow.textContent=c.eyebrow;
 intro.textContent=c.intro;fromCaption.textContent=c.from;toCaption.textContent=c.to;
 routeLabel.textContent=c.open;source.textContent=c.source;close.setAttribute('aria-label',c.close);
 graph=core.analyze(snapshot(),legacy);worldSignature=signature(snapshot());
 stats.replaceChildren();chain.replaceChildren();bridge.hidden=true;ghost.hidden=true;
 if(!['ok','empty'].includes(graph.status)){
  status.textContent=graph.status==='limited'?c.limited:c.unavailable;
  controls.hidden=true;content.hidden=true;mapNote.textContent='';return;
 }
 controls.hidden=false;content.hidden=false;
 stat(graph.nodes.length,c.statsObjects);stat(graph.links,c.statsPairs);
 stat(graph.components.length,c.statsGroups);stat(graph.largest,c.statsLargest);
 listOptions();showRoute();
}
function update(){
 selectedA=Number(from.value);selectedB=Number(to.value);
 clearGhost();showRoute();
}
from.addEventListener('change',update);to.addEventListener('change',update);
function openFrom(index=0){
 const current=core.analyze(snapshot(),legacy);
 selectedA=Number.isSafeInteger(index)&&index>=0&&index<(current.nodes?.length||0)?index:0;
 selectedB=current.nodes?.length>1?(selectedA===0?1:0):0;
 clearGhost();render();if(!dialog.open)dialog.showModal();
}
trigger.addEventListener('click',()=>openFrom());
close.addEventListener('click',()=>dialog.close());
dialog.addEventListener('click',event=>{if(event.target===dialog)dialog.close()});
dialog.addEventListener('close',()=>{if(!armed)clearGhost()});
function revealWorld(){
 if(!armed||ghost.hidden||!window.matchMedia?.('(max-width:740px)').matches)return;
 const stage=d.querySelector('#world');if(!stage)return;
 const marker=ghost.getBoundingClientRect(),x=marker.left+marker.width/2,y=marker.top+marker.height/2;
 const above=x>=0&&x<innerWidth&&y>=0&&y<innerHeight?d.elementFromPoint(x,y):null;
 if(!above?.closest('#world')||above.closest('button,.dock,[data-memory]'))
  stage.scrollIntoView({block:'start',inline:'nearest',behavior:'auto'});
}
choose.addEventListener('click',()=>{
 if(!suggestion||suggestion.status!=='suggested'||d.body.classList.contains('replay-mode'))return;
 const newWorld=snapshot();
 if(signature(newWorld)!==worldSignature){
  clearGhost();render();status.textContent=tr().updated;return;
 }
 const button=d.querySelector('.tools [data-tool="'+suggestion.tool+'"]')||
  d.querySelector('.catalog [data-extra="'+suggestion.tool+'"]');
 if(!button||button.disabled){status.textContent=tr().unavailableTool;return}
 button.click();armed=true;d.body.classList.add('inherit-network-armed');dialog.close();
 d.querySelector('#world')?.focus?.({preventScroll:true});
 requestAnimationFrame(revealWorld);
 game.notify?.(tr().armed);
});
const objects=d.querySelector('#objects'),gen=d.querySelector('#gen');
let queued=false;
function schedule(){
 if(queued)return;queued=true;
 queueMicrotask(()=>{queued=false;clearGhost();if(dialog.open)render()});
}
const observer=new MutationObserver(schedule);
if(objects)observer.observe(objects,{childList:true});
if(gen)observer.observe(gen,{childList:true,subtree:true,characterData:true});
window.InheritLegacyNetworkUI=Object.freeze({
 open:()=>openFrom(),openFrom,refresh:()=>{if(dialog.open)render();else trigger.textContent=tr().trigger},
 getGraph:()=>core.analyze(snapshot(),legacy),getRoute:()=>core.route(core.analyze(snapshot(),legacy),selectedA,selectedB),
 getSuggestion:()=>suggestion,isArmed:()=>armed
});
trigger.textContent=tr().trigger;
})();
