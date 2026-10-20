/* INHERIT — WORLD CYCLE UI v2. No writes to shared-world data or server endpoints. */
(()=>{
'use strict';
const d=document,engine=window.InheritWorldCycle,notebook=window.InheritReturnNotebook,game=window.InheritGame;
const world=d.querySelector('#world'),island=d.querySelector('#island'),dialog=d.querySelector('.inherit-legacy-dialog');
if(!engine||!notebook||!game||!world||!dialog||!island)return;
const locale=()=>{const id=window.InheritUI?.getLanguage?.();return ['ru','en','zh'].includes(id)?id:'ru'};
const create=(tag,className,content)=>{const element=d.createElement(tag);if(className)element.className=className;if(content!==undefined)element.textContent=content;return element};
const copy={
 ru:{
  pretitle:'Событие поколения',incident:'Событие',detail:'Открыть историю',unresolved:'История ждёт твоего выбора',resolved:'Ты изменил историю этого поколения',choose:'Выбрать',readOnly:'Только чтение',trace:'След',world:'Состояние мира',growth:'Развитие мира',
  chapters:'Сезон острова',season:{tide:'Время прилива',sun:'Время солнца',wind:'Время ветров',mist:'Время туманов'},
  stages:{untouched:'Нетронутый берег',growing:'Мир оживает',settlement:'Знакомые места',ancient:'Старое наследие'},
  tone:{quiet:'В ожидании',nature:'Природа',routes:'Дороги и огни',memory:'Память и камни'},
  source:'События и атмосфера — художественное отражение сохранённых следов. Здесь нет вымышленных онлайн-жителей, платежей или дополнительных игровых ресурсов.',
  episode:'История этого поколения',growingTitle:'Во что превратился остров',outcomes:'Последствия твоих решений',milestones:'Открытия мира',
  achievementCount:'Открыто',notYet:'Ещё не открыто',completed:'Открыто',count:'из',impact:'Последствие',
  missing:'Выбери один из предметов ниже и оставь его на острове. Только настоящее размещение меняет историю.',
  confirmed:'Новая деталь появилась благодаря размещённому в этом поколении следу.',
  unknown:'Не удалось проверить соответствие текущих объектов и черновика. Событие не засчитывается.',
  noRight:'Мир сейчас доступен только для чтения. Событие не создаёт права изменять чужие объекты.',
  more:'Читать и продолжить',legacy:'Сохранённые следы',age:'Снимки поколений',ageUnknown:'Возраст отдельных объектов неизвестен без старых снимков.',
  counts:{nature:'Живая природа',routes:'Дороги и свет',memory:'Постройки',connections:'Связи'},
  stagesDesc:{
   untouched:'Пока на острове мало отметок. Следующий путь ещё предстоит придумать.',
   growing:'Следы становятся заметны. Теперь у следующего хранителя есть с чего начать.',
   settlement:'Связанные участки превращаются в узнаваемые места острова.',
   ancient:'Старые сочетания пережили несколько поколений — их возраст подтверждён снимками.'
  },
  milestone:{
   first:['Первый след','Оставить хотя бы один предмет'],
   diversity:['Три материала','Использовать три вида следов'],
   connected:['Первая связь','Создать первое сочетание предметов'],
   gardener:['Зелёные берега','Оставить три живых следа'],
   pathfinder:['Дорога домой','Оставить три дорожных или световых следа'],
   architect:['Наследие строителей','Оставить три каменных следа'],
   sanctuary:['Остров связан','Создать три сочетания'],
   ten:['Десять следов','Оставить десять предметов'],
   collector:['Все десять','Использовать все десять видов предметов'],
   enduring:['Старше трёх поколений','Иметь след с подтверждённым возрастом от трёх поколений'],
   fifty:['Большой остров','Оставить 50 предметов'],
   woven:['Переплетённые пути','Создать шесть сочетаний']
  },
  notebook:'Дневник возвращений',notebookIntro:'Хранит только даты визитов и четыре числа о твоём локальном мире — исключительно на этом устройстве. Без отправки данных, наказаний за пропуски и платных наград.',
  enable:'Включить дневник',disable:'Очистить и отключить',days:'Разных дней',last:'Последняя запись',
  noRecord:'Дневник отключён. Ты можешь играть без него.',private:'Записи не синхронизируются и не доказывают действия других игроков.',
  accountPrivate:'Дневник доступен только для локального мира. Сведения об аккаунтах и чужих мирах не собираются.',
  noStorage:'Хранилище браузера недоступно. Играть можно, но дневник не сохранится.',
  returnTitle:'С возвращением на остров',returnNothing:'По сохранению изменений со времени прошлого визита не обнаружено.',
  returnPlus:'В текущем сохранении изменилось: поколений {g}, следов {o}, связей {l}, открытий {m}. Мы не знаем, кто и когда это сделал.',
  returnNegative:'Сохранение отличается от прошлого визита (возможно, был импортирован или восстановлен другой архив). Автора изменений определить нельзя.',
  cleared:'Личный дневник очищен.',tools:{tree:'Дерево',stone:'Камень',light:'Фонарь',path:'Тропа',flower:'Цветы',arch:'Арка',chime:'Колокольчик',moss:'Мох',cairn:'Насыпь',marker:'Указатель'},
  events:{
   afterstorm:['После шторма','На мокром берегу можно оставить дерево для укрытия или камень для защиты.'],
   'tidal-flare':['Свет отлива','Когда море уходит, фонарь или указатель помогут найти путь.'],
   'first-nesting':['Первые гнёзда','Дерево или цветы меняют вид тихой долины.'],
   'voices-under-stone':['Голоса под камнем','Арка или камень помогут сохранить память этого места.'],
   waterline:['Линия воды','Мох у берега или новая тропа меняют путь через луг.'],
   'cloudless-watch':['Звёздная вахта','Оставь фонарь или колокольчик для следующего хранителя.'],
   'garden-in-wind':['Сад под ветром','Цветы или мох помогают острову ожить.'],
   'forgotten-inscription':['Забытая надпись','Камень или указатель напомнят, откуда начался путь.'],
   'quiet-crossing':['Тихая переправа','Путь или дерево дадут ориентир у воды.'],
   'distant-shimmer':['Далёкое мерцание','Фонарь или каменная насыпь превратятся в ориентир.'],
   'return-of-colors':['Возвращение красок','Цветы и колокольчик пробуждают безмолвный берег.'],
   'old-foundations':['Старый фундамент','Арка или каменная насыпь продолжают историю строителей.'],
   'high-meadow':['Высокий луг','Посади дерево или мох, чтобы изменить вид луга.'],
   'signal-in-fog':['Сигнал в тумане','Фонарь или тропа делают дорогу заметнее.'],
   'last-wildflowers':['Последние цветы','Цветы или дерево сохраняют жизнь на берегу.'],
   'names-on-the-shore':['Имена на берегу','Указатель или камень станут знаком памяти.']
  },
  impacts:{sprout:'У новой зелени появился шанс прижиться.',shelter:'На берегу появилось место для укрытия.',glow:'Среди тумана виден тёплый свет.',route:'Остался указатель, показывающий путь.',
   birds:'Рядом с деревом может возникнуть новый уголок для птиц.',pollinators:'Цветы сделали остров ярче.',echo:'Арка продолжает память о строителях.',memorial:'Камень стал новым местом памяти.',reeds:'Влажный берег постепенно зеленеет.',crossing:'Среди травы обозначился путь.',breeze:'Новый колокольчик напоминает о ветре.'}
 },
 en:{
  pretitle:'Generation incident',incident:'Incident',detail:'Open the story',unresolved:'The story awaits your choice',resolved:'You changed this generation’s story',choose:'Choose',readOnly:'Read only',trace:'Trace',world:'World state',growth:'World evolution',
  chapters:'Island season',season:{tide:'Season of tides',sun:'Season of sunlight',wind:'Season of winds',mist:'Season of mist'},
  stages:{untouched:'Untouched shore',growing:'The world awakens',settlement:'Places of belonging',ancient:'An enduring legacy'},
  tone:{quiet:'Waiting',nature:'Nature',routes:'Roads and lights',memory:'Stone and memory'},
  source:'Episodes and atmosphere are creative interpretations of saved traces, not claims of online players, purchases or extra in-game resources.',
  episode:'This generation’s episode',growingTitle:'How the island has grown',outcomes:'Consequences of your choices',milestones:'World discoveries',
  achievementCount:'Unlocked',notYet:'Not unlocked',completed:'Unlocked',count:'of',impact:'Consequence',
  missing:'Choose one of the objects and place it on the island. Only real placement advances this episode.',
  confirmed:'A new detail appeared because of a trace placed in this generation.',
  unknown:'The current draft does not match the world objects. The episode cannot be awarded.',
  noRight:'This world is read only at present. An episode cannot grant permission to change other people’s traces.',
  more:'Read and continue',legacy:'Saved traces',age:'Generation snapshots',ageUnknown:'Ages are unknown without archived generation snapshots.',
  counts:{nature:'Living nature',routes:'Roads and lights',memory:'Structures',connections:'Connections'},
  stagesDesc:{
   untouched:'Few marks remain on the island. Its next path has yet to be chosen.',
   growing:'Traces are taking shape, giving the next keeper something to build on.',
   settlement:'Linked locations have become recognizable places of the island.',
   ancient:'Old connections lasted through generations; snapshots confirm their age.'
  },
  milestone:{
   first:['First trace','Leave at least one object'],diversity:['Three materials','Use three trace types'],connected:['First connection','Create one trace combination'],
   gardener:['Green shores','Leave three living traces'],pathfinder:['Way home','Leave three road or light traces'],
   architect:['Builders’ legacy','Leave three stone traces'],sanctuary:['Connected island','Create three combinations'],
   ten:['Ten traces','Place ten objects'],collector:['All ten','Use every trace type'],
   enduring:['Three generations old','Preserve a trace whose age is verified at three generations or more'],
   fifty:['Big island','Leave fifty objects'],woven:['Woven paths','Create six trace combinations']
  },
  notebook:'Return notebook',notebookIntro:'Stores only visit dates and four numbers from your local world on this device. No data is sent, no streak penalties, no paid rewards.',
  enable:'Enable notebook',disable:'Delete and disable',days:'Days visited',last:'Last record',
  noRecord:'The notebook is off. You can play without it.',private:'Entries are not synchronized and do not prove activity by other players.',
  accountPrivate:'The notebook is for local worlds only. Account or other players’ details are not collected.',
  noStorage:'Browser storage is unavailable. Play continues, but the notebook cannot save.',
  returnTitle:'Welcome back to the island',returnNothing:'No saved-world changes were detected since your previous visit.',
  returnPlus:'The current save changed: generations {g}, traces {o}, connections {l}, discoveries {m}. The author and timing are unknown.',
  returnNegative:'The save differs from your previous visit (perhaps another archive was imported or restored). The author cannot be determined.',
  cleared:'Private notebook deleted.',tools:{tree:'Tree',stone:'Stone',light:'Lantern',path:'Path',flower:'Flowers',arch:'Arch',chime:'Chime',moss:'Moss',cairn:'Cairn',marker:'Marker'},
  events:{
   afterstorm:['After the storm','A tree can shelter this shore, while a stone could protect it.'],'tidal-flare':['Tidal flare','A lantern or marker helps find the way as the sea recedes.'],
   'first-nesting':['First nesting','A tree or flowers will change the quiet valley.'],'voices-under-stone':['Voices beneath stone','An arch or stone can keep the memory of this place.'],
   waterline:['Waterline','Moss on the shore or a new path changes the way across.'],'cloudless-watch':['Clear-sky watch','Leave a lantern or chime for the next keeper.'],
   'garden-in-wind':['Garden in the wind','Flowers or moss breathe life into the island.'],'forgotten-inscription':['Forgotten inscription','A stone or marker remembers the beginning of a journey.'],
   'quiet-crossing':['Quiet crossing','A path or tree brings an anchor to the water.'],'distant-shimmer':['Distant shimmer','A lantern or cairn becomes a landmark.'],
   'return-of-colors':['Return of colors','Flowers or a chime wake up the silent shore.'],'old-foundations':['Old foundations','An arch or cairn continues the builders’ history.'],
   'high-meadow':['High meadow','Plant a tree or moss to change this meadow.'],'signal-in-fog':['Signal in fog','Lanterns or paths make the crossing clearer.'],
   'last-wildflowers':['Last wildflowers','Flowers or a tree keep this shore alive.'],'names-on-the-shore':['Names on the shore','A marker or stone will become a memorial.']
  },
  impacts:{sprout:'New greenery has a chance to take root.',shelter:'The shore gains a place of shelter.',glow:'A warm light glows in the mist.',route:'A marker now shows the route.',
   birds:'A tree may shelter birds.',pollinators:'Flowers brighten the island.',echo:'The arch holds the memory of its builders.',memorial:'A stone becomes a place of memory.',reeds:'The wet shoreline turns greener.',crossing:'A route emerges through the grass.',breeze:'A chime recalls the winds.'}
 },
 zh:{
  pretitle:'世代事件',incident:'事件',detail:'打开故事',unresolved:'故事等待你的选择',resolved:'你改变了这个世代的故事',choose:'选择',readOnly:'只读',trace:'痕迹',world:'世界状态',growth:'世界发展',
  chapters:'岛屿季节',season:{tide:'潮汐时节',sun:'阳光时节',wind:'风之时节',mist:'迷雾时节'},
  stages:{untouched:'原始海岸',growing:'世界苏醒',settlement:'熟悉之地',ancient:'久远传承'},
  tone:{quiet:'等待',nature:'自然',routes:'道路与灯光',memory:'石头与记忆'},
  source:'事件与氛围是对存档痕迹的艺术演绎，不代表有真实在线玩家、购买行为或额外游戏资源。',
  episode:'本世代故事',growingTitle:'岛屿的发展',outcomes:'你的选择带来的变化',milestones:'世界发现',
  achievementCount:'已解锁',notYet:'未解锁',completed:'已解锁',count:'共',impact:'结果',
  missing:'选择下面的物件并放在岛上，只有真实放置才能推进本事件。',
  confirmed:'本世代放置的痕迹带来了新的变化。',
  unknown:'目前的草稿与世界物件不符，不能授予事件进度。',
  noRight:'当前世界只能查看。事件不会授予修改其他玩家痕迹的权限。',
  more:'阅读并继续',legacy:'已保存痕迹',age:'世代快照',ageUnknown:'如果没有过去世代的快照，就无法确认物件年代。',
  counts:{nature:'自然',routes:'道路与灯光',memory:'建筑',connections:'连接'},
  stagesDesc:{untouched:'岛上还没有太多痕迹，下一段旅程仍在等待。',growing:'痕迹逐渐成形，下一位守护者有了新的起点。',settlement:'相连的地点成为了岛上熟悉的风景。',ancient:'古老的连接跨越世代，快照可以证实其年代。'},
  milestone:{
   first:['第一道痕迹','放置至少一个物件'],diversity:['三种材料','使用三种痕迹'],connected:['第一次连接','创造一个物件组合'],
   gardener:['绿色海岸','放置三道生命痕迹'],pathfinder:['回家的路','放置三道路标或灯光痕迹'],
   architect:['建造者传承','放置三道石制痕迹'],sanctuary:['相连的小岛','创造三个组合'],
   ten:['十道痕迹','放置十个物件'],collector:['全部十种','使用全部十种物件'],
   enduring:['跨越三代','有一处已证实保存三代以上的痕迹'],
   fifty:['巨大的岛屿','放置五十个物件'],woven:['交织的路','创造六个物件组合']
  },
  notebook:'回归日志',notebookIntro:'只在本设备保存访问日期和本地世界的四个数字。不会发送数据、没有连续登录惩罚、没有付费奖励。',
  enable:'启用日志',disable:'清除并关闭',days:'访问天数',last:'上次记录',
  noRecord:'日志已关闭，你可以不使用它继续游玩。',private:'记录不会同步，也不能证明其他玩家的活动。',
  accountPrivate:'日志仅用于本地世界，不收集账号或其他玩家的信息。',
  noStorage:'浏览器存储不可用，游戏可以继续，但日志无法保存。',
  returnTitle:'欢迎回到小岛',returnNothing:'与上次访问相比，存档未检测到变化。',
  returnPlus:'当前存档发生了变化：世代 {g}，痕迹 {o}，连接 {l}，发现 {m}。作者和时间未知。',
  returnNegative:'存档与上次访问不同（可能导入或恢复了其他存档），无法判断修改者。',
  cleared:'个人日志已清除。',tools:{tree:'树',stone:'石头',light:'灯',path:'道路',flower:'花朵',arch:'拱门',chime:'风铃',moss:'苔藓',cairn:'石堆',marker:'路标'},
  events:{
   afterstorm:['风暴之后','树木可以提供庇护，石头可以保护海岸。'],'tidal-flare':['退潮之光','当海水退去，灯或路标可以指引道路。'],
   'first-nesting':['初次筑巢','树木或花朵改变宁静的山谷。'],'voices-under-stone':['石下回声','拱门或石头可以保存这里的记忆。'],
   waterline:['水位线','岸边苔藓或新道路会改变穿行方式。'],'cloudless-watch':['晴夜守望','为下一位守护者留下灯或风铃。'],
   'garden-in-wind':['风中花园','花朵或苔藓唤醒小岛。'],'forgotten-inscription':['遗忘的铭文','石头或路标记下旅途的起点。'],
   'quiet-crossing':['安静的渡口','道路或树木提供水边的方向。'],'distant-shimmer':['远方微光','灯或石堆成为新的地标。'],
   'return-of-colors':['色彩归来','花朵或风铃唤醒沉默的海岸。'],'old-foundations':['古老地基','拱门或石堆延续建造者的故事。'],
   'high-meadow':['高山草甸','种树或苔藓改变草甸。'],'signal-in-fog':['雾中信号','灯或小径让道路更清晰。'],
   'last-wildflowers':['最后的野花','花朵或树木为海岸留下生命。'],'names-on-the-shore':['岸边的名字','路标或石头会成为纪念。']
  },
  impacts:{sprout:'新的绿色有机会扎根。',shelter:'海岸多了一处庇护。',glow:'迷雾中出现了温暖的光。',route:'路标现在指引道路。',
   birds:'树木可能为鸟类提供庇护。',pollinators:'鲜花使小岛更加明亮。',echo:'拱门保留了建造者的记忆。',memorial:'石头成为纪念之地。',reeds:'潮湿的海岸逐渐变绿。',crossing:'草地上出现新的道路。',breeze:'风铃让人想起海风。'}
 }
};
const t=()=>copy[locale()];
const insertAfter=d.querySelector('.inherit-chapter-panel')||dialog.querySelector('.inherit-legacy-intro');
if(!insertAfter)return;
// Island-facing episode entry: useful without creating another toolbar or intercepting game input.
const entry=create('aside','inherit-cycle-entry');
entry.dataset.noTranslate='';
entry.setAttribute('aria-label','Generation incident');
const label=create('span','inherit-cycle-entry-label');
const name=create('strong','inherit-cycle-entry-name');
const status=create('p','inherit-cycle-entry-status');
const open=create('button','inherit-cycle-entry-open');open.type='button';
entry.append(label,name,status,open);world.appendChild(entry);
// Ambient particles are decorative and never interactive.
const ambience=create('div','inherit-cycle-ambience');ambience.setAttribute('aria-hidden','true');
for(let i=0;i<12;i++){
 const mote=create('i','inherit-cycle-mote');mote.style.setProperty('--i',String(i));
 mote.style.left=(8+i*7.3)+'%';mote.style.top=(14+(i*17)%68)+'%';ambience.appendChild(mote);
}
world.appendChild(ambience);
const imprints=create('div','inherit-cycle-imprint-layer');imprints.setAttribute('aria-hidden','true');island.appendChild(imprints);
const chapter=create('section','inherit-cycle-journal');chapter.dataset.noTranslate='';
chapter.setAttribute('aria-labelledby','inherit-cycle-title');
const brow=create('span','inherit-cycle-eyebrow');
const heading=create('h3','inherit-cycle-title');heading.id='inherit-cycle-title';
const summary=create('p','inherit-cycle-summary');
const choiceLabel=create('p','inherit-cycle-choice-label');
const options=create('div','inherit-cycle-choices');
const consequence=create('p','inherit-cycle-consequence');
const phaseHead=create('h4','inherit-cycle-subtitle');
const phaseDesc=create('p','inherit-cycle-phase-description');
const facts=create('div','inherit-cycle-facts');
const badgeHead=create('h4','inherit-cycle-subtitle');
const unlockCount=create('p','inherit-cycle-unlocked');
const milestoneList=create('ul','inherit-cycle-milestones');
const truth=create('p','inherit-cycle-truth');
const returnSection=create('section','inherit-return-section');
const returnHead=create('h4','inherit-cycle-subtitle');
const returnInfo=create('p','inherit-return-intro');
const returnStatus=create('div','inherit-return-status');
const returnActions=create('div','inherit-return-actions');
const consent=create('button','inherit-return-enable');consent.type='button';
const erase=create('button','inherit-return-erase');erase.type='button';
returnActions.append(consent,erase);returnSection.append(returnHead,returnInfo,returnStatus,returnActions);
chapter.append(brow,heading,summary,choiceLabel,options,consequence,phaseHead,phaseDesc,facts,badgeHead,unlockCount,milestoneList,truth,returnSection);
insertAfter.after(chapter);
let initialized=false,book=null,lastDelta=null,storageUnavailable=false,lastEvent=null,scheduled=false;
let stored=null;try{stored=window.InheritPersistence||window.localStorage}catch{storageUnavailable=true}
function local(){return !game.accountMode?.()}
function read(){
 try{
  const raw=stored?.getItem?.(notebook.KEY);
  if(!raw||raw.length>4096)return null;
  return notebook.normalize(JSON.parse(raw));
 }catch{storageUnavailable=true;return null}
}
function save(record){
 try{stored?.setItem?.(notebook.KEY,JSON.stringify(record));return true}
 catch{storageUnavailable=true;return false}
}
function clear(){
 try{stored?.removeItem?.(notebook.KEY);return true}
 catch{storageUnavailable=true;return false}
}
function noticeIfReturned(){
 if(initialized||!local())return;
 initialized=true;book=read();
 if(book){
   const result=notebook.enter(book,notebook.todayLocal(),engine.evaluate(game.snapshot()));
   if(result.isNewDay){
     lastDelta=result.delta;
     if(save(result.record))book=result.record;
   }
 }
}
function allowed(){
 if(d.querySelector('#pass')?.disabled)return false;
 if(d.body.classList.contains('past')||d.body.classList.contains('replay-mode'))return false;
 if(game.accountMode?.()){
   const state=window.InheritAccount?.state?.();
   return !!state?.canEdit&&!state?.busy&&!state?.loading&&!state?.pending?.length;
 }
 return true;
}
function selectTrace(type){
 if(!allowed())return;
 const tool=d.querySelector('.tools [data-tool="'+type+'"]')||d.querySelector('.catalog [data-extra="'+type+'"]');
 if(!tool)return;
 tool.click();
 if(dialog.open)dialog.close();
 world.setAttribute('tabindex','-1');world.focus?.({preventScroll:true});
}
function show(){
 const opener=d.querySelector('.inherit-legacy-trigger');
 if(opener){opener.click();heading.scrollIntoView?.({block:'nearest',behavior:'instant'})}
}
open.addEventListener('click',show);
consent.addEventListener('click',()=>{
 if(!local()||storageUnavailable)return;
 const record=notebook.enable(notebook.todayLocal(),engine.evaluate(game.snapshot()));
 if(record&&save(record)){book=record;lastDelta=null;render()}
});
erase.addEventListener('click',()=>{
 if(!local())return;
 if(clear()){book=null;lastDelta=null;render()}
});
function fact(number,title){const x=create('div','inherit-cycle-fact');x.append(create('strong','',String(number)),create('small','',title));facts.append(x)}
function interpolate(value,variables){return String(value).replace(/\{([a-z]+)\}/g,(_,key)=>String(variables[key]??''))}
function renderReturn(state,strings){
 returnHead.textContent=strings.notebook;
 returnInfo.textContent=strings.notebookIntro;
 returnActions.hidden=!local()||storageUnavailable;
 consent.textContent=strings.enable;consent.hidden=!!book;
 erase.textContent=strings.disable;erase.hidden=!book;
 returnStatus.replaceChildren();
 if(!local()){returnStatus.append(create('p','',strings.accountPrivate));return}
 if(storageUnavailable){returnStatus.append(create('p','',strings.noStorage));return}
 if(!book){returnStatus.append(create('p','',strings.noRecord));return}
 const box=create('div','inherit-return-stats');
 box.append(create('span','',strings.days+': '+book.dayCount),create('span','',strings.last+': '+book.last.day));
 returnStatus.append(box);
 if(lastDelta){
  const changed=[lastDelta.generation,lastDelta.objects,lastDelta.links,lastDelta.discoveries];
  let message=changed.some(v=>v<0)?strings.returnNegative:changed.some(v=>v>0)?interpolate(strings.returnPlus,{
    g:lastDelta.generation,o:lastDelta.objects,l:lastDelta.links,m:lastDelta.discoveries}):strings.returnNothing;
  returnStatus.append(create('p','inherit-return-changes',strings.returnTitle+' · '+message));
 }
 returnStatus.append(create('p','inherit-return-private',strings.private));
}
function render(){
 noticeIfReturned();
 const current=engine.evaluate(game.snapshot()),strings=t(),incident=current.event;
 const episode=strings.events[incident.id]||[incident.id,''];
 d.body.dataset.inheritSeason=current.season;
 d.body.dataset.inheritStage=current.stage;
 d.body.dataset.inheritIncident=incident.resolved?incident.impact:'none';
 imprints.replaceChildren();
 if(incident.resolved&&incident.position){
  const glyph=create('span','inherit-cycle-imprint inherit-cycle-imprint--'+incident.impact);
  glyph.style.left=incident.position.x+'%';glyph.style.top=incident.position.y+'%';
  imprints.appendChild(glyph);
 }
 label.textContent=strings.pretitle+' · '+current.generation;
 name.textContent=episode[0];
 status.textContent=incident.resolved?strings.resolved:strings.unresolved;
 open.textContent=strings.detail;
 brow.textContent=strings.episode+' / '+current.generation;
 heading.textContent=episode[0];
 summary.textContent=episode[1];
 choiceLabel.textContent=incident.resolved?strings.confirmed:current.pendingValid?strings.missing:strings.unknown;
 options.replaceChildren();
 if(!incident.resolved){
  for(const type of incident.types){
   const b=create('button','inherit-cycle-choice',strings.choose+': '+strings.tools[type]);b.type='button';
   b.disabled=!allowed();b.setAttribute('aria-label',strings.choose+': '+strings.tools[type]);
   b.addEventListener('click',()=>selectTrace(type));options.appendChild(b);
  }
 }
 consequence.textContent=incident.resolved?strings.impact+': '+strings.impacts[incident.impact]:!allowed()?strings.noRight:'';
 phaseHead.textContent=strings.growingTitle+' · '+strings.season[current.season];
 phaseDesc.textContent=strings.stages[current.stage]+' — '+strings.stagesDesc[current.stage];
 facts.replaceChildren();
 fact(current.metrics.objects,strings.legacy);
 fact(current.metrics.connections,strings.counts.connections);
 fact(current.metrics.living,strings.counts.nature);
 fact(current.metrics.built,strings.counts.memory);
 badgeHead.textContent=strings.milestones;
 unlockCount.textContent=strings.achievementCount+' '+current.unlocked+' '+strings.count+' '+current.totalMilestones;
 milestoneList.replaceChildren();
 for(const milestone of current.milestones){
   const li=create('li','inherit-cycle-milestone'+(milestone.unlocked?' is-unlocked':''));
   const icon=create('span','inherit-cycle-milestone-icon',milestone.unlocked?'✦':'◇');
   const info=create('div','inherit-cycle-milestone-info');
   info.append(create('strong','',strings.milestone[milestone.id][0]),create('small','',strings.milestone[milestone.id][1]));
   li.append(icon,info,create('span','inherit-cycle-milestone-progress',milestone.progress+'/'+milestone.threshold));
   milestoneList.append(li);
 }
 truth.textContent=strings.source+(current.limited?' '+(locale()==='ru'?'Большой архив: часть подсчётов ограничена.':locale()==='zh'?'大型存档：部分计算受限。':'Large archive: some calculations are limited.'):'');
 renderReturn(current,strings);
 // Restrict aria-live to genuine state transitions; a reload with already-complete
 // event should not masquerade as something that just happened.
 const stateKey=current.generation+'|'+incident.id+'|'+String(incident.resolved);
 if(lastEvent!==null&&lastEvent!==stateKey&&incident.resolved){
   status.setAttribute('role','status');
 }else status.removeAttribute('role');
 lastEvent=stateKey;
}
function refresh(){if(scheduled)return;scheduled=true;queueMicrotask(()=>{scheduled=false;render()})}
const observer=new MutationObserver(refresh);
const objects=d.querySelector('#objects'),gen=d.querySelector('#gen');
if(objects)observer.observe(objects,{childList:true});
if(gen)observer.observe(gen,{childList:true,characterData:true,subtree:true});
window.InheritWorldUI=Object.freeze({refresh,getState:()=>engine.evaluate(game.snapshot()),getNotebook:()=>book?{dayCount:book.dayCount,last:book.last.day}:null});
render();
})();
