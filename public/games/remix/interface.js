/* RU/EN interface layer. Keeps original game state and mechanics independent of presentation. */
(()=>{
"use strict";
const persistence=window.RemixPersistence;
const dictionary={
 "Failed to fetch":"Нет связи с игровым сервисом. Проверьте подключение.",
 "OSGARD ENTERTAINMENT / 03": "OSGARD PLAY / 03",
 "One daily seed. One challenge link. Let a friend try the same run and compare server-recorded results. Every run is an invitation to beat your best.": "Испытание дня с одинаковыми условиями. Отправьте другу ссылку и сравните результаты, если сервис матчей подтвердит оба прохождения.",
 "DAILY CHALLENGE / SERVER-RECORDED RESULTS": "ИСПЫТАНИЕ ДНЯ / ПОДТВЕРЖДЕНИЕ СЕРВЕРОМ",
 "Play in browser ↗": "Открыть игру ↗",
 "The loop": "Как устроено испытание",
 "01 / CREATE": "01 / СОЗДАЙТЕ",
 "Shape a challenge": "Создайте испытание",
 "Publish a challenge with deterministic rules and a clear objective.": "Создайте испытание с повторяемыми правилами и понятной целью.",
 "02 / PLAY": "02 / ПРОЙДИТЕ",
 "Enter the match": "Начните матч",
 "Countdown, live state and inputs are validated by the authoritative service.": "Состояние матча и команды игрока обрабатывает отдельный игровой сервис.",
 "03 / REMIX": "03 / ПОДЕЛИТЕСЬ",
 "Leave proof": "Сохраните результат",
 "Results persist as replay keys that can be shared, inspected and remixed.": "Сервис выдаёт подтверждённый результат и данные повтора, когда эти функции доступны.",
 "The player build runs separately from the challenge console. Server validation remains the source of match results; social links never manufacture scores.": "Игровая сборка открывается отдельно от консоли испытаний. Подтверждённый результат приходит от сервера; ссылка сама по себе не подтверждает очки.",
 "04 / GROWTH + REVENUE": "04 / ПАРТНЁРАМ",
 "Invite a rival.": "Пригласите соперника.",
 "Open a sponsor slot.": "Создайте совместное испытание.",
 "The daily seed gives players a reason to return; the challenge link gives them a concrete reason to invite someone; a result screen can introduce a clearly labelled sponsor only after the run ends. Sponsorship is by inquiry until a real campaign is contracted.": "Испытание дня даёт новый повод зайти, а ссылка — пригласить друга. Партнёрское размещение обсуждается отдельно и может появиться только после прохождения. Действующая рекламная кампания не заявляется.",
 "Sponsor a challenge series ↗": "Обсудить серию испытаний ↗",
 "LIVE MATCH CONSOLE": "КОНСОЛЬ ИСПЫТАНИЙ",
 "Ready to enter": "Готовы начать?",
 "The daily challenge uses a shared UTC seed. Create a run, then send the invite link to a friend.": "Условия испытания одинаковы в течение дня по UTC. Создайте матч, затем отправьте другу ссылку.",
 "API URL": "Адрес игрового сервиса",
 "Create daily challenge": "Создать испытание дня",
 "Local input preview": "Поле управления консоли, не изображение Unity",
 "CHALLENGE PASSPORT": "КАРТОЧКА ИСПЫТАНИЯ",
 "Awaiting server ID": "Ожидаем номер от сервера",
 "Use this link to challenge a friend to the same ruleset. Only the server result is presented as a result.": "Ссылка приглашает друга пройти те же правила. Результат считается подтверждённым после ответа сервера.",
 "Shareable challenge URL": "Ссылка для приглашения друга",
 "Share challenge ↗": "Поделиться испытанием ↗",
 "Copy invite link": "Скопировать ссылку",
 "Run this challenge again ↻": "Пройти ещё раз ↻",
 "Share result card ↗": "Поделиться карточкой ↗",
 "Download result card PNG ↓": "Скачать карточку PNG ↓",
 "PARTNER SLOT / INQUIRY ONLY": "ПАРТНЁРАМ / ОБСУЖДЕНИЕ",
 "A brand can sponsor the next challenge.": "Следующее испытание можно создать с партнёром.",
 "This is a commercial inquiry link, not a live ad. It appears after the result, never over active controls. No sponsor campaign is currently represented as active.": "Ссылка ведёт к обсуждению партнёрства и появляется после результата. Действующая рекламная кампания не подключена.",
 "Discuss a sponsored challenge ↗": "Обсудить партнёрское испытание ↗",
 "Opening a server-owned daily challenge...": "Запрашиваем испытание у игрового сервиса…",
 "The challenge service returned no challenge ID.": "Сервис не вернул номер испытания.",
 "The match service returned no match ID.": "Сервис не вернул номер матча.",
 "Shared challenge accepted by the match service. Use arrow keys or WASD.": "Сервис принял приглашение. На поле: A/D или ←/→; W, ↑ или пробел — прыжок.",
 "Match created. Use arrow keys or WASD to submit input.": "Матч создан. На поле: A/D или ←/→; W, ↑ или пробел — прыжок.",
 "Match active": "Матч идёт",
 "Retry shared challenge": "Повторить подключение",
 "Retry daily challenge": "Попробовать снова",
 "Unknown error": "Неизвестная ошибка",
 "FRIEND CHALLENGE / SERVER CHECK": "ИСПЫТАНИЕ ДРУГА / ПРОВЕРКА СЕРВЕРОМ",
 "FRIEND CHALLENGE / PENDING SERVER VALIDATION": "ИСПЫТАНИЕ ДРУГА / ОЖИДАЕТ ПРОВЕРКИ",
 "Finish a server-recorded run first.": "Сначала завершите матч и получите подтверждённый результат.",
 "Result card downloaded. Share the challenge link so a friend can run the same seed.": "Карточка скачана. Отправьте другу ссылку, чтобы он прошёл те же условия.",
 "The share sheet opened. Share delivery depends on the target app.": "Окно отправки открыто. Дальнейшая отправка зависит от выбранного приложения.",
 "This browser cannot share files directly. The PNG card was downloaded instead.": "Браузер не поддерживает прямую отправку файлов. Карточка PNG скачана.",
 "Create or accept a challenge first.": "Сначала создайте испытание или примите приглашение.",
 "Invite link copied. Send it to a friend who can open the same challenge.": "Ссылка скопирована. Отправьте её другу.",
 "Share sheet opened. The recipient still needs to open the link and start the challenge.": "Окно отправки открыто. Получателю нужно открыть ссылку и начать испытание.",
 "Create another match": "Создать следующий матч",
 "Ready to run this same challenge again.": "Готово к повторному прохождению.",
 "A friend shared a challenge. Accept it to ask the match service to validate and start it.": "Вас пригласили в испытание. Примите приглашение, чтобы сервис проверил его и создал матч.",
 "Accept shared challenge": "Принять приглашение",
 "Server returned the result. Challenge a friend to compare this same ruleset.": "Сервер вернул результат. Предложите другу пройти те же условия.",
 "The match service is unavailable. Try again later.": "Игровой сервис недоступен. Попробуйте позже.",
 "The match service rejected this request.": "Игровой сервис отклонил запрос.",
 "The match service returned an invalid response.": "Сервис вернул ответ в неверном формате.",
 "The match service took too long to respond.": "Сервис не ответил вовремя. Повторите попытку.",
 "Enter the REMIX API URL first": "Укажите адрес сервиса в дополнительных настройках.",
 "Copy the challenge invite link": "Скопируйте ссылку-приглашение",
 "Before you start": "Перед запуском",
 "Unity WebGL: a browser with WebGL 2 is required. The player and the console below are separate views.": "Unity WebGL: нужен браузер с WebGL 2. Игровая сборка и консоль ниже открываются отдельно.",
 "Save and online: match results require the REMIX service. Page loading does not confirm an online match or a saved result.": "Сохранение и онлайн: результат матча подтверждает сервис REMIX. Открытая страница ещё не означает работающий онлайн или сохранённый результат.",
 "Player controls are shown inside the build. For the console: focus its field, use A/D or left/right; W, up or Space jumps.": "Управление сборкой показано внутри игры. В консоли: выберите поле, A/D или ←/→ — движение; W, ↑ или пробел — прыжок.",
 "Advanced connection settings": "Дополнительные настройки подключения",
 "Keep the default address unless you run your own compatible match service.": "Оставьте адрес по умолчанию, если вы не используете собственный совместимый игровой сервис.",
 "Console controls: focus the field or use the buttons below. A/D or arrows moves; W, up or Space jumps.": "Управление консолью: выберите поле или используйте кнопки ниже. A/D или ←/→ — движение; W, ↑ или пробел — прыжок.",
 "← Left": "← Влево",
 "Jump ↑": "Прыжок ↑",
 "Right →": "Вправо →",
 "Preferences cannot be saved in this browser. You can still play while this page is open.": "Браузер не сохраняет настройки. На открытой странице можно продолжить игру."
};

const originals=new WeakMap(),attributes=new WeakMap();
let ready=false,locale='ru';
try{const requested=new URLSearchParams(location.search).get('lang');locale=requested==='en'?'en':requested==='ru'?'ru':persistence?.getItem('osgard:game-language')==='en'?'en':'ru'}catch{}
const dynamic=[];
function t(value){
 const raw=String(value??''),key=raw.replace(/\s+/g,' ').trim();
 const source=ephemeralText(key);
 if(locale==='en')return source===key?raw:source;
 let translated=dictionary[source];
 if(translated===undefined){for(const [pattern,render] of dynamic){const match=source.match(pattern);if(match){translated=render(...match.slice(1));break}}}
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
 locale=value==='en'?'en':'ru';persistence?.setItem('osgard:game-language',locale);
 document.documentElement.lang=locale;
 try{const url=new URL(location.href);url.searchParams.set('lang',locale);history.replaceState(null,'',url.href)}catch{}
 if(ready){apply();updateStorage();document.querySelectorAll('[data-game-language]').forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.gameLanguage===locale)))}
}
function languageTools(){
 const bar=document.createElement('div');bar.className='game-language';bar.dataset.localeTools='';bar.setAttribute('role','group');bar.setAttribute('aria-label','Язык / Language');
 for(const [code,label] of [['ru','Русский'],['en','English']]){const button=document.createElement('button');button.type='button';button.textContent=label;button.dataset.gameLanguage=code;button.setAttribute('aria-pressed',String(locale===code));button.addEventListener('click',()=>setLanguage(code));bar.appendChild(button)}return bar;
}
function watch(){
 const observer=new MutationObserver(records=>{for(const record of records){if(record.type==='characterData')textNode(record.target);else if(record.type==='attributes')element(record.target);else record.addedNodes.forEach(node=>apply(node))}});
 observer.observe(document.body,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['aria-label','title','placeholder']});
}

dynamic.push(
 [/^(Connection error|State error|Input error|Card export unavailable|Result-card sharing unavailable): (.+)$/,(kind,value)=>({'Connection error':'Ошибка подключения','State error':'Ошибка состояния','Input error':'Команда не отправлена','Card export unavailable':'Не удалось скачать карточку','Result-card sharing unavailable':'Не удалось отправить карточку'})[kind]+': '+t(value)],
 [/^Match (.+)$/,id=>'Матч '+id],[/^Friend challenge (.+)$/,id=>'Испытание друга '+id],
 [/^CHALLENGE \/ (.+)$/,id=>'ИСПЫТАНИЕ / '+id],[/^DAILY CHALLENGE \/ (.+)$/,date=>'ИСПЫТАНИЕ ДНЯ / '+date],
 [/^Seed (\d+) · Share this link to let a friend enter the same challenge\. The match API must accept the shared challenge before it starts\.$/,seed=>'Код условий: '+seed+'. Отправьте ссылку другу. Для запуска сервис должен подтвердить приглашение.'],
 [/^Server result · score (.+)$/,score=>'Подтверждённый результат · очки: '+score],
 [/^Server result · (.+)$/,score=>'Подтверждённый результат · '+score],[/^RESULTS · (.+)$/,score=>'РЕЗУЛЬТАТ · '+t(score)],
 [/^(.+) · (\d+) player\(s\) · (\d+) replay frames$/,(phase,players,frames)=>(({'WAITING':'Ожидание','COUNTDOWN':'Обратный отсчёт','PLAYING':'Матч идёт','RUNNING':'Матч идёт','RESULTS':'Результаты'})[phase]||phase)+' · игроков: '+players+' · кадров повтора: '+frames]
);
function ephemeralText(key){return key}
function updateStorage(){const node=document.querySelector('#remix-storage-state');if(node){node.hidden=!persistence?.ephemeral;node.textContent=t('Preferences cannot be saved in this browser. You can still play while this page is open.')}}
function init(){
 ready=true;document.documentElement.lang=locale;
 const hero=document.querySelector('.hero'),tools=languageTools();hero.insertAdjacentElement('beforebegin',tools);
 const guide=document.createElement('aside');guide.className='remix-guide';guide.innerHTML='<strong>Before you start</strong><p>Unity WebGL: a browser with WebGL 2 is required. The player and the console below are separate views.</p><p>Player controls are shown inside the build. For the console: focus its field, use A/D or left/right; W, up or Space jumps.</p><p>Save and online: match results require the REMIX service. Page loading does not confirm an online match or a saved result.</p>';hero.appendChild(guide);
 const api=document.querySelector('#api-url'),settings=document.createElement('details');settings.className='remix-settings';settings.innerHTML='<summary>Advanced connection settings</summary><p>Keep the default address unless you run your own compatible match service.</p><label>API URL</label>';api.insertAdjacentElement('beforebegin',settings);settings.querySelector('label').appendChild(api);
 const arena=document.querySelector('#arena');arena.tabIndex=0;arena.setAttribute('aria-describedby','remix-console-controls');const controls=document.createElement('div');controls.className='remix-console-controls';controls.innerHTML='<p id="remix-console-controls">Console controls: focus the field or use the buttons below. A/D or arrows moves; W, up or Space jumps.</p><div><button type="button" data-console-action="left">← Left</button><button type="button" data-console-action="jump">Jump ↑</button><button type="button" data-console-action="right">Right →</button></div><p id="remix-storage-state" role="status" hidden></p>';arena.insertAdjacentElement('afterend',controls);
 controls.querySelectorAll('[data-console-action]').forEach(button=>button.addEventListener('click',()=>{const action=button.dataset.consoleAction;if(action==='left')send(-1,0,false);if(action==='right')send(1,0,false);if(action==='jump')send(0,1,true)}));
 const status=document.querySelector('#match-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');
 apply();updateStorage();watch();
}
window.RemixUI={t,setLanguage,getLanguage:()=>locale,updateStorage};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();

})();
