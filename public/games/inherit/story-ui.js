/* INHERIT — Chapter Journal. Uses live saved state and existing trace controls only.
   A goal is only completed by a real unsubmitted trace, never by a decorative preview. */
(()=>{
'use strict';
const doc=document,engine=window.InheritStoryEngine;
const dialog=doc.querySelector('.inherit-legacy-dialog');
const introduction=dialog?.querySelector('.inherit-legacy-intro');
const objects=doc.querySelector('#objects');
if(!engine||!dialog||!introduction||!objects||!window.InheritGame)return;
const copy={
 ru:{
  chapter:'Глава поколения',progress:'Выполнено',of:'из',intro:'Каждое поколение создаёт свою главу. Задания добровольные: следы остаются в сохранённом мире, даже если глава не закончена.',
  next:'Выбрать',done:'Выполнено',hint:'Подсказка',pair:'Создай указанное сочетание рядом с уже оставленными следами.',
  actions:'Цели поколения',unlock:'История меняется',end:'Глава завершена! Все три цели выполнены настоящими следами. Можно продолжить или передать поколение.',
  more:'Оставь след на острове, чтобы продолжить эту главу.',readOnly:'Изменение мира сейчас недоступно — цели показаны только для просмотра.',
  mismatch:'Не удалось однозначно сопоставить черновик с объектами мира. Новые достижения не засчитываются; сохранение не изменено.',
  disclaimer:'Сюжет и настроение острова вычисляются из существующих следов. Это игровая интерпретация, а не новые серверные события.',
  themes:{quiet:['Тихое начало','Мир ещё ждёт первых следов.'],nature:['Мир зелени','Растения, цветы и рощи делают остров убежищем.'],routes:['Мир дорог','Огни и тропы помогают следующему хранителю найти путь.'],memory:['Мир памяти','Камни и арки сохраняют историю строительства.']},
  chapters:{shore:['После прилива','Оставь укрытие и путь тем, кто придёт после тебя.'],signal:['Огонь на берегу','Сделай так, чтобы следующий хранитель нашёл остров.'],haven:['Остров для жизни','Преврати пустынный берег в место, куда хочется вернуться.'],memory:['Голоса камней','Оставь след, который смогут прочесть через поколения.']},
  goals:{shelter:['Оставь живой след','Посади дерево, цветы или добавь мох.'],route:['Обозначь дорогу','Проложи путь или поставь указатель.'],meeting:['Соедини два следа','Создай любое новое сочетание объектов рядом друг с другом.'],
   flame:['Дай сигнал','Поставь фонарь или колокольчик.'],guidance:['Направь путешественника','Добавь тропу или указатель.'],beacon:['Создай световой ориентир','Соедини тропу с фонарём, тропу с указателем или насыпь с фонарём.'],
   roots:['Пусти корни','Добавь дерево или мох.'],color:['Принеси жизнь','Посади цветы или поставь колокольчик.'],refuge:['Создай укрытие','Соедини дерево с мхом или цветы с колокольчиком.'],
   foundation:['Оставь камень памяти','Поставь камень или арку.'],waystone:['Сохрани ориентир','Поставь каменную насыпь или указатель.'],monument:['Укрепи наследие','Соедини арку с камнем или насыпь с фонарём.']},
  tools:{tree:'дерево',stone:'камень',light:'фонарь',path:'тропу',flower:'цветы',arch:'арку',chime:'колокольчик',moss:'мох',cairn:'насыпь',marker:'указатель'}
 },
 en:{
  chapter:'Generation chapter',progress:'Completed',of:'of',intro:'Every generation tells its own story. Objectives are optional; your placed traces persist whether or not you complete a chapter.',
  next:'Choose',done:'Completed',hint:'Hint',pair:'Make the combination near existing traces.',
  actions:'Generation objectives',unlock:'The world responds',end:'Chapter complete! Three objectives were fulfilled by real traces. Keep building or pass this generation on.',
  more:'Leave a trace on the island to continue this chapter.',readOnly:'World editing is unavailable right now. Objectives are shown for reference.',
  mismatch:'The draft cannot be safely matched to the saved objects. No objectives are awarded; the save remains unchanged.',
  disclaimer:'The story and island mood are derived from saved traces. They are game interpretations, not new server events.',
  themes:{quiet:['A quiet beginning','The world awaits its first traces.'],nature:['World of green','Plants and groves make this island a refuge.'],routes:['World of paths','Lights and trails help the next keeper find the way.'],memory:['World of memory','Stone and arches preserve the story of builders.']},
  chapters:{shore:['After the tide','Leave shelter and a path for those who follow.'],signal:['Fire on the shore','Make sure the next keeper can find this island.'],haven:['An island for life','Turn a quiet shore into somewhere worth returning to.'],memory:['Voices in stone','Leave a trace that survives generations.']},
  goals:{shelter:['Leave a living trace','Plant a tree, flowers or moss.'],route:['Show the way','Build a path or place a marker.'],meeting:['Connect two traces','Make any new nearby combination of objects.'],
   flame:['Send a signal','Place a lantern or wind chime.'],guidance:['Guide the traveler','Add a path or a marker.'],beacon:['Create a beacon','Combine path and light, marker and path, or cairn and light.'],
   roots:['Put down roots','Place a tree or moss.'],color:['Bring life','Plant flowers or place a chime.'],refuge:['Create a refuge','Join tree and moss or flowers and a chime.'],
   foundation:['Leave a memory stone','Place a stone or arch.'],waystone:['Preserve a landmark','Add a cairn or a marker.'],monument:['Strengthen the legacy','Combine arch and stone or cairn and light.']},
  tools:{tree:'tree',stone:'stone',light:'lantern',path:'path',flower:'flowers',arch:'arch',chime:'chime',moss:'moss',cairn:'cairn',marker:'marker'}
 },
 zh:{
  chapter:'世代章节',progress:'已完成',of:'共',intro:'每个世代都有自己的故事。目标是自愿的：即使未完成章节，你放置的痕迹也会保留。',
  next:'选择',done:'已完成',hint:'提示',pair:'在已有痕迹附近创建组合。',
  actions:'本代目标',unlock:'世界正在回应',end:'章节完成！三个目标都由真实放置的痕迹完成。继续建设，或传承给下一代。',
  more:'在岛上留下痕迹，继续本章。',readOnly:'目前无法编辑世界，目标仅供查看。',
  mismatch:'无法安全匹配草稿与世界物件。不会授予目标进度，存档保持不变。',
  disclaimer:'故事与岛屿风格根据保存的痕迹推算。这是游戏演绎，并非新的服务器事件。',
  themes:{quiet:['宁静开端','世界正等待第一道痕迹。'],nature:['绿色世界','植物和树林让小岛成为避风港。'],routes:['道路世界','灯光和小径帮助下一位守护者找到方向。'],memory:['记忆世界','石头和拱门保存建造者的故事。']},
  chapters:{shore:['潮汐之后','为后来的人留下庇护与道路。'],signal:['海岸之火','让下一位守护者能够找到这座岛。'],haven:['宜居之岛','把宁静的海岸变成值得重访的地方。'],memory:['石头的声音','留下能够跨越世代的痕迹。']},
  goals:{shelter:['留下生命','种树、种花或放置苔藓。'],route:['标记道路','建造小径或放置路标。'],meeting:['连接两道痕迹','让相互呼应的物件在附近形成新组合。'],
   flame:['发送信号','放置灯笼或风铃。'],guidance:['指引旅行者','添加小径或路标。'],beacon:['创建灯标','组合小径与灯、路标与小径，或石堆与灯。'],
   roots:['扎下根基','放置树木或苔藓。'],color:['带来生命','种花或放置风铃。'],refuge:['创建庇护','组合树木与苔藓，或花朵与风铃。'],
   foundation:['留下纪念之石','放置石头或拱门。'],waystone:['留下地标','添加石堆或路标。'],monument:['巩固传承','组合拱门与石头，或石堆与灯。']},
  tools:{tree:'树',stone:'石头',light:'灯',path:'道路',flower:'花',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'}
 }
};
const lang=()=>{const l=window.InheritUI?.getLanguage?.();return copy[l]?l:'ru'};
const t=()=>copy[lang()];
const create=(tag,cls,text)=>{const x=doc.createElement(tag);if(cls)x.className=cls;if(text!==undefined)x.textContent=text;return x};
const section=create('section','inherit-chapter-panel');section.dataset.noTranslate='';
section.setAttribute('aria-labelledby','inherit-chapter-title');
const eyebrow=create('span','inherit-chapter-eyebrow');section.appendChild(eyebrow);
const title=create('h3','inherit-chapter-title');title.id='inherit-chapter-title';section.appendChild(title);
const intro=create('p','inherit-chapter-lead');section.appendChild(intro);
const progressInfo=create('div','inherit-chapter-progress-info');section.appendChild(progressInfo);
const progress=create('progress','inherit-chapter-progress');progress.max=3;progress.value=0;section.appendChild(progress);
const goalHeading=create('h4','inherit-chapter-goals-heading');section.appendChild(goalHeading);
const goals=create('ol','inherit-chapter-goals');section.appendChild(goals);
const outcome=create('div','inherit-chapter-outcome');section.appendChild(outcome);
const caution=create('p','inherit-chapter-caution');section.appendChild(caution);
introduction.after(section);
let queued=false,current=null;
function permitted(){
 if(doc.body.classList.contains('replay-mode'))return false;
 if(doc.querySelector('#pass')?.disabled)return false;
 if(window.InheritGame?.accountMode?.()){
   const state=window.InheritAccount?.state?.();
   return !!state?.canEdit && !state?.busy && !state?.loading && !state?.pending?.length;
 }
 return true;
}
function choose(type){
 if(!permitted())return;
 const tool=doc.querySelector('.tools [data-tool="'+type+'"]')||doc.querySelector('.catalog [data-extra="'+type+'"]');
 if(!tool)return;
 tool.click();
 if(dialog.open)dialog.close();
 const world=doc.querySelector('#world');
 if(world){world.setAttribute('tabindex','-1');world.focus?.({preventScroll:true});}
}
function render(){
 const snapshot=window.InheritGame.snapshot();
 const state=engine.evaluate(snapshot),strings=t(), editable=permitted();
 current=state; doc.body.dataset.inheritMood=state.mood;
 eyebrow.textContent=strings.chapter+' · '+state.generation;
 title.textContent=strings.chapters[state.chapter][0];
 intro.textContent=strings.chapters[state.chapter][1]+' '+strings.intro;
 progress.value=state.done;
 progress.setAttribute('aria-label',strings.progress+' '+state.done+' '+strings.of+' '+state.goalCount);
 progressInfo.textContent=strings.progress+' '+state.done+' '+strings.of+' '+state.goalCount;
 goalHeading.textContent=strings.actions;
 goals.replaceChildren();
 for(const objective of state.objectives){
   const row=create('li','inherit-chapter-goal'+(objective.done?' inherit-chapter-goal--done':''));
   const marker=create('span','inherit-chapter-goal-mark',objective.done?'✓':'○');marker.setAttribute('aria-hidden','true');
   const body=create('div','inherit-chapter-goal-body');
   const h=create('strong','',strings.goals[objective.id][0]);
   const detail=create('p','',strings.goals[objective.id][1]);
   body.append(h,detail);row.append(marker,body);
   if(objective.done){
     row.appendChild(create('small','inherit-chapter-done',strings.done));
   } else if(objective.tool){
     const button=create('button','inherit-chapter-tool',strings.next+': '+strings.tools[objective.tool]);
     button.type='button';button.disabled=!editable;
     button.setAttribute('aria-label',strings.next+': '+strings.tools[objective.tool]);
     button.addEventListener('click',()=>choose(objective.tool));
     row.appendChild(button);
   }
   goals.appendChild(row);
 }
 outcome.replaceChildren();
 outcome.appendChild(create('strong','',strings.unlock+' — '+strings.themes[state.mood][0]));
 outcome.appendChild(create('p','',strings.themes[state.mood][1]));
 outcome.appendChild(create('p','inherit-chapter-next',state.complete?strings.end:strings.more));
 caution.textContent=(state.dataConsistent?'':strings.mismatch+' ')+(!editable?strings.readOnly+' ':'')+strings.disclaimer;
 section.dataset.complete=String(state.complete);
}
function schedule(){if(queued)return;queued=true;queueMicrotask(()=>{queued=false;render()})}
const observer=new MutationObserver(schedule);
observer.observe(objects,{childList:true});
const gen=doc.querySelector('#gen');if(gen)observer.observe(gen,{childList:true,characterData:true,subtree:true});
window.InheritStoryUI=Object.freeze({refresh:schedule,getState:()=>engine.evaluate(window.InheritGame.snapshot())});
render();
})();
