/* RU/EN interface layer. Keeps original game state and mechanics independent of presentation. */
(()=>{
"use strict";
const persistence=window.InheritPersistence;
const dictionary={
 "THE QUIET REACH /":"ТИХАЯ ГАВАНЬ /",
 "GEN":"ПОК.",
 "A WORLD LEFT FOR YOU": "МИР, ОСТАВЛЕННЫЙ ВАМ",
 "Someone built a path": "Кто-то проложил путь",
 "to the sea.": "к морю.",
 "They did not say why.": "И не объяснил зачем.",
 "THE QUIET REACH": "ТИХАЯ ГАВАНЬ",
 "Start a new lineage": "Начать новую историю",
 "Start a new local lineage?": "Начать новую локальную историю? Текущий мир будет сброшен. Сначала экспортируйте его, если хотите сохранить.",
 "Click the island to leave a trace": "Нажмите на остров, чтобы оставить след",
 "YOUR TURN": "ВАШ ХОД",
 "changes remaining": "изменений осталось",
 "Plant": "Посадить дерево",
 "Place stone": "Положить камень",
 "Leave a light": "Зажечь фонарь",
 "Mark a path": "Проложить тропу",
 "See history ↗": "История мира ↗",
 "Pass this world on →": "Завершить поколение →",
 "Passing generation…": "Сохраняем поколение…",
 "Generation handoff is in progress. Please wait.": "Поколение сохраняется. Дождитесь завершения.",
 "Passing this generation. Traces are paused until the request finishes.": "Сохраняем поколение. Новые следы можно оставить после завершения запроса.",
 "Saved locally. The server has not confirmed this generation.": "Поколение сохранено локально. Подтверждения сервера нет.",
 "This generation stays in the open page only. Server confirmation is unknown; export before leaving.": "Поколение осталось только на открытой странице. Подтверждения сервера нет; экспортируйте мир перед уходом.",
 "The shared world changed. Your pending traces are unchanged; export before reloading.": "Сетевой мир изменился. Ваши незавершённые следы сохранены без изменений; экспортируйте мир перед перезагрузкой.",
 "The world changed while the archive was loading. Choose the file again.": "Мир изменился во время чтения архива. Выберите файл ещё раз.",
 "This lineage cannot advance further. Export it before starting a new lineage.": "Это поколение больше нельзя продолжить. Экспортируйте мир перед началом новой истории.",
 "OBJECT MEMORY": "ПАМЯТЬ ОБЪЕКТА",
 "WORLD HISTORY": "ИСТОРИЯ МИРА",
 "Every change becomes a trace.": "Каждое действие оставляет след.",
 "Show past traces": "Показать прошлое",
 "Return to today": "Вернуться в настоящее",
 "Return to present": "Вернуться в настоящее",
 "The old tree": "Старое дерево",
 "The stone arch": "Каменная арка",
 "The last signal": "Последний сигнал",
 "A trace you left": "Ваш след",
 "It has watched 143 generations arrive at this shore. Its roots hold the first promise this island received.": "Оно видело 143 поколения на этом берегу. Его корни хранят первое обещание острова. Это часть вступительной истории.",
 "It survived a storm that erased every marker from the eastern coast. Someone rebuilt it before they left.": "Арка пережила шторм, стёрший все указатели на восточном берегу. Кто-то восстановил её перед уходом.",
 "It blinks slowly over the water. A small invitation made for whoever came next.": "Он медленно мерцает над водой. Маленькое приглашение для следующего хранителя.",
 "First planted by": "Первое дерево посадил",
 "Restored by": "Восстановил",
 "Left by": "Оставил",
 "Created by": "Автор:",
 "you": "вы",
 "Placed the first lantern at the western shore.": "Поставил первый фонарь на западном берегу.",
 "Restored the stone arch after the winter tide.": "Восстановил каменную арку после зимнего прилива.",
 "Marked a safe path through the river meadow.": "Отметил безопасную тропу через луг у реки.",
 "Left the island quiet, except for one signal.": "Оставил остров в тишине, сохранив один сигнал.",
 "3 days ago": "3 дня назад",
 "2 days ago": "2 дня назад",
 "Yesterday": "Вчера",
 "Now": "Сейчас",
 "Just now": "Только что",
 "planted a young tree": "посадили молодое дерево",
 "placed a shoreline stone": "положили камень на берегу",
 "left a lantern for the next person": "оставили фонарь следующему хранителю",
 "marked a new path": "проложили новую тропу",
 "planted moonflowers": "посадили лунные цветы",
 "raised a small arch": "поставили небольшую арку",
 "hung a wind chime": "повесили музыку ветра",
 "restored a patch of moss": "восстановили мох",
 "stacked a stone cairn": "сложили каменную пирамиду",
 "left a gold waymarker": "оставили золотой указатель",
 "Your change budget is complete": "В этом поколении больше нет доступных изменений.",
 "Earlier traces are glowing over the island": "На острове подсвечены следы прошлого.",
 "Leave one trace before passing the world on": "Сначала оставьте хотя бы один след на острове.",
 "Your trace is waiting for the next person.": "Ваш след сохранён в истории этого мира.",
 "World passed on — a new generation begins": "Поколение завершено. Начинается новая глава.",
 "Founder preview": "Будущий выпуск",
 "Open the cosmetic Founder Pass preview": "Посмотреть концепцию будущего выпуска",
 "Close Founder preview": "Закрыть описание будущего выпуска",
 "FUTURE EDITION": "БУДУЩИЙ ВЫПУСК",
 "Founder Pass": "Набор основателя",
 "Cosmetic traces, a founder mark, and an expanded generation card. It will never change budget, score, coordinates, or another player's world.": "Декоративные следы, знак основателя и расширенная карточка поколения. Они не меняют запас действий, очки, координаты или чужой мир.",
 "No payment is available in this preview. Your interest stays on this device.": "Оплата не подключена. Отметка интереса хранится только в этом браузере.",
 "Mark my interest": "Мне интересно",
 "Interest saved on this device": "Интерес сохранён в браузере",
 "Founder interest saved locally": "Отметка интереса сохранена локально.",
 "Keep INHERIT close": "Установить INHERIT",
 "Install INHERIT on this device": "Установить INHERIT на устройство",
 "Showing the world before your generation": "Показан мир до вашего поколения.",
 "Returned to your generation": "Вы вернулись в своё поколение.",
 "Shared lineage loaded": "Загружена история из сетевого сервиса.",
 "Offline lineage is active": "Активен локальный мир. Сетевой сервис недоступен.",
 "Local traces are waiting to be passed on": "Локальные изменения ожидают завершения поколения; сетевой ответ их не заменил.",
 "Someone changed this world — loading their generation": "Мир изменился. Загружаем актуальное поколение.",
 "Your trace is now part of a shared history.": "Сервис подтвердил запись вашего следа.",
 "Server unavailable — your local lineage is preserved": "Сервер недоступен. Локальная история сохранена.",
 "Name shown in your world history:": "Какое имя показывать в истории мира?",
 "Profile updated": "Имя обновлено.",
 "YOUR WORLD CHANGED": "ВАШ МИР ИЗМЕНИЛСЯ",
 "Someone left a new trace.": "В истории появился новый след.",
 "See what they did": "Посмотреть изменения",
 "MORE WAYS TO LEAVE A TRACE": "БОЛЬШЕ ВОЗМОЖНОСТЕЙ",
 "Make the next arrival curious.": "Оставьте повод присмотреться.",
 "✿ Moonflowers": "✿ Лунные цветы",
 "∩ Stone arch": "∩ Каменная арка",
 "♬ Wind chime": "♬ Музыка ветра",
 "◌ Moss patch": "◌ Мох",
 "▰ Stone cairn": "▰ Пирамида камней",
 "│ Gold waymarker": "│ Золотой указатель",
 "More traces +6": "Ещё 6 следов",
 "Your journey": "Ваш прогресс",
 "Explorer": "Исследователь",
 "Creator": "Создатель",
 "Historian": "Летописец",
 "World chronicle": "Летопись мира",
 "Close chronicle": "Закрыть летопись",
 "FACTUAL WORLD HISTORY": "ЗАПИСИ ЭТОГО МИРА",
 "A world of traces.": "Мир из оставленных следов.",
 "No generation has been recorded yet.": "В истории пока нет завершённых поколений.",
 "Viewing an earlier generation": "Просмотр прошлого поколения",
 "This is the island exactly as it was passed on.": "Так остров выглядел при завершении этого поколения.",
 "The present is yours to continue.": "Теперь можно продолжить текущий мир.",
 "View traces": "Посмотреть следы",
 "Your offline lineage is safe on this device.": "Локальная история сохранена в этом браузере.",
 "Server unavailable — saved as a local generation": "Сервер недоступен. Поколение сохранено локально.",
 "Keys 1-0 choose traces": "Клавиши 1–0: выбрать след",
 "Use number keys 1 through 0 to choose trace types": "Клавиши 1–0 выбирают вид следа",
 "Export lineage": "Экспортировать мир",
 "Export the current Quiet Reach lineage": "Скачать историю и объекты текущего мира",
 "Download your world history as JSON": "Скачать историю мира в формате JSON",
 "Lineage archive exported": "Архив мира скачан.",
 "Import lineage": "Импортировать мир",
 "Import a Quiet Reach lineage archive": "Загрузить архив мира INHERIT",
 "Restore a previously exported lineage": "Восстановить мир из ранее скачанного архива",
 "Lineage archive restored": "Мир восстановлен из архива.",
 "Archive rejected — invalid lineage file": "Не удалось импортировать: неверный формат архива мира.",
 "FIRST TRACE": "ПЕРВАЯ ЦЕЛЬ",
 "Leave 3 kinds of traces": "Оставьте три разных вида следов",
 "The island remembers your hand": "Цель достигнута. Остров запомнил вас.",
 "Nothing to undo in this generation": "В этом поколении пока нечего отменять.",
 "the last trace": "последний след",
 "Share this generation": "Поделиться поколением",
 "Generation shared": "Окно отправки поколения открыто.",
 "Share text copied": "Текст приглашения скопирован.",
 "Sharing is unavailable on this device": "Отправка недоступна на этом устройстве.",
 "Export play data": "Экспортировать прогресс",
 "Export locally stored INHERIT play data": "Скачать локальный журнал действий INHERIT",
 "COMMUNITY SIGNAL": "СИГНАЛ МИРА",
 "Community signal complete": "Пять видов следов найдены",
 "Leave a living mark": "Оставьте живой след",
 "Create generation card": "Карточка поколения",
 "Create a shareable generation card": "Создать карточку поколения для отправки",
 "Close generation card": "Закрыть карточку поколения",
 "A WORLD TO CONTINUE": "МИР ДЛЯ ПРОДОЛЖЕНИЯ",
 "Leave one trace. Pass it on.": "Оставьте след. Продолжите историю.",
 "Copy invite": "Скопировать приглашение",
 "Invite one heir": "Пригласить хранителя",
 "Open continuation link": "Открыть ссылку на мир",
 "Generation invite copied": "Приглашение скопировано.",
 "Copy is unavailable on this device": "Копирование недоступно на этом устройстве.",
 "Your INHERIT invitation": "Приглашение в INHERIT",
 "Heir invitation shared": "Окно отправки приглашения открыто.",
 "Heir invitation copied": "Приглашение хранителю скопировано.",
 "Invitation is unavailable on this device": "Отправка приглашения недоступна на этом устройстве.",
 "Leave a quiet marker for whoever arrives next.": "Оставьте тихий знак для следующего хранителя.",
 "Add one light to the edge of the map.": "Зажгите один фонарь у края острова.",
 "Place a trace that makes the island easier to remember.": "Оставьте след, который поможет запомнить остров.",
 "Connect two places with a path.": "Соедините два места тропой.",
 "Give the next keeper a reason to look closer.": "Дайте следующему хранителю повод присмотреться.",
 "Daily signal": "Сигнал дня",
 "Open today's INHERIT signal": "Открыть сегодняшний сигнал INHERIT",
 "Close daily signal": "Закрыть сигнал дня",
 "TODAY'S RETURN": "ВОЗВРАЩЕНИЕ СЕГОДНЯ",
 "Signal left today. The island will be waiting tomorrow.": "Сегодняшний сигнал оставлен. Остров будет ждать завтра.",
 "One small action keeps the lineage moving.": "Одно небольшое действие продолжает историю.",
 "Signal left": "Сигнал оставлен",
 "Leave this signal": "Оставить сигнал",
 "Choose a trace, then place it on the island": "Выберите вид следа, затем укажите место на острове.",
 "Open your private INHERIT journey progress": "Посмотреть личный прогресс INHERIT",
 "Close journey panel": "Закрыть личный прогресс",
 "YOUR QUIET REACH": "ВАША ТИХАЯ ГАВАНЬ",
 "Stored on this device. Nothing in this panel is sent to OSGARD.": "Панель использует локальные события этого браузера. Её данные не отправляются OSGARD.",
 "First trace": "Первый след",
 "Three traces": "Три следа",
 "Worlds passed on": "Завершено поколений",
 "Generations shared": "Отправлено поколений",
 "Invites copied": "Скопировано приглашений",
 "Heirs invited": "Приглашено хранителей",
 "Daily signals": "Сигналы дня",
 "Community signals": "Сигналы мира",
 "Heirs returned": "Возвращения хранителей",
 "Leave the next trace": "Оставить следующий след",
 "Continue the lineage by leaving the next trace": "Продолжить мир: оставить следующий след",
 "INHERIT — The Quiet Reach": "INHERIT — Тихая гавань",
 "How to play": "Как играть",
 "Choose a trace. Leave it on the island.": "Выберите след и оставьте его на острове.",
 "Start with three different trace types. Finish the generation when you are ready to begin the next chapter.": "Начните с трёх разных видов следов. Завершите поколение, когда будете готовы перейти к следующей главе.",
 "Controls: click or tap the island; 1–0 chooses a trace. Focus the island, use arrows and Enter to place. Ctrl/Cmd+Z undoes the last trace; H opens the chronicle.": "Управление: нажатие на остров; 1–0 — вид следа. На поле: стрелки — место, Enter — разместить. Ctrl/Cmd+Z — отменить след; H — летопись.",
 "The first four entries are a fictional introduction. Names in local history do not mean other people are online. An invitation shares the route, not your local save.": "Первые четыре записи — вымышленное вступление. Имена в локальной летописи не означают, что другие люди сейчас онлайн. Приглашение передаёт ссылку, а не ваше локальное сохранение.",
 "Enter the island": "Перейти на остров",
 "Download recovered save": "Скачать исходное сохранение",
 "Close memory": "Закрыть память объекта",
 "Island: choose a location with arrows and place with Enter": "Остров: выберите место стрелками и разместите след клавишей Enter",
 "Old tree: read its memory": "Старое дерево: прочитать историю",
 "Stone arch: read its memory": "Каменная арка: прочитать историю",
 "Beacon: read its memory": "Маяк: прочитать историю",
 "Save: this browser only. Use Export lineage to keep a separate copy.": "Сохранение: в этом браузере. Экспортируйте мир, чтобы оставить отдельную копию.",
 "Save unavailable: the world stays in this open page only. Export it before leaving.": "Сохранение недоступно: мир существует только на открытой странице. Экспортируйте его перед уходом.",
 "An unreadable save was preserved separately. A fresh local world is open; you can download the original.": "Нечитаемое сохранение отложено отдельно. Открыт новый локальный мир; исходные данные можно скачать.",
 "Online: unavailable. This is a local world.": "Онлайн недоступен. Сейчас открыт локальный мир.",
 "Online: the world service responded. Each generation still needs server confirmation.": "Сервис мира ответил. Запись каждого поколения требует отдельного подтверждения.",
 "Online: checking the world service; local play is available.": "Проверяем сервис мира; локальная игра доступна.",
 "Saved for this open page only": "Сохранено только до закрытия страницы",
 "Server unavailable — this generation remains in the open page. Export before leaving.": "Сервер недоступен. Поколение осталось на открытой странице; экспортируйте его перед уходом.",
 "The local world remains in this open page. Export before leaving.": "Локальный мир доступен на открытой странице. Экспортируйте его перед уходом."
};

const chinese=window.InheritChinese;
const originals=new WeakMap(),attributes=new WeakMap();
let ready=false,locale='ru';
try{const requested=new URLSearchParams(location.search).get('lang'),saved=persistence?.getItem('osgard:game-language');locale=['ru','en','zh'].includes(requested)?requested:['ru','en','zh'].includes(saved)?saved:'ru'}catch{}
const dynamic=[];
function t(value){
 const raw=String(value??''),key=raw.replace(/\s+/g,' ').trim();
 const source=ephemeralText(key);
 if(locale==='en')return source===key?raw:source;
 let translated=locale==='zh'?chinese?.translate(source):dictionary[source];
 if(translated===undefined&&locale==='ru'){for(const [pattern,render] of dynamic){const match=source.match(pattern);if(match){translated=render(...match.slice(1));break}}}
 return translated===undefined?raw:(raw.match(/^\s*/)?.[0]||'')+translated+(raw.match(/\s*$/)?.[0]||'');
}
chinese?.setTranslator?.(t);
function textNode(node){
 const parent=node.parentElement;if(!parent||parent.closest('script,style,noscript,[data-locale-tools],[data-no-translate]'))return;
 let state=originals.get(node);if(!state||node.nodeValue!==state.rendered)state={source:node.nodeValue,rendered:node.nodeValue};
 const rendered=t(state.source);if(node.nodeValue!==rendered)node.nodeValue=rendered;
 originals.set(node,{source:state.source,rendered});
}
function element(node){
 if(!node.getAttribute||node.closest?.('script,style,[data-locale-tools],[data-no-translate]'))return;
 let saved=attributes.get(node)||{};
 for(const name of ['aria-label','title','placeholder']){if(!node.hasAttribute(name))continue;const current=node.getAttribute(name);const before=saved[name];const source=before&&current===before.rendered?before.source:current;const rendered=t(source);if(current!==rendered)node.setAttribute(name,rendered);saved[name]={source,rendered}}
 attributes.set(node,saved);
}
function apply(root=document.body){
 if(!root)return;if(root.nodeType===3){textNode(root);return}element(root);
 const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);let node;while((node=walker.nextNode()))textNode(node);
 root.querySelectorAll?.('[aria-label],[title],[placeholder]').forEach(element);
}
function setLanguage(value){
 locale=['ru','en','zh'].includes(value)?value:'ru';persistence?.setItem('osgard:game-language',locale);
 document.documentElement.lang=locale==='zh'?'zh-CN':locale;
 try{const url=new URL(location.href);url.searchParams.set('lang',locale);history.replaceState(null,'',url.href)}catch{}
 if(ready){apply();updateStorage();document.querySelectorAll('[data-game-language]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.gameLanguage===locale)));window.InheritAccount?.render();window.InheritCinematic?.updateLabels?.();window.InheritLegacyUI?.refresh?.();window.InheritStoryUI?.refresh?.();window.InheritWorldUI?.refresh?.();window.InheritCosmeticUI?.refresh?.();window.InheritResearchUI?.refresh?.();window.InheritOnboarding?.refresh?.();window.InheritAtlasUI?.refresh?.();window.InheritTimeLapseUI?.refresh?.();window.InheritHandoffMomentUI?.refresh?.()}
}
function languageTools(){
 const bar=document.createElement('div');bar.className='game-language';bar.dataset.localeTools='';bar.setAttribute('role','group');bar.setAttribute('aria-label','Язык / Language');
 for(const [code,label] of [['ru','Русский'],['en','English'],['zh','简体中文']]){const button=document.createElement('button');button.type='button';button.textContent=label;button.dataset.gameLanguage=code;button.setAttribute('aria-pressed',String(locale===code));button.addEventListener('click',()=>setLanguage(code));bar.appendChild(button)}return bar;
}
function watch(){
 const observer=new MutationObserver(records=>{for(const record of records){if(record.type==='characterData')textNode(record.target);else if(record.type==='attributes')element(record.target);else record.addedNodes.forEach(node=>apply(node))}});
 observer.observe(document.body,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['aria-label','title','placeholder']});
}

dynamic.push(
 [/^GEN (\d+)$/,n=>'ПОК. '+n],[/^Generation (\d+)$/,n=>'Поколение '+n],
 [/^INHERIT — Generation (\d+)$/,n=>'INHERIT — Поколение '+n],
 [/^Selected: (.+)$/,v=>'Выбрано: '+t(v)],[/^You (.+)$/,v=>'Вы '+t(v)],
 [/^Trace (\d+): (.+)$/, (n,v)=>'След '+n+': '+t(v)],[/^Undid (.+)$/,v=>'Отменено: '+t(v)],
 [/^Leave (\d+) more kinds? of trace$/,n=>'Добавьте ещё видов следов: '+n],
 [/^Generation (\d+) carries (\d+) recorded traces\.$/,(n,c)=>'Поколение '+n+' · записей в истории: '+c],
 [/^This history contains (\d+) author labels\. Its latest entry is by (.+)\.$/,(n,a)=>'В этой истории имён авторов: '+n+'. Последняя запись: '+a+'.'],
 [/^Viewing generation (\d+) · (\d+) preserved traces$/,(n,c)=>'Поколение '+n+' · сохранено следов: '+c],
 [/^(\d+\/\d+) trace kinds discovered in this lineage\.$/,n=>'Видов следов в этом мире: '+n+'.'],
 [/^(\d+) visits, (\d+) traces, and a world still waiting for its next keeper\.$/,(n,c)=>'Посещений: '+n+'. Следов: '+c+'. Мир ждёт продолжения.'],
 [/^Generation (\d+) holds (\d+) traces? across (\d+) kinds?\.$/,(n,c,k)=>'Поколение '+n+' · следов: '+c+' · видов: '+k+'.'],
 [/^Generation (\d+) is safely passed on$/,n=>'Сервис подтвердил поколение '+n+'.'],
 [/^(\d+) local traces preserved for the next person\.$/,n=>'Сохранено локальных следов: '+n+'.'],
 [/^(\d+) local traces preserved; server confirmation is unknown\.$/,n=>'Сохранено локальных следов: '+n+'. Подтверждения сервера нет.'],
 [/^(\d+) new traces for the next person\.$/,n=>'Новых следов для следующего поколения: '+n+'.'],
 [/^(.+) continued your world in generation (\d+)\.$/,(a,n)=>a+' продолжил мир: поколение '+n+'.'],
 [/^Generation (\d+) (.+)\. Someone will find it after you pass this world on\.$/,(n,v)=>'Поколение '+n+': '+t(v)+'. След остаётся в истории мира.'],
 [/^(\d+) changes: (.+)\.$/,(n,v)=>'Изменений: '+n+'. '+v.split(', ').map(t).join(', ')+'.'],
 [/^I left a trace in INHERIT, generation (\d+)\. Continue the island: (.+)$/,(n,url)=>'Я оставил след в INHERIT, поколение '+n+'. Открыть остров: '+url],
 [/^I chose you as the next keeper of INHERIT, generation (\d+)\. Continue the island: (.+)$/,(n,url)=>'Приглашаю тебя стать хранителем INHERIT, поколение '+n+'. Открыть остров: '+url],
 [/^I am passing on INHERIT, generation (\d+) — (\d+) traces?, (\d+) kinds?\. Leave one trace and continue the island: (.+)$/,(n,c,k,url)=>'INHERIT, поколение '+n+' · следов: '+c+' · видов: '+k+'. Продолжить историю: '+url]
);
function ephemeralText(key){if(!persistence?.ephemeral)return key;return ({'Interest saved on this device':'Saved for this open page only','Founder interest saved locally':'Saved for this open page only','Server unavailable — saved as a local generation':'Server unavailable — this generation remains in the open page. Export before leaving.','Your offline lineage is safe on this device.':'The local world remains in this open page. Export before leaving.','Saved locally. The server has not confirmed this generation.':'This generation stays in the open page only. Server confirmation is unknown; export before leaving.'})[key]||key}
function updateStorage(){
 if(window.InheritAccount?.isAccountMode()){window.InheritAccount.renderStorage();return}
 const save=document.querySelector('#inherit-save-state'),online=document.querySelector('#inherit-online-state'),recovery=document.querySelector('#inherit-recovery');
 if(save)save.textContent=t(persistence?.ephemeral?'Save unavailable: the world stays in this open page only. Export it before leaving.':'Save: this browser only. Use Export lineage to keep a separate copy.');
 if(online)online.textContent=t(persistence?.online===true?'Online: the world service responded. Each generation still needs server confirmation.':persistence?.online===false?'Online: unavailable. This is a local world.':'Online: checking the world service; local play is available.');
 if(recovery)recovery.hidden=!persistence?.recovered;
}
function init(){
 ready=true;document.documentElement.lang=locale==='zh'?'zh-CN':locale;
 const intro=document.createElement('section');intro.className='inherit-guide';intro.innerHTML='<div class="inherit-guide-heading"><div><span class="eyebrow">How to play</span><h2>Choose a trace. Leave it on the island.</h2></div></div><p>Start with three different trace types. Finish the generation when you are ready to begin the next chapter.</p><p id="inherit-controls">Controls: click or tap the island; 1–0 chooses a trace. Focus the island, use arrows and Enter to place. Ctrl/Cmd+Z undoes the last trace; H opens the chronicle.</p><div class="inherit-storage" role="status"><p id="inherit-save-state"></p><p id="inherit-online-state"></p></div><p class="inherit-truth">The first four entries are a fictional introduction. Names in local history do not mean other people are online. An invitation shares the route, not your local save.</p><div class="inherit-guide-actions"><button type="button" class="save" id="inherit-enter">Enter the island</button><a href="/play#catalog">← Каталог / Catalog</a></div><div id="inherit-recovery" hidden><p>An unreadable save was preserved separately. A fresh local world is open; you can download the original.</p><button type="button" id="inherit-recovery-download">Download recovered save</button></div>';
 document.querySelector('.app > header').insertAdjacentElement('afterend',intro);intro.querySelector('.inherit-guide-heading').appendChild(languageTools());
 intro.querySelector('.inherit-guide-heading').insertAdjacentElement('afterend',intro.querySelector('.inherit-guide-actions'));
 const journey=document.querySelector('.journey');if(journey)intro.appendChild(journey);
 const world=document.querySelector('#world');world.tabIndex=0;world.setAttribute('aria-label','Island: choose a location with arrows and place with Enter');world.setAttribute('aria-describedby','inherit-controls');
 document.querySelector('#inherit-enter').addEventListener('click',()=>{world.focus();world.scrollIntoView({block:'center',behavior:'auto'})});
 const cursor=document.createElement('span');cursor.className='inherit-cursor';cursor.setAttribute('aria-hidden','true');document.querySelector('#island').appendChild(cursor);let point={x:50,y:35};
 const coordinate=document.createElement('span');coordinate.className='inherit-coordinate';coordinate.setAttribute('role','status');world.appendChild(coordinate);
 const drawCursor=()=>{cursor.style.left=point.x+'%';cursor.style.top=point.y+'%';coordinate.textContent=(locale==='ru'?'Место: ':'Position: ')+point.x+', '+point.y;};drawCursor();
 world.addEventListener('focus',()=>world.classList.add('inherit-keyboard'));world.addEventListener('blur',()=>world.classList.remove('inherit-keyboard'));
 world.addEventListener('keydown',event=>{if(event.target!==world||event.ctrlKey||event.metaKey||event.altKey)return;const key=event.key;if(!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Enter'].includes(key))return;event.preventDefault();if(key==='ArrowLeft')point.x=Math.max(8,point.x-3);if(key==='ArrowRight')point.x=Math.min(91,point.x+3);if(key==='ArrowUp')point.y=Math.max(12,point.y-3);if(key==='ArrowDown')point.y=Math.min(77,point.y+3);drawCursor();if(key==='Enter'){const r=document.querySelector('#island').getBoundingClientRect();world.dispatchEvent(new MouseEvent('click',{bubbles:true,clientX:r.left+r.width*point.x/100,clientY:r.top+r.height*point.y/100}))}});
 document.querySelectorAll('[data-memory]').forEach(node=>node.setAttribute('aria-label',({tree:'Old tree: read its memory',ruin:'Stone arch: read its memory',beacon:'Beacon: read its memory'})[node.dataset.memory]));
 document.querySelectorAll('.close').forEach(button=>{if(!button.hasAttribute('aria-label'))button.setAttribute('aria-label','Close memory')});
 document.querySelector('#inherit-recovery-download').addEventListener('click',()=>{const raw=persistence?.getItem(persistence.recoveryKey);if(!raw)return;const url=URL.createObjectURL(new Blob([raw],{type:'application/json'}));const link=document.createElement('a');link.href=url;link.download='inherit-original-save.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000)});
 for(const [selector,openClass,triggerSelector] of [['#panel','show'],['.catalog','open','.catalog-button'],['.chronicle','open','.chronicle-button'],['.return-card','show'],['.replay-banner','show'],['#toast','show']]){
  const item=document.querySelector(selector);if(!item)continue;
  const trigger=triggerSelector?document.querySelector(triggerSelector):null;
  if(trigger){if(!item.id)item.id='inherit-'+selector.slice(1);trigger.setAttribute('aria-controls',item.id)}
  const sync=()=>{const open=item.classList.contains(openClass);item.hidden=!open;item.inert=!open;item.setAttribute('aria-hidden',String(!open));if(trigger)trigger.setAttribute('aria-expanded',String(open))};
  sync();new MutationObserver(sync).observe(item,{attributes:true,attributeFilter:['class']});
 }
 apply();updateStorage();watch();
}
window.InheritUI={t,setLanguage,getLanguage:()=>locale,updateStorage};
window.InheritUI.addTranslations=values=>{Object.assign(dictionary,values);if(ready)apply()};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();

})();
