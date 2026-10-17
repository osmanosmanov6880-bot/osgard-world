/* RU/EN presentation only. Match/auth state belongs to remix-client.js. */
(()=>{
"use strict";
const persistence=window.RemixPersistence||(()=>{
 const memory=new Map(),store={ephemeral:false};
 store.getItem=key=>{if(memory.has(key))return memory.get(key);try{return localStorage.getItem(key)}catch{store.ephemeral=true;return null}};
 store.setItem=(key,value)=>{memory.set(key,String(value));try{localStorage.setItem(key,String(value))}catch{store.ephemeral=true}};
 return store;
})();
window.RemixPersistence=persistence;
const english={
 "REMIX — создай и пройди испытание":"REMIX — create and complete a challenge",
 "Экосистема OSGARD":"OSGARD ecosystem",
 "Продукты OSGARD":"OSGARD products",
 "← Каталог игровых миров":"← Game worlds catalog",
 "Создай · Пройди · Передай":"Create · Complete · Share",
 "Найди путь через барьеры и опасные клетки. Пройди своё испытание, опубликуй его и предложи другому игроку найти более короткий маршрут.":"Find a path through barriers and hazards. Complete your challenge, publish it and invite another player to find a shorter route.",
 "Режимы REMIX":"REMIX modes",
 "Открыть серверную арену ↓":"Open the server arena ↓",
 "Открыть Unity-версию ↗":"Open the Unity version ↗",
 "Одинаковый seed — одинаковое поле":"Same seed, same arena",
 "Результат рассчитывает сервер":"The server calculates results",
 "Клавиатура и touch":"Keyboard and touch",
 "Перед запуском":"Before you start",
 "Серверная арена.":"Server arena.",
 "Войдите в OSGARD Core, создайте поле и достигните цели. После публикации другой игрок сможет пройти то же испытание в своём заезде.":"Sign in to OSGARD Core, create an arena and reach the goal. Once published, another player can attempt the same challenge in their own run.",
 "Управление.":"Controls.",
 "Выберите поле: стрелки или WASD — ход, Space — прыжок в последнем направлении. На телефоне используйте кнопки под полем. Tab перемещает фокус по странице.":"Focus the arena: arrows or WASD move; Space jumps in the last direction. On a phone, use the buttons below the arena. Tab moves focus around the page.",
 "Сохранение и онлайн.":"Saving and online play.",
 "Арене нужен совместимый сервис REMIX на этом сайте. Подтверждённые ходы и результаты сохраняет сервер; при потере ответа повторите неподтверждённое действие.":"The arena requires a compatible REMIX service on this site. The server saves confirmed moves and results; if a response is lost, retry the unconfirmed action.",
 "Отдельная игровая сборка требует WebGL 2. Её управление показано внутри игры; сетевой сервис и результаты не объединены с этой ареной.":"The separate game build requires WebGL 2. Its controls are shown in the game; its online service and results are separate from this arena.",
 "Подключение серверной арены":"Arena connection",
 "Используется сервис этого сайта. Совместимость проверяется перед входом; адрес Unity-сервиса здесь не меняется.":"This arena uses the service on this site. Compatibility is checked before sign-in; this setting does not change the Unity service.",
 "Адрес API арены":"Arena API address",
 "Серверное испытание REMIX":"REMIX server challenge",
 "Проверяем сервер матчей…":"Checking the match service…",
 "Сессия ещё не проверена":"Session not checked yet",
 "Поле испытания":"Challenge arena",
 "Подключаемся к сервису испытаний…":"Connecting to the challenge service…",
 "Поле испытания. Управление стрелками или WASD.":"Challenge arena. Use the arrow keys or WASD.",
 "Ожидаем подтверждённое сервером поле":"Waiting for the server-confirmed arena",
 "Игрок":"Player",
 "Барьер":"Barrier",
 "Опасность":"Hazard",
 "Цель":"Goal",
 "Направление хода":"Move direction",
 "Ход вверх":"Move up",
 "Ход влево":"Move left",
 "Ход вниз":"Move down",
 "Ход вправо":"Move right",
 "Прыжок":"Jump",
 "Стрелки или WASD":"Arrow keys or WASD",
 "— ход на одну клетку.":"move one cell.",
 "— прыжок на две клетки в последнем направлении; барьер перепрыгнуть нельзя. Опасная клетка возвращает на старт. Ход стоит 100 мс игрового времени, прыжок — 200 мс, падение добавляет 1500 мс. Это пошаговая арена: задержка сети не влияет на счёт.":"jumps two cells in the last direction; barriers cannot be jumped. A hazard returns you to the start. A move costs 100 ms of game time, a jump costs 200 ms and a fall adds 1500 ms. This is a turn-based arena: network latency does not affect your score.",
 "Повторить неподтверждённое действие":"Retry the unconfirmed action",
 "Восстановить сохранённый заезд":"Restore the saved run",
 "Вход в OSGARD Core":"Sign in to OSGARD Core",
 "Один аккаунт хранит ваши испытания, заезды и повторы.":"One account stores your challenges, runs and replays.",
 "Имя пользователя":"Username",
 "Пароль — от 12 символов":"Password — at least 12 characters",
 "Войти":"Sign in",
 "Создать аккаунт":"Create account",
 "Испытание дня":"Daily challenge",
 "Твой маршрут":"Your route",
 "Название испытания":"Challenge title",
 "Seed — код поля":"Seed — arena code",
 "Создать испытание":"Create challenge",
 "Сначала автор достигает цели в проверочном заезде. После публикации каждый игрок проходит то же поле отдельно; в таблицу попадает его лучший заезд.":"The creator must first reach the goal in a proof run. Once published, each player attempts the same arena separately; their best run appears on the leaderboard.",
 "Пройти ещё раз":"Run again",
 "Новое поле":"New arena",
 "Черновики доступны только автору.":"Drafts are only visible to their creator.",
 "Заезд завершён":"Run complete",
 "Твой результат":"Your result",
 "Подтвердить и опубликовать":"Validate and publish",
 "Посмотреть повтор":"View replay",
 "Сделать свой ремикс":"Create your remix",
 "Серверный повтор":"Server replay",
 "Ход повтора":"Replay step",
 "Закрыть повтор":"Close replay",
 "Лучшие заезды испытания":"Best challenge runs",
 "Опубликованное испытание":"Published challenge",
 "Ссылка для другого игрока":"Link for another player",
 "Поделиться испытанием ↗":"Share challenge ↗",
 "Скопировать ссылку":"Copy invite link",
 "Поделиться карточкой ↗":"Share result card ↗",
 "Скачать карточку PNG ↓":"Download result card PNG ↓",
 "ПАРТНЁРАМ / ОБСУЖДЕНИЕ":"PARTNER SLOT / INQUIRY ONLY",
 "Испытание для вашего проекта":"A challenge for your project",
 "Это заявка на сотрудничество после заезда. Активная рекламная кампания здесь не представлена.":"This is a partnership inquiry after the run. No active advertising campaign is represented here.",
 "Обсудить партнёрское испытание ↗":"Discuss a sponsored challenge ↗",
 "Здесь работает отдельная серверная арена REMIX. Существующая Unity-версия открывается отдельно; её сетевой сервис и результаты не объединены с этой ареной.":"This page runs a separate REMIX server arena. The existing Unity version opens separately; its online service and results are not shared with this arena.",
 "Сервис вернул страницу вместо ответа API.":"The service returned a page instead of an API response.",
 "Запрос отклонён сервером.":"The server rejected this request.",
 "Нет подтверждения от сервера. Проверьте соединение и повторите действие.":"No confirmation from the server. Check your connection and retry the action.",
 "Заезд идёт":"Run in progress",
 "Начать заезд":"Start run",
 "Поле появится после запуска заезда":"The arena appears when a run starts",
 "Сервис вернул неподдерживаемое испытание.":"The service returned an unsupported challenge.",
 "Ремикс опубликованного поля":"Remix of a published arena",
 "Твоё испытание":"Your challenge",
 "Испытание другого игрока":"Another player's challenge",
 "Опубликовано. Каждый игрок получает тот же набор объектов и собственный заезд.":"Published. Each player receives the same objects and their own run.",
 "Черновик. Достигни цели в проверочном заезде, затем подтверди публикацию.":"Draft. Reach the goal in a proof run, then validate publication.",
 "Сервис вернул неподдерживаемое состояние заезда.":"The service returned an unsupported run state.",
 "Заезд активен. Выбирай направление; клетка меняется после ответа сервера.":"Run active. Choose a direction; your position changes after the server responds.",
 "Результат не относится к этому заезду.":"The result does not belong to this run.",
 "Неподдерживаемая таблица результатов.":"Unsupported leaderboard response.",
 "Сначала войдите в доступный сервис.":"Sign in to the available service first.",
 "Сначала восстановите сохранённый заезд.":"Restore your saved run first.",
 "Сначала повторите неподтверждённое действие.":"Retry the unconfirmed action first.",
 "Сервер не подтвердил этот ход.":"The server did not confirm this move.",
 "Испытание опубликовано. Отправь ссылку другому игроку или пройди заезд для таблицы результатов.":"Challenge published. Send the link to another player or complete a leaderboard run.",
 "Действие не подтверждено.":"Action not confirmed.",
 "Введите название от 2 до 100 символов и целый seed от 1 до 2147483647.":"Enter a title of 2–100 characters and a whole-number seed from 1 to 2147483647.",
 "Не удалось обновить состояние.":"Could not refresh the run state.",
 "Восстанавливаем сохранённый заезд…":"Restoring your saved run…",
 "Есть неподтверждённое действие. Повтор сохранит его номер и ключ, поэтому второй ход не будет создан.":"An action is unconfirmed. Retrying preserves its sequence and key, so it cannot create a second move.",
 "Испытание загружено с сервера. Начни свой заезд.":"Challenge loaded from the server. Start your run.",
 "Сервис готов. Создай испытание и пройди маршрут.":"Service ready. Create a challenge and complete the route.",
 "Сессия истекла. Для сохранённого действия войдите тем же аккаунтом.":"Session expired. Sign in to the same account to recover the saved action.",
 "Сессия истекла. Войдите снова.":"Session expired. Sign in again.",
 "Создаём аккаунт…":"Creating your account…",
 "Проверяем вход…":"Signing in…",
 "Сервис входа вернул неподдерживаемую сессию.":"The sign-in service returned an unsupported session.",
 "Повтор не соответствует этому результату.":"The replay does not match this result.",
 "Контрольный хеш повтора не совпадает.":"The replay checksum does not match.",
 "Ссылка скопирована. Другой игрок сможет открыть это же испытание.":"Link copied. Another player can open this same challenge.",
 "Ссылка выделена. Скопируйте её из поля.":"Link selected. Copy it from the field.",
 "Не удалось создать PNG результата.":"Could not create the result PNG.",
 "Браузер не передал файл напрямую. Карточка PNG скачана.":"The browser could not share the file directly. The PNG card was downloaded.",
 "Карточка с серверным результатом скачана.":"The server result card was downloaded.",
 "Новое испытание":"New challenge",
 "Выбери название и seed следующего поля.":"Choose a title and seed for the next arena.",
 "Подключённый backend не объявляет совместимую арену remix-arena-v1. Этот режим здесь недоступен.":"The connected backend does not announce a compatible remix-arena-v1 arena. This mode is unavailable here.",
 "Серверная арена доступна":"Server arena available",
 "Неверный формат сессии.":"Invalid session format.",
 "Для сохранения заезда нужен вход":"Sign in to save your run",
 "Войдите в OSGARD Core или создайте аккаунт, чтобы начать заезд.":"Sign in to OSGARD Core or create an account to start a run.",
 "Серверная арена недоступна":"Server arena unavailable",
 "На этом сайте сервис REMIX arena не включён. Создание заездов недоступно.":"The REMIX arena service is not enabled on this site. Runs cannot be created.",
 "Сервис вернул неподдерживаемый результат.":"The service returned an unsupported result.",
 "ИСПЫТАНИЕ ПРОЙДЕНО":"CHALLENGE COMPLETE",
 "ЛИМИТ ХОДОВ":"MOVE LIMIT",
 "Повтори маршрут. Найди более короткий путь.":"Try the route. Find a shorter path.",
 "Браузер не сохраняет настройки языка. Выбор действует на открытой странице; сохранение заездов подтверждает сервер.":"Language preferences cannot be saved in this browser. Your choice lasts while this page is open; the server confirms saved runs."
};
const russian=Object.fromEntries(Object.entries(english).map(([ru,en])=>[en,ru]));
const originals=new WeakMap(),attributes=new WeakMap();
let ready=false,locale='ru';
try{const requested=new URLSearchParams(location.search).get('lang');locale=requested==='en'?'en':requested==='ru'?'ru':persistence.getItem('osgard:game-language')==='en'?'en':'ru'}catch{}
const dynamicEnglish=[
 [/^Игрок: (.+)$/,name=>'Player: '+name],
 [/^(Проверочный заезд|Заезд испытания) · (.+)$/,(kind,id)=>(kind==='Проверочный заезд'?'Proof run':'Challenge run')+' · '+id],
 [/^Клетка (\d+), (\d+) · ход (\d+)\/256 · падений (\d+) · (\d+) мс$/,(x,y,step,falls,time)=>`Cell ${x}, ${y} · move ${step}/256 · falls ${falls} · ${time} ms`],
 [/^Опубликованное испытание · seed (\d+)$/,seed=>'Published challenge · seed '+seed],
 [/^(Цель достигнута|Лимит ходов) · (\d+) ходов · (\d+) очков$/,(kind,steps,score)=>(kind==='Цель достигнута'?'Goal reached':'Move limit')+` · ${steps} moves · ${score} points`],
 [/^(\d+) мс игрового времени · падений (\d+) · прыжков (\d+) · повтор (.+)$/,(time,falls,jumps,hash)=>`${time} ms game time · falls ${falls} · jumps ${jumps} · replay ${hash}`],
 [/^(Ты|Игрок .+) · (\d+) очков · (\d+) мс$/,(player,score,time)=>(player==='Ты'?'You':player.replace(/^Игрок /,'Player '))+` · ${score} points · ${time} ms`],
 [/^Не удалось восстановить заезд: (.+)$/,message=>'Could not restore the run: '+t(message)],
 [/^Серверный повтор · ход (\d+)\/(\d+) · клетка (\d+), (\d+) · (\d+) мс$/,(step,total,x,y,time)=>`Server replay · move ${step}/${total} · cell ${x}, ${y} · ${time} ms`]
];
function t(value){
 const raw=String(value??''),key=raw.replace(/\s+/g,' ').trim();
 let translated=(locale==='en'?english:russian)[key];
 if(translated===undefined&&locale==='en')for(const [pattern,render] of dynamicEnglish){const match=key.match(pattern);if(match){translated=render(...match.slice(1));break}}
 if(translated===undefined&&key.startsWith('RESULTS · '))translated='RESULTS · '+t(key.slice(10));
 return translated===undefined?raw:(raw.match(/^\s*/)?.[0]||'')+translated+(raw.match(/\s*$/)?.[0]||'');
}
function textNode(node){
 const parent=node.parentElement;if(!parent||parent.closest('script,style,noscript,[data-locale-tools],[data-no-translate]'))return;
 let state=originals.get(node);if(!state||node.nodeValue!==state.rendered)state={source:node.nodeValue,rendered:node.nodeValue};
 const rendered=t(state.source);if(node.nodeValue!==rendered)node.nodeValue=rendered;
 originals.set(node,{source:state.source,rendered});
}
function element(node){
 if(!node.getAttribute||node.closest?.('script,style,[data-locale-tools],[data-no-translate]'))return;
 const saved=attributes.get(node)||{};
 for(const name of ['aria-label','title','placeholder']){if(!node.hasAttribute(name))continue;const current=node.getAttribute(name),before=saved[name],source=before&&current===before.rendered?before.source:current,rendered=t(source);if(current!==rendered)node.setAttribute(name,rendered);saved[name]={source,rendered}}
 attributes.set(node,saved);
}
function apply(root=document.body){
 if(!root)return;if(root.nodeType===3){textNode(root);return}element(root);
 const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);let node;while((node=walker.nextNode()))textNode(node);
 root.querySelectorAll?.('[aria-label],[title],[placeholder]').forEach(element);
}
function setLanguage(value){
 locale=value==='en'?'en':'ru';persistence.setItem('osgard:game-language',locale);
 document.documentElement.lang=locale;
 try{const url=new URL(location.href);url.searchParams.set('lang',locale);history.replaceState(null,'',url.href)}catch{}
 if(ready){apply();document.title=t('REMIX — создай и пройди испытание');updateStorage();document.querySelectorAll('[data-game-language]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.gameLanguage===locale)));window.dispatchEvent(new Event('remix:languagechange'))}
}
function languageTools(){
 const bar=document.createElement('div');bar.className='game-language';bar.dataset.localeTools='';bar.setAttribute('role','group');bar.setAttribute('aria-label','Язык / Language');
 for(const [code,label] of [['ru','Русский'],['en','English']]){const button=document.createElement('button');button.type='button';button.textContent=label;button.dataset.gameLanguage=code;button.setAttribute('aria-pressed',String(locale===code));button.addEventListener('click',()=>setLanguage(code));bar.appendChild(button)}return bar;
}
function updateStorage(){const node=document.querySelector('#remix-storage-state');if(node){node.hidden=!persistence.ephemeral;node.textContent=t('Браузер не сохраняет настройки языка. Выбор действует на открытой странице; сохранение заездов подтверждает сервер.')}}
function init(){
 ready=true;document.documentElement.lang=locale;document.title=t('REMIX — создай и пройди испытание');
 document.querySelector('.hero').insertAdjacentElement('beforebegin',languageTools());
 apply();updateStorage();
 const observer=new MutationObserver(records=>{for(const record of records){if(record.type==='characterData')textNode(record.target);else if(record.type==='attributes')element(record.target);else record.addedNodes.forEach(node=>apply(node))}});
 observer.observe(document.body,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['aria-label','title','placeholder']});
}
window.RemixUI={t,setLanguage,getLanguage:()=>locale,updateStorage};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();
