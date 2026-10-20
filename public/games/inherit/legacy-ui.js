/* INHERIT Legacy Journal. Read-only consequences drawn from current saved traces.
   Does not alter generation actions, account drafts, payment flows or server API. */
(()=>{
'use strict';
const doc=document,engine=window.InheritLegacyEngine;
if(!engine||!window.InheritGame||!doc.querySelector('#objects'))return;
const i18n={
 ru:{button:'✧ Наследие',title:'Наследие острова',subtitle:'Твои решения меняют характер мира.',intro:'Сочетай следы рядом друг с другом — так появляются новые уголки острова, которые увидят следующие поколения.',traces:'Следов',links:'Связей',generation:'Поколение',verified:'Древних следов',effects:'Что ожило на острове',none:'Пока связей нет. Оставь два дополняющих друг друга следа рядом.',hint:'Следующее открытие',first:'Попробуй посадить дерево, а рядом оставить мох.',near:'Рядом с {near} добавь {place}.',close:'Попробуй расположить дополняющие следы ближе друг к другу.',memory:'Память поколений',noAge:'Возраст следов можно подтвердить, только если сохранились снимки прошлых поколений.',age:'Сохраняется уже {n} поколений',since:'Впервые видно в снимке поколения {n}',unknown:'Давность пока неизвестна',new:'Только появилось',growing:'Развивается',heritage:'Стало наследием',limit:'Большой или плотный архив: часть сочетаний и их подсветки может быть не показана. Данные не изменены.',source:'Это художественная интерпретация сохранённых объектов, а не подтверждение событий сервера. Действия и лимиты игры не меняются.',past:'Открыта история прошлого. Эффекты показаны для текущего сохранённого мира.',closeLabel:'Закрыть наследие',ruleNames:{grove:'Тихая роща',waylight:'Освещённая тропа',garden:'Сад ветра',monument:'Арка памяти',waymark:'Дорога открытий',landmark:'Береговой маяк'},ruleBody:{grove:'Мох прижился у дерева. Теперь у следующих хранителей есть тенистое место.',waylight:'Фонарь освещает тропу. Дорога стала заметнее.',garden:'Цветы и колокольчик создали место, куда хочется возвращаться.',monument:'Камень укрепляет арку. Она хранит память о строителях.',waymark:'Указатель рядом с тропой помогает найти дорогу.',landmark:'Каменная насыпь и свет превратились в ориентир для путешественников.'},tools:{tree:'деревом',stone:'камнем',light:'фонарём',path:'тропой',flower:'цветами',arch:'аркой',chime:'колокольчиком',moss:'мхом',cairn:'каменной насыпью',marker:'указателем'},places:{tree:'дерево',stone:'камень',light:'фонарь',path:'тропу',flower:'цветы',arch:'арку',chime:'колокольчик',moss:'мох',cairn:'каменную насыпь',marker:'указатель'}},
 en:{button:'✧ Legacy',title:'Island legacy',subtitle:'Your choices shape the world.',intro:'Place complementary traces near each other to create lasting places for future keepers.',traces:'Traces',links:'Connections',generation:'Generation',verified:'Old traces',effects:'What came to life',none:'No connections yet. Place two complementary traces near each other.',hint:'Next discovery',first:'Plant a tree, then place moss near it.',near:'Add {place} near {near}.',close:'Try bringing complementary traces closer together.',memory:'Memories across generations',noAge:'Trace ages can only be confirmed when previous generation snapshots exist.',age:'Preserved for {n} generations',since:'First visible in generation {n} snapshot',unknown:'Age not established',new:'Just appeared',growing:'Growing',heritage:'Became a legacy',limit:'Large or dense archive: some combinations and highlights may be omitted. Your data is unchanged.',source:'A creative interpretation of saved objects, not confirmation of server events. Gameplay limits and actions are unchanged.',past:'You are viewing the past. The legacy journal describes the current saved world.',closeLabel:'Close legacy journal',ruleNames:{grove:'Quiet grove',waylight:'Lantern path',garden:'Wind garden',monument:'Memory arch',waymark:'Trail of discovery',landmark:'Shore beacon'},ruleBody:{grove:'Moss grows by the tree, sheltering future keepers.',waylight:'A lantern makes the route easier to find.',garden:'Flowers and a chime create a place worth revisiting.',monument:'Stone supports the arch and recalls the builders.',waymark:'A marker beside the path guides arrivals.',landmark:'A cairn and a light form a landmark for travelers.'},tools:{tree:'a tree',stone:'a stone',light:'a lantern',path:'a path',flower:'flowers',arch:'an arch',chime:'a chime',moss:'moss',cairn:'a cairn',marker:'a marker'},places:{tree:'a tree',stone:'a stone',light:'a lantern',path:'a path',flower:'flowers',arch:'an arch',chime:'a chime',moss:'moss',cairn:'a cairn',marker:'a marker'}},
 zh:{button:'✧ 传承',title:'岛屿传承',subtitle:'你的选择改变世界。',intro:'将相互呼应的痕迹放在附近，创造可以传给下一代的地方。',traces:'痕迹',links:'联系',generation:'世代',verified:'古老痕迹',effects:'岛上诞生的新景象',none:'还没有联系。请在附近放置两种相互呼应的痕迹。',hint:'下一个发现',first:'先种一棵树，然后在旁边放上苔藓。',near:'在{near}旁边添加{place}。',close:'试着把互补的痕迹放得更近。',memory:'跨越世代的记忆',noAge:'只有保存了以前世代的快照，才能确认痕迹的年代。',age:'已保存 {n} 代',since:'最早出现在第 {n} 代的快照中',unknown:'年代尚未确定',new:'刚刚出现',growing:'正在成长',heritage:'成为传承',limit:'存档较大或对象密集：部分组合和光效可能未显示。数据未改变。',source:'这是基于存档对象的艺术性演绎，不代表服务器已确认相关事件。游戏操作和限制没有改变。',past:'你正在查看过去。传承日志展示的是当前存档世界的状态。',closeLabel:'关闭传承日志',ruleNames:{grove:'宁静树林',waylight:'灯光小径',garden:'风之花园',monument:'记忆拱门',waymark:'发现之路',landmark:'海岸灯标'},ruleBody:{grove:'树旁的苔藓生长起来，为后来的守护者提供阴凉。',waylight:'路边的灯让道路更加清晰。',garden:'鲜花与风铃创造了值得重访的地方。',monument:'石头支撑拱门，纪念建造者。',waymark:'路边的标记指引后来者。',landmark:'石堆和灯光成了旅行者的路标。'},tools:{tree:'树',stone:'石头',light:'灯',path:'道路',flower:'花',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'},places:{tree:'树',stone:'石头',light:'灯',path:'小径',flower:'花',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'}}
};
const locale=()=>{const id=window.InheritUI?.getLanguage?.();return i18n[id]?id:'ru'};
const tr=()=>i18n[locale()];
const format=(string,params={})=>String(string).replace(/\{(\w+)\}/g,(_m,key)=>String(params[key]??''));
const create=(tag,cls,text)=>{const el=doc.createElement(tag);if(cls)el.className=cls;if(text!==undefined)el.textContent=text;return el};
const island=doc.querySelector('#island'),stage=doc.querySelector('#world');
if(!island||!stage)return;
const layer=create('div','inherit-legacy-aura-layer');layer.setAttribute('aria-hidden','true');layer.dataset.noTranslate='';island.appendChild(layer);
const trigger=create('button','inherit-legacy-trigger');trigger.type='button';trigger.dataset.noTranslate='';stage.appendChild(trigger);
const pulse=create('span','inherit-legacy-pulse');pulse.dataset.noTranslate='';pulse.setAttribute('aria-hidden','true');doc.querySelector('#world').appendChild(pulse);
const panel=create('dialog','inherit-legacy-dialog');panel.dataset.noTranslate='';panel.setAttribute('aria-labelledby','inherit-legacy-title');
const close=create('button','inherit-legacy-close','×');close.type='button';panel.appendChild(close);
const eyebrow=create('span','inherit-legacy-eyebrow','INHERIT / LEGACY');panel.appendChild(eyebrow);
const title=create('h2','inherit-legacy-title');title.id='inherit-legacy-title';panel.appendChild(title);
const subtitle=create('p','inherit-legacy-subtitle');panel.appendChild(subtitle);
const stats=create('div','inherit-legacy-stats');panel.appendChild(stats);
const intro=create('p','inherit-legacy-intro');panel.appendChild(intro);
const sectionTitle=create('h3','inherit-legacy-section-title');panel.appendChild(sectionTitle);
const list=create('ul','inherit-legacy-list');panel.appendChild(list);
const suggestionTitle=create('h3','inherit-legacy-section-title');panel.appendChild(suggestionTitle);
const suggestion=create('p','inherit-legacy-suggestion');panel.appendChild(suggestion);
const memoryTitle=create('h3','inherit-legacy-section-title');panel.appendChild(memoryTitle);
const memories=create('ul','inherit-legacy-memories');panel.appendChild(memories);
const note=create('p','inherit-legacy-disclosure');panel.appendChild(note);
doc.body.appendChild(panel);
const memoryNames={
 ru:{tree:'Дерево',stone:'Камень',light:'Фонарь',path:'Тропа',flower:'Цветы',arch:'Арка',chime:'Колокольчик',moss:'Мох',cairn:'Каменная насыпь',marker:'Указатель'},
 en:{tree:'Tree',stone:'Stone',light:'Lantern',path:'Path',flower:'Flowers',arch:'Arch',chime:'Wind chime',moss:'Moss',cairn:'Cairn',marker:'Marker'},
 zh:{tree:'树木',stone:'石头',light:'灯笼',path:'道路',flower:'花朵',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'}
};
function duration(n){
 const c=tr();
 if(locale()!=='ru')return format(c.age,{n});
 const tens=n%100,ones=n%10;
 const suffix=tens>=11&&tens<=14?'поколений':ones===1?'поколение':ones>=2&&ones<=4?'поколения':'поколений';
 return 'Сохраняется уже '+n+' '+suffix;
}
const current=()=>window.InheritGame?.snapshot?.();
let model=engine.derive(current()),queued=false;
function addStat(value,title){const box=create('div','inherit-legacy-stat');box.appendChild(create('strong','',String(value)));box.appendChild(create('small','',title));stats.appendChild(box)}
function update(){
 model=engine.derive(current());const c=tr(),replay=doc.body.classList.contains('replay-mode');
 trigger.textContent=c.button+' · '+model.total;
 trigger.setAttribute('aria-label',c.button+' · '+model.total);
 pulse.textContent=replay?c.past:(model.total?c.subtitle+' · '+model.total+' '+c.links:c.first);
 title.textContent=c.title;subtitle.textContent=c.subtitle;
 stats.replaceChildren();addStat(model.objects,c.traces);addStat(model.total,c.links);addStat(model.generation,c.generation);addStat(model.memoryCount,c.verified);
 intro.textContent=c.intro;sectionTitle.textContent=c.effects;list.replaceChildren();
 for(const rule of engine.rules){
   const count=model.totals[rule.id];if(!count)continue;
   const item=create('li','inherit-legacy-story');const heading=create('strong','',c.ruleNames[rule.id]+' · '+count);
   const body=create('p','',c.ruleBody[rule.id]);item.append(heading,body);
   const ages=model.effects.filter(effect=>effect.id===rule.id&&effect.age!==null).map(effect=>effect.age);
   if(ages.length){const oldest=Math.max(...ages);const stage=oldest>=4?c.heritage:oldest>=1?c.growing:c.new;item.appendChild(create('small','',stage+' · '+duration(oldest)));}
   list.appendChild(item);
 }
 if(!list.children.length)list.appendChild(create('li','inherit-legacy-empty',c.none));
 suggestionTitle.textContent=c.hint;
 if(model.available.length){const next=model.available[0];suggestion.textContent=format(c.near,{near:c.tools[next.near],place:c.places[next.place]})}
 else if(!model.objects)suggestion.textContent=c.first;
 else suggestion.textContent=c.close;
 memoryTitle.textContent=c.memory;memories.replaceChildren();
 if(model.memory.length){for(const mark of model.memory){const label=memoryNames[locale()][mark.type]||mark.type;memories.appendChild(create('li','',label+(mark.count>1?' ×'+mark.count:'')+' · '+format(c.since,{n:mark.since})+' · '+duration(mark.age)));}}
 else memories.appendChild(create('li','',c.noAge));
 note.textContent=c.source+(replay?' '+c.past:'')+(model.limited?' '+c.limit:'');
 close.setAttribute('aria-label',c.closeLabel);
 layer.hidden=replay;layer.replaceChildren();
 if(!replay){for(const effect of model.effects.slice(0,18)){
   const halo=create('span','inherit-legacy-aura inherit-legacy-aura--'+effect.id+' inherit-legacy-aura--'+effect.stage);
   halo.style.left=effect.x+'%';halo.style.top=effect.y+'%';layer.appendChild(halo);
 }}
}
function schedule(){if(queued)return;queued=true;queueMicrotask(()=>{queued=false;update()})}
trigger.addEventListener('click',()=>{update();if(typeof panel.showModal==='function')panel.showModal()});
close.addEventListener('click',()=>panel.close());
const objects=doc.querySelector('#objects'),gen=doc.querySelector('#gen');
const observer=new MutationObserver(schedule);observer.observe(objects,{childList:true});if(gen)observer.observe(gen,{childList:true,characterData:true,subtree:true});
window.InheritLegacyUI=Object.freeze({refresh:schedule,getState:()=>engine.derive(current())});
update();
})();
